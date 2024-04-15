#ifndef Z_RENDER_PIPELINE_BLIT_COMMON
#define Z_RENDER_PIPELINE_BLIT_COMMON

    struct a2v 
    {
        float4 positionOS : POSITION;
        float2 uv         : TEXCOORD0;
    };

    struct v2f 
    {
        float4 positionCS : SV_POSITION;
        float2 uv         : TEXCOORD0;
    };

    v2f vert_blit(a2v v) 
    {
        v2f o;
            o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
            o.uv         = v.uv;
        return o;
    }

#endif