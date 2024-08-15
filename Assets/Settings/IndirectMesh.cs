using System;
using UnityEngine;
using UnityEngine.Rendering.ZPipeline.ZUniversal;

public class IndirectMesh : MonoBehaviour
{
    public bool Upload;
    private MeshRenderer meshRenderer;
    private Mesh mesh;
    private uint vertexBufferOffset;
    private uint indexBufferOffset;
    private uint clusterBufferOffset;

    void Awake()
    {
        meshRenderer = GetComponent<MeshRenderer>();
        meshRenderer.enabled = false;

        mesh = this.GetComponent<MeshFilter>().mesh;

        vertexBufferOffset = IndirectDraw.Instance.vertexBufferLength;
        indexBufferOffset = IndirectDraw.Instance.indexBufferLength;
        clusterBufferOffset = IndirectDraw.Instance.clusterBufferLength;

        //IndirectDraw.Instance.vertexBufferLength += (uint)(mesh.vertexCount + (64 - mesh.vertexCount % 64));
        IndirectDraw.Instance.vertexBufferLength += (uint)mesh.vertexCount;
        IndirectDraw.Instance.indexBufferLength += mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);
        //IndirectDraw.Instance.clusterBufferLength += (uint)mesh.vertexCount;

        SetVertexBuffer();
        SetIndexBuffer();
        SetMeshOffset();

        Upload = false;
        IndirectDraw.Instance.CreateBuffer = true;
        IndirectDraw.Instance.SetBuffer = true;
    }

    void Update()
    {
        if(Upload)
        {
            mesh = this.GetComponent<MeshFilter>().mesh;

            vertexBufferOffset = IndirectDraw.Instance.vertexBufferLength;
            indexBufferOffset = IndirectDraw.Instance.indexBufferLength;
            clusterBufferOffset = IndirectDraw.Instance.clusterBufferLength;

            IndirectDraw.Instance.vertexBufferLength += (uint)mesh.vertexCount;
            IndirectDraw.Instance.indexBufferLength += mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);
            //IndirectDraw.Instance.clusterBufferLength += (uint)mesh.vertexCount;

            SetVertexBuffer();
            SetIndexBuffer();
            SetMeshOffset();

            Upload = false;
            IndirectDraw.Instance.CreateBuffer = true;
            IndirectDraw.Instance.SetBuffer = true;
        }
    }

    void OnEnable()
    {
        mesh = this.GetComponent<MeshFilter>().mesh;

        meshRenderer = GetComponent<MeshRenderer>();
        meshRenderer.enabled = false;

        vertexBufferOffset = IndirectDraw.Instance.vertexBufferLength;
        indexBufferOffset = IndirectDraw.Instance.indexBufferLength;
        clusterBufferOffset = IndirectDraw.Instance.clusterBufferLength;

        IndirectDraw.Instance.vertexBufferLength += (uint)mesh.vertexCount;
        IndirectDraw.Instance.indexBufferLength += mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);
        //IndirectDraw.Instance.clusterBufferLength += (uint)mesh.vertexCount;

        SetVertexBuffer();
        SetIndexBuffer();
        SetMeshOffset();

        Upload = false;
        IndirectDraw.Instance.CreateBuffer = true;
        IndirectDraw.Instance.SetBuffer = true;
    }

    public void SetVertexBuffer()
    {
        var VertexBufferArray = IndirectDraw.Instance.VertexBufferArray;

        uint preLength = (uint)VertexBufferArray.Length;
        uint length = preLength + (uint)mesh.vertexCount;

        //保证顶点按64倍传输，多余的填入顶点最后一位
        //uint nullLength = preLength + (uint)(mesh.vertexCount + (64 - mesh.vertexCount % 64));

        //VertexBuffer[] VB = new VertexBuffer[nullLength];
        VertexBuffer[] VB = new VertexBuffer[length];


        for(int i = 0; i < preLength; i++)
        {
            VB[i] = VertexBufferArray[i];
        }

        //TODO 缩放 旋转
        //不传矩阵，实例化才传
        //存下世界坐标，awake时候传
        for(uint i = preLength; i < length; i++)
        {
            VB[i].Position = mesh.vertices[i - preLength] + transform.position;
            VB[i].Normal = mesh.normals[i - preLength] +  transform.position;
            VB[i].Texcoord = mesh.uv[i - preLength];
            VB[i].Tangent = mesh.tangents[i - preLength] +  new Vector4(transform.position.x, transform.position.y, transform.position.z, 0.0f);
        }

        // for(uint i = length; i < nullLength; i++)
        // {
        //     VB[i] = VB[length - 1];
        // }

        IndirectDraw.Instance.VertexBufferArray = VB;
    }

    public void SetIndexBuffer()
    {
        var IndexBufferArray = IndirectDraw.Instance.IndexBufferArray;

        uint preLength = (uint)IndexBufferArray.Length;
        uint length = preLength + mesh.GetIndexCount(0);

        uint nullLength = preLength + mesh.GetIndexCount(0) + (64 - mesh.GetIndexCount(0) % 64);

        uint[] IB = new uint[nullLength];
        //uint[] IB = new uint[length];

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
        uint DrawLength = Math.Max(mesh.GetIndexCount(0) / 64, 1);
        IndirectDraw.Instance.DrawLength += DrawLength;

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
        }

        IndirectDraw.Instance.MeshOffsetArray = MO;
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
