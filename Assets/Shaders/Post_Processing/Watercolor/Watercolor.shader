Shader "Post/Watercolor"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PaperTex ("Paper Texture", 2D) = "white" {}
        _SecondTex ("Random Noise Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _PaperTex;
            sampler2D _SecondTex;

            v2f vert (appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            // 获取颜色，将其与灰色混合
            fixed4 getCol(float2 pos, sampler2D tex)
            {
                float2 uv = pos.xy / _ScreenParams.xy;
                fixed4 c1 = tex2D(tex, uv);
                fixed4 c2 = fixed4(.4, .4, .4, 1); // 在绿色屏幕上为灰色
                float d = clamp(dot(c1.rgb, float3(-0.5, 1.0, -0.5)), 0.0, 1.0);
                return lerp(c1, c2, 1.8 * d);
            }

            // 获取位置处的梯度
            float2 getGrad(float2 pos, float delta, sampler2D tex)
            {
                float2 d = float2(delta, 0);
                return float2(
                    dot((getCol(pos + d.xy, tex) - getCol(pos - d.xy, tex)).rgb, .333),
                    dot((getCol(pos + d.yx, tex) - getCol(pos - d.yx, tex)).rgb, .333)
                ) / delta;
            }

            // 获取随机噪声
            fixed4 getRand(float2 pos, sampler2D tex) 
            {
                float2 uv = pos.xy / _ScreenParams.xy;
                return tex2D(tex, uv);
            }

            // 生成一种图案
            float htPattern(float2 pos, sampler2D tex)
            {
                float p;
                float r = getRand(pos * .4 / .7 * 1., tex).r;
                p = clamp((pow(r + .3, 2.) - .45), 0., 1.);
                return p;
            }

            // 获取位置处的值
            float getVal(float2 pos, float level, sampler2D tex)
            {
                return length(getCol(pos, tex).rgb) + 0.0001 * length(pos - 0.5 * _ScreenParams.xy);
            }

            // 获取黑白距离
            fixed4 getBWDist(float2 pos, sampler2D tex)
            {
                return smoothstep(.9, 1.1, getVal(pos, 0., tex) * .9 + htPattern(pos * .7, tex));
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 计算位置
                float2 pos = i.uv * _ScreenParams.xy;
                float2 pos2 = pos;
                float2 pos3 = pos;
                float2 pos4 = pos;
                float2 pos0 = pos;
                float3 col = float3(0, 0, 0);
                float3 col2 = float3(0, 0, 0);
                float cnt = 0.0;
                float cnt2 = 0.;

                // 对每个采样点进行循环处理
                for(int j = 0; j < 24; j++)
                {   
                    // 获取梯度用于轮廓
                    float2 gr = getGrad(pos, 2.0, _MainTex) + .0001 * (getRand(pos, _SecondTex).xy - .5);
                    float2 gr2 = getGrad(pos2, 2.0, _MainTex) + .0001 * (getRand(pos2, _SecondTex).xy - .5);
                    
                    // 获取梯度用于水洗效果
                    float2 gr3 = getGrad(pos3, 2.0, _MainTex) + .0001 * (getRand(pos3, _SecondTex).xy - .5);
                    float2 gr4 = getGrad(pos4, 2.0, _MainTex) + .0001 * (getRand(pos4, _SecondTex).xy - .5);
                    
                    float grl = clamp(10. * length(gr), 0., 1.);
                    float gr2l = clamp(10. * length(gr2), 0., 1.);

                    // 处理轮廓
                    pos += .8 * normalize(gr);
                    pos2 -= .8 * normalize(gr2);
                    float fact = 1. - float(j) / 24.;
                    col += fact * lerp(float3(1.2, 1.2, 1.2), getBWDist(pos, _MainTex).rgb * 2., grl);
                    col += fact * lerp(float3(1.2, 1.2, 1.2), getBWDist(pos2, _MainTex).rgb * 2., gr2l);
                    
                    // 处理颜色和水洗效果
                    pos3 += .25 * normalize(gr3) + .5 * (getRand(pos0, _SecondTex).xy - .5);
                    pos4 -= .5 * normalize(gr4) + .5 * (getRand(pos0, _SecondTex).xy - .5);
                    
                    float f1 = 3. * fact;
                    float f2 = 4. * (.7 - fact); 
                    col2 += f1 * (getCol(pos3, _MainTex).rgb + .25 + .4 * getRand(pos3 * 1., _SecondTex).xyz);
                    col2 += f2 * (getCol(pos4, _MainTex).rgb + .25 + .4 * getRand(pos4 * 1., _SecondTex).xyz);
                    
                    cnt2 += f1 + f2;
                    cnt += fact;
                }
                // 归一化
                col /= cnt * 2.5;
                col2 /= cnt2 * 1.65;
                
                // 调整轮廓和颜色
                col = clamp(clamp(col * .9 + .1, 0., 1.) * col2, 0., 1.);
                // 纸张颜色和纹理
                col = col * float3(.93, 0.93, 0.85) * lerp(tex2D(_PaperTex, i.uv).rgb, float3(1.2, 1.2, 1.2), .7)
                    + .15 * getRand(pos0 * 2.5, _SecondTex).r;
                // 晕影效果
                float r = length((i.uv - 0.5 * _ScreenParams.xy) / _ScreenParams.x);
                float vign = 1. - r * r * r * r;
                
                // 设置颜色并输出
                return fixed4(col * vign, 1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
