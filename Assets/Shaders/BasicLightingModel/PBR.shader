Shader "BasicLightingModel/PBR"
{
    Properties
    {
        [Header(Base)]
        _BaseColor ("Base Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _BaseMap ("Base Map", 2D) = "white" {}

        [Enum(UnityEngie.Rendering.CullMade)] _Cull ("Cull", Float) = 2 
        [Enum(UnityEngie.Rendering.BlendMade)] _SrcBlend ("Src Blend", Float) = 1 
        [Enum(UnityEngie.Rendering.BlendMade)] _DstBlend ("Dst Blend", Float) = 0 

        [Toggle(_UseNormal)] _UseNormal ("Use Normal", Float) = 0
        _NormalMap ("Normal Map", 2D) = "bump" {}

        [Header(Metallic)]
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.2
        _MetallicMap ("Metallic Map", 2D) = "white" {}

        [Header(Roughness)]
        _Roughness ("Roughness", Range(0.0, 1.0)) = 0.1
        _RoughnessMap ("Roughness", 2D) = "white" {}

        _AO ("AO", 2D) = "white" {}
        [Toggle(_UseEmissive)] _UseEmissive ("Use Emissive", Float) = 0
        _EmissiveMap ("Emissive Map", 2D) = "white" {}

        _LUT ("LUT", 2D) = "white" {}
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
            #pragma shader_feature_local_fragment _UseEmissive

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #define HALF_MIN_SQRT 0.0078125
			#define HALF_MIN 6.103515625e-5

            CBUFFER_START(UnityPerMateials)
            half4 _BaseColor;
            float4 _BaseMap_ST;

            half _Metallic;

            half _Roughness;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            TEXTURE2D(_NormalMap);
            TEXTURE2D(_MetallicMap);
            TEXTURE2D(_RoughnessMap);
            TEXTURE2D(_AO);
            TEXTURE2D(_EmissiveMap);
            TEXTURE2D(_LUT);
            
            SAMPLER(sampler_BaseMap);
            SAMPLER(sampler_NormalMap);
            SAMPLER(sampler_MetallicMap);
            SAMPLER(sampler_RoughnessMap);
            SAMPLER(sampler_AO);
            SAMPLER(sampler_EmissiveMap);
            SAMPLER(sampler_LUT);

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
                float3 bitangentWS  : TEXCOORD4;
            };

            half3 mon2lin(half3 c)
            {
                c /= c + 1;
                return pow(c, 1.0 / 2.2);
            }

            half Pow5(half x)
            {
                return x * x * x * x * x;
            }

            half3 SchlickFresnel(half3 F0, half NdotH)
            {
                return F0 + (1 - F0) * Pow5(1 - NdotH);
            }

            half GTR_1(half alpha, half NdotH)
            {
                half alpha2 = alpha;
                half NdotH2 = NdotH * NdotH;

                half d = NdotH * (alpha2 - 1) + 1;

                return (alpha2 - 1) / (d * log(alpha2));
            }

            half GTR_2(half alpha, half NdotH)
            {
                half alpha2 = alpha;
                half NdotH2 = NdotH * NdotH;

                half d = NdotH * (alpha2 - 1) + 1;

                return alpha2 / (d * d);
            }

            half3 DisneyDiffuse(half3 albode, half r, half NdotV, half NdotL, half LdotH)
            {
                half Fd90 = 0.5 + 2.0 * LdotH * LdotH * r;

                half v = 1 + (Fd90 - 1) * Pow5(1 - NdotV);
                half l = 1 + (Fd90 - 1) * Pow5(1 - NdotL);

                return albode * (v * l);
            }

            half3 SchlickFresnel_R(half3 F0, half alpha, half NdotV)
            {
                half3 a = 1 - alpha;
                return F0 + (max(a, F0) - F0) * Pow5(1 - NdotV);
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
                o.bitangentWS = nor.bitangentWS;
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);

                return o;
            }

            half4 frag(VertexOut i) : SV_TARGET
            {
                Light mainLight = GetMainLight();

                #if _UseNormal
                    half3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv));
                    half3x3 tangentToWorld = half3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                    i.normalWS = TransformTangentToWorld(bump, tangentToWorld);
                #endif

                half3 N = normalize(i.normalWS);
                half3 L = normalize(mainLight.direction);
                half3 V = normalize(GetWorldSpaceViewDir(i.posWS));
                half3 H = normalize(V + L);

                half NdotH = saturate(dot(N, H));
                half NdotV = saturate(dot(N, V));
                half NdotL = saturate(dot(N, L));
                half LdotH = saturate(dot(L, H));

                half3 albode = _BaseColor.rgb * SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half R = _Roughness * SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, i.uv).g;

                half alpha = max(R * R, HALF_MIN_SQRT);
                half alpha2 = max(alpha * alpha, HALF_MIN);
                half M = _Metallic * SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, i.uv).b;

                half3 F0 = lerp(0.04, albode, M);
                half3 ks = lerp(kDieletricSpec.rgb, albode, M);

                half D = GTR_2(alpha2, NdotH);
                half GF = 1 / (LdotH * LdotH * alpha + 0.5);
                half3 specular = albode * ks * D * GF;

                half kd = (1 - ks) * (1 - M);
                half3 diffuse = kd * DisneyDiffuse(albode, R, NdotV, NdotL, LdotH);

                half3 ambient_ibl = SampleSH(N);
                half3 iblDiffuse = albode * ambient_ibl * kd;

                half mip_r = R * (1.7 - 0.7 * R);
                half3 refDir = reflect(-V, N);
                half mip = mip_r * UNITY_SPECCUBE_LOD_STEPS;
                half4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, refDir, mip);

                half3 iblSpecular = albode * DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);
                float surfaceReduction = 1.0 / (alpha + 1.0);
				float grazingTerm = saturate(2 - R - kd);
				float fresnelTerm = pow(1.0 - NdotV, 4);
				half3 iblBrdf = surfaceReduction * lerp(ks, grazingTerm, fresnelTerm);

                half envUV = half2(lerp(0,0.9,NdotV), lerp(0, 0.9, alpha));
                half2 env = SAMPLE_TEXTURE2D(_LUT, sampler_LUT, envUV).rg;

                iblSpecular = iblSpecular * (ks * env.x + env.y);
                half3 iblResult = iblDiffuse + iblSpecular;
                
                half3 c = mainLight.color * (specular + diffuse) * NdotL + iblResult; //(diffuse + specular) * NdotL + iblResult
                c = c * SAMPLE_TEXTURE2D(_AO, sampler_AO, i.uv);
                
                #if _UseEmissive
                    c += 50 * c * SAMPLE_TEXTURE2D(_EmissiveMap, sampler_EmissiveMap, i.uv);
                #endif

                //c = R;
                //c = iblSpecular;
                //c /= c + 1.0;
                //c = pow(c, 1.0 / 2.2);

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
