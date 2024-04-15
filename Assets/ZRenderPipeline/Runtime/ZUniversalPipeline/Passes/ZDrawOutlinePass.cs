namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZDrawOutlinePass : ZDrawObjectsPass
    {
        protected override bool m_IsTransparent => false;

        public override void Create()
        {
            m_ExtShaderTagId = new ShaderTagId("ZOutline");

            base.Create();
        }
    }

}

