Shader "ZPipeline/ZUniversal/Examples/example_ssr_object"
{
    Properties 
    {
        [GroupDrawer] BaseGroup ("基础", Float) = 1
        //[SubGroupDrawer(BaseGroup)] _BaseMap   ("基础贴图", 2D) = "white" {}
        [SubGroupDrawer(BaseGroup)] _BaseColor ("基础颜色", Color) = (0, 0.66, 0.73, 1)
        [SubGroupDrawer(BaseGroup)] _Roughness ("粗糙度", Range(0.0, 1.0)) = 0.5
        [SubGroupDrawer(BaseGroup)] _Metallic  ("金属度", Range(0.0, 1.0)) = 0.0
    }
    SubShader 
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Assets/ZRenderPipeline/Shaders/environment/z_obj_mrt.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;

            float _Roughness;
            float _Metallic;
        CBUFFER_END

        #define OUTLINE_VIEW_OFFSET 0.01

        struct a2v 
        {
            float4 positionOS : POSITION;
            float3 normal     : NORMAL;
            float4 tangent    : TANGENT;
        };

        struct v2f 
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD1;
            float3 positionOS : TEXCOORD2;
            float3 normal     : TEXCOORD3;
        };

        Texture2D _BaseMap; SamplerState sampler_BaseMap;


        v2f vert(a2v v) 
        {
            float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
            float3 positionVS = TransformWorldToView(positionWS.xyz);

            v2f o;
                o.positionOS = v.positionOS.xyz;
                o.positionWS = positionWS;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.normal     = TransformObjectToWorldNormal(v.normal);
            return o;
        }

        FRAGMENT_MRT(frag, v2f, i)
        {
            INITIALIZE_GBUFFERS(0);

            SET_SCENE_COLOR(float4(i.positionWS, 0));

            SET_GBUFFER_A(float4(i.normal * 0.5 + 0.5, 0.0));
            SET_GBUFFER_B(float4(_Metallic, 0.0, _Roughness, 0.0));
            SET_GBUFFER_C(_BaseColor);
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
