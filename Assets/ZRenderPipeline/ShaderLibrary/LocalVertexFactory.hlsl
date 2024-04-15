#ifndef Z_RENDER_PIPELINE_LOCAL_VERTEX_FACTORY_INCLUDE
#define Z_RENDER_PIPELINE_LOCAL_VERTEX_FACTORY_INCLUDE


/**
 * Per-vertex inputs from bound vertex buffers
 */
struct FVertexFactoryInput
{
	float4	Position	: POSITION;

	float4  Color    : COLOR;

	float4  TangentX : TANGENT;
	float3  TangentZ : NORMAL;

	float2  TexCoords : TEXCOORD0;


//#if !MANUAL_VERTEX_FETCH
//	#if METAL_PROFILE
//		float3	TangentX	: ATTRIBUTE1;
//		// TangentZ.w contains sign of tangent basis determinant
//		float4	TangentZ	: ATTRIBUTE2;

//		float4	Color		: ATTRIBUTE3;
//	#else
//		half3	TangentX	: ATTRIBUTE1;
//		// TangentZ.w contains sign of tangent basis determinant
//		half4	TangentZ	: ATTRIBUTE2;

//		half4	Color		: ATTRIBUTE3;
//	#endif
//#endif

//#if NUM_MATERIAL_TEXCOORDS_VERTEX
//	#if !MANUAL_VERTEX_FETCH
//		#if GPUSKIN_PASS_THROUGH
//			// These must match GPUSkinVertexFactory.usf
//			float2	TexCoords[NUM_MATERIAL_TEXCOORDS_VERTEX] : ATTRIBUTE4;
//			#if NUM_MATERIAL_TEXCOORDS_VERTEX > 4
//				#error Too many texture coordinate sets defined on GPUSkin vertex input. Max: 4.
//			#endif
//		#else
//			#if NUM_MATERIAL_TEXCOORDS_VERTEX > 1
//				float4	PackedTexCoords4[NUM_MATERIAL_TEXCOORDS_VERTEX/2] : ATTRIBUTE4;
//			#endif
//			#if NUM_MATERIAL_TEXCOORDS_VERTEX == 1
//				float2	PackedTexCoords2 : ATTRIBUTE4;
//			#elif NUM_MATERIAL_TEXCOORDS_VERTEX == 3
//				float2	PackedTexCoords2 : ATTRIBUTE5;
//			#elif NUM_MATERIAL_TEXCOORDS_VERTEX == 5
//				float2	PackedTexCoords2 : ATTRIBUTE6;
//			#elif NUM_MATERIAL_TEXCOORDS_VERTEX == 7
//				float2	PackedTexCoords2 : ATTRIBUTE7;
//			#endif
//		#endif
//	#endif
//#elif USE_PARTICLE_SUBUVS && !MANUAL_VERTEX_FETCH
//	float2	TexCoords[1] : ATTRIBUTE4;
//#endif

//#if USE_INSTANCING && !MANUAL_VERTEX_FETCH
//	float4 InstanceOrigin : ATTRIBUTE8;  // per-instance random in w 
//	half4 InstanceTransform1 : ATTRIBUTE9;  // hitproxy.r + 256 * selected in .w
//	half4 InstanceTransform2 : ATTRIBUTE10; // hitproxy.g in .w
//	half4 InstanceTransform3 : ATTRIBUTE11; // hitproxy.b in .w
//	float4 InstanceLightmapAndShadowMapUVBias : ATTRIBUTE12; 
//#endif //USE_INSTANCING

//#if VF_USE_PRIMITIVE_SCENE_DATA
//	uint PrimitiveId : ATTRIBUTE13;
//#endif

//#if NEEDS_LIGHTMAP_COORDINATE && !MANUAL_VERTEX_FETCH
//	float2	LightMapCoordinate : ATTRIBUTE15;
//#endif

//#if USE_INSTANCING
//	uint InstanceId	: SV_InstanceID;
//#endif

//#if GPUSKIN_PASS_THROUGH || MANUAL_VERTEX_FETCH
//	uint VertexId : SV_VertexID;
//#endif
};


/** 
 * Caches intermediates that would otherwise have to be computed multiple times.  Avoids relying on the compiler to optimize out redundant operations.
 */
struct FVertexFactoryIntermediates
{
	half3x3 TangentToLocal;
	half3x3 TangentToWorld;
	half TangentToWorldSign;

	half4 Color;
//#if USE_INSTANCING
//		float4 InstanceOrigin;
//		float4 InstanceTransform1;
//		float4 InstanceTransform2;
//		float4 InstanceTransform3;

//		#if USE_INSTANCING_BONEMAP
//			float4 InstancePrevOrigin;
//			float4 InstancePrevTransform1;
//			float4 InstancePrevTransform2;
//			float4 InstancePrevTransform3;
//		#endif

//		float4 InstanceLightmapAndShadowMapUVBias;

//	// x = per-instance random, y = per-instance fade out amount, z = hide/show flag, w dither fade cutoff
//	float4 PerInstanceParams;
//#endif	// USE_INSTANCING
	uint PrimitiveId;

	float3 PreSkinPosition;
};


half3x3 CalcTangentToWorldNoScale(FVertexFactoryIntermediates Intermediates, half3x3 TangentToLocal)
{
	half3x3 LocalToWorld = (half3x3)GetObjectToWorldMatrix(); //GetLocalToWorld3x3(Intermediates.PrimitiveId);
	//half3 InvScale = GetPrimitiveData(Intermediates.PrimitiveId).InvNonUniformScaleAndDeterminantSign.xyz;
	//LocalToWorld[0] *= InvScale.x;
	//LocalToWorld[1] *= InvScale.y;
	//LocalToWorld[2] *= InvScale.z;
	return mul(LocalToWorld, TangentToLocal); 
}

half3x3 CalcTangentToLocal(FVertexFactoryInput Input, out float TangentSign)
{
	half3x3 Result;

	half4 TangentInputX = Input.TangentX;
	half3 TangentInputZ = Input.TangentZ;

	half4 TangentX = TangentInputX;
	half3 TangentZ = TangentInputZ;

	TangentSign = TangentX.w;

	half3 TangentY = cross(TangentX.xyz, TangentZ.xyz) * TangentSign;

	TangentX.xyz = cross(TangentY.xyz, TangentZ.xyz) * TangentSign;

	//Result = half3x3(TangentX.x, TangentY.x, TangentZ.x,
	//				   TangentX.y, TangentY.y, TangentZ.y,
	//				   TangentX.z, TangentY.z, TangentZ.z);


	return Result;

//#if MANUAL_VERTEX_FETCH
//	half3 TangentInputX = LocalVF.VertexFetch_PackedTangentsBuffer[2 * (LocalVF.VertexFetch_Parameters[VF_VertexOffset] + Input.VertexId) + 0].xyz;
//	half4 TangentInputZ = LocalVF.VertexFetch_PackedTangentsBuffer[2 * (LocalVF.VertexFetch_Parameters[VF_VertexOffset] + Input.VertexId) + 1].xyzw;
//#else
//	half3 TangentInputX = Input.TangentX;
//	half4 TangentInputZ = Input.TangentZ;
//#endif

//#ifdef GPUSKIN_PASS_THROUGH
//	half3 TangentX = TangentInputX;
//	half4 TangentZ = TangentInputZ;
//#else
//	half3 TangentX = TangentBias(TangentInputX);
//	half4 TangentZ = TangentBias(TangentInputZ);
//#endif

//	TangentSign = TangentZ.w;

//#if USE_SPLINEDEFORM
//	// Make slice rotation matrix, and use that to transform tangents
//	half3x3 SliceRot = CalcSliceRot(dot(Input.Position.xyz, SplineMeshDir));

//	TangentX = mul(TangentX, SliceRot);
//	TangentZ.xyz = mul(TangentZ.xyz, SliceRot);
//#endif	// USE_SPLINEDEFORM

//	// derive the binormal by getting the cross product of the normal and tangent
//	half3 TangentY = cross(TangentZ.xyz, TangentX) * TangentZ.w;
	
//	// Recalculate TangentX off of the other two vectors
//	// This corrects quantization error since TangentX was passed in as a quantized vertex input
//	// The error shows up most in specular off of a mesh with a smoothed UV seam (normal is smooth, but tangents vary across the seam)
//	Result[0] = cross(TangentY, TangentZ.xyz) * TangentZ.w;
//	Result[1] = TangentY;
//	Result[2] = TangentZ.xyz;

//	return Result;
}

half3x3 CalcTangentToWorld(FVertexFactoryIntermediates Intermediates, half3x3 TangentToLocal)
{
//#if USE_INSTANCING
//	half3x3 InstanceToWorld = mul(GetInstanceToLocal3x3(Intermediates), GetLocalToWorld3x3(Intermediates.PrimitiveId));
//	// remove scaling
//	InstanceToWorld[0] = normalize(InstanceToWorld[0]);
//	InstanceToWorld[1] = normalize(InstanceToWorld[1]);
//	InstanceToWorld[2] = normalize(InstanceToWorld[2]);
//	half3x3 TangentToWorld = mul(TangentToLocal, InstanceToWorld);
//#else
	half3x3 TangentToWorld = CalcTangentToWorldNoScale(Intermediates, TangentToLocal);
//#endif	// USE_INSTANCING
	return TangentToWorld;
}


FVertexFactoryIntermediates GetVertexFactoryIntermediates(FVertexFactoryInput Input)
{
	FVertexFactoryIntermediates Intermediates;

//#if VF_USE_PRIMITIVE_SCENE_DATA
//	Intermediates.PrimitiveId = Input.PrimitiveId;
//#else
	Intermediates.PrimitiveId = 0;
//#endif

//#if MANUAL_VERTEX_FETCH
//	Intermediates.Color = LocalVF.VertexFetch_ColorComponentsBuffer[(LocalVF.VertexFetch_Parameters[VF_VertexOffset] + Input.VertexId) & LocalVF.VertexFetch_Parameters[VF_ColorIndexMask_Index]] FMANUALFETCH_COLOR_COMPONENT_SWIZZLE; // Swizzle vertex color.
//#else
//	Intermediates.Color = Input.Color FCOLOR_COMPONENT_SWIZZLE; // Swizzle vertex color.
//#endif

	Intermediates.Color = Input.Color;

//#if USE_INSTANCING && MANUAL_VERTEX_FETCH && !USE_INSTANCING_BONEMAP
//	uint InstanceId = GetInstanceId(Input.InstanceId);
//	Intermediates.InstanceTransform1 = InstanceVF.VertexFetch_InstanceTransformBuffer[3 * (InstanceId + InstanceOffset) + 0];
//	Intermediates.InstanceTransform2 = InstanceVF.VertexFetch_InstanceTransformBuffer[3 * (InstanceId + InstanceOffset) + 1];
//	Intermediates.InstanceTransform3 = InstanceVF.VertexFetch_InstanceTransformBuffer[3 * (InstanceId + InstanceOffset) + 2];
//	Intermediates.InstanceOrigin = InstanceVF.VertexFetch_InstanceOriginBuffer[(InstanceId + InstanceOffset)];
//	Intermediates.InstanceLightmapAndShadowMapUVBias = InstanceVF.VertexFetch_InstanceLightmapBuffer[(InstanceId + InstanceOffset)];
//#elif MANUAL_VERTEX_FETCH && USE_INSTANCING_BONEMAP
//	uint InstanceIndex = VertexFetch_InstanceBoneMapBuffer[LocalVF.VertexFetch_Parameters[VF_VertexOffset] + Input.VertexId];
//	Intermediates.InstanceTransform1 = VertexFetch_InstanceTransformBuffer[4 * InstanceIndex + 0];
//	Intermediates.InstanceTransform2 = VertexFetch_InstanceTransformBuffer[4 * InstanceIndex + 1];
//	Intermediates.InstanceTransform3 = VertexFetch_InstanceTransformBuffer[4 * InstanceIndex + 2];
//	Intermediates.InstanceOrigin = VertexFetch_InstanceTransformBuffer[4 * InstanceIndex + 3];	

//	Intermediates.InstancePrevTransform1 = VertexFetch_InstancePrevTransformBuffer[4 * InstanceIndex + 0];
//	Intermediates.InstancePrevTransform2 = VertexFetch_InstancePrevTransformBuffer[4 * InstanceIndex + 1];
//	Intermediates.InstancePrevTransform3 = VertexFetch_InstancePrevTransformBuffer[4 * InstanceIndex + 2];
//	Intermediates.InstancePrevOrigin = VertexFetch_InstancePrevTransformBuffer[4 * InstanceIndex + 3];	

//	Intermediates.InstanceLightmapAndShadowMapUVBias = float4(0,0,0,0);
//#elif USE_INSTANCING
//	Intermediates.InstanceTransform1 = Input.InstanceTransform1;
//	Intermediates.InstanceTransform2 = Input.InstanceTransform2;
//	Intermediates.InstanceTransform3 = Input.InstanceTransform3;
//	Intermediates.InstanceOrigin = Input.InstanceOrigin;
//	Intermediates.InstanceLightmapAndShadowMapUVBias = Input.InstanceLightmapAndShadowMapUVBias;
//#endif

	float TangentSign;
	Intermediates.TangentToLocal = CalcTangentToLocal(Input, TangentSign);
	Intermediates.TangentToWorld = CalcTangentToWorld(Intermediates, Intermediates.TangentToLocal);
	Intermediates.TangentToWorldSign = TangentSign * GetOddNegativeScale();// * GetPrimitiveData(Intermediates.PrimitiveId).InvNonUniformScaleAndDeterminantSign.w;

//#if USE_INSTANCING && !USE_INSTANCING_BONEMAP
//	// x = per-instance random, y = per-instance fade out factor, z = zero or one depending of if it is shown at all, w is dither cutoff 

//	// PerInstanceParams.z stores a hide/show flag for this instance
//	float SelectedValue = GetInstanceSelected(Intermediates);
//	Intermediates.PerInstanceParams.x = GetInstanceRandom(Intermediates);
//	float3 InstanceLocation = TransformLocalToWorld(GetInstanceOrigin(Intermediates), Intermediates.PrimitiveId).xyz;
//	Intermediates.PerInstanceParams.y = 1.0 - saturate((length(InstanceLocation + ResolvedView.PreViewTranslation.xyz) - InstancingFadeOutParams.x) * InstancingFadeOutParams.y);
//	// InstancingFadeOutParams.z,w are RenderSelected and RenderDeselected respectively.
//	Intermediates.PerInstanceParams.z = InstancingFadeOutParams.z * SelectedValue + InstancingFadeOutParams.w * (1-SelectedValue);
//	#if USE_DITHERED_LOD_TRANSITION
//		float RandomLOD = InstancingViewZCompareZero.w * Intermediates.PerInstanceParams.x;
//		float ViewZZero = length(InstanceLocation - InstancingWorldViewOriginZero.xyz) + RandomLOD;
//		float ViewZOne = length(InstanceLocation - InstancingWorldViewOriginOne.xyz) + RandomLOD;
//		Intermediates.PerInstanceParams.w = 
//			dot(float3(ViewZZero.xxx > InstancingViewZCompareZero.xyz), InstancingViewZConstant.xyz) * InstancingWorldViewOriginZero.w +
//			dot(float3(ViewZOne.xxx > InstancingViewZCompareOne.xyz), InstancingViewZConstant.xyz) * InstancingWorldViewOriginOne.w;
//		Intermediates.PerInstanceParams.z *= abs(Intermediates.PerInstanceParams.w) < .999;
//	#else
//		Intermediates.PerInstanceParams.w = 0;
//	#endif
//#elif USE_INSTANCING && USE_INSTANCING_BONEMAP	
//	Intermediates.PerInstanceParams.x = 0;	
//	Intermediates.PerInstanceParams.y = 1;
//	Intermediates.PerInstanceParams.z = 1;
//	Intermediates.PerInstanceParams.w = 0;
//#endif	// USE_INSTANCING

//#if GPUSKIN_PASS_THROUGH
//	uint PreSkinVertexOffset = LocalVF.PreSkinBaseVertexIndex + Input.VertexId * 3;
//	Intermediates.PreSkinPosition.x = LocalVF.VertexFetch_PreSkinPositionBuffer[PreSkinVertexOffset + 0];
//	Intermediates.PreSkinPosition.y = LocalVF.VertexFetch_PreSkinPositionBuffer[PreSkinVertexOffset + 1];
//	Intermediates.PreSkinPosition.z = LocalVF.VertexFetch_PreSkinPositionBuffer[PreSkinVertexOffset + 2];
//#else
	Intermediates.PreSkinPosition = Input.Position.xyz;
//#endif

	return Intermediates;
}


/** Converts from vertex factory specific interpolants to a FMaterialPixelParameters, which is used by material inputs. */
FMaterialPixelParameters GetMaterialPixelParameters(FVertexFactoryInterpolantsVSToPS Interpolants, float4 SvPosition)
{
	// GetMaterialPixelParameters is responsible for fully initializing the result
	FMaterialPixelParameters Result = MakeInitializedMaterialPixelParameters();

#if NUM_TEX_COORD_INTERPOLATORS
	UNROLL
	for( int CoordinateIndex = 0; CoordinateIndex < NUM_TEX_COORD_INTERPOLATORS; CoordinateIndex++ )
	{
		Result.TexCoords[CoordinateIndex] = GetUV(Interpolants, CoordinateIndex);
	}
#endif

#if USE_PARTICLE_SUBUVS
	// Output TexCoord0 for when previewing materials that use ParticleSubUV.
	Result.Particle.SubUVCoords[0] = GetUV(Interpolants, 0);
	Result.Particle.SubUVCoords[1] = GetUV(Interpolants, 0);
#endif	// USE_PARTICLE_SUBUVS

	half3 TangentToWorld0 = GetTangentToWorld0(Interpolants).xyz;
	half4 TangentToWorld2 = GetTangentToWorld2(Interpolants);
	Result.UnMirrored = TangentToWorld2.w;

	Result.VertexColor = GetColor(Interpolants);

	// Required for previewing materials that use ParticleColor
	Result.Particle.Color = half4(1,1,1,1);
#if USE_INSTANCING
	Result.PerInstanceParams = Interpolants.PerInstanceParams;
#endif

	Result.TangentToWorld = AssembleTangentToWorld( TangentToWorld0, TangentToWorld2 );
#if USE_WORLDVERTEXNORMAL_CENTER_INTERPOLATION
	Result.WorldVertexNormal_Center = Interpolants.TangentToWorld2_Center.xyz;
#endif

#if LIGHTMAP_UV_ACCESS
#if NEEDS_LIGHTMAP_COORDINATE
	#if (ES3_1_PROFILE)
		// Not supported in pixel shader
		Result.LightmapUVs = float2(0, 0);
	#else
		Result.LightmapUVs = Interpolants.LightMapCoordinate.xy;
	#endif	// ES3_1_PROFILE
#endif	// NEEDS_LIGHTMAP_COORDINATE
#endif	// LIGHTMAP_UV_ACCESS

	Result.TwoSidedSign = 1;
	Result.PrimitiveId = GetPrimitiveId(Interpolants);

#if NEEDS_PARTICLE_LOCAL_TO_WORLD
	Result.Particle.ParticleToWorld = GetPrimitiveData(Result.PrimitiveId).LocalToWorld;
#endif

#if NEEDS_PARTICLE_WORLD_TO_LOCAL
	Result.Particle.WorldToParticle = GetPrimitiveData(Result.PrimitiveId).WorldToLocal;
#endif

	return Result;
}


/** Converts from vertex factory specific input to a FMaterialVertexParameters, which is used by vertex shader material inputs. */
FMaterialVertexParameters GetMaterialVertexParameters(FVertexFactoryInput Input, FVertexFactoryIntermediates Intermediates, float3 WorldPosition, half3x3 TangentToLocal)
{
	FMaterialVertexParameters Result = (FMaterialVertexParameters)0;
	Result.WorldPosition = WorldPosition;
	Result.VertexColor = Intermediates.Color;

	// does not handle instancing!
	Result.TangentToWorld = Intermediates.TangentToWorld;

//#if USE_INSTANCING
//	Result.InstanceLocalToWorld = mul(GetInstanceTransform(Intermediates), GetPrimitiveData(Intermediates.PrimitiveId).LocalToWorld);
//	Result.InstanceLocalPosition = Input.Position.xyz;
//	Result.PerInstanceParams = Intermediates.PerInstanceParams;

//	Result.InstanceId = GetInstanceId(Input.InstanceId); 
//	Result.InstanceOffset = InstanceOffset;

//	#if USE_INSTANCING_BONEMAP
//		// when using geometry collections, we can correctly compute velocities because we pass along previous transforms
//		Result.PrevFrameLocalToWorld = mul(GetInstancePrevTransform(Intermediates), GetPrimitiveData(Intermediates.PrimitiveId).PreviousLocalToWorld);
//	#else
//		// Assumes instance transform never change, which means per-instance
//		// motion will cause TAA and motion blur artifacts
//		Result.PrevFrameLocalToWorld = mul(GetInstanceTransform(Intermediates), GetPrimitiveData(Intermediates.PrimitiveId).PreviousLocalToWorld);
//	#endif // USE_INSTANCING_BONEMAP
//#else
	Result.PrevFrameLocalToWorld = GetPrimitiveData(Intermediates.PrimitiveId).PreviousLocalToWorld;
//#endif	// USE_INSTANCING

	Result.PreSkinnedPosition = Intermediates.PreSkinPosition.xyz;
	Result.PreSkinnedNormal = TangentToLocal._m02_m12_m22;// [2]; //TangentBias(Input.TangentZ.xyz);

//#if MANUAL_VERTEX_FETCH && NUM_MATERIAL_TEXCOORDS_VERTEX
		//const uint NumFetchTexCoords = LocalVF.VertexFetch_Parameters[VF_NumTexcoords_Index];
		//UNROLL
		//for (uint CoordinateIndex = 0; CoordinateIndex < NUM_MATERIAL_TEXCOORDS_VERTEX; CoordinateIndex++)
		//{
		//	// Clamp coordinates to mesh's maximum as materials can request more than are available
		//	uint ClampedCoordinateIndex = min(CoordinateIndex, NumFetchTexCoords-1);
		//	Result.TexCoords[CoordinateIndex] = LocalVF.VertexFetch_TexCoordBuffer[NumFetchTexCoords * (LocalVF.VertexFetch_Parameters[VF_VertexOffset] + Input.VertexId) + ClampedCoordinateIndex];
		//}
//#elif NUM_MATERIAL_TEXCOORDS_VERTEX
//		#if GPUSKIN_PASS_THROUGH
//			UNROLL
//			for (int CoordinateIndex = 0; CoordinateIndex < NUM_MATERIAL_TEXCOORDS_VERTEX; CoordinateIndex++)
//			{
//				Result.TexCoords[CoordinateIndex] = Input.TexCoords[CoordinateIndex].xy;
//			}
//		#else
//			#if NUM_MATERIAL_TEXCOORDS_VERTEX > 1
//				UNROLL
//				for(int CoordinateIndex = 0; CoordinateIndex < NUM_MATERIAL_TEXCOORDS_VERTEX-1; CoordinateIndex+=2)
//				{
//					Result.TexCoords[CoordinateIndex] = Input.PackedTexCoords4[CoordinateIndex/2].xy;
//					if( CoordinateIndex+1 < NUM_MATERIAL_TEXCOORDS_VERTEX )
//					{
//						Result.TexCoords[CoordinateIndex+1] = Input.PackedTexCoords4[CoordinateIndex/2].zw;
//					}
//				}
//			#endif	// NUM_MATERIAL_TEXCOORDS_VERTEX > 1
//			#if NUM_MATERIAL_TEXCOORDS_VERTEX % 2 == 1
//				Result.TexCoords[NUM_MATERIAL_TEXCOORDS_VERTEX-1] = Input.PackedTexCoords2;
//			#endif	// NUM_MATERIAL_TEXCOORDS_VERTEX % 2 == 1
//		#endif
//#endif  //MANUAL_VERTEX_FETCH && NUM_MATERIAL_TEXCOORDS_VERTEX

	Result.PrimitiveId = Intermediates.PrimitiveId;

//#if NEEDS_PARTICLE_LOCAL_TO_WORLD
//	Result.Particle.ParticleToWorld = GetPrimitiveData(Result.PrimitiveId).LocalToWorld;
//#endif

//#if NEEDS_PARTICLE_WORLD_TO_LOCAL
//	Result.Particle.WorldToParticle = GetPrimitiveData(Result.PrimitiveId).WorldToLocal;
//#endif

	return Result;
}

FVertexFactoryInterpolantsVSToPS VertexFactoryGetInterpolantsVSToPS(FVertexFactoryInput Input, FVertexFactoryIntermediates Intermediates, FMaterialVertexParameters VertexParameters)
{
	FVertexFactoryInterpolantsVSToPS Interpolants;

	// Initialize the whole struct to 0
	// Really only the last two components of the packed UVs have the opportunity to be uninitialized
	Interpolants = (FVertexFactoryInterpolantsVSToPS)0;

//#if NUM_TEX_COORD_INTERPOLATORS
//	float2 CustomizedUVs[NUM_TEX_COORD_INTERPOLATORS];
//	GetMaterialCustomizedUVs(VertexParameters, CustomizedUVs);
//	GetCustomInterpolators(VertexParameters, CustomizedUVs);
	
//	UNROLL
//	for (int CoordinateIndex = 0; CoordinateIndex < NUM_TEX_COORD_INTERPOLATORS; CoordinateIndex++)
//	{
//		SetUV(Interpolants, CoordinateIndex, CustomizedUVs[CoordinateIndex]);
//	}

//#elif NUM_MATERIAL_TEXCOORDS_VERTEX == 0 && USE_PARTICLE_SUBUVS
//	#if MANUAL_VERTEX_FETCH
//		SetUV(Interpolants, 0, LocalVF.VertexFetch_TexCoordBuffer[LocalVF.VertexFetch_Parameters[VF_NumTexcoords_Index] * (LocalVF.VertexFetch_Parameters[VF_VertexOffset] + Input.VertexId)]);
//	#else
//		SetUV(Interpolants, 0, Input.TexCoords[0]);
//	#endif
//#endif

//#if NEEDS_LIGHTMAP_COORDINATE
//	float2 LightMapCoordinate = 0;
//	float2 ShadowMapCoordinate = 0;
//	#if MANUAL_VERTEX_FETCH
//		float2 LightMapCoordinateInput = LocalVF.VertexFetch_TexCoordBuffer[LocalVF.VertexFetch_Parameters[VF_NumTexcoords_Index] * (LocalVF.VertexFetch_Parameters[VF_VertexOffset] + Input.VertexId) + LocalVF.VertexFetch_Parameters[FV_LightMapIndex_Index]];
//	#else
//		float2 LightMapCoordinateInput = Input.LightMapCoordinate;
//	#endif

//	uint LightmapDataIndex = 0;

//#if VF_USE_PRIMITIVE_SCENE_DATA
//	LightmapDataIndex = GetPrimitiveData(Intermediates.PrimitiveId).LightmapDataIndex + LocalVF.LODLightmapDataIndex;
//#endif

//	float4 LightMapCoordinateScaleBias = GetLightmapData(LightmapDataIndex).LightMapCoordinateScaleBias;

//	#if USE_INSTANCING
//		LightMapCoordinate = LightMapCoordinateInput * LightMapCoordinateScaleBias.xy + GetInstanceLightMapBias(Intermediates);
//	#else
//		LightMapCoordinate = LightMapCoordinateInput * LightMapCoordinateScaleBias.xy + LightMapCoordinateScaleBias.zw;
//	#endif
//	#if STATICLIGHTING_TEXTUREMASK
//		float4 ShadowMapCoordinateScaleBias = GetLightmapData(LightmapDataIndex).ShadowMapCoordinateScaleBias;

//		#if USE_INSTANCING
//			ShadowMapCoordinate = LightMapCoordinateInput * ShadowMapCoordinateScaleBias.xy + GetInstanceShadowMapBias(Intermediates);
//		#else
//			ShadowMapCoordinate = LightMapCoordinateInput * ShadowMapCoordinateScaleBias.xy + ShadowMapCoordinateScaleBias.zw;
//		#endif
//	#endif	// STATICLIGHTING_TEXTUREMASK

//	SetLightMapCoordinate(Interpolants, LightMapCoordinate, ShadowMapCoordinate);
//	SetLightmapDataIndex(Interpolants, LightmapDataIndex);
//#endif	// NEEDS_LIGHTMAP_COORDINATE

	SetTangents(Interpolants, Intermediates.TangentToWorld[0], Intermediates.TangentToWorld[2], Intermediates.TangentToWorldSign);
	SetColor(Interpolants, Intermediates.Color);
//#if USE_INSTANCING
//	Interpolants.PerInstanceParams = Intermediates.PerInstanceParams;
//#endif

//#if INSTANCED_STEREO
//	Interpolants.EyeIndex = 0;
//#endif

	SetPrimitiveId(Interpolants, Intermediates.PrimitiveId);

	return Interpolants;
}

/**
* Get the 3x3 tangent basis vectors for this vertex factory
* this vertex factory will calculate the binormal on-the-fly
*
* @param Input - vertex input stream structure
* @return 3x3 matrix
*/
half3x3 VertexFactoryGetTangentToLocal( FVertexFactoryInput Input, FVertexFactoryIntermediates Intermediates )
{
	return Intermediates.TangentToLocal;
}


// @return translated world position
float4 VertexFactoryGetWorldPosition(FVertexFactoryInput Input, FVertexFactoryIntermediates Intermediates)
{
	return mul(GetObjectToWorldMatrix(), float4(Input.Position, 1.0));

//#if USE_INSTANCING
//	return CalcWorldPosition(Input.Position, GetInstanceTransform(Intermediates), Intermediates.PrimitiveId) * Intermediates.PerInstanceParams.z;
//#else
//	return CalcWorldPosition(Input.Position, Intermediates.PrimitiveId);
//#endif	// USE_INSTANCING
}

#endif