#ifndef Z_RENDER_PIPELINE_LOCAL_VERTEX_FACTORY_COMMON_INCLUDE
#define Z_RENDER_PIPELINE_LOCAL_VERTEX_FACTORY_COMMON_INCLUDE

// Copyright Epic Games, Inc. All Rights Reserved.

/*=============================================================================
	LocalVertexFactoryCommon.usf: Local vertex factory common functionality
=============================================================================*/

#define TANGENTTOWORLD_INTERPOLATOR_BLOCK	float4 TangentToWorld0 : TEXCOORD10; float4	TangentToWorld2	: TEXCOORD11; 

struct FVertexFactoryInterpolantsVSToPS
{
	//TANGENTTOWORLD_INTERPOLATOR_BLOCK

	float4  TangentToWorld0 : TEXCOORD10;
	float4	TangentToWorld2	: TEXCOORD11; 

#if INTERPOLATE_VERTEX_COLOR
	half4	Color : COLOR0;
#endif

#if USE_INSTANCING
	// x = per-instance random, y = per-instance fade out amount, z = hide/show flag, w dither fade cutoff
	float4  PerInstanceParams : COLOR1;
#endif

#if NUM_TEX_COORD_INTERPOLATORS
	float4	TexCoords[(NUM_TEX_COORD_INTERPOLATORS+1)/2]	: TEXCOORD0;
//#elif USE_PARTICLE_SUBUVS
//	float4	TexCoords[1] : TEXCOORD0;
#endif

//#if NEEDS_LIGHTMAP_COORDINATE
//	float4	LightMapCoordinate : TEXCOORD4;
//#endif

//#if INSTANCED_STEREO
//	nointerpolation uint EyeIndex : PACKED_EYE_INDEX;
//#endif
//#if VF_USE_PRIMITIVE_SCENE_DATA
//	nointerpolation uint PrimitiveId : PRIMITIVE_ID;
//	#if NEEDS_LIGHTMAP_COORDINATE
//		nointerpolation uint LightmapDataIndex : LIGHTMAP_ID;
//	#endif
//#endif
//#if HAIR_STRAND_MESH_FACTORY || HAIR_CARD_MESH_FACTORY
//	nointerpolation uint HairPrimitiveId	: HAIR_PRIMITIVE_ID; // Control point ID
//	float2 HairPrimitiveUV					: HAIR_PRIMITIVE_UV; // U: parameteric distance between the two surrounding control points. V: parametric distance along the width.
//#endif
};


//#if NUM_TEX_COORD_INTERPOLATORS || USE_PARTICLE_SUBUVS
float2 GetUV(FVertexFactoryInterpolantsVSToPS Interpolants, int UVIndex)
{
	float4 UVVector = Interpolants.TexCoords[UVIndex / 2];
	return UVIndex % 2 ? UVVector.zw : UVVector.xy;
}

void SetUV(inout FVertexFactoryInterpolantsVSToPS Interpolants, int UVIndex, float2 InValue)
{
	FLATTEN
	if (UVIndex % 2)
	{
		Interpolants.TexCoords[UVIndex / 2].zw = InValue;
	}
	else
	{
		Interpolants.TexCoords[UVIndex / 2].xy = InValue;
	}
}
//#endif

void SetTangents(inout FVertexFactoryInterpolantsVSToPS Interpolants, float3 InTangentToWorld0, float3 InTangentToWorld2, float InTangentToWorldSign)
{
	Interpolants.TangentToWorld0 = float4(InTangentToWorld0,InTangentToWorldSign);
	Interpolants.TangentToWorld2 = float4(InTangentToWorld2,0.0);
//#if USE_WORLDVERTEXNORMAL_CENTER_INTERPOLATION
//	Interpolants.TangentToWorld2_Center = Interpolants.TangentToWorld2;
//#endif
}


void SetPrimitiveId(inout FVertexFactoryInterpolantsVSToPS Interpolants, uint PrimitiveId)
{
#if VF_USE_PRIMITIVE_SCENE_DATA
	Interpolants.PrimitiveId = PrimitiveId;
#endif
}


#endif