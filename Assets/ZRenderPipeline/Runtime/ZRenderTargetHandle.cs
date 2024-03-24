using Unity.Mathematics;

namespace UnityEngine.Rendering.ZPipeline
{
    public class ZRenderTargetHandle 
    {
        private RenderTargetIdentifier m_identifier;

        private int m_Id;

        private int m_Width;
        private int m_Height;

        public ZRenderTargetHandle(string identifier)
        {
            this.m_identifier = new RenderTargetIdentifier(identifier);
            this.m_Id = Shader.PropertyToID(identifier);
        }

        public ZRenderTargetHandle(string identifier, int width, int height)
        {
            this.m_identifier = new RenderTargetIdentifier(identifier);
            this.m_Id = Shader.PropertyToID(identifier);

            m_Width = width;
            m_Height = height;
        }

        public void SetWidth(int width)
        {
            m_Width = width;
        }

        public void SetHeight(int height)
        {
            m_Height = height;
        }

        public void SetSize(int width, int height)
        {
            m_Width = width;
            m_Height = height;
        }

        public float4 GetBufferSizeAndInverse()
        {
            return new float4(m_Width, m_Height, 1.0f / m_Width, 1.0f / m_Height);
        }

        public float4 GetBufferBilinearMinMax()
        {
            return new float4(0.5f / m_Width, 0.5f / m_Height, (m_Width - 0.5f) / m_Width, (m_Height - 0.5f) / m_Height);
        }


        public RenderTargetIdentifier GetIdentifier()
        {
            return m_identifier;
        }

        public int GetID()
        {
            return m_Id;
        }

        public int GetWidth()
        {
            return m_Width;
        }

        public int GetHeight()
        {
            return m_Height;
        }

        public static float4 GetScreenPosToBufferUV(float4 bufferSizeAndInverse, int2 viewPortOffset)
        {
            return new float4(
                bufferSizeAndInverse.x * 0.5f * bufferSizeAndInverse.z,
                bufferSizeAndInverse.y * 0.5f * bufferSizeAndInverse.w,
                (bufferSizeAndInverse.x * 0.5f + viewPortOffset.x) * bufferSizeAndInverse.z,
                (bufferSizeAndInverse.y * 0.5f + viewPortOffset.y) * bufferSizeAndInverse.w);
        }

        public static float4 GetBufferSizeAndInverse(RenderTexture texture)
        {
            return new float4(texture.width, texture.height, 1.0f / texture.width, 1.0f / texture.height);
        }

        public static float4 GetBufferBilinearMinMax(RenderTexture texture)
        {
            return new float4(0.5f / texture.width, 0.5f / texture.height, (texture.width - 0.5f) / texture.width, (texture.height - 0.5f) / texture.height);
        }

        public static float4 GetScreenSizeAndInverse()
        {
            return new float4(Screen.width, Screen.height, 1.0f / Screen.width, 1.0f / Screen.height);
        }

        public static float4 GetScreenBilinearMinMax()
        {
            return new float4(0.5f / Screen.width, 0.5f / Screen.height, (Screen.width - 0.5f) / Screen.width, (Screen.height - 0.5f) / Screen.height);
        }
    }

}

