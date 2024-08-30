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
            uint clusterStart;
            uint clusterCount;
            uint meshLength;
        };

        struct Cluster
        {
            uint VertCount;
            uint VertOffset;
            uint PrimCount;
            uint PrimOffset;
        };

        StructuredBuffer<Vertex>       VertexBuffer;
        StructuredBuffer<uint>         IndexBuffer;
        StructuredBuffer<MeshOffset>   MeshOffsetBuffer;
        
        // StructuredBuffer<Cluster>      CullResultClusterBuffer;
        // StructuredBuffer<uint3>        CullResultPrimitiveBuffer;
        
        StructuredBuffer<Cluster>      ClusterBuffer;
        StructuredBuffer<uint3>        ClusterPrimitiveBuffer;

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
                uint vertexID : SV_VertexID; // 0 - 511
                uint ClusterPrimitiveInstanceID : SV_InstanceID; // 0 - (ClusterCount - 1)
            };

            struct Varyings
            { 
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 positionCS : SV_POSITION;
            };

            Vertex GetClusterVertexAttribute(uint vertexID, uint ClusterPrimitiveInstanceID)
            {   
                MeshOffset meshOffset = MeshOffsetBuffer[ClusterPrimitiveInstanceID];
                Cluster cluster = ClusterBuffer[ClusterPrimitiveInstanceID + (meshOffset.clusterStart - meshOffset.meshLength)];

                uint index = ClusterPrimitiveBuffer[vertexID / 3 + cluster.PrimOffset][vertexID % 3];

                Vertex vertexData = VertexBuffer[index];
                return vertexData;
            }

            Varyings vert (Attributes input)
            {
                Varyings output;

                //Vertex vertexOS = GetClusterVertexAttribute(input.vertexID, input.ClusterPrimitiveInstanceID);

                MeshOffset meshOffset = MeshOffsetBuffer[input.ClusterPrimitiveInstanceID];
                Cluster cluster = ClusterBuffer[input.ClusterPrimitiveInstanceID + (meshOffset.clusterStart - meshOffset.meshLength)];


                Vertex vertexData = (Vertex)0;

                if (input.vertexID / 3 >= cluster.PrimCount)
                {
                    return output;
                }
                else
                {
                    uint index = ClusterPrimitiveBuffer[input.vertexID / 3 + cluster.PrimOffset][input.vertexID % 3];

                    vertexData = VertexBuffer[index];
                }

                output.positionCS = TransformWorldToHClip(vertexData.Position);
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