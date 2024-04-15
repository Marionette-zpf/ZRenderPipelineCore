#ifndef Z_RENDER_PIPELINE_SCENE_TEXTURE_COMMON_INCLUDE
#define Z_RENDER_PIPELINE_SCENE_TEXTURE_COMMON_INCLUDE

#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/Common.hlsl"


#define SceneTexturesStruct_SceneColorTextureSampler sampler_PointClamp
#define SceneTexturesStruct_SceneDepthTextureSampler sampler_PointClamp
#define SceneTexturesStruct_CustomDepthTextureSampler sampler_PointClamp
#define SceneTexturesStruct_GBufferATextureSampler sampler_PointClamp
#define SceneTexturesStruct_GBufferBTextureSampler sampler_PointClamp
#define SceneTexturesStruct_GBufferCTextureSampler sampler_PointClamp
#define SceneTexturesStruct_GBufferDTextureSampler sampler_PointClamp
#define SceneTexturesStruct_GBufferETextureSampler sampler_PointClamp
#define SceneTexturesStruct_GBufferFTextureSampler sampler_PointClamp
#define SceneTexturesStruct_GBufferVelocityTextureSampler sampler_PointClamp
#define SceneTexturesStruct_ScreenSpaceAOTextureSampler sampler_PointClamp

/** Returns DeviceZ which is the z value stored in the depth buffer. */
float LookupDeviceZ( float2 ScreenUV )
{
	// native Depth buffer lookup
	return Texture2DSampleLevel(_SceneTexturesStruct_SceneDepthTexture, SceneTexturesStruct_SceneDepthTextureSampler, ScreenUV, 0).r;
}

/** Returns clip space W, which is world space distance along the View Z axis. Note if you need DeviceZ LookupDeviceZ() is the faster option */
float CalcSceneDepth(float2 ScreenUV)
{
	return ConvertFromDeviceZ(LookupDeviceZ(ScreenUV));
}

#endif