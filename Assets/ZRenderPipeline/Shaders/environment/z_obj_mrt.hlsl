#ifndef Z_OBJ_MRT
#define Z_OBJ_MRT

    #define FRAGMENT_MRT(frag,v2f,i) void frag(v2f i, out float4 sv_target0 : SV_Target0, out float4 sv_target1 : SV_Target1, out float4 sv_target2 : SV_Target2, out float4 sv_target3 : SV_Target3, out float4 sv_target4 : SV_Target4) 

    #define SET_SCENE_COLOR(data) sv_target0 = data

    #define SET_GBUFFER_A(data) sv_target1 = data
    #define SET_GBUFFER_B(data) sv_target2 = data
    #define SET_GBUFFER_C(data) sv_target3 = data
    #define SET_GBUFFER_D(data) sv_target4 = data

    #define INITIALIZE_GBUFFERS(data) sv_target0 = data; sv_target1 = data; sv_target2 = data; sv_target3 = data; sv_target4 = data
    
#endif 
