Shader "ZPipeline/ZUniversal/Examples/example_sample_spherical_map"
{
    Properties 
    {
        [GroupDrawer] BaseGroup ("基础", Float) = 1
        [SubGroupDrawer(BaseGroup)] _BaseMap   ("基础贴图", 2D) = "white" {}
        [SubGroupDrawer(BaseGroup)] _BaseColor ("基础颜色", Color) = (0, 0.66, 0.73, 1)

        [SubGroupDrawer(BaseGroup)] _CubeMap ("CubeMap", Cube) = "" {}
    }
    SubShader 
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Assets/ZRenderPipeline/Shaders/environment/z_obj_mrt.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        float4 _BaseColor;

        float _OutlineWidth;
        float _EnableFOVWidth;
        CBUFFER_END

        #define OUTLINE_VIEW_OFFSET 0.01

        struct a2v 
        {
            float4 positionOS : POSITION;
            float2 uv         : TEXCOORD0;
            float4 color      : COLOR;

            float3 normal     : NORMAL;
            float4 tangent    : TANGENT;
        };

        struct v2f 
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD1;
            float3 positionOS : TEXCOORD2;
            float2 uv         : TEXCOORD0;
            float4 color      : COLOR;
        };

        Texture2D _BaseMap; SamplerState sampler_BaseMap;
        TextureCube _CubeMap; SamplerState sampler_CubeMap;

        static float2 invAtan = float2(0.1591, 0.3183);
        float2 SampleSphericalMap(float3 v)
        {
            float2 uv = float2(atan2(v.z, v.x), asin(v.y));
            uv *= invAtan;
            uv += 0.5;
            return uv;
        }


        v2f vert(a2v v) 
        {
            float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
            float3 positionVS = TransformWorldToView(positionWS.xyz);

            v2f o;
                o.positionOS = v.positionOS.xyz;
                o.positionWS = positionWS;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.color = v.color;
            return o;
        }

        FRAGMENT_MRT(frag, v2f, i)
        {
            INITIALIZE_GBUFFERS(0);

            float2 uv = SampleSphericalMap(normalize(i.positionOS)); // make sure to normalize localPos

            half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);

            SET_SCENE_COLOR(baseMap * _BaseColor);
        }


        ENDHLSL

        Pass 
        {
            Tags { "LightMode" = "ZUniversal" }

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
            ENDHLSL
        }
    }
}
