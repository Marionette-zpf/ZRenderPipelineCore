#ifndef Z_OBJ_PRE_PASS
#define Z_OBJ_PRE_PASS

    struct a2v_pre_depth 
    {
        float4 positionOS : POSITION;
    };

    struct v2f_pre_depth 
    {
        float4 positionCS : SV_POSITION;
    };

    v2f_pre_depth vert_pre_depth (a2v_pre_depth v) 
    {
        v2f_pre_depth o;
            o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
        return o;
    }

    half4 frag_pre_depth (v2f_pre_depth i) : SV_Target 
    {
        return 0;
    }

#endif 
