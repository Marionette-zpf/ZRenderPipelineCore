using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.ZPipeline.ZUniversal;


//TODO 相同材质一个脚本，收集Child下所有顶点相关数据，来进行合批
//TODO 采用世界坐标存储顶点
//TODO 视椎体剔除，遮挡剔除
//TODO LOD
//TODO 相同Mesh合批实例化
//TODO 应用SubMesh
//TODO Cluster剔除
public class IndirectMesh : MonoBehaviour
{
    public bool UploadBuffer = false;
    private bool ControlUpload = true;
    private bool ControlRemove = false;
    private MeshRenderer meshRenderer;
    private Mesh mesh;
    private uint vertexBufferOffset;
    private uint vertexBufferCount;
    private uint indexBufferOffset;
    private uint indexBufferCount;
    private uint meshLengthOffset;
    private uint meshLengthCount;
    private uint clusterBufferOffset;

    void Awake()
    {
        meshRenderer = GetComponent<MeshRenderer>();
        meshRenderer.enabled = false;

        mesh = this.GetComponent<MeshFilter>().mesh;

        vertexBufferOffset = IndirectDraw.Instance.vertexBufferLength;
        indexBufferOffset = IndirectDraw.Instance.indexBufferLength;
        meshLengthOffset = IndirectDraw.Instance.DrawLength;
        clusterBufferOffset = IndirectDraw.Instance.clusterBufferLength;

        vertexBufferCount = (uint)mesh.vertexCount;
        indexBufferCount = mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);
        meshLengthCount = Math.Max((mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64)) / 64 , 1);

        IndirectDraw.Instance.vertexBufferLength += (uint)mesh.vertexCount;
        IndirectDraw.Instance.indexBufferLength += mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);

        SetVertexBuffer();
        SetIndexBuffer();
        SetMeshOffset();

        UploadBuffer = true;
        ControlUpload = false;
        ControlRemove = true;
        IndirectDraw.Instance.CreateBuffer = true;
        IndirectDraw.Instance.SetBuffer = true;
    }

    void Update()
    {
        if(UploadBuffer && ControlUpload)
        {
            mesh = this.GetComponent<MeshFilter>().mesh;

            vertexBufferOffset = IndirectDraw.Instance.vertexBufferLength;
            indexBufferOffset = IndirectDraw.Instance.indexBufferLength;
            meshLengthOffset = IndirectDraw.Instance.DrawLength;
            clusterBufferOffset = IndirectDraw.Instance.clusterBufferLength;

            vertexBufferCount = (uint)mesh.vertexCount;
            indexBufferCount = mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);
            meshLengthCount = Math.Max((mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64)) / 64 , 1);

            IndirectDraw.Instance.vertexBufferLength += (uint)mesh.vertexCount;
            IndirectDraw.Instance.indexBufferLength += mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);

            SetVertexBuffer();
            SetIndexBuffer();
            SetMeshOffset();

            ControlUpload = false;
            ControlRemove = true;
            IndirectDraw.Instance.CreateBuffer = true;
            IndirectDraw.Instance.SetBuffer = true;
        }

        if(!UploadBuffer && ControlRemove)
        {
            vertexBufferCount = (uint)mesh.vertexCount;
            indexBufferCount = mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);
            meshLengthCount = Math.Max((mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64)) / 64 , 1);

            IndirectDraw.Instance.vertexBufferLength -= (uint)mesh.vertexCount;
            IndirectDraw.Instance.indexBufferLength -= mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);

            RemoveVertexBuffer();
            RemoveIndexBuffer();
            RemoveMeshOffset();

            vertexBufferOffset = 0;
            indexBufferOffset = 0;
            meshLengthOffset = 0;
            clusterBufferOffset = 0;

            UploadBuffer = true;
            ControlUpload = false;
            ControlRemove = true;
            IndirectDraw.Instance.CreateBuffer = true;
            IndirectDraw.Instance.SetBuffer = true;
        }

        // var cmd = CommandBufferPool.Get();
        // cmd.DrawProceduralIndirect(Matrix4x4.identity, meshRenderer.material, 0, MeshTopology.Triangles, IndirectDraw.Instance.ArgsBuffer, 0);
    }

    void OnEnable()
    {
        meshRenderer = GetComponent<MeshRenderer>();
        meshRenderer.enabled = false;

        mesh = this.GetComponent<MeshFilter>().mesh;

        vertexBufferOffset = IndirectDraw.Instance.vertexBufferLength;
        indexBufferOffset = IndirectDraw.Instance.indexBufferLength;
        meshLengthOffset = IndirectDraw.Instance.DrawLength;
        clusterBufferOffset = IndirectDraw.Instance.clusterBufferLength;

        vertexBufferCount = (uint)mesh.vertexCount;
        indexBufferCount = mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);
        meshLengthCount = Math.Max((mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64)) / 64 , 1);

        IndirectDraw.Instance.vertexBufferLength += (uint)mesh.vertexCount;
        IndirectDraw.Instance.indexBufferLength += mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);

        SetVertexBuffer();
        SetIndexBuffer();
        SetMeshOffset();

        UploadBuffer = true;
        ControlUpload = false;
        ControlRemove = true;
        IndirectDraw.Instance.CreateBuffer = true;
        IndirectDraw.Instance.SetBuffer = true;
    }

    public void SetVertexBuffer()
    {
        var VertexBufferArray = IndirectDraw.Instance.VertexBufferArray;

        uint preLength = (uint)VertexBufferArray.Length;
        uint length = preLength + (uint)mesh.vertexCount;

        VertexBuffer[] VB = new VertexBuffer[length];

        for(int i = 0; i < preLength; i++)
        {
            VB[i] = VertexBufferArray[i];
        }

        for(uint i = preLength; i < length; i++)
        {
            VB[i].Position = mesh.vertices[i - preLength] + transform.position;
            VB[i].Normal = mesh.normals[i - preLength] +  transform.position;
            VB[i].Texcoord = mesh.uv[i - preLength];
            VB[i].Tangent = mesh.tangents[i - preLength] +  new Vector4(transform.position.x, transform.position.y, transform.position.z, 0.0f);
        }

        IndirectDraw.Instance.VertexBufferArray = VB;
    }

    public void SetIndexBuffer()
    {
        var IndexBufferArray = IndirectDraw.Instance.IndexBufferArray;

        uint preLength = (uint)IndexBufferArray.Length;
        uint length = preLength + mesh.GetIndexCount(0);

        uint nullLength = preLength + mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);

        uint[] IB = new uint[nullLength];

        for(int i = 0; i < preLength; i++)
        {
            IB[i] = IndexBufferArray[i];
        }

        for(uint i = preLength; i < length; i++)
        {
            IB[i] = (uint)mesh.GetIndices(0)[i - preLength];
        }

        for(uint i = length; i < nullLength; i++)
        {
            IB[i] = IB[length - 1];
        }

        IndirectDraw.Instance.IndexBufferArray = IB;
    }

    public void SetMeshOffset()
    {
        uint DrawLength = Math.Max((mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64)) / 64 , 1);


        uint preLength = (uint)IndirectDraw.Instance.MeshOffsetArray.Length;
        uint length = preLength + DrawLength;

        MeshOffset[] MO = new MeshOffset[length];

        for(int i = 0; i < preLength; i++)
        {
            MO[i] = IndirectDraw.Instance.MeshOffsetArray[i];
        }

        for(uint i = preLength; i < length; i++)
        {
            MO[i].vertexStart = vertexBufferOffset;
            MO[i].vertexCount = (uint)mesh.vertexCount;
            MO[i].indexStart = indexBufferOffset;
            MO[i].indexCount = mesh.GetIndexCount(0);
            MO[i].meshLength = IndirectDraw.Instance.DrawLength;
        }

        IndirectDraw.Instance.DrawLength += DrawLength;
        IndirectDraw.Instance.MeshOffsetArray = MO;
    }

    public void RemoveVertexBuffer()
    {
        var VertexBufferArray = IndirectDraw.Instance.VertexBufferArray;

        uint preLength = (uint)VertexBufferArray.Length;
        uint length = preLength - vertexBufferCount;

        VertexBuffer[] VB = new VertexBuffer[length];

        for(int i = 0; i < vertexBufferOffset; i++)
        {
            VB[i] = VertexBufferArray[i];
        }

        for(uint i = vertexBufferOffset; i < length; i++)
        {
            VB[i] = VertexBufferArray[i + vertexBufferCount];
        }

        IndirectDraw.Instance.VertexBufferArray = VB;
    }

    public void RemoveIndexBuffer()
    {
        var IndexBufferArray = IndirectDraw.Instance.IndexBufferArray;

        uint preLength = (uint)IndexBufferArray.Length;
        uint length = preLength - indexBufferCount;

        uint[] IB = new uint[length];

        for(int i = 0; i < indexBufferOffset; i++)
        {
            IB[i] = IndexBufferArray[i];
        }

        for(uint i = indexBufferOffset; i < length; i++)
        {
            IB[i] = IndexBufferArray[i + indexBufferCount];
        }

        IndirectDraw.Instance.IndexBufferArray = IB;
    }

    public void RemoveMeshOffset()
    {
        uint DrawLength = Math.Max((mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64)) / 64 , 1);

        var MeshOffsetArray = IndirectDraw.Instance.MeshOffsetArray;

        uint preLength = (uint)MeshOffsetArray.Length;
        uint length = preLength - meshLengthCount;

        MeshOffset[] MS = new MeshOffset[length];

        for(int i = 0; i < meshLengthOffset; i++)
        {
            MS[i] = MeshOffsetArray[i];
        }

        for(uint i = meshLengthOffset; i < length; i++)
        {
            MS[i] = MeshOffsetArray[i + meshLengthCount];
            MS[i].vertexStart -= vertexBufferCount;
            MS[i].vertexCount -= vertexBufferCount;
            MS[i].indexStart -= indexBufferCount;
            MS[i].indexCount -= indexBufferCount;
            MS[i].meshLength -= DrawLength;
        }

        //ResetMeshOffset

        IndirectDraw.Instance.DrawLength -= DrawLength;
        IndirectDraw.Instance.MeshOffsetArray = MS;
    }
    //TODO
    // public void SetClusterBuffer()
    // {
    //     ClusterBuffer = new ComputeBuffer(1, Marshal.SizeOf<Cluster>(), ComputeBufferType.Structured);

    //     ClusterArray = new Cluster[1];
    //     ClusterArray[0].VertCount = 64;
    //     ClusterArray[0].PrimCount = 128;
    //     ClusterArray[0].VertOffset = 0;
    //     ClusterArray[0].PrimOffset = 0;
    // }

    //     //TODO
    // public void SetClusterIndexBuffer()
    // {
    //     ClusterIndexBuffer = new ComputeBuffer(64 * 1, Marshal.SizeOf<int>(), ComputeBufferType.Raw); //ClusterCount * ClusterVertexCount

    //     //ClusterIndexArray = new int {0};
    // }

    // //TODO
    // public void SetCullDataBuffer()
    // {
    //     CullDataBuffer = new ComputeBuffer(1, Marshal.SizeOf<ClusterCullData>(), ComputeBufferType.Structured);

    //     CullDataBufferArray = new ClusterCullData[1];
    //     CullDataBufferArray[0].BoundingSphere = new Vector4(0.0f, 0.0f, 0.0f, 0.0f);
    //     CullDataBufferArray[0].NormalCone1 = 0;
    //     CullDataBufferArray[0].NormalCone2 = 0;
    //     CullDataBufferArray[0].NormalCone3 = 0;
    //     CullDataBufferArray[0].NormalCone4 = 0;
    //     CullDataBufferArray[0].ApexOffset = 0;
    // }

    // //TODO
    // public void SetClusterConstantBuffer()
    // {
    //     ConstantBuffer = new ComputeBuffer(1, Marshal.SizeOf<ClusterConstantBuffer>(), ComputeBufferType.Constant);

    //     ConstantBufferArray[0] = new ClusterConstantBuffer();
    //     ConstantBufferArray[0].ClusterCount = 1;
    //     ConstantBufferArray[0].LastClusterVertCount = 1;
    //     ConstantBufferArray[0].LastClusterPrimCount = 1;
    // }

    // public void SetArgsBuffer()
    // {
    //     ArgsArray = new uint[4]{64, mesh.GetIndexCount(0) / 64 + 1, mesh.GetIndexStart(0), mesh.GetBaseVertex(0)}; //ClusterVertexCount:64, ClusterCount 0, ClusterVertexCount * ClusterCount

    //     ArgsBuffer = new ComputeBuffer(1, ArgsArray.Length * Marshal.SizeOf<uint>(), ComputeBufferType.IndirectArguments);
    // }
}
