using System.Collections;
using System.Collections.Generic;
using UnityEngine;


namespace UnityEngine.Rendering.ZUniversal
{
    public class ZToonTools : MonoBehaviour
    {

        public Mesh SmoothNormalToTangentMesh;

        [ContextMenu("平滑法线")]
        public void WriteSmoothNormalToTangent()
        {
            ModifyMeshTangents(SmoothNormalToTangentMesh);
        }

        /// <summary>
        /// 平滑法线，即是求出一个顶点 所在的所有三角面的法线的平均值
        /// </summary>
        /// <param name="mesh"></param>
        private void WriteSmoothNormalToTangent(Mesh mesh)
        {
            Dictionary<Vector3, Vector3> vertexNormalDic = new Dictionary<Vector3, Vector3>();
            for (int i = 0; i < mesh.vertexCount; i++)
            {
                if (!vertexNormalDic.ContainsKey(mesh.vertices[i]))
                {
                    vertexNormalDic.Add(mesh.vertices[i], mesh.normals[i]);
                }
                else
                {
                    vertexNormalDic[mesh.vertices[i]] += mesh.normals[i];
                }
            }

            Vector4[] tangents = null;
            bool hasTangent = mesh.colors.Length == mesh.vertexCount;
            if (hasTangent)
            {
                tangents = mesh.tangents;
            }
            else
            {
                tangents = new Vector4[mesh.vertexCount];
            }

            for (int i = 0; i < mesh.vertexCount; i++)
            {
                Vector3 averageNormal = vertexNormalDic[mesh.vertices[i]].normalized;
                tangents[i] = new Vector4(averageNormal.x, averageNormal.y, averageNormal.z, 0f);//如果写入到顶点色需要将值映射到[0,1]，再在Shader中重新映射到[-1,1]
            }
            mesh.tangents = tangents;
        }

        private static void ModifyMeshTangents(Mesh mesh)
        {

            var vertices = mesh.vertices;
            var triangles = mesh.triangles;
            var unmerged = new Vector3[mesh.vertexCount];
            var merged = new Dictionary<Vector3, Vector3>(); // Use a dictionary to map vertices to their merged normals
            var tangents = new Vector4[mesh.vertexCount];

            for (int i = 0; i < triangles.Length; i += 3)
            {
                var i0 = triangles[i + 0];
                var i1 = triangles[i + 1];
                var i2 = triangles[i + 2];

                var v0 = vertices[i0] * 100;
                var v1 = vertices[i1] * 100;
                var v2 = vertices[i2] * 100;

                var normal_ = Vector3.Cross(v1 - v0, v2 - v0).normalized;

                unmerged[i0] += normal_ * Vector3.Angle(v1 - v0, v2 - v0);
                unmerged[i1] += normal_ * Vector3.Angle(v0 - v1, v2 - v1);
                unmerged[i2] += normal_ * Vector3.Angle(v0 - v2, v1 - v2);
            }

            for (int i = 0; i < vertices.Length; i++)
            {
                if (!merged.ContainsKey(vertices[i]))
                {
                    merged[vertices[i]] = unmerged[i];
                }
                else
                {
                    merged[vertices[i]] += unmerged[i];
                }
            }

            for (int i = 0; i < vertices.Length; i++)
            {
                var normal = merged[vertices[i]].normalized;
                tangents[i] = new Vector4(normal.x, normal.y, normal.z, 0);
            }

            mesh.tangents = tangents;
        }
    }

}

