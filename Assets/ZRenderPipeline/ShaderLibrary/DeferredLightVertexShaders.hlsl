#ifndef Z_RENDER_PIPELINE_DEFERRED_LIGHT_VERTEX_SHADER_INCLUDE
#define Z_RENDER_PIPELINE_DEFERRED_LIGHT_VERTEX_SHADER_INCLUDE

#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/Common.hlsl"

/** Vertex shader for rendering a directional light using a full screen quad. */
void DirectionalVertexMain(
	in float2 InPosition : POSITION,
	in float2 InUV       : Texcoord0,
	out float2 OutTexCoord : TEXCOORD0,
	out float3 OutScreenVector : TEXCOORD1,
	out float4 OutPosition : SV_POSITION
	)
{	
	DrawRectangle(float4(InPosition.xy, 0, 1), InUV, OutPosition, OutTexCoord);
	OutScreenVector = mul(_View_ScreenToTranslatedWorld, float4(OutPosition.x, -OutPosition.y, 1, 0)).xyz;
}


#endif