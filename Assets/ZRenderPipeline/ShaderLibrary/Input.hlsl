#ifndef Z_RENDER_PIPELINE_INPUT_INCLUDE
#define Z_RENDER_PIPELINE_INPUT_INCLUDE


#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// common texture parameters.
Texture2D _CameraTargetColor;
Texture2D _CameraTargetDepth;

Texture2D _GBufferA;
Texture2D _GBufferB;
Texture2D _GBufferC;
Texture2D _GBufferD;

Texture2D _VelocityTexture;


// common vectore parameters.
uniform float4 _V_BufferSizeAndInvSize;
uniform float4 _V_HZBUvFactorAndInvFactor;
uniform float4 _V_ScreenPositionScaleBias;

// common int parameters.
uniform uint _U_StateFrameIndexMod8;


// common matrix parameters.
uniform float4x4 _M_ViewMatrix;
uniform float4x4 _M_ProjMatrix;
uniform float4x4 _M_ViewToClip;
uniform float4x4 _M_WorldToClip;

uniform float4x4 _M_ScreenToWorldMatrix;
uniform float4x4 _M_ScreenToTranslatedWorldMatrix;
uniform float4x4 _M_TranslatedWorldToClip;
uniform float4x4 _M_TranslatedWorldToCameraView;







// scene texture struct.
Texture2D _SceneTexturesStruct_SceneColorTexture;
Texture2D _SceneTexturesStruct_SceneDepthTexture;

Texture2D _SceneTexturesStruct_GBufferATexture;
Texture2D _SceneTexturesStruct_GBufferBTexture;
Texture2D _SceneTexturesStruct_GBufferCTexture;
Texture2D _SceneTexturesStruct_GBufferDTexture;
Texture2D _SceneTexturesStruct_GBufferETexture;
Texture2D _SceneTexturesStruct_GBufferFTexture;
     
Texture2D _SceneTexturesStruct_ScreenSpaceAOTexture;
Texture2D _SceneTexturesStruct_CustomDepthTexture;

Texture2D<uint2> _SceneTexturesStruct_CustomStencilTexture;

// deferred light common.
uniform float4 _DeferredLightUniforms_ShadowMapChannelMask;
uniform float3 _DeferredLightUniforms_Position;
uniform float3 _DeferredLightUniforms_Color;
uniform float3 _DeferredLightUniforms_Direction;
uniform float3 _DeferredLightUniforms_Tangent;

uniform float2 _DeferredLightUniforms_DistanceFadeMAD;
uniform float2 _DeferredLightUniforms_SpotAngles;

uniform float _DeferredLightUniforms_ContactShadowLength;
uniform float _DeferredLightUniforms_ContactShadowNonShadowCastingIntensity;
uniform float _DeferredLightUniforms_VolumetricScatteringIntensity;
uniform float _PrePadding_DeferredLightUniforms_44;
uniform float _DeferredLightUniforms_InvRadius;
uniform float _DeferredLightUniforms_FalloffExponent;
uniform float _DeferredLightUniforms_SpecularScale;
uniform float _DeferredLightUniforms_SourceRadius;
uniform float _DeferredLightUniforms_SoftSourceRadius;
uniform float _DeferredLightUniforms_SourceLength;
uniform float _DeferredLightUniforms_RectLightBarnCosAngle;
uniform float _DeferredLightUniforms_RectLightBarnLength;

uniform uint _DeferredLightUniforms_ShadowedBits;
uniform uint _DeferredLightUniforms_LightingChannelMask;

Texture2D _DeferredLightUniforms_SourceTexture;


// view.
uniform uint _View_StateFrameIndexMod8;

uniform float _View_MinRoughness;

uniform float4 _View_BufferSizeAndInvSize;
uniform float4 _View_TemporalAAParams;

uniform float3 _View_WorldCameraOrigin;

// -- matrixs.
uniform float4x4 _View_TranslatedWorldToClip;

uniform float4x4 _View_ScreenToWorld;
uniform float4x4 _View_ScreenToTranslatedWorld;

// -- editor params.
uniform float4 _View_DiffuseOverrideParameter;
uniform float4 _View_SpecularOverrideParameter;

uniform float _View_bSubsurfacePostprocessEnabled;
uniform float _View_bCheckerboardSubsurfaceProfileRendering;

#endif