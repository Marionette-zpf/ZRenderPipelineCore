#ifndef Z_RENDER_PIPELINE_PLATFOEM_INCLUDE
#define Z_RENDER_PIPELINE_PLATFOEM_INCLUDE


/** Avoids flow control constructs. */
#define UNROLL [unroll]
#define UNROLL_N(N) [unroll(N)]

/** Gives preference to flow control constructs. */
#define LOOP [loop]

/** Performs branching by using control flow instructions like jmp and label. */
#define BRANCH [branch]

/** Performs branching by using the cnd instructions. */
#define FLATTEN [flatten]

/** Allows a compute shader loop termination condition to be based off of a UAV read. The loop must not contain synchronization intrinsics. */
#define ALLOW_UAV_CONDITION [allow_uav_condition]

#ifndef INVARIANT
#define INVARIANT										
#endif


float min3( float a, float b, float c )
{
	return min( a, min( b, c ) );
}

float max3( float a, float b, float c )
{
	return max( a, max( b, c ) );
}

float2 min3( float2 a, float2 b, float2 c )
{
	return float2(
		min3( a.x, b.x, c.x ),
		min3( a.y, b.y, c.y )
	);
}

float2 max3( float2 a, float2 b, float2 c )
{
	return float2(
		max3( a.x, b.x, c.x ),
		max3( a.y, b.y, c.y )
	);
}

float3 max3( float3 a, float3 b, float3 c )
{
	return float3(
		max3( a.x, b.x, c.x ),
		max3( a.y, b.y, c.y ),
		max3( a.z, b.z, c.z )
	);
}

float3 min3( float3 a, float3 b, float3 c )
{
	return float3(
		min3( a.x, b.x, c.x ),
		min3( a.y, b.y, c.y ),
		min3( a.z, b.z, c.z )
	);
}

float4 min3( float4 a, float4 b, float4 c )
{
	return float4(
		min3( a.x, b.x, c.x ),
		min3( a.y, b.y, c.y ),
		min3( a.z, b.z, c.z ),
		min3( a.w, b.w, c.w )
	);
}

float4 max3( float4 a, float4 b, float4 c )
{
	return float4(
		max3( a.x, b.x, c.x ),
		max3( a.y, b.y, c.y ),
		max3( a.z, b.z, c.z ),
		max3( a.w, b.w, c.w )
	);
}

#endif