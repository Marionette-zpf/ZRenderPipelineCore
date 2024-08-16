using MemoryPack;
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using Unity.Mathematics;
using UnityEngine;

public class ZClusterReader : MonoBehaviour
{

    public static string g_Path = "/ZRenderPipeline/Examples/004_cluster/";

    public string fileName;

    private byte[] m_buffer;
    private Mesh[] m_meshes;

    [ContextMenu("测试读取 Cluster 数据")]
    public void Test01()
    {

        FileHeader header;
        MeshHeader[] meshes;
        Accessor[] accessors;
        BufferView[] bufferViews;

        BinaryReader br;

        try
        {
            br = new BinaryReader(new FileStream(Application.dataPath + g_Path + fileName,
                            FileMode.Open));
        }
        catch (IOException e)
        {
            Debug.LogError(e.Message + "\n Cannot open file.");
            return;
        }
        try
        {

            header = MemoryPackSerializer.Deserialize<FileHeader>(br.ReadBytes(Marshal.SizeOf(typeof(FileHeader))));

            meshes = new MeshHeader[header.MeshCount];
            accessors = new Accessor[header.AccessorCount];
            bufferViews = new BufferView[header.BufferViewCount];


            for (int i = 0; i < header.MeshCount; i++)
            {
                MeshHeader meshHeader;
                meshHeader.Attributes = new uint[Attribute.EType.Count.GetHashCode()];

                meshHeader.Indices = br.ReadUInt32();
                meshHeader.IndexSubsets = br.ReadUInt32();

                for (int attrIndex = 0; attrIndex < meshHeader.Attributes.Length; attrIndex++)
                {
                    meshHeader.Attributes[attrIndex] = br.ReadUInt32();
                }

                meshHeader.Meshlets = br.ReadUInt32();
                meshHeader.MeshletSubsets = br.ReadUInt32();
                meshHeader.UniqueVertexIndices = br.ReadUInt32();
                meshHeader.PrimitiveIndices = br.ReadUInt32();
                meshHeader.CullData = br.ReadUInt32();

                meshes[i] = meshHeader;
            }

            for (int i = 0; i < header.AccessorCount; i++)
            {
                accessors[i] = MemoryPackSerializer.Deserialize<Accessor>(br.ReadBytes(Marshal.SizeOf(typeof(Accessor))));
            }

            for (int i = 0; i < header.BufferViewCount; i++)
            {
                bufferViews[i] = MemoryPackSerializer.Deserialize<BufferView>(br.ReadBytes(Marshal.SizeOf(typeof(BufferView))));
            }

            m_buffer = br.ReadBytes((int)header.BufferSize);

            if (br.BaseStream.Position != br.BaseStream.Length)
            {
                throw new Exception("error.");
            }

            //Assert.AreEqual(br.Read(), 0);
        }
        catch (IOException e)
        {
            Debug.LogError(e.Message + "\n Cannot read from file.");
            return;
        }
        br.Close();

        m_meshes = new Mesh[meshes.Length];


        var spanBuffer = new Span<byte>(m_buffer);

        for (int i = 0; i < m_meshes.Length; i++)
        {
            ref var meshView = ref meshes[i];
            ref var mesh = ref m_meshes[i];

            // Index data
            {
                ref Accessor accessor = ref accessors[meshView.Indices];
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                mesh.IndexSize = accessor.Size;
                mesh.IndexCount = accessor.Count;

                mesh.Indices = spanBuffer.Slice((int)bufferView.Offset, (int)bufferView.Size).ToArray();
            }

            // Index Subset data
            {
                ref Accessor accessor = ref accessors[meshView.IndexSubsets];
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                mesh.IndexSubsets = new Subset[accessor.Count];

                var subsetSize = Marshal.SizeOf(typeof(Subset));

                for (int subsetIndex = 0; subsetIndex < mesh.IndexSubsets.Length; subsetIndex++)
                {
                    mesh.IndexSubsets[subsetIndex] = MemoryPackSerializer.Deserialize<Subset>(spanBuffer.Slice((int)bufferView.Offset + subsetIndex * subsetSize));
                }
            }

            // Vertex data & layout metadata

            // Determine the number of unique Buffer Views associated with the vertex attributes & copy vertex buffers.
            var vbMap = new List<uint>();

            //mesh.LayoutDesc.pInputElementDescs = mesh.LayoutElems;
            //mesh.LayoutDesc.NumElements = 0;

            mesh.VertexStrides = new List<uint>();
            mesh.Vertices = new List<byte>();

            for (uint j = 0; j < Attribute.EType.Count.GetHashCode(); ++j)
            {
                if (meshView.Attributes[j] == 4294967295)
                    continue;

                ref Accessor accessor = ref accessors[meshView.Attributes[j]];

                if (vbMap.Contains(accessor.BufferView))
                    continue;

                // New buffer view encountered; add to list and copy vertex data
                vbMap.Add(accessor.BufferView);
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                Span<byte> verts = spanBuffer.Slice((int)bufferView.Offset, (int)bufferView.Size);//  MakeSpan(m_buffer.data() + bufferView.Offset, bufferView.Size);

                mesh.VertexStrides.Add(accessor.Stride);
                mesh.Vertices.AddRange(verts.ToArray());
                mesh.VertexCount = (uint)verts.Length / accessor.Stride;
            }


            // Populate the vertex buffer metadata from accessors.
            //for (uint32_t j = 0; j < Attribute::Count; ++j)
            //{
            //    if (meshView.Attributes[j] == -1)
            //        continue;

            //    Accessor & accessor = accessors[meshView.Attributes[j]];

            //    // Determine which vertex buffer index holds this attribute's data
            //    auto it = std::find(vbMap.begin(), vbMap.end(), accessor.BufferView);

            //    D3D12_INPUT_ELEMENT_DESC desc = c_elementDescs[j];
            //    desc.InputSlot = static_cast<uint32_t>(std::distance(vbMap.begin(), it));

            //    mesh.LayoutElems[mesh.LayoutDesc.NumElements++] = desc;
            //}


            // Meshlet data
            {
                ref Accessor accessor = ref accessors[meshView.Meshlets];
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                mesh.Meshlets = new Meshlet[accessor.Count];

                var meshletSize = Marshal.SizeOf(typeof(Meshlet));

                for (int meshletIndex = 0; meshletIndex < mesh.Meshlets.Length; meshletIndex++)
                {
                    mesh.Meshlets[meshletIndex] = MemoryPackSerializer.Deserialize<Meshlet>(spanBuffer.Slice((int)bufferView.Offset + meshletIndex * meshletSize));
                }
            }


            // Meshlet Subset data
            {
                ref Accessor accessor = ref accessors[meshView.MeshletSubsets];
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                mesh.MeshletSubsets = new Subset[accessor.Count];

                var subsetSize = Marshal.SizeOf(typeof(Subset));

                for (int subsetIndex = 0; subsetIndex < mesh.MeshletSubsets.Length; subsetIndex++)
                {
                    mesh.MeshletSubsets[subsetIndex] = MemoryPackSerializer.Deserialize<Subset>(spanBuffer.Slice((int)bufferView.Offset + subsetIndex * subsetSize));
                }
            }

            // Unique Vertex Index data
            {
                ref Accessor accessor = ref accessors[meshView.UniqueVertexIndices];
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                mesh.UniqueVertexIndices = spanBuffer.Slice((int)bufferView.Offset, (int)bufferView.Size).ToArray();// MakeSpan(m_buffer.data() + bufferView.Offset, bufferView.Size);
            }

            // Primitive Index data
            {
                ref Accessor accessor = ref accessors[meshView.PrimitiveIndices];
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                mesh.PrimitiveIndices = new PackedTriangle[accessor.Count];

                var packedTriangleSize = Marshal.SizeOf(typeof(PackedTriangle));

                for (int packedTriangleIndex = 0; packedTriangleIndex < mesh.PrimitiveIndices.Length; packedTriangleIndex++)
                {
                    mesh.PrimitiveIndices[packedTriangleIndex] = MemoryPackSerializer.Deserialize<PackedTriangle>(spanBuffer.Slice((int)bufferView.Offset + packedTriangleIndex * packedTriangleSize));
                }
            }

            // Cull data
            {
                ref Accessor accessor = ref accessors[meshView.CullData];
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                mesh.CullingData = new CullData[accessor.Count];

                for (int cullIndex = 0; cullIndex < mesh.CullingData.Length; cullIndex++)
                {
                    int offset = 0;

                    mesh.CullingData[cullIndex].NormalCone = new byte[4];

                    mesh.CullingData[cullIndex].BoundingSphere = MemoryPackSerializer.Deserialize<float4>(spanBuffer.Slice((int)bufferView.Offset, sizeof(float) * 4));

                    offset += sizeof(float) * 4;

                    mesh.CullingData[cullIndex].NormalCone = spanBuffer.Slice((int)bufferView.Offset + offset, 4).ToArray();

                    offset += 4;

                    mesh.CullingData[cullIndex].ApexOffset = MemoryPackSerializer.Deserialize<float>(spanBuffer.Slice((int)bufferView.Offset + offset, sizeof(float)));
                }
            }


            //// Build bounding spheres for each mesh
            //for (uint32_t i = 0; i < static_cast<uint32_t>(m_meshes.size()); ++i)
            //{
            //    auto & m = m_meshes[i];

            //    uint32_t vbIndexPos = 0;

            //    // Find the index of the vertex buffer of the position attribute
            //    for (uint32_t j = 1; j < m.LayoutDesc.NumElements; ++j)
            //    {
            //        auto & desc = m.LayoutElems[j];
            //        if (strcmp(desc.SemanticName, "POSITION") == 0)
            //        {
            //            vbIndexPos = j;
            //            break;
            //        }
            //    }

            //    // Find the byte offset of the position attribute with its vertex buffer
            //    uint32_t positionOffset = 0;

            //    for (uint32_t j = 0; j < m.LayoutDesc.NumElements; ++j)
            //    {
            //        auto & desc = m.LayoutElems[j];
            //        if (strcmp(desc.SemanticName, "POSITION") == 0)
            //        {
            //            break;
            //        }

            //        if (desc.InputSlot == vbIndexPos)
            //        {
            //            positionOffset += GetFormatSize(m.LayoutElems[j].Format);
            //        }
            //    }

            //    XMFLOAT3* v0 = reinterpret_cast<XMFLOAT3*>(m.Vertices[vbIndexPos].data() + positionOffset);
            //    uint32_t stride = m.VertexStrides[vbIndexPos];

            //    BoundingSphere::CreateFromPoints(m.BoundingSphere, m.VertexCount, v0, stride);

            //    if (i == 0)
            //    {
            //        m_boundingSphere = m.BoundingSphere;
            //    }
            //    else
            //    {
            //        BoundingSphere::CreateMerged(m_boundingSphere, m_boundingSphere, m.BoundingSphere);
            //    }
            //}
        }

        Debug.LogWarning("FileHeader : " + header.ToString());
    }

    struct FileHeader
    {
        public uint Prolog;
        public uint Version;

        public uint MeshCount;
        public uint AccessorCount;
        public uint BufferViewCount;
        public uint BufferSize;

        public override string ToString()
        {
            return "Prolog:" + Prolog + ", Version:" + Version + ", " + "MeshCount:" 
                + MeshCount + ", " + "AccessorCount:" + AccessorCount + ", " + "BufferViewCount:" + BufferViewCount + ", " + "BufferSize:" + BufferSize;
        }
    }

    struct MeshHeader
    {
        public uint Indices;
        public uint IndexSubsets;
        public uint[] Attributes;

        public uint Meshlets;
        public uint MeshletSubsets;
        public uint UniqueVertexIndices;
        public uint PrimitiveIndices;
        public uint CullData;
    };

    struct BufferView
    {
        public uint Offset;
        public uint Size;
    };

    struct Accessor
    {
        public uint BufferView;
        public uint Offset;
        public uint Size;
        public uint Stride;
        public uint Count;
    };


    struct Attribute
    {
        public enum EType : uint
        {
            Position,
            Normal,
            TexCoord,
            Tangent,
            Bitangent,
            Count
        };

        public EType Type;
        public uint Offset;
    };

    struct Subset
    {
        public uint Offset;
        public uint Count;
    };

    struct MeshInfo
    {
        public uint IndexSize;
        public uint MeshletCount;

        public uint LastMeshletVertCount;
        public uint LastMeshletPrimCount;
    };

    struct Meshlet
    {
        public uint VertCount;
        public uint VertOffset;
        public uint PrimCount;
        public uint PrimOffset;
    };

    struct PackedTriangle
    {
        public uint i0;
        public uint i1;
        public uint i2;
    };

    struct CullData
    {
        public float4 BoundingSphere; // xyz = center, w = radius
        public byte[] NormalCone;     // xyz = axis, w = -cos(a + 90)
        public float  ApexOffset;     // apex = center - axis * offset
    };

    struct Mesh
    {
        //D3D12_INPUT_ELEMENT_DESC   LayoutElems[Attribute::Count];
        //D3D12_INPUT_LAYOUT_DESC    LayoutDesc;

        public List<byte> Vertices;
        public List<uint> VertexStrides;
        public uint VertexCount;
        //DirectX::BoundingSphere    BoundingSphere;


        public Subset[] IndexSubsets;
        public byte[] Indices;
        public uint IndexSize;
        public uint IndexCount;

        public Subset[] MeshletSubsets;
        public Meshlet[] Meshlets;
        public byte[] UniqueVertexIndices;
        public PackedTriangle[] PrimitiveIndices;
        public CullData[] CullingData;

        //// D3D resource references
        //std::vector<D3D12_VERTEX_BUFFER_VIEW>  VBViews;
        //D3D12_INDEX_BUFFER_VIEW                IBView;

        //std::vector<Microsoft::WRL::ComPtr<ID3D12Resource>> VertexResources;
        //Microsoft::WRL::ComPtr<ID3D12Resource>              IndexResource;
        //Microsoft::WRL::ComPtr<ID3D12Resource>              MeshletResource;
        //Microsoft::WRL::ComPtr<ID3D12Resource>              UniqueVertexIndexResource;
        //Microsoft::WRL::ComPtr<ID3D12Resource>              PrimitiveIndexResource;
        //Microsoft::WRL::ComPtr<ID3D12Resource>              CullDataResource;
        //Microsoft::WRL::ComPtr<ID3D12Resource>              MeshInfoResource;

        //// Calculates the number of instances of the last meshlet which can be packed into a single threadgroup.
        //uint32_t GetLastMeshletPackCount(uint32_t subsetIndex, uint32_t maxGroupVerts, uint32_t maxGroupPrims) 
        //{ 
        //    if (Meshlets.size() == 0)
        //        return 0;

        //    auto& subset = MeshletSubsets[subsetIndex];
        //    auto& meshlet = Meshlets[subset.Offset + subset.Count - 1];

        //    return min(maxGroupVerts / meshlet.VertCount, maxGroupPrims / meshlet.PrimCount);
        //}

        //void GetPrimitive(uint32_t index, uint32_t& i0, uint32_t& i1, uint32_t& i2) const
        //{
        //    auto prim = PrimitiveIndices[index];
        //    i0 = prim.i0;
        //    i1 = prim.i1;
        //    i2 = prim.i2;
        //}

        //uint32_t GetVertexIndex(uint32_t index) const
        //{
        //    const uint8_t* addr = UniqueVertexIndices.data() + index * IndexSize;
        //    if (IndexSize == 4)
        //    {
        //        return *reinterpret_cast<const uint32_t*>(addr);
        //    }
        //    else 
        //    {
        //        return *reinterpret_cast<const uint16_t*>(addr);
        //    }
        //}
    }
}
