Shader "BasicLightingModel/Tool"
{
    Properties
    {
        [Header(Base)]
        _BaseColor ("Base Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _BaseMap ("Base Map", 2D) = "white" {}

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

            #define MAIN_LIGHT_CALCULATE_SHADOWS  //定义阴影采样

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl" 

            CBUFFER_START(UnityPerMateials)
            half4 _BaseColor;
            float4 _BaseMap_ST;

            CBUFFER_END

            TEXTURE2D(_BaseMap);

            
            SAMPLER(sampler_BaseMap);


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

                half4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                half shadowAtten = MainLightRealtimeShadow(shadowCoord);

                half3 c = diffuse + specular + _BaseColor.rgb * 0.05;

                c *= shadowAtten;

                c /= c + 1.0;
                c = pow(c, 1.0 / 2.2);

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
