namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZRenderingPropertiesPass : ZScriptableRendererPass
    {
        #region fields
        protected Matrix4x4 m_ViewMatrix;
        protected Matrix4x4 m_ProjMatrix;

        protected Matrix4x4 m_JitterProjMatrix;

        protected Matrix4x4 m_PreViewMatrix;
        protected Matrix4x4 m_PreProjMatrix;

        protected Matrix4x4 m_PreJitterProjMatrix;

        protected Vector4 m_ZBufferParams;
        #endregion

        #region properties
        public Matrix4x4 ViewMatrix => m_ViewMatrix;
        public Matrix4x4 ProjMatrix => m_ProjMatrix;
        public Matrix4x4 JitterProjMatrix => m_JitterProjMatrix;

        public Matrix4x4 PreViewMatrix => m_PreViewMatrix;
        public Matrix4x4 PreProjMatrix => m_PreProjMatrix;
        public Matrix4x4 PreJitterProjMatrix => m_PreJitterProjMatrix;
        #endregion

        #region life cycle
        public override void SetupRendererPass(CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            m_ViewMatrix = renderingData.camera.worldToCameraMatrix;
            m_ProjMatrix = renderingData.camera.projectionMatrix;

            m_JitterProjMatrix = Matrix4x4.identity;
        }

        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            // cal params.
            UpdateZbufferParams(renderingData.camera);

            // set unity params.
            cmd.SetGlobalVector(ZUniversalShaderContents.ZBufferParams, m_ZBufferParams);
            cmd.SetGlobalVector(ZUniversalShaderContents.WorldSpaceCameraPos, renderingData.camera.transform.position);

            cmd.SetViewProjectionMatrices(m_ViewMatrix, m_JitterProjMatrix != Matrix4x4.identity ? m_JitterProjMatrix : m_ProjMatrix);

            // set global matrixs.
            cmd.SetGlobalMatrix(ZUniversalShaderContents.M_ViewMatrix, m_ViewMatrix);
            cmd.SetGlobalMatrix(ZUniversalShaderContents.M_ProjMatrix, m_ProjMatrix);
            cmd.SetGlobalMatrix(ZUniversalShaderContents.M_JitterProjMatrix, m_JitterProjMatrix);
            cmd.SetGlobalMatrix(ZUniversalShaderContents.M_PreViewMatrix, m_PreViewMatrix);
            cmd.SetGlobalMatrix(ZUniversalShaderContents.M_PreProjMatrix, m_PreProjMatrix);
            cmd.SetGlobalMatrix(ZUniversalShaderContents.M_PreJitterProjMatrix, m_PreJitterProjMatrix);

            // set global vectors.
            cmd.SetGlobalVector(ZUniversalShaderContents.V_ScreenParams, new Vector4(renderingData.cameraColorDesc.width, renderingData.cameraColorDesc.height, 1.0f / renderingData.cameraColorDesc.width, 1.0f / renderingData.cameraColorDesc.height));
        }

        public override void OnFrameEnd(CommandBuffer cmd)
        {
            m_PreViewMatrix = m_ViewMatrix;
            m_PreProjMatrix = m_ProjMatrix;

            m_PreJitterProjMatrix = m_JitterProjMatrix;
        }
        #endregion

        #region interface
        public void UpdateJitterProjMatrix(Matrix4x4 jitterMatrix)
        {
            m_JitterProjMatrix = jitterMatrix;
        }

        public void ReverseViewProjMatrix(CommandBuffer cmd)
        {
            cmd.SetViewProjectionMatrices(m_ViewMatrix, m_JitterProjMatrix != Matrix4x4.identity ? m_JitterProjMatrix : m_ProjMatrix);
        }
        #endregion

        #region local method
        private void UpdateZbufferParams(Camera camera)
        {
            float near = camera.nearClipPlane;
            float far = camera.farClipPlane;
            float invNear = Mathf.Approximately(near, 0.0f) ? 0.0f : 1.0f / near;
            float invFar = Mathf.Approximately(far, 0.0f) ? 0.0f : 1.0f / far;
            //float isOrthographic = camera.orthographic ? 1.0f : 0.0f;

            // From http://www.humus.name/temp/Linearize%20depth.txt
            // But as depth component textures on OpenGL always return in 0..1 range (as in D3D), we have to use
            // the same constants for both D3D and OpenGL here.
            // OpenGL would be this:
            // zc0 = (1.0 - far / near) / 2.0;
            // zc1 = (1.0 + far / near) / 2.0;
            // D3D is this:
            float zc0 = 1.0f - far * invNear;
            float zc1 = far * invNear;

            m_ZBufferParams = new Vector4(zc0, zc1, zc0 * invFar, zc1 * invFar);

            if (SystemInfo.usesReversedZBuffer)
            {
                m_ZBufferParams.y += m_ZBufferParams.x;
                m_ZBufferParams.x = -m_ZBufferParams.x;
                m_ZBufferParams.w += m_ZBufferParams.z;
                m_ZBufferParams.z = -m_ZBufferParams.z;
            }
        }
        #endregion

        public static class ZUniversalShaderContents
        {
            // matrixs.
            public static int M_ViewMatrix          = Shader.PropertyToID("_M_ViewMatrix");
            public static int M_ProjMatrix          = Shader.PropertyToID("_M_ProjMatrix");
            public static int M_JitterProjMatrix    = Shader.PropertyToID("_M_JitterProjMatrix");
            public static int M_PreViewMatrix       = Shader.PropertyToID("_M_PreViewMatrix");
            public static int M_PreProjMatrix       = Shader.PropertyToID("_M_PreProjMatrix");
            public static int M_PreJitterProjMatrix = Shader.PropertyToID("_M_PreJitterProjMatrix");

            // vecvors.
            public static int V_ScreenParams = Shader.PropertyToID("_V_ScreenParams");


            // floats.


            // unity default.
            public static int ZBufferParams = Shader.PropertyToID("_ZBufferParams");
            public static int WorldSpaceCameraPos = Shader.PropertyToID("_WorldSpaceCameraPos");
        }
    }

}
