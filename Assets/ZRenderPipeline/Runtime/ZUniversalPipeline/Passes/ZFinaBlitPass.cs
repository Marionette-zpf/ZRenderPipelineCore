namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZFinaBlitPass : ZScriptableRendererPass
    {
        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            var currentCameraTarget = ZUniversalRenderer.Instance.GetRendererPass<ZRenderingTargetPass>().CurrentCameraColorTarget;

            if (currentCameraTarget != BuiltinRenderTextureType.CameraTarget)
            {
                //cmd.Blit(ZUniversalRenderer.Instance.GetRendererPass<ZScreenSpaceReflectionPass>().SSRRenderTextureHandle.GetIdentifier(), BuiltinRenderTextureType.CameraTarget);
                cmd.Blit(currentCameraTarget, BuiltinRenderTextureType.CameraTarget);
            }
        }
    }

}

