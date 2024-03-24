using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZRenderingTargetPass : ZScriptableRendererPass
    {
        const GraphicsFormat k_DepthStencilFormat = GraphicsFormat.D32_SFloat_S8_UInt;
        const int k_DepthBufferBits = 32;

        private ZRenderTargetHandle m_CameraColorTarget;
        private ZRenderTargetHandle m_CameraDepthTarget;

        private RenderTextureDescriptor m_CameraColorDesc;
        private RenderTextureDescriptor m_CameraDepthDesc;

        private RenderTargetIdentifier m_CurrentCameraColorTarget;
        private RenderTargetIdentifier m_CurrentCameraDepthTarget;

        public RenderTargetIdentifier CurrentCameraColorTarget => m_CurrentCameraColorTarget;
        public RenderTargetIdentifier CurrentCameraDepthTarget => m_CurrentCameraDepthTarget;

        #region life cycle
        public override void Create()
        {
            m_CameraColorTarget = new ZRenderTargetHandle("_CameraTargetColor");
            m_CameraDepthTarget = new ZRenderTargetHandle("_CameraTargetDepth");
        }

        public override void SetupRendererPass(CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            // base params.
            int width = renderingData.camera.pixelWidth;
            int heigh = renderingData.camera.pixelHeight;

            // create camera color desc.
            m_CameraColorDesc = new RenderTextureDescriptor(width, heigh);
            m_CameraColorDesc.width = Mathf.Max(1, m_CameraColorDesc.width);
            m_CameraColorDesc.height = Mathf.Max(1, m_CameraColorDesc.height);
            m_CameraColorDesc.graphicsFormat = GraphicsFormat.B10G11R11_UFloatPack32;
            m_CameraColorDesc.depthBufferBits = 0;
            m_CameraColorDesc.msaaSamples = 1;
            m_CameraColorDesc.sRGB = (QualitySettings.activeColorSpace == ColorSpace.Linear);
            m_CameraColorDesc.dimension = TextureDimension.Tex2D;
            m_CameraColorDesc.useMipMap = false;

            m_CameraColorDesc.enableRandomWrite = false;
            m_CameraColorDesc.bindMS = false;
            m_CameraColorDesc.useDynamicScale = renderingData.camera.allowDynamicResolution;

            // cteate camera depth desc.
            m_CameraDepthDesc = m_CameraColorDesc;
            m_CameraDepthDesc.graphicsFormat = GraphicsFormat.None;
            m_CameraDepthDesc.depthStencilFormat = k_DepthStencilFormat;
            m_CameraDepthDesc.depthBufferBits = k_DepthBufferBits;
            m_CameraDepthDesc.msaaSamples = 1;// Depth-Only pass don't use MSAA

            // get res.
            cmd.GetTemporaryRT(m_CameraColorTarget.GetID(), m_CameraColorDesc);
            cmd.GetTemporaryRT(m_CameraDepthTarget.GetID(), m_CameraDepthDesc);
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            cmd.SetRenderTarget(
                m_CameraColorTarget.GetIdentifier(), RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
                m_CameraDepthTarget.GetIdentifier(), RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);

            cmd.ClearRenderTarget(true, true, Color.clear);

            SetCurrentActiveColorDepthTarget(m_CameraColorTarget.GetIdentifier(), m_CameraDepthTarget.GetIdentifier());
        }

        public override void OnFrameEnd(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_CameraColorTarget.GetID());
            cmd.ReleaseTemporaryRT(m_CameraDepthTarget.GetID());
        }
        #endregion

        #region interface
        public void SetCurrentActiveColorTarget(RenderTargetIdentifier colorIdentifier)
        {
            m_CurrentCameraColorTarget = colorIdentifier;
        }

        public void SetCurrentActiveDepthTarget(RenderTargetIdentifier depthIdentifier)
        {
            m_CurrentCameraDepthTarget = depthIdentifier;
        }

        public void SetCurrentActiveColorDepthTarget(RenderTargetIdentifier colorIdentifier, RenderTargetIdentifier depthIdentifier)
        {
            SetCurrentActiveColorTarget(colorIdentifier);
            SetCurrentActiveDepthTarget(depthIdentifier);
        }
        #endregion

    }

}

