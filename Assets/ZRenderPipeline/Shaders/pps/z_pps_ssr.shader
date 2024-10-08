Shader "ZPipeline/ZUniversal/PPS/SSR"
{
	HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"

	#include "Assets/ZRenderPipeline/ShaderLibrary/Platform.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/TextureSampling.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/Common.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/BlitCommon.hlsl"
    #include "Assets/ZRenderPipeline/ShaderLibrary/Input.hlsl"
    #include "Assets/ZRenderPipeline/ShaderLibrary/DeferredShadingCommon.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/MonteCarlo.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/SSRT/SSRTRayCast.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/ScreenSpaceDenoise/SSDPublic.hlsl"

	#define SSR_QUALITY 2


	uniform float4 _SSR_V_SSRParams;



	Texture2D _SSR_T_SceneColor;
	SamplerState sampler_SSR_T_SceneColor;

	Texture2D _SSR_T_HZBTexture;
	SamplerState sampler_SSR_T_HZBTexture;


	float GetRoughness(const in ZGBufferData GBuffer)
	{
		float Roughness = GBuffer.Roughness;

		//BRANCH
		//if( GBuffer.ShadingModelID == SHADINGMODELID_CLEAR_COAT )
		//{
		//	const float ClearCoat			= GBuffer.CustomData.x;
		//	const float ClearCoatRoughness	= GBuffer.CustomData.y;

		//	Roughness = lerp( Roughness, ClearCoatRoughness, ClearCoat );
		//}

		return Roughness;
	}

	float GetRoughnessFade(in float Roughness)
	{
		// mask SSR to reduce noise and for better performance, roughness of 0 should have SSR, at MaxRoughness we fade to 0
		return min(Roughness * _SSR_V_SSRParams.y + 2, 1.0);
	}


    void ScreenSpaceReflections(float4 SvPosition, out float4 OutColor)
    {
        float2 UV = SvPosition.xy * _V_BufferSizeAndInvSize.zw;
        float2 ScreenPos = ViewportUVToScreenPos(UV);

        uint2 PixelPos = (uint2)SvPosition.xy;

        OutColor = 0;

	    ZGBufferData GBuffer = ZGetGBufferDataFromSceneTextures(UV);

	    float3 N = GBuffer.WorldNormal;
	    const float SceneDepth = GBuffer.Depth;
	    const float3 PositionTranslatedWorld = mul(_M_ScreenToTranslatedWorldMatrix, float4( ScreenPos * SceneDepth, SceneDepth, 1 ) ).xyz;
	    const float3 V = normalize(-PositionTranslatedWorld);


		if (SceneDepth > 10000)
		{
			OutColor.rgb = _SSR_T_SceneColor.SampleLevel( sampler_SSR_T_SceneColor, UV, 0 ).rgb;

			return;
		}

		//OutColor.rgba = mul(_M_TranslatedWorldToClip, float4(PositionTranslatedWorld + _WorldSpaceCameraPos.xyz, 1));
		//OutColor.rgb /= OutColor.a;
		//OutColor.rgb = OutColor.b;

//#if SUPPORTS_ANISOTROPIC_MATERIALS
//	// We do not need to execute ModifyGGXAnisotropicNormalRoughness in order to handle anisotropy on clear coat material.
//	// This is because SSR is only tracing the top layer which we consider to not have any anisotropy. This is when ClearCoat is 1.
//	// When clear coat decreases, we smoothly fades in the anisotropy influence from the bottom layer.
//	const float ClearCoat = GBuffer.CustomData.x;
//	const float AnisotropyBlendValue = GBuffer.ShadingModelID == SHADINGMODELID_CLEAR_COAT ? ClearCoat : 0.0f;
//	const float SSRAnisotropy = lerp(GBuffer.Anisotropy, 0.0f, AnisotropyBlendValue);
//	ModifyGGXAnisotropicNormalRoughness(GBuffer.WorldTangent, SSRAnisotropy, GBuffer.Roughness, N, V);
//#endif

	    float Roughness = 0.4;// GetRoughness(GBuffer);
	    float RoughnessFade = 0.5;// GetRoughnessFade(Roughness);

		// Early out. Useless if using the stencil prepass.
		BRANCH if( RoughnessFade <= 0.0 ) // || GBuffer.ShadingModelID == 0 )
		{
			return;
		}

	#if SSR_QUALITY == 0
		// visualize SSR

		float PatternMask = ((PixelPos.x / 4 + PixelPos.y / 4) % 2);

		OutColor = lerp(float4(1, 0, 0, 1), float4(1, 1 ,0, 1), PatternMask) * 0.2f;
		return;
	#endif

		float a = Roughness * Roughness;
		float a2 = a * a;
	
		float NoV = saturate( dot( N, V ) );
		float G_SmithV = 2 * NoV / (NoV + sqrt(NoV * (NoV - NoV * a2) + a2));

		float ClosestHitDistanceSqr = INFINITE_FLOAT;

	#if SSR_QUALITY == 1
		uint NumSteps = 8;
		uint NumRays = 1;
		bool bGlossy = false;
	#elif SSR_QUALITY == 2
		uint NumSteps = 16;
		uint NumRays = 1;
		//#if SSR_OUTPUT_FOR_DENOISER
		//	bool bGlossy = true;
		//#else
			bool bGlossy = false;
		//#endif
	#elif SSR_QUALITY == 3
		uint NumSteps = 8;
		uint NumRays = 4;
		bool bGlossy = true;
	#else // SSR_QUALITY == 4
		uint NumSteps = 12;
		uint NumRays = 12;
		bool bGlossy = true;
	#endif

		if( NumRays > 1 )
		{
			float2 Noise;
			Noise.x = InterleavedGradientNoise( SvPosition.xy, _U_StateFrameIndexMod8 );
			Noise.y = InterleavedGradientNoise( SvPosition.xy, _U_StateFrameIndexMod8 * 117 );
	
			//uint2 Random = 0x10000 * Noise;
			uint2 Random = Rand3DPCG16( int3( PixelPos, _U_StateFrameIndexMod8 ) ).xy;
			
			float3x3 TangentBasis = GetTangentBasis( N );
			float3 TangentV = mul( TangentBasis, V );

			float Count = 0;

			if( Roughness < 0.1 )
			{
				NumSteps = min( NumSteps * NumRays, 24u );
				NumRays = 1;
			}

			// Shoot multiple rays
			LOOP for( uint i = 0; i < NumRays; i++ )
			{
				float StepOffset = Noise.x;
				#if 0 // TODO
					StepOffset -= 0.9;
				#else
					StepOffset -= 0.5;
				#endif
			
				float2 E = Hammersley16( i, NumRays, Random );

	//#if 1
				float3 H = mul( ImportanceSampleVisibleGGX(UniformSampleDisk(E), a2, TangentV ).xyz, TangentBasis );
				float3 L = 2 * dot( V, H ) * H - V;
	//#elif 0
	//			float3 H = mul( ImportanceSampleGGX( E, a2 ).xyz, TangentBasis );
	//			float3 L = 2 * dot( V, H ) * H - V;
	//#elif 0
	//			float3 L = CosineSampleHemisphere( E, N ).xyz;
	//#elif 0
	//			float3 L = CosineSampleHemisphere( E ).xyz;
	//			L = mul( L, TangentBasis );
	//#else
	//			float3 L;
	//			L.xy = UniformSampleDiskConcentric( E );
	//			L.z = sqrt( 1 - dot( L.xy, L.xy ) );
	//			L = mul( L, TangentBasis );
	//			float3 H = normalize(V + L);
	//#endif

	// When 'Correct integration applies DGF' is enabled below, enable this and account for anisotropy
	//#if 0
	//			float NoL = saturate( dot(N, L) );
	//			float NoH = saturate( dot(N, H) );
	//			float VoH = saturate( dot(V, H) );
		
	//			float D = D_GGX( a2, NoH );
	//			float G_SmithL = 2 * NoL / (NoL + sqrt(NoL * (NoL - NoL * a2) + a2));
	//			float Vis = Vis_Smith( a2, NoV,  NoL );
	//			float3 F = F_Schlick( GBuffer.SpecularColor, VoH );
	//#endif

				float3 HitUVz;
				float Level = 0;
			
				if( Roughness < 0.1 )
				{
					L = reflect(-V, N);
				}
			
				bool bHit = RayCast(
					_SSR_T_HZBTexture, sampler_SSR_T_HZBTexture,
					PositionTranslatedWorld, L, Roughness, SceneDepth, 
					NumSteps, StepOffset,
					_V_HZBUvFactorAndInvFactor,
					false, // bDebugPrint,
					HitUVz,
					Level
				);

	//#if 0	// Backface check
	//			if( bHit )
	//			{
	//				float3 SampleNormal = GetGBufferData( HitUVz.xy ).WorldNormal;
	//				bHit = dot( SampleNormal, L ) < 0;
	//			}
	//#endif

				// if there was a hit
				BRANCH if( bHit )
				{
					ClosestHitDistanceSqr = min(ClosestHitDistanceSqr, ComputeRayHitSqrDistance(PositionTranslatedWorld, HitUVz));

					float2 SampleUV;
					float Vignette;
					//ReprojectHit(PrevScreenPositionScaleBias, GBufferVelocityTexture, GBufferVelocityTextureSampler, HitUVz, SampleUV, Vignette);

					//float4 SampleColor = SampleScreenColor( SceneColor, SceneColorSampler, SampleUV ) * Vignette;
					float4 SampleColor = SampleScreenColor(_SSR_T_SceneColor, sampler_SSR_T_SceneColor, HitUVz);

					SampleColor.rgb *= rcp( 1 + Luminance(SampleColor.rgb) );

					// Correct integration applies DGF below but for speed we apply EnvBRDF later when compositing
	//#if 0
	//				// CosineSampleHemisphere
	//				// PDF = NoL / PI,
	//				SampleColor.rgb *= F * (D * Vis * PI);
	//#elif 0
	//				// ImportanceSampleGGX
	//				// PDF = D * NoH / (4 * VoH),
	//				SampleColor.rgb *= F * ( NoL * Vis * (4 * VoH / NoH) );
	//#elif 0
	//				// ImportanceSampleVisibleGGX
	//				// PDF = G_SmithV * VoH * D / NoV / (4 * VoH)
	//				// PDF = G_SmithV * D / (4 * NoV);
	//				SampleColor.rgb *= F * G_SmithL;
	//#endif

					OutColor += SampleColor;
				}
			}

			//OutColor /= NumRays;
			OutColor /= max( NumRays, 0.0001 );
			OutColor.rgb *= rcp( 1 - Luminance(OutColor.rgb) );
		}
		else
		{
			float StepOffset = InterleavedGradientNoise(SvPosition.xy, _U_StateFrameIndexMod8);
			//#if 0 // TODO
			//	StepOffset -= 0.9;
			//#else
				StepOffset -= 0.5;
			//#endif
		
			float3 L;
			if (bGlossy)
			{
				float2 E = Rand1SPPDenoiserInput(PixelPos);
			
				//#if SSR_OUTPUT_FOR_DENOISER
				//{
				//	E.y *= 1 - GGX_IMPORTANT_SAMPLE_BIAS;
				//}
				//#endif
				
				float3x3 TangentBasis = GetTangentBasis( N );
				float3 TangentV = mul( TangentBasis, V );

				float3 H = mul( ImportanceSampleVisibleGGX(UniformSampleDisk(E), a2, TangentV ).xyz, TangentBasis );
				L = 2 * dot( V, H ) * H - V;
			}
			else
			{
				L = reflect( -V, N );
			}

			//OutColor.rgb = L;
		
			float3 HitUVz;
			float Level = 0;
			bool bHit = RayCast(
				_SSR_T_HZBTexture, sampler_SSR_T_HZBTexture,
				PositionTranslatedWorld, L, Roughness, SceneDepth,
				NumSteps, StepOffset,
				_V_HZBUvFactorAndInvFactor,
				false,// bDebugPrint,
				HitUVz,
				Level
			);

			BRANCH if( bHit )
			{
				//ClosestHitDistanceSqr = ComputeRayHitSqrDistance(PositionTranslatedWorld, HitUVz);

				//float2 SampleUV;
				//float Vignette;
				//ReprojectHit(PrevScreenPositionScaleBias, GBufferVelocityTexture, GBufferVelocityTextureSampler, HitUVz, SampleUV, Vignette);

				//OutColor = SampleScreenColor(SceneColor, SceneColorSampler, SampleUV) * Vignette;

				OutColor = SampleScreenColor(_SSR_T_SceneColor, sampler_SSR_T_SceneColor, HitUVz);
			}


			//float3 RayOriginTranslatedWorld = PositionTranslatedWorld;
			//float3 WorldRayDirection = L;

			//float4 RayStartClip	= mul(_M_TranslatedWorldToClip, float4(RayOriginTranslatedWorld, 1));
			//float4 RayEndClip = mul(_M_TranslatedWorldToClip, float4(RayOriginTranslatedWorld + WorldRayDirection * SceneDepth, 1));

			//float3 RayStartScreen = RayStartClip.xyz * rcp(RayStartClip.w);
			//float3 RayEndScreen = RayEndClip.xyz * rcp(RayEndClip.w);

			//float4 RayDepthClip = RayStartClip + mul(_M_ViewToClip, float4(0, 0, SceneDepth, 0));
			//float3 RayDepthScreen = RayDepthClip.xyz * rcp(RayDepthClip.w);

			//FSSRTRay Ray;
			//Ray.RayStartScreen = RayStartScreen;
			//Ray.RayStepScreen = RayEndScreen - RayStartScreen;
	
			//Ray.RayStepScreen *= GetStepScreenFactorToClipAtScreenEdge(RayStartScreen.xy, Ray.RayStepScreen.xy);

			//// TODO
			////#if IS_SSGI_SHADER
			////	Ray.CompareTolerance = max(abs(Ray.RayStepScreen.z), (RayStartScreen.z - RayDepthScreen.z) * 2);
			////#else
			//	Ray.CompareTolerance = max(abs(Ray.RayStepScreen.z), (RayStartScreen.z - RayDepthScreen.z) * 4);
			////#endif

			////OutColor.rgb = Ray.CompareTolerance;

			//OutColor.rgb = _SSR_T_SceneColor.SampleLevel( sampler_SSR_T_SceneColor, pp.xy * 0.5 + 0.5, 0 ).rgb;
		}

        //OutColor.rgb = float3(UV * _V_HZBUvFactorAndInvFactor.xy, 0);
    }

	void frag_ssr(v2f input, out float4 OutColor : SV_Target0)
	{
    	ScreenSpaceReflections(input.positionCS, OutColor);
	}

    ENDHLSL

    SubShader
    {
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "Down Sample"

            HLSLPROGRAM
                #pragma vertex   vert_blit
                #pragma fragment frag_ssr
            ENDHLSL
        }
    }
}
