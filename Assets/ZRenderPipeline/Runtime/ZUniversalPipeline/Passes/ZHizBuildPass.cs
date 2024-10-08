using Unity.Mathematics;

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZHizBuildPass : ZScriptableRendererPass
    {
        [SerializeField]
        private ComputeShader m_HizBuildComputer;

        private RenderTexture m_FurthestHizMap;

        public RenderTexture FurthestHizTexture => m_FurthestHizMap;

        public override bool IsValidPass()
        {
            return m_HizBuildComputer != null;
        }

        public override void SetupRendererPass(CommandBuffer cmd, ref ZRenderingData renderingData)
        {

        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            var desc = renderingData.cameraColorDesc;

            int2 HZBSize;
            int NumMips;
            {
                int NumMipsX = (int)math.max(math.ceil(math.log2(desc.width)) - 1, 1);
                int NumMipsY = (int)math.max(math.ceil(math.log2(desc.height)) - 1, 1);

                NumMips = math.max(NumMipsX, NumMipsY);

                // Must be power of 2
                HZBSize = new int2(1 << NumMipsX, 1 << NumMipsY);
            }

            // Debug.LogWarning("NumMips : " + NumMips + " , HZBSize : " + HZBSize);

            var hizDesc = desc;
            hizDesc.width = HZBSize.x;
            hizDesc.height = HZBSize.y;
            hizDesc.graphicsFormat = Experimental.Rendering.GraphicsFormat.R16_SFloat;
            hizDesc.sRGB = false;
            hizDesc.useMipMap = true;
            hizDesc.autoGenerateMips = false;
            hizDesc.mipCount = NumMips;
            hizDesc.enableRandomWrite = true;

            if (m_FurthestHizMap == null || m_FurthestHizMap.width != hizDesc.width || m_FurthestHizMap.height != hizDesc.height)
            {
                ReleaseHizMap();
                m_FurthestHizMap = RenderTexture.GetTemporary(hizDesc);
                m_FurthestHizMap.name = "_HizMap";
                m_FurthestHizMap.Create();
                m_FurthestHizMap.GenerateMips();
            }

            for (int mipmapLevel = 0; mipmapLevel < NumMips; mipmapLevel += 4)
            {
                int gx = math.max(1, (HZBSize.x >> mipmapLevel) / 8);
                int gy = math.max(1, (HZBSize.y >> mipmapLevel) / 8);
                int gz = 1;

                int kernel;

                int genMipCount = math.min(4, NumMips - mipmapLevel);

                int2 srcSize;

                if (mipmapLevel == 0)
                {
                    kernel = genMipCount - 1;
                    cmd.SetComputeTextureParam(m_HizBuildComputer, kernel, Shader.PropertyToID("ParentTextureMip"), ZUniversalRenderer.Instance.GetRendererPass<ZRenderingTargetPass>().CameraDepthTarget);

                    srcSize = new int2(desc.width, desc.height);
                }
                else
                {
                    kernel = genMipCount - 1 + 4;
                    cmd.SetComputeTextureParam(m_HizBuildComputer, kernel, Shader.PropertyToID("RWParentTextureMip"), m_FurthestHizMap, mipmapLevel - 1);

                    srcSize = new int2(HZBSize.x >> (mipmapLevel - 1), HZBSize.y >> (mipmapLevel - 1));
                }

                cmd.SetComputeTextureParam(m_HizBuildComputer, kernel, Shader.PropertyToID("FurthestHZBOutput_0"), m_FurthestHizMap, mipmapLevel);

                if (genMipCount > 1)
                {
                    cmd.SetComputeTextureParam(m_HizBuildComputer, kernel, Shader.PropertyToID("FurthestHZBOutput_1"), m_FurthestHizMap, mipmapLevel + 1);
                }

                if (genMipCount > 2)
                {
                    cmd.SetComputeTextureParam(m_HizBuildComputer, kernel, Shader.PropertyToID("FurthestHZBOutput_2"), m_FurthestHizMap, mipmapLevel + 2);
                }

                if (genMipCount > 3)
                {
                    cmd.SetComputeTextureParam(m_HizBuildComputer, kernel, Shader.PropertyToID("FurthestHZBOutput_3"), m_FurthestHizMap, mipmapLevel + 3);
                }


                float2 InvSize = new float2(1.0f / srcSize.x, 1.0f / srcSize.y);
                float2 InputViewportMaxBound = new float2((srcSize.x - 0.5f) / srcSize.x, (srcSize.y - 0.5f) / srcSize.y);
                float4 DispatchThreadIdToBufferUV = new float4(2.0f / srcSize.x, 2.0f / srcSize.y, 0.0f, 0.0f);

                cmd.SetComputeVectorParam(m_HizBuildComputer, Shader.PropertyToID("DispatchThreadIdToBufferUV"), DispatchThreadIdToBufferUV);
                cmd.SetComputeVectorParam(m_HizBuildComputer, Shader.PropertyToID("InputViewportMaxBound"), new float4(InputViewportMaxBound, srcSize.x - 1, srcSize.y - 1));
                cmd.SetComputeVectorParam(m_HizBuildComputer, Shader.PropertyToID("InvSize"), new float4(InvSize, 0, 0));

                cmd.DispatchCompute(m_HizBuildComputer, kernel, gx, gy, gz);
            }

            float2 HZBUvFactor = new float2(desc.width / (2.0f * HZBSize.x), desc.height / (2.0f * HZBSize.y));
            float4 HZBUvFactorAndInvFactor = new float4(HZBUvFactor.x, HZBUvFactor.y, 1.0f / HZBUvFactor.x, 1.0f / HZBUvFactor.y);

            cmd.SetGlobalVector("_V_HZBUvFactorAndInvFactor", HZBUvFactorAndInvFactor);
        }

        protected override void Dispose(bool disposing)
        {
            ReleaseHizMap();
        }

        private void ReleaseHizMap()
        {
            if (m_FurthestHizMap != null)
            {
                RenderTexture.ReleaseTemporary(m_FurthestHizMap);
                m_FurthestHizMap = null;
            }
        }
    }

}
