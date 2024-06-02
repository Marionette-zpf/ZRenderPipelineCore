Shader "ZPipeline/ZUniversal/PPS/TAAStandalone"
{
	HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"

	#include "Assets/ZRenderPipeline/ShaderLibrary/Platform.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/TextureSampling.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/Common.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/BlitCommon.hlsl"
	#include "Assets/ZRenderPipeline/ShaderLibrary/MonteCarlo.hlsl"

	//------------------------------------------------------- ENUM VALUES

	/** Payload of the history. History might still have addtional TAA internals. */
	// Only have RGB.
	#define HISTORY_PAYLOAD_RGB 0
	
	// Have RGB and translucency in alpha.
	#define HISTORY_PAYLOAD_RGB_TRANSLUCENCY 1
	
	// Have RGB and opacity in alpha.
	#define HISTORY_PAYLOAD_RGB_OPACITY (HISTORY_PAYLOAD_RGB_TRANSLUCENCY)
	

	// /** Caching method for scene color. */
	// // Disable any in code cache.
	// #define AA_SAMPLE_CACHE_METHOD_DISABLE 0
	
	// // Caches 3x3 Neighborhood into VGPR (although my have corner optimised away).
	// #define AA_SAMPLE_CACHE_METHOD_VGPR_3X3 1
	
	// // Prefetches scene color into 10x10 LDS tile (8x8 when screen percentage < 71%).
	// #define AA_SAMPLE_CACHE_METHOD_LDS 2
	

	/** Clamping method for scene color. */
	// Min max neighboorhing samples.
	#define HISTORY_CLAMPING_BOX_MIN_MAX 0
	
	// Variance computed from neighboorhing samples.
	#define HISTORY_CLAMPING_BOX_VARIANCE 1

	// Min max samples that are within distance from output pixel. 
	#define HISTORY_CLAMPING_BOX_SAMPLE_DISTANCE 2


	//------------------------------------------------------- CONFIGS
	// Main
	



	#if POST_PROCESS_ALPHA
	#define AA_HISTORY_PAYLOAD (HISTORY_PAYLOAD_RGB_TRANSLUCENCY)
	#else
	#define AA_HISTORY_PAYLOAD (HISTORY_PAYLOAD_RGB)
	#endif

	#define AA_BICUBIC 1
	#define AA_CROSS 2
	#define AA_DYNAMIC 1
	#define AA_FILTERED 1
	#define AA_MANUALLY_CLAMP_HISTORY_UV 1
	#define AA_TONE 1
	#define AA_YCOCG 1

	#if !TAA_FAST
		#define AA_DYNAMIC_ANTIGHOST 1
	#endif


	//------------------------------------------------------- CONFIG DISABLED DEFAULTS
	// Num samples of current frame
	#ifndef AA_SAMPLES
		#define AA_SAMPLES 5
	#endif

	// 1 = Use tighter AABB clamp for history.
	// 0 = Use simple min/max clamp.
	#ifndef AA_CLIP
		#define AA_CLIP 0
	#endif

	// Cross distance in pixels used in depth search X pattern.
	// 0 = Turn this feature off.
	// 2 = Is required for standard temporal AA pass.
	#ifndef AA_CROSS
		#define AA_CROSS 0
	#endif

	// 1 = Use dynamic motion.
	// 0 = Skip dynamic motion, currently required for half resolution passes.
	#ifndef AA_DYNAMIC
		#define AA_DYNAMIC 0
	#endif

	// 0 = Dynamic motion based lerp value (default).
	// non-zero = Use 1/LERP fixed lerp value (used for reflections).
	#ifndef AA_LERP
		#define AA_LERP 0
	#endif

	// 1 = Use higher quality round clamp.
	// 0 = Use lower quality but faster box clamp.
	#ifndef AA_ROUND
		#define AA_ROUND 0
	#endif

	// Force clamp on alpha.
	#ifndef AA_FORCE_ALPHA_CLAMP
		#define AA_FORCE_ALPHA_CLAMP 0
	#endif

	// Use YCoCg path.
	#ifndef AA_YCOCG
		#define AA_YCOCG 0
	#endif

	// Bicubic filter history
	#ifndef AA_BICUBIC
		#define AA_BICUBIC 0
	#endif

	// Tone map to kill fireflies
	#ifndef AA_TONE
		#define AA_TONE 0
	#endif

	// Antighosting using dynamic mask
	#ifndef AA_DYNAMIC_ANTIGHOST
		#define AA_DYNAMIC_ANTIGHOST 0
	#endif

	// Sample the stencil buffer inline rather than multiple masked passes.
	#ifndef AA_SINGLE_PASS_RESPONSIVE
		#define AA_SINGLE_PASS_RESPONSIVE	0
	#endif

	// Upsample the output.
	#ifndef AA_UPSAMPLE
		#define AA_UPSAMPLE 0
	#endif

	// Method used for generating the history clamping box.
	#ifndef AA_HISTORY_CLAMPING_BOX
		#define AA_HISTORY_CLAMPING_BOX (HISTORY_CLAMPING_BOX_MIN_MAX)
	#endif

	// Change the upsampling filter size when history is rejected that reduce blocky output pixels.
	#ifndef AA_UPSAMPLE_ADAPTIVE_FILTERING
		#define AA_UPSAMPLE_ADAPTIVE_FILTERING 0
	#endif

	// Whether this pass run at lower resolution than main view rectangle.
	#ifndef AA_LOWER_RESOLUTION
		#define AA_LOWER_RESOLUTION 0
	#endif

	// Whether the history buffer UV should be manually clamped.
	#ifndef AA_MANUALLY_CLAMP_HISTORY_UV
		#define AA_MANUALLY_CLAMP_HISTORY_UV 0
	#endif


	//------------------------------------------------------- CONFIG ENABLED DEFAULTS

	// Always enable scene color filtering
	// 1 = Use filtered sample.
	// 0 = Use center sample.
	#ifndef AA_FILTERED
		#define AA_FILTERED 1
	#endif

	// Always enable AA_NAN to avoid all NAN in all TAA pass that is more convenient considering the amount of / 0 we can have.
	// 0 = Don't use.
	// 1 = Use extra clamp to avoid NANs
	#ifndef AA_NAN
		#define AA_NAN 1
	#endif

	// Neighborhood clamping. Disable for testing reprojection. Always enabled, well because TAA is totally broken otherwise.
	#ifndef AA_CLAMP
		#define AA_CLAMP 1
	#endif

	// By default, always cache neighbooring samples into VGPR.
	#ifndef AA_SAMPLE_CACHE_METHOD
		#define AA_SAMPLE_CACHE_METHOD (AA_SAMPLE_CACHE_METHOD_VGPR_3X3)
	#endif

	// By default, enable stocastic quantization of the output.
	#ifndef AA_ENABLE_STOCASTIC_QUANTIZATION
		#define AA_ENABLE_STOCASTIC_QUANTIZATION 1
	#endif

	//------------------------------------------------------- MENDATORY CONFIG

	#ifndef AA_HISTORY_PAYLOAD
		#error You forgot to defines the history payload.
	#endif

	//------------------------------------------------------- DERIVES

	// Defines number of component in history payload.
	#if AA_HISTORY_PAYLOAD == HISTORY_PAYLOAD_RGB
		#define HISTORY_PAYLOAD_COMPONENTS 3
	#endif

	//------------------------------------------------------- CONFIG CHECKS

	#if AA_SAMPLES != 9 && AA_SAMPLES != 5 && AA_SAMPLES != 6
		#error Samples must be 5, (6 for TAAU) or 9
	#endif

	#if AA_SAMPLE_CACHE_METHOD >= 2 && !COMPUTESHADER
		#error Group share only for compute shader.
	#endif

	//------------------------------------------------------- CONSTANTS

	// K = Center of the nearest input pixel.
	// O = Center of the output pixel.
	//
	//          |           |
	//    0     |     1     |     2
	//          |           |
	//          |           |
	//  --------+-----------+--------
	//          |           |
	//          | O         |
	//    3     |     K     |     5
	//          |           |
	//          |           |
	//  --------+-----------+--------
	//          |           |
	//          |           |
	//    6     |     7     |     8
	//          |           |
	//
	static const int2 kOffsets3x3[9] =
	{
		int2(-1, -1),
		int2( 0, -1),
		int2( 1, -1),
		int2(-1,  0),
		int2( 0,  0), // K
		int2( 1,  0),
		int2(-1,  1),
		int2( 0,  1),
		int2( 1,  1),
	};
	
	// Indexes of the 3x3 square.
	static const uint kSquareIndexes3x3[9] = { 0, 1, 2, 3, 4, 5, 6, 7, 8 };

	// Indexes of the offsets to have plus + shape.
	static const uint kPlusIndexes3x3[5] = { 1, 3, 4, 5, 7 };

	// Number of neighbors.
	static const uint kNeighborsCount = 9;


	#if AA_UPSAMPLE
		// T = Center of the nearest top left pixel input pixel.
		// O = Center of the output pixel.
		//
		//          | 
		//    T     |     .
		//          | 
		//       O  | 
		//  --------+--------
		//          | 
		//          | 
		//    .     |     .
		//          | 
		static const int2 Offsets2x2[4] =
		{
			int2( 0,  0), // T
			int2( 1,  0),
			int2( 0,  1),
			int2( 1,  1),
		};
		
		// Indexes of the 2x2 square.
		static const uint SquareIndexes2x2[4] = { 0, 1, 2, 3 };

	#endif // AA_UPSAMPLE


	//------------------------------------------------------- PARAMETERS
	TEXTURE2D(_HistoryTaaTexture); SAMPLER(sampler_HistoryTaaTexture);
	//TEXTURE2D(_VelocityTexture);   SAMPLER(sampler_VelocityTexture);
	
	TEXTURE2D(_SceneColorTexture);  
	TEXTURE2D(_SceneDepthTexture); 
	
	uniform float4 _TAA_V_ScreenPosToHistoryBufferUV;
	uniform float4 _TAA_V_HistoryBufferUVMinMax;
	uniform float4 _TAA_V_HistoryBufferSize;
	uniform float4 _TAA_V_InputSceneColorSize;
	uniform float4 _TAA_V_OutputViewportSize;
	uniform float4 _TAA_V_OutputQuantizationError;

	uniform float4 _TAA_V_InputMinMaxPixelCoord;

	uniform float2 _TAA_V_ScreenPosAbsMax;
	uniform float2 _TAA_V_TemporalJitterPixels;

	uniform float4 _TAA_V_InputViewSize;
	uniform float2 _TAA_V_InputViewMin;

	uniform float _TAA_F_CameraCut;
	uniform float _TAA_F_CurrentFrameWeight;

	uniform float _TAA_FA_SampleWeights[9];
    uniform float _TAA_FA_PlusWeights[5];

	//------------------------------------------------------- FUNCTIONS

	float3 RGBToYCoCg( float3 RGB )
	{
		float Y  = dot( RGB, float3(  1, 2,  1 ) );
		float Co = dot( RGB, float3(  2, 0, -2 ) );
		float Cg = dot( RGB, float3( -1, 2, -1 ) );
	
		float3 YCoCg = float3( Y, Co, Cg );
		return YCoCg;
	}

	float3 YCoCgToRGB( float3 YCoCg )
	{
		float Y  = YCoCg.x * 0.25;
		float Co = YCoCg.y * 0.25;
		float Cg = YCoCg.z * 0.25;

		float R = Y + Co - Cg;
		float G = Y + Cg;
		float B = Y - Co - Cg;

		float3 RGB = float3( R, G, B );
		return RGB;
	}


	// Faster but less accurate luma computation. 
	// Luma includes a scaling by 4.
	float Luma4(float3 Color)
	{
		return (Color.g * 2.0) + (Color.r + Color.b);
	}

	// Optimized HDR weighting function.
	float HdrWeight4(float3 Color, float Exposure) 
	{
		return rcp(Luma4(Color) * Exposure + 4.0);
	}

	float HdrWeightY(float Color, float Exposure) 
	{
		return rcp(Color * Exposure + 4.0);
	}


	// Intersect ray with AABB, knowing there is an intersection.
	//   Dir = Ray direction.
	//   Org = Start of the ray.
	//   Box = Box is at {0,0,0} with this size.
	// Returns distance on line segment.
	float IntersectAABB(float3 Dir, float3 Org, float3 Box)
	{
		#if PS4_PROFILE
			// This causes flicker, it should only be used on PS4 until proper fix is in.
			if(min(min(abs(Dir.x), abs(Dir.y)), abs(Dir.z)) < (1.0/65536.0)) return 1.0;
		#endif
		float3 RcpDir = rcp(Dir);
		float3 TNeg = (  Box  - Org) * RcpDir;
		float3 TPos = ((-Box) - Org) * RcpDir;
		return max(max(min(TNeg.x, TPos.x), min(TNeg.y, TPos.y)), min(TNeg.z, TPos.z));
	}


	float HistoryClip(float3 History, float3 Filtered, float3 NeighborMin, float3 NeighborMax)
	{
	#if 0
		float3 Min = min(Filtered, min(NeighborMin, NeighborMax));
		float3 Max = max(Filtered, max(NeighborMin, NeighborMax));	
		float3 Avg2 = Max + Min;
		float3 Dir = Filtered - History;
		float3 Org = History - Avg2 * 0.5;
		float3 Scale = Max - Avg2 * 0.5;
		return saturate(IntersectAABB(Dir, Org, Scale));
	#else
		float3 BoxMin = NeighborMin;
		float3 BoxMax = NeighborMax;
		//float3 BoxMin = min( Filtered, NeighborMin );
		//float3 BoxMax = max( Filtered, NeighborMax );

		float3 RayOrigin = History;
		float3 RayDir = Filtered - History;
		RayDir = abs( RayDir ) < (1.0/65536.0) ? (1.0/65536.0) : RayDir;
		float3 InvRayDir = rcp( RayDir );

		float3 MinIntersect = (BoxMin - RayOrigin) * InvRayDir;
		float3 MaxIntersect = (BoxMax - RayOrigin) * InvRayDir;
		float3 EnterIntersect = min( MinIntersect, MaxIntersect );
		return max3( EnterIntersect.x, EnterIntersect.y, EnterIntersect.z );
	#endif
	}


	float2 WeightedLerpFactors(float WeightA, float WeightB, float Blend)
	{
		float BlendA = (1.0 - Blend) * WeightA;
		float BlendB =        Blend  * WeightB;

		float RcpBlend = rcp(BlendA + BlendB);
		BlendA *= RcpBlend;
		BlendB *= RcpBlend;

		return float2(BlendA, BlendB);
	}


	//------------------------------------------------------- HISTORY's PAYLOAD
	
	// Payload of the TAA's history.
	struct FTAAHistoryPayload
	{
		// Transformed scene color and alpha channel.
		float4 Color;
	};

	FTAAHistoryPayload MulPayload(in FTAAHistoryPayload Payload, in float x)
	{
		Payload.Color *= x;
		return Payload;
	}

	FTAAHistoryPayload AddPayload(in FTAAHistoryPayload Payload0, in FTAAHistoryPayload Payload1)
	{
		Payload0.Color += Payload1.Color;
		return Payload0;
	}

	FTAAHistoryPayload MinPayload(in FTAAHistoryPayload Payload0, in FTAAHistoryPayload Payload1)
	{
		Payload0.Color = min(Payload0.Color, Payload1.Color);
		return Payload0;
	}

	FTAAHistoryPayload MaxPayload(in FTAAHistoryPayload Payload0, in FTAAHistoryPayload Payload1)
	{
		Payload0.Color = max(Payload0.Color, Payload1.Color);
		return Payload0;
	}

	FTAAHistoryPayload MinPayload3(in FTAAHistoryPayload Payload0, in FTAAHistoryPayload Payload1, in FTAAHistoryPayload Payload2)
	{
		Payload0.Color = min3(Payload0.Color, Payload1.Color, Payload2.Color);
		return Payload0;
	}

	FTAAHistoryPayload MaxPayload3(in FTAAHistoryPayload Payload0, in FTAAHistoryPayload Payload1, in FTAAHistoryPayload Payload2)
	{
		Payload0.Color = max3(Payload0.Color, Payload1.Color, Payload2.Color);
		return Payload0;
	}

	//------------------------------------------------------- TAA INTERMEDIARY STRUCTURES
	// 输出像素参数。一旦设置，不应修改
	struct FTAAInputParameters
	{
		// 输出像素的视口UV
		float2 ViewportUV;

		// 输出像素在屏幕上的位置
		float2 ScreenPos;

		// 最近输入像素的缓冲器UV
		float2 NearestBufferUV;

		#if AA_UPSAMPLE
			// 最近左上角输入像素的缓冲器UV
			float2 NearestTopLeftBufferUV;
		#endif

		// 此像素是否应该是响应的
		float bIsResponsiveAAPixel;

		// 帧曝光的比例
		float FrameExposureScale;

		// 邻居转换场景颜色的缓存
		#if AA_SAMPLE_CACHE_METHOD == AA_SAMPLE_CACHE_METHOD_VGPR_3X3
			float4 CachedNeighbors0[kNeighborsCount];
		#endif
	};

	// 主要函数之间方便地共享值的中间结果
	// 可以将此结构传递给主要函数，其中的变量仍未初始化
	struct FTAAIntermediaryResult
	{
		// 过滤后的输入
		FTAAHistoryPayload Filtered;
	};

	// 创建中间结果
	FTAAIntermediaryResult CreateIntermediaryResult()
	{
		FTAAIntermediaryResult IntermediaryResult = (FTAAIntermediaryResult)0;
		return IntermediaryResult;
	}

	// 一个样本的转换后场景颜色数据
	struct FTAASceneColorSample
	{
		// 转换后的场景颜色和 alpha 通道
		float4 Color;

		// 场景颜色样本的 HDR 权重
		float HdrWeight;
	};


	//------------------------------------------------------- SCENE COLOR SPACE MANAGMENT

	// Transform RAW linear scene color RGB to TAA's working color space.
	float4 TransformSceneColor(float4 RawLinearSceneColorRGBA)
	{
		#if AA_YCOCG
			return float4(RGBToYCoCg(RawLinearSceneColorRGBA.rgb), RawLinearSceneColorRGBA.a);
		#endif
		return RawLinearSceneColorRGBA;
	}

	// Reciprocal of TransformSceneColor().
	float4 TransformBackToRawLinearSceneColor(float4 SceneColor)
	{
		#if AA_YCOCG
			return float4(YCoCgToRGB(SceneColor.xyz), SceneColor.a);
		#endif
		return SceneColor;
	}

	// Transform current frame's RAW scene color RGB to TAA's working color space.
	float4 TransformCurrentFrameSceneColor(float4 RawSceneColorRGBA)
	{
		return TransformSceneColor(RawSceneColorRGBA);
	}

	// Get the Luma4 of the sceneColor
	float GetSceneColorLuma4(float4 SceneColor)
	{
	 	#if AA_YCOCG
	 		return SceneColor.x;
	 	#endif
		return Luma4(SceneColor.rgb);
	}

	// Get the HDR weight of the transform scene color.
	float GetSceneColorHdrWeight(in FTAAInputParameters InputParams, float4 SceneColor)
	{
		#if AA_YCOCG
			return HdrWeightY(SceneColor.x, InputParams.FrameExposureScale);
		#endif
		return HdrWeight4(SceneColor.rgb, InputParams.FrameExposureScale);
	}



	
	//------------------------------------------------------- INPUT SAMPLE CACHING.
	// API to sample input scene color and depth through caching system.
	// 
	// Precache scene color or depth:
	//		PrecacheInputSceneColor(InputParams);
	//		PrecacheInputSceneDepth(InputParams);
	//
	// Then sample scene color or depth:
	//		SampleCachedSceneColorTexture(InputParams, /* Offset = */ int2(-1, -1));
	//		SampleCachedSceneDepthTexture(InputParams, /* Offset = */ int2(-1, -1));
	//
	//		<Offset> parameter is meant to be compile time constant of the pixel offset from nearest input sample.
	void PrecacheInputSceneColor(inout FTAAInputParameters InputParams)
	{
		// Precache 3x3 input scene color into FTAAInputParameters::CachedNeighbors.
		UNITY_UNROLL
		for (uint i = 0; i < kNeighborsCount; i++)
		{
			int2 Coord = int2(InputParams.NearestBufferUV * _TAA_V_InputSceneColorSize.xy) + kOffsets3x3[i];
			Coord = clamp(Coord, _TAA_V_InputMinMaxPixelCoord.xy, _TAA_V_InputMinMaxPixelCoord.zw);

			InputParams.CachedNeighbors0[i] = TransformCurrentFrameSceneColor(_SceneColorTexture[Coord]);
		}
	}

	FTAASceneColorSample SampleCachedSceneColorTexture(
		inout FTAAInputParameters InputParams, 
		int2 PixelOffset)
	{
		// PixelOffset is const at compile time. Therefore all this computaton is actually free.
		uint NeighborsId = uint(4 + PixelOffset.x + PixelOffset.y * 3);
		FTAASceneColorSample Sample;

		Sample.Color = InputParams.CachedNeighbors0[NeighborsId];
		Sample.HdrWeight = GetSceneColorHdrWeight(InputParams, Sample.Color);
		return Sample;
	}

	// Sample scene color.
	float SampleCachedSceneDepthTexture(in FTAAInputParameters InputParams, int2 PixelOffset)
	{
		return _SceneDepthTexture.SampleLevel(sampler_PointClamp, InputParams.NearestBufferUV, 0, PixelOffset).r;
	}



	//------------------------------------------------------- TAA MAJOR FUNCTIONS
	// Filter input pixels.
	void FilterCurrentFrameInputSamples(in FTAAInputParameters InputParams, inout FTAAIntermediaryResult IntermediaryResult)
	{
		#if !AA_FILTERED
		{
			IntermediaryResult.Filtered.Color     = SampleCachedSceneColorTexture(InputParams, int2(0, 0)).Color;
			return;
		}
		#endif

		FTAAHistoryPayload Filtered;
		{
			#if AA_SAMPLES == 5
				const uint SampleIndexes[5] = kPlusIndexes3x3;
			#endif

			// 计算邻居的HDR, 最终权重和颜色.
			float  NeighborsHdrWeight   = 0;
			float  NeighborsFinalWeight = 0;
			float4 NeighborsColor       = 0;

			UNITY_UNROLL
			for (uint i = 0; i <  AA_SAMPLES ; i++)
			{
				// 从最近的输入像素获得样本偏移量.
				int2 SampleOffset;
				{
					const uint SampleIndex = SampleIndexes[i];
					SampleOffset = kOffsets3x3[SampleIndex];
				}

				float2 fSampleOffset       = float2(SampleOffset);

				#if AA_SAMPLES == 5
					float SampleSpatialWeight = _TAA_FA_PlusWeights[i];
				#else
					#error Do not know how to compute filtering sample weight.
				#endif

				// Fetch sample.
				FTAASceneColorSample Sample = SampleCachedSceneColorTexture(InputParams, SampleOffset);

				// 查找采样点的HDR权重.
				#if AA_TONE
					float SampleHdrWeight = Sample.HdrWeight;
				#else
					float SampleHdrWeight = 1;
				#endif

				// 根据有效负载求出样本的双边权重.
				float BilateralWeight = 1;

				// 计算最终采样权重.
				float SampleFinalWeight = SampleSpatialWeight * SampleHdrWeight * BilateralWeight;

				// 应用权重到采样颜色中.
				NeighborsColor       += SampleFinalWeight * Sample.Color;
				NeighborsFinalWeight += SampleFinalWeight;

				NeighborsHdrWeight += SampleSpatialWeight * SampleHdrWeight;
			}

			#if AA_TONE 
			{
				// Reweight because SampleFinalWeight does not that have total sum = 1.
				Filtered.Color = NeighborsColor * rcp(NeighborsFinalWeight);
			}
			#else
			{
				Filtered.Color = NeighborsColor;
			}
			#endif
		}

		IntermediaryResult.Filtered = Filtered;
	}

	
	// 计算用于拒绝历史记录的邻域包围盒.
	void ComputeNeighborhoodBoundingbox(
		in FTAAInputParameters InputParams,
		in FTAAIntermediaryResult IntermediaryResult,
		out FTAAHistoryPayload OutNeighborMin,
		out FTAAHistoryPayload OutNeighborMax)
	{
		// 相邻像素的数据.
		FTAAHistoryPayload Neighbors[kNeighborsCount];
		UNROLL
		for (uint i = 0; i < kNeighborsCount; i++)
		{
			Neighbors[i].Color = SampleCachedSceneColorTexture(InputParams, kOffsets3x3[i]).Color;
		}
	
		FTAAHistoryPayload NeighborMin;
		FTAAHistoryPayload NeighborMax;
	
		#if AA_HISTORY_CLAMPING_BOX == HISTORY_CLAMPING_BOX_VARIANCE 
		// 这个就是NVIDIA版本的Variance Clipping.
		{
			#if AA_SAMPLES == 5
				const uint SampleIndexes[5] = kPlusIndexes3x3;
			#else
				#error Unknown number of samples.
			#endif
	
			// 计算当前像素的矩(moment).
			float4 m1 = 0;
			float4 m2 = 0;
			for( uint i = 0; i < AA_SAMPLES; i++ )
			{
				float4 SampleColor = Neighbors[ SampleIndexes[i] ];
	
				m1 += SampleColor;
				m2 += Pow2( SampleColor );
			}
	
			m1 *= (1.0 / AA_SAMPLES);
			m2 *= (1.0 / AA_SAMPLES);
	
			// 标准方差.
			float4 StdDev = sqrt( abs(m2 - m1 * m1) );
			// 邻居的最大最小值.
			NeighborMin = m1 - 1.25 * StdDev;
			NeighborMax = m1 + 1.25 * StdDev;
	
			// 跟输入的过滤数据做比较, 找出最大最小值.
			NeighborMin = min( NeighborMin, IntermediaryResult.Filtered );
			NeighborMax = max( NeighborMax, IntermediaryResult.Filtered );
		}
		#elif AA_HISTORY_CLAMPING_BOX == HISTORY_CLAMPING_BOX_SAMPLE_DISTANCE
		// 只在某个半径内执行颜色裁剪.
		{
			float2 PPCo = InputParams.ViewportUV * _TAA_V_InputViewSize.xy + _TAA_V_TemporalJitterPixels;
			float2 PPCk = floor(PPCo) + 0.5;
			float2 dKO = PPCo - PPCk;
			
			// 总是考虑4个样本.
			NeighborMin = Neighbors[4];
			NeighborMax = Neighbors[4];
			
			// 减少距离阈值作为upsacale因素增加, 以减少鬼影.
			float DistthresholdLerp = 0;// UpscaleFactor - 1;
			float DistThreshold = lerp(1.51, 1.3, DistthresholdLerp);
	
			const uint Indexes[5] = kPlusIndexes3x3;
	
			// 计算所有样本的最大最小值.
			UNROLL
			for( uint i = 0; i < AA_SAMPLES; i++ )
			{
				uint NeightborId = Indexes[i];
				if (NeightborId != 4)
				{
					float2 dPP = float2(kOffsets3x3[NeightborId]) - dKO;
	
					FLATTEN
					if (dot(dPP, dPP) < (DistThreshold * DistThreshold))
					{
						NeighborMin = MinPayload(NeighborMin, Neighbors[NeightborId]);
						NeighborMax = MaxPayload(NeighborMax, Neighbors[NeightborId]);
					}
				}
			}
		}
		#elif AA_HISTORY_CLAMPING_BOX == HISTORY_CLAMPING_BOX_MIN_MAX
		// 用最大最小包围盒来裁剪, 是默认的方式.
		{
			NeighborMin = MinPayload3( Neighbors[1], Neighbors[3], Neighbors[4] );
			NeighborMin = MinPayload3( NeighborMin,  Neighbors[5], Neighbors[7] );
	
			NeighborMax = MaxPayload3( Neighbors[1], Neighbors[3], Neighbors[4] );
			NeighborMax = MaxPayload3( NeighborMax,  Neighbors[5], Neighbors[7] );
			
			//#if AA_SAMPLES == 9
			//{
			//	FTAAHistoryPayload NeighborMinPlus = NeighborMin;
			//	FTAAHistoryPayload NeighborMaxPlus = NeighborMax;
	
			//	NeighborMin = MinPayload3( NeighborMin, Neighbors[0], Neighbors[2] );
			//	NeighborMin = MinPayload3( NeighborMin, Neighbors[6], Neighbors[8] );
	
			//	NeighborMax = MaxPayload3( NeighborMax, Neighbors[0], Neighbors[2] );
			//	NeighborMax = MaxPayload3( NeighborMax, Neighbors[6], Neighbors[8] );
	
			//	if( AA_ROUND )
			//	{
			//		NeighborMin = AddPayload(MulPayload(NeighborMin, 0.5), MulPayload(NeighborMinPlus, 0.5));
			//		NeighborMax = AddPayload(MulPayload(NeighborMax, 0.5), MulPayload(NeighborMaxPlus, 0.5));
			//	}
			//}
			//#endif
		}
		#else
			#error Unknown history clamping box.
		#endif
	
		OutNeighborMin = NeighborMin;
		OutNeighborMax = NeighborMax;
	}
	
	float4 SamplerHisLinear(float2 uv)
	{
		return _HistoryTaaTexture.SampleLevel(sampler_HistoryTaaTexture, uv + float2(0 / 1920, 0 / 1080), 0) * 0.25 +
			   _HistoryTaaTexture.SampleLevel(sampler_HistoryTaaTexture, uv + float2(1 / 1920, 0 / 1080), 0) * 0.25 + 
			   _HistoryTaaTexture.SampleLevel(sampler_HistoryTaaTexture, uv + float2(0 / 1920, 1 / 1080), 0) * 0.25 +
			   _HistoryTaaTexture.SampleLevel(sampler_HistoryTaaTexture, uv + float2(1 / 1920, 1 / 1080), 0) * 0.25;
	}

	// 采样历史数据.
	FTAAHistoryPayload SampleHistory(in float2 HistoryScreenPosition)
	{
		float4 RawHistory0 = 0;
		float4 RawHistory1 = 0;
	
		// 用Catmull-Rom曲线采样历史数据, 以减少运动模糊.(默认使用)
		#if AA_BICUBIC
		{
			float2 HistoryBufferUV = HistoryScreenPosition * _TAA_V_ScreenPosToHistoryBufferUV.xy + _TAA_V_ScreenPosToHistoryBufferUV.zw;
	
			// 裁剪HistoryBufferUV，避免对额外样本的计算.
			#if AA_MANUALLY_CLAMP_HISTORY_UV
				HistoryBufferUV = clamp(HistoryBufferUV, _TAA_V_HistoryBufferUVMinMax.xy, _TAA_V_HistoryBufferUVMinMax.zw);
			#endif
	
			FCatmullRomSamples Samples = GetBicubic2DCatmullRomSamples(HistoryBufferUV, _TAA_V_HistoryBufferSize.xy, _TAA_V_HistoryBufferSize.zw);
			for (uint i = 0; i < Samples.Count; i++)
			{
				float2 SampleUV = Samples.UV[i];
	
				// 裁剪SampleUV在_TAA_V_HistoryBufferUVMinMax内, 避免取样潜在NaN跑到视图区域之外.
				// 可能消耗很大，但Samples.UVDir实际上是编译期常数。
				if (AA_MANUALLY_CLAMP_HISTORY_UV)
				{
					if (Samples.UVDir[i].x < 0)
					{
						SampleUV.x = max(SampleUV.x, _TAA_V_HistoryBufferUVMinMax.x);
					}
					else if (Samples.UVDir[i].x > 0)
					{
						SampleUV.x = min(SampleUV.x, _TAA_V_HistoryBufferUVMinMax.z);
					}
	
					if (Samples.UVDir[i].y < 0)
					{
						SampleUV.y = max(SampleUV.y, _TAA_V_HistoryBufferUVMinMax.y);
					}
					else if (Samples.UVDir[i].y > 0)
					{
						SampleUV.y = min(SampleUV.y, _TAA_V_HistoryBufferUVMinMax.w);
					}
				}

				RawHistory0 += _HistoryTaaTexture.SampleLevel(sampler_LinearClamp, SampleUV, 0) * Samples.Weight[i];
			}
			RawHistory0 *= Samples.FinalMultiplier;
		}
		// 双线性采样历史数据.
		#else
		{
			// Clamp HistoryScreenPosition to be within viewport.
			//if (AA_MANUALLY_CLAMP_HISTORY_UV)
			//{
			//	HistoryScreenPosition = clamp(HistoryScreenPosition, -_TAA_V_ScreenPosAbsMax, _TAA_V_ScreenPosAbsMax);
			//}
	
			float2 HistoryBufferUV = HistoryScreenPosition * _TAA_V_ScreenPosToHistoryBufferUV.xy + _TAA_V_ScreenPosToHistoryBufferUV.zw;
	
			RawHistory0 = _HistoryTaaTexture.SampleLevel(sampler_LinearClamp, HistoryBufferUV, 0);
		}
		#endif
		
		// 处理和保存历史数据的结果.
		FTAAHistoryPayload HistoryPayload;
		HistoryPayload.Color = RawHistory0;
		HistoryPayload.Color = TransformSceneColor(RawHistory0);
	
		return HistoryPayload;
	}



	// 裁剪历史数据.
	FTAAHistoryPayload ClampHistory(inout FTAAIntermediaryResult IntermediaryResult, FTAAHistoryPayload History, FTAAHistoryPayload NeighborMin, FTAAHistoryPayload NeighborMax)
	{
		#if !AA_CLAMP
			return History;
		#elif AA_CLIP // 使用更紧的AABB裁剪历史数据.
			// 裁剪历史，这使用颜色AABB相交更紧.
			float4 TargetColor = Filtered;

			// 历史裁剪.
			float ClipBlend = HistoryClip( HistoryColor.rgb, TargetColor.rgb, NeighborMin.rgb, NeighborMax.rgb );
			// 裁剪到0~1.
			ClipBlend = saturate( ClipBlend );

			// 根据混合权重插值历史和目标颜色.
			HistoryColor = lerp( HistoryColor, TargetColor, ClipBlend );

			#if AA_FORCE_ALPHA_CLAMP
				HistoryColor.a = clamp( HistoryColor.a, NeighborMin.a, NeighborMax.a );
			#endif

			return HistoryColor;

		#else //!AA_CLIP, 使用Neighborhood clamping(邻域裁剪).
			History.Color = clamp(History.Color, NeighborMin.Color, NeighborMax.Color);
			return History;
		#endif
	}

	

	half4 frag_taa(v2f input) : SV_Target
	{
		FTAAInputParameters InputParams = (FTAAInputParameters)0;

		InputParams.FrameExposureScale =  1.0; //FrameExposureScale * View_OneOverPreExposure

		// 每像素设置.
		{
			InputParams.ViewportUV = input.uv;
			InputParams.ScreenPos = ViewportUVToScreenPos(InputParams.ViewportUV); // -1 ~ 1

			// 用于TAAU，但是该技术较为落后，固不支持。高端设备建议使用FSR或者DLSS，低端建议使用 TAA + GSR
		    InputParams.NearestBufferUV = InputParams.ViewportUV;// * ViewportUVToInputBufferUV.xy + ViewportUVToInputBufferUV.zw; 

			// todo 
			InputParams.bIsResponsiveAAPixel = 0;
		}

		// 设置中间结果.
		FTAAIntermediaryResult IntermediaryResult = CreateIntermediaryResult();

		// FIND MOTION OF PIXEL AND NEAREST IN NEIGHBORHOOD
		// ------------------------------------------------
        float3 PosN;
        PosN.xy = InputParams.ScreenPos;

		// todo => 使用 group shared memory 优化 computer shader 实现 taa.
		// PrecacheInputSceneDepth(InputParams);
        PosN.z = SampleCachedSceneDepthTexture(InputParams, int2(0, 0));

		// 找到最小深度的屏幕位置.
		float2 VelocityOffset = float2(0.0, 0.0);

		// TODO: 2x2.
		#if AA_CROSS 
		{
			// 用于运动矢量，使用在像素周围模式中最小深度像素的摄像机/动态运动。
			// 这样可以在不同运动背景下获得更好的前景轮廓质量。
			// 较大的 2 像素距离 "x" 效果最佳（因为AA扩大表面）。
			float4 Depths;
			Depths.x = SampleCachedSceneDepthTexture(InputParams, int2(-AA_CROSS, -AA_CROSS));
			Depths.y = SampleCachedSceneDepthTexture(InputParams, int2( AA_CROSS, -AA_CROSS));
			Depths.z = SampleCachedSceneDepthTexture(InputParams, int2(-AA_CROSS,  AA_CROSS));
			Depths.w = SampleCachedSceneDepthTexture(InputParams, int2( AA_CROSS,  AA_CROSS));

			float2 DepthOffset = float2(AA_CROSS, AA_CROSS);
			float DepthOffsetXx = float(AA_CROSS);

			if(Depths.x > Depths.y) 
			{
				DepthOffsetXx = -AA_CROSS;
			}
			if(Depths.z > Depths.w) 
			{
				DepthOffset.x = -AA_CROSS;
			}
			float DepthsXY = max(Depths.x, Depths.y);
			float DepthsZW = max(Depths.z, Depths.w);
			if(DepthsXY > DepthsZW) 
			{
				DepthOffset.y = -AA_CROSS;
				DepthOffset.x = DepthOffsetXx; 
			}
			float DepthsXYZW = max(DepthsXY, DepthsZW);
			if(DepthsXYZW > PosN.z) 
			{

				// 这是从速度纹理读取的偏移量.
				// 这支持半分辨率或分数分辨率的速度纹理.
				VelocityOffset = DepthOffset;

				// This is [0 to 1] flipped in Y.
				// PosN.xy = ScreenPos + DepthOffset * _TAA_V_OutputViewportSize.zw * 2.0;
				PosN.z = DepthsXYZW;
			}
		}
		#endif	// AA_CROSS

		// Camera motion for pixel or nearest pixel (in ScreenPos space).
		bool OffScreen = false;
		float Velocity = 0;
		float HistoryBlur = 0;
		float2 HistoryScreenPosition = InputParams.ScreenPos;

		#if 1
		{
			float2 BackN = 0;//
			float2 BackTemp;

			#if 1
			{
				float4 EncodedVelocity = 0;//_VelocityTexture.SampleLevel(sampler_VelocityTexture, InputParams.NearestBufferUV + VelocityOffset, 0);

				bool DynamicN = EncodedVelocity.x > 0.0;

				if(DynamicN)
				{
					BackN = DecodeVelocityFromTexture(EncodedVelocity).xy;
				}

				BackTemp = BackN * _TAA_V_OutputViewportSize.xy;
			}
			#endif

			Velocity = sqrt(dot(BackTemp, BackTemp));

			#if !AA_BICUBIC
				// 保存仅相机运动的像素偏移量，稍后用作由历史引入的模糊量.
				float HistoryBlurAmp = 2.0;
				HistoryBlur = saturate(abs(BackTemp.x) * HistoryBlurAmp + abs(BackTemp.y) * HistoryBlurAmp);
			#endif

			// 当前像素对应的历史帧位置.
			HistoryScreenPosition = InputParams.ScreenPos - BackN;

        	// 检测HistoryBufferUV是否在视口之外.
			OffScreen = max(abs(HistoryScreenPosition.x), abs(HistoryScreenPosition.y)) >= 1.0;
		}
		#endif

		// todo : computer shader.
		// 缓存输入的颜色数据
		PrecacheInputSceneColor(/* inout = */ InputParams);

		// Filter input.
		FilterCurrentFrameInputSamples(InputParams, /* inout = */ IntermediaryResult);

		// 计算邻域的包围盒.
		FTAAHistoryPayload NeighborMin;
		FTAAHistoryPayload NeighborMax;

		ComputeNeighborhoodBoundingbox(
			InputParams,
			/* inout = */ IntermediaryResult,
			NeighborMin, NeighborMax);


		// 采样历史数据.
		FTAAHistoryPayload History = SampleHistory(HistoryScreenPosition);

		bool bCameraCut = _TAA_F_CameraCut == 1;

		// 是否需要忽略历史数据(历史数据在视口之外或突然出现).
		bool IgnoreHistory = OffScreen || bCameraCut;

		// 动态抗鬼影.
		// ---------------------
		#if AA_DYNAMIC_ANTIGHOST && AA_DYNAMIC && HISTORY_PAYLOAD_COMPONENTS == 3
		bool Dynamic4 = false; // 判断这个点是不是运动的
		//{
		//	#if !AA_DYNAMIC
		//		#error AA_DYNAMIC_ANTIGHOST requires AA_DYNAMIC
		//	#endif
		//	// 分别采样速度缓冲的下边(Dynamic1), 左边(Dynamic3), 自身(Dynamic4), 右边(Dynamic5), 上面(Dynamic7).
		//	bool Dynamic1 = _VelocityTexture.SampleLevel(sampler_VelocityTexture, InputParams.NearestBufferUV, 0, int2( 0, -1)).x > 0;
		//	bool Dynamic3 = _VelocityTexture.SampleLevel(sampler_VelocityTexture, InputParams.NearestBufferUV, 0, int2(-1,  0)).x > 0;
		//	Dynamic4 = _VelocityTexture.SampleLevel(sampler_VelocityTexture, InputParams.NearestBufferUV, 0).x > 0;
		//	bool Dynamic5 = _VelocityTexture.SampleLevel(sampler_VelocityTexture, InputParams.NearestBufferUV, 0, int2( 1,  0)).x > 0;
		//	bool Dynamic7 = _VelocityTexture.SampleLevel(sampler_VelocityTexture, InputParams.NearestBufferUV, 0, int2( 0,  1)).x > 0;

		//	// 判断以上任意一点是否运动的
		//	bool Dynamic = Dynamic1 || Dynamic3 || Dynamic4 || Dynamic5 || Dynamic7;
		//	// 继续判断是否需要忽略历史数据(不运动且历史的alpha>0).
		//	IgnoreHistory = IgnoreHistory || (!Dynamic && History.Color.a > 0);
		//}
		#endif


		// Clamp历史亮度之前先保存之.
		float LumaMin     = GetSceneColorLuma4(NeighborMin.Color);
		float LumaMax     = GetSceneColorLuma4(NeighborMax.Color);
		float LumaHistory = GetSceneColorLuma4(History.Color);

		// Clamp历史数据.
		FTAAHistoryPayload PreClampingHistoryColor = History;
		History = ClampHistory(IntermediaryResult, History, NeighborMin, NeighborMax);



		// 重新添加锯齿以锐化
		// -------------------------------
		#if AA_FILTERED && !AA_BICUBIC
		{
			// Blend in non-filtered based on the amount of sub-pixel motion.
			float AddAliasing = saturate(HistoryBlur) * 0.5;
			float LumaContrastFactor = 32.0;
			#if AA_YCOCG // TODO: Probably a bug arround here because using Luma4() even with YCOCG=0.
				// 1/4 as bright.
				LumaContrastFactor *= 4.0;
			#endif
			float LumaContrast = LumaMax - LumaMin;
			AddAliasing = saturate(AddAliasing + rcp(1.0 + LumaContrast * LumaContrastFactor));
			IntermediaryResult.Filtered.Color = lerp(IntermediaryResult.Filtered.Color, SampleCachedSceneColorTexture(InputParams, int2(0, 0)).Color, AddAliasing);
		}
		#endif


		// 计算混合因子.
		// --------------------
		float BlendFinal;
		{
			float LumaFiltered = GetSceneColorLuma4(IntermediaryResult.Filtered.Color);

			// CurrentFrameWeight是从c++传入的，默认为0.04f
			BlendFinal = _TAA_F_CurrentFrameWeight;
			// 根据速度进行插值，速度越大，则BlendFinal越大
			// 速度越大，历史帧越不可信
			BlendFinal = lerp(BlendFinal, 0.2, saturate(Velocity / 40));

			// 确保至少有一些小的贡献.
			BlendFinal = max( BlendFinal, saturate( 0.01 * LumaHistory / abs( LumaFiltered - LumaHistory ) ) );

			#if AA_NAN && (COMPILER_GLSL || COMPILER_METAL)
				// The current Metal & GLSL compilers don't handle saturate(NaN) -> 0, instead they return NaN/INF.
				BlendFinal = -min(-BlendFinal, 0.0);
			#endif

			// ResponsiveAA强制成新帧的1/4.
			BlendFinal = InputParams.bIsResponsiveAAPixel ? (1.0/4.0) : BlendFinal;

			#if AA_LERP 
				BlendFinal = 1.0/float(AA_LERP);
			#endif
			
			// 如果是镜头切换, 当前帧强制成1.
			if (bCameraCut)
			{
				BlendFinal = 1.0;
			}
		}

		// return History.Color;
		// 忽略历史帧, 重置数据.
		if (IgnoreHistory)
		{
			// 历史帧等于滤波后的结果.
			History = IntermediaryResult.Filtered;

			#if HISTORY_PAYLOAD_COMPONENTS == 3
				History.Color.a = 0.0;
			#endif
		}

		// 最终在历史和过滤颜色之间混合
		// -------------------------------------------------
		// 亮度权重混合.
		float FilterWeight = GetSceneColorHdrWeight(InputParams, IntermediaryResult.Filtered.Color.x);
		float HistoryWeight = GetSceneColorHdrWeight(InputParams, History.Color.x);

		FTAAHistoryPayload OutputPayload;
		{
			// 计算带权重的插值.
			float2 Weights = WeightedLerpFactors(HistoryWeight, FilterWeight, BlendFinal);
			// 增加输出的历史负载数据, 会进行加权, 历史帧的alpha会乘以Weights.x系数下降.
			OutputPayload = AddPayload(MulPayload(History, Weights.x), MulPayload(IntermediaryResult.Filtered, Weights.y));
		}

		// 调整靠近1的Alpha, 0.995 < 0.996 = 254/255
		if (OutputPayload.Color.a > 0.995)
		{
			OutputPayload.Color.a = 1;
		}

		// 转换颜色回到线性空间.
    	OutputPayload.Color = TransformBackToRawLinearSceneColor(OutputPayload.Color);

		// 非法数据.
		#if AA_NAN 
			OutputPayload.Color = -min(-OutputPayload.Color, 0.0);
		#endif

		#if HISTORY_PAYLOAD_COMPONENTS == 3
			#if  AA_DYNAMIC_ANTIGHOST && AA_DYNAMIC 
				// 如果这一帧是运动的话，那么alpha为1，写入历史帧.
				OutputPayload.Color.a = Dynamic4 ? 1 : 0;
			#else
				// 不运动或非动态, Alpha为0.
				OutputPayload.Color.a = 0;
			#endif
		#endif


		float4 OutColor0 = 0;
		float4 OutColor1 = 0;

		OutColor0 = OutputPayload.Color;

		float4 FinalOutput0 = min(MaxHalfFloat.xxxx, OutColor0);

		#if 1
		{
			uint2 PixelPos = InputParams.ViewportUV * _TAA_V_OutputViewportSize.xy;

			// 随机量化采样.
			#if AA_ENABLE_STOCASTIC_QUANTIZATION
			{
				uint2 Random = Rand3DPCG16(int3(PixelPos, _U_StateFrameIndexMod8)).xy;
				float2 E = Hammersley16(0, 1, Random);

				FinalOutput0.rgb += FinalOutput0.rgb * (E.x * _TAA_V_OutputQuantizationError.rgb);
			}
			#endif
		}
		#endif

	    return FinalOutput0;
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
                #pragma fragment frag_taa
            ENDHLSL
        }
    }
}
