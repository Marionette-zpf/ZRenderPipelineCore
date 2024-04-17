#ifndef Z_RENDER_PIPELINE_DEFERRED_LIGHT_PIXEL_SHADERS_INCLUDE
#define Z_RENDER_PIPELINE_DEFERRED_LIGHT_PIXEL_SHADERS_INCLUDE

// todo:
#define INVERSE_SQUARED_FALLOFF 0
#define LIGHT_SOURCE_SHAPE 0
#define USE_HAIR_COMPLEX_TRANSMITTANCE 0

#include "Assets/ZRenderPipeline/ShaderLibrary/Common.hlsl"
#include "Assets/ZRenderPipeline/ShaderLibrary/DeferredShadingCommon.hlsl"
#include "Assets/ZRenderPipeline/ShaderLibrary/DeferredLightingCommon.hlsl"
#include "Assets/ZRenderPipeline/ShaderLibrary/IESLightProfilesCommon.hlsl"

struct FInputParams
{
	float2 PixelPos;
	float4 ScreenPosition;
	float2 ScreenUV;
	float3 ScreenVector;
};

struct FDerivedParams
{
	float3 CameraVector;
	float3 WorldPosition;
};

FDerivedParams GetDerivedParams(in FInputParams Input, in float SceneDepth)
{
	FDerivedParams Out;
#if LIGHT_SOURCE_SHAPE > 0
	// With a perspective projection, the clip space position is NDC * Clip.w
	// With an orthographic projection, clip space is the same as NDC
	float2 ClipPosition = Input.ScreenPosition.xy / Input.ScreenPosition.w * (View.ViewToClip[3][3] < 1.0f ? SceneDepth : 1.0f);
	Out.WorldPosition = mul(float4(ClipPosition, SceneDepth, 1), View.ScreenToWorld).xyz;
	Out.CameraVector = normalize(Out.WorldPosition - View.WorldCameraOrigin);
#else

	//float4 ClipPos = float4((Input.ScreenUV - 0.5) * 2.0, 1, 0);

	//float3 ScreenVector =mul(_View_ScreenToTranslatedWorld, ClipPos).xyz;

	Out.WorldPosition = Input.ScreenVector * SceneDepth + _View_WorldCameraOrigin;
	Out.CameraVector = normalize(Input.ScreenVector);
#endif
	return Out;
}



FDeferredLightData SetupLightDataForStandardDeferred()
{
	// Build the light data struct using the DeferredLightUniforms and light defines
	// We are heavily relying on the shader compiler to optimize out constant subexpressions in GetDynamicLighting()
	FDeferredLightData LightData;
	LightData.Position = _DeferredLightUniforms_Position;
	LightData.InvRadius = _DeferredLightUniforms_InvRadius;
	LightData.Color = _DeferredLightUniforms_Color;
	LightData.FalloffExponent = _DeferredLightUniforms_FalloffExponent;
	LightData.Direction = _DeferredLightUniforms_Direction;
	LightData.Tangent = _DeferredLightUniforms_Tangent;
	LightData.SpotAngles = _DeferredLightUniforms_SpotAngles;
	LightData.SourceRadius = _DeferredLightUniforms_SourceRadius;
	LightData.SourceLength = _DeferredLightUniforms_SourceLength;
    LightData.SoftSourceRadius = _DeferredLightUniforms_SoftSourceRadius;
	LightData.SpecularScale = _DeferredLightUniforms_SpecularScale;
	LightData.ContactShadowLength = abs(_DeferredLightUniforms_ContactShadowLength);
	LightData.ContactShadowLengthInWS = _DeferredLightUniforms_ContactShadowLength < 0.0f;
	LightData.ContactShadowNonShadowCastingIntensity = _DeferredLightUniforms_ContactShadowNonShadowCastingIntensity;
	LightData.DistanceFadeMAD = _DeferredLightUniforms_DistanceFadeMAD;
	LightData.ShadowMapChannelMask = _DeferredLightUniforms_ShadowMapChannelMask;
	LightData.ShadowedBits = _DeferredLightUniforms_ShadowedBits;

	LightData.bInverseSquared = INVERSE_SQUARED_FALLOFF;
	LightData.bRadialLight = LIGHT_SOURCE_SHAPE > 0;
	//@todo - permutation opportunity
	LightData.bSpotLight = LIGHT_SOURCE_SHAPE > 0;
	LightData.bRectLight = LIGHT_SOURCE_SHAPE == 2;
	
	LightData.RectLightBarnCosAngle = _DeferredLightUniforms_RectLightBarnCosAngle;
	LightData.RectLightBarnLength = _DeferredLightUniforms_RectLightBarnLength;

	LightData.HairTransmittance = InitHairTransmittanceData();
	return LightData;
}

float GetExposure()
{
#if USE_PREEXPOSURE
	return _View_PreExposure;
#else
	return 1;
#endif
}

void DeferredLightPixelMain(
#if LIGHT_SOURCE_SHAPE > 0
	float4 InScreenPosition : TEXCOORD0,
#else
	float2 ScreenUV			: TEXCOORD0,
	float3 ScreenVector		: TEXCOORD1,
#endif
	float4 SVPos			: SV_POSITION,
	out float4 OutColor		: SV_Target0
	)
{

    const float2 PixelPos = SVPos.xy;
	OutColor = 0;

	// Convert input data (directional/local light)
	FInputParams InputParams = (FInputParams)0;
	InputParams.PixelPos		= SVPos.xy;
#if LIGHT_SOURCE_SHAPE > 0
	InputParams.ScreenPosition	= InScreenPosition;
	InputParams.ScreenUV		= InScreenPosition.xy / InScreenPosition.w * View.ScreenPositionScaleBias.xy + View.ScreenPositionScaleBias.wz;
	InputParams.ScreenVector	= 0;
#else
	InputParams.ScreenPosition	= 0;
	InputParams.ScreenUV		= ScreenUV;
	InputParams.ScreenVector	= ScreenVector;
#endif

    FScreenSpaceData ScreenSpaceData = GetScreenSpaceData(InputParams.ScreenUV);


	// Only light pixels marked as using deferred shading
	BRANCH if( ScreenSpaceData.GBuffer.ShadingModelID > 0 
//#if USE_LIGHTING_CHANNELS
//		&& (GetLightingChannelMask(InputParams.ScreenUV) & _DeferredLightUniforms_LightingChannelMask)
//#endif
		)
	{

		const float SceneDepth = CalcSceneDepth(InputParams.ScreenUV);
		const FDerivedParams DerivedParams = GetDerivedParams(InputParams, SceneDepth);

		FDeferredLightData LightData = SetupLightDataForStandardDeferred();
	// #if USE_HAIR_COMPLEX_TRANSMITTANCE
	//	if (ScreenSpaceData.GBuffer.ShadingModelID == SHADINGMODELID_HAIR && ShouldUseHairComplexTransmittance(ScreenSpaceData.GBuffer))
	//	{
	//		LightData.HairTransmittance = EvaluateDualScattering(ScreenSpaceData.GBuffer, DerivedParams.CameraVector, -_DeferredLightUniforms_Direction);
	//	}
	//#endif

		float Dither = InterleavedGradientNoise(InputParams.PixelPos, _View_StateFrameIndexMod8);
		FRectTexture RectTexture = InitRectTexture(_DeferredLightUniforms_SourceTexture);

		float SurfaceShadow = 1.0f;
		const float4 Radiance = GetDynamicLighting(DerivedParams.WorldPosition, DerivedParams.CameraVector, ScreenSpaceData.GBuffer, ScreenSpaceData.AmbientOcclusion, ScreenSpaceData.GBuffer.ShadingModelID, LightData, GetPerPixelLightAttenuation(InputParams.ScreenUV), Dither, uint2(InputParams.PixelPos), RectTexture, SurfaceShadow);
		const float  Attenuation = ComputeLightProfileMultiplier(DerivedParams.WorldPosition, _DeferredLightUniforms_Position, -_DeferredLightUniforms_Direction, _DeferredLightUniforms_Tangent);

		OutColor += (Radiance * Attenuation);


	//#if USE_ATMOSPHERE_TRANSMITTANCE || USE_CLOUD_TRANSMITTANCE
	//	float DeviceZ = LookupDeviceZ(ScreenUV);
	//	float3 StableLargeWorldPosition = SvPositionToWorld(float4(SVPos.xy, DeviceZ, 1.0));
	//#endif

	//#if USE_ATMOSPHERE_TRANSMITTANCE
	//	OutColor.rgb *= GetAtmosphericLightTransmittance(StableLargeWorldPosition, InputParams.ScreenUV, DeferredLightUniforms.Direction.xyz);
	//#endif

	//#if USE_CLOUD_TRANSMITTANCE
	//	float OutOpticalDepth = 0.0f;
	//	OutColor.rgb *= lerp(1.0f, GetCloudVolumetricShadow(StableLargeWorldPosition, CloudShadowmapWorldToLightClipMatrix, CloudShadowmapFarDepthKm, CloudShadowmapTexture, CloudShadowmapSampler, OutOpticalDepth), CloudShadowmapStrength);
	//#endif
	}

    //OutColor = CalcSceneDepth(InputParams.ScreenUV);
}


#endif

//DeferredLightUniforms_Position,"0.00, 0.00, 0.00",48,float3
//DeferredLightUniforms_InvRadius,"0.00",60,float
//DeferredLightUniforms_Color,"2.75, 2.60509, 2.11242",64,float3
//DeferredLightUniforms_FalloffExponent,"0.00",76,float
//DeferredLightUniforms_Direction,"0.34025, 0.57993, 0.74021",80,float3
//DeferredLightUniforms_SpecularScale,"1.00",92,float
//DeferredLightUniforms_Tangent,"0.34025, 0.57993, 0.74021",96,float3
//DeferredLightUniforms_SourceRadius,"0.00467",108,float
//DeferredLightUniforms_SpotAngles,"0.00, 0.00",112,float2
//DeferredLightUniforms_SoftSourceRadius,"0.00",120,float
//DeferredLightUniforms_SourceLength,"0.00",124,float
//DeferredLightUniforms_RectLightBarnCosAngle,"-2.21135E-36",128,float
//DeferredLightUniforms_RectLightBarnLength,"8.57595E-43",132,float


//Name,Value,Byte Offset,Type
//DrawRectangleParameters_PosScaleBias,"1124.00, 684.00, 0.00, 0.00",0,float4
//DrawRectangleParameters_UVScaleBias,"1124.00, 684.00, 0.00, 0.00",16,float4
//DrawRectangleParameters_InvTargetSizeAndTextureSize,"0.00089, 0.00146, 0.00089, 0.00146",32,float4


//Name,Value,Byte Offset,Type
//View_TranslatedWorldToClip,,0,float4x4 (row_major)
//View_TranslatedWorldToClip.row0,"-0.00711, -0.26933, 0.00, -0.98655",,float4
//View_TranslatedWorldToClip.row1,"-0.99997, 0.00201, 0.00, 0.00738",,float4
//View_TranslatedWorldToClip.row2,"0.00006, 1.62105, 0.00, -0.16327",,float4
//View_TranslatedWorldToClip.row3,"0.00, 0.00, 10.00, 0.00",,float4
//View_WorldToClip,,64,float4x4 (row_major)
//View_WorldToClip.row0,"-0.00711, -0.26933, 0.00, -0.98655",,float4
//View_WorldToClip.row1,"-0.99997, 0.00201, 0.00, 0.00738",,float4
//View_WorldToClip.row2,"0.00006, 1.62105, 0.00, -0.16327",,float4
//View_WorldToClip.row3,"-8.77944, -222.10905, 10.00, 55.33678",,float4
//View_ClipToWorld,,128,float4x4 (row_major)
//View_ClipToWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_ClipToWorld.row1,"-0.09936, 0.00074, 0.60037, 0.00",,float4
//View_ClipToWorld.row2,"3.24536, -0.90019, 14.24187, 0.10",,float4
//View_ClipToWorld.row3,"-0.98645, 0.00701, -0.16391, 0.00",,float4
//View_TranslatedWorldToView,,192,float4x4 (row_major)
//View_TranslatedWorldToView.row0,"-0.00748, -0.16327, -0.98655, 0.00",,float4
//View_TranslatedWorldToView.row1,"-0.99997, 0.00122, 0.00738, 0.00",,float4
//View_TranslatedWorldToView.row2,"-1.83765E-09, 0.98658, -0.16327, 0.00",,float4
//View_TranslatedWorldToView.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_ViewToTranslatedWorld,,256,float4x4 (row_major)
//View_ViewToTranslatedWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_ViewToTranslatedWorld.row1,"-0.16327, 0.00122, 0.98658, 0.00",,float4
//View_ViewToTranslatedWorld.row2,"-0.98655, 0.00738, -0.16327, 0.00",,float4
//View_ViewToTranslatedWorld.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_TranslatedWorldToCameraView,,320,float4x4 (row_major)
//View_TranslatedWorldToCameraView.row0,"-0.00748, -0.16327, -0.98655, 0.00",,float4
//View_TranslatedWorldToCameraView.row1,"-0.99997, 0.00122, 0.00738, 0.00",,float4
//View_TranslatedWorldToCameraView.row2,"-1.83765E-09, 0.98658, -0.16327, 0.00",,float4
//View_TranslatedWorldToCameraView.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_CameraViewToTranslatedWorld,,384,float4x4 (row_major)
//View_CameraViewToTranslatedWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_CameraViewToTranslatedWorld.row1,"-0.16327, 0.00122, 0.98658, 0.00",,float4
//View_CameraViewToTranslatedWorld.row2,"-0.98655, 0.00738, -0.16327, 0.00",,float4
//View_CameraViewToTranslatedWorld.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_ViewToClip,,448,float4x4 (row_major)
//View_ViewToClip.row0,"1.00, 0.00, 0.00, 0.00",,float4
//View_ViewToClip.row1,"0.00, 1.64327, 0.00, 0.00",,float4
//View_ViewToClip.row2,"-0.00037, 0.00105, 0.00, 1.00",,float4
//View_ViewToClip.row3,"0.00, 0.00, 10.00, 0.00",,float4
//View_ViewToClipNoAA,,512,float4x4 (row_major)
//View_ViewToClipNoAA.row0,"1.00, 0.00, 0.00, 0.00",,float4
//View_ViewToClipNoAA.row1,"0.00, 1.64327, 0.00, 0.00",,float4
//View_ViewToClipNoAA.row2,"0.00, 0.00, 0.00, 1.00",,float4
//View_ViewToClipNoAA.row3,"0.00, 0.00, 10.00, 0.00",,float4
//View_ClipToView,,576,float4x4 (row_major)
//View_ClipToView.row0,"1.00, 0.00, 0.00, 0.00",,float4
//View_ClipToView.row1,"0.00, 0.60854, 0.00, 0.00",,float4
//View_ClipToView.row2,"0.00, 0.00, 0.00, 0.10",,float4
//View_ClipToView.row3,"0.00037, -0.00064, 1.00, 0.00",,float4
//View_ClipToTranslatedWorld,,640,float4x4 (row_major)
//View_ClipToTranslatedWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_ClipToTranslatedWorld.row1,"-0.09936, 0.00074, 0.60037, 0.00",,float4
//View_ClipToTranslatedWorld.row2,"0.00, 0.00, 0.00, 0.10",,float4
//View_ClipToTranslatedWorld.row3,"-0.98645, 0.00701, -0.16391, 0.00",,float4
//View_SVPositionToTranslatedWorld,,704,float4x4 (row_major)
//View_SVPositionToTranslatedWorld.row0,"-0.00001, -0.00178, -3.26984E-12, 0.00",,float4
//View_SVPositionToTranslatedWorld.row1,"0.00029, -2.17254E-06, -0.00176, 0.00",,float4
//View_SVPositionToTranslatedWorld.row2,"0.00, 0.00, 0.00, 0.10",,float4
//View_SVPositionToTranslatedWorld.row3,"-1.07833, 1.00772, 0.43647, 0.00",,float4
//View_ScreenToWorld,,768,float4x4 (row_major)
//View_ScreenToWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_ScreenToWorld.row1,"-0.09936, 0.00074, 0.60037, 0.00",,float4
//View_ScreenToWorld.row2,"-0.98645, 0.00701, -0.16391, 0.00",,float4
//View_ScreenToWorld.row3,"32.45358, -9.0019, 142.41872, 1.00",,float4
//View_ScreenToTranslatedWorld,,832,float4x4 (row_major)
//View_ScreenToTranslatedWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_ScreenToTranslatedWorld.row1,"-0.09936, 0.00074, 0.60037, 0.00",,float4
//View_ScreenToTranslatedWorld.row2,"-0.98645, 0.00701, -0.16391, 0.00",,float4
//View_ScreenToTranslatedWorld.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_MobileMultiviewShadowTransform,,896,float4x4 (row_major)
//View_MobileMultiviewShadowTransform.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_MobileMultiviewShadowTransform.row1,"-0.09936, 0.00074, 0.60037, 0.00",,float4
//View_MobileMultiviewShadowTransform.row2,"-0.98645, 0.00701, -0.16391, 0.00",,float4
//View_MobileMultiviewShadowTransform.row3,"32.45358, -9.0019, 142.41872, 1.00",,float4
//View_ViewForward,"-0.98655, 0.00738, -0.16327",960,float3
//PrePadding_View_972,"0.00",972,float
//View_ViewUp,"-0.16327, 0.00122, 0.98658",976,float3
//PrePadding_View_988,"0.00",988,float
//View_ViewRight,"-0.00748, -0.99997, -1.83765E-09",992,float3
//PrePadding_View_1004,"0.00",1004,float
//View_HMDViewNoRollUp,"-0.16327, 0.00122, 0.98658",1008,float3
//PrePadding_View_1020,"0.00",1020,float
//View_HMDViewNoRollRight,"-0.00748, -0.99997, -1.83765E-09",1024,float3
//PrePadding_View_1036,"0.00",1036,float
//View_InvDeviceZToWorldZTransform,"0.00, 0.00, 0.10, -1.00000E-08",1040,float4
//View_ScreenPositionScaleBias,"0.50, -0.50, 0.50, 0.50",1056,float4
//View_WorldCameraOrigin,"32.45358, -9.0019, 142.41872",1072,float3
//PrePadding_View_1084,"0.00",1084,float
//View_TranslatedWorldCameraOrigin,"0.00, 0.00, 0.00",1088,float3
//PrePadding_View_1100,"0.00",1100,float
//View_WorldViewOrigin,"32.45358, -9.0019, 142.41872",1104,float3
//PrePadding_View_1116,"0.00",1116,float
//View_PreViewTranslation,"-32.45358, 9.0019, -142.41872",1120,float3
//PrePadding_View_1132,"0.00",1132,float
//View_PrevProjection,,1136,float4x4 (row_major)
//View_PrevProjection.row0,"1.00, 0.00, 0.00, 0.00",,float4
//View_PrevProjection.row1,"0.00, 1.64327, 0.00, 0.00",,float4
//View_PrevProjection.row2,"-0.00029, -0.00083, 0.00, 1.00",,float4
//View_PrevProjection.row3,"0.00, 0.00, 10.00, 0.00",,float4
//View_PrevViewProj,,1200,float4x4 (row_major)
//View_PrevViewProj.row0,"-0.00719, -0.26748, 0.00, -0.98655",,float4
//View_PrevViewProj.row1,"-0.99997, 0.002, 0.00, 0.00738",,float4
//View_PrevViewProj.row2,"0.00005, 1.62136, 0.00, -0.16327",,float4
//View_PrevViewProj.row3,"-8.7751, -222.2133, 10.00, 55.33678",,float4
//View_PrevViewRotationProj,,1264,float4x4 (row_major)
//View_PrevViewRotationProj.row0,"-0.00719, -0.26748, 0.00, -0.98655",,float4
//View_PrevViewRotationProj.row1,"-0.99997, 0.002, 0.00, 0.00738",,float4
//View_PrevViewRotationProj.row2,"0.00005, 1.62136, 0.00, -0.16327",,float4
//View_PrevViewRotationProj.row3,"0.00, 0.00, 10.00, 0.00",,float4
//View_PrevViewToClip,,1328,float4x4 (row_major)
//View_PrevViewToClip.row0,"1.00, 0.00, 0.00, 0.00",,float4
//View_PrevViewToClip.row1,"0.00, 1.64327, 0.00, 0.00",,float4
//View_PrevViewToClip.row2,"-0.00029, -0.00083, 0.00, 1.00",,float4
//View_PrevViewToClip.row3,"0.00, 0.00, 10.00, 0.00",,float4
//View_PrevClipToView,,1392,float4x4 (row_major)
//View_PrevClipToView.row0,"1.00, 0.00, 0.00, 0.00",,float4
//View_PrevClipToView.row1,"0.00, 0.60854, 0.00, 0.00",,float4
//View_PrevClipToView.row2,"0.00, 0.00, 0.00, 0.10",,float4
//View_PrevClipToView.row3,"0.00029, 0.00051, 1.00, 0.00",,float4
//View_PrevTranslatedWorldToClip,,1456,float4x4 (row_major)
//View_PrevTranslatedWorldToClip.row0,"-0.00719, -0.26748, 0.00, -0.98655",,float4
//View_PrevTranslatedWorldToClip.row1,"-0.99997, 0.002, 0.00, 0.00738",,float4
//View_PrevTranslatedWorldToClip.row2,"0.00005, 1.62136, 0.00, -0.16327",,float4
//View_PrevTranslatedWorldToClip.row3,"0.00, 0.00, 10.00, 0.00",,float4
//View_PrevTranslatedWorldToView,,1520,float4x4 (row_major)
//View_PrevTranslatedWorldToView.row0,"-0.00748, -0.16327, -0.98655, 0.00",,float4
//View_PrevTranslatedWorldToView.row1,"-0.99997, 0.00122, 0.00738, 0.00",,float4
//View_PrevTranslatedWorldToView.row2,"-1.83765E-09, 0.98658, -0.16327, 0.00",,float4
//View_PrevTranslatedWorldToView.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_PrevViewToTranslatedWorld,,1584,float4x4 (row_major)
//View_PrevViewToTranslatedWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_PrevViewToTranslatedWorld.row1,"-0.16327, 0.00122, 0.98658, 0.00",,float4
//View_PrevViewToTranslatedWorld.row2,"-0.98655, 0.00738, -0.16327, 0.00",,float4
//View_PrevViewToTranslatedWorld.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_PrevTranslatedWorldToCameraView,,1648,float4x4 (row_major)
//View_PrevTranslatedWorldToCameraView.row0,"-0.00748, -0.16327, -0.98655, 0.00",,float4
//View_PrevTranslatedWorldToCameraView.row1,"-0.99997, 0.00122, 0.00738, 0.00",,float4
//View_PrevTranslatedWorldToCameraView.row2,"-1.83765E-09, 0.98658, -0.16327, 0.00",,float4
//View_PrevTranslatedWorldToCameraView.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_PrevCameraViewToTranslatedWorld,,1712,float4x4 (row_major)
//View_PrevCameraViewToTranslatedWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_PrevCameraViewToTranslatedWorld.row1,"-0.16327, 0.00122, 0.98658, 0.00",,float4
//View_PrevCameraViewToTranslatedWorld.row2,"-0.98655, 0.00738, -0.16327, 0.00",,float4
//View_PrevCameraViewToTranslatedWorld.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_PrevWorldCameraOrigin,"32.45358, -9.0019, 142.41872",1776,float3
//PrePadding_View_1788,"0.00",1788,float
//View_PrevWorldViewOrigin,"32.45358, -9.0019, 142.41872",1792,float3
//PrePadding_View_1804,"0.00",1804,float
//View_PrevPreViewTranslation,"-32.45358, 9.0019, -142.41872",1808,float3
//PrePadding_View_1820,"0.00",1820,float
//View_PrevInvViewProj,,1824,float4x4 (row_major)
//View_PrevInvViewProj.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_PrevInvViewProj.row1,"-0.09936, 0.00074, 0.60037, 0.00",,float4
//View_PrevInvViewProj.row2,"3.24536, -0.90019, 14.24187, 0.10",,float4
//View_PrevInvViewProj.row3,"-0.98664, 0.00709, -0.16277, 0.00",,float4
//View_PrevScreenToTranslatedWorld,,1888,float4x4 (row_major)
//View_PrevScreenToTranslatedWorld.row0,"-0.00748, -0.99997, -1.83765E-09, 0.00",,float4
//View_PrevScreenToTranslatedWorld.row1,"-0.09936, 0.00074, 0.60037, 0.00",,float4
//View_PrevScreenToTranslatedWorld.row2,"-0.98664, 0.00709, -0.16277, 0.00",,float4
//View_PrevScreenToTranslatedWorld.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_ClipToPrevClip,,1952,float4x4 (row_major)
//View_ClipToPrevClip.row0,"1.00, -1.85274E-10, 0.00, -1.65622E-10",,float4
//View_ClipToPrevClip.row1,"2.66664E-12, 1.00, 0.00, -1.49012E-08",,float4
//View_ClipToPrevClip.row2,"0.00, 0.00, 1.00, 0.00",,float4
//View_ClipToPrevClip.row3,"-1.65622E-10, -5.96046E-08, 0.00, 1.00",,float4
//View_TemporalAAJitter,"-0.00037, 0.00105, -0.00029, -0.00083",2016,float4
//View_GlobalClippingPlane,"0.00, 0.00, 0.00, 0.00",2032,float4
//View_FieldOfViewWideAngles,"1.5708, 1.09335",2048,float2
//View_PrevFieldOfViewWideAngles,"1.5708, 1.09335",2056,float2
//View_ViewRectMin,"0.00, 0.00, 0.00, 0.00",2064,float4
//View_ViewSizeAndInvSize,"1124.00, 684.00, 0.00089, 0.00146",2080,float4
//View_LightProbeSizeRatioAndInvSizeRatio,"1.00, 1.00, 1.00, 1.00",2096,float4
//View_BufferSizeAndInvSize,"1124.00, 684.00, 0.00089, 0.00146",2112,float4
//View_BufferBilinearUVMinMax,"0.00044, 0.00073, 0.99956, 0.99927",2128,float4
//View_ScreenToViewSpace,"2.00, -1.21708, -1.00, 0.60854",2144,float4
//View_NumSceneColorMSAASamples,"1",2160,int
//View_PreExposure,"1.00",2164,float
//View_OneOverPreExposure,"1.00",2168,float
//PrePadding_View_2172,"0.00",2172,float
//View_DiffuseOverrideParameter,"0.00, 0.00, 0.00, 1.00",2176,float4
//View_SpecularOverrideParameter,"0.00, 0.00, 0.00, 1.00",2192,float4
//View_NormalOverrideParameter,"0.00, 0.00, 0.00, 1.00",2208,float4
//View_RoughnessOverrideParameter,"0.00, 1.00",2224,float2
//View_PrevFrameGameTime,"62.48462",2232,float
//View_PrevFrameRealTime,"103.57781",2236,float
//View_OutOfBoundsMask,"0.00",2240,float
//PrePadding_View_2244,"0.00",2244,float
//PrePadding_View_2248,"0.00",2248,float
//PrePadding_View_2252,"0.00",2252,float
//View_WorldCameraMovementSinceLastFrame,"0.00, 0.00, 0.00",2256,float3
//View_CullingSign,"1.00",2268,float
//View_NearPlane,"10.00",2272,float
//View_AdaptiveTessellationFactor,"57.35888",2276,float
//View_GameTime,"62.51744",2280,float
//View_RealTime,"103.61063",2284,float
//View_DeltaTime,"0.03282",2288,float
//View_MaterialTextureMipBias,"0.00",2292,float
//View_MaterialTextureDerivativeMultiply,"1.00",2296,float
//View_Random,"14114",2300,uint
//View_FrameNumber,"1564",2304,uint
//View_StateFrameIndexMod8,"1",2308,uint
//View_StateFrameIndex,"1561",2312,uint
//View_DebugViewModeMask,"0",2316,uint
//View_CameraCut,"0.00",2320,float
//View_UnlitViewmodeMask,"0.00",2324,float
//PrePadding_View_2328,"0.00",2328,float
//PrePadding_View_2332,"0.00",2332,float
//View_DirectionalLightColor,"0.87535, 0.82923, 0.6724, 0.00",2336,float4
//View_DirectionalLightDirection,"0.34025, 0.57993, 0.74021",2352,float3
//PrePadding_View_2364,"0.00",2364,float
//View_TranslucencyLightingVolumeMin,,2368,float4[2]
//View_TranslucencyLightingVolumeMin[0],"-3407.70996, -2097.05225, -2162.58521, 0.01563",2368,float4
//View_TranslucencyLightingVolumeMin[1],"-11564.98535, -6982.63281, -7419.04736, 0.01563",2384,float4
//View_TranslucencyLightingVolumeInvSize,,2400,float4[2]
//View_TranslucencyLightingVolumeInvSize[0],"0.00024, 0.00024, 0.00024, 65.53288",2400,float4
//View_TranslucencyLightingVolumeInvSize[1],"0.00007, 0.00007, 0.00007, 218.20728",2416,float4
//View_TemporalAAParams,"1.00, 8.00, -0.208, -0.36027",2432,float4
//View_CircleDOFParams,"0.00, 1.00, 0.00, 0.00",2448,float4
//View_ForceDrawAllVelocities,"0",2464,uint
//View_DepthOfFieldSensorWidth,"24.576",2468,float
//View_DepthOfFieldFocalDistance,"0.00",2472,float
//View_DepthOfFieldScale,"0.00",2476,float
//View_DepthOfFieldFocalLength,"50.00",2480,float
//View_DepthOfFieldFocalRegion,"0.00",2484,float
//View_DepthOfFieldNearTransitionRegion,"300.00",2488,float
//View_DepthOfFieldFarTransitionRegion,"500.00",2492,float
//View_MotionBlurNormalizedToPixel,"56.20",2496,float
//View_bSubsurfacePostprocessEnabled,"1.00",2500,float
//View_GeneralPurposeTweak,"1.00",2504,float
//View_DemosaicVposOffset,"0.00",2508,float
//View_IndirectLightingColorScale,"1.00, 1.00, 1.00",2512,float3
//View_AtmosphericFogSunPower,"1.00",2524,float
//View_AtmosphericFogPower,"1.00",2528,float
//View_AtmosphericFogDensityScale,"1.00",2532,float
//View_AtmosphericFogDensityOffset,"0.00",2536,float
//View_AtmosphericFogGroundOffset,"-99759.00",2540,float
//View_AtmosphericFogDistanceScale,"1.00",2544,float
//View_AtmosphericFogAltitudeScale,"1.00",2548,float
//View_AtmosphericFogHeightScaleRayleigh,"8.00",2552,float
//View_AtmosphericFogStartDistance,"0.15",2556,float
//View_AtmosphericFogDistanceOffset,"0.00",2560,float
//View_AtmosphericFogSunDiscScale,"1.00",2564,float
//PrePadding_View_2568,"0.00",2568,float
//PrePadding_View_2572,"0.00",2572,float
//View_AtmosphereLightDirection,,2576,float4[2]
//View_AtmosphereLightDirection[0],"0.34025, 0.57993, 0.74021, 1.00",2576,float4
//View_AtmosphereLightDirection[1],"0.00, 0.00, 1.00, 1.00",2592,float4
//View_AtmosphereLightColor,,2608,float4[2]
//View_AtmosphereLightColor[0],"2.75, 2.60509, 2.11242, 1.00",2608,float4
//View_AtmosphereLightColor[1],"0.00, 0.00, 0.00, 0.00",2624,float4
//View_AtmosphereLightColorGlobalPostTransmittance,,2640,float4[2]
//View_AtmosphereLightColorGlobalPostTransmittance[0],"2.75, 2.60509, 2.11242, 0.00",2640,float4
//View_AtmosphereLightColorGlobalPostTransmittance[1],"0.00, 0.00, 0.00, 0.00",2656,float4
//View_AtmosphereLightDiscLuminance,,2672,float4[2]
//View_AtmosphereLightDiscLuminance[0],"40125.60547, 38011.25, 30822.5332, 0.00",2672,float4
//View_AtmosphereLightDiscLuminance[1],"0.00, 0.00, 0.00, 1.00",2688,float4
//View_AtmosphereLightDiscCosHalfApexAngle,,2704,float4[2]
//View_AtmosphereLightDiscCosHalfApexAngle[0],"0.99999, 0.00, 0.00, 1.00",2704,float4
//View_AtmosphereLightDiscCosHalfApexAngle[1],"1.00, 0.00, 0.00, 1.00",2720,float4
//View_SkyViewLutSizeAndInvSize,"1.00, 1.00, 1.00, 1.00",2736,float4
//View_SkyWorldCameraOrigin,"32.45358, -9.0019, 142.41872",2752,float3
//PrePadding_View_2764,"0.00",2764,float
//View_SkyPlanetCenterAndViewHeight,"0.00, 0.00, 0.00, 0.00",2768,float4
//View_SkyViewLutReferential,,2784,float4x4 (row_major)
//View_SkyViewLutReferential.row0,"1.00, 0.00, 0.00, 0.00",,float4
//View_SkyViewLutReferential.row1,"0.00, 1.00, 0.00, 0.00",,float4
//View_SkyViewLutReferential.row2,"0.00, 0.00, 1.00, 0.00",,float4
//View_SkyViewLutReferential.row3,"0.00, 0.00, 0.00, 1.00",,float4
//View_SkyAtmosphereSkyLuminanceFactor,"1.00, 1.00, 1.00, 1.00",2848,float4
//View_SkyAtmospherePresentInScene,"0.00",2864,float
//View_SkyAtmosphereHeightFogContribution,"0.00",2868,float
//View_SkyAtmosphereBottomRadiusKm,"1.00",2872,float
//View_SkyAtmosphereTopRadiusKm,"1.00",2876,float
//View_SkyAtmosphereCameraAerialPerspectiveVolumeSizeAndInvSize,"1.00, 1.00, 1.00, 1.00",2880,float4
//View_SkyAtmosphereAerialPerspectiveStartDepthKm,"1.00",2896,float
//View_SkyAtmosphereCameraAerialPerspectiveVolumeDepthResolution,"1.00",2900,float
//View_SkyAtmosphereCameraAerialPerspectiveVolumeDepthResolutionInv,"1.00",2904,float
//View_SkyAtmosphereCameraAerialPerspectiveVolumeDepthSliceLengthKm,"1.00",2908,float
//View_SkyAtmosphereCameraAerialPerspectiveVolumeDepthSliceLengthKmInv,"1.00",2912,float
//View_SkyAtmosphereApplyCameraAerialPerspectiveVolume,"0.00",2916,float
//View_AtmosphericFogRenderMask,"0",2920,uint
//View_AtmosphericFogInscatterAltitudeSampleNum,"2",2924,uint
//View_NormalCurvatureToRoughnessScaleBias,"1.00, 0.00, 0.333",2928,float3
//View_RenderingReflectionCaptureMask,"0.00",2940,float
//View_RealTimeReflectionCapture,"0.00",2944,float
//View_RealTimeReflectionCapturePreExposure,"1.00",2948,float
//PrePadding_View_2952,"0.00",2952,float
//PrePadding_View_2956,"0.00",2956,float
//View_AmbientCubemapTint,"1.00, 1.00, 1.00, 1.00",2960,float4
//View_AmbientCubemapIntensity,"0.00",2976,float
//View_SkyLightApplyPrecomputedBentNormalShadowingFlag,"0.00",2980,float
//View_SkyLightAffectReflectionFlag,"1.00",2984,float
//View_SkyLightAffectGlobalIlluminationFlag,"1.00",2988,float
//View_SkyLightColor,"1.00, 1.00, 1.00, 1.00",2992,float4
//View_MobileSkyIrradianceEnvironmentMap,,3008,float4[7]
//View_MobileSkyIrradianceEnvironmentMap[0],"0.00, 0.00, 0.00, 0.00",3008,float4
//View_MobileSkyIrradianceEnvironmentMap[1],"0.00, 0.00, 0.00, 0.00",3024,float4
//View_MobileSkyIrradianceEnvironmentMap[2],"0.00, 0.00, 0.00, 0.00",3040,float4
//View_MobileSkyIrradianceEnvironmentMap[3],"0.00, 0.00, 0.00, 0.00",3056,float4
//View_MobileSkyIrradianceEnvironmentMap[4],"0.00, 0.00, 0.00, 0.00",3072,float4
//View_MobileSkyIrradianceEnvironmentMap[5],"0.00, 0.00, 0.00, 0.00",3088,float4
//View_MobileSkyIrradianceEnvironmentMap[6],"0.00, 0.00, 0.00, 0.00",3104,float4
//View_MobilePreviewMode,"0.00",3120,float
//View_HMDEyePaddingOffset,"1.00",3124,float
//View_ReflectionCubemapMaxMip,"7.00",3128,float
//View_ShowDecalsMask,"1.00",3132,float
//View_DistanceFieldAOSpecularOcclusionMode,"1",3136,uint
//View_IndirectCapsuleSelfShadowingIntensity,"0.80",3140,float
//PrePadding_View_3144,"0.00",3144,float
//PrePadding_View_3148,"0.00",3148,float
//View_ReflectionEnvironmentRoughnessMixingScaleBiasAndLargestWeight,"5.00, -0.50, 10000.00",3152,float3
//View_StereoPassIndex,"0",3164,int
//View_GlobalVolumeCenterAndExtent,,3168,float4[4]
//View_GlobalVolumeCenterAndExtent[0],"0.00, 0.00, 0.00, 1.00",3168,float4
//View_GlobalVolumeCenterAndExtent[1],"0.00, 0.00, 0.00, 1.00",3184,float4
//View_GlobalVolumeCenterAndExtent[2],"0.00, 0.00, 0.00, 1.00",3200,float4
//View_GlobalVolumeCenterAndExtent[3],"0.00, 0.00, 0.00, 1.00",3216,float4
//View_GlobalVolumeWorldToUVAddAndMul,,3232,float4[4]
//View_GlobalVolumeWorldToUVAddAndMul[0],"0.00, 0.00, 0.00, 1.00",3232,float4
//View_GlobalVolumeWorldToUVAddAndMul[1],"0.00, 0.00, 0.00, 1.00",3248,float4
//View_GlobalVolumeWorldToUVAddAndMul[2],"0.00, 0.00, 0.00, 1.00",3264,float4
//View_GlobalVolumeWorldToUVAddAndMul[3],"0.00, 0.00, 0.00, 1.00",3280,float4
//View_GlobalVolumeDimension,"0.00",3296,float
//View_GlobalVolumeTexelSize,"0.00",3300,float
//View_MaxGlobalDistance,"0.00",3304,float
//PrePadding_View_3308,"0.00",3308,float
//View_CursorPosition,"1093, 27",3312,int2
//View_bCheckerboardSubsurfaceProfileRendering,"0.00",3320,float
//PrePadding_View_3324,"0.00",3324,float
//View_VolumetricFogInvGridSize,"0.00, 0.00, 0.00",3328,float3
//PrePadding_View_3340,"0.00",3340,float
//View_VolumetricFogGridZParams,"0.00, 0.00, 0.00",3344,float3
//PrePadding_View_3356,"0.00",3356,float
//View_VolumetricFogSVPosToVolumeUV,"0.00, 0.00",3360,float2
//View_VolumetricFogMaxDistance,"0.00",3368,float
//PrePadding_View_3372,"0.00",3372,float
//View_VolumetricLightmapWorldToUVScale,"3.40000E+38, 3.40000E+38, 3.40000E+38",3376,float3
//PrePadding_View_3388,"0.00",3388,float
//View_VolumetricLightmapWorldToUVAdd,"0.00, 0.00, 0.00",3392,float3
//PrePadding_View_3404,"0.00",3404,float
//View_VolumetricLightmapIndirectionTextureSize,"0.00, 0.00, 0.00",3408,float3
//View_VolumetricLightmapBrickSize,"0.00",3420,float
//View_VolumetricLightmapBrickTexelSize,"3.40000E+38, 3.40000E+38, 3.40000E+38",3424,float3
//View_StereoIPD,"0.00",3436,float
//View_IndirectLightingCacheShowFlag,"1.00",3440,float
//View_EyeToPixelSpreadAngle,"0.00292",3444,float
//PrePadding_View_3448,"0.00",3448,float
//PrePadding_View_3452,"0.00",3452,float
//View_WorldToVirtualTexture,,3456,float4x4 (row_major)
//View_WorldToVirtualTexture.row0,"0.00, 0.00, 0.00, 0.00",,float4
//View_WorldToVirtualTexture.row1,"0.00, 0.00, 0.00, 0.00",,float4
//View_WorldToVirtualTexture.row2,"0.00, 0.00, 0.00, 0.00",,float4
//View_WorldToVirtualTexture.row3,"0.00, 0.00, 0.00, 0.00",,float4
//View_XRPassthroughCameraUVs,,3520,float4[2]
//View_XRPassthroughCameraUVs[0],"0.00, 0.00, 0.00, 1.00",3520,float4
//View_XRPassthroughCameraUVs[1],"1.00, 0.00, 1.00, 1.00",3536,float4
//View_VirtualTextureFeedbackStride,"71",3552,uint
//View_VirtualTextureFeedbackJitterOffset,"164",3556,uint
//View_VirtualTextureFeedbackSampleOffset,"31",3560,uint
//PrePadding_View_3564,"0",3564,uint
//View_RuntimeVirtualTextureMipLevel,"0.00, 0.00, 0.00, 0.00",3568,float4
//View_RuntimeVirtualTexturePackHeight,"0.00, 0.00",3584,float2
//PrePadding_View_3592,"0.00",3592,float
//PrePadding_View_3596,"0.00",3596,float
//View_RuntimeVirtualTextureDebugParams,"0.00, 0.00, 0.00, 0.00",3600,float4
//View_FarShadowStaticMeshLODBias,"0",3616,int
//View_MinRoughness,"0.02",3620,float
//PrePadding_View_3624,"0.00",3624,float
//PrePadding_View_3628,"0.00",3628,float
//View_HairRenderInfo,"0.00037, 0.00073, 0.0011, 0.04448",3632,float4
//View_EnableSkyLight,"0",3648,uint
//View_HairRenderInfoBits,"0",3652,uint
//View_HairComponents,"31",3656,uint
//PrePadding_View_3660,"0",3660,uint
//View_PhysicsFieldClipmapCenter,"0.00, 0.00, 0.00",3664,float3
//View_PhysicsFieldClipmapDistance,"1.00",3676,float
//View_PhysicsFieldClipmapResolution,"2",3680,int
//View_PhysicsFieldClipmapExponent,"1",3684,int
//View_PhysicsFieldClipmapCount,"1",3688,int
//View_PhysicsFieldTargetCount,"0",3692,int
//View_PhysicsFieldVectorTargets,,3696,int[32]
//View_PhysicsFieldVectorTargets[0],"0",3696,int
//View_PhysicsFieldVectorTargets[1],"0",3712,int
//View_PhysicsFieldVectorTargets[2],"0",3728,int
//View_PhysicsFieldVectorTargets[3],"0",3744,int
//View_PhysicsFieldVectorTargets[4],"0",3760,int
//View_PhysicsFieldVectorTargets[5],"0",3776,int
//View_PhysicsFieldVectorTargets[6],"0",3792,int
//View_PhysicsFieldVectorTargets[7],"0",3808,int
//View_PhysicsFieldVectorTargets[8],"0",3824,int
//View_PhysicsFieldVectorTargets[9],"0",3840,int
//View_PhysicsFieldVectorTargets[10],"0",3856,int
//View_PhysicsFieldVectorTargets[11],"0",3872,int
//View_PhysicsFieldVectorTargets[12],"0",3888,int
//View_PhysicsFieldVectorTargets[13],"0",3904,int
//View_PhysicsFieldVectorTargets[14],"0",3920,int
//View_PhysicsFieldVectorTargets[15],"0",3936,int
//View_PhysicsFieldVectorTargets[16],"0",3952,int
//View_PhysicsFieldVectorTargets[17],"0",3968,int
//View_PhysicsFieldVectorTargets[18],"0",3984,int
//View_PhysicsFieldVectorTargets[19],"1119937836",4000,int
//View_PhysicsFieldVectorTargets[20],"-522543312",4016,int
//View_PhysicsFieldVectorTargets[21],"1606543024",4032,int
//View_PhysicsFieldVectorTargets[22],"-925990912",4048,int
//View_PhysicsFieldVectorTargets[23],"-925990912",4064,int
//View_PhysicsFieldVectorTargets[24],"930825024",4080,int
//View_PhysicsFieldVectorTargets[25],"910177664",4096,int
//View_PhysicsFieldVectorTargets[26],"0",4112,int
//View_PhysicsFieldVectorTargets[27],"0",4128,int
//View_PhysicsFieldVectorTargets[28],"910178360",4144,int
//View_PhysicsFieldVectorTargets[29],"5776",4160,int
//View_PhysicsFieldVectorTargets[30],"192465160",4176,int
//View_PhysicsFieldVectorTargets[31],"0",4192,int
//PrePadding_View_4196,"0",4196,int
//PrePadding_View_4200,"0",4200,int
//PrePadding_View_4204,"0",4204,int
//View_PhysicsFieldScalarTargets,,4208,int[32]
//View_PhysicsFieldScalarTargets[0],"0",4208,int
//View_PhysicsFieldScalarTargets[1],"0",4224,int
//View_PhysicsFieldScalarTargets[2],"0",4240,int
//View_PhysicsFieldScalarTargets[3],"0",4256,int
//View_PhysicsFieldScalarTargets[4],"0",4272,int
//View_PhysicsFieldScalarTargets[5],"0",4288,int
//View_PhysicsFieldScalarTargets[6],"0",4304,int
//View_PhysicsFieldScalarTargets[7],"0",4320,int
//View_PhysicsFieldScalarTargets[8],"0",4336,int
//View_PhysicsFieldScalarTargets[9],"0",4352,int
//View_PhysicsFieldScalarTargets[10],"0",4368,int
//View_PhysicsFieldScalarTargets[11],"0",4384,int
//View_PhysicsFieldScalarTargets[12],"0",4400,int
//View_PhysicsFieldScalarTargets[13],"0",4416,int
//View_PhysicsFieldScalarTargets[14],"0",4432,int
//View_PhysicsFieldScalarTargets[15],"0",4448,int
//View_PhysicsFieldScalarTargets[16],"0",4464,int
//View_PhysicsFieldScalarTargets[17],"0",4480,int
//View_PhysicsFieldScalarTargets[18],"0",4496,int
//View_PhysicsFieldScalarTargets[19],"1119937836",4512,int
//View_PhysicsFieldScalarTargets[20],"-522543312",4528,int
//View_PhysicsFieldScalarTargets[21],"1606543024",4544,int
//View_PhysicsFieldScalarTargets[22],"-925990912",4560,int
//View_PhysicsFieldScalarTargets[23],"-925990912",4576,int
//View_PhysicsFieldScalarTargets[24],"930825024",4592,int
//View_PhysicsFieldScalarTargets[25],"910177664",4608,int
//View_PhysicsFieldScalarTargets[26],"0",4624,int
//View_PhysicsFieldScalarTargets[27],"0",4640,int
//View_PhysicsFieldScalarTargets[28],"910178360",4656,int
//View_PhysicsFieldScalarTargets[29],"5776",4672,int
//View_PhysicsFieldScalarTargets[30],"192465160",4688,int
//View_PhysicsFieldScalarTargets[31],"0",4704,int
//PrePadding_View_4708,"0",4708,int
//PrePadding_View_4712,"0",4712,int
//PrePadding_View_4716,"0",4716,int
//View_PhysicsFieldIntegerTargets,,4720,int[32]
//View_PhysicsFieldIntegerTargets[0],"0",4720,int
//View_PhysicsFieldIntegerTargets[1],"0",4736,int
//View_PhysicsFieldIntegerTargets[2],"0",4752,int
//View_PhysicsFieldIntegerTargets[3],"0",4768,int
//View_PhysicsFieldIntegerTargets[4],"0",4784,int
//View_PhysicsFieldIntegerTargets[5],"0",4800,int
//View_PhysicsFieldIntegerTargets[6],"0",4816,int
//View_PhysicsFieldIntegerTargets[7],"0",4832,int
//View_PhysicsFieldIntegerTargets[8],"0",4848,int
//View_PhysicsFieldIntegerTargets[9],"0",4864,int
//View_PhysicsFieldIntegerTargets[10],"0",4880,int
//View_PhysicsFieldIntegerTargets[11],"0",4896,int
//View_PhysicsFieldIntegerTargets[12],"0",4912,int
//View_PhysicsFieldIntegerTargets[13],"0",4928,int
//View_PhysicsFieldIntegerTargets[14],"0",4944,int
//View_PhysicsFieldIntegerTargets[15],"0",4960,int
//View_PhysicsFieldIntegerTargets[16],"0",4976,int
//View_PhysicsFieldIntegerTargets[17],"0",4992,int
//View_PhysicsFieldIntegerTargets[18],"0",5008,int
//View_PhysicsFieldIntegerTargets[19],"1119937836",5024,int
//View_PhysicsFieldIntegerTargets[20],"-522543312",5040,int
//View_PhysicsFieldIntegerTargets[21],"1606543024",5056,int
//View_PhysicsFieldIntegerTargets[22],"-925990912",5072,int
//View_PhysicsFieldIntegerTargets[23],"-925990912",5088,int
//View_PhysicsFieldIntegerTargets[24],"930825024",5104,int
//View_PhysicsFieldIntegerTargets[25],"910177664",5120,int
//View_PhysicsFieldIntegerTargets[26],"0",5136,int
//View_PhysicsFieldIntegerTargets[27],"0",5152,int
//View_PhysicsFieldIntegerTargets[28],"910178360",5168,int
//View_PhysicsFieldIntegerTargets[29],"5776",5184,int
//View_PhysicsFieldIntegerTargets[30],"192465160",5200,int
//View_PhysicsFieldIntegerTargets[31],"0",5216,int
