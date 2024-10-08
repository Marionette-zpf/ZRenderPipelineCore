#ifndef Z_RENDER_PIPELINE_BASE_PASS_VERTEX_SHADER_INCLUDE
#define Z_RENDER_PIPELINE_BASE_PASS_VERTEX_SHADER_INCLUDE



/** Entry point for the base pass vertex shader. */
void Main(
	FVertexFactoryInput Input,
	//OPTIONAL_VertexID
	out FBasePassVSOutput Output
//#if USE_GLOBAL_CLIP_PLANE && !USING_TESSELLATION
//	, out float OutGlobalClipPlaneDistance : SV_ClipDistance
//#endif
//#if INSTANCED_STEREO
//	, uint InstanceId : SV_InstanceID
//	#if !MULTI_VIEW
//		, out float OutClipDistance : SV_ClipDistance1
//	#else
//		, out uint ViewportIndex : SV_ViewPortArrayIndex
//	#endif
//#endif
	)
{	
//#if INSTANCED_STEREO
//	const uint EyeIndex = GetEyeIndex(InstanceId);
//	ResolvedView = ResolveView(EyeIndex);
//	#if !MULTI_VIEW
//		OutClipDistance = 0.0;
//	#else
//		ViewportIndex = EyeIndex;
//	#endif
//#else
	//uint EyeIndex = 0;
	//ResolvedView = ResolveView();
//#endif

	FVertexFactoryIntermediates VFIntermediates = GetVertexFactoryIntermediates(Input);
	float4 WorldPositionExcludingWPO = VertexFactoryGetWorldPosition(Input, VFIntermediates);
	float4 WorldPosition = WorldPositionExcludingWPO;
	float4 ClipSpacePosition;

	float3x3 TangentToLocal = VertexFactoryGetTangentToLocal(Input, VFIntermediates);	
	FMaterialVertexParameters VertexParameters = GetMaterialVertexParameters(Input, VFIntermediates, WorldPosition.xyz, TangentToLocal);

	// Isolate instructions used for world position offset
	// As these cause the optimizer to generate different position calculating instructions in each pass, resulting in self-z-fighting.
	// This is only necessary for shaders used in passes that have depth testing enabled.
	{
		WorldPosition.xyz += GetMaterialWorldPositionOffset(VertexParameters);
	}

//#if USING_TESSELLATION
//	// We let the Domain Shader convert to post projection when tessellating
//	Output.Position = WorldPosition;	

//	#if USE_WORLD_POSITION_EXCLUDING_SHADER_OFFSETS
//		Output.BasePassInterpolants.WorldPositionExcludingWPO = WorldPositionExcludingWPO.xyz;
//	#endif
//#else
	{
		float4 RasterizedWorldPosition = VertexFactoryGetRasterizedWorldPosition(Input, VFIntermediates, WorldPosition);
	//#if ODS_CAPTURE
	//	float3 ODS = OffsetODS(RasterizedWorldPosition.xyz, ResolvedView.TranslatedWorldCameraOrigin.xyz, ResolvedView.StereoIPD);
	//	ClipSpacePosition = mul(float4(RasterizedWorldPosition.xyz + ODS, 1.0), ResolvedView.TranslatedWorldToClip);
	//#else
		ClipSpacePosition = mul(_View_TranslatedWorldToClip, RasterizedWorldPosition);// ResolvedView.TranslatedWorldToClip);// INVARIANT(mul(RasterizedWorldPosition, ResolvedView.TranslatedWorldToClip));
	//#endif
		Output.Position = ClipSpacePosition;// INVARIANT(ClipSpacePosition);
	}

	//#if INSTANCED_STEREO && !MULTI_VIEW
	//BRANCH
	//if (IsInstancedStereo())
	//{
	//	// Clip at the center of the screen
	//	OutClipDistance = dot(Output.Position, EyeClipEdge[EyeIndex]);

	//	// Scale to the width of a single eye viewport
	//	Output.Position.x *= 0.5 * ResolvedView.HMDEyePaddingOffset;

	//	// Shift to the eye viewport
	//	Output.Position.x += (EyeOffsetScale[EyeIndex] * Output.Position.w) * (1.0f - 0.5 * ResolvedView.HMDEyePaddingOffset);
	//}
	//#endif
	
//#if USE_GLOBAL_CLIP_PLANE
//	OutGlobalClipPlaneDistance = dot(ResolvedView.GlobalClippingPlane, float4(WorldPosition.xyz - ResolvedView.PreViewTranslation.xyz, 1));
//#endif
//	#if USE_WORLD_POSITION_EXCLUDING_SHADER_OFFSETS
//		Output.BasePassInterpolants.PixelPositionExcludingWPO = WorldPositionExcludingWPO.xyz;
//	#endif
//#endif	// USING_TESSELLATION

	Output.FactoryInterpolants = VertexFactoryGetInterpolants(Input, VFIntermediates, VertexParameters);

//#if INSTANCED_STEREO
//	#if USING_TESSELLATION	
//		Output.FactoryInterpolants.InterpolantsVSToPS.EyeIndex = EyeIndex;
//	#else
//		Output.FactoryInterpolants.EyeIndex = EyeIndex;
//	#endif
//#endif

//// Calculate the fog needed for translucency
//#if NEEDS_BASEPASS_VERTEX_FOGGING
//	#if BASEPASS_ATMOSPHERIC_FOG
//	Output.BasePassInterpolants.VertexFog = CalculateVertexAtmosphericFog(WorldPosition.xyz, ResolvedView.TranslatedWorldCameraOrigin);
//	#else
//	Output.BasePassInterpolants.VertexFog = CalculateHeightFog(WorldPosition.xyz - ResolvedView.TranslatedWorldCameraOrigin);
//	#endif

//	const float OneOverPreExposure = USE_PREEXPOSURE ? ResolvedView.OneOverPreExposure : 1.0f;

//#if PROJECT_SUPPORT_SKY_ATMOSPHERE && MATERIAL_IS_SKY==0 // Do not apply aerial perpsective on sky materials
//	if (ResolvedView.SkyAtmosphereApplyCameraAerialPerspectiveVolume > 0.0f)
//	{
//		// Sample the aerial perspective (AP). It is also blended under the VertexFog parameter.
//		Output.BasePassInterpolants.VertexFog = GetAerialPerspectiveLuminanceTransmittanceWithFogOver(
//			ResolvedView.RealTimeReflectionCapture, ResolvedView.SkyAtmosphereCameraAerialPerspectiveVolumeSizeAndInvSize,
//			Output.Position, WorldPosition.xyz*CM_TO_SKY_UNIT, ResolvedView.TranslatedWorldCameraOrigin*CM_TO_SKY_UNIT,
//			View.CameraAerialPerspectiveVolume, View.CameraAerialPerspectiveVolumeSampler,
//			ResolvedView.SkyAtmosphereCameraAerialPerspectiveVolumeDepthResolutionInv,
//			ResolvedView.SkyAtmosphereCameraAerialPerspectiveVolumeDepthResolution,
//			ResolvedView.SkyAtmosphereAerialPerspectiveStartDepthKm,
//			ResolvedView.SkyAtmosphereCameraAerialPerspectiveVolumeDepthSliceLengthKm,
//			ResolvedView.SkyAtmosphereCameraAerialPerspectiveVolumeDepthSliceLengthKmInv,
//			OneOverPreExposure, Output.BasePassInterpolants.VertexFog);
//	}
//#endif

//#if MATERIAL_ENABLE_TRANSLUCENCY_CLOUD_FOGGING

//	if (TranslucentBasePass.ApplyVolumetricCloudOnTransparent > 0.0f)
//	{
//		Output.BasePassInterpolants.VertexFog = GetCloudLuminanceTransmittanceOverFog(
//			Output.Position, WorldPosition.xyz, ResolvedView.TranslatedWorldCameraOrigin,
//			TranslucentBasePass.VolumetricCloudColor, TranslucentBasePass.VolumetricCloudColorSampler,
//			TranslucentBasePass.VolumetricCloudDepth, TranslucentBasePass.VolumetricCloudDepthSampler,
//			OneOverPreExposure, Output.BasePassInterpolants.VertexFog);
//	}

//#endif

//#endif

//#if TRANSLUCENCY_ANY_PERVERTEX_LIGHTING
//	float3 WorldPositionForVertexLightingTranslated = VertexFactoryGetPositionForVertexLighting(Input, VFIntermediates, WorldPosition.xyz);
//	float3 WorldPositionForVertexLighting = WorldPositionForVertexLightingTranslated - ResolvedView.PreViewTranslation.xyz;
//#endif

//#if TRANSLUCENCY_PERVERTEX_LIGHTING_VOLUME
//	float4 VolumeLighting;
//	float3 InterpolatedLighting = 0;

//	float3 InnerVolumeUVs;
//	float3 OuterVolumeUVs;
//	float FinalLerpFactor;

//	//@todo - get from VF
//	float3 LightingPositionOffset = 0;
//	ComputeVolumeUVs(WorldPositionForVertexLighting, LightingPositionOffset, InnerVolumeUVs, OuterVolumeUVs, FinalLerpFactor);

//	#if TRANSLUCENCY_LIGHTING_VOLUMETRIC_PERVERTEX_DIRECTIONAL
	
//		Output.BasePassInterpolants.AmbientLightingVector = GetAmbientLightingVectorFromTranslucentLightingVolume(InnerVolumeUVs, OuterVolumeUVs, FinalLerpFactor).xyz;
//		Output.BasePassInterpolants.DirectionalLightingVector = GetDirectionalLightingVectorFromTranslucentLightingVolume(InnerVolumeUVs, OuterVolumeUVs, FinalLerpFactor);

//	#elif TRANSLUCENCY_LIGHTING_VOLUMETRIC_PERVERTEX_NONDIRECTIONAL

//		Output.BasePassInterpolants.AmbientLightingVector = GetAmbientLightingVectorFromTranslucentLightingVolume(InnerVolumeUVs, OuterVolumeUVs, FinalLerpFactor).xyz;

//	#endif
//#elif TRANSLUCENCY_PERVERTEX_FORWARD_SHADING

//	float4 VertexLightingClipSpacePosition = mul(float4(WorldPositionForVertexLightingTranslated, 1), ResolvedView.TranslatedWorldToClip);
//	float2 SvPosition = (VertexLightingClipSpacePosition.xy / VertexLightingClipSpacePosition.w * float2(.5f, -.5f) + .5f) * ResolvedView.ViewSizeAndInvSize.xy;
//	uint GridIndex = ComputeLightGridCellIndex((uint2)(SvPosition* View.LightProbeSizeRatioAndInvSizeRatio.zw - ResolvedView.ViewRectMin.xy), VertexLightingClipSpacePosition.w, EyeIndex);
//	Output.BasePassInterpolants.VertexDiffuseLighting = GetForwardDirectLightingForVertexLighting(GridIndex, WorldPositionForVertexLighting, Output.Position.w, VertexParameters.TangentToWorld[2], EyeIndex);

//#endif

//	#if PRECOMPUTED_IRRADIANCE_VOLUME_LIGHTING && TRANSLUCENCY_ANY_PERVERTEX_LIGHTING
//		float3 BrickTextureUVs = ComputeVolumetricLightmapBrickTextureUVs(WorldPositionForVertexLighting);

//		#if TRANSLUCENCY_LIGHTING_VOLUMETRIC_PERVERTEX_NONDIRECTIONAL
//			FOneBandSHVectorRGB IrradianceSH = GetVolumetricLightmapSH1(BrickTextureUVs);
//			Output.BasePassInterpolants.VertexIndirectAmbient = float3(IrradianceSH.R.V, IrradianceSH.G.V, IrradianceSH.B.V);
//		#elif TRANSLUCENCY_LIGHTING_VOLUMETRIC_PERVERTEX_DIRECTIONAL
//			// Need to interpolate directional lighting so we can incorporate a normal in the pixel shader
//			FTwoBandSHVectorRGB IrradianceSH = GetVolumetricLightmapSH2(BrickTextureUVs);
//			Output.BasePassInterpolants.VertexIndirectSH[0] = IrradianceSH.R.V;
//			Output.BasePassInterpolants.VertexIndirectSH[1] = IrradianceSH.G.V;
//			Output.BasePassInterpolants.VertexIndirectSH[2] = IrradianceSH.B.V;
//		#endif
//	#endif

//#if WRITES_VELOCITY_TO_GBUFFER
//	{
//		float4 PrevTranslatedWorldPosition = float4(0, 0, 0, 1);
//		BRANCH
//		if (GetPrimitiveData(VFIntermediates.PrimitiveId).OutputVelocity > 0 || View.ForceDrawAllVelocities != 0)
//		{
//			PrevTranslatedWorldPosition = VertexFactoryGetPreviousWorldPosition( Input, VFIntermediates );	
//			VertexParameters = GetMaterialVertexParameters(Input, VFIntermediates, PrevTranslatedWorldPosition.xyz, TangentToLocal);
//			PrevTranslatedWorldPosition.xyz += GetMaterialPreviousWorldPositionOffset(VertexParameters);
	
//			#if !USING_TESSELLATION
//				PrevTranslatedWorldPosition = mul(float4(PrevTranslatedWorldPosition.xyz, 1), ResolvedView.PrevTranslatedWorldToClip);
//			#endif
//		}

//		#if USING_TESSELLATION
//			// We let the Domain Shader convert to post projection when tessellating
//			Output.BasePassInterpolants.VelocityPrevScreenPosition = PrevTranslatedWorldPosition;
//			#if WRITES_VELOCITY_TO_GBUFFER_USE_POS_INTERPOLATOR
//			Output.BasePassInterpolants.VelocityScreenPosition = WorldPosition;
//			#endif
//		#else
//			// compute the old screen pos with the old world position and the old camera matrix
//			Output.BasePassInterpolants.VelocityPrevScreenPosition = PrevTranslatedWorldPosition; 
//			#if WRITES_VELOCITY_TO_GBUFFER_USE_POS_INTERPOLATOR
//			Output.BasePassInterpolants.VelocityScreenPosition = ClipSpacePosition;
//			#endif
//		#endif	// USING_TESSELLATION
//	}
//#endif	// WRITES_VELOCITY_TO_GBUFFER

	//OutputVertexID( Output );
}


#endif