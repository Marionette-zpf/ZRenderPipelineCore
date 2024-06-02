#ifndef Z_RENDER_PIPELINE_COMMON_INCLUDE
#define Z_RENDER_PIPELINE_COMMON_INCLUDE

#include "Assets/ZRenderPipeline/ShaderLibrary/Input.hlsl"
#include "Assets/ZRenderPipeline/ShaderLibrary/TextureSampling.hlsl"
#include "Assets/ZRenderPipeline/ShaderLibrary/Platform.hlsl"
 
//// These types are used for material translator generated code, or any functions the translated code can call
//#if PIXELSHADER
//	#define MaterialFloat half
//	#define MaterialFloat2 half2
//	#define MaterialFloat3 half3
//	#define MaterialFloat4 half4
//	#define MaterialFloat3x3 half3x3
//	#define MaterialFloat4x4 half4x4 
//	#define MaterialFloat4x3 half4x3 
//#else
	// Material translated vertex shader code always uses floats, 
	// Because it's used for things like world position and UVs
	#define MaterialFloat float
	#define MaterialFloat2 float2
	#define MaterialFloat3 float3
	#define MaterialFloat4 float4
	#define MaterialFloat3x3 float3x3
	#define MaterialFloat4x4 float4x4 
	#define MaterialFloat4x3 float4x3 
//#endif

#ifndef PI
const static float PI = 3.1415926535897932f;
#endif

const static float MaxHalfFloat = 65504.0f;
const static float Max10BitsFloat = 64512.0f;




float4 Texture2DSample(Texture2D Tex, SamplerState Sampler, float2 UV)
{
	return Tex.SampleLevel(Sampler, UV, 0);
}

float4 Texture2DSampleLevel(Texture2D Tex, SamplerState Sampler, float2 UV, float Mip)
{
	return Tex.SampleLevel(Sampler, UV, Mip);
}


MaterialFloat Luminance( MaterialFloat3 LinearColor )
{
	return dot( LinearColor, MaterialFloat3( 0.3, 0.59, 0.11 ) );
}

MaterialFloat length2(MaterialFloat2 v)
{
	return dot(v, v);
}
MaterialFloat length2(MaterialFloat3 v)
{
	return dot(v, v);
}
MaterialFloat length2(MaterialFloat4 v)
{
	return dot(v, v);
}


uint Mod(uint a, uint b)
{
#if FEATURE_LEVEL >= FEATURE_LEVEL_ES3_1
	return a % b;
#else
	return a - (b * (uint)((float)a / (float)b));
#endif
}

uint2 Mod(uint2 a, uint2 b)
{
#if FEATURE_LEVEL >= FEATURE_LEVEL_ES3_1
	return a % b;
#else
	return a - (b * (uint2)((float2)a / (float2)b));
#endif
}

uint3 Mod(uint3 a, uint3 b)
{
#if FEATURE_LEVEL >= FEATURE_LEVEL_ES3_1
	return a % b;
#else
	return a - (b * (uint3)((float3)a / (float3)b));
#endif
}

MaterialFloat UnClampedPow(MaterialFloat X, MaterialFloat Y)
{
	return pow(X, INVARIANT(Y));
}
MaterialFloat2 UnClampedPow(MaterialFloat2 X, MaterialFloat2 Y)
{
	return pow(X, INVARIANT(Y));
}
MaterialFloat3 UnClampedPow(MaterialFloat3 X, MaterialFloat3 Y)
{
	return pow(X, INVARIANT(Y));
}
MaterialFloat4 UnClampedPow(MaterialFloat4 X, MaterialFloat4 Y)
{
	return pow(X, INVARIANT(Y));
}

#define POW_CLAMP 0.000001f

// Clamp the base, so it's never <= 0.0f (INF/NaN).
MaterialFloat ClampedPow(MaterialFloat X,MaterialFloat Y)
{
	return pow(max(abs(X),POW_CLAMP),Y);
}
MaterialFloat2 ClampedPow(MaterialFloat2 X,MaterialFloat2 Y)
{
	return pow(max(abs(X),MaterialFloat2(POW_CLAMP,POW_CLAMP)),Y);
}
MaterialFloat3 ClampedPow(MaterialFloat3 X,MaterialFloat3 Y)
{
	return pow(max(abs(X),MaterialFloat3(POW_CLAMP,POW_CLAMP,POW_CLAMP)),Y);
}  
MaterialFloat4 ClampedPow(MaterialFloat4 X,MaterialFloat4 Y)
{
	return pow(max(abs(X),MaterialFloat4(POW_CLAMP,POW_CLAMP,POW_CLAMP,POW_CLAMP)),Y);
} 

/* Pow function that will return 0 if Base is <=0. This ensures that no compiler expands pow into exp(Exponent * log(Base)) with Base=0 */
MaterialFloat PositiveClampedPow(MaterialFloat Base, MaterialFloat Exponent)
{
	return (Base <= 0.0f) ? 0.0f : pow(Base, Exponent);
}
MaterialFloat2 PositiveClampedPow(MaterialFloat2 Base, MaterialFloat2 Exponent)
{
	return MaterialFloat2(PositiveClampedPow(Base.x, Exponent.x), PositiveClampedPow(Base.y, Exponent.y)); 
}
MaterialFloat3 PositiveClampedPow(MaterialFloat3 Base, MaterialFloat3 Exponent)
{
	return MaterialFloat3(PositiveClampedPow(Base.xy, Exponent.xy), PositiveClampedPow(Base.z, Exponent.z)); 
}  
MaterialFloat4 PositiveClampedPow(MaterialFloat4 Base, MaterialFloat4 Exponent)
{
	return MaterialFloat4(PositiveClampedPow(Base.xy, Exponent.xy), PositiveClampedPow(Base.zw, Exponent.zw)); 
} 

float DDX(float Input)
{
#if USE_FORCE_TEXTURE_MIP
	return 0;
#else
	return ddx(Input);
#endif
}

float2 DDX(float2 Input)
{
#if USE_FORCE_TEXTURE_MIP
	return 0;
#else
	return ddx(Input);
#endif
}

float3 DDX(float3 Input)
{
#if USE_FORCE_TEXTURE_MIP
	return 0;
#else
	return ddx(Input);
#endif
}

float4 DDX(float4 Input)
{
#if USE_FORCE_TEXTURE_MIP
	return 0;
#else
	return ddx(Input);
#endif
}

float DDY(float Input)
{
#if USE_FORCE_TEXTURE_MIP
	return 0;
#else
	return ddy(Input);
#endif
}

float2 DDY(float2 Input)
{
#if USE_FORCE_TEXTURE_MIP
	return 0;
#else
	return ddy(Input);
#endif
}

float3 DDY(float3 Input)
{
#if USE_FORCE_TEXTURE_MIP
	return 0;
#else
	return ddy(Input);
#endif
}

float4 DDY(float4 Input)
{
#if USE_FORCE_TEXTURE_MIP
	return 0;
#else
	return ddy(Input);
#endif
}


uint ReverseBits32( uint bits )
{
	return reversebits( bits );
}

//float2 Hammersley16( uint Index, uint NumSamples, uint2 Random )
//{
//	float E1 = frac( (float)Index / NumSamples + float( Random.x ) * (1.0 / 65536.0) );
//	float E2 = float( ( ReverseBits32(Index) >> 16 ) ^ Random.y ) * (1.0 / 65536.0);
//	return float2( E1, E2 );
//}

float2 ViewportUVToScreenPos(float2 ViewportUV)
{
	return 2 * ViewportUV.xy - 1;
}


float ConvertFromDeviceZ(float DeviceZ)
{
	return LinearEyeDepth(DeviceZ, _ZBufferParams);
}


// for velocity rendering, motionblur and temporal AA
// velocity needs to support -2..2 screen space range for x and y
// texture is 16bit 0..1 range per channel
float4 EncodeVelocityToTexture(float3 V)
{
	// 0.499f is a value smaller than 0.5f to avoid using the full range to use the clear color (0,0) as special value
	// 0.5f to allow for a range of -2..2 instead of -1..1 for really fast motions for temporal AA
	float4 EncodedV;
	EncodedV.xy = V.xy * (0.499f * 0.5f) + 32767.0f / 65535.0f;

#if VELOCITY_ENCODE_DEPTH
	uint Vz = asuint(V.z);

	EncodedV.z = saturate(float((Vz >> 16) & 0xFFFF) * rcp(65535.0f) + (0.1 / 65535.0f));
	EncodedV.w = saturate(float((Vz >>  0) & 0xFFFF) * rcp(65535.0f) + (0.1 / 65535.0f));

	return EncodedV;
#else
	return float4(EncodedV.x, EncodedV.y, 0, 0);
#endif
}
// see EncodeVelocityToTexture()
float3 DecodeVelocityFromTexture(float4 EncodedV)
{
	const float InvDiv = 1.0f / (0.499f * 0.5f);

	float3 V;
	V.xy = EncodedV.xy * InvDiv - 32767.0f / 65535.0f * InvDiv;

#if VELOCITY_ENCODE_DEPTH
	V.z = asfloat((uint(round(EncodedV.z * 65535.0f)) << 16) | uint(round(EncodedV.w * 65535.0f)));

	return V;
#else
	return float3 (V.x, V.y, 0);
#endif
}



uniform float4 _DrawRectangleParameters_PosScaleBias; // "1124.00, 684.00, 0.00, 0.00",0,float4
uniform float4 _DrawRectangleParameters_UVScaleBias;  // "1124.00, 684.00, 0.00, 0.00",16,float4
uniform float4 _DrawRectangleParameters_InvTargetSizeAndTextureSize; // "0.00089, 0.00146, 0.00089, 0.00146",32,float4

/** Used for calculating vertex positions and UVs when drawing with DrawRectangle */
void DrawRectangle(
	in  float4 InPosition,
	in  float2 InTexCoord,
	out float4 OutPosition,
	out float2 OutTexCoord
    )
{
	OutPosition = InPosition;
	OutPosition.xy = -1.0f + 2.0f * (_DrawRectangleParameters_PosScaleBias.zw + (InPosition.xy * _DrawRectangleParameters_PosScaleBias.xy)) * _DrawRectangleParameters_InvTargetSizeAndTextureSize.xy;
	OutPosition.xy *= float2( 1, -1 );
	OutTexCoord.xy = (_DrawRectangleParameters_UVScaleBias.zw + (InTexCoord.xy * _DrawRectangleParameters_UVScaleBias.xy)) * _DrawRectangleParameters_InvTargetSizeAndTextureSize.zw;
}

#include "Assets/ZRenderPipeline/ShaderLibrary/FastMath.hlsl"
#include "Assets/ZRenderPipeline/ShaderLibrary/Random.hlsl"

/** 
 * Use this function to compute the pow() in the specular computation.
 * This allows to change the implementation depending on platform or it easily can be replaced by some approxmation.
 */
MaterialFloat PhongShadingPow(MaterialFloat X, MaterialFloat Y)
{
	// The following clamping is done to prevent NaN being the result of the specular power computation.
	// Clamping has a minor performance cost.

	// In HLSL pow(a, b) is implemented as exp2(log2(a) * b).

	// For a=0 this becomes exp2(-inf * 0) = exp2(NaN) = NaN.

	// As seen in #TTP 160394 "QA Regression: PS3: Some maps have black pixelated artifacting."
	// this can cause severe image artifacts (problem was caused by specular power of 0, lightshafts propagated this to other pixels).
	// The problem appeared on PlayStation 3 but can also happen on similar PC NVidia hardware.

	// In order to avoid platform differences and rarely occuring image atrifacts we clamp the base.

	// Note: Clamping the exponent seemed to fix the issue mentioned TTP but we decided to fix the root and accept the
	// minor performance cost.

	return ClampedPow(X, Y);
}

// Optional VertexID - used by tessellation to uniquely identify control points.
#if USING_TESSELLATION && DISPLACEMENT_ANTICRACK
	#define OPTIONAL_VertexID			uint VertexID : SV_VertexID,
	#define OPTIONAL_VertexID_PARAM		VertexID,
	#define OPTIONAL_VertexID_VS_To_DS	uint VertexID : VS_To_DS_VertexID;
	#define OutputVertexID( Out ) Out.VertexID = VertexID
#else // #if USING_TESSELLATION && DISPLACEMENT_ANTICRACK
	#define OPTIONAL_VertexID
	#define OPTIONAL_VertexID_PARAM
	#define OPTIONAL_VertexID_VS_To_DS
	#define OutputVertexID( Out )
#endif // #if USING_TESSELLATION && DISPLACEMENT_ANTICRACK


Texture2D		LightAttenuationTexture;

float Square( float x )
{
	return x*x;
}

float2 Square( float2 x )
{
	return x*x;
}

float3 Square( float3 x )
{
	return x*x;
}

float4 Square( float4 x )
{
	return x*x;
}

float Pow2( float x )
{
	return x*x;
}

float2 Pow2( float2 x )
{
	return x*x;
}

float3 Pow2( float3 x )
{
	return x*x;
}

float4 Pow2( float4 x )
{
	return x*x;
}

float Pow3( float x )
{
	return x*x*x;
}

float2 Pow3( float2 x )
{
	return x*x*x;
}

float3 Pow3( float3 x )
{
	return x*x*x;
}

float4 Pow3( float4 x )
{
	return x*x*x;
}

#ifndef UNITY_POW4

float Pow4( float x )
{
	float xx = x*x;
	return xx * xx;
}

#endif

float2 Pow4( float2 x )
{
	float2 xx = x*x;
	return xx * xx;
}

float3 Pow4( float3 x )
{
	float3 xx = x*x;
	return xx * xx;
}

float4 Pow4( float4 x )
{
	float4 xx = x*x;
	return xx * xx;
}

float Pow5( float x )
{
	float xx = x*x;
	return xx * xx * x;
}

float2 Pow5( float2 x )
{
	float2 xx = x*x;
	return xx * xx * x;
}

float3 Pow5( float3 x )
{
	float3 xx = x*x;
	return xx * xx * x;
}

float4 Pow5( float4 x )
{
	float4 xx = x*x;
	return xx * xx * x;
}

float Pow6( float x )
{
	float xx = x*x;
	return xx * xx * xx;
}

float2 Pow6( float2 x )
{
	float2 xx = x*x;
	return xx * xx * xx;
}

float3 Pow6( float3 x )
{
	float3 xx = x*x;
	return xx * xx * xx;
}

float4 Pow6( float4 x )
{
	float4 xx = x*x;
	return xx * xx * xx;
}

//Since some platforms don't remove Nans in saturate calls, 
//SafeSaturate function will remove nan/inf.    
//Can be expensive, only call when there's a good reason to expect Nans.
//D3D saturate actually turns NaNs -> 0  since it does the max(0.0f, value) first, and D3D NaN rules specify the non-NaN operand wins in such a case.  
//See: https://docs.microsoft.com/en-us/windows/desktop/direct3dhlsl/saturate
#define SafeSaturate_Def(type)\
type SafeSaturate(type In) \
{\
	return saturate(In);\
}

SafeSaturate_Def(float)
SafeSaturate_Def(float2)
SafeSaturate_Def(float3)
SafeSaturate_Def(float4)


// Only valid for x >= 0
MaterialFloat AtanFast( MaterialFloat x )
{
	// Minimax 3 approximation
	MaterialFloat3 A = x < 1 ? MaterialFloat3( x, 0, 1 ) : MaterialFloat3( 1/x, 0.5 * PI, -1 );
	return A.y + A.z * ( ( ( -0.130234 * A.x - 0.0954105 ) * A.x + 1.00712 ) * A.x - 0.00001203333 );
}

/** Converts a linear input value into a value to be stored in the light attenuation buffer. */
MaterialFloat EncodeLightAttenuation(MaterialFloat InColor)
{
	// Apply a 1/2 power to the input, which allocates more bits for the darks and prevents banding
	// Similar to storing colors in gamma space, except this uses less instructions than a pow(x, 1/2.2)
	return sqrt(InColor);
}

/** Converts a linear input value into a value to be stored in the light attenuation buffer. */
MaterialFloat4 EncodeLightAttenuation(MaterialFloat4 InColor)
{
	return sqrt(InColor);
}

// Like RGBM but this can be interpolated.
MaterialFloat4 RGBTEncode(MaterialFloat3 Color)
{
	MaterialFloat4 RGBT;
	MaterialFloat Max = max(max(Color.r, Color.g), max(Color.b, 1e-6));
	MaterialFloat RcpMax = rcp(Max);
	RGBT.rgb = Color.rgb * RcpMax;
	RGBT.a = Max * rcp(1.0 + Max);
	return RGBT;
}

MaterialFloat3 RGBTDecode(MaterialFloat4 RGBT)
{
	RGBT.a = RGBT.a * rcp(1.0 - RGBT.a);
	return RGBT.rgb * RGBT.a;
}



MaterialFloat4 RGBMEncode( MaterialFloat3 Color )
{
	Color *= 1.0 / 64.0;
	
	float4 rgbm;
	rgbm.a = saturate( max( max( Color.r, Color.g ), max( Color.b, 1e-6 ) ) );
	rgbm.a = ceil( rgbm.a * 255.0 ) / 255.0;
	rgbm.rgb = Color / rgbm.a;
	return rgbm;
}

MaterialFloat4 RGBMEncodeFast( MaterialFloat3 Color )
{
	// 0/0 result written to fixed point buffer goes to zero
	MaterialFloat4 rgbm;
	rgbm.a = dot( Color, 255.0 / 64.0 );
	rgbm.a = ceil( rgbm.a );
	rgbm.rgb = Color / rgbm.a;
	rgbm *= MaterialFloat4( 255.0 / 64.0, 255.0 / 64.0, 255.0 / 64.0, 1.0 / 255.0 );
	return rgbm;
}

MaterialFloat3 RGBMDecode( MaterialFloat4 rgbm, MaterialFloat MaxValue )
{
	return rgbm.rgb * (rgbm.a * MaxValue);
}

MaterialFloat3 RGBMDecode( MaterialFloat4 rgbm )
{
	return rgbm.rgb * (rgbm.a * 64.0f);
}

MaterialFloat4 RGBTEncode8BPC(MaterialFloat3 Color, MaterialFloat Range)
{
	MaterialFloat Max = max(max(Color.r, Color.g), max(Color.b, 1e-6));
	Max = min(Max, Range);

	MaterialFloat4 RGBT;
	RGBT.a = (Range + 1) / Range *  Max / (1 + Max);

	// quantise alpha to 8 bit.
	RGBT.a = ceil(RGBT.a*255.0) / 255.0;
	Max = RGBT.a / (1 + 1 / Range - RGBT.a);

	MaterialFloat RcpMax = rcp(Max);
	RGBT.rgb = Color.rgb * RcpMax;
	return RGBT;
}

MaterialFloat3 RGBTDecode8BPC(MaterialFloat4 RGBT, MaterialFloat Range)
{
	RGBT.a = RGBT.a / (1 + 1 / Range - RGBT.a);
	return RGBT.rgb * RGBT.a;
}

float4 GetPerPixelLightAttenuation(float2 UV)
{
	return Square(Texture2DSampleLevel(LightAttenuationTexture, sampler_PointClamp, UV, 0));
}



#endif