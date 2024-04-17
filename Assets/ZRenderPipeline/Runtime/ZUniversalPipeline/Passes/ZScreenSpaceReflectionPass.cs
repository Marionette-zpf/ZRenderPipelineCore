namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZScreenSpaceReflectionPass : ZScriptableRendererPass
    {

        private Material m_SSRMat;

        private ZRenderTargetHandle m_SSRRenderTextureHandle;

        public override void Create()
        {
            m_SSRMat = CoreUtils.CreateEngineMaterial(Shader.Find("ZPipeline/ZUniversal/PPS/SSR"));
            m_SSRRenderTextureHandle = new ZRenderTargetHandle("_SSRRenderTexture");
        }

        public override void SetupRendererPass(CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            var desc = renderingData.cameraColorDesc;

            cmd.GetTemporaryRT(m_SSRRenderTextureHandle.GetID(), desc);
            m_SSRRenderTextureHandle.SetSize(desc.width, desc.height);
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            cmd.SetGlobalVector(ZUniversalShaderContents.V_BufferSizeAndInvSize, m_SSRRenderTextureHandle.GetBufferSizeAndInverse());

            cmd.SetRenderTarget(m_SSRRenderTextureHandle.GetIdentifier(), RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            cmd.Blit(-1, BuiltinRenderTextureType.CurrentActive, m_SSRMat);
        }

        public override void OnFrameEnd(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_SSRRenderTextureHandle.GetID());
        }

        protected override void Dispose(bool disposing)
        {

        }
    }
}


