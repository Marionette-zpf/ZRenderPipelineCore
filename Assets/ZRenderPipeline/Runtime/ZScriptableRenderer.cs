using System;
using System.Collections.Generic;

namespace UnityEngine.Rendering.ZPipeline
{

    public abstract class ZScriptableRenderer : IDisposable
    {

        protected Dictionary<Type, ZScriptableRendererPassData> m_RendererPasses = new Dictionary<Type, ZScriptableRendererPassData>();

        public bool IsValidPass<TPass>() where TPass : ZScriptableRendererPass
        {
            var containsPass = m_RendererPasses.TryGetValue(typeof(TPass), out var passData);

            if (passData != null && containsPass && passData.IsValid && passData.RendererPass.isActive)
            {
                return true;
            }

            return false;
        }

        public T GetRendererPass<T>() where T : ZScriptableRendererPass
        {
            if (m_RendererPasses.TryGetValue(typeof(T), out var item))
            {
                return item.RendererPass as T;
            }

            return null;
        }

        public abstract void Dispose();

        protected class ZScriptableRendererPassData
        {
            public ZScriptableRendererPass RendererPass;
            public bool IsValid;
        }
    }

    public class ZRenderingData
    {
        public Camera camera;

        public CullingResults cullingResults;

        public int cameraMask;

        public RenderTextureDescriptor cameraColorDesc;
        public RenderTextureDescriptor cameraDepthDesc;

        public bool IsSceneCamera => camera.cameraType == CameraType.SceneView;
        public bool IsGameCamera => camera.cameraType == CameraType.Game;
        public bool IsPreviewCamera => camera.cameraType == CameraType.Preview;
    }

}
