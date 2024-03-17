using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.ZRendering.NPR
{

    public sealed partial class ZNPRRenderPipeline : ZRenderPipeline
    {
     
        /// <summary>
        /// Returns the current render pipeline asset for the current quality setting.
        /// If no render pipeline asset is assigned in QualitySettings, then returns the one assigned in GraphicsSettings.
        /// </summary>
        public static ZNPRRenderPipelineAsset asset
        {
            get => GraphicsSettings.currentRenderPipeline as ZNPRRenderPipelineAsset;
        }

        public ZNPRRenderPipeline(ZNPRRenderPipelineAsset asset)
        {
            //asset.scriptableRendererData.rendererFeatures
        }

        protected override void Render(ScriptableRenderContext context, Camera[] cameras)
        {

        }

        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
        }
    }
}

