Shader "Post/Fisheye"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float _Value;
            float _Radius;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv; // 获取纹理坐标

                float ratio = _ScreenParams.x / _ScreenParams.y; // 计算屏幕宽高比
                float value = _Value;
                float radius = _Radius;

                float2 uv2 = uv;
                float2 uv3 = uv;
                uv3 -= .5;
                float2 scale = float2(1, 1);
                if (ratio < 1.) {
                    scale.x *= ratio;
                } else {
                    scale.y /= ratio;
                }
                uv3 *= scale;
                uv3 += .5;

                float2 center = float2(.5, .5); // 扭曲中心点坐标
                float2 d = uv3 - center; // 计算与中心点的距离向量
                float r0 = sqrt(dot(center, center)); // 计算中心点到原点的距离
                float r = sqrt(dot(d, d)); // 计算当前像素点到中心点的距离

                float power = (2.0 * 3.141592 / (2.0 * r0)) * (value - 0.5); // 计算扭曲的功率

                float bind = lerp(r0, lerp(center.x, center.y, step(1., ratio)), step(power, 0.)); // 计算绑定的半径

                if (power > 0.0) {
                    uv2 = center + lerp(normalize(d) * tan(r * power) * bind / tan(bind * power), d, smoothstep(0., radius, r)) * (1. / scale); // 根据扭曲的功率计算新的UV坐标
                } else if (power < 0.0) {
                    uv2 = center + lerp(normalize(d) * atan(r * -power * 10.0) * bind / atan(-power * bind * 10.0), d, smoothstep(0., radius, r)) * (1. / scale); // 根据扭曲的功率计算新的UV坐标
                }

                float4 col = tex2D(_MainTex, uv2); // 获取扭曲后的颜色值
                return col; // 返回颜色值
            }
            ENDCG
        }
    }
}
