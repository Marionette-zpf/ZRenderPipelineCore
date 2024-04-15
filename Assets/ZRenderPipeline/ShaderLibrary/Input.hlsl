#ifndef Z_RENDER_PIPELINE_INPUT_INCLUDE
#define Z_RENDER_PIPELINE_INPUT_INCLUDE

 //   // scene texture struct.
 //   Texture2D _SceneTexturesStruct_SceneColorTexture;
 //   Texture2D _SceneTexturesStruct_SceneDepthTexture;

 //   Texture2D _SceneTexturesStruct_GBufferATexture;
 //   Texture2D _SceneTexturesStruct_GBufferBTexture;
 //   Texture2D _SceneTexturesStruct_GBufferCTexture;
 //   Texture2D _SceneTexturesStruct_GBufferDTexture;
 //   Texture2D _SceneTexturesStruct_GBufferETexture;
 //   Texture2D _SceneTexturesStruct_GBufferFTexture;
     
 //   Texture2D _SceneTexturesStruct_ScreenSpaceAOTexture;
 //   Texture2D _SceneTexturesStruct_CustomDepthTexture;

 //   Texture2D<uint2> _SceneTexturesStruct_CustomStencilTexture;

 //   // deferred light common.
 //   uniform float4 _DeferredLightUniforms_ShadowMapChannelMask;
 //   uniform float3 _DeferredLightUniforms_Position;
 //   uniform float3 _DeferredLightUniforms_Color;
 //   uniform float3 _DeferredLightUniforms_Direction;
 //   uniform float3 _DeferredLightUniforms_Tangent;

	//uniform float2 _DeferredLightUniforms_DistanceFadeMAD;
 //   uniform float2 _DeferredLightUniforms_SpotAngles;

	//uniform float _DeferredLightUniforms_ContactShadowLength;
	//uniform float _DeferredLightUniforms_ContactShadowNonShadowCastingIntensity;
	//uniform float _DeferredLightUniforms_VolumetricScatteringIntensity;
	//uniform float _PrePadding_DeferredLightUniforms_44;
	//uniform float _DeferredLightUniforms_InvRadius;
	//uniform float _DeferredLightUniforms_FalloffExponent;
	//uniform float _DeferredLightUniforms_SpecularScale;
	//uniform float _DeferredLightUniforms_SourceRadius;
	//uniform float _DeferredLightUniforms_SoftSourceRadius;
	//uniform float _DeferredLightUniforms_SourceLength;
	//uniform float _DeferredLightUniforms_RectLightBarnCosAngle;
	//uniform float _DeferredLightUniforms_RectLightBarnLength;

 //   uniform uint _DeferredLightUniforms_ShadowedBits;
	//uniform uint _DeferredLightUniforms_LightingChannelMask;

 //   Texture2D _DeferredLightUniforms_SourceTexture;


 //   // view.
 //   uniform uint _View_StateFrameIndexMod8;

 //   uniform float _View_MinRoughness;

 //   uniform float4 _View_BufferSizeAndInvSize;
 //   uniform float4 _View_TemporalAAParams;

 //   uniform float3 _View_WorldCameraOrigin;

 //   // -- matrixs.
 //   uniform float4x4 _View_TranslatedWorldToClip;

 //   uniform float4x4 _View_ScreenToWorld;
 //   uniform float4x4 _View_ScreenToTranslatedWorld;

 //   // -- editor params.
 //   uniform float4 _View_DiffuseOverrideParameter;
 //   uniform float4 _View_SpecularOverrideParameter;

 //   uniform float _View_bSubsurfacePostprocessEnabled;
 //   uniform float _View_bCheckerboardSubsurfaceProfileRendering;




 //   // custom.

 //   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


 //   uniform float4x4 _Matrix_Inv_View;
 //   uniform float4x4 _Matrix_Inv_Project;
 //   uniform float4x4 _Matrix_Inv_ViewProject;
	//uniform float4x4 _Matrix_Cur_No_AA_ViewProject;
 //   uniform float4x4 _Matrix_Pre_No_AA_ViewProject;

 //   uniform float4x4 _Matrix_ScreenToTranslatedWorld;
 //   uniform float4x4 _Matrix_ScreenToWorld;

 //   uniform int StateFrameIndexMod8;

 //   uniform float4 _CurentBufferSizeAndInverse;

 //   float ZSampleSceneDepth(float2 UV)
 //   {
 //       return SAMPLE_TEXTURE2D_X(_SceneTexturesStruct_SceneDepthTexture, sampler_PointClamp, UV).r;
 //   }

 //   float ZLoadSceneDepth(uint2 UV)
 //   {
 //       return LOAD_TEXTURE2D_X(_SceneTexturesStruct_SceneDepthTexture, UV).r;
 //   }

 //   float ZLinearSceneDepth(float2 UV)
 //   {
 //       float device_depth = ZSampleSceneDepth(UV);

 //       return LinearEyeDepth(device_depth, _ZBufferParams);
 //   }

 //   float3 ZGetWorldPos(float DeviceDepth, float2 ClipPosXY)
 //   {
 //       float3 ClipPos = float3(ClipPosXY.xy, DeviceDepth);

 //   #if UNITY_REVERSED_Z
 //       ClipPos.z = 1.0 - ClipPos.z;
 //   #endif

 //       ClipPos.z = 2.0 * ClipPos.z - 1.0;

	//	float4 PositionWS = mul(_Matrix_Inv_ViewProject, float4(ClipPos, 1.0));
	//		   PositionWS = PositionWS / PositionWS.w; 

 //       return PositionWS.xyz;
 //   }

 uniform uint _U_StateFrameIndexMod8;

#endif