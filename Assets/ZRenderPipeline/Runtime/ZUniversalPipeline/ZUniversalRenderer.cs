namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZUniversalRenderer : ZScriptableRenderer
    {
        public static ZUniversalRenderer Instance;

        private ZUniversalRendererData m_PipelineData;

        private ZRenderingData m_RenderingData = new ZRenderingData();

        public ZUniversalRenderer(ZUniversalRendererData rendererData)
        {
            m_PipelineData = rendererData;

            for (int i = 0; i < m_PipelineData.rendererFeatures.Count; i++)
            {
                var pass = m_PipelineData.rendererFeatures[i];

                if (pass == null)
                    continue;

                pass.Create();

                m_RendererPasses.Add(pass.GetType(), new ZScriptableRendererPassData() { RendererPass = pass, IsValid = false });
            }

            Instance = this;
        }

        public void CameraRendering(ScriptableRenderContext context, Camera camera)
        {
            context.SetupCameraProperties(camera);

#if UNITY_EDITOR
            PrepareForSceneWindow(camera);
#endif

            if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
            {
                m_RenderingData.cullingResults = context.Cull(ref p);
                m_RenderingData.camera = camera;

                m_RenderingData.cameraMask = 
                    camera.cameraType == CameraType.Game ? 1 :
                    camera.cameraType == CameraType.SceneView ? 2 :
                    camera.cameraType == CameraType.Preview ? 4 : 0;
            }
            else
            {
                return;
            }



            var cmd = CommandBufferPool.Get();
            cmd.name = string.Empty;

            var prifleInfo = "ZUniversal Pipeline : " + camera.name;

            foreach (var item in m_RendererPasses.Values)
            {
                RunIsValidPass(cmd, item);
                context.ExecuteAndClear(cmd);
            }

            foreach (var item in m_RendererPasses.Values)
            {
                RunSetupRendererPass(cmd, item);
                context.ExecuteAndClear(cmd);
            }

            cmd.BeginSample(prifleInfo);


            foreach (var item in m_RendererPasses.Values)
            {
                RunExecuRendererPass(context, cmd, item);
                context.ExecuteAndClear(cmd);
            }

            cmd.EndSample(prifleInfo);

            foreach (var item in m_RendererPasses.Values)
            {
                RunOnFrameEnd(cmd, item);
                context.ExecuteAndClear(cmd);
            }

            foreach (var item in m_RendererPasses.Values)
            {
                item.IsValid = false;
            }

#if UNITY_EDITOR
            DrawGizmos(context, camera);
#endif

            // submit.
            context.Submit();

            // release res.
            CommandBufferPool.Release(cmd);
        }
        private void RunIsValidPass(CommandBuffer cmd, ZScriptableRendererPassData item)
        {
            if (item.RendererPass.isActive && (item.RendererPass.CameraMaks & m_RenderingData.cameraMask) != 0)
            {
                item.IsValid = item.RendererPass.IsValidPass();
            }
            else
            {
                item.IsValid = false;
            }

        }

        private void RunSetupRendererPass(CommandBuffer cmd, ZScriptableRendererPassData item)
        {
            if (item.IsValid)
            {
                item.RendererPass.SetupRendererPass(cmd, ref m_RenderingData);
            }
        }

        private void RunExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ZScriptableRendererPassData item)
        {
            if (item.IsValid)
            {
                cmd.BeginSample(item.RendererPass.name);

                item.RendererPass.ExecuRendererPass(context, cmd, ref m_RenderingData);

                cmd.EndSample(item.RendererPass.name);
            }
        }


        private static void RunOnFrameEnd(CommandBuffer cmd, ZScriptableRendererPassData item)
        {
            if (item.IsValid)
            {
                item.RendererPass.OnFrameEnd(cmd);
            }
        }


        public override void Dispose()
        {
            foreach (var item in m_RendererPasses.Values)
            {
                item.RendererPass.Dispose();
            }

            m_RendererPasses.Clear();
        }

#if UNITY_EDITOR
        private void PrepareForSceneWindow(Camera camera)
        {
            if (camera.cameraType == CameraType.SceneView)
            {
                ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
            }
        }
        private void DrawGizmos(ScriptableRenderContext context, Camera camera)
        {
            if (UnityEditor.Handles.ShouldRenderGizmos())
            {
                context.SetupCameraProperties(camera);

                context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
                context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
            }
        }
#endif
    }

}
