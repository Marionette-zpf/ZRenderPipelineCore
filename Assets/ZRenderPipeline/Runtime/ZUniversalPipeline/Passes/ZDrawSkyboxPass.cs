namespace UnityEngine.Rendering.ZPipeline
{
    public class ZDrawSkyboxPass : ZScriptableRendererPass
    {
        public override void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData)
        {
            context.DrawSkybox(renderingData.camera);
        }
    }

}

