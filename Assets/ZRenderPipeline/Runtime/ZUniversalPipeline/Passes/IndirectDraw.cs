using System.Runtime.InteropServices;
using UnityEditor;

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    [InitializeOnLoad]
    public class IndirectDraw : ZScriptableRendererPass
    {
        public Mesh ClusterMesh;
        public bool Upload;
        public bool Clear;
        public bool CreateBuffer;
        public bool SetBuffer;
        public Material mat;
        public ComputeShader ClusterCullCS;

        public uint vertexBufferLength = 0;
        public uint indexBufferLength = 0;
        public uint clusterBufferLength = 0;

        public uint DrawLength = 0;
        public MeshOffset[] MeshOffsetArray = new MeshOffset[1];

        //ComputeBuffer
        public ComputeBuffer VertexBuffer;
        public ComputeBuffer IndexBuffer;
        public ComputeBuffer ClusterBuffer;
        public ComputeBuffer ClusterIndexBuffer;
        public ComputeBuffer CullDataBuffer;
        private ComputeBuffer MeshOffsetBuffer;
        private ComputeBuffer ConstantBuffer;
        public ComputeBuffer ArgsBuffer;

        private static readonly int VertexBufferInfo = Shader.PropertyToID("VertexBuffer");  
        private static readonly int IndexBufferInfo = Shader.PropertyToID("IndexBuffer");  
        private static readonly int ClusterBufferInfo = Shader.PropertyToID("ClusterBuffer");
        private static readonly int ClusterIndexBufferInfo = Shader.PropertyToID("ClusterIndexBuffer");  
        private static readonly int CullDataBufferInfo = Shader.PropertyToID("CullDataBuffer");  
        private static readonly int MeshOffsetBufferInfo = Shader.PropertyToID("MeshOffsetBuffer");  
        private static readonly int ConstantBufferInfo = Shader.PropertyToID("ConstantBuffer");  

        public VertexBuffer[] VertexBufferArray;
        public uint[] IndexBufferArray;
        public Cluster[] ClusterArray;
        public uint[] ClusterIndexArray = new uint[64];
        public ClusterCullData[] CullDataBufferArray;
        public ClusterConstantBuffer[] ConstantBufferArray = new ClusterConstantBuffer[1];
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
            Upload = true;
            CreateBuffer = true;
            vertexBufferLength = 0;
            indexBufferLength = 0;
            clusterBufferLength = 0;
            DrawLength = 0;
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            if(vertexBufferLength == 0 || indexBufferLength == 0)
            {
                Debug.Log("Error");
                return;
            }

            if(Upload)
            {
                SetVertexBuffer();
                SetIndexBuffer();
                SetClusterBuffer();
                SetClusterIndexBuffer();
                SetCullDataBuffer();
                SetClusterConstantBuffer();

                Upload = false;
            }

            if(CreateBuffer)
            {
                CreateVertexBuffer();
                CreateIndexBuffer();
                CreateMeshOffsetBuffer();
                
                CreateBuffer = false;
            }

            if(SetBuffer)
            {
                cmd.SetBufferData(VertexBuffer, VertexBufferArray);
                cmd.SetBufferData(IndexBuffer, IndexBufferArray);
                cmd.SetBufferData(ClusterBuffer, ClusterArray);
                cmd.SetBufferData(ClusterIndexBuffer, ClusterIndexArray);
                cmd.SetBufferData(CullDataBuffer, CullDataBufferArray);
                cmd.SetBufferData(ConstantBuffer, ConstantBufferArray);
                cmd.SetBufferData(MeshOffsetBuffer, MeshOffsetArray);

                kernelIndex = ClusterCullCS.FindKernel("ClusterCull");

                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, VertexBufferInfo, VertexBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, IndexBufferInfo, IndexBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, ClusterBufferInfo, ClusterBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, ClusterIndexBufferInfo, ClusterIndexBuffer);
                cmd.SetComputeBufferParam(ClusterCullCS, kernelIndex, CullDataBufferInfo, CullDataBuffer);
                cmd.SetComputeConstantBufferParam(ClusterCullCS, ConstantBufferInfo, ConstantBuffer, 0, Marshal.SizeOf<ClusterConstantBuffer>());

                cmd.SetGlobalBuffer(VertexBufferInfo, VertexBuffer);
                cmd.SetGlobalBuffer(IndexBufferInfo, IndexBuffer);
                cmd.SetGlobalBuffer(MeshOffsetBufferInfo, MeshOffsetBuffer);
                
                SetBuffer = false;
            }

            SetArgsBuffer();
            cmd.SetBufferData(ArgsBuffer, ArgsArray);

            int GroupX = (int)vertexBufferLength / 64;

            cmd.DispatchCompute(ClusterCullCS, kernelIndex, GroupX, 1, 1);

            cmd.DrawProceduralIndirect(Matrix4x4.identity, mat, 0, MeshTopology.Triangles, ArgsBuffer, 0);

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
            if(ConstantBuffer != null) ConstantBuffer.Dispose();
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

        public void SetVertexBuffer()
        {
            //vertexBufferLength += (uint)ClusterMesh.vertexCount;

            // uint Length = vertexBufferLength;

            // VertexBufferArray = new VertexBuffer[Length];

            // for(int i = 0; i < Length; i++)
            // {
            //     VertexBufferArray[i].Position = ClusterMesh.vertices[i];
            //     VertexBufferArray[i].Normal = ClusterMesh.normals[i];
            //     VertexBufferArray[i].Texcoord = ClusterMesh.uv[i];
            //     VertexBufferArray[i].Tangent = ClusterMesh.tangents[i];
            // }

        }

        public void SetIndexBuffer()
        {
            //indexBufferLength += ClusterMesh.GetIndexCount(0);

            // uint Length = indexBufferLength;

            // IndexBufferArray = new uint[Length];

            // for(int i = 0; i < Length; i++)
            // {
            //     IndexBufferArray[i] = (uint)ClusterMesh.GetIndices(0)[i];
            // }
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

            //ClusterIndexArray = new int {0};
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
        public void SetClusterConstantBuffer()
        {
            ConstantBuffer = new ComputeBuffer(1, Marshal.SizeOf<ClusterConstantBuffer>(), ComputeBufferType.Constant);

            ConstantBufferArray[0] = new ClusterConstantBuffer();
            ConstantBufferArray[0].ClusterCount = 1;
            ConstantBufferArray[0].LastClusterVertCount = 1;
            ConstantBufferArray[0].LastClusterPrimCount = 1;
        }

        public void SetArgsBuffer()
        {
            ArgsArray = new uint[4]{64, indexBufferLength / 64, ClusterMesh.GetIndexStart(0), ClusterMesh.GetBaseVertex(0)}; //ClusterVertexCount:64, ClusterCount 0, ClusterVertexCount * ClusterCount
            //ArgsArray = new uint[4]{64, indexBufferLength / 64 + 2, 0, 0}; //ClusterVertexCount:64, ClusterCount 0, ClusterVertexCount * ClusterCount
  
            ArgsBuffer = new ComputeBuffer(1, ArgsArray.Length * Marshal.SizeOf<uint>(), ComputeBufferType.IndirectArguments);
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

