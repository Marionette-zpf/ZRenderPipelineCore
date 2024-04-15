#ifndef Z_RENDER_PIPELINE_DEFERRED_LIGHTING_COMMON_INCLUDE
#define Z_RENDER_PIPELINE_DEFERRED_LIGHTING_COMMON_INCLUDE

#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/HairBsdf.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/LightAccumulator.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/ShadingModels.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/CapsuleLight.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/CapsuleLightIntegrate.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/DynamicLightingCommon.hlsl"

/** 
 * Data about a single light.
 * Putting the light data in this struct allows the same lighting code to be used between standard deferred, 
 * Where many light properties are known at compile time, and tiled deferred, where all light properties have to be fetched from a buffer.
 */
// TODO: inherit or compose FLightShaderParameters
struct FDeferredLightData
{
	float3 Position;
	float  InvRadius;
	float3 Color;
	float  FalloffExponent;
	float3 Direction;
	float3 Tangent;
    float SoftSourceRadius;
	float2 SpotAngles;
	float SourceRadius;
	float SourceLength;
	float SpecularScale;
	float ContactShadowLength;
	/** Intensity of non-shadow-casting contact shadows */
	float ContactShadowNonShadowCastingIntensity;
	float2 DistanceFadeMAD;
	float4 ShadowMapChannelMask;
	/** Whether ContactShadowLength is in World Space or in Screen Space. */
	bool ContactShadowLengthInWS;
	/** Whether to use inverse squared falloff. */
	bool bInverseSquared;
	/** Whether this is a light with radial attenuation, aka point or spot light. */
	bool bRadialLight;
	/** Whether this light needs spotlight attenuation. */
	bool bSpotLight;
	bool bRectLight;
	/** Whether the light should apply shadowing. */
	uint ShadowedBits;
	float RectLightBarnCosAngle;
	float RectLightBarnLength;

	FHairTransmittanceData HairTransmittance;
};


void GetShadowTerms(FGBufferData GBuffer, FDeferredLightData LightData, float3 WorldPosition, float3 L, float4 LightAttenuation, float Dither, inout FShadowTerms Shadow)
{
	Shadow = (FShadowTerms)0;
	Shadow.SurfaceShadow = 1;
	Shadow.TransmissionShadow = 1;

//	float ContactShadowLength = 0.0f;
//	const float ContactShadowLengthScreenScale = View.ClipToView[1][1] * GBuffer.Depth;

//	BRANCH
//	if (LightData.ShadowedBits)
//	{
//		// Remapping the light attenuation buffer (see ShadowRendering.cpp)

//		// LightAttenuation: Light function + per-object shadows in z, per-object SSS shadowing in w, 
//		// Whole scene directional light shadows in x, whole scene directional light SSS shadows in y
//		// Get static shadowing from the appropriate GBuffer channel
//		float UsesStaticShadowMap = dot(LightData.ShadowMapChannelMask, float4(1, 1, 1, 1));
//		float StaticShadowing = lerp(1, dot(GBuffer.PrecomputedShadowFactors, LightData.ShadowMapChannelMask), UsesStaticShadowMap);

//		if (LightData.bRadialLight)
//		{
//			// Remapping the light attenuation buffer (see ShadowRendering.cpp)

//			Shadow.SurfaceShadow = LightAttenuation.z * StaticShadowing;
//			// SSS uses a separate shadowing term that allows light to penetrate the surface
//			//@todo - how to do static shadowing of SSS correctly?
//			Shadow.TransmissionShadow = LightAttenuation.w * StaticShadowing;

//			Shadow.TransmissionThickness = LightAttenuation.w;
//		}
//		else
//		{
//			// Remapping the light attenuation buffer (see ShadowRendering.cpp)
//			// Also fix up the fade between dynamic and static shadows
//			// to work with plane splits rather than spheres.

//			float DynamicShadowFraction = DistanceFromCameraFade(GBuffer.Depth, LightData, WorldPosition, View.WorldCameraOrigin);
//			// For a directional light, fade between static shadowing and the whole scene dynamic shadowing based on distance + per object shadows
//			Shadow.SurfaceShadow = lerp(LightAttenuation.x, StaticShadowing, DynamicShadowFraction);
//			// Fade between SSS dynamic shadowing and static shadowing based on distance
//			Shadow.TransmissionShadow = min(lerp(LightAttenuation.y, StaticShadowing, DynamicShadowFraction), LightAttenuation.w);

//			Shadow.SurfaceShadow *= LightAttenuation.z;
//			Shadow.TransmissionShadow *= LightAttenuation.z;

//			// Need this min or backscattering will leak when in shadow which cast by non perobject shadow(Only for directional light)
//			Shadow.TransmissionThickness = min(LightAttenuation.y, LightAttenuation.w);
//		}

//		FLATTEN
//		if (LightData.ShadowedBits > 1 && LightData.ContactShadowLength > 0)
//		{
//			ContactShadowLength = LightData.ContactShadowLength * (LightData.ContactShadowLengthInWS ? 1.0f : ContactShadowLengthScreenScale);
//		}
//	}

//#if SUPPORT_CONTACT_SHADOWS
//	if (LightData.ShadowedBits < 2 && (GBuffer.ShadingModelID == SHADINGMODELID_HAIR))
//	{
//		ContactShadowLength = 0.2 * ContactShadowLengthScreenScale;
//	}
//	// World space distance to cover eyelids and eyelashes but not beyond
//	if (GBuffer.ShadingModelID == SHADINGMODELID_EYE)
//	{
//		ContactShadowLength = 0.5;
		
//	}

//	#if MATERIAL_CONTACT_SHADOWS
//		ContactShadowLength = 0.2 * ContactShadowLengthScreenScale;
//	#endif

//	BRANCH
//	if (ContactShadowLength > 0.0)
//	{
//		float StepOffset = Dither - 0.5;
//		bool bHitCastContactShadow = false;
//		float HitDistance = ShadowRayCast( WorldPosition + View.PreViewTranslation, L, ContactShadowLength, 8, StepOffset, bHitCastContactShadow );
				
//		if ( HitDistance > 0.0 )
//		{
//			float ContactShadowOcclusion = bHitCastContactShadow ? 1.0 : LightData.ContactShadowNonShadowCastingIntensity;

//			// Exponential attenuation is not applied on hair/eye/SSS-profile here, as the hit distance (shading-point to blocker) is different from the estimated 
//			// thickness (closest-point-from-light to shading-point), and this creates light leaks. Instead we consider first hit as a blocker (old behavior)
//			BRANCH
//			if (ContactShadowOcclusion > 0.0 && 
//				IsSubsurfaceModel(GBuffer.ShadingModelID) && 
//				GBuffer.ShadingModelID != SHADINGMODELID_HAIR && 
//				GBuffer.ShadingModelID != SHADINGMODELID_EYE && 
//				GBuffer.ShadingModelID != SHADINGMODELID_SUBSURFACE_PROFILE)
//			{
//				// Reduce the intensity of the shadow similar to the subsurface approximation used by the shadow maps path
//				// Note that this is imperfect as we don't really have the "nearest occluder to the light", but this should at least
//				// ensure that we don't darken-out the subsurface term with the contact shadows
//				float Opacity = GBuffer.CustomData.a;
//				float Density = SubsurfaceDensityFromOpacity( Opacity );
//				ContactShadowOcclusion *= 1.0 - saturate( exp( -Density * HitDistance ) );
//			}

//			float ContactShadow = 1.0 - ContactShadowOcclusion;

//			Shadow.SurfaceShadow *= ContactShadow;
//			Shadow.TransmissionShadow *= ContactShadow;
//		}
		
//	}
//#endif

//	Shadow.HairTransmittance = LightData.HairTransmittance;
//	Shadow.HairTransmittance.OpaqueVisibility = Shadow.SurfaceShadow;
}

float GetLocalLightAttenuation(
	float3 WorldPosition, 
	FDeferredLightData LightData, 
	inout float3 ToLight, 
	inout float3 L)
{
	ToLight = LightData.Position - WorldPosition;
		
	float DistanceSqr = dot( ToLight, ToLight );
	L = ToLight * rsqrt( DistanceSqr );

	float LightMask;
	if (LightData.bInverseSquared)
	{
		LightMask = Square( saturate( 1 - Square( DistanceSqr * Square(LightData.InvRadius) ) ) );
	}
	else
	{
		LightMask = RadialAttenuation(ToLight * LightData.InvRadius, LightData.FalloffExponent);
	}

	if (LightData.bSpotLight)
	{
		LightMask *= SpotAttenuation(L, -LightData.Direction, LightData.SpotAngles);
	}

	if( LightData.bRectLight )
	{
		// Rect normal points away from point
		LightMask = dot( LightData.Direction, L ) < 0 ? 0 : LightMask;
	}

	return LightMask;
}



#define RECLIGHT_BARNDOOR 1
// Wrapper for FDeferredLightData for computing visible rect light (i.e., unoccluded by barn doors)
FRect GetRect(float3 ToLight, FDeferredLightData LightData)
{
	return GetRect(
		ToLight, 
		LightData.Direction, 
		LightData.Tangent, 
		LightData.SourceRadius, 
		LightData.SourceLength, 
		LightData.RectLightBarnCosAngle, 
		LightData.RectLightBarnLength,
		RECLIGHT_BARNDOOR);
}

FCapsuleLight GetCapsule( float3 ToLight, FDeferredLightData LightData )
{
	FCapsuleLight Capsule;
	Capsule.Length = LightData.SourceLength;
	Capsule.Radius = LightData.SourceRadius;
	Capsule.SoftRadius = LightData.SoftSourceRadius;
	Capsule.DistBiasSqr = 1;
	Capsule.LightPos[0] = ToLight - 0.5 * Capsule.Length * LightData.Tangent;
	Capsule.LightPos[1] = ToLight + 0.5 * Capsule.Length * LightData.Tangent;
	return Capsule;
}

/** Calculates lighting for a given position, normal, etc with a fully featured lighting model designed for quality. */
FDeferredLightingSplit GetDynamicLightingSplit(
	float3 WorldPosition, float3 CameraVector, FGBufferData GBuffer, float AmbientOcclusion, uint ShadingModelID, 
	FDeferredLightData LightData, float4 LightAttenuation, float Dither, uint2 SVPos, FRectTexture SourceTexture,
	inout float SurfaceShadow)
{
	FLightAccumulator LightAccumulator = (FLightAccumulator)0;

	float3 V = -CameraVector;
	float3 N = GBuffer.WorldNormal;
	//BRANCH if( GBuffer.ShadingModelID == SHADINGMODELID_CLEAR_COAT && CLEAR_COAT_BOTTOM_NORMAL)
	//{
	//	const float2 oct1 = ((float2(GBuffer.CustomData.a, GBuffer.CustomData.z) * 2) - (256.0/255.0)) + UnitVectorToOctahedron(GBuffer.WorldNormal);
	//	N = OctahedronToUnitVector(oct1);			
	//}
	
	float3 L = LightData.Direction;	// Already normalized
	float3 ToLight = L;
	
	float LightMask = 1;
	//if (LightData.bRadialLight) // bRadialLight false
	//{
	//	LightMask = GetLocalLightAttenuation( WorldPosition, LightData, ToLight, L );
	//}

	LightAccumulator.EstimatedCost += 0.3f;		// running the PixelShader at all has a cost

	BRANCH
	if( LightMask > 0 )
	{
		FShadowTerms Shadow;
		Shadow.SurfaceShadow = AmbientOcclusion;
		Shadow.TransmissionShadow = 1;
		Shadow.TransmissionThickness = 1;
		Shadow.HairTransmittance.OpaqueVisibility = 1;
		GetShadowTerms(GBuffer, LightData, WorldPosition, L, LightAttenuation, Dither, Shadow);
		SurfaceShadow = Shadow.SurfaceShadow;

		LightAccumulator.EstimatedCost += 0.3f;		// add the cost of getting the shadow terms

		BRANCH
		if( Shadow.SurfaceShadow + Shadow.TransmissionShadow > 0 )
		{
			const bool bNeedsSeparateSubsurfaceLightAccumulation = UseSubsurfaceProfile(GBuffer.ShadingModelID);
			float3 LightColor = LightData.Color;

		//#if NON_DIRECTIONAL_DIRECT_LIGHTING
		//	float Lighting;

		//	if( LightData.bRectLight )
		//	{
		//		FRect Rect = GetRect( ToLight, LightData );

		//		Lighting = IntegrateLight( Rect, SourceTexture);
		//	}
		//	else
		//	{
		//		FCapsuleLight Capsule = GetCapsule( ToLight, LightData );

		//		Lighting = IntegrateLight( Capsule, LightData.bInverseSquared );
		//	}

		//	float3 LightingDiffuse = Diffuse_Lambert( GBuffer.DiffuseColor ) * Lighting;
		//	LightAccumulator_AddSplit(LightAccumulator, LightingDiffuse, 0.0f, 0, LightColor * LightMask * Shadow.SurfaceShadow, bNeedsSeparateSubsurfaceLightAccumulation);
		//#else
			FDirectLighting Lighting;

			//if (LightData.bRectLight)
			//{
			//	FRect Rect = GetRect( ToLight, LightData );

			//	#if REFERENCE_QUALITY
			//		Lighting = IntegrateBxDF( GBuffer, N, V, Rect, Shadow, SourceTexture, SVPos );
			//	#else
			//		Lighting = IntegrateBxDF( GBuffer, N, V, Rect, Shadow, SourceTexture);
			//	#endif
			//}
			//else
			{
				FCapsuleLight Capsule = GetCapsule( ToLight, LightData );

				#if REFERENCE_QUALITY
					Lighting = IntegrateBxDF( GBuffer, N, V, Capsule, Shadow, SVPos );
				#else
					Lighting = IntegrateBxDF( GBuffer, N, V, Capsule, Shadow, LightData.bInverseSquared );
				#endif
			}

			Lighting.Specular *= LightData.SpecularScale;
				
			LightAccumulator_AddSplit( LightAccumulator, Lighting.Diffuse, Lighting.Specular, Lighting.Diffuse, LightColor * LightMask * Shadow.SurfaceShadow, bNeedsSeparateSubsurfaceLightAccumulation );
			LightAccumulator_AddSplit( LightAccumulator, Lighting.Transmission, 0.0f, Lighting.Transmission, LightColor * LightMask * Shadow.TransmissionShadow, bNeedsSeparateSubsurfaceLightAccumulation );

			LightAccumulator.EstimatedCost += 0.4f;		// add the cost of the lighting computations (should sum up to 1 form one light)

		//#endif
		}
	}

	return LightAccumulator_GetResultSplit(LightAccumulator);
}

float4 GetDynamicLighting(
	float3 WorldPosition, float3 CameraVector, FGBufferData GBuffer, float AmbientOcclusion, uint ShadingModelID, 
	FDeferredLightData LightData, float4 LightAttenuation, float Dither, uint2 SVPos, FRectTexture SourceTexture,
	inout float SurfaceShadow)
{
	FDeferredLightingSplit SplitLighting = GetDynamicLightingSplit(
		WorldPosition, CameraVector, GBuffer, AmbientOcclusion, ShadingModelID, 
		LightData, LightAttenuation, Dither, SVPos, SourceTexture,
		SurfaceShadow);

	return SplitLighting.SpecularLighting + SplitLighting.DiffuseLighting;
}


#endif