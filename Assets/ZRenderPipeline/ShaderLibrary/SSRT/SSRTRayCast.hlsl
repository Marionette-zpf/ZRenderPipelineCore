#ifndef Z_RENDER_PIPELINE_SSRT_RAY_CAST_INCLUDE
#define Z_RENDER_PIPELINE_SSRT_RAY_CAST_INCLUDE


// Number of sample batched at same time.
#define SSRT_SAMPLE_BATCH_SIZE 4

#ifndef IS_SSGI_SHADER
#define IS_SSGI_SHADER 0
#endif

#include "../Common.hlsl"	

#define SSGI_TRACE_CONE 0


#ifndef DEBUG_SSRT
	#define DEBUG_SSRT 0
#endif

#if DEBUG_SSRT

RWTexture2D<float4> ScreenSpaceRayTracingDebugOutput;


void PrintSample(
	float4 HZBUvFactorAndInvFactor, 
	float2 HZBUV,
	float4 DebugColor)
{	
	HZBUV.xy *= HZBUvFactorAndInvFactor.zw;

	uint2 Position = HZBUV.xy * View.ViewSizeAndInvSize.xy;

	ScreenSpaceRayTracingDebugOutput[Position] = DebugColor;
}

#endif


/** Return float multiplier to scale RayStepScreen such that it clip it right at the edge of the screen. */
float GetStepScreenFactorToClipAtScreenEdge(float2 RayStartScreen, float2 RayStepScreen)
{
	// Computes the scale down factor for RayStepScreen required to fit on the X and Y axis in order to clip it in the viewport
	const float RayStepScreenInvFactor = 0.5 * length(RayStepScreen);
	const float2 S = 1 - max(abs(RayStepScreen + RayStartScreen * RayStepScreenInvFactor) - RayStepScreenInvFactor, 0.0f) / abs(RayStepScreen);

	// Rescales RayStepScreen accordingly
	const float RayStepFactor = min(S.x, S.y) / RayStepScreenInvFactor;

	return RayStepFactor;
}


/** Structure that represent a ray to be shot in screen space. */
struct FSSRTRay
{
	float3 RayStartScreen;
	float3 RayStepScreen;

	float CompareTolerance;
};

/** Compile a ray for screen space ray casting. */
FSSRTRay InitScreenSpaceRayFromWorldSpace(
	float3 RayOriginTranslatedWorld,
	float3 WorldRayDirection,
	float SceneDepth)
{
	float4 RayStartClip	= mul(_M_TranslatedWorldToClip, float4(RayOriginTranslatedWorld, 1));
	float4 RayEndClip = mul(_M_TranslatedWorldToClip, float4(RayOriginTranslatedWorld + WorldRayDirection * SceneDepth, 1));

	float3 RayStartScreen = RayStartClip.xyz * rcp(RayStartClip.w);
	float3 RayEndScreen = RayEndClip.xyz * rcp(RayEndClip.w);

	float4 RayDepthClip = RayStartClip + mul(_M_ViewToClip, float4(0, 0, SceneDepth, 0));
	float3 RayDepthScreen = RayDepthClip.xyz * rcp(RayDepthClip.w);

	FSSRTRay Ray;
	Ray.RayStartScreen = RayStartScreen;
	Ray.RayStepScreen = RayEndScreen - RayStartScreen;
	
	Ray.RayStepScreen *= GetStepScreenFactorToClipAtScreenEdge(RayStartScreen.xy, Ray.RayStepScreen.xy);

	// TODO
	//#if IS_SSGI_SHADER
	//	Ray.CompareTolerance = max(abs(Ray.RayStepScreen.z), (RayStartScreen.z - RayDepthScreen.z) * 2);
	//#else
		Ray.CompareTolerance = max(abs(Ray.RayStepScreen.z), (RayStartScreen.z - RayDepthScreen.z) * 4);
		//Ray.CompareTolerance = Ray.CompareTolerance * lerp(0.2, 1.0, SceneDepth * 0.01);//
	//#endif

	return Ray;
} // InitScreenSpaceRayFromWorldSpace()

//float4 ApplyProjMatrix(float4 V)
//{
//	return float4(
//		V.xy * GetCotanHalfFieldOfView(),
//		V.z * _M_ViewToClip[2][2] + V.w * _M_ViewToClip[3][2],
//		V.z);
//}

///** Compile a ray for screen space ray casting, but avoiding the computation of translated world position. */
//// TODO: passdown ViewRayDirection instead?
//FSSRTRay InitScreenSpaceRay(
//	float2 ScreenPos,
//	float DeviceZ,
//	float3 ViewRayDirection)
//{
//	float3 RayStartScreen = float3(ScreenPos, DeviceZ);

//	// float3 RayStartClip = float4(ScreenPos, DeviceZ, 1) * SceneDepth;
//	// float4 RayEndClip = RayStartClip + mul(float4(WorldRayDirection * SceneDepth, 0), View.TranslatedWorldToClip);
	
//	// float4 RayEndClip = mul(float4(WorldRayDirection, 0), View.TranslatedWorldToClip) + float4(RayStartScreen, 1); // * SceneDepth;
//	float4 RayEndClip = ApplyProjMatrix(float4(ViewRayDirection, 0)) + float4(RayStartScreen, 1); // * SceneDepth;

//	float3 RayEndScreen = RayEndClip.xyz * rcp(RayEndClip.w);

//	// float3 RayStartClip = float4(ScreenPos, DeviceZ, 1) * SceneDepth;
//	// float4 RayDepthClip = RayStartClip + mul(float4(0, 0, SceneDepth, 0), View.ViewToClip);
//	// RayDepthClip.w = 2.0 * SceneDepth;
//	// float3 RayDepthScreen = RayDepthClip.xyz * rcp(RayDepthClip.w);
//	float3 RayDepthScreen = 0.5 * (_M_ViewToClip, RayStartScreen + mul(float4(0, 0, 1, 0)).xyz);

//	FSSRTRay Ray;
//	Ray.RayStartScreen = RayStartScreen;
//	Ray.RayStepScreen = RayEndScreen - RayStartScreen;
	
//	Ray.RayStepScreen *= GetStepScreenFactorToClipAtScreenEdge(RayStartScreen.xy, Ray.RayStepScreen.xy);

//	// TODO
//	#if IS_SSGI_SHADER
//		Ray.CompareTolerance = max(abs(Ray.RayStepScreen.z), (RayStartScreen.z - RayDepthScreen.z) * 2);
//	#else
//		Ray.CompareTolerance = max(abs(Ray.RayStepScreen.z), (RayStartScreen.z - RayDepthScreen.z) * 4);
//	#endif

//	return Ray;
//} // InitScreenSpaceRay()

/** Cast a screen space ray. */
bool CastScreenSpaceRay(
	Texture2D Texture, SamplerState Sampler,
	FSSRTRay Ray,
	float Roughness,
	uint NumSteps, float StepOffset,
	float4 HZBUvFactorAndInvFactor, 
	bool bDebugPrint,
	out float3 OutHitUVz,
	out float Level)
{
	const float3 RayStartScreen = Ray.RayStartScreen;
	float3 RayStepScreen = Ray.RayStepScreen;

	float3 RayStartUVz = float3( (RayStartScreen.xy * float2( 0.5, 0.5 ) + 0.5) * HZBUvFactorAndInvFactor.xy, RayStartScreen.z );
	float3 RayStepUVz  = float3(  RayStepScreen.xy  * float2( 0.5, 0.5 )		* HZBUvFactorAndInvFactor.xy, RayStepScreen.z );
	
	const float Step = 1.0 / NumSteps;
	float CompareTolerance = Ray.CompareTolerance * Step;
	
	float LastDiff = 0;
	Level = 1;

	//StepOffset = View.GeneralPurposeTweak;

	RayStepUVz *= Step;
	float3 RayUVz = RayStartUVz + RayStepUVz * StepOffset;
	//#if IS_SSGI_SHADER && SSGI_TRACE_CONE
	//	RayUVz = RayStartUVz;
	//#endif
	
	//#if DEBUG_SSRT
	//{
	//	if (bDebugPrint)
	//		PrintSample(HZBUvFactorAndInvFactor, RayStartUVz.xy, float4(1, 0, 0, 1));
	//}
	//#endif
	
	float4 MultipleSampleDepthDiff;
	bool4 bMultipleSampleHit; // TODO: Might consumes VGPRS if bug in compiler.
	bool bFoundAnyHit = false;
	
	//#if IS_SSGI_SHADER && SSGI_TRACE_CONE
	//	const float ConeAngle = PI / 4;
	//	const float d = 1;
	//	const float r = d * sin(0.5 * ConeAngle);
	//	const float Exp = 1.6; //(d + r) / (d - r);
	//	const float ExpLog2 = log2(Exp);
	//	const float MaxPower = exp2(log2(Exp) * (NumSteps + 1.0)) - 0.9;

	//	{
	//		//Level = 2;
	//	}
	//#endif

	uint i;

	LOOP
	for (i = 0; i < NumSteps; i += SSRT_SAMPLE_BATCH_SIZE)
	{
		float2 SamplesUV[SSRT_SAMPLE_BATCH_SIZE];
		float4 SamplesZ;
		float4 SamplesMip;

		// Compute the sample coordinates.
		//#if IS_SSGI_SHADER && SSGI_TRACE_CONE
		//{
		//	UNROLL_N(SSRT_SAMPLE_BATCH_SIZE)
		//	for (uint j = 0; j < SSRT_SAMPLE_BATCH_SIZE; j++)
		//	{
		//		float S = float(i + j) + StepOffset;

		//		float NormalizedPower = (exp2(ExpLog2 * S) - 0.9) / MaxPower;

		//		float Offset = NormalizedPower * NumSteps;

		//		SamplesUV[j] = RayUVz.xy + Offset * RayStepUVz.xy;
		//		SamplesZ[j] = RayUVz.z + Offset * RayStepUVz.z;
		//	}
		
		//	SamplesMip.xy = Level;
		//	Level += (8.0 / NumSteps) * Roughness;
		//	//Level += 2.0 * ExpLog2;
		
		//	SamplesMip.zw = Level;
		//	Level += (8.0 / NumSteps) * Roughness;
		//	//Level += 2.0 * ExpLog2;
		//}
		//#else
		{
			UNROLL_N(SSRT_SAMPLE_BATCH_SIZE)
			for (uint j = 0; j < SSRT_SAMPLE_BATCH_SIZE; j++)
			{
				SamplesUV[j] = RayUVz.xy + (float(i) + float(j + 1)) * RayStepUVz.xy;
				SamplesZ[j] = RayUVz.z + (float(i) + float(j + 1)) * RayStepUVz.z;
			}
		
			SamplesMip.xy = Level;
			Level += (8.0 / NumSteps) * Roughness;
		
			SamplesMip.zw = Level;
			Level += (8.0 / NumSteps) * Roughness;
		}
		//#endif

		// Sample the scene depth.
		float4 SampleDepth;
		{
			UNROLL_N(SSRT_SAMPLE_BATCH_SIZE)
			for (uint j = 0; j < SSRT_SAMPLE_BATCH_SIZE; j++)
			{
				//#if DEBUG_SSRT
				//{
				//	if (bDebugPrint)
				//	{
				//		PrintSample(HZBUvFactorAndInvFactor, SamplesUV[j], float4(0, 1, 0, 1));
				//	}
				//}
				//#endif
				SampleDepth[j] = Texture.SampleLevel(Sampler, SamplesUV[j], SamplesMip[j]).r;
			}
		}

		// Evaluates the intersections.
		MultipleSampleDepthDiff = SamplesZ - SampleDepth;
		bMultipleSampleHit = abs(MultipleSampleDepthDiff + CompareTolerance) < CompareTolerance;
		bFoundAnyHit = any(bMultipleSampleHit);

		BRANCH
		if (bFoundAnyHit)
		{
			break;
		}

		LastDiff = MultipleSampleDepthDiff.w;

		//#if !SSGI_TRACE_CONE
		//	RayUVz += SSRT_SAMPLE_BATCH_SIZE * RayStepUVz;
		//#endif
	} // for( uint i = 0; i < NumSteps; i += 4 )
	
	// Compute the output coordinates.
	BRANCH
	if (bFoundAnyHit)
    {
		//#if IS_SSGI_SHADER && SSGI_TRACE_CONE
		//{
		//	// If hit set to intersect time. If missed set to beyond end of ray
  //          float4 HitTime = bMultipleSampleHit ? float4(0, 1, 2, 3) : 4;

		//	// Take closest hit
  //          float Time1 = min(min3(HitTime.x, HitTime.y, HitTime.z), HitTime.w);
		
		//	float S = float(i + Time1) + StepOffset;

		//	float NormalizedPower = (exp2(log2(Exp) * S) - 0.9) / MaxPower;

		//	float Offset = NormalizedPower * NumSteps;

  //          OutHitUVz = RayUVz + RayStepUVz * Offset;
		//}
		//#elif IS_SSGI_SHADER
		//{
		//	// If hit set to intersect time. If missed set to beyond end of ray
  //          float4 HitTime = bMultipleSampleHit ? float4(1, 2, 3, 4) : 5;

		//	// Take closest hit
  //          float Time1 = float(i) + min(min3(HitTime.x, HitTime.y, HitTime.z), HitTime.w);
		
  //          OutHitUVz = RayUVz + RayStepUVz * Time1;
		//}
		//#elif 0 // binary search refinement that has been attempted for SSR.
  //      {
		//	// If hit set to intersect time. If missed set to beyond end of ray
  //          float4 HitTime = bMultipleSampleHit ? float4(1, 2, 3, 4) : 5;

		//	// Take closest hit
  //          float Time1 = float(i) + min(min3(HitTime.x, HitTime.y, HitTime.z), HitTime.w);
  //          float Time0 = Time1 - 1;

  //          const uint NumBinarySteps = Roughness < 0.2 ? 4 : 0;

		//	// Binary search
  //          for (uint j = 0; j < NumBinarySteps; j++)
  //          {
  //              CompareTolerance *= 0.5;

  //              float MidTime = 0.5 * (Time0 + Time1);
  //              float3 MidUVz = RayUVz + RayStepUVz * MidTime;
  //              float MidDepth = Texture.SampleLevel(Sampler, MidUVz.xy, Level).r;
  //              float MidDepthDiff = MidUVz.z - MidDepth;

  //              if (abs(MidDepthDiff + CompareTolerance) < CompareTolerance)
  //              {
  //                  Time1 = MidTime;
  //              }
  //              else
  //              {
  //                  Time0 = MidTime;
  //              }
  //          }
			
  //          OutHitUVz = RayUVz + RayStepUVz * Time1;
  //      }
		//#else // SSR
        {
            float DepthDiff0 = MultipleSampleDepthDiff[2];
            float DepthDiff1 = MultipleSampleDepthDiff[3];
            float Time0 = 3;

            FLATTEN
            if (bMultipleSampleHit[2])
            {
                DepthDiff0 = MultipleSampleDepthDiff[1];
                DepthDiff1 = MultipleSampleDepthDiff[2];
                Time0 = 2;
            }
            FLATTEN
            if (bMultipleSampleHit[1])
            {
                DepthDiff0 = MultipleSampleDepthDiff[0];
                DepthDiff1 = MultipleSampleDepthDiff[1];
                Time0 = 1;
            }
            FLATTEN
            if (bMultipleSampleHit[0])
            {
                DepthDiff0 = LastDiff;
                DepthDiff1 = MultipleSampleDepthDiff[0];
                Time0 = 0;
            }

			Time0 += float(i);

            float Time1 = Time0 + 1;
			//#if 0
			//{
			//	// Binary search
			//	for( uint j = 0; j < 4; j++ )
			//	{
			//		CompareTolerance *= 0.5;

			//		float  MidTime = 0.5 * ( Time0 + Time1 );
			//		float3 MidUVz = RayUVz + RayStepUVz * MidTime;
			//		float  MidDepth = Texture.SampleLevel( Sampler, MidUVz.xy, Level ).r;
			//		float  MidDepthDiff = MidUVz.z - MidDepth;

			//		if( abs( MidDepthDiff + CompareTolerance ) < CompareTolerance )
			//		{
			//			DepthDiff1	= MidDepthDiff;
			//			Time1		= MidTime;
			//		}
			//		else
			//		{
			//			DepthDiff0	= MidDepthDiff;
			//			Time0		= MidTime;
			//		}
			//	}
			//}
			//#endif

			// Find more accurate hit using line segment intersection
            float TimeLerp = saturate(DepthDiff0 / (DepthDiff0 - DepthDiff1));
            float IntersectTime = Time0 + TimeLerp;
			//float IntersectTime = lerp( Time0, Time1, TimeLerp );
				
            OutHitUVz = RayUVz + RayStepUVz * IntersectTime;
        }
		//#endif
		
		//#if DEBUG_SSRT
		//{
		//	if (bDebugPrint)
		//		PrintSample(HZBUvFactorAndInvFactor, OutHitUVz.xy, float4(0, 0, 1, 1));
		//}
		//#endif

		OutHitUVz.xy *= HZBUvFactorAndInvFactor.zw;
		//OutHitUVz.xy = OutHitUVz.xy * float2( 2, -2 ) + float2( -1, 1 );
		//OutHitUVz.xy = OutHitUVz.xy * View.ScreenPositionScaleBias.xy + View.ScreenPositionScaleBias.wz;
    }
	else
    {
		OutHitUVz = float3(0, 0, 0);
    }
	
	return bFoundAnyHit;
} // CastScreenSpaceRay()


bool RayCast(
	Texture2D Texture, SamplerState Sampler,
	float3 RayOriginTranslatedWorld, float3 RayDirection,
	float Roughness, float SceneDepth,
	uint NumSteps, float StepOffset,
	float4 HZBUvFactorAndInvFactor, 
	bool bDebugPrint,
	out float3 OutHitUVz,
	out float Level)
{
	FSSRTRay Ray = InitScreenSpaceRayFromWorldSpace(RayOriginTranslatedWorld, RayDirection, SceneDepth);

	return CastScreenSpaceRay(
		Texture, Sampler,
		Ray,
		Roughness, NumSteps, StepOffset,
		HZBUvFactorAndInvFactor, bDebugPrint,
		/* out */ OutHitUVz,
		/* out */ Level);
} // RayCast()

float ComputeHitVignetteFromScreenPos(float2 ScreenPos)
{
	float2 Vignette = saturate(abs(ScreenPos) * 5 - 4);
	
	//PrevScreen sometimes has NaNs or Infs.  DX11 is protected because saturate turns NaNs -> 0.
	//Do a SafeSaturate so other platforms get the same protection.
	return SafeSaturate(1.0 - dot(Vignette, Vignette));
}

//void ReprojectHit(float4 PrevScreenPositionScaleBias, float3 HitUVz, out float2 OutPrevUV, out float OutVignette)
//{
//	// Camera motion for pixel (in ScreenPos space).
//	float2 ThisScreen = (HitUVz.xy - View.ScreenPositionScaleBias.wz) / View.ScreenPositionScaleBias.xy;
//	float4 ThisClip = float4( ThisScreen, HitUVz.z, 1 );
//	float4 PrevClip = mul( ThisClip, View.ClipToPrevClip );
//	float2 PrevScreen = PrevClip.xy / PrevClip.w;
//	float2 PrevUV = PrevScreen.xy * PrevScreenPositionScaleBias.xy + PrevScreenPositionScaleBias.zw;

//	OutVignette = min(ComputeHitVignetteFromScreenPos(ThisScreen), ComputeHitVignetteFromScreenPos(PrevScreen));
//	OutPrevUV = PrevUV;
//}

//void ReprojectHit(float4 PrevScreenPositionScaleBias, Texture2D Texture, SamplerState Sampler, float3 HitUVz, out float2 OutPrevUV, out float OutVignette)
//{
//	// Camera motion for pixel (in ScreenPos space).
//	float2 ThisScreen = (HitUVz.xy - View.ScreenPositionScaleBias.wz) / View.ScreenPositionScaleBias.xy;
//	float4 ThisClip = float4( ThisScreen, HitUVz.z, 1 );
//	float4 PrevClip = mul( ThisClip, View.ClipToPrevClip );
//	float2 PrevScreen = PrevClip.xy / PrevClip.w;

//	float4 EncodedVelocity = Texture.SampleLevel(Sampler, HitUVz.xy, 0);
//	if( EncodedVelocity.x > 0.0 )
//	{
//		PrevScreen = ThisClip.xy - DecodeVelocityFromTexture(EncodedVelocity).xy;
//	}

//	float2 PrevUV = PrevScreen.xy * PrevScreenPositionScaleBias.xy + PrevScreenPositionScaleBias.zw;
	
//	OutVignette = min(ComputeHitVignetteFromScreenPos(ThisScreen), ComputeHitVignetteFromScreenPos(PrevScreen));
//	OutPrevUV = PrevUV;
//}

float ComputeRayHitSqrDistance(float3 OriginTranslatedWorld, float3 HitUVz)
{
	// ALU get factored out with ReprojectHit.
	float2 HitScreenPos = (HitUVz.xy - _V_ScreenPositionScaleBias.wz) / _V_ScreenPositionScaleBias.xy;
	float HitSceneDepth = ConvertFromDeviceZ(HitUVz.z);

	float3 HitTranslatedWorld = mul(_M_ScreenToTranslatedWorldMatrix, float4(HitScreenPos * HitSceneDepth, HitSceneDepth, 1)).xyz;

	return length2(OriginTranslatedWorld - HitTranslatedWorld);
}

float4 SampleScreenColor(Texture2D Texture, SamplerState Sampler, float2 UV)
{
	float4 OutColor;

	OutColor.rgb = Texture.SampleLevel( Sampler, UV, 0 ).rgb;
	// Transform NaNs to black, transform negative colors to black.
	OutColor.rgb = -min(-OutColor.rgb, 0.0);
	OutColor.a = 1;
	
	return OutColor;
}

float4 SampleHCBLevel( Texture2D Texture, SamplerState Sampler, float2 UV, float Level, float4 HZBUvFactorAndInvFactor )
{
	float4 OutColor;

	OutColor.rgb = Texture.SampleLevel( Sampler, UV * HZBUvFactorAndInvFactor.xy, Level ).rgb;
	// Transform NaNs to black, transform negative colors to black.
	OutColor.rgb = -min(-OutColor.rgb, 0.0);
	OutColor.a = 1;

	return OutColor;
}

#endif