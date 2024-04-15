#ifndef UE_TONEMAP_COMMON_INCLUDE
#define UE_TONEMAP_COMMON_INCLUDE

#include "UE_GammaCorrectionCommon.hlsl"

float3  InverseGamma;

static const float LinearToNitsScale = 100.0;
static const float LinearToNitsScaleInverse = 1.0 / 100.0;


float4  ColorMatrixR_ColorCurveCd1;
float4  ColorMatrixG_ColorCurveCd3Cm3;
float4  ColorMatrixB_ColorCurveCm2;
float4  ColorCurve_Cm0Cd0_Cd2_Ch0Cm1_Ch3;
float4  ColorCurve_Ch1_Ch2;
float4  ColorShadow_Luma;
float4  ColorShadow_Tint1;
float4  ColorShadow_Tint2;

float3  FilmPostProcess( float3  LinearColor)
{

	float3  MatrixColor;


	MatrixColor.r = dot(LinearColor, ColorMatrixR_ColorCurveCd1.rgb);
	MatrixColor.g = dot(LinearColor, ColorMatrixG_ColorCurveCd3Cm3.rgb);
	MatrixColor.b = dot(LinearColor, ColorMatrixB_ColorCurveCm2.rgb);

	MatrixColor *= ColorShadow_Tint1.rgb + ColorShadow_Tint2.rgb * rcp(dot(LinearColor, ColorShadow_Luma.rgb) + 1.0);


	MatrixColor = max( float3 (0.0, 0.0, 0.0), MatrixColor);

	float3  MatrixColorD = max(0, ColorCurve_Cm0Cd0_Cd2_Ch0Cm1_Ch3.xxx - MatrixColor);
	float3  MatrixColorH = max(MatrixColor, ColorCurve_Cm0Cd0_Cd2_Ch0Cm1_Ch3.zzz);
	float3  MatrixColorM = clamp(MatrixColor, ColorCurve_Cm0Cd0_Cd2_Ch0Cm1_Ch3.xxx, ColorCurve_Cm0Cd0_Cd2_Ch0Cm1_Ch3.zzz);
	float3  CurveColor   = (MatrixColorH*ColorCurve_Ch1_Ch2.xxx + ColorCurve_Ch1_Ch2.yyy) * rcp(MatrixColorH + ColorCurve_Cm0Cd0_Cd2_Ch0Cm1_Ch3.www) +
						   (
						   (MatrixColorM*ColorMatrixB_ColorCurveCm2.aaa + ((MatrixColorD*ColorMatrixR_ColorCurveCd1.aaa) * rcp(MatrixColorD + ColorCurve_Cm0Cd0_Cd2_Ch0Cm1_Ch3.yyy) + ColorMatrixG_ColorCurveCd3Cm3.aaa)
						   )
						   );

	CurveColor -= 0.002;

	return CurveColor;
}

float3  TonemapAndGammaCorrect( float3  LinearColor)
{


	LinearColor = max(LinearColor, 0);

	float3  GammaColor = pow(LinearColor, InverseGamma.x);


	GammaColor = saturate(GammaColor);

	return GammaColor;
}

float FilmSlope;
float FilmToe;
float FilmShoulder;
float FilmBlackClip;
float FilmWhiteClip;

float3  FilmToneMap(  float3  LinearColor )
{
	const float3x3 sRGB_2_AP0 = mul( XYZ_2_AP0_MAT, mul( D65_2_D60_CAT, sRGB_2_XYZ_MAT ) );
	const float3x3 sRGB_2_AP1 = mul( XYZ_2_AP1_MAT, mul( D65_2_D60_CAT, sRGB_2_XYZ_MAT ) );

	const float3x3 AP0_2_sRGB = mul( XYZ_2_sRGB_MAT, mul( D60_2_D65_CAT, AP0_2_XYZ_MAT ) );
	const float3x3 AP1_2_sRGB = mul( XYZ_2_sRGB_MAT, mul( D60_2_D65_CAT, AP1_2_XYZ_MAT ) );

	const float3x3 AP0_2_AP1 = mul( XYZ_2_AP1_MAT, AP0_2_XYZ_MAT );
	const float3x3 AP1_2_AP0 = mul( XYZ_2_AP0_MAT, AP1_2_XYZ_MAT );

	float3 ColorAP1 = LinearColor;
	float3 ColorAP0 = mul( AP1_2_AP0, ColorAP1 );

	const float RRT_GLOW_GAIN = 0.05;
	const float RRT_GLOW_MID = 0.08;

	float saturation = rgb_2_saturation( ColorAP0 );
	float ycIn = rgb_2_yc( ColorAP0 );
	float s = sigmoid_shaper( (saturation - 0.4) / 0.2);
	float addedGlow = 1 + glow_fwd( ycIn, RRT_GLOW_GAIN * s, RRT_GLOW_MID);
	ColorAP0 *= addedGlow;

	const float RRT_RED_SCALE = 0.82;
	const float RRT_RED_PIVOT = 0.03;
	const float RRT_RED_HUE = 0;
	const float RRT_RED_WIDTH = 135;
	float hue = rgb_2_hue( ColorAP0 );
	float centeredHue = center_hue( hue, RRT_RED_HUE );
	float hueWeight = Square( smoothstep( 0, 1, 1 - abs( 2 * centeredHue / RRT_RED_WIDTH ) ) );

	ColorAP0.r += hueWeight * saturation * (RRT_RED_PIVOT - ColorAP0.r) * (1. - RRT_RED_SCALE);

	float3 WorkingColor = mul( AP0_2_AP1_MAT, ColorAP0 );

	WorkingColor = max( 0, WorkingColor );
	WorkingColor = lerp( dot( WorkingColor, AP1_RGB2Y ), WorkingColor, 0.96 );

	const  float  ToeScale = 1 + FilmBlackClip - FilmToe;
	const  float  ShoulderScale = 1 + FilmWhiteClip - FilmShoulder;

	const float InMatch = 0.18;
	const float OutMatch = 0.18;

	float ToeMatch;

	if( FilmToe > 0.8 )
	{
		ToeMatch = ( 1 - FilmToe - OutMatch ) / FilmSlope + log10( InMatch );
	}
	else
	{
		const float bt = ( OutMatch + FilmBlackClip ) / ToeScale - 1;
		ToeMatch = log10( InMatch ) - 0.5 * log( (1+bt)/(1-bt) ) * (ToeScale / FilmSlope);
	}

	float StraightMatch = ( 1 - FilmToe ) / FilmSlope - ToeMatch;
	float ShoulderMatch = FilmShoulder / FilmSlope - StraightMatch;

	float3  LogColor = log10( WorkingColor );
	float3  StraightColor = FilmSlope * ( LogColor + StraightMatch );

	float3  ToeColor = ( -FilmBlackClip ) + (2 * ToeScale) / ( 1 + exp( (-2 * FilmSlope / ToeScale) * ( LogColor - ToeMatch ) ) );
	float3  ShoulderColor = ( 1 + FilmWhiteClip ) - (2 * ShoulderScale) / ( 1 + exp( ( 2 * FilmSlope / ShoulderScale) * ( LogColor - ShoulderMatch ) ) );

	ToeColor = LogColor < ToeMatch ? ToeColor : StraightColor;
	ShoulderColor = LogColor > ShoulderMatch ? ShoulderColor : StraightColor;

	float3  t = saturate( ( LogColor - ToeMatch ) / ( ShoulderMatch - ToeMatch ) );
	t = ShoulderMatch < ToeMatch ? 1 - t : t;
	t = (3-2*t)*t*t;
	float3  ToneColor = lerp( ToeColor, ShoulderColor, t );


	ToneColor = lerp( dot( float3(ToneColor), AP1_RGB2Y ), ToneColor, 0.93 );


	return max( 0, ToneColor );
}

float3  FilmToneMapInverse(  float3  ToneColor )
{
	const float3x3 sRGB_2_AP1 = mul( XYZ_2_AP1_MAT, mul( D65_2_D60_CAT, sRGB_2_XYZ_MAT ) );
	const float3x3 AP1_2_sRGB = mul( XYZ_2_sRGB_MAT, mul( D60_2_D65_CAT, AP1_2_XYZ_MAT ) );


	float3  WorkingColor = mul( sRGB_2_AP1, saturate( ToneColor ) );

	WorkingColor = max( 0, WorkingColor );


	WorkingColor = lerp( dot( WorkingColor, AP1_RGB2Y ), WorkingColor, 1.0 / 0.93 );

	float3  ToeColor = 0.374816 * pow( 0.9 / min( WorkingColor, 0.8 ) - 1, -0.588729 );
	float3  ShoulderColor = 0.227986 * pow( 1.56 / ( 1.04 - WorkingColor ) - 1, 1.02046 );

	float3  t = saturate( ( WorkingColor - 0.35 ) / ( 0.45 - 0.35 ) );
	t = (3-2*t)*t*t;
	float3  LinearColor = lerp( ToeColor, ShoulderColor, t );


	LinearColor = lerp( dot( LinearColor, AP1_RGB2Y ), LinearColor, 1.0 / 0.96 );

	LinearColor = mul( AP1_2_sRGB, LinearColor );


	return max( 0, LinearColor );
}

float3 ACESOutputTransformsRGBD65( float3 SceneReferredLinearsRGBColor )
{
	const float3x3 sRGB_2_AP0 = mul( XYZ_2_AP0_MAT, mul( D65_2_D60_CAT, sRGB_2_XYZ_MAT ) );

	float3 aces = mul( sRGB_2_AP0, SceneReferredLinearsRGBColor * 1.5 );
	float3 oces = RRT( aces );
	float3 OutputReferredLinearsRGBColor = ODT_sRGB_D65( oces );
	return OutputReferredLinearsRGBColor;
}

float3 InverseACESOutputTransformsRGBD65( float3 OutputReferredLinearsRGBColor )
{
	const float3x3 AP0_2_sRGB = mul( XYZ_2_sRGB_MAT, mul( D60_2_D65_CAT, AP0_2_XYZ_MAT ) );

	float3 oces = Inverse_ODT_sRGB_D65( OutputReferredLinearsRGBColor );
	float3 aces = Inverse_RRT( oces );
	float3 SceneReferredLinearsRGBColor = mul( AP0_2_sRGB, aces ) * 0.6666;

	return SceneReferredLinearsRGBColor;
}

float3 ACESOutputTransforms1000( float3 SceneReferredLinearsRGBColor )
{
	const float3x3 sRGB_2_AP0 = mul( XYZ_2_AP0_MAT, mul( D65_2_D60_CAT, sRGB_2_XYZ_MAT ) );

	float3 aces = mul( sRGB_2_AP0, SceneReferredLinearsRGBColor * 1.5 );
	float3 oces = RRT( aces );
	float3 OutputReferredLinearAP1Color = ODT_1000nits( oces );
	return OutputReferredLinearAP1Color;
}

float3 ACESOutputTransforms2000( float3 SceneReferredLinearsRGBColor )
{
	const float3x3 sRGB_2_AP0 = mul( XYZ_2_AP0_MAT, mul( D65_2_D60_CAT, sRGB_2_XYZ_MAT ) );

	float3 aces = mul( sRGB_2_AP0, SceneReferredLinearsRGBColor * 1.5 );
	float3 oces = RRT( aces );
	float3 OutputReferredLinearAP1Color = ODT_2000nits( oces );
	return OutputReferredLinearAP1Color;
}

static const float3x3 GamutMappingIdentityMatrix = { 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 };

float3x3 OuputGamutMappingMatrix( uint OutputGamut )
{

	const float3x3 AP1_2_sRGB = mul( XYZ_2_sRGB_MAT, mul( D60_2_D65_CAT, AP1_2_XYZ_MAT ) );
	const float3x3 AP1_2_DCI_D65 = mul( XYZ_2_P3D65_MAT, mul( D60_2_D65_CAT, AP1_2_XYZ_MAT ) );
	const float3x3 AP1_2_Rec2020 = mul( XYZ_2_Rec2020_MAT, mul( D60_2_D65_CAT, AP1_2_XYZ_MAT ) );

	if( OutputGamut == 1 )
		return AP1_2_DCI_D65;
	else if( OutputGamut == 2 )
		return AP1_2_Rec2020;
	else if( OutputGamut == 3 )
		return AP1_2_AP0_MAT;
	else if( OutputGamut == 4 )
		return GamutMappingIdentityMatrix;
	else
		return AP1_2_sRGB;
}

float3x3 OuputInverseGamutMappingMatrix( uint OutputGamut )
{
	const float3x3 sRGB_2_AP1 = mul( XYZ_2_AP1_MAT, mul( D65_2_D60_CAT, sRGB_2_XYZ_MAT ) );
	const float3x3 DCI_D65_2_AP1 = mul( XYZ_2_AP1_MAT, mul( D65_2_D60_CAT, P3D65_2_XYZ_MAT ) );
	const float3x3 Rec2020_2_AP1 = mul( XYZ_2_AP1_MAT, mul( D65_2_D60_CAT, Rec2020_2_XYZ_MAT ) );

	float3x3 GamutMappingMatrix = sRGB_2_AP1;
	if( OutputGamut == 1 )
		GamutMappingMatrix = DCI_D65_2_AP1;
	else if( OutputGamut == 2 )
		GamutMappingMatrix = Rec2020_2_AP1;
	else if( OutputGamut == 3 )
		GamutMappingMatrix = AP0_2_AP1_MAT;

	return GamutMappingMatrix;
}

float3 ST2084ToScRGB(float3 Color, uint OutputDevice)
{

	const float3x3 AP1_2_sRGB = mul(XYZ_2_sRGB_MAT, AP1_2_XYZ_MAT);
	const float WhitePoint = 80.f;


	float MaxODTNits = 1000.0f;
	float MinODTNits = 0.0001f;

	if (OutputDevice == 4 || OutputDevice == 6)
	{

		MaxODTNits = 2000.0f;
		MinODTNits = 0.005f;
	}

	float3 OutColor = ST2084ToLinear(Color);

	OutColor = clamp(OutColor, MinODTNits, MaxODTNits);
	OutColor.x = Y_2_linCV(OutColor.x, MaxODTNits, MinODTNits);
	OutColor.y = Y_2_linCV(OutColor.y, MaxODTNits, MinODTNits);
	OutColor.z = Y_2_linCV(OutColor.z, MaxODTNits, MinODTNits);

	float scRGBScale = MaxODTNits / WhitePoint;
	OutColor = mul(AP1_2_sRGB, OutColor) * scRGBScale;

	return OutColor;
}

float2 PlanckianLocusChromaticity( float Temp )
{
	float u = ( 0.860117757f + 1.54118254e-4f * Temp + 1.28641212e-7f * Temp*Temp ) / ( 1.0f + 8.42420235e-4f * Temp + 7.08145163e-7f * Temp*Temp );
	float v = ( 0.317398726f + 4.22806245e-5f * Temp + 4.20481691e-8f * Temp*Temp ) / ( 1.0f - 2.89741816e-5f * Temp + 1.61456053e-7f * Temp*Temp );

	float x = 3*u / ( 2*u - 8*v + 4 );
	float y = 2*v / ( 2*u - 8*v + 4 );

	return float2(x,y);
}

float2 D_IlluminantChromaticity( float Temp )
{


	Temp *= 1.4388 / 1.438;
	float OneOverTemp = 1.0/Temp;
	float x = Temp <= 7000 ?
				0.244063 + ( 0.09911e3 + ( 2.9678e6 - 4.6070e9 * OneOverTemp ) * OneOverTemp) * OneOverTemp:
				0.237040 + ( 0.24748e3 + ( 1.9018e6 - 2.0064e9 * OneOverTemp ) * OneOverTemp ) * OneOverTemp;

	float y = -3 * x*x + 2.87 * x - 0.275;

	return float2(x,y);
}

float CorrelatedColorTemperature( float x, float y )
{
	float n = (x - 0.3320) / (0.1858 - y);
	return -449 * n*n*n + 3525 * n*n - 6823.3 * n + 5520.33;
}

float2 PlanckianIsothermal( float Temp, float Tint )
{
	float u = ( 0.860117757f + 1.54118254e-4f * Temp + 1.28641212e-7f * Temp*Temp ) / ( 1.0f + 8.42420235e-4f * Temp + 7.08145163e-7f * Temp*Temp );
	float v = ( 0.317398726f + 4.22806245e-5f * Temp + 4.20481691e-8f * Temp*Temp ) / ( 1.0f - 2.89741816e-5f * Temp + 1.61456053e-7f * Temp*Temp );

	float ud = ( -1.13758118e9f - 1.91615621e6f * Temp - 1.53177f * Temp*Temp ) / Square( 1.41213984e6f + 1189.62f * Temp + Temp*Temp );
	float vd = ( 1.97471536e9f - 705674.0f * Temp - 308.607f * Temp*Temp ) / Square( 6.19363586e6f - 179.456f * Temp + Temp*Temp );

	float2 uvd = normalize( float2( u, v ) );


	u += -uvd.y * Tint * 0.05;
	v += uvd.x * Tint * 0.05;

	float x = 3*u / ( 2*u - 8*v + 4 );
	float y = 2*v / ( 2*u - 8*v + 4 );

	return float2(x,y);
}

#endif