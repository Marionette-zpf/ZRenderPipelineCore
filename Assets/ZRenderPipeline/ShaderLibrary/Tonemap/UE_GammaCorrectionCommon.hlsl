#ifndef UE_GAMMA_CORECTION_COMMON_INCLUDE
#define UE_GAMMA_CORECTION_COMMON_INCLUDE

float3  LinearTo709Branchless( float3  lin)
{
	lin = max(6.10352e-5, lin);
	return min(lin * 4.5, pow(max(lin, 0.018), 0.45) * 1.099 - 0.099);
}

float3  LinearToSrgbBranchless( float3  lin)
{
	lin = max(6.10352e-5, lin);
	return min(lin * 12.92, pow(max(lin, 0.00313067), 1.0/2.4) * 1.055 - 0.055);
}

float  LinearToSrgbBranchingChannel( float  lin)
{
	if(lin < 0.00313067) return lin * 12.92;
	return pow(lin, (1.0/2.4)) * 1.055 - 0.055;
}

float3  LinearToSrgbBranching( float3  lin)
{
	return  float3 (
		LinearToSrgbBranchingChannel(lin.r),
		LinearToSrgbBranchingChannel(lin.g),
		LinearToSrgbBranchingChannel(lin.b));
}

float3  LinearToSrgb( float3  lin)
{
	return LinearToSrgbBranching(lin);
}

float3  sRGBToLinear(  float3  Color )
{
	Color = max(6.10352e-5, Color);
	return Color > 0.04045 ? pow( Color * (1.0 / 1.055) + 0.0521327, 2.4 ) : Color * (1.0 / 12.92);
}

float3  ApplyGammaCorrection( float3  LinearColor,  float  GammaCurveRatio)
{
	float3  CorrectedColor = pow(LinearColor, GammaCurveRatio);
			CorrectedColor = LinearToSrgb(CorrectedColor);

	return CorrectedColor;
}

float3 LogToLin( float3 LogColor )
{
	const float LinearRange  = 14;
	const float LinearGrey   = 0.18;
	const float ExposureGrey = 444;

	float3 LinearColor = exp2( ( LogColor - ExposureGrey / 1023.0 ) * LinearRange ) * LinearGrey;

	return LinearColor;
}

float3 LinToLog( float3 LinearColor )
{
	const float LinearRange  = 14;
	const float LinearGrey   = 0.18;
	const float ExposureGrey = 444;

	float3 LogColor = log2(LinearColor) / LinearRange - log2(LinearGrey) / LinearRange + ExposureGrey / 1023.0;
		   LogColor = saturate( LogColor );

	return LogColor;
}

float aces100nitFitInverseFloat(float x)
{
	x = max(0.f, min(0.99f, x));

	float c = ( -0.632456 * sqrt( -0.21510484096 *x*x + 0.267146462932 * x + 0.00027735750507 ) - 0.146704 * x + 0.0083284 ) / ( x - 1.01654 );


	return max(0.f, min(65504.f, c));
}

float3 aces100nitFitInverse(float3 FilmColor)
{
	float3 inverse;
	inverse.r = aces100nitFitInverseFloat(FilmColor.r);
	inverse.g = aces100nitFitInverseFloat(FilmColor.g);
	inverse.b = aces100nitFitInverseFloat(FilmColor.b);
	return inverse;
}

float3 ST2084ToLinear(float3 pq)
{
	const float m1 = 0.1593017578125;
	const float m2 = 78.84375;
	const float c1 = 0.8359375;
	const float c2 = 18.8515625;
	const float c3 = 18.6875;
	const float C = 10000.;

	float3 Np = pow( abs( pq), 1./m2 );
	float3 L = Np - c1;
	L = max(0., L);
	L = L / (c2 - c3 * Np);
	L = pow( abs(L), 1./m1 );
	float3 P = L * C;

	return P;
}

float3 LinearToST2084(float3 lin)
{
	const float m1 = 0.1593017578125;
	const float m2 = 78.84375;
	const float c1 = 0.8359375;
	const float c2 = 18.8515625;
	const float c3 = 18.6875;
	const float C = 10000.;

	float3 L = lin/C;
	float3 Lm = pow(abs(L), m1);
	float3 N1 = ( c1 + c2 * Lm );
	float3 N2 = ( 1.0 + c3 * Lm );
	float3 N = N1 * rcp(N2);
	float3 P = pow( N, m2 );

	return P;
}



#endif