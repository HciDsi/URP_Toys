Shader "BasicLightingModel/Test"
{
    Properties
    {
        [Header(Base)]
        _BaseColor ("Base Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _BaseMap ("Base Map", 2D) = "white" {}

        _ShadowRamp ("Shadow Ramp", 2D) = "while" {}
        _ShadowSampleStep ("Shadow Sample Step", Range(1.0, 20.0)) = 5.0

        [Enum(UnityEngie.Rendering.CullMade)] _Cull ("Cull", Float) = 2 
        [Enum(UnityEngie.Rendering.BlendMade)] _SrcBlend ("Src Blend", Float) = 1 
        [Enum(UnityEngie.Rendering.BlendMade)] _DstBlend ("Dst Blend", Float) = 0 
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "Forward"
            Tags {"LightMode"="UniversalForward"}

            Cull [_Cull]
            ZWrite On
            Blend [_SrcBlend] [_DstBlend]

            HLSLPROGRAM

            #pragma shader_feature_local_fragment _UseNormal

            #pragma vertex vert
            #pragma fragment frag

            #define MAIN_LIGHT_CALCULATE_SHADOWS  //定义阴影采样

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #define NUM_SAMPLES 20
            #define NUM_RINGS 10

            CBUFFER_START(UnityPerMateials)
            half4 _BaseColor;
            float4 _BaseMap_ST;

            half _ShadowSampleStep;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            
            TEXTURE2D(_ShadowRamp);
            SAMPLER(sampler_ShadowRamp);

            struct VertexIn
            {
                float4 pos      : POSITION;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
                float2 uv       : TEXCOORD;
            };

            struct VertexOut
            {
                float4 pos          : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 posWS        : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 tangentWS    : TEXCOORD3;
                float3 bitangent    : TEXCOORD4;
            };

            half2 poissonDisk[NUM_SAMPLES];

            half rand_1to1(half x) {
                return frac(sin(x) * 10000.0);
            }

            half rand_2to1(half2 uv) {
                // 0 - 1
                const half a = 12.9898;
                const half b = 78.233;
                const half c = 43758.5453;
                half dt = dot(uv.xy, half2(a, b));
                half sn = fmod(dt, PI); 
                return frac(sin(sn) * c);
            }

            void poissonDiskSamples(half2 randomSeed) {
                half PI2 = 6.28318530718; // 2 * PI
                half ANGLE_STEP = 2 * PI * half(NUM_RINGS) / half(NUM_SAMPLES);
                half INV_NUM_SAMPLES = 1.0 / half(NUM_SAMPLES);

                half angle = rand_2to1(randomSeed) * PI2;
                half radius = INV_NUM_SAMPLES;
                half radiusStep = radius;

                for (int i = 0; i < NUM_SAMPLES; i++) {
                    poissonDisk[i] = half2(cos(angle), sin(angle)) * pow(radius, 0.75);
                    radius += radiusStep;
                    angle += ANGLE_STEP;
                }
            }

            void uniformDiskSamples(half2 randomSeed) {
                half PI2 = 6.28318530718; // 2 * PI

                half randNum = rand_2to1(randomSeed);
                half sampleX = rand_1to1(randNum);
                half sampleY = rand_1to1(sampleX);

                half angle = sampleX * PI2;
                half radius = sqrt(sampleY);

                for (int i = 0; i < NUM_SAMPLES; i++) {
                    poissonDisk[i] = half2(radius * cos(angle), radius * sin(angle));

                    sampleX = rand_1to1(sampleY);
                    sampleY = rand_1to1(sampleX);

                    angle = sampleX * PI2;
                    radius = sqrt(sampleY);
                }
            }


            half PCF(half4 coord)
            {
                uniformDiskSamples(coord.xy);
                half shadowAtton = 0;
                half size = _ShadowSampleStep / 2048;
                for(int i = 0; i < NUM_SAMPLES; i++)
                {
                    half temp = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, half3(coord.xy + poissonDisk[i] * size, coord.z));
                    if(temp > coord.z + 0.1)
                    {
                        shadowAtton += 1.0;
                    }
                }

                return shadowAtton / 20.0;
            }

            half PCSS()
            {
                return 0;
            }

            half3 SoftShadow(half3 pos)
            {
                half4 shadowCoord = TransformWorldToShadowCoord(pos);
                half shadowAtton = PCF(shadowCoord);
                shadowAtton = lerp(0.1, 0.8, shadowAtton);
                half3 c = SAMPLE_TEXTURE2D(_ShadowRamp, sampler_ShadowRamp, half2(shadowAtton, 0.5));
                return c;
            }
            
            VertexOut vert(VertexIn v)
            {
                VertexPositionInputs pos = GetVertexPositionInputs(v.pos.xyz);
                VertexNormalInputs nor = GetVertexNormalInputs(v.normal, v.tangent);

                VertexOut o;
                o.pos = pos.positionCS;
                o.posWS = pos.positionWS;
                o.normalWS = nor.normalWS;
                o.tangentWS = nor.tangentWS;
                o.bitangent = nor.bitangentWS;
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);

                return o;
            }

            half4 frag(VertexOut i) : SV_TARGET
            {
                Light mainLight = GetMainLight();

                half3 L = normalize(mainLight.direction);
                half3 V = normalize(GetWorldSpaceViewDir(i.posWS));
                half3 N = normalize(i.normalWS);
                half3 H = normalize(V + L);

                half NdotH = saturate(dot(N, H));
                half NdotL = saturate(dot(N, L));

                half3 diffuse = _BaseColor.rgb * NdotL;
                half3 specular = pow(NdotH, 64);

                half3 shadowAtton = SoftShadow(i.posWS);

                half3 c = diffuse + specular + _BaseColor.rgb * 0.05;
                c *= shadowAtton;

                return half4(c, 1.0);
            }

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"

            ENDHLSL
        }
    
    }

}
