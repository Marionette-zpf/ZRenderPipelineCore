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

        public ZUniversalRenderPipeline(ZUniversalRenderPipelineAsset asset)
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

