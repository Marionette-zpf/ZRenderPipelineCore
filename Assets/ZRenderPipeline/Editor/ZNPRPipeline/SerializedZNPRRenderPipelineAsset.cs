using UnityEngine.Rendering.ZRendering.NPR;

namespace UnityEditor.Rendering.ZRendering.NPR
{
    public class SerializedZNPRRenderPipelineAsset
    {
        public SerializedProperty hdr { get; }
        public SerializedProperty hdrColorBufferPrecisionProp { get; }
        public SerializedProperty renderScale { get; }
        public SerializedProperty srpBatcher { get; }
        public SerializedProperty supportsDynamicBatching { get; }
        public SerializedProperty useFastSRGBLinearConversion { get; }

        public ZNPRRenderPipelineAsset asset { get; }
        public SerializedObject serializedObject { get; }

        public EditorPrefBoolFlags<ZEditorUtils.Unit> state;

        public SerializedZNPRRenderPipelineAsset(SerializedObject serializedObject)
        {
            asset = serializedObject.targetObject as ZNPRRenderPipelineAsset;
            this.serializedObject = serializedObject;

            hdr = serializedObject.FindProperty("m_SupportsHDR");
            hdrColorBufferPrecisionProp = serializedObject.FindProperty("m_HDRColorBufferPrecision");
            renderScale = serializedObject.FindProperty("m_RenderScale");
            srpBatcher = serializedObject.FindProperty("m_UseSRPBatcher");
            supportsDynamicBatching = serializedObject.FindProperty("m_SupportsDynamicBatching");
            useFastSRGBLinearConversion = serializedObject.FindProperty("m_UseFastSRGBLinearConversion");

            string Key = "Universal_Shadow_Setting_Unit:UI_State";
            state = new EditorPrefBoolFlags<ZEditorUtils.Unit>(Key);
        }

        /// <summary>
        /// Refreshes the serialized object
        /// </summary>
        public void Update()
        {
            serializedObject.Update();
        }

        /// <summary>
        /// Applies the modified properties of the serialized object
        /// </summary>
        public void Apply()
        {
            serializedObject.ApplyModifiedProperties();
        }
    }

}

