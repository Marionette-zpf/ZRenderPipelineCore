namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public class ZDrawCharactersPass : ZDrawObjectsPass
    {
        protected override bool m_IsTransparent => false;

        public override void Create()
        {
            m_ExtShaderTagId = new ShaderTagId("ZCharacters");

            base.Create();
        }
    }

}

