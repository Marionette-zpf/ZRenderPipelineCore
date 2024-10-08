#ifndef Z_RENDER_PIPELINE_SSD_PUBLIC_INCLUDE
#define Z_RENDER_PIPELINE_SSD_PUBLIC_INCLUDE

#include "../Random.hlsl"
#include "../MonteCarlo.hlsl"
//#include "../SobolRandom.hlsl"


/** Bias used on GGX important sample when denoising, to remove part of the tail that creates a lot more noise. 
 *  NOTE: This assumes that GGX sampling is configured to use a polar mapping. */
#define GGX_IMPORTANT_SAMPLE_BIAS 0.1

/** Special value to be encoded in denoiser input when no ray has been shot. */
#define DENOISER_INVALID_HIT_DISTANCE -2.0

/** Special value to be encoded in denoiser input when no ray intersection has been found. */
#define DENOISER_MISS_HIT_DISTANCE -1.0

/** Special value to be encoded in denoiser input when no ray has been shot. */
#define DENOISER_INVALID_CONFUSION_FACTOR -1.0


/** Random generator used for 1 sample per pixel for denoiser input. */
float2 Rand1SPPDenoiserInput(uint2 PixelPos) // TODO(Denoiser): kill
{
	float2 E;

	#if 1
	{
		uint2 Random = Rand3DPCG16( int3( PixelPos, _U_StateFrameIndexMod8 ) ).xy;
		E = float2(Random) * rcp(65536.0); // equivalent to Hammersley16(0, 1, Random).
	}
	#elif 0
	{
		uint2 SobolFrame = ComputePixelUniqueSobolRandSample(PixelPos);
		E = SobolIndexToUniformUnitSquare(SobolFrame);
	}
	#else
		#error Miss-configured random generator.
	#endif

	return E;
}

/** Compute the factor to apply to inifinity bluring radius based on the sample's hit distance. */
float ComputeDenoiserConfusionFactor(bool bValid, float DistanceCameraToPixel, float ClosestHitDistance)
{
	return bValid ? (ClosestHitDistance / (DistanceCameraToPixel + ClosestHitDistance)) : DENOISER_INVALID_CONFUSION_FACTOR;
}


#endif