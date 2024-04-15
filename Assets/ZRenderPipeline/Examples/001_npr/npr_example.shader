Shader "ZPipeline/ZUniversal/NPR/npr_example"
{
    Properties 
    {
        [GroupDrawer] BaseGroup ("基础", Float) = 1
        [SubGroupDrawer(BaseGroup)] _BaseMap   ("基础贴图", 2D) = "white" {}
        [SubGroupDrawer(BaseGroup)] _BaseColor ("基础颜色", Color) = (0, 0.66, 0.73, 1)



        [GroupDrawer] OutlineGroup ("描边", Float) = 1
        [SubGroupDrawer(OutlineGroup)] _OutlineWidth   ("描边宽度", Range(0, 1)) = 0.01
        [SubGroupDrawer(OutlineGroup)] _EnableFOVWidth ("投影校正", Range(0, 1)) = 1
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
            float2 uv         : TEXCOORD0;
            float4 color      : COLOR;
        };

        TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

        v2f vert(a2v v) 
        {
            float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
            float3 positionVS = TransformWorldToView(positionWS.xyz);

            v2f o;
                o.positionWS = positionWS;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.color = v.color;
            return o;
        }

        FRAGMENT_MRT(frag,v2f,i)
        //half4 frag(v2f i) : SV_Target 
        {
            half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);

            SET_SCENE_COLOR(baseMap * _BaseColor);
        }

        v2f vert_outline(a2v v) 
        {
            float3 outline_normal;
            outline_normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.tangent.xyz);
            outline_normal.z = -0.1;
            outline_normal.xyz = normalize(outline_normal.xyz);

            float4 position_vs = mul(UNITY_MATRIX_MV, v.positionOS);

            float fov_width = 1.0f / (rsqrt(abs(position_vs.z / unity_CameraProjection._m11)));
            if(_EnableFOVWidth == 0) fov_width = 1;

            position_vs.xyz = position_vs + (outline_normal * fov_width * (v.color.a * _OutlineWidth));

            v2f o;
                o.positionCS = mul(UNITY_MATRIX_P, position_vs);
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
            return o;
        }

        half4 frag_outline(v2f i) : SV_Target 
        {
            half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);

            return baseMap * 0.4;
        }


        ENDHLSL

        Pass 
        {
            Tags { "LightMode" = "ZCharacters" }

            Cull Off
            //ZTest Equal

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }

        Pass 
        {
            Tags { "LightMode" = "ZOutline" }
            Cull Front

            HLSLPROGRAM
            #pragma vertex vert_outline
            #pragma fragment frag_outline
            ENDHLSL
        }

        //Pass 
        //{
        //    Tags { "LightMode" = "ZPreDepth" }

        //    ColorMask 0
        //    Cull Off

        //    HLSLPROGRAM
        //    #pragma vertex vert_pre_depth
        //    #pragma fragment frag_pre_depth
        //    ENDHLSL
        //}
    }
}
