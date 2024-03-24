using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{

    public sealed partial class ZUniversalRenderPipeline : ZRenderPipeline
    {
     
        /// <summary>
        /// Returns the current render pipeline asset for the current quality setting.
        /// If no render pipeline asset is assigned in QualitySettings, then returns the one assigned in GraphicsSettings.
        /// </summary>
        public static ZUniversalRenderPipelineAsset asset
        {
            get => GraphicsSettings.currentRenderPipeline as ZUniversalRenderPipelineAsset;
        }

        private ZUniversalRenderPipelineAsset m_PipelineAsset;

        public ZUniversalRenderPipeline(ZUniversalRenderPipelineAsset asset)
        {
            m_PipelineAsset = asset;
        }

        protected override void Render(ScriptableRenderContext context, Camera[] cameras)
        {
            if (m_PipelineAsset != asset)
                throw new System.Exception("error.");

            for (int i = 0; i < cameras.Length; i++)
            {
                var renderer = asset.GetRenderer(0) as ZUniversalRenderer;
                renderer.CameraRendering(context, cameras[i]);
            }
        }

        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
        }
    }

    public static class ZRenderPipelineExt
    {
        public static void ExecuteAndClear(this ScriptableRenderContext @this, CommandBuffer cmd)
        {
            @this.ExecuteCommandBuffer(cmd);

            cmd.Clear();
        }

        public static float ComputeLuminance(this Color color)
        {
            return ColorUtils.Luminance(color);
        }

    }
}

