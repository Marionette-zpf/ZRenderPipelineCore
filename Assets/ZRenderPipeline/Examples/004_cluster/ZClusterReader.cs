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
    private ClusterMesh[] m_meshes;

    private BoundingSphere m_boundingSphere;

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

        m_meshes = new ClusterMesh[meshes.Length];


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

            mesh.LayoutDesc.pInputElementDescs = mesh.LayoutElems;
            mesh.LayoutDesc.NumElements = 0;

            mesh.VertexStrides = new List<uint>();
            mesh.Vertices = new List<byte[]>();

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
                mesh.Vertices.Add(verts.ToArray());
                mesh.VertexCount = (uint)verts.Length / accessor.Stride;
            }


            // Populate the vertex buffer metadata from accessors.

            mesh.LayoutElems = new D3D12_INPUT_ELEMENT_DESC[Attribute.EType.Count.GetHashCode()];

            for (uint j = 0; j < Attribute.EType.Count.GetHashCode(); ++j)
            {
                if (meshView.Attributes[j] == 4294967295)
                    continue;

                Accessor accessor = accessors[meshView.Attributes[j]];


                // Determine which vertex buffer index holds this attribute's data
                var it = vbMap.Find(x => x == accessor.BufferView);

                D3D12_INPUT_ELEMENT_DESC desc = c_elementDescs[j];
                desc.InputSlot = it;

                mesh.LayoutElems[mesh.LayoutDesc.NumElements++] = desc;
            }


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

                var packedTriangleSize = 4;// Marshal.SizeOf(typeof(PackedTriangle));

                for (int packedTriangleIndex = 0; packedTriangleIndex < mesh.PrimitiveIndices.Length; packedTriangleIndex++)
                {
                    mesh.PrimitiveIndices[packedTriangleIndex] = ConvertBytesToPackedTriangle(spanBuffer.Slice((int)bufferView.Offset + packedTriangleIndex * packedTriangleSize, 4));
                }
            }

            // Cull data
            {
                ref Accessor accessor = ref accessors[meshView.CullData];
                ref BufferView bufferView = ref bufferViews[accessor.BufferView];

                mesh.CullingData = new CullData[accessor.Count];

                int cullDataSize = sizeof(float) * 4 + 4 + sizeof(float);

                for (int cullIndex = 0; cullIndex < mesh.CullingData.Length; cullIndex++)
                {
                    int offset = 0;
                    int bufferOffset = (int)bufferView.Offset + cullDataSize * cullIndex;

                    mesh.CullingData[cullIndex].NormalCone = new byte[4];

                    mesh.CullingData[cullIndex].BoundingSphere = MemoryPackSerializer.Deserialize<float4>(spanBuffer.Slice(bufferOffset, sizeof(float) * 4));

                    offset += sizeof(float) * 4;

                    mesh.CullingData[cullIndex].NormalCone = spanBuffer.Slice(bufferOffset + offset, 4).ToArray();

                    offset += 4;

                    mesh.CullingData[cullIndex].ApexOffset = MemoryPackSerializer.Deserialize<float>(spanBuffer.Slice(bufferOffset + offset, sizeof(float)));
                }
            }
        }

        // Build bounding spheres for each mesh
        for (uint i = 0; i < m_meshes.Length; ++i)
        {
            ref var m = ref m_meshes[i];

            uint vbIndexPos = 0;

            // Find the index of the vertex buffer of the position attribute
            for (uint j = 1; j < m.LayoutDesc.NumElements; ++j)
            {
                ref var desc = ref m.LayoutElems[j];
                if (string.Equals(desc.SemanticName, "POSITION"))
                {
                    vbIndexPos = j;
                    break;
                }
            }

            // Find the byte offset of the position attribute with its vertex buffer
            uint positionOffset = 0;

            for (uint j = 0; j < m.LayoutDesc.NumElements; ++j)
            {
                ref var desc = ref m.LayoutElems[j];
                if (string.Equals(desc.SemanticName, "POSITION"))
                {
                    break;
                }

                if (desc.InputSlot == vbIndexPos)
                {
                    positionOffset += GetFormatSize(m.LayoutElems[j].Format);
                }
            }

            float3[] v0 = new float3[m.VertexCount];
            Span<byte> spanVertex = new Span<byte>(m.Vertices[(int)vbIndexPos]);
            int float3Size = Marshal.SizeOf(typeof(float3));
            uint stride = m.VertexStrides[(int)vbIndexPos];

            for (int vertexIndex = 0; vertexIndex < v0.Length; vertexIndex++)
            {
                v0[vertexIndex] = MemoryPackSerializer.Deserialize<float3>(spanVertex.Slice((int)positionOffset + vertexIndex * (int)stride, float3Size));
            }
                

            BoundingSphere.CreateFromPoints(ref m.BoundingSphere, m.VertexCount, v0, stride);

            if (i == 0)
            {
                m_boundingSphere = m.BoundingSphere;
            }
            else
            {
                BoundingSphere.CreateMerged(ref m_boundingSphere, ref m_boundingSphere, ref m.BoundingSphere);
            }
        }

        Debug.LogWarning("FileHeader : " + header.ToString());
    }

    private PackedTriangle ConvertBytesToPackedTriangle(ReadOnlySpan<byte> bytes)
    {
        PackedTriangle triangle = new PackedTriangle();

        int value = BitConverter.ToInt32(bytes);

        triangle.i0 = (uint)(value & 0x3FF); 
        triangle.i1 = (uint)((value >> 10) & 0x3FF);
        triangle.i2 = (uint)((value >> 20) & 0x3FF);

        return triangle;
    }

    private uint GetFormatSize(DXGI_FORMAT format)
    {
        switch (format)
        {
            case DXGI_FORMAT.DXGI_FORMAT_R32G32B32A32_FLOAT : return 16;
            case DXGI_FORMAT.DXGI_FORMAT_R32G32B32_FLOAT    : return 12;
            case DXGI_FORMAT.DXGI_FORMAT_R32G32_FLOAT       : return 8;
            case DXGI_FORMAT.DXGI_FORMAT_R32_FLOAT          : return 4;
            default: throw new Exception("Unimplemented type");
        }
    }

    static D3D12_INPUT_ELEMENT_DESC[] c_elementDescs =
    {
        new D3D12_INPUT_ELEMENT_DESC { SemanticName = "POSITION",  SemanticIndex = 0, Format = DXGI_FORMAT.DXGI_FORMAT_R32G32B32_FLOAT, InputSlot = 0, AlignedByteOffset = 0xffffffff, InstanceDataStepRate = 1 },
        new D3D12_INPUT_ELEMENT_DESC { SemanticName = "NORMAL",    SemanticIndex = 0, Format = DXGI_FORMAT.DXGI_FORMAT_R32G32B32_FLOAT, InputSlot = 0, AlignedByteOffset = 0xffffffff, InstanceDataStepRate = 1 },
        new D3D12_INPUT_ELEMENT_DESC { SemanticName = "TEXCOORD",  SemanticIndex = 0, Format = DXGI_FORMAT.DXGI_FORMAT_R32G32_FLOAT,    InputSlot = 0, AlignedByteOffset = 0xffffffff, InstanceDataStepRate = 1 },
        new D3D12_INPUT_ELEMENT_DESC { SemanticName = "TANGENT",   SemanticIndex = 0, Format = DXGI_FORMAT.DXGI_FORMAT_R32G32B32_FLOAT, InputSlot = 0, AlignedByteOffset = 0xffffffff, InstanceDataStepRate = 1 },
        new D3D12_INPUT_ELEMENT_DESC { SemanticName = "BITANGENT", SemanticIndex = 0, Format = DXGI_FORMAT.DXGI_FORMAT_R32G32B32_FLOAT, InputSlot = 0, AlignedByteOffset = 0xffffffff, InstanceDataStepRate = 1 }
    };

    struct D3D12_INPUT_ELEMENT_DESC
    {
        public string SemanticName;
        public uint SemanticIndex;
        public DXGI_FORMAT Format;
        public uint InputSlot;
        public uint AlignedByteOffset;
        //D3D12_INPUT_CLASSIFICATION InputSlotClass;
        public uint InstanceDataStepRate;
    };

    struct D3D12_INPUT_LAYOUT_DESC
    {
        public D3D12_INPUT_ELEMENT_DESC[] pInputElementDescs;
        public uint NumElements;
    };

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

    struct BoundingSphere
    {
        public float3 Center;          // Center of the sphere.
        public float Radius;           // Radius of the sphere.

        public static void CreateFromPoints(ref BoundingSphere Out, uint Count, float3[] pPoints, uint Stride)
        {
            //assert(Count > 0);
            //assert(pPoints);

            if (Count <= 0 || pPoints == null)
                throw new Exception("error");

            // Find the points with minimum and maximum x, y, and z
            float3 MinX, MaxX, MinY, MaxY, MinZ, MaxZ;

            MinX = MaxX = MinY = MaxY = MinZ = MaxZ = pPoints[0]; // XMLoadFloat3(pPoints);

            for (int i = 1; i < Count; ++i)
            {
                float3 Point = pPoints[i];// XMLoadFloat3(reinterpret_cast <const XMFLOAT3*> (reinterpret_cast <const uint8_t*> (pPoints) + i * Stride));

                float px = Point.x;
                float py = Point.y;
                float pz = Point.z;

                if (px < MinX.x)
                    MinX = Point;

                if (px > MaxX.x)
                    MaxX = Point;

                if (py < MinY.y)
                    MinY = Point;

                if (py > MaxY.y)
                    MaxY = Point;

                if (pz < MinZ.z)
                    MinZ = Point;

                if (pz > MaxZ.z)
                    MaxZ = Point;
            }

            // Use the min/max pair that are farthest apart to form the initial sphere.
            float3 DeltaX = MaxX - MinX; // XMVectorSubtract(MaxX, MinX);
            float DistX = math.length(DeltaX); //  XMVector3Length(DeltaX);

            float3 DeltaY = MaxY - MinY;// XMVectorSubtract(MaxY, MinY);
            float DistY = math.length(DeltaY); //XMVector3Length(DeltaY);

            float3 DeltaZ = MaxZ - MinZ;// XMVectorSubtract(MaxZ, MinZ);
            float DistZ = math.length(DeltaZ); //XMVector3Length(DeltaZ);

            float3 vCenter;
            float vRadius;

            if (DistX > DistY)
            {
                if (DistX > DistZ)
                {
                    // Use min/max x.
                    vCenter = math.lerp(MaxX, MinX, 0.5f);// XMVectorLerp(MaxX, MinX, 0.5f);
                    vRadius = DistX * 0.5f;// XMVectorScale(DistX, 0.5f);
                }
                else
                {
                    // Use min/max z.
                    vCenter = math.lerp(MaxZ, MinZ, 0.5f);//XMVectorLerp(MaxZ, MinZ, 0.5f);
                    vRadius = DistZ * 0.5f;//XMVectorScale(DistZ, 0.5f);
                }
            }
            else // Y >= X
            {
                if (DistY > DistZ)
                {
                    // Use min/max y.
                    vCenter = math.lerp(MaxY, MinY, 0.5f);//XMVectorLerp(MaxY, MinY, 0.5f);
                    vRadius = DistY * 0.5f;//XMVectorScale(DistY, 0.5f);
                }
                else
                {
                    // Use min/max z.
                    vCenter = math.lerp(MaxZ, MinZ, 0.5f);//XMVectorLerp(MaxZ, MinZ, 0.5f);
                    vRadius = DistZ * 0.5f;//XMVectorScale(DistZ, 0.5f);
                }
            }

            // Add any points not inside the sphere.
            for (int i = 0; i < Count; ++i)
            {
                float3 Point = pPoints[i] ;// XMLoadFloat3(reinterpret_cast <const XMFLOAT3*> (reinterpret_cast <const uint8_t*> (pPoints) + i * Stride));

                float3 Delta = Point - vCenter;// XMVectorSubtract(Point, vCenter);

                float Dist = math.length(Delta); //XMVector3Length(Delta);

                if (Dist > vRadius)
                {
                    // Adjust sphere to include the new point.
                    vRadius = (vRadius + Dist) * 0.5f;// XMVectorScale(XMVectorAdd(vRadius, Dist), 0.5f);
                    vCenter = vCenter + (1.0f - vRadius / Dist) * Delta; // XMVectorAdd(vCenter, XMVectorMultiply(XMVectorSubtract(XMVectorReplicate(1.0f), XMVectorDivide(vRadius, Dist)), Delta));
                }
            }

            Out.Center = vCenter;
            Out.Radius = vRadius;
            //XMStoreFloat3(&Out.Center, vCenter);
            //XMStoreFloat(&Out.Radius, vRadius);
        }

        //-----------------------------------------------------------------------------
        // Creates a bounding sphere that contains two other bounding spheres
        //-----------------------------------------------------------------------------
        public static void CreateMerged(ref BoundingSphere Out, ref BoundingSphere S1, ref BoundingSphere S2)
        {
            float3 Center1 = S1.Center;
            float r1 = S1.Radius;

            float3 Center2 = S2.Center;
            float r2 = S2.Radius;

            float3 V = Center2 - Center1;

            float Dist = math.length(V);

            float d = Dist;

            if (r1 + r2 >= d)
            {
                if (r1 - r2 >= d)
                {
                    Out = S1;
                    return;
                }
                else if (r2 - r1 >= d)
                {
                    Out = S2;
                    return;
                }
            }

            float3 N = V / Dist;// XMVectorDivide(V, Dist);

            float t1 = math.min(-r1, d - r2); // XMMin(-r1, d - r2);
            float t2 = math.max( r1, d + r2);  // XMMax(r1, d + r2);
            float t_5 = (t2 - t1) * 0.5f;

            float3 NCenter = Center1 + (N * (t_5 + t1));// //XMVectorAdd(Center1, XMVectorMultiply(N, XMVectorReplicate(t_5 + t1)));

            //XMStoreFloat3(&Out.Center, NCenter);
            Out.Center = NCenter;
            Out.Radius = t_5;
        }
    }

    struct ClusterMesh
    {
        public D3D12_INPUT_ELEMENT_DESC[] LayoutElems;
        public D3D12_INPUT_LAYOUT_DESC LayoutDesc;

        public List<byte[]> Vertices;
        public List<uint> VertexStrides;
        public uint VertexCount;
        public BoundingSphere BoundingSphere;


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

    enum DXGI_FORMAT : uint
    {
        DXGI_FORMAT_UNKNOWN = 0,
        DXGI_FORMAT_R32G32B32A32_TYPELESS = 1,
        DXGI_FORMAT_R32G32B32A32_FLOAT = 2,
        DXGI_FORMAT_R32G32B32A32_UINT = 3,
        DXGI_FORMAT_R32G32B32A32_SINT = 4,
        DXGI_FORMAT_R32G32B32_TYPELESS = 5,
        DXGI_FORMAT_R32G32B32_FLOAT = 6,
        DXGI_FORMAT_R32G32B32_UINT = 7,
        DXGI_FORMAT_R32G32B32_SINT = 8,
        DXGI_FORMAT_R16G16B16A16_TYPELESS = 9,
        DXGI_FORMAT_R16G16B16A16_FLOAT = 10,
        DXGI_FORMAT_R16G16B16A16_UNORM = 11,
        DXGI_FORMAT_R16G16B16A16_UINT = 12,
        DXGI_FORMAT_R16G16B16A16_SNORM = 13,
        DXGI_FORMAT_R16G16B16A16_SINT = 14,
        DXGI_FORMAT_R32G32_TYPELESS = 15,
        DXGI_FORMAT_R32G32_FLOAT = 16,
        DXGI_FORMAT_R32G32_UINT = 17,
        DXGI_FORMAT_R32G32_SINT = 18,
        DXGI_FORMAT_R32G8X24_TYPELESS = 19,
        DXGI_FORMAT_D32_FLOAT_S8X24_UINT = 20,
        DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS = 21,
        DXGI_FORMAT_X32_TYPELESS_G8X24_UINT = 22,
        DXGI_FORMAT_R10G10B10A2_TYPELESS = 23,
        DXGI_FORMAT_R10G10B10A2_UNORM = 24,
        DXGI_FORMAT_R10G10B10A2_UINT = 25,
        DXGI_FORMAT_R11G11B10_FLOAT = 26,
        DXGI_FORMAT_R8G8B8A8_TYPELESS = 27,
        DXGI_FORMAT_R8G8B8A8_UNORM = 28,
        DXGI_FORMAT_R8G8B8A8_UNORM_SRGB = 29,
        DXGI_FORMAT_R8G8B8A8_UINT = 30,
        DXGI_FORMAT_R8G8B8A8_SNORM = 31,
        DXGI_FORMAT_R8G8B8A8_SINT = 32,
        DXGI_FORMAT_R16G16_TYPELESS = 33,
        DXGI_FORMAT_R16G16_FLOAT = 34,
        DXGI_FORMAT_R16G16_UNORM = 35,
        DXGI_FORMAT_R16G16_UINT = 36,
        DXGI_FORMAT_R16G16_SNORM = 37,
        DXGI_FORMAT_R16G16_SINT = 38,
        DXGI_FORMAT_R32_TYPELESS = 39,
        DXGI_FORMAT_D32_FLOAT = 40,
        DXGI_FORMAT_R32_FLOAT = 41,
        DXGI_FORMAT_R32_UINT = 42,
        DXGI_FORMAT_R32_SINT = 43,
        DXGI_FORMAT_R24G8_TYPELESS = 44,
        DXGI_FORMAT_D24_UNORM_S8_UINT = 45,
        DXGI_FORMAT_R24_UNORM_X8_TYPELESS = 46,
        DXGI_FORMAT_X24_TYPELESS_G8_UINT = 47,
        DXGI_FORMAT_R8G8_TYPELESS = 48,
        DXGI_FORMAT_R8G8_UNORM = 49,
        DXGI_FORMAT_R8G8_UINT = 50,
        DXGI_FORMAT_R8G8_SNORM = 51,
        DXGI_FORMAT_R8G8_SINT = 52,
        DXGI_FORMAT_R16_TYPELESS = 53,
        DXGI_FORMAT_R16_FLOAT = 54,
        DXGI_FORMAT_D16_UNORM = 55,
        DXGI_FORMAT_R16_UNORM = 56,
        DXGI_FORMAT_R16_UINT = 57,
        DXGI_FORMAT_R16_SNORM = 58,
        DXGI_FORMAT_R16_SINT = 59,
        DXGI_FORMAT_R8_TYPELESS = 60,
        DXGI_FORMAT_R8_UNORM = 61,
        DXGI_FORMAT_R8_UINT = 62,
        DXGI_FORMAT_R8_SNORM = 63,
        DXGI_FORMAT_R8_SINT = 64,
        DXGI_FORMAT_A8_UNORM = 65,
        DXGI_FORMAT_R1_UNORM = 66,
        DXGI_FORMAT_R9G9B9E5_SHAREDEXP = 67,
        DXGI_FORMAT_R8G8_B8G8_UNORM = 68,
        DXGI_FORMAT_G8R8_G8B8_UNORM = 69,
        DXGI_FORMAT_BC1_TYPELESS = 70,
        DXGI_FORMAT_BC1_UNORM = 71,
        DXGI_FORMAT_BC1_UNORM_SRGB = 72,
        DXGI_FORMAT_BC2_TYPELESS = 73,
        DXGI_FORMAT_BC2_UNORM = 74,
        DXGI_FORMAT_BC2_UNORM_SRGB = 75,
        DXGI_FORMAT_BC3_TYPELESS = 76,
        DXGI_FORMAT_BC3_UNORM = 77,
        DXGI_FORMAT_BC3_UNORM_SRGB = 78,
        DXGI_FORMAT_BC4_TYPELESS = 79,
        DXGI_FORMAT_BC4_UNORM = 80,
        DXGI_FORMAT_BC4_SNORM = 81,
        DXGI_FORMAT_BC5_TYPELESS = 82,
        DXGI_FORMAT_BC5_UNORM = 83,
        DXGI_FORMAT_BC5_SNORM = 84,
        DXGI_FORMAT_B5G6R5_UNORM = 85,
        DXGI_FORMAT_B5G5R5A1_UNORM = 86,
        DXGI_FORMAT_B8G8R8A8_UNORM = 87,
        DXGI_FORMAT_B8G8R8X8_UNORM = 88,
        DXGI_FORMAT_R10G10B10_XR_BIAS_A2_UNORM = 89,
        DXGI_FORMAT_B8G8R8A8_TYPELESS = 90,
        DXGI_FORMAT_B8G8R8A8_UNORM_SRGB = 91,
        DXGI_FORMAT_B8G8R8X8_TYPELESS = 92,
        DXGI_FORMAT_B8G8R8X8_UNORM_SRGB = 93,
        DXGI_FORMAT_BC6H_TYPELESS = 94,
        DXGI_FORMAT_BC6H_UF16 = 95,
        DXGI_FORMAT_BC6H_SF16 = 96,
        DXGI_FORMAT_BC7_TYPELESS = 97,
        DXGI_FORMAT_BC7_UNORM = 98,
        DXGI_FORMAT_BC7_UNORM_SRGB = 99,
        DXGI_FORMAT_AYUV = 100,
        DXGI_FORMAT_Y410 = 101,
        DXGI_FORMAT_Y416 = 102,
        DXGI_FORMAT_NV12 = 103,
        DXGI_FORMAT_P010 = 104,
        DXGI_FORMAT_P016 = 105,
        DXGI_FORMAT_420_OPAQUE = 106,
        DXGI_FORMAT_YUY2 = 107,
        DXGI_FORMAT_Y210 = 108,
        DXGI_FORMAT_Y216 = 109,
        DXGI_FORMAT_NV11 = 110,
        DXGI_FORMAT_AI44 = 111,
        DXGI_FORMAT_IA44 = 112,
        DXGI_FORMAT_P8 = 113,
        DXGI_FORMAT_A8P8 = 114,
        DXGI_FORMAT_B4G4R4A4_UNORM = 115,

        DXGI_FORMAT_P208 = 130,
        DXGI_FORMAT_V208 = 131,
        DXGI_FORMAT_V408 = 132,


        DXGI_FORMAT_SAMPLER_FEEDBACK_MIN_MIP_OPAQUE = 189,
        DXGI_FORMAT_SAMPLER_FEEDBACK_MIP_REGION_USED_OPAQUE = 190,


        DXGI_FORMAT_FORCE_UINT = 0xffffffff
    };
}
