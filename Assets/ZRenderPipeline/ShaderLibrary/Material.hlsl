#ifndef Z_RENDER_PIPELINE_MATERIAL_INCLUDE
#define Z_RENDER_PIPELINE_MATERIAL_INCLUDE

#define COMPILER_HLSL 1

/** 
 * Parameters needed by pixel shader material inputs, related to Geometry.
 * These are independent of vertex factory.
 */
struct FMaterialPixelParameters
{
#if NUM_TEX_COORD_INTERPOLATORS
	float2 TexCoords[NUM_TEX_COORD_INTERPOLATORS];
#endif

	/** Interpolated vertex color, in linear color space. */
	half4 VertexColor;

	/** Normalized world space normal. */
	half3 WorldNormal;
	
	/** Normalized world space tangent. */
	half3 WorldTangent;

	/** Normalized world space reflected camera vector. */
	half3 ReflectionVector;

	/** Normalized world space camera vector, which is the vector from the point being shaded to the camera position. */
	half3 CameraVector;

	/** World space light vector, only valid when rendering a light function. */
	half3 LightVector;

	/**
	 * Like SV_Position (.xy is pixel position at pixel center, z:DeviceZ, .w:SceneDepth)
	 * using shader generated value SV_POSITION
	 * Note: this is not relative to the current viewport.  RelativePixelPosition = MaterialParameters.SvPosition.xy - View.ViewRectMin.xy;
	 */
	float4 SvPosition;
		
	/** Post projection position reconstructed from SvPosition, before the divide by W. left..top -1..1, bottom..top -1..1  within the viewport, W is the SceneDepth */
	float4 ScreenPosition;

	half UnMirrored;

	half TwoSidedSign;

	/**
	 * Orthonormal rotation-only transform from tangent space to world space
	 * The transpose(TangentToWorld) is WorldToTangent, and TangentToWorld[2] is WorldVertexNormal
	 */
	half3x3 TangentToWorld;

//#if USE_WORLDVERTEXNORMAL_CENTER_INTERPOLATION
//	/** World vertex normal interpolated at the pixel center that is safe to use for derivatives. */
//	half3 WorldVertexNormal_Center;
//#endif

	/** 
	 * Interpolated worldspace position of this pixel
	 * todo: Make this TranslatedWorldPosition and also rename the VS/DS/HS WorldPosition to be TranslatedWorldPosition
	 */
	float3 AbsoluteWorldPosition;

	/** 
	 * Interpolated worldspace position of this pixel, centered around the camera
	 */
	float3 WorldPosition_CamRelative;

	/** 
	 * Interpolated worldspace position of this pixel, not including any world position offset or displacement.
	 * Only valid if shader is compiled with NEEDS_WORLD_POSITION_EXCLUDING_SHADER_OFFSETS, otherwise just contains 0
	 */
	float3 WorldPosition_NoOffsets;

	/** 
	 * Interpolated worldspace position of this pixel, not including any world position offset or displacement.
	 * Only valid if shader is compiled with NEEDS_WORLD_POSITION_EXCLUDING_SHADER_OFFSETS, otherwise just contains 0
	 */
	float3 WorldPosition_NoOffsets_CamRelative;

	/** Offset applied to the lighting position for translucency, used to break up aliasing artifacts. */
	half3 LightingPositionOffset;

	float AOMaterialMask;

//#if LIGHTMAP_UV_ACCESS
//	float2	LightmapUVs;
//#endif

//#if USE_INSTANCING
//	half4 PerInstanceParams;
//#endif

	// Index into View.PrimitiveSceneData
	uint PrimitiveId;

//	// Actual primitive Id
//#if IS_HAIR_FACTORY
//	uint	HairPrimitiveId;	// Control point ID
//	float2	HairPrimitiveUV;	// U: parametric distance between the two surrounding control point. V: parametric distance along hair width
//#endif

	/** Per-particle properties. Only valid for particle vertex factories. */
	FMaterialParticleParameters Particle;

//#if ES3_1_PROFILE
//	float4 LayerWeights;
//#endif

//#if TEX_COORD_SCALE_ANALYSIS
//	/** Parameters used by the MaterialTexCoordScales shader. */
//	FTexCoordScalesParams TexCoordScalesParams;
//#endif

//#if POST_PROCESS_MATERIAL && (FEATURE_LEVEL <= FEATURE_LEVEL_ES3_1)
//	/** Used in mobile custom pp material to preserve original SceneColor Alpha */
//	half BackupSceneColorAlpha;
//#endif

#if COMPILER_HLSL
	// Workaround for "error X3067: 'GetObjectWorldPosition': ambiguous function call"
	// Which happens when FMaterialPixelParameters and FMaterialVertexParameters have the same number of floats with the HLSL compiler ver 9.29.952.3111
	// Function overload resolution appears to identify types based on how many floats / ints / etc they contain
	uint Dummy;
#endif

//#if NUM_VIRTUALTEXTURE_SAMPLES || LIGHTMAP_VT_ENABLED
//	FVirtualTextureFeedbackParams VirtualTextureFeedback;
//#endif

//#if WATER_MESH_FACTORY
//	uint WaterWaveParamIndex;
//#endif

//#if CLOUD_LAYER_PIXEL_SHADER
//	float CloudSampleAltitude;
//	float CloudSampleAltitudeInLayer;
//	float CloudSampleNormAltitudeInLayer;
//	float3 VolumeSampleConservativeDensity;
//	float ShadowSampleDistance;
//#endif
};


FMaterialPixelParameters MakeInitializedMaterialPixelParameters()
{
	FMaterialPixelParameters MPP;
	MPP = (FMaterialPixelParameters)0;
	MPP.TangentToWorld = float3x3(1,0,0,0,1,0,0,0,1);
	return MPP;
}


/** 
 * Parameters needed by vertex shader material inputs.
 * These are independent of vertex factory.
 */
struct FMaterialVertexParameters
{
	// Position in the translated world (VertexFactoryGetWorldPosition).
	// Previous position in the translated world (VertexFactoryGetPreviousWorldPosition) if
	//    computing material's output for previous frame (See {BasePassVertex,Velocity}Shader.usf).
	float3 WorldPosition;
	// TangentToWorld[2] is WorldVertexNormal
	half3x3 TangentToWorld;
#if USE_INSTANCING
	/** Per-instance properties. */
	float4x4 InstanceLocalToWorld;
	float3 InstanceLocalPosition;
	float4 PerInstanceParams;
	uint InstanceId;
	uint InstanceOffset;

#elif IS_MESHPARTICLE_FACTORY 
	/** Per-particle properties. */
	float4x4 InstanceLocalToWorld;
#endif
	// If either USE_INSTANCING or (IS_MESHPARTICLE_FACTORY && FEATURE_LEVEL >= FEATURE_LEVEL_SM4)
	// is true, PrevFrameLocalToWorld is a per-instance transform
	float4x4 PrevFrameLocalToWorld;

	float3 PreSkinnedPosition;
	float3 PreSkinnedNormal;

//#if GPU_SKINNED_MESH_FACTORY
//	float3 PreSkinOffset;
//	float3 PostSkinOffset;
//#endif

	half4 VertexColor;
#if NUM_MATERIAL_TEXCOORDS_VERTEX
	float2 TexCoords[NUM_MATERIAL_TEXCOORDS_VERTEX];
	//#if ES3_1_PROFILE
	//float2 TexCoordOffset; // Offset for UV localization for large UV values
	//#endif
#endif

	/** Per-particle properties. Only valid for particle vertex factories. */
	FMaterialParticleParameters Particle;

	// Index into View.PrimitiveSceneData
	uint PrimitiveId;

//#if WATER_MESH_FACTORY
//	uint WaterWaveParamIndex;
//#endif
};

#endif