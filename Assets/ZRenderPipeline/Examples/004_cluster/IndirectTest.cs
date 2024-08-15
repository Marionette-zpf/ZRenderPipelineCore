using System.Runtime.InteropServices;


namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class IndirectTest : ZScriptableRendererPass
    {
        public Mesh ClusterMesh;
        public bool Upload = true;
        public Material mat;

        //ComputeBuffer
        private ComputeBuffer VertexBuffer;
        private ComputeBuffer IndexBuffer;


        private static readonly int VertexBufferInfo = Shader.PropertyToID("VertexBuffer");  
        private static readonly int IndexBufferInfo = Shader.PropertyToID("IndexBuffer");  
        private VertexBuffer[] VBArray = { new VertexBuffer() };

        private Vector4[] VBArray4;

        private int[] IBArray = { new int() };

        public override void Create()
        {
            Upload = true;
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            //if(Upload)
            //{
            //    SetVertexBuffer();
            //    SetIndexBuffer();

            //    cmd.SetBufferData(VertexBuffer, VBArray4);
            //    cmd.SetBufferData(IndexBuffer, IBArray);

            //    Upload = false;
            //}



            SetVertexBuffer();
            SetIndexBuffer();

            cmd.SetBufferData(VertexBuffer, VBArray4);
            cmd.SetBufferData(IndexBuffer, IBArray);


            cmd.SetGlobalVectorArray("VertexBuffer", VBArray4);

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();


            //cmd.DrawProcedural(Matrix4x4.identity, mat, 0, MeshTopology.Triangles, ClusterMesh.vertices.Length, ClusterMesh);

            //cmd.DrawMesh(ClusterMesh, Matrix4x4.identity, mat, 0);

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();       
        }

        public override void OnFrameEnd(CommandBuffer cmd) 
        {
            VertexBuffer?.Dispose();
            IndexBuffer?.Dispose();

        }

        public void SetVertexBuffer()
        {
            VertexBuffer = new ComputeBuffer(ClusterMesh.vertices.Length, sizeof(float) * 4, ComputeBufferType.Structured);


            VBArray = new VertexBuffer[ClusterMesh.vertices.Length];

            VBArray4 = new Vector4[ClusterMesh.vertices.Length];

            for (int i = 0; i < ClusterMesh.vertices.Length; i++)
            {
                VBArray[i].Position = ClusterMesh.vertices[i];
                VBArray[i].Normal = ClusterMesh.normals[i];

                VBArray4[i] = new Vector4(ClusterMesh.vertices[i].x, ClusterMesh.vertices[i].y, ClusterMesh.vertices[i].z, 1.0f);
            }
        }

        public void SetIndexBuffer()
        {
            IndexBuffer = new ComputeBuffer((int)ClusterMesh.GetIndexCount(0), Marshal.SizeOf<uint>(), ComputeBufferType.IndirectArguments);
            IBArray = ClusterMesh.GetIndices(0);

        }

       
    }

    public struct VertexBuffer
    {
        public Vector3 Position;
        public Vector3 Normal;
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

}

