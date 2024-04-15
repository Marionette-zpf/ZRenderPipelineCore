#ifndef Z_RENDER_PIPELINE_BASE_PASS_VERTEX_COMMON_INCLUDE
#define Z_RENDER_PIPELINE_BASE_PASS_VERTEX_COMMON_INCLUDE


struct FBasePassVSToPS
{
	FVertexFactoryInterpolantsVSToPS FactoryInterpolants;
	//FBasePassInterpolantsVSToPS BasePassInterpolants;
	float4 Position : SV_POSITION;
};

//#if USING_TESSELLATION	
//	struct FBasePassVSToDS
//	{
//		FVertexFactoryInterpolantsVSToDS FactoryInterpolants;
//		FBasePassInterpolantsVSToDS BasePassInterpolants;
//		float4 Position : VS_To_DS_Position;
//		OPTIONAL_VertexID_VS_To_DS
//	};
	
//	#define FBasePassVSOutput FBasePassVSToDS
//	#define VertexFactoryGetInterpolants VertexFactoryGetInterpolantsVSToDS
//	#define FPassSpecificVSToDS FBasePassVSToDS
//	#define FPassSpecificVSToPS FBasePassVSToPS
//#else
	#define FBasePassVSOutput FBasePassVSToPS
	#define VertexFactoryGetInterpolants VertexFactoryGetInterpolantsVSToPS
//#endif



#endif