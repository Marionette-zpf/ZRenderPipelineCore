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
            uint PrimCount;
            uint PrimOffset;
        };
        struct Meshlet
        {
            uint VertCount;
            uint VertOffset;
            uint PrimCount;
            uint PrimOffset;
        };

        struct Triangle
        {
            uint i0;
            uint i1;
            uint i2;
        };


        StructuredBuffer<Vertex>       VertexBuffer;
        StructuredBuffer<uint3>        CullResultPrimitiveBuffer;
        StructuredBuffer<Cluster>      CullResultClusterBuffer;
        StructuredBuffer<MeshOffset>   MeshOffsetBuffer;

        StructuredBuffer<Meshlet>   _MeshletBuffer;
        StructuredBuffer<float3>    _VerticesBuffer;
        StructuredBuffer<uint3>     _IndicesBuffer;
        

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
                uint vertexID : SV_VertexID; // 0 - 127
                uint ClusterPrimitiveInstanceID : SV_InstanceID; // 0 - (ClusterCount - 1)
            };

            struct Varyings
            { 
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 positionCS : SV_POSITION;
            };

            // Vertex GetVertexAttribute(uint vertexID, uint ClusterInstanceID)
            // {   
            //     MeshOffset meshOffset = MeshOffsetBuffer[ClusterInstanceID];
            //     uint index = IndexBuffer[vertexID + (ClusterInstanceID - meshOffset.meshLength) * 63 + meshOffset.indexStart];

            //     Vertex vertexData = VertexBuffer[index + meshOffset.vertexStart];
            //     return vertexData;
            // }

            Vertex GetClusterVertexAttribute(uint vertexID, uint ClusterPrimitiveInstanceID)
            {   
                MeshOffset meshOffset = MeshOffsetBuffer[ClusterPrimitiveInstanceID];
                Cluster cluster = CullResultClusterBuffer[ClusterPrimitiveInstanceID + (meshOffset.clusterStart - meshOffset.meshLength)];

                uint inputVertexID = vertexID + cluster.PrimOffset;
                uint index = CullResultPrimitiveBuffer[((inputVertexID / 3) + inputVertexID % 3)];

                Vertex vertexData = VertexBuffer[index];
                vertexData = VertexBuffer[vertexID];
                return vertexData;
            }

            Varyings vert (Attributes input)
            {
                Varyings output;

                Vertex vertexOS = GetClusterVertexAttribute(input.vertexID, input.ClusterPrimitiveInstanceID);
                // vertexOS.Position = float3(1.0, 0.0, 0.0);
                // vertexOS.Normal = float3(1.0, 0.0, 0.0);
                // vertexOS.Texcoord = float2(1.0, 0.0);
                // vertexOS.Tangent = float4(1.0, 0.0, 0.0, 0.0);
                Meshlet meshlet = _MeshletBuffer[input.ClusterInstanceID];
                uint triangleIndex = floor(input.vertexID / 3);
                uint vertexIndex = input.vertexID % 3;

                float3 PositionOS = 0;
                if (triangleIndex >= meshlet.PrimCount)
                {
                    PositionOS /= 0;
                }
                else
                {
                    uint3 tri = _IndicesBuffer[meshlet.PrimOffset + triangleIndex];
                    
                    PositionOS = _VerticesBuffer[tri[vertexIndex]];
                }


                output.positionCS = TransformWorldToHClip(PositionOS);
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