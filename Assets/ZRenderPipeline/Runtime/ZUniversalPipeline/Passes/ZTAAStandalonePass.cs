using Unity.Mathematics;

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZTAAStandalonePass : ZScriptableRendererPass
    {

        private static float[,] g_SampleOffsets = new float[9, 2]
        {
            { -1.0f, -1.0f },
            {  0.0f, -1.0f },
            {  1.0f, -1.0f },
            { -1.0f,  0.0f },
            {  0.0f,  0.0f },
            {  1.0f,  0.0f },
            { -1.0f,  1.0f },
            {  0.0f,  1.0f },
            {  1.0f,  1.0f },
        };

        // configs.
        [SerializeField, Range(0.0f, 1.0f), Tooltip("Size of the filter kernel. (1.0 = smoother, 0.0 = sharper but aliased).")]
        private float m_TemporalAAFilterSize = 1.0f;

        [SerializeField, Range(0, 1), Tooltip("Whether to use a Catmull-Rom filter kernel. Should be a bit sharper than Gaussian.")]
        private int m_TemporalAACatmullRom;

        // local params.
        private int m_TemporalSampleIndex;

        private float2 m_TemporalAAProjectionJitter;

        private float[] m_SampleWeights = new float[9];
        private float[] m_PlusWeights = new float[5];


        private RenderTexture m_TaaBufferA;
        private RenderTexture m_TaaBufferB;

        private RenderTexture m_HistoryBuffer;
        private RenderTexture m_CurrentBuffer;

        private RenderTextureDescriptor m_TaaDesc;

        private Material m_TaaMat;

        public ComputeShader m_TaaComputer;

        public override void Create()
        {
            if (m_TaaMat == null)
            {
                m_TaaMat = CoreUtils.CreateEngineMaterial(Shader.Find("ZPipeline/ZUniversal/PPS/TAAStandalone"));
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (m_TaaMat)
            {
                CoreUtils.Destroy(m_TaaMat);
                m_TaaMat = null;
            }
        }

        public override void SetupRendererPass(CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            int CVarTemporalAASamplesValue = 8; // 4, 8, 16, 32, 64

            int TemporalAASamples = CVarTemporalAASamplesValue;

            if (!FrameDebugger.enabled)
            {
                m_TemporalSampleIndex = m_TemporalSampleIndex + 1;
            }

            if (m_TemporalSampleIndex >= TemporalAASamples)
            {
                m_TemporalSampleIndex = 0;
            }

            // cal offset 
            float SampleX, SampleY;
            {
                float u1 = Halton(m_TemporalSampleIndex + 1, 2);
                float u2 = Halton(m_TemporalSampleIndex + 1, 3);

                // Generates samples in normal distribution
                // exp( x^2 / Sigma^2 )

                float FilterSize = math.max(0.05f, m_TemporalAAFilterSize); // 1.0 = smoother, 0.0 = sharper but aliased
                 
                // Scale distribution to set non-unit variance
                // Variance = Sigma^2
                float Sigma = 0.47f * FilterSize;

                // Window to [-0.5, 0.5] output
                // Without windowing we could generate samples far away on the infinite tails.
                float OutWindow = 0.5f;
                float InWindow = math.exp(-0.5f * (OutWindow / Sigma) * (OutWindow / Sigma));

                // Box-Muller transform
                float Theta = 2.0f * math.PI * u2;
                float r = Sigma * math.sqrt(-2.0f * math.log((1.0f - u1) * InWindow + u1));

                SampleX = r * math.cos(Theta);
                SampleY = r * math.sin(Theta);
            }

            var propertiesPass = ZUniversalRenderer.Instance.GetRendererPass<ZRenderingPropertiesPass>();

            var jitterProjMatrix = propertiesPass.ProjMatrix;

            jitterProjMatrix[0, 2] += SampleX * 2.0f / renderingData.cameraColorDesc.width;
            jitterProjMatrix[1, 2] += SampleY * 2.0f / renderingData.cameraColorDesc.height;

            propertiesPass.UpdateJitterProjMatrix(jitterProjMatrix);

            m_TemporalAAProjectionJitter.x = SampleX;
            m_TemporalAAProjectionJitter.y = SampleY;
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            var sceneBufferDesc = renderingData.cameraColorDesc;

            var refreshTex = m_TaaDesc.width != sceneBufferDesc.width || m_TaaDesc.height != sceneBufferDesc.height;

            if (refreshTex)
            {
                m_TaaDesc = sceneBufferDesc;
                m_TaaDesc.enableRandomWrite = true;

                //m_TaaDesc.width = (int)(m_TaaDesc.width * 0.99f);
                //m_TaaDesc.height = (int)(m_TaaDesc.height * 0.99f);

                if (m_TaaBufferA) RenderTexture.ReleaseTemporary(m_TaaBufferA);
                if (m_TaaBufferB) RenderTexture.ReleaseTemporary(m_TaaBufferB);

                m_TaaBufferA = RenderTexture.GetTemporary(m_TaaDesc);
                m_TaaBufferA.filterMode = FilterMode.Bilinear;
                m_TaaBufferA.name = "TemporalAA_A";
                m_TaaBufferA.Create();

                m_TaaBufferB = RenderTexture.GetTemporary(m_TaaDesc);
                m_TaaBufferB.filterMode = FilterMode.Bilinear;
                m_TaaBufferB.name = "TemporalAA_B";
                m_TaaBufferB.Create();

                m_TaaBufferA.hideFlags = HideFlags.HideAndDontSave;
                m_TaaBufferB.hideFlags = HideFlags.HideAndDontSave;

                m_CurrentBuffer = m_TaaBufferA;
                m_HistoryBuffer = m_TaaBufferB;
            }

            float JitterX = m_TemporalAAProjectionJitter.x;
            float JitterY = m_TemporalAAProjectionJitter.y;

            float ResDivisorInv = 1.0f;// / m_Settings.RenderScale;// / new float(PassParameters.ResolutionDivisor);

            float FilterSize = math.max(0.05f, m_TemporalAAFilterSize);
            bool bCatmullRom = m_TemporalAACatmullRom == 1;

            // Compute 3x3 weights
            {
                float TotalWeight = 0.0f;
                for (int i = 0; i < 9; i++)
                {
                    float PixelOffsetX = g_SampleOffsets[i, 0] - JitterX * ResDivisorInv;
                    float PixelOffsetY = g_SampleOffsets[i, 1] - JitterY * ResDivisorInv;

                    PixelOffsetX /= FilterSize;
                    PixelOffsetY /= FilterSize;

                    if (bCatmullRom)
                    {
                        m_SampleWeights[i] = CatmullRom(PixelOffsetX) * CatmullRom(PixelOffsetY);
                        TotalWeight += m_SampleWeights[i];
                    }
                    else
                    {
                        // Normal distribution, Sigma = 0.47
                        m_SampleWeights[i] = math.exp(-2.29f * (PixelOffsetX * PixelOffsetX + PixelOffsetY * PixelOffsetY));
                        TotalWeight += m_SampleWeights[i];
                    }
                }

                for (int i = 0; i < 9; i++)
                    m_SampleWeights[i] /= TotalWeight;
            }

            // Compute 3x3 + weights.
            {
                m_PlusWeights[0] = m_SampleWeights[1];
                m_PlusWeights[1] = m_SampleWeights[3];
                m_PlusWeights[2] = m_SampleWeights[4];
                m_PlusWeights[3] = m_SampleWeights[5];
                m_PlusWeights[4] = m_SampleWeights[7];

                float TotalWeightPlus = (
                    m_SampleWeights[1] +
                    m_SampleWeights[3] +
                    m_SampleWeights[4] +
                    m_SampleWeights[5] +
                    m_SampleWeights[7]);

                for (int i = 0; i < 5; i++)
                    m_PlusWeights[i] /= TotalWeightPlus;
            }

            var renderingTargetPass = ZUniversalRenderer.Instance.GetRendererPass<ZRenderingTargetPass>();

            float4 sceneBufferSizeAndInverse = new float4(sceneBufferDesc.width, sceneBufferDesc.height, 1.0f / sceneBufferDesc.width, 1.0f / sceneBufferDesc.height);

            cmd.SetGlobalFloat("_U_StateFrameIndexMod8", m_TemporalSampleIndex);

            cmd.SetGlobalFloat("_TAA_F_CurrentFrameWeight", 0.04f);
            cmd.SetGlobalFloatArray("_TAA_FA_PlusWeights", m_PlusWeights);
            cmd.SetGlobalFloatArray("_TAA_FA_SampleWeights", m_SampleWeights);

            cmd.SetGlobalTexture("_HistoryTaaTexture", m_HistoryBuffer);
            cmd.SetGlobalTexture("_SceneColorTexture", renderingTargetPass.CurrentCameraColorTarget);
            cmd.SetGlobalTexture("_SceneDepthTexture", renderingTargetPass.CurrentCameraDepthTarget);

            cmd.SetGlobalVector("_TAA_V_ScreenPosToHistoryBufferUV", ZRenderTargetHandle.GetScreenPosToBufferUV(sceneBufferSizeAndInverse, new int2(0, 0)));
            cmd.SetGlobalVector("_TAA_V_HistoryBufferUVMinMax", ZRenderTargetHandle.GetBufferBilinearMinMax(m_HistoryBuffer)); //ZCameraTargetPass.Instance.GetSceneBufferBilinearMinMax());
            cmd.SetGlobalVector("_TAA_V_HistoryBufferSize", ZRenderTargetHandle.GetBufferSizeAndInverse(m_HistoryBuffer)); //sceneBufferSizeAndInverse);
            cmd.SetGlobalVector("_TAA_V_InputSceneColorSize", sceneBufferSizeAndInverse);
            cmd.SetGlobalVector("_TAA_V_OutputViewportSize", ZRenderTargetHandle.GetBufferSizeAndInverse(m_CurrentBuffer)); //sceneBufferSizeAndInverse);
            cmd.SetGlobalVector("_TAA_V_InputMinMaxPixelCoord", new float4(0, 0, sceneBufferSizeAndInverse.x - 1, sceneBufferSizeAndInverse.y - 1));
            cmd.SetGlobalVector("_TAA_V_OutputQuantizationError", new float4(ComputePixelFormatQuantizationError(), 0));

            //cmd.SetRenderTarget(m_CurrentBuffer, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            //cmd.Blit(-1, BuiltinRenderTextureType.CurrentActive, m_TaaMat);

            //renderingTargetPass.SetCurrentActiveColorTarget(m_CurrentBuffer);


            int groupX = (int)math.ceil(m_CurrentBuffer.width / 8);
            int groupY = (int)math.ceil(m_CurrentBuffer.width / 8);

            cmd.SetComputeTextureParam(m_TaaComputer, 0, Shader.PropertyToID("OutResult"), m_CurrentBuffer);
            cmd.DispatchCompute(m_TaaComputer, 0, groupX, groupY, 1);

            renderingTargetPass.SetCurrentActiveColorTarget(m_CurrentBuffer);
        }

        public override void OnFrameEnd(CommandBuffer cmd)
        {
            if (m_CurrentBuffer == m_TaaBufferA)
            {
                m_CurrentBuffer = m_TaaBufferB;
                m_HistoryBuffer = m_TaaBufferA;
            }
            else
            {
                m_CurrentBuffer = m_TaaBufferA;
                m_HistoryBuffer = m_TaaBufferB;
            }
        }

        private float Halton(int Index, int Base)
        {
            float Result = 0.0f;
            float InvBase = 1.0f / Base;
            float Fraction = InvBase;

            while (Index > 0)
            {
                Result += (Index % Base) * Fraction;
                Index /= Base;
                Fraction *= InvBase;
            }

            return Result;
        }

        private float CatmullRom(float x)
        {
            float ax = math.abs(x);

            if (ax > 1.0f)
                return ((-0.5f * ax + 2.5f) * ax - 4.0f) * ax + 2.0f;
            else
                return (1.5f * ax - 2.5f) * ax * ax + 1.0f;
        }

        private float3 ComputePixelFormatQuantizationError()
        {
            float3 Error;

            {
                float3 HistoryColorMantissaBits = new float3(10, 10, 10);

                Error.x = math.pow(0.5f, HistoryColorMantissaBits.x);
                Error.y = math.pow(0.5f, HistoryColorMantissaBits.y);
                Error.z = math.pow(0.5f, HistoryColorMantissaBits.z);
            }

            return Error;
        }
    }

}

