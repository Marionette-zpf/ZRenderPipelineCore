namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public abstract class ZDrawObjectsPass : ZScriptableRendererPass
    {
       
        protected abstract bool m_IsTransparent { get; }

        protected ShaderTagId[] m_LegacyShaderTagIds;

        protected DrawingSettings m_DreawingSettings;
        protected FilteringSettings m_FilteringSettings;

        public override void Create()
        {
            m_DreawingSettings = new DrawingSettings();
            m_FilteringSettings = new FilteringSettings(m_IsTransparent ? RenderQueueRange.transparent : RenderQueueRange.opaque);

            m_LegacyShaderTagIds = new ShaderTagId[]
            {
                new ShaderTagId("Always"),
                new ShaderTagId("ForwardBase"),
                new ShaderTagId("PrepassBase"),
                new ShaderTagId("Vertex"),
                new ShaderTagId("VertexLMRGBM"),
                new ShaderTagId("VertexLM")
            };


            for (int i = 0; i < m_LegacyShaderTagIds.Length; i++)
            {
                m_DreawingSettings.SetShaderPassName(i, m_LegacyShaderTagIds[i]);
            }
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
#if UNITY_EDITOR
            // refresh to frame debug.
            context.ExecuteAndClear(cmd);
#endif

            var sortingSettings = new SortingSettings(renderingData.camera)
            {
                criteria = m_IsTransparent ? SortingCriteria.CommonTransparent : SortingCriteria.CommonOpaque
            };

            m_DreawingSettings.sortingSettings = sortingSettings;

            context.DrawRenderers(
                renderingData.cullingResults, ref m_DreawingSettings, ref m_FilteringSettings
            );
        }
    }

}

