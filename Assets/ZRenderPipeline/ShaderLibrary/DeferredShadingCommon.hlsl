#ifndef Z_RENDER_PIPELINE_COMMON_DEFERRED_SHADING_COMMON_INCLUDE
#define Z_RENDER_PIPELINE_COMMON_DEFERRED_SHADING_COMMON_INCLUDE

#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/TextureSampling.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/Input.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/SceneTexturesCommon.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/ShadingCommon.hlsl"

float3 DecodeNormal( float3 N )
{
	return N * 2 - 1;
	//return OctahedronToUnitVector( Pack888To1212( N ) * 2 - 1 );
}

float3 DecodeBaseColor(float3 BaseColor)
{
	// we use sRGB on the render target to give more precision to the darks
	return BaseColor;
}

float DecodeIndirectIrradiance(float IndirectIrradiance)
{
#if USE_PREEXPOSURE
	const float OneOverPreExposure = View.OneOverPreExposure;
#else
	const float OneOverPreExposure = 1.f;
#endif

	// LogL -> L
	float LogL = IndirectIrradiance;
	const float LogBlackPoint = 0.00390625;	// exp2(-8);
	return OneOverPreExposure * (exp2( LogL * 16 - 8 ) - LogBlackPoint);	// 1 exp2, 1 smad, 1 ssub
}

float EncodeShadingModelIdAndSelectiveOutputMask(uint ShadingModelId, uint SelectiveOutputMask)
{
	uint Value = (ShadingModelId & SHADINGMODELID_MASK) | SelectiveOutputMask;
	return (float)Value / (float)0xFF;
}

uint DecodeShadingModelId(float InPackedChannel)
{
	return ((uint)round(InPackedChannel * (float)0xFF)) & SHADINGMODELID_MASK;
}

uint DecodeSelectiveOutputMask(float InPackedChannel)
{
	return ((uint)round(InPackedChannel * (float)0xFF)) & ~SHADINGMODELID_MASK;
}

bool UseSubsurfaceProfile(int ShadingModel)
{
	return ShadingModel == SHADINGMODELID_SUBSURFACE_PROFILE || ShadingModel == SHADINGMODELID_EYE;
}

bool HasCustomGBufferData(int ShadingModelID)
{
	return ShadingModelID == SHADINGMODELID_SUBSURFACE
		|| ShadingModelID == SHADINGMODELID_PREINTEGRATED_SKIN
		|| ShadingModelID == SHADINGMODELID_CLEAR_COAT
		|| ShadingModelID == SHADINGMODELID_SUBSURFACE_PROFILE
		|| ShadingModelID == SHADINGMODELID_TWOSIDED_FOLIAGE
		|| ShadingModelID == SHADINGMODELID_HAIR
		|| ShadingModelID == SHADINGMODELID_CLOTH
		|| ShadingModelID == SHADINGMODELID_EYE;
}

bool HasAnisotropy(int SelectiveOutputMask)
{
	return (SelectiveOutputMask & HAS_ANISOTROPY_MASK) != 0;
}


// all values that are output by the forward rendering pass
struct FGBufferData
{
	// normalized
	float3 WorldNormal;
	// normalized, only valid if HAS_ANISOTROPY_MASK in SelectiveOutputMask
	float3 WorldTangent;
	// 0..1 (derived from BaseColor, Metalness, Specular)
	float3 DiffuseColor;
	// 0..1 (derived from BaseColor, Metalness, Specular)
	float3 SpecularColor;
	// 0..1, white for SHADINGMODELID_SUBSURFACE_PROFILE and SHADINGMODELID_EYE (apply BaseColor after scattering is more correct and less blurry)
	float3 BaseColor;
	// 0..1
	float Metallic;
	// 0..1
	float Specular;
	// 0..1
	float4 CustomData;
	// Indirect irradiance luma
	float IndirectIrradiance;
	// Static shadow factors for channels assigned by Lightmass
	// Lights using static shadowing will pick up the appropriate channel in their deferred pass
	float4 PrecomputedShadowFactors;
	// 0..1
	float Roughness;
	// -1..1, only valid if only valid if HAS_ANISOTROPY_MASK in SelectiveOutputMask
	float Anisotropy;
	// 0..1 ambient occlusion  e.g.SSAO, wet surface mask, skylight mask, ...
	float GBufferAO;
	// 0..255 
	uint ShadingModelID;
	// 0..255 
	uint SelectiveOutputMask;
	// 0..1, 2 bits, use CastContactShadow(GBuffer) or HasDynamicIndirectShadowCasterRepresentation(GBuffer) to extract
	float PerObjectGBufferData;
	// in world units
	float CustomDepth;
	// Custom depth stencil value
	uint CustomStencil;
	// in unreal units (linear), can be used to reconstruct world position,
	// only valid when decoding the GBuffer as the value gets reconstructed from the Z buffer
	float Depth;
	// Velocity for motion blur (only used when WRITES_VELOCITY_TO_GBUFFER is enabled)
	float4 Velocity;

	// 0..1, only needed by SHADINGMODELID_SUBSURFACE_PROFILE and SHADINGMODELID_EYE which apply BaseColor later
	float3 StoredBaseColor;
	// 0..1, only needed by SHADINGMODELID_SUBSURFACE_PROFILE and SHADINGMODELID_EYE which apply Specular later
	float StoredSpecular;
	// 0..1, only needed by SHADINGMODELID_EYE which encodes Iris Distance inside Metallic
	float StoredMetallic;
};

struct FScreenSpaceData
{
	// GBuffer (material attributes from forward rendering pass)
	FGBufferData GBuffer;
	// 0..1, only valid in some passes, 1 if off
	float AmbientOcclusion;
};

// SubsurfaceProfile does deferred lighting with a checker board pixel pattern
// we separate the view from the non view dependent lighting and later recombine the two color constributions in a postprocess
// We have the option to apply the BaseColor/Specular in the base pass or do it later in the postprocess (has implications to texture detail, fresnel and performance)
void AdjustBaseColorAndSpecularColorForSubsurfaceProfileLighting(inout float3 BaseColor, inout float3 SpecularColor, inout float Specular, bool bChecker)
{
#if SUBSURFACE_CHANNEL_MODE == 0
	// If SUBSURFACE_CHANNEL_MODE is 0, we can't support full-resolution lighting, so we 
	// ignore View.bCheckerboardSubsurfaceProfileRendering
	const bool bCheckerboardRequired = _View_bSubsurfacePostprocessEnabled > 0;
#else
	const bool bCheckerboardRequired = _View_bSubsurfacePostprocessEnabled > 0 && _bCheckerboardSubsurfaceProfileRendering > 0;
	BaseColor = _bSubsurfacePostprocessEnabled ? float3(1, 1, 1) : BaseColor;
#endif

	if (bCheckerboardRequired)
	{
		// because we adjust the BaseColor here, we need StoredBaseColor

		// we apply the base color later in SubsurfaceRecombinePS()
		BaseColor = bChecker;
		// in SubsurfaceRecombinePS() does not multiply with Specular so we do it here
		SpecularColor *= !bChecker;
		Specular *= !bChecker;
	}
}


// High frequency Checkerboard pattern
// @param PixelPos relative to left top of the rendertarget (not viewport)
// @return true/false, todo: profile if float 0/1 would be better (need to make sure it's 100% the same)
bool CheckerFromPixelPos(uint2 PixelPos)
{
	// todo: Index is float and by staying float we can optimize this 
	// We alternate the pattern to get 2x supersampling on the lower res data to get more near to full res
	uint TemporalAASampleIndex = _View_TemporalAAParams.x;

#if FEATURE_LEVEL >= FEATURE_LEVEL_SM4
	return (PixelPos.x + PixelPos.y + TemporalAASampleIndex) % 2;
#else
	return (uint)(fmod(PixelPos.x + PixelPos.y + TemporalAASampleIndex, 2)) != 0;
#endif
}

// High frequency Checkerboard pattern
// @param UVSceneColor at pixel center
// @return true/false, todo: profile if float 0/1 would be better (need to make sure it's 100% the same)
bool CheckerFromSceneColorUV(float2 UVSceneColor)
{
	// relative to left top of the rendertarget (not viewport)
	uint2 PixelPos = uint2(UVSceneColor * _View_BufferSizeAndInvSize.xy);

	return CheckerFromPixelPos(PixelPos);
}


/** Populates FGBufferData */
// @param bChecker High frequency Checkerboard pattern computed with one of the CheckerFrom.. functions, todo: profile if float 0/1 would be better (need to make sure it's 100% the same)
FGBufferData DecodeGBufferData(
	float4 InGBufferA,
	float4 InGBufferB,
	float4 InGBufferC,
	float4 InGBufferD,
	float4 InGBufferE,
	float4 InGBufferF,
	float4 InGBufferVelocity,
	float CustomNativeDepth,
	uint CustomStencil,
	float SceneDepth,
	bool bGetNormalizedNormal,
	bool bChecker)
{
	FGBufferData GBuffer;

	GBuffer.WorldNormal = DecodeNormal( InGBufferA.xyz );
	if(bGetNormalizedNormal)
	{
		GBuffer.WorldNormal = normalize(GBuffer.WorldNormal);
	}

	GBuffer.PerObjectGBufferData = InGBufferA.a;  
	GBuffer.Metallic	= InGBufferB.r;
	GBuffer.Specular	= InGBufferB.g;
	GBuffer.Roughness	= InGBufferB.b;
	// Note: must match GetShadingModelId standalone function logic
	// Also Note: SimpleElementPixelShader directly sets SV_Target2 ( GBufferB ) to indicate unlit.
	// An update there will be required if this layout changes.
	GBuffer.ShadingModelID = DecodeShadingModelId(InGBufferB.a);
	GBuffer.SelectiveOutputMask = DecodeSelectiveOutputMask(InGBufferB.a);

	GBuffer.BaseColor = DecodeBaseColor(InGBufferC.rgb);

#if ALLOW_STATIC_LIGHTING
	GBuffer.GBufferAO = 1;
	GBuffer.IndirectIrradiance = DecodeIndirectIrradiance(InGBufferC.a);
#else
	GBuffer.GBufferAO = InGBufferC.a;
	GBuffer.IndirectIrradiance = 1;
#endif

	GBuffer.CustomData = HasCustomGBufferData(GBuffer.ShadingModelID) ? InGBufferD : 0;

	GBuffer.PrecomputedShadowFactors = !(GBuffer.SelectiveOutputMask & SKIP_PRECSHADOW_MASK) ? InGBufferE :  ((GBuffer.SelectiveOutputMask & ZERO_PRECSHADOW_MASK) ? 0 :  1);
	GBuffer.CustomDepth = ConvertFromDeviceZ(CustomNativeDepth);
	GBuffer.CustomStencil = CustomStencil;
	GBuffer.Depth = SceneDepth;

	GBuffer.StoredBaseColor = GBuffer.BaseColor;
	GBuffer.StoredMetallic = GBuffer.Metallic;
	GBuffer.StoredSpecular = GBuffer.Specular;

	FLATTEN
	if( GBuffer.ShadingModelID == SHADINGMODELID_EYE )
	{
		GBuffer.Metallic = 0.0;
#if IRIS_NORMAL
		GBuffer.Specular = 0.25;
#endif
	}

	// derived from BaseColor, Metalness, Specular
	{
		GBuffer.SpecularColor = ComputeF0(GBuffer.Specular, GBuffer.BaseColor, GBuffer.Metallic);

		//if (UseSubsurfaceProfile(GBuffer.ShadingModelID))
		//{
		//	AdjustBaseColorAndSpecularColorForSubsurfaceProfileLighting(GBuffer.BaseColor, GBuffer.SpecularColor, GBuffer.Specular, bChecker);
		//}

		GBuffer.DiffuseColor = GBuffer.BaseColor - GBuffer.BaseColor * GBuffer.Metallic;

		//#if USE_DEVELOPMENT_SHADERS
		//{
		//	// this feature is only needed for development/editor - we can compile it out for a shipping build (see r.CompileShadersForDevelopment cvar help)
		//	// 这个功能只在开发者/编辑器中需要使用，我们可以在打包构建中将其排除编译（参见r.CompileShadersForDevelopment cvar帮助文件）
		//	GBuffer.DiffuseColor = GBuffer.DiffuseColor * _DiffuseOverrideParameter.www + _DiffuseOverrideParameter.xyz;
		//	GBuffer.SpecularColor = GBuffer.SpecularColor * _SpecularOverrideParameter.w + _SpecularOverrideParameter.xyz;
		//}
		//#endif //USE_DEVELOPMENT_SHADERS
	}

	{
		bool bHasAnisoProp = HasAnisotropy(GBuffer.SelectiveOutputMask);

		GBuffer.WorldTangent = bHasAnisoProp ? DecodeNormal(InGBufferF.rgb) : 0;
		GBuffer.Anisotropy   = bHasAnisoProp ? InGBufferF.a * 2.0f - 1.0f   : 0;

		if (bGetNormalizedNormal && bHasAnisoProp)
		{
			GBuffer.WorldTangent = normalize(GBuffer.WorldTangent);
		}
	}

	GBuffer.Velocity = !(GBuffer.SelectiveOutputMask & SKIP_VELOCITY_MASK) ? InGBufferVelocity : 0;

	return GBuffer;
}


// @param UV - UV space in the GBuffer textures (BufferSize resolution)
FGBufferData GetGBufferData(float2 UV, bool bGetNormalizedNormal = true)
{
	float4 GBufferA = Texture2DSampleLevel(_SceneTexturesStruct_GBufferATexture,  sampler_PointClamp , UV, 0);
	float4 GBufferB = Texture2DSampleLevel(_SceneTexturesStruct_GBufferBTexture,  sampler_PointClamp , UV, 0);
	float4 GBufferC = Texture2DSampleLevel(_SceneTexturesStruct_GBufferCTexture,  sampler_PointClamp , UV, 0);
	float4 GBufferD = Texture2DSampleLevel(_SceneTexturesStruct_GBufferDTexture,  sampler_PointClamp , UV, 0);
	float CustomNativeDepth = Texture2DSampleLevel(_SceneTexturesStruct_CustomDepthTexture,  sampler_PointClamp , UV, 0).r;

	int2 IntUV = (int2)trunc(UV * _View_BufferSizeAndInvSize.xy);
	uint CustomStencil = _SceneTexturesStruct_CustomStencilTexture.Load(int3(IntUV, 0)).g ;

	float4 GBufferE = 1;
	float4 GBufferF = Texture2DSampleLevel(_SceneTexturesStruct_GBufferFTexture,  sampler_PointClamp , UV, 0);


	float4 GBufferVelocity = 0;


	float SceneDepth = CalcSceneDepth(UV);

	return DecodeGBufferData(GBufferA, GBufferB, GBufferC, GBufferD, GBufferE, GBufferF, GBufferVelocity, CustomNativeDepth, CustomStencil, SceneDepth, bGetNormalizedNormal, CheckerFromSceneColorUV(UV));
}

// @param UV - UV space in the GBuffer textures (BufferSize resolution)
FScreenSpaceData GetScreenSpaceData(float2 UV, bool bGetNormalizedNormal = true)
{
	FScreenSpaceData Out;

	Out.GBuffer = GetGBufferData(UV, bGetNormalizedNormal);
	float4 ScreenSpaceAO = Texture2DSampleLevel(_SceneTexturesStruct_ScreenSpaceAOTexture,  sampler_PointClamp , UV, 0);

	Out.AmbientOcclusion = ScreenSpaceAO.r;

	return Out;
}

#endif