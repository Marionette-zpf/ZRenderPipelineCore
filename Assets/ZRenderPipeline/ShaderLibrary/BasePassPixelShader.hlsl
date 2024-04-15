#ifndef Z_RENDER_PIPELINE_BASE_PASS_PIXEL_SHADER_INCLUDE
#define Z_RENDER_PIPELINE_BASE_PASS_PIXEL_SHADER_INCLUDE


// is called in MainPS() from PixelShaderOutputCommon.usf
void FPixelShaderInOut_MainPS(
	FVertexFactoryInterpolantsVSToPS Interpolants,
	FBasePassInterpolantsVSToPS BasePassInterpolants,
	in FPixelShaderIn In,
	inout FPixelShaderOut Out)
{
	//#if INSTANCED_STEREO
	//	const uint EyeIndex = Interpolants.EyeIndex;
	//	ResolvedView = ResolveView(EyeIndex);
	//#else
	//	const uint EyeIndex = 0;
	//	ResolvedView = ResolveView();
	//#endif

	// Velocity
	float4 OutVelocity = 0;
	
	// CustomData
	float4 OutGBufferD = 0;
	
	// PreShadowFactor
	float4 OutGBufferE = 0;

	FMaterialPixelParameters MaterialParameters = GetMaterialPixelParameters(Interpolants, In.SvPosition);
	FPixelMaterialInputs PixelMaterialInputs;

}

#endif