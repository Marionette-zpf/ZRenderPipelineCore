using System;
using System.Runtime.InteropServices;
using UnityEditor;

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    [InitializeOnLoad]
    public class IndirectDraw : ZScriptableRendererPass
    {
        public bool Clear;
        public bool CreateBuffer;
        public bool SetBuffer;
        public bool DebugBuffer;
        public Material mat;
        public ComputeShader ClusterCullCS;

        public uint vertexBufferLength = 0;
        public uint indexBufferLength = 0;
        public uint clusterBufferLength = 0;
        public uint DrawLength = 0;

        //ComputeBuffer
        public ComputeBuffer VertexBuffer;
        public ComputeBuffer IndexBuffer;
        public ComputeBuffer ClusterBuffer;
        public ComputeBuffer ClusterIndexBuffer;
        public ComputeBuffer CullDataBuffer;
        private ComputeBuffer MeshOffsetBuffer;
        private ComputeBuffer ConstantBuffer;
        private ComputeBuffer CullResultBuffer;
        private ComputeBuffer CullResultIndexBuffer;
        public ComputeBuffer ArgsBuffer;

        //BufferInfo
        private static readonly int VertexBufferInfo = Shader.PropertyToID("VertexBuffer");  
        private static readonly int IndexBufferInfo = Shader.PropertyToID("IndexBuffer");  
        private static readonly int ClusterBufferInfo = Shader.PropertyToID("ClusterBuffer");
        private static readonly int ClusterIndexBufferInfo = Shader.PropertyToID("ClusterIndexBuffer");  
        private static readonly int CullDataBufferInfo = Shader.PropertyToID("CullDataBuffer");  
        private static readonly int MeshOffsetBufferInfo = Shader.PropertyToID("MeshOffsetBuffer");  
        private static readonly int ConstantBufferInfo = Shader.PropertyToID("ConstantBuffer");  
        private static readonly int CullResultBufferInfo = Shader.PropertyToID("CullResultBuffer");  
        private static readonly int CullResultIndexBufferInfo = Shader.PropertyToID("CullResultIndexBuffer");  

        //BufferArray
        public VertexBuffer[] VertexBufferArray;
        public uint[] IndexBufferArray;
        public Cluster[] ClusterArray;
        public uint[] ClusterIndexArray = new uint[64];
        public ClusterCullData[] CullDataBufferArray;
        public ClusterConstantBuffer[] ConstantBufferArray = new ClusterConstantBuffer[1];
        public MeshOffset[] MeshOffsetArray = new MeshOffset[1];
        public uint[] ArgsArray = { new uint() };

        private int kernelIndex;

        private static IndirectDraw _instance;

        public IndirectDraw()
        {
            _instance = this;
        }
        public static IndirectDraw Instance
        {
            get => _instance;
        }

        public override void Create()
        {
            CreateBuffer = true;
            vertexBufferLength = 0;
            indexBufferLength = 0;
            clusterBufferLength = 0;
            DrawLength = 0;

            VertexBufferArray = new VertexBuffer[0];
            IndexBufferArray = new uint[0];
            MeshOffsetArray = new MeshOffset[0];
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            if(vertexBufferLength == 0 || indexBufferLength == 0)
            {
                Debug.Log("Error");
                return;
            }

            if(CreateBuffer)
            {
                CreateVertexBuffer();
                CreateIndexBuffer();
                CreateMeshOffsetBuffer();
                CreateCullResultConstantBuffer();
                CreateCullResultIndexBuffer();
                CreateConstantBuffer();

                CreateBuffer = false;
            }

            if(SetBuffer)
            {
                cmd.SetBufferData(VertexBuffer, VertexBufferArray);
                cmd.SetBufferData(IndexBuffer, IndexBufferArray);
                //cmd.SetBufferData(ClusterBuffer, ClusterArray);
                //cmd.SetBufferData(ClusterIndexBuffer, ClusterIndexArray);
                //cmd.SetBufferData(CullDataBuffer, CullDataBufferArray);
                cmd.SetBufferData(ConstantBuffer, ConstantBufferArray);
                cmd.SetBufferData(MeshOffsetBuffer, MeshOffsetArray);

                kernelIndex = ClusterCullCS.FindKernel("ClusterCull");

                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, VertexBufferInfo, VertexBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, IndexBufferInfo, IndexBuffer);
                // cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, ClusterBufferInfo, ClusterBuffer);
                // cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, ClusterIndexBufferInfo, ClusterIndexBuffer);
                // cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, CullDataBufferInfo, CullDataBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, MeshOffsetBufferInfo, MeshOffsetBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, CullResultIndexBufferInfo, CullResultIndexBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, CullResultBufferInfo, CullResultBuffer);
                cmd.SetComputeConstantBufferParam(ClusterCullCS, ConstantBufferInfo, ConstantBuffer, Marshal.SizeOf<uint>(), Marshal.SizeOf<ClusterConstantBuffer>());

                cmd.SetGlobalBuffer(VertexBufferInfo, VertexBuffer);
                cmd.SetGlobalBuffer(CullResultIndexBufferInfo, CullResultIndexBuffer);
                cmd.SetGlobalBuffer(MeshOffsetBufferInfo, MeshOffsetBuffer);

                SetBuffer = false;
            }

            //ComputeBuffer.CopyCount(CullResultConstantBuffer, ArgsBuffer, 0);

            SetArgsBuffer();
            cmd.SetBufferData(ArgsBuffer, ArgsArray);

            int GroupX = Math.Max((int)indexBufferLength / 64, 1);

            cmd.DispatchCompute(ClusterCullCS, kernelIndex, GroupX, 1, 1);

            cmd.DrawProceduralIndirect(Matrix4x4.identity, mat, 0, MeshTopology.Triangles, ArgsBuffer, 0);

            if(DebugBuffer)
            {
                int[] ResultIndex = new int[indexBufferLength];
                CullResultIndexBuffer.GetData(ResultIndex);


                for(int i = 0; i < indexBufferLength; i++)
                {
                    Debug.Log(ResultIndex[i]);
                }

                DebugBuffer = false;
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();       
        }

        public override void OnFrameEnd(CommandBuffer cmd) 
        {
            if(Clear)
            {
                Create();
                Dispose();
                VertexBufferArray = new VertexBuffer[0];
                IndexBufferArray = new uint[0];
                MeshOffsetArray = new MeshOffset[0];
                Clear = false;
            }
        }

        protected override void Dispose(bool disposing)
        {
            if(VertexBuffer != null) VertexBuffer.Dispose();
            if(IndexBuffer != null) IndexBuffer.Dispose();
            if(ClusterBuffer != null) ClusterBuffer.Dispose();
            if(ClusterIndexBuffer != null) ClusterIndexBuffer.Dispose();
            if(CullDataBuffer != null) CullDataBuffer.Dispose();
            if(MeshOffsetBuffer !=null) MeshOffsetBuffer.Dispose();
            if(ConstantBuffer != null) ConstantBuffer.Dispose();
            if(CullResultBuffer != null) CullResultBuffer.Dispose();
            if(CullResultIndexBuffer != null) CullResultIndexBuffer.Dispose();
            if(ArgsBuffer != null) ArgsBuffer.Dispose();

        }

        public void CreateVertexBuffer()
        {
            VertexBuffer = new ComputeBuffer((int)vertexBufferLength, Marshal.SizeOf<VertexBuffer>(), ComputeBufferType.Structured);
        }

        public void CreateIndexBuffer()
        {
            IndexBuffer = new ComputeBuffer((int)indexBufferLength, Marshal.SizeOf<uint>(), ComputeBufferType.Structured);
        }

        public void CreateMeshOffsetBuffer()
        {
            MeshOffsetBuffer = new ComputeBuffer((int)DrawLength, Marshal.SizeOf<MeshOffset>(), ComputeBufferType.Structured);
        }

        public void CreateCullResultConstantBuffer()
        {
            CullResultBuffer = new ComputeBuffer(1, 4 * Marshal.SizeOf<uint>(), ComputeBufferType.Structured);
        }

        public void CreateCullResultIndexBuffer()
        {
            CullResultIndexBuffer = new ComputeBuffer((int)indexBufferLength, Marshal.SizeOf<uint>(), ComputeBufferType.Append);
        }

        //TODO
        public void SetClusterBuffer()
        {
            ClusterBuffer = new ComputeBuffer(1, Marshal.SizeOf<Cluster>(), ComputeBufferType.Structured);

            ClusterArray = new Cluster[1];
            ClusterArray[0].VertCount = 64;
            ClusterArray[0].PrimCount = 128;
            ClusterArray[0].VertOffset = 0;
            ClusterArray[0].PrimOffset = 0;
        }

        //TODO
        public void SetClusterIndexBuffer()
        {
            ClusterIndexBuffer = new ComputeBuffer(64 * 1, Marshal.SizeOf<int>(), ComputeBufferType.Raw); //ClusterCount * ClusterVertexCount
        }

        //TODO
        public void SetCullDataBuffer()
        {
            CullDataBuffer = new ComputeBuffer(1, Marshal.SizeOf<ClusterCullData>(), ComputeBufferType.Structured);

            CullDataBufferArray = new ClusterCullData[1];
            CullDataBufferArray[0].BoundingSphere = new Vector4(0.0f, 0.0f, 0.0f, 0.0f);
            CullDataBufferArray[0].NormalCone1 = 0;
            CullDataBufferArray[0].NormalCone2 = 0;
            CullDataBufferArray[0].NormalCone3 = 0;
            CullDataBufferArray[0].NormalCone4 = 0;
            CullDataBufferArray[0].ApexOffset = 0;
        }

        //TODO
        public void CreateConstantBuffer()
        {
            ConstantBuffer = new ComputeBuffer(1, Marshal.SizeOf<ClusterConstantBuffer>(), ComputeBufferType.Constant);

            ConstantBufferArray[0] = new ClusterConstantBuffer();
            ConstantBufferArray[0].ClusterCount = 1;
            ConstantBufferArray[0].LastClusterVertCount = 1;
            ConstantBufferArray[0].LastClusterPrimCount = 1;
        }

        public void SetArgsBuffer()
        {
            ArgsArray = new uint[4]{64, indexBufferLength / 64, 0, 0}; //ClusterVertexCount:64, ClusterCount 0, ClusterVertexCount * ClusterCount
  
            ArgsBuffer = new ComputeBuffer(1, 4 * Marshal.SizeOf<uint>(), ComputeBufferType.IndirectArguments);
        }

    }

    public struct VertexBuffer
    {
        public Vector3 Position;
        public Vector3 Normal;
        public Vector2 Texcoord;
        public Vector4 Tangent;
    }

    public struct MeshOffset
    {
        public uint vertexStart;
        public uint vertexCount;
        public uint indexStart;
        public uint indexCount;
        public uint meshLength;
    }

    public struct Cluster
    {
        public uint VertCount;
        public uint VertOffset;
        public uint PrimCount;
        public uint PrimOffset;
    }

    public struct ClusterConstantBuffer
    {
        public uint ClusterCount;
        public uint LastClusterVertCount;
        public uint LastClusterPrimCount;
    }

    public struct ClusterCullData
    {
        public Vector4 BoundingSphere; // xyz = center, w = radius
        public uint NormalCone1;          // xyz = axis, w = -cos(a + 90)
        public uint NormalCone2;
        public uint NormalCone3;
        public uint NormalCone4;
        public uint ApexOffset; // apex = center - axis * offset
    }
}

