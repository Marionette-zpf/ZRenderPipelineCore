using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZRenderingTargetPass : ZScriptableRendererPass
    {
        const GraphicsFormat k_DepthStencilFormat = GraphicsFormat.D32_SFloat_S8_UInt;
        const int k_DepthBufferBits = 32;

        [SerializeField, Range(0.1f, 2.0f)]
        private float m_RenderScale = 1.0f;

        private ZRenderTargetHandle m_CameraColorTarget;
        private ZRenderTargetHandle m_CameraDepthTarget;

        private ZRenderTargetHandle m_CameraGBufferA;
        private ZRenderTargetHandle m_CameraGBufferB;
        private ZRenderTargetHandle m_CameraGBufferC;
        private ZRenderTargetHandle m_CameraGBufferD;

        private RenderTextureDescriptor m_CameraColorDesc;
        private RenderTextureDescriptor m_CameraDepthDesc;

        private RenderTargetIdentifier m_CurrentCameraColorTarget;
        private RenderTargetIdentifier m_CurrentCameraDepthTarget;

        private RenderTargetIdentifier[] m_BasePassTargets;

        public RenderTargetIdentifier CameraColorTarget => m_CameraColorTarget.GetIdentifier();
        public RenderTargetIdentifier CameraDepthTarget => m_CameraDepthTarget.GetIdentifier();
        public RenderTargetIdentifier CurrentCameraColorTarget => m_CurrentCameraColorTarget;
        public RenderTargetIdentifier CurrentCameraDepthTarget => m_CurrentCameraDepthTarget;
        public RenderTargetIdentifier[] BasePassTargets => m_BasePassTargets;

        #region life cycle
        public override void Create()
        {
            m_CameraColorTarget = new ZRenderTargetHandle("_CameraTargetColor");
            m_CameraDepthTarget = new ZRenderTargetHandle("_CameraTargetDepth");

            m_CameraGBufferA = new ZRenderTargetHandle("_GBufferA");
            m_CameraGBufferB = new ZRenderTargetHandle("_GBufferB");
            m_CameraGBufferC = new ZRenderTargetHandle("_GBufferC");
            m_CameraGBufferD = new ZRenderTargetHandle("_GBufferD");
        }

        public override void SetupRendererPass(CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            // base params.
            int width = (int)(renderingData.camera.pixelWidth * m_RenderScale);
            int heigh = (int)(renderingData.camera.pixelHeight * m_RenderScale);

            // create camera color desc.
            m_CameraColorDesc = new RenderTextureDescriptor(width, heigh);
            m_CameraColorDesc.width = Mathf.Max(1, m_CameraColorDesc.width);
            m_CameraColorDesc.height = Mathf.Max(1, m_CameraColorDesc.height);
            m_CameraColorDesc.graphicsFormat = GraphicsFormat.B10G11R11_UFloatPack32;
            m_CameraColorDesc.depthBufferBits = 0;
            m_CameraColorDesc.msaaSamples = 1;
            m_CameraColorDesc.sRGB = (QualitySettings.activeColorSpace == ColorSpace.Linear);
            m_CameraColorDesc.dimension = TextureDimension.Tex2D;
            //m_CameraColorDesc.useMipMap = true;

            m_CameraColorDesc.enableRandomWrite = false;
            m_CameraColorDesc.bindMS = false;
            m_CameraColorDesc.useDynamicScale = renderingData.camera.allowDynamicResolution;

            // cteate camera depth desc.
            m_CameraDepthDesc = m_CameraColorDesc;
            m_CameraDepthDesc.graphicsFormat = GraphicsFormat.None;
            m_CameraDepthDesc.depthStencilFormat = k_DepthStencilFormat;
            m_CameraDepthDesc.depthBufferBits = k_DepthBufferBits;
            m_CameraDepthDesc.msaaSamples = 1;// Depth-Only pass don't use MSAA

            var gBufferDesc = m_CameraColorDesc;
            gBufferDesc.sRGB = false;

            var gBufferADesc = gBufferDesc;
            gBufferADesc.graphicsFormat = GraphicsFormat.A2B10G10R10_UNormPack32;

            var gBufferBDesc = gBufferDesc;
            gBufferBDesc.graphicsFormat = GraphicsFormat.R8G8B8A8_UNorm;

            var gBufferCDesc = gBufferDesc;
            gBufferCDesc.graphicsFormat = GraphicsFormat.R8G8B8A8_UNorm;

            var gBufferDDesc = gBufferDesc;
            gBufferDDesc.graphicsFormat = GraphicsFormat.R8G8B8A8_UNorm;

            // get res.
            cmd.GetTemporaryRT(m_CameraColorTarget.GetID(), m_CameraColorDesc, FilterMode.Bilinear);
            cmd.GetTemporaryRT(m_CameraDepthTarget.GetID(), m_CameraDepthDesc, FilterMode.Point);

            cmd.GetTemporaryRT(m_CameraGBufferA.GetID(), gBufferADesc, FilterMode.Point);
            cmd.GetTemporaryRT(m_CameraGBufferB.GetID(), gBufferBDesc, FilterMode.Point);
            cmd.GetTemporaryRT(m_CameraGBufferC.GetID(), gBufferCDesc, FilterMode.Point);
            cmd.GetTemporaryRT(m_CameraGBufferD.GetID(), gBufferDDesc, FilterMode.Point);

            m_CameraColorTarget.SetSize(m_CameraColorDesc.width, m_CameraColorDesc.height);

            renderingData.cameraColorDesc = m_CameraColorDesc;
            renderingData.cameraDepthDesc = m_CameraDepthDesc;

            m_BasePassTargets = new RenderTargetIdentifier[5];
            m_BasePassTargets[0] = m_CameraColorTarget.GetIdentifier();
            m_BasePassTargets[1] = m_CameraGBufferA.GetIdentifier();
            m_BasePassTargets[2] = m_CameraGBufferB.GetIdentifier();
            m_BasePassTargets[3] = m_CameraGBufferC.GetIdentifier();
            m_BasePassTargets[4] = m_CameraGBufferD.GetIdentifier();
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            cmd.SetGlobalTexture("_CameraTargetColor", m_CameraColorTarget.GetIdentifier());
            cmd.SetGlobalTexture("_CameraTargetDepth", m_CameraDepthTarget.GetIdentifier());

            cmd.SetGlobalTexture("_GBufferA", m_CameraGBufferA.GetIdentifier());
            cmd.SetGlobalTexture("_GBufferB", m_CameraGBufferB.GetIdentifier());
            cmd.SetGlobalTexture("_GBufferC", m_CameraGBufferC.GetIdentifier());
            cmd.SetGlobalTexture("_GBufferD", m_CameraGBufferD.GetIdentifier());
        }

        public override void OnFrameEnd(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_CameraColorTarget.GetID());
            cmd.ReleaseTemporaryRT(m_CameraDepthTarget.GetID());

            cmd.ReleaseTemporaryRT(m_CameraGBufferA.GetID());
            cmd.ReleaseTemporaryRT(m_CameraGBufferB.GetID());
            cmd.ReleaseTemporaryRT(m_CameraGBufferC.GetID());
            cmd.ReleaseTemporaryRT(m_CameraGBufferD.GetID());
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

