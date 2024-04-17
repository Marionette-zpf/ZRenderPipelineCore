Shader "ZPipeline/ZUniversal/PPS/SSR"
{
	HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"

	#include "Assets/ZRenderPipeline/ShaderLibrary/Platform.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/TextureSampling.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/Common.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/BlitCommon.hlsl"
    #include "Assets/ZRenderPipeline/ShaderLibrary/Input.hlsl"
    #include "Assets/ZRenderPipeline/ShaderLibrary/DeferredShadingCommon.hlsl"


    void ScreenSpaceReflections(float4 SvPosition, out float4 OutColor)
    {
        float2 UV = SvPosition.xy * _V_BufferSizeAndInvSize.zw;
        float2 ScreenPos = ViewportUVToScreenPos(UV);

        uint2 PixelPos = (uint2)SvPosition.xy;

        OutColor = 0;

	    ZGBufferData GBuffer = ZGetGBufferDataFromSceneTextures(UV);

	    float3 N = GBuffer.WorldNormal;
	    const float SceneDepth = GBuffer.Depth;
	    const float3 PositionTranslatedWorld = mul(_M_ScreenToTranslatedWorldMatrix, float4( ScreenPos * SceneDepth, SceneDepth, 1 ) ).xyz;
	    const float3 V = normalize(-PositionTranslatedWorld);

        OutColor.rgb = V;

    }

	void frag_ssr(v2f input, out float4 OutColor : SV_Target0)
	{
    	ScreenSpaceReflections(input.positionCS, OutColor);
	}

    ENDHLSL

    SubShader
    {
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "Down Sample"

            HLSLPROGRAM
                #pragma vertex   vert_blit
                #pragma fragment frag_ssr
            ENDHLSL
        }
    }
}
