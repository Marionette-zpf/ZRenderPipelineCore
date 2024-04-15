#ifndef Z_RENDER_PIPELINE_HAIR_BSDF_INCLUDE
#define Z_RENDER_PIPELINE_HAIR_BSDF_INCLUDE

#include "Assets/ZRenderPipeline/Shaders/ShaderLibrary/ShadingCommon.hlsl"

///////////////////////////////////////////////////////////////////////////////////////////////////
// Transmittance functions

struct FHairTransmittanceData
{
	bool bUseLegacyAbsorption;
	bool bUseSeparableR;
	bool bUseBacklit;

	float  OpaqueVisibility;
	float3 LocalScattering;
	float3 GlobalScattering;

	uint ScatteringComponent;
};

FHairTransmittanceData InitHairTransmittanceData(bool bMultipleScatterEnable = true)
{
	FHairTransmittanceData o;
	o.bUseLegacyAbsorption = true;
	o.bUseSeparableR = true;
	o.bUseBacklit = false;

	o.OpaqueVisibility = 1;
	o.LocalScattering = 0;
	o.GlobalScattering = 1;
	o.ScatteringComponent = HAIR_COMPONENT_R | HAIR_COMPONENT_TT | HAIR_COMPONENT_TRT | (bMultipleScatterEnable ? HAIR_COMPONENT_MULTISCATTER : 0);

	return o;
}

#endif