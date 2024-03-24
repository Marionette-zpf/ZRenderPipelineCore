namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZRenderingPropertiesPass : ZScriptableRendererPass
    {
        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            //context.SetupCameraProperties(renderingData.camera);

            cmd.SetViewProjectionMatrices(renderingData.camera.worldToCameraMatrix, renderingData.camera.projectionMatrix);
        }
    }

}
