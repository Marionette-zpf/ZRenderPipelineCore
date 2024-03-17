namespace UnityEngine.Rendering.ZPipeline
{


    /// <summary>
    /// The default color buffer format in HDR (only).
    /// Affects camera rendering and postprocessing color buffers.
    /// </summary>
    public enum ZHDRColorBufferPrecision
    {
        /// <summary> Typically R11G11B10f for faster rendering. Recommend for mobile.
        /// R11G11B10f can cause a subtle blue/yellow banding in some rare cases due to lower precision of the blue component.</summary>
        [Tooltip("Use 32-bits per pixel for HDR rendering.")]
        _32Bits,
        /// <summary>Typically R16G16B16A16f for better quality. Can reduce banding at the cost of memory and performance.</summary>
        [Tooltip("Use 64-bits per pixel for HDR rendering.")]
        _64Bits,
    }

    /// <summary>
    /// Softness quality of soft shadows. Higher means better quality, but lower performance.
    /// </summary>
    public enum ZSoftShadowQuality
    {
        /// <summary>
        /// Use this to choose the setting set on the pipeline asset.
        /// </summary>
        [InspectorName("Use settings from Render Pipeline Asset")]
        UsePipelineSettings,

        /// <summary>
        /// Low quality soft shadows. Recommended for mobile. 4 PCF sample filtering.
        /// </summary>
        Low,
        /// <summary>
        /// Medium quality soft shadows. The default. 5x5 tent filtering.
        /// </summary>
        Medium,
        /// <summary>
        /// High quality soft shadows. Low performance due to high sample count. 7x7 tent filtering.
        /// </summary>
        High,
    }


    internal enum ZDefaultMaterialType
    {
        Standard,
        Particle,
        Terrain,
        Sprite,
        UnityBuiltinDefault,
        SpriteMask,
        Decal
    }

    //[CreateAssetMenu(menuName = "Rendering/ZRender Pipeline")]
    //public class ZRenderPipelineAsset : RenderPipelineAsset
    //{
    //    protected override RenderPipeline CreatePipeline()
    //    {
    //        return new ZRenderPipeline();
    //    }
    //}

}

