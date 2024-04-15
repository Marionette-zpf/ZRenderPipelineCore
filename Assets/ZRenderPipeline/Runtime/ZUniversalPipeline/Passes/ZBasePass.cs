namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZBasePass : ZScriptableRendererPass 
    {
        protected DrawingSettings m_DreawingSettings;
        protected FilteringSettings m_FilteringSettings;

        public override void Create()
        {
            m_DreawingSettings = new DrawingSettings();
            m_DreawingSettings.SetShaderPassName(0, new ShaderTagId("ZUniversal"));

            m_FilteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            var targetPass = ZUniversalRenderer.Instance.GetRendererPass<ZRenderingTargetPass>();

            cmd.SetRenderTarget(targetPass.BasePassTargets, targetPass.CameraDepthTarget);
            cmd.ClearRenderTarget(true, true, Color.clear);

            targetPass.SetCurrentActiveColorDepthTarget(targetPass.CameraColorTarget, targetPass.CameraDepthTarget);

#if UNITY_EDITOR
            // refresh to frame debug.
            context.ExecuteAndClear(cmd);
#endif

            var sortingSettings = new SortingSettings(renderingData.camera)
            {
                criteria = SortingCriteria.CommonOpaque
            };

            m_DreawingSettings.sortingSettings = sortingSettings;

            context.DrawRenderers(
                renderingData.cullingResults, ref m_DreawingSettings, ref m_FilteringSettings
            );
        }
    }


}

