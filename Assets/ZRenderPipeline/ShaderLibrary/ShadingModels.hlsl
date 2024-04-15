#ifndef Z_RENDER_PIPELINE_SHADING_MODELS_INCLUDE
#define Z_RENDER_PIPELINE_SHADING_MODELS_INCLUDE

#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/HairBsdf.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/BRDF.hlsl"
#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/RectLight.hlsl"


struct FAreaLight
{
	float		SphereSinAlpha;
	float		SphereSinAlphaSoft;
	float		LineCosSubtended;

	float3		FalloffColor;

	FRect		Rect;
	FRectTexture Texture;
	bool		bIsRect;
};

struct FDirectLighting
{
	float3	Diffuse;
	float3	Specular;
	float3	Transmission;
};

struct FShadowTerms
{
	float	SurfaceShadow;
	float	TransmissionShadow;
	float	TransmissionThickness;
	FHairTransmittanceData HairTransmittance;
};

float New_a2( float a2, float SinAlpha, float VoH )
{
	return a2 + 0.25 * SinAlpha * (3.0 * sqrtFast(a2) + SinAlpha) / ( VoH + 0.001 );
	//return a2 + 0.25 * SinAlpha * ( saturate(12 * a2 + 0.125) + SinAlpha ) / ( VoH + 0.001 );
	//return a2 + 0.25 * SinAlpha * ( a2 * 2 + 1 + SinAlpha ) / ( VoH + 0.001 );
}

float EnergyNormalization( inout float a2, float VoH, FAreaLight AreaLight )
{
	if( AreaLight.SphereSinAlphaSoft > 0 )
	{
		// Modify Roughness
		a2 = saturate( a2 + Pow2( AreaLight.SphereSinAlphaSoft ) / ( VoH * 3.6 + 0.4 ) );
	}

	float Sphere_a2 = a2;
	float Energy = 1;
	if( AreaLight.SphereSinAlpha > 0 )
	{
		Sphere_a2 = New_a2( a2, AreaLight.SphereSinAlpha, VoH );
		Energy = a2 / Sphere_a2;
	}

	if( AreaLight.LineCosSubtended < 1 )
	{
#if 1
		float LineCosTwoAlpha = AreaLight.LineCosSubtended;
		float LineTanAlpha = sqrt( ( 1.0001 - LineCosTwoAlpha ) / ( 1 + LineCosTwoAlpha ) );
		float Line_a2 = New_a2( Sphere_a2, LineTanAlpha, VoH );
		Energy *= sqrt( Sphere_a2 / Line_a2 );
#else
		float LineCosTwoAlpha = AreaLight.LineCosSubtended;
		float LineSinAlpha = sqrt( 0.5 - 0.5 * LineCosTwoAlpha );
		float Line_a2 = New_a2( Sphere_a2, LineSinAlpha, VoH );
		Energy *= Sphere_a2 / Line_a2;
#endif
	}

	return Energy;
}

float3 SpecularGGX(float Roughness, float Anisotropy, float3 SpecularColor, BxDFContext Context, float NoL, FAreaLight AreaLight)
{
	float Alpha = Roughness * Roughness;
	float a2 = Alpha * Alpha;

	FAreaLight Punctual = AreaLight;
	Punctual.SphereSinAlpha = 0;
	Punctual.SphereSinAlphaSoft = 0;
	Punctual.LineCosSubtended = 1;
	Punctual.Rect = (FRect)0;
	Punctual.bIsRect = false;

	float Energy = EnergyNormalization(a2, Context.VoH, Punctual);

	float ax = 0;
	float ay = 0;
	GetAnisotropicRoughness(Alpha, Anisotropy, ax, ay);

	// Generalized microfacet specular
	float3 D = D_GGXaniso(ax, ay, Context.NoH, Context.XoH, Context.YoH) * Energy;
	float3 Vis = Vis_SmithJointAniso(ax, ay, Context.NoV, NoL, Context.XoV, Context.XoL, Context.YoV, Context.YoL);
	float3 F = F_Schlick( SpecularColor, Context.VoH );

	return (D * Vis) * F;
}

float3 SpecularGGX( float Roughness, float3 SpecularColor, BxDFContext Context, float NoL, FAreaLight AreaLight )
{
	float a2 = Pow4( Roughness );
	float Energy = EnergyNormalization( a2, Context.VoH, AreaLight );
	
	// Generalized microfacet specular
	float D = D_GGX( a2, Context.NoH ) * Energy;
	float Vis = Vis_SmithJointApprox( a2, Context.NoV, NoL );
	float3 F = F_Schlick( SpecularColor, Context.VoH );

	return (D * Vis) * F;
}

FDirectLighting DefaultLitBxDF( FGBufferData GBuffer, half3 N, half3 V, half3 L, float Falloff, float NoL, FAreaLight AreaLight, FShadowTerms Shadow )
{
	BxDFContext Context;

#if SUPPORTS_ANISOTROPIC_MATERIALS
	bool bHasAnisotropy = HasAnisotropy(GBuffer.SelectiveOutputMask);
#else
	bool bHasAnisotropy = false;
#endif

	BRANCH
	if (bHasAnisotropy)
	{
		half3 X = GBuffer.WorldTangent;
		half3 Y = normalize(cross(N, X));
		Init(Context, N, X, Y, V, L);
	}
	else
	{
		Init(Context, N, V, L);
		SphereMaxNoH(Context, AreaLight.SphereSinAlpha, true);
	}

	Context.NoV = saturate(abs( Context.NoV ) + 1e-5);

	FDirectLighting Lighting;
	Lighting.Diffuse  = AreaLight.FalloffColor * (Falloff * NoL) * Diffuse_Lambert( GBuffer.DiffuseColor );

	BRANCH
	if (bHasAnisotropy)
	{
		//Lighting.Specular = GBuffer.WorldTangent * .5f + .5f;
		Lighting.Specular = AreaLight.FalloffColor * (Falloff * NoL) * SpecularGGX(GBuffer.Roughness, GBuffer.Anisotropy, GBuffer.SpecularColor, Context, NoL, AreaLight);
	}
	else
	{
		//if( AreaLight.bIsRect )
		//{
		//	Lighting.Specular = RectGGXApproxLTC(GBuffer.Roughness, GBuffer.SpecularColor, N, V, AreaLight.Rect, AreaLight.Texture);
		//}
		//else
		{
			Lighting.Specular = AreaLight.FalloffColor * (Falloff * NoL) * SpecularGGX(GBuffer.Roughness, GBuffer.SpecularColor, Context, NoL, AreaLight);
		}
	}

	Lighting.Transmission = 0;
	return Lighting;
}


FDirectLighting IntegrateBxDF( FGBufferData GBuffer, half3 N, half3 V, half3 L, float Falloff, float NoL, FAreaLight AreaLight, FShadowTerms Shadow )
{
	switch( GBuffer.ShadingModelID )
	{
		case SHADINGMODELID_DEFAULT_LIT:
		case SHADINGMODELID_SINGLELAYERWATER:
		case SHADINGMODELID_THIN_TRANSLUCENT:
			return DefaultLitBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		//case SHADINGMODELID_SUBSURFACE:
		//	return SubsurfaceBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		//case SHADINGMODELID_PREINTEGRATED_SKIN:
		//	return PreintegratedSkinBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		//case SHADINGMODELID_CLEAR_COAT:
		//	return ClearCoatBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		//case SHADINGMODELID_SUBSURFACE_PROFILE:
		//	return SubsurfaceProfileBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		//case SHADINGMODELID_TWOSIDED_FOLIAGE:
		//	return TwoSidedBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		//case SHADINGMODELID_HAIR:
		//	return HairBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		//case SHADINGMODELID_CLOTH:
		//	return ClothBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		//case SHADINGMODELID_EYE:
		//	return EyeBxDF( GBuffer, N, V, L, Falloff, NoL, AreaLight, Shadow );
		default:
			return (FDirectLighting)0;
	}
}

//FDirectLighting EvaluateBxDF( FGBufferData GBuffer, half3 N, half3 V, half3 L, float NoL, FShadowTerms Shadow )
//{
//	FAreaLight AreaLight;
//	AreaLight.SphereSinAlpha = 0;
//	AreaLight.SphereSinAlphaSoft = 0;
//	AreaLight.LineCosSubtended = 1;
//	AreaLight.FalloffColor = 1;
//	AreaLight.Rect = (FRect)0;
//	AreaLight.bIsRect = false;
//    AreaLight.Texture = InitRectTexture(LTCAmpTexture); // Dummy

//	return IntegrateBxDF( GBuffer, N, V, L, 1, NoL, AreaLight, Shadow );
//}

#endif