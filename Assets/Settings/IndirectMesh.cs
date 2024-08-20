using System;
using UnityEngine;
using UnityEngine.Rendering.ZPipeline.ZUniversal;
using System.Collections.Generic;
using Unity.Mathematics;

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
    private ZClusterReader.ClusterMesh mesh;
    private uint vertexBufferOffset;
    private uint vertexBufferCount;
    private uint meshLengthOffset;
    private uint meshLengthCount;
    private uint clusterBufferOffset;
    private uint clusterBufferCount;
    private uint clusterPrimitiveOffset;
    private uint clusterPrimitiveCount;
    void Awake()
    {
        meshRenderer = GetComponent<MeshRenderer>();
        if(meshRenderer != null) meshRenderer.enabled = false;


        mesh = GetComponent<ZClusterReader>().GetMesh();
        if(EqualityComparer<ZClusterReader.ClusterMesh>.Default.Equals(mesh)) return;

        vertexBufferOffset = IndirectDraw.Instance.vertexBufferLength;
        meshLengthOffset = IndirectDraw.Instance.DrawLength;
        clusterBufferOffset = IndirectDraw.Instance.clusterBufferLength;
        clusterPrimitiveOffset = IndirectDraw.Instance.clusterPrimitiveLength;

        vertexBufferCount = mesh.VertexCount;
        meshLengthCount = Math.Max((mesh.IndexCount + (128 - mesh.IndexCount % 128)) / 128 , 1);
        clusterBufferCount = (uint)mesh.Meshlets.Length;
        clusterPrimitiveCount = (uint)mesh.PrimitiveIndices.Length;

        IndirectDraw.Instance.vertexBufferLength += mesh.VertexCount;
        IndirectDraw.Instance.clusterBufferLength += (uint)mesh.Meshlets.Length;
        IndirectDraw.Instance.clusterPrimitiveLength += (uint)mesh.PrimitiveIndices.Length;

        SetVertexBuffer();
        SetClusterBuffer();
        SetClusterPrimitiveBuffer();
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
            mesh = GetComponent<ZClusterReader>().GetMesh();
            if(EqualityComparer<ZClusterReader.ClusterMesh>.Default.Equals(mesh)) return;

            vertexBufferOffset = IndirectDraw.Instance.vertexBufferLength;
            meshLengthOffset = IndirectDraw.Instance.DrawLength;
            clusterBufferOffset = IndirectDraw.Instance.clusterBufferLength;
            clusterPrimitiveOffset = IndirectDraw.Instance.clusterPrimitiveLength;

            vertexBufferCount = mesh.VertexCount;
            meshLengthCount = Math.Max((mesh.IndexCount + (128 - mesh.IndexCount % 128)) / 128 , 1);
            clusterBufferCount = (uint)mesh.Meshlets.Length;
            clusterPrimitiveCount = (uint)mesh.PrimitiveIndices.Length;

            IndirectDraw.Instance.vertexBufferLength += (uint)mesh.VertexCount;
            IndirectDraw.Instance.clusterBufferLength += (uint)mesh.Meshlets.Length;
            IndirectDraw.Instance.clusterPrimitiveLength += (uint)mesh.PrimitiveIndices.Length;

            SetVertexBuffer();
            SetClusterBuffer();
            SetClusterPrimitiveBuffer();
            SetMeshOffset();

            ControlUpload = false;
            ControlRemove = true;
            IndirectDraw.Instance.CreateBuffer = true;
            IndirectDraw.Instance.SetBuffer = true;
        }

        if(!UploadBuffer && ControlRemove)
        {
            vertexBufferCount = mesh.VertexCount;
            meshLengthCount = Math.Max((mesh.IndexCount + (128 - mesh.IndexCount % 128)) / 128 , 1);
            clusterBufferCount = (uint)mesh.Meshlets.Length;
            clusterPrimitiveCount = (uint)mesh.PrimitiveIndices.Length;

            IndirectDraw.Instance.vertexBufferLength -= mesh.VertexCount;
            IndirectDraw.Instance.clusterBufferLength -= (uint)mesh.Meshlets.Length;
            IndirectDraw.Instance.clusterPrimitiveLength -= (uint)mesh.PrimitiveIndices.Length;

            RemoveVertexBuffer();
            RemoveClusterBuffer();
            RemoveClusterPrimitiveBuffer();
            RemoveMeshOffset();

            vertexBufferOffset = 0;
            meshLengthOffset = 0;
            clusterBufferOffset = 0;
            clusterPrimitiveOffset = 0;

            UploadBuffer = true;
            ControlUpload = false;
            ControlRemove = true;
            IndirectDraw.Instance.CreateBuffer = true;
            IndirectDraw.Instance.SetBuffer = true;
        }

        // var cmd = CommandBufferPool.Get();
        // cmd.DrawProceduralIndirect(Matrix4x4.identity, meshRenderer.material, 0, MeshTopology.Triangles, IndirectDraw.Instance.ArgsBuffer, 0);
    }

    public void SetVertexBuffer()
    {
        var VertexBufferArray = IndirectDraw.Instance.VertexBufferArray;

        uint preLength = (uint)VertexBufferArray.Length;
        uint length = preLength + (uint)mesh.VertexCount;

        VertexBuffer[] VB = new VertexBuffer[length];

        for(int i = 0; i < preLength; i++)
        {
            VB[i] = VertexBufferArray[i];
        }

        for(uint i = preLength; i < length; i++)
        {
            VB[i].Position = (Vector3)mesh.Vertexs[i - preLength] + transform.position;

            if(mesh.Normals != null)
            {
                VB[i].Normal = (Vector3)mesh.Normals[i - preLength] +  transform.position;
            }
            else
            {
                VB[i].Normal = new Vector3(0.0f, 0.0f, 0.0f);
            } 

            if(mesh.Texcoords != null)
            {
                VB[i].Texcoord = (Vector2)mesh.Texcoords[i - preLength];
            }
            else
            {
                VB[i].Texcoord = new Vector2(0.0f, 0.0f);
            } 

            if(mesh.Tangents != null)
            {
                VB[i].Tangent = (Vector3)mesh.Tangents[i - preLength] +  new Vector3(transform.position.x, transform.position.y, transform.position.z);

            }
            else
            {
                VB[i].Tangent = new Vector3(0.0f, 0.0f, 0.0f);
            } 
        }

        IndirectDraw.Instance.VertexBufferArray = VB;
    }

    public void SetClusterBuffer()
    {
        var ClusterBufferArray = IndirectDraw.Instance.ClusterBufferArray;

        uint preLength = (uint)ClusterBufferArray.Length;
        uint length = preLength + (uint)mesh.Meshlets.Length;

        Cluster[] CB = new Cluster[length];

        for(int i = 0; i < preLength; i++)
        {
            CB[i] = ClusterBufferArray[i];
        }

        for(uint i = preLength; i < length; i++)
        {
            CB[i].PrimCount = mesh.Meshlets[i - preLength].PrimCount;
            CB[i].PrimOffset = mesh.Meshlets[i - preLength].PrimOffset;
        }

        IndirectDraw.Instance.ClusterBufferArray = CB;
    }

    public void SetClusterPrimitiveBuffer()
    {
        var ClusterPrimitiveArray = IndirectDraw.Instance.ClusterPrimitiveArray;

        uint preLength = (uint)ClusterPrimitiveArray.Length;
        uint length = preLength + (uint)mesh.PrimitiveIndices.Length;

        uint3[] CPB = new uint3[length];

        for(int i = 0; i < preLength; i++)
        {
            CPB[i] = ClusterPrimitiveArray[i];
        }

        for(uint i = preLength; i < length; i++)
        {
            CPB[i][0] = mesh.PrimitiveIndices[i - preLength].i0;
            CPB[i][1] = mesh.PrimitiveIndices[i - preLength].i1;
            CPB[i][2] = mesh.PrimitiveIndices[i - preLength].i2;
        }

        IndirectDraw.Instance.ClusterPrimitiveArray = CPB;
    }

    public void SetMeshOffset()
    {
        uint DrawLength = Math.Max((mesh.IndexCount + (128 - mesh.IndexCount % 128)) / 128 , 1);

        uint preLength = (uint)IndirectDraw.Instance.MeshOffsetArray.Length;
        uint length = preLength + DrawLength;

        MeshOffset[] MO = new MeshOffset[length];

        for(int i = 0; i < preLength; i++)
        {
            MO[i] = IndirectDraw.Instance.MeshOffsetArray[i];
        }

        for(uint i = preLength; i < length; i++)
        {
            MO[i].clusterStart = clusterBufferOffset;
            MO[i].clusterCount = (uint)mesh.Meshlets.Length;
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

    public void RemoveClusterBuffer()
    {
        var ClusterBufferArray = IndirectDraw.Instance.ClusterBufferArray;

        uint preLength = (uint)ClusterBufferArray.Length;
        uint length = preLength - clusterBufferCount;

        Cluster[] CB = new Cluster[length];

        for(int i = 0; i < clusterBufferCount; i++)
        {
            CB[i] = ClusterBufferArray[i];
        }

        for(uint i = clusterBufferCount; i < length; i++)
        {
            CB[i] = ClusterBufferArray[i + clusterBufferCount];
        }

        IndirectDraw.Instance.ClusterBufferArray = CB;
    }

    public void RemoveClusterPrimitiveBuffer()
    {
        var ClusterPrimitiveArray = IndirectDraw.Instance.ClusterPrimitiveArray;

        uint preLength = (uint)ClusterPrimitiveArray.Length;
        uint length = preLength - clusterBufferCount * 128;

        uint3[] CPB = new uint3[length];

        for(int i = 0; i < vertexBufferOffset; i++)
        {
            CPB[i] = ClusterPrimitiveArray[i];
        }

        for(uint i = vertexBufferOffset; i < length; i++)
        {
            CPB[i] = ClusterPrimitiveArray[i + vertexBufferCount];
        }

        IndirectDraw.Instance.ClusterPrimitiveArray = CPB;
    }

    public void RemoveMeshOffset()
    {
        uint DrawLength = Math.Max((mesh.IndexCount + (128 - mesh.IndexCount % 128)) / 128 , 1);

        var MeshOffsetArray = IndirectDraw.Instance.MeshOffsetArray;

        uint preLength = (uint)MeshOffsetArray.Length;
        uint length = preLength - meshLengthCount;

        MeshOffset[] MO = new MeshOffset[length];

        for(int i = 0; i < meshLengthOffset; i++)
        {
            MO[i] = MeshOffsetArray[i];
        }

        for(uint i = meshLengthOffset; i < length; i++)
        {
            MO[i] = MeshOffsetArray[i + meshLengthCount];

            MO[i].clusterStart -= clusterBufferOffset;
            MO[i].clusterCount -= (uint)mesh.Meshlets.Length;
            MO[i].meshLength -= DrawLength;
        }

        //ResetMeshOffset
        IndirectDraw.Instance.DrawLength -= DrawLength;
        IndirectDraw.Instance.MeshOffsetArray = MO;
    }
}
