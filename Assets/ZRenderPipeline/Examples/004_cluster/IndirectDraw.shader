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

        //struct Vertex
        //{
        //    float3 Position;
        //    float3 Normal;
        //};

        //StructuredBuffer<float4>    VertexBuffer;
        //StructuredBuffer<Vertex>   VertexBuffer;


        uniform float4 VertexBuffer[24];


        TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);

        ENDHLSL

        Pass
        {
            Tags {"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                //float2 texcoord : TEXCOORD0;
                uint vertexID : SV_VertexID;
                uint inst : SV_InstanceID;
            };

            struct Varyings
            { 
                //float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float3 color : TEXCOORD1;
            };

            Varyings vert (Attributes input)
            {
                Varyings output;

                float3 positionOS = VertexBuffer[input.vertexID].xyz;

                //if (input.vertexID < 6)
                //{
                    
                //}

                

                //if (input.vertexID == 0)
                //{
                //    positionOS = float3(-10, 0, 0);
                //}

                //if (input.vertexID == 1)
                //{
                //    positionOS = float3( 10, 0, 0);
                //}

                //if (input.vertexID == 2)
                //{
                //    positionOS = float3( 10, 10, 0);
                //}

                //if (input.vertexID == 3)
                //{
                //    positionOS = float3(-10, 0, 0);
                //}

                //if (input.vertexID == 4)
                //{
                //    positionOS = float3( 10, 0, 0);
                //}

                //if (input.vertexID == 5)
                //{
                //    positionOS = float3( -10, 10, 0);
                //}
                output.color = abs( VertexBuffer[2].xyz) * 10;

                output.positionCS = TransformObjectToHClip(positionOS);
                //output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                return float4(input.color, 1);
            }
            ENDHLSL
        }
    }
}