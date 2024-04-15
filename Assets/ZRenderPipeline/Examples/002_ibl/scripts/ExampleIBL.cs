using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

public class ExampleIBL : MonoBehaviour
{
    public Cubemap cub; 

    [ContextMenu("´´½¨CubeMap")]
    public void CreateCubeMap()
    {
        Debug.LogError(cub.name);

        //var newCubemap  = new Cubemap(128, TextureFormat.ARGB32, false);
        //AssetDatabase.CreateAsset(newCubemap, "Assets/ZRenderPipeline/Examples/002_ibl/NewCubemap.cubemap");
    }
}
