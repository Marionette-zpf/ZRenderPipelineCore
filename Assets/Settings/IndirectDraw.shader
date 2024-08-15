Shader "Universal Render Pipeline/Custom/IndirectDraw"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags {"RenderPipeline" = "UniversalPipeline"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        
        CBUFFER_START(UnityPerMaterial);

            half4 _MainTex_ST;

        CBUFFER_END;

        struct Vertex
        {
            float3 Position;
            float3 Normal;
            float2 Texcoord;
            float4 Tangent;
        };

        struct MeshOffset
        {
            uint vertexStart;
            uint vertexCount;
            uint indexStart;
            uint indexCount;
        };


        StructuredBuffer<Vertex>   VertexBuffer;
        StructuredBuffer<uint>   IndexBuffer;
        StructuredBuffer<MeshOffset>   MeshOffsetBuffer;

        TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);

        ENDHLSL

        Pass
        {
            Tags {"LightMode" = "UniversalForward"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            struct Attributes
            {
                uint vertexID : SV_VertexID; // 0 - 63
                uint ClusterInstance : SV_InstanceID; // 0 - (instnaceCount - 1)
            };

            struct Varyings
            { 
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 positionCS : SV_POSITION;
            };

            Varyings vert (Attributes input)
            {
                Varyings output;

                MeshOffset meshOffset = MeshOffsetBuffer[input.ClusterInstance];
                //meshOffset = MeshOffsetBuffer[36];
                uint index = IndexBuffer[input.vertexID + input.ClusterInstance * 63 + meshOffset.indexStart]; // 2368 515
                index = IndexBuffer[input.vertexID + input.ClusterInstance * 63 + input.ClusterInstance == 37 ? 2368 : 0.0]; // 2368 515

                //Vertex vertexOS = VertexBuffer[index + meshOffset.vertexStart];
                Vertex vertexOS = VertexBuffer[index + input.ClusterInstance == 37 ? 515 : 0];



                output.positionCS = TransformWorldToHClip(vertexOS.Position);
                output.uv = vertexOS.Texcoord;
                output.normalWS = TransformObjectToWorldNormal(vertexOS.Normal);
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            { 
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                return col;
            }
            ENDHLSL
        }
    }
}