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
        public uint clusterPrimitiveLength = 0;
        public uint DrawLength = 0;

        //ComputeBuffer
        public ComputeBuffer VertexBuffer;
        public ComputeBuffer IndexBuffer;
        public ComputeBuffer ClusterBuffer;
        public ComputeBuffer ClusterPrimitiveBuffer;
        public ComputeBuffer CullDataBuffer;
        private ComputeBuffer MeshOffsetBuffer;
        private ComputeBuffer ConstantBuffer;
        private ComputeBuffer CullResultBuffer;
        private ComputeBuffer CullResultClusterBuffer;
        public ComputeBuffer ArgsBuffer;

        //BufferInfo
        private static readonly int VertexBufferInfo = Shader.PropertyToID("VertexBuffer");  
        private static readonly int IndexBufferInfo = Shader.PropertyToID("IndexBuffer");  
        private static readonly int ClusterBufferInfo = Shader.PropertyToID("ClusterBuffer");
        private static readonly int ClusterPrimitiveBufferInfo = Shader.PropertyToID("ClusterIndexBuffer");  
        private static readonly int CullDataBufferInfo = Shader.PropertyToID("CullDataBuffer");  
        private static readonly int MeshOffsetBufferInfo = Shader.PropertyToID("MeshOffsetBuffer");  
        private static readonly int ConstantBufferInfo = Shader.PropertyToID("ConstantBuffer");  
        private static readonly int CullResultBufferInfo = Shader.PropertyToID("CullResultBuffer");  
        private static readonly int CullResultClusterBufferInfo = Shader.PropertyToID("CullResultClusterBuffer");  

        //BufferArray
        public VertexBuffer[] VertexBufferArray;
        public uint[] IndexBufferArray;
        public Cluster[] ClusterBufferArray;
        public Primitive[] ClusterPrimitiveArray = new Primitive[128]; //可以进一步减少
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
            clusterPrimitiveLength = 0;
            DrawLength = 0;

            VertexBufferArray = new VertexBuffer[0];
            IndexBufferArray = new uint[0];
            ClusterBufferArray = new Cluster[0];
            ClusterPrimitiveArray = new Primitive[0];
            CullDataBufferArray = new ClusterCullData[0];
            ConstantBufferArray = new ClusterConstantBuffer[1];
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
                CreateClusterBuffer();
                CreateClusterPrimitiveBuffer();
                CreateCullDataBuffer();
                CreateConstantBuffer();
                CreateMeshOffsetBuffer();
                CreateCullResultConstantBuffer();
                CreateCullResultClusterBuffer();
                
                CreateBuffer = false;
            }

            if(SetBuffer)
            {
                cmd.SetBufferData(VertexBuffer, VertexBufferArray);
                cmd.SetBufferData(IndexBuffer, IndexBufferArray);
                cmd.SetBufferData(ClusterBuffer, ClusterBufferArray);
                cmd.SetBufferData(ClusterPrimitiveBuffer, ClusterPrimitiveArray);
                cmd.SetBufferData(CullDataBuffer, CullDataBufferArray);
                cmd.SetBufferData(ConstantBuffer, ConstantBufferArray);
                cmd.SetBufferData(MeshOffsetBuffer, MeshOffsetArray);

                kernelIndex = ClusterCullCS.FindKernel("ClusterCull");

                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, VertexBufferInfo, VertexBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, IndexBufferInfo, IndexBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, ClusterBufferInfo, ClusterBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, ClusterPrimitiveBufferInfo, ClusterPrimitiveBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, CullDataBufferInfo, CullDataBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, MeshOffsetBufferInfo, MeshOffsetBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, CullResultClusterBufferInfo, CullResultClusterBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, CullResultBufferInfo, CullResultBuffer);
                cmd.SetComputeConstantBufferParam(ClusterCullCS, ConstantBufferInfo, ConstantBuffer, Marshal.SizeOf<uint>(), Marshal.SizeOf<ClusterConstantBuffer>());

                cmd.SetGlobalBuffer(VertexBufferInfo, VertexBuffer);
                // cmd.SetGlobalBuffer(IndexBufferInfo, IndexBuffer);
                cmd.SetGlobalBuffer(ClusterPrimitiveBufferInfo, ClusterPrimitiveBuffer);
                cmd.SetGlobalBuffer(CullResultClusterBufferInfo, CullResultClusterBuffer);
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
                CullResultClusterBuffer.GetData(ResultIndex);


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
                Clear = false;
            }
        }

        protected override void Dispose(bool disposing)
        {
            if(VertexBuffer != null) VertexBuffer.Dispose();
            if(IndexBuffer != null) IndexBuffer.Dispose();
            if(ClusterBuffer != null) ClusterBuffer.Dispose();
            if(ClusterPrimitiveBuffer != null) ClusterPrimitiveBuffer.Dispose();
            if(CullDataBuffer != null) CullDataBuffer.Dispose();
            if(MeshOffsetBuffer !=null) MeshOffsetBuffer.Dispose();
            if(ConstantBuffer != null) ConstantBuffer.Dispose();
            if(CullResultBuffer != null) CullResultBuffer.Dispose();
            if(CullResultClusterBuffer != null) CullResultClusterBuffer.Dispose();
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

        public void CreateClusterBuffer()
        {
            ClusterBuffer = new ComputeBuffer((int)clusterBufferLength, Marshal.SizeOf<Cluster>(), ComputeBufferType.Structured);
        }

        public void CreateClusterPrimitiveBuffer()
        {
            ClusterPrimitiveBuffer = new ComputeBuffer((int)clusterPrimitiveLength * 128, Marshal.SizeOf<Primitive>(), ComputeBufferType.Structured);
        }

        public void CreateCullDataBuffer()
        {
            CullDataBuffer = new ComputeBuffer((int)clusterBufferLength, Marshal.SizeOf<ClusterCullData>(), ComputeBufferType.Structured);
        }

        public void CreateMeshOffsetBuffer()
        {
            MeshOffsetBuffer = new ComputeBuffer((int)DrawLength, Marshal.SizeOf<uint>(), ComputeBufferType.Structured);
        }

        public void CreateCullResultConstantBuffer()
        {
            CullResultBuffer = new ComputeBuffer(1, 4 * Marshal.SizeOf<uint>(), ComputeBufferType.Structured);
        }

        public void CreateCullResultClusterBuffer()
        {
            CullResultClusterBuffer = new ComputeBuffer((int)clusterBufferLength, Marshal.SizeOf<Cluster>(), ComputeBufferType.Append);
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
        public Vector3 Tangent;
    }

    public struct MeshOffset
    {
        public uint clusterStart;
        public uint clusterCount;
        public uint meshLength;
    }

    public struct Cluster
    {
        public uint VertCount;
        public uint VertOffset;
        public uint PrimCount;
        public uint PrimOffset;
    }

    public struct Primitive
    {
        public uint i0;
        public uint i1;
        public uint i2;
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

