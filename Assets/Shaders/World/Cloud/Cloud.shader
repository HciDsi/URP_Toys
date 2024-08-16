Shader "World/Cloud"
{
    Properties
    {
        _MainTex ("Main Tex", 2D) = "white"
    }
    SubShader
    {
        Cull Off 
        ZWrite Off 
        ZTest Always

        Pass
        {
            HLSLPROGRAM

            #pragma shader_feature_local_fragment _UseNormal

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            CBUFFER_START(UnityPerMateials)
            float4 _MainTex_ST;

            half _Density;

            half _LightAbsorptionTowardSun;
            half _DarknessThreshold;
            half4 _CloudColor1;
            half _ColorOffset1;
            half4 _CloudColor2;
            half _ColorOffset2;
            
            half _3DNoiseTilling;
            half _3DNoiseOffset;
    
            half4 _PhasePamas;

            half4 _BlueNoiseUV;
            half _BlueIntensity;
    
            half4x4 _InvProj;
            half4x4 _InvView;
    
            half3 _BoundMax;
            half3 _BoundMin;

            half4 _ShapeNoiseWeights;
            half _DensityOffset;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE3D(_3DNoise);
            SAMPLER(sampler_3DNoise);

            TEXTURE2D(_WeatherTex);
            SAMPLER(sampler_WeatherTex);

            TEXTURE2D(_BlueNoise);
            SAMPLER(sampler_BlueNoise);

            struct VertexIn
            {
                float4 pos      : POSITION;
                float2 uv       : TEXCOORD;
            };

            struct VertexOut
            {
                float4 pos          : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            half3 GetWorldPos(half depth, half2 uv)
            {
                half4 view = mul(_InvProj, half4(uv * 2.0 - 1.0, depth, 1.0));
                view.xyz /= view.w;
                half4 world = mul(_InvView, half4(view.xyz, 1.0));

                return world.xyz;
            }

            half2 RayBoxDst(half3 pos, half3 invRayDir)
            {
                half3 t1 = (_BoundMin - pos) * invRayDir;
                half3 t2 = (_BoundMax - pos) * invRayDir;
                half3 tMin = min(t1, t2);
                half3 tMax = max(t1, t2);

                half dstA = max(tMin.x, max(tMin.y, tMin.z));
                half dstB = min(tMax.x, min(tMax.y, tMax.z));

                half dstToBox = max(0.0, dstA);
                half dstInsideBox = max(0.0, dstB - dstToBox);

                return half2(dstToBox, dstInsideBox);
            }

            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
            {
                return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
            }

            half SampleNoise(half3 pos)
            {
                // 计算云体积包围盒的中心点
                float3 boundsCentre = (_BoundMax + _BoundMin) * 0.5;
                // 计算包围盒的大小
                float3 size = _BoundMax - _BoundMin;
                // 获取时间和速度的组合值，用于动画效果
                float speedShape = _Time.y * 0.2;
                float speedDetail = _Time.y * 0.2;

                // 计算用于形状噪声的3D纹理坐标
                float3 uvwShape  = pos * _3DNoiseTilling * 0.1;// + float3(speedShape, speedShape * 0.2, 0);
                // 计算用于细节噪声的3D纹理坐标
                float3 uvwDetail = pos * _3DNoiseTilling;// + float3(speedDetail, speedDetail * 0.2, 0);

                 // 计算用于2D纹理采样的UV坐标
                float2 uv = (size.xz * 0.5f + (pos.xz - boundsCentre.xz)) / max(size.x, size.z);

                float4 weatherMap = SAMPLE_TEXTURE2D(_WeatherTex, sampler_WeatherTex, uv);
                float heightPercent = (pos.y - _BoundMin.y) / size.y;//计算一个梯度值
                float heightGradient = saturate(remap(heightPercent, 0.0, weatherMap.r, 1, 0));

                float4 shapeNoise = SAMPLE_TEXTURE3D_LOD(_3DNoise, sampler_3DNoise, uvwShape, 0);
                float4 normalizedShapeWeights = _ShapeNoiseWeights / dot(_ShapeNoiseWeights, 1);
                float shapeFBM = dot(shapeNoise, normalizedShapeWeights) ;
                float baseShapeDensity = shapeFBM + _DensityOffset * 0.01;
                
                return baseShapeDensity * heightGradient;
            }

            half3 LightMarching(half3 pos)
            {
                int SampleSize = 8;

                Light l = GetMainLight();
                half3 dir = l.direction;
                half dstInsideBox = RayBoxDst(pos, 1 / dir).y;
                half rayStep = dstInsideBox / SampleSize;

                half d = 0;
                for(int i = 0; i < SampleSize; i++)
                {
                    d += max(0.0, SampleNoise(pos + i * rayStep * dir));
                }
                half temp = exp(-d * _LightAbsorptionTowardSun * 0.000001);
                
                half3 c = lerp(_CloudColor1, l.color, saturate(temp * _ColorOffset1));
                c = lerp(_CloudColor2, c, saturate(pow(temp * _ColorOffset2, 3)));

                return _DarknessThreshold + (1 - _DarknessThreshold) * temp * c;
            }

            half Hg(half g, half a)
            {
                half g2 = g * g;
                return (1 - g2) / (4.0 * PI * pow(1.0 + g2 - g * a * 2.0, 1.5));
            }
            half Phase(half a)
            {
                half blend = 0.5;
                half hgblend = (1 - blend) * Hg(_PhasePamas.x, a) + blend * Hg(-_PhasePamas.y, a);
                return _PhasePamas.z + hgblend * _PhasePamas.w;
            }

            half4 RayMarching(half rayStep, half dstLimit, half3 pos, half3 dir)
            {
                //rayStep = 0.1;
                half density = 1;
                half3 cloudColor = 0;

                half rayL = 0;

                half VdotL = saturate(dot(dir, GetMainLight().direction));
                half phaseVal = Phase(VdotL);

                for(int i = 0; i < 16; i++)
                {
                    if(rayL < dstLimit)
                    {
                        half3 posT = pos + rayL * dir;
                        half d = SampleNoise(posT);

                        if(d > 0)
                        {
                            cloudColor += d * rayStep * density * LightMarching(posT) * phaseVal;
                            density *= exp(-d * rayStep * 0.001);
                            if(density < 0.01)
                                break;
                        }
                    }

                    rayL += rayStep;
                }

                return half4(cloudColor, density);
            }

            VertexOut vert(VertexIn v)
            {
                VertexPositionInputs pos = GetVertexPositionInputs(v.pos.xyz);
                
                VertexOut o;
                o.pos = pos.positionCS;
                
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            half4 frag(VertexOut i) : SV_TARGET
            {
                half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                half depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv).r;
                half3 posW = GetWorldPos(depth, i.uv);
                half3 posV = _WorldSpaceCameraPos;
                half3 V = normalize(posW - posV);

                half rayEyeLinear = length(posW - posV);
                half2 dst = RayBoxDst(posV, 1 / V);
                half dstToBox = dst.x;
                half dstInsideBox = dst.y;
                half dstLimit = min(dstInsideBox, rayEyeLinear - dstToBox);

                half blueNoise = SAMPLE_TEXTURE2D(_BlueNoise, sampler_BlueNoise, i.uv * _BlueNoiseUV.xy + _BlueNoiseUV.zw).r * _BlueIntensity;

                half4 cloud = RayMarching(_Density * 2 + blueNoise, dstLimit, posV + dstToBox * V, V);

                c = half4(c.rgb * cloud.a + cloud.rgb, 1.0);

                return c;
            }

            ENDHLSL
        }
    }
}
