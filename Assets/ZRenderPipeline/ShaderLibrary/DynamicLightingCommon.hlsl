#ifndef Z_RENDER_PIPELINE_DYNAMIC_LIGHTING_COMMON_INCLUDE
#define Z_RENDER_PIPELINE_DYNAMIC_LIGHTING_COMMON_INCLUDE

#include "Assets/ZRenderPipeline/ShaderLibrary/Input.hlsl"

// Copyright Epic Games, Inc. All Rights Reserved.

/*=============================================================================
	DynamicLightingCommon.usf: Contains functions shared by dynamic light shaders.
=============================================================================*/

/** 
 * Returns a radial attenuation factor for a point light.  
 * WorldLightVector is the vector from the position being shaded to the light, divided by the radius of the light. 
 */
float RadialAttenuationMask(float3 WorldLightVector)
{
	float NormalizeDistanceSquared = dot(WorldLightVector, WorldLightVector);
	return 1.0f - saturate(NormalizeDistanceSquared);
}
float RadialAttenuation(float3 WorldLightVector, half FalloffExponent)
{
	// UE3 (fast, but now we not use the default of 2 which looks quite bad):
	return pow(RadialAttenuationMask(WorldLightVector), FalloffExponent);

	// new UE4 (more physically correct but slower and has a more noticable cutoff ring in the dark):
	// AttenFunc(x) = 1 / (x * x + 1)
	// derived: InvAttenFunc(y) = sqrtf(1 / y - 1)
	// FalloffExponent is ignored
	// the following code is a normalized (scaled and biased f(0)=1 f(1)=0) and optimized
/*
	// light less than x % is considered 0
	// 20% produces a bright sphere, 5 % is ok for performance, 8% looks close to the old one, smaller numbers would be more realistic but then the attenuation radius also should be increased.
	// we can expose CutoffPercentage later, alternatively we also can compute the attenuation radius from the CutoffPercentage and the brightness
	const float CutoffPercentage = 5.0f;  
	    
	float CutoffFraction = CutoffPercentage * 0.01f;  

	// those could be computed on C++ side
	float PreCompX = 1.0f - CutoffFraction;
	float PreCompY = CutoffFraction;
	float PreCompZ = CutoffFraction / PreCompX;

	return (1 / ( NormalizeDistanceSquared * PreCompX + PreCompY) - 1) * PreCompZ;
*/
}


/** 
 * Calculates attenuation for a spot light.
 * L normalize vector to light. 
 * SpotDirection is the direction of the spot light.
 * SpotAngles.x is CosOuterCone, SpotAngles.y is InvCosConeDifference. 
 */
float SpotAttenuationMask(float3 L, float3 SpotDirection, float2 SpotAngles)
{
	return saturate((dot(L, -SpotDirection) - SpotAngles.x) * SpotAngles.y);
}
float SpotAttenuation(float3 L, float3 SpotDirection, float2 SpotAngles)
{
	float ConeAngleFalloff = Square(SpotAttenuationMask(L, SpotDirection, SpotAngles));
	return ConeAngleFalloff;
}

/** Calculates radial and spot attenuation. */
float CalcLightAttenuation(float3 WorldPosition, out float3 WorldLightVector)
{
	WorldLightVector = _DeferredLightUniforms_Direction;
	float DistanceAttenuation = 1;

#if RADIAL_ATTENUATION
	WorldLightVector = DeferredLightUniforms.Position - WorldPosition;
	float DistanceSqr = dot( WorldLightVector, WorldLightVector );

	// TODO Line segment falloff

	// Sphere falloff (technically just 1/d2 but this avoids inf)
	DistanceAttenuation = 1 / ( DistanceSqr + 1 );
	
	float LightRadiusMask = Square( saturate( 1 - Square( DistanceSqr * DeferredLightUniforms.InvRadius * DeferredLightUniforms.InvRadius ) ) );
	DistanceAttenuation *= LightRadiusMask;
	
#if !INVERSE_SQUARED_FALLOFF
	DistanceAttenuation = RadialAttenuation(WorldLightVector * DeferredLightUniforms.InvRadius, DeferredLightUniforms.FalloffExponent);
#endif
#endif

	float SpotFalloff = 1;
	#if RADIAL_ATTENUATION
		SpotFalloff = SpotAttenuation( normalize(WorldLightVector), -DeferredLightUniforms.Direction, DeferredLightUniforms.SpotAngles);
	#endif

	return SpotFalloff * DistanceAttenuation;
}

float3 GetNormalizedLightVector(float3 WorldPosition)
{
	// assumed to be normalized
	float3 Ret = _DeferredLightUniforms_Direction;

	#if RADIAL_ATTENUATION
		Ret = normalize(DeferredLightUniforms.Position - WorldPosition);
	#endif

	return Ret;
}

float GetLightInfluenceMask(float3 WorldPosition)
{
	float LightMask = 1;

	if (_DeferredLightUniforms_InvRadius > 0)
	{
		float3 ToLight = _DeferredLightUniforms_Position - WorldPosition;
		float DistanceSqr = dot(ToLight, ToLight);
		float3 L = ToLight * rsqrt(DistanceSqr);

		if (_DeferredLightUniforms_FalloffExponent == 0)
		{
			LightMask = saturate(1 - Square(DistanceSqr * Square(_DeferredLightUniforms_InvRadius)));
			//LightRadiusMask = Square(LightRadiusMask); No need to square since we are only doing a binary comparison below (and a saturate is used)
		}
		else
		{
			LightMask = RadialAttenuationMask(ToLight * _DeferredLightUniforms_InvRadius);
		}

		if (_DeferredLightUniforms_SpotAngles.x > -2.0f)
		{
			LightMask *= SpotAttenuationMask(L, -_DeferredLightUniforms_Direction, _DeferredLightUniforms_SpotAngles);
		}
	}

	return LightMask > 0.0f ? 1.0f : 0.0f;
}

#endif