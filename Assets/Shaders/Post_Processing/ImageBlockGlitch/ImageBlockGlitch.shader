Shader "Post/ImageBlockGlitch"
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

            sampler2D _MainTex; // 主纹理
            float4 _MainTex_ST; // 纹理坐标转换矩阵

            // 定义参数
            #define SPEED (10.1) // 噪声函数的速度
            #define _Fade (1.0) // 淡入淡出效果的参数
            #define _Offset (10.0) // 故障效果的偏移量

            #define _BlockLayer1_U (5.0) // 第一层块状效果的U方向数量
            #define _BlockLayer1_V (9.5) // 第一层块状效果的V方向数量

            #define _BlockLayer2_U (15.0) // 第二层块状效果的U方向数量
            #define _BlockLayer2_V (15.0) // 第二层块状效果的V方向数量

            #define _BlockLayer1_Indensity (6.0) // 第一层块状效果的强度
            #define _BlockLayer2_Indensity (4.0) // 第二层块状效果的强度

            #define _RGBSplit_Indensity (4.0) // RGB分离的强度

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

            // 随机噪声函数
            float randomNoise(float2 seed)
            {
                return frac(sin(dot(seed * floor(_Time.y * SPEED), float2(127.13, 311.71))) * 43758.5453123);
            }

            // 重载的随机噪声函数
            float randomNoise(float seed)
            {
                return randomNoise(float2(seed, 1.0));
            }

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

                float2 blockLayer1 = floor(uv * float2(_BlockLayer1_U, _BlockLayer1_V)); // 计算第一层块状效果的坐标
                float2 blockLayer2 = floor(uv * float2(_BlockLayer2_U, _BlockLayer2_V)); // 计算第二层块状效果的坐标

                float lineNoise1 = pow(randomNoise(blockLayer1), _BlockLayer1_Indensity); // 第一层块状效果的噪声
                float lineNoise2 = pow(randomNoise(blockLayer2), _BlockLayer2_Indensity); // 第二层块状效果的噪声
                float RGBSplitNoise = pow(randomNoise(5.1379), 7.1) * _RGBSplit_Indensity; // RGB分离的噪声
                float lineNoise = lineNoise1 * lineNoise2 * _Offset - RGBSplitNoise; // 整体的噪声

                float4 colR = tex2D(_MainTex, uv); // 红色通道
                float4 colG = tex2D(_MainTex, uv + float2(lineNoise * 0.05 * randomNoise(7.0), 0.0)); // 绿色通道
                float4 colB = tex2D(_MainTex, uv - float2(lineNoise * 0.05 * randomNoise(23.0), 0.0)); // 蓝色通道
                
                float4 re = float4(float3(colR.r, colG.g, colB.b), colR.a + colG.a + colB.a); // 合成颜色
                re = lerp(colR, re, _Fade); // 应用淡入淡出效果
                return re; // 返回颜色
            }
            ENDCG
        }
    }
}
