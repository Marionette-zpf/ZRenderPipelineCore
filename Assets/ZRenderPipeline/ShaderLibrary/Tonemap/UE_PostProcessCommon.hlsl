#ifndef UE_POST_PROCESS_COMMON_INCLUDE
#define UE_POST_PROCESS_COMMON_INCLUDE

Texture2D PostprocessInput0;
SamplerState PostprocessInput0Sampler;
Texture2D PostprocessInput1;
SamplerState PostprocessInput1Sampler;
Texture2D PostprocessInput2;
SamplerState PostprocessInput2Sampler;
Texture2D PostprocessInput3;
SamplerState PostprocessInput3Sampler;
Texture2D PostprocessInput4;
SamplerState PostprocessInput4Sampler;
Texture2D PostprocessInput5;
SamplerState PostprocessInput5Sampler;
Texture2D PostprocessInput6;
SamplerState PostprocessInput6Sampler;
Texture2D PostprocessInput7;
SamplerState PostprocessInput7Sampler;
Texture2D PostprocessInput8;
SamplerState PostprocessInput8Sampler;
Texture2D PostprocessInput9;
SamplerState PostprocessInput9Sampler;
Texture2D PostprocessInput10;
SamplerState PostprocessInput10Sampler;


float4 PostprocessInput0Size;
float4 PostprocessInput1Size;
float4 PostprocessInput2Size;
float4 PostprocessInput3Size;
float4 PostprocessInput4Size;
float4 PostprocessInput5Size;
float4 PostprocessInput6Size;
float4 PostprocessInput7Size;
float4 PostprocessInput8Size;
float4 PostprocessInput9Size;
float4 PostprocessInput10Size;


float4 PostprocessInput0MinMax;
float4 PostprocessInput1MinMax;
float4 PostprocessInput2MinMax;
float4 PostprocessInput3MinMax;
float4 PostprocessInput4MinMax;
float4 PostprocessInput5MinMax;
float4 PostprocessInput6MinMax;
float4 PostprocessInput7MinMax;
float4 PostprocessInput8MinMax;
float4 PostprocessInput9MinMax;
float4 PostprocessInput10MinMax;

float4 ViewportSize;

uint4 ViewportRect;

float4 ScreenPosToPixel;
float4 SceneColorBufferUVViewport;

float2 ViewportUVToPostProcessingSceneColorBufferUV(float2 ViewportUV)
{
	return ViewportUV * SceneColorBufferUVViewport.xy + SceneColorBufferUVViewport.zw;
}

float DiscMask(float2 ScreenPos)
{
	float x = saturate(1.0f - dot(ScreenPos, ScreenPos));

	return x * x;
}

float RectMask(float2 ScreenPos)
{
	float2 UV = saturate(ScreenPos * 0.5 + 0.5f);
	float2 Mask2 = UV * (1 - UV);

	return Mask2.x * Mask2.y * 8.0f;
}

float ComputeDistanceToRect(int2 Pos, int2 LeftTop, int2 Extent, bool bRoundBorders = true)
{
	int2 RightBottom = LeftTop + Extent - 1;


	int2 Rel = max(int2(0, 0), Pos - RightBottom) + max(int2(0, 0), LeftTop - Pos);

	if(bRoundBorders)
	{

		return length((float2)Rel);
	}
	else
	{

		return max(Rel.x, Rel.y);
	}
}

float3 MappingPolynomial;

float3  ColorCorrection( float3  InLDRColor)
{

	return MappingPolynomial.x * (InLDRColor * InLDRColor) + MappingPolynomial.y * InLDRColor + MappingPolynomial.z;
}

float ComputeVignetteMask(float2 VignetteCircleSpacePos, float Intensity)
{


	VignetteCircleSpacePos *= Intensity;
	float Tan2Angle = dot( VignetteCircleSpacePos, VignetteCircleSpacePos );
	float Cos4Angle = Square( rcp( Tan2Angle + 1 ) );
	return Cos4Angle;
}

float2 VignetteSpace(float2 Pos, float AspectRatio)
{

	float Scale = sqrt(2.0) / sqrt(1.0 + AspectRatio * AspectRatio);
	return Pos * float2(1.0, AspectRatio) * Scale;
}

float2 VignetteSpace(float2 Pos)
{
	return VignetteSpace(Pos, ViewportSize.y * ViewportSize.z);
}

float4  UnwrappedTexture3DSample( Texture2D Texture, SamplerState Sampler, float3 UVW, float Size )
{
	float IntW = floor( UVW.z * Size - 0.5 );
	float  FracW = UVW.z * Size - 0.5 - IntW;

	float U = ( UVW.x + IntW ) / Size;
	float V = UVW.y;

	float4  RG0 = Texture2DSample( Texture, Sampler, float2(U, V) );
	float4  RG1 = Texture2DSample( Texture, Sampler, float2(U + 1.0f / Size, V) );

	return lerp(RG0, RG1, FracW);
}

bool IsComputeUVOutOfBounds(in float2 UV)
{
	float2 CenterDist = abs(UV - 0.5f);
	return (max(CenterDist.x, CenterDist.y) >= 0.5f);
}


float  CocMaxRadiusInPixelsRcp()
{
	float2  MaxOffset =  float2 (-2.125, -0.50) * 2.0;
	return rcp(sqrt(dot(MaxOffset, MaxOffset)));
}

float2  CocBlendScaleBias()
{
	float  Start = 0.25 * CocMaxRadiusInPixelsRcp();
	float  End = 1.0 * CocMaxRadiusInPixelsRcp();
	float2  ScaleBias;
	ScaleBias.x = 1.0 / (End - Start);
	ScaleBias.y = (-Start) * ScaleBias.x;
	return ScaleBias;
}

float2  CocBlendScaleBiasFine()
{
	float  Start = 0.0 * CocMaxRadiusInPixelsRcp();
	float  End = 0.5 * CocMaxRadiusInPixelsRcp();
	float2  ScaleBias;
	ScaleBias.x = 1.0 / (End - Start);
	ScaleBias.y = (-Start) * ScaleBias.x;
	return ScaleBias;
}
#endif