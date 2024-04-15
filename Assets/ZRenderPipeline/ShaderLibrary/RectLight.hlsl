#ifndef Z_RENDER_PIPELINE_RECT_LIGHT_INCLUDE
#define Z_RENDER_PIPELINE_RECT_LIGHT_INCLUDE

//#ifndef USE_SOURCE_TEXTURE
//#define USE_SOURCE_TEXTURE 1
//#endif

//#ifndef USE_SOURCE_TEXTURE_ARRAY 
//#define USE_SOURCE_TEXTURE_ARRAY 0
//#endif


struct FRect
{
	float3		Origin;
	float3x3	Axis;
	float2		Extent;
	float2		FullExtent;
	float2		Offset;
};


struct FRectTexture
{
#if COMPILER_HLSLCC && !COMPILER_METAL
	uint Dummy;
#else
#if USE_SOURCE_TEXTURE_ARRAY
	Texture2D SourceTexture0;
	Texture2D SourceTexture1;
	Texture2D SourceTexture2;
	Texture2D SourceTexture3;
	Texture2D SourceTexture4;
	Texture2D SourceTexture5;
	Texture2D SourceTexture6;
	Texture2D SourceTexture7;
	uint SourceTextureIndex; 
#elif USE_SOURCE_TEXTURE
	Texture2D SourceTexture;
#else
	uint Dummy;
#endif
#endif	// COMPILER_HLSLCC && !COMPILER_METAL
};


FRectTexture InitRectTexture(Texture2D SourceTexture)
{
	FRectTexture Output;
#if COMPILER_HLSLCC && !COMPILER_METAL
	uint Dummy;
#else
#if USE_SOURCE_TEXTURE_ARRAY
	Output.SourceTexture0 = SourceTexture;
	Output.SourceTexture1 = SourceTexture;
	Output.SourceTexture2 = SourceTexture;
	Output.SourceTexture3 = SourceTexture;
	Output.SourceTexture4 = SourceTexture;
	Output.SourceTexture5 = SourceTexture;
	Output.SourceTexture6 = SourceTexture;
	Output.SourceTexture7 = SourceTexture;
	Output.SourceTextureIndex   = 99;
#elif USE_SOURCE_TEXTURE
	Output.SourceTexture = SourceTexture;
#else
	Output.Dummy = 0;
#endif
#endif	// COMPILER_HLSLCC && !COMPILER_METAL
	return Output;
}


FRect GetRect(
	float3 ToLight, 
	float3 LightDataDirection, 
	float3 LightDataTangent, 
	float LightDataSourceRadius, 
	float LightDataSourceLength, 
	float LightDataRectLightBarnCosAngle, 
	float LightDataRectLightBarnLength,
	bool bComputeVisibleRect)
{
	// Is blocked by barn doors
	FRect Rect;
	Rect.Origin = ToLight;
	Rect.Axis[1] = LightDataTangent;
	Rect.Axis[2] = LightDataDirection;
	Rect.Axis[0] = cross( Rect.Axis[1], Rect.Axis[2] );
	Rect.Extent = float2(LightDataSourceRadius, LightDataSourceLength);
	Rect.FullExtent = Rect.Extent;
	Rect.Offset = 0;

	// Compute the visible rectangle from the current shading point. 
	// The new rectangle will have reduced width/height, and a shifted origin
	//
	// Common setup for occlusion computation
	// Notes: Barn angle & length are identical for all sides
	//					D_B
	//					<-->
	//							D_S
	//						<--------------->     O         +X
	//					   -------------.--------------->------       ^
	//					  /        .          |                \      |
	//					 /   .                |					\     |  BarnDepth
	//				   ./                     |					 \    v
	//		     .      C                     v +Z
	//		.  
	// .
	// S
	//
	// Only compute the occluded rect if the barn door has an angle less 
	// than 88 degrees
	if (bComputeVisibleRect && LightDataRectLightBarnCosAngle > 0.035f)
	{
		const float3 LightdPdv = -Rect.Axis[1];
		const float3 LightdPdu = -Rect.Axis[0];
		const float2 LightExtent = float2(LightDataSourceRadius, LightDataSourceLength);
		const float BarnLength = LightDataRectLightBarnLength;
	
		// Project shading point S into light space
		float3 S_Light = mul(Rect.Axis, ToLight);

		// Compute barn door projection (D_B). Clamp the projection to the shading point if it is closer 
		// to the light than the actual barn door
		// Theta is the angle between the Z axis and the barn door
		const float CosTheta = LightDataRectLightBarnCosAngle;
		const float SinTheta = sqrt(1 - CosTheta * CosTheta);
		const float BarnDepth = min(S_Light.z, CosTheta * BarnLength);
		const float S_ratio = BarnDepth / (CosTheta * BarnLength);
		const float D_B = SinTheta * BarnLength * S_ratio;
		
		// Clamp shading point onto the closest edge, if it is inside the rect light
		const float2 SignS = sign(S_Light.xy);
		S_Light.xy = SignS * max(abs(S_Light.xy), LightExtent + D_B.xx);
		
		// Compute the closest rect lignt corner, offset by the barn door size
		const float3 C = float3(SignS * (LightExtent + D_B.xx), BarnDepth);
			
		// Compute projected distance (D_S) of barn door onto the rect light
		// Eta is the angle between the Z axis and the direction vector (S-C)
		const float3 SProj = S_Light - C;
		const float CosEta = max(SProj.z, 0.001f);
		const float2 SinEta = abs(SProj.xy);
		const float2 TanEta = abs(SProj.xy) / CosEta;
		const float2 D_S = BarnDepth * TanEta;

		// Equivalent to (e.g., X axis):
		//  if (SignS.x < 0) MinMaxX.x += D_S - D_B;
		//  if (SignS.x > 0) MinMaxX.y -= D_S - D_B;
		const float2 MinXY = clamp(-LightExtent + (D_S - D_B.xx) * max(0, -SignS), -LightExtent, LightExtent);
		const float2 MaxXY = clamp( LightExtent - (D_S - D_B.xx) * max(0,  SignS), -LightExtent, LightExtent);
		const float2 RectOffset = 0.5f * (MinXY + MaxXY);

		Rect.Extent = 0.5f * (MaxXY - MinXY);
		Rect.Origin = Rect.Origin + LightdPdu * RectOffset.x + LightdPdv * RectOffset.y;
		Rect.Offset = -RectOffset;
		Rect.FullExtent = LightExtent;
	}

	return Rect;
}

#endif