using UnityEngine;
using UnityEngine.Rendering.ZPipeline.ZUniversal;

namespace UnityEditor.Rendering.ZUniversal.Internal
{
    /// <summary>
    /// Contains a database of built-in resource GUIds. These are used to load built-in resource files.
    /// </summary>
    public static class ResourceGuid
    {
        /// <summary>
        /// GUId for the <c>ScriptableRendererFeature</c> template file.
        /// </summary>
        public static readonly string rendererTemplate = string.Empty;
    }
}

namespace UnityEditor.Rendering.ZUniversal
{
    public static partial class ZEditorUtils
    {
        public enum Unit { Metric, Percent }

        internal class Styles
        {
            //Measurements
            public static float defaultLineSpace = EditorGUIUtility.singleLineHeight + EditorGUIUtility.standardVerticalSpacing;
        }

        internal static void FeatureHelpBox(string message, MessageType type)
        {
            CoreEditorUtils.DrawFixMeBox(message, type, "Open", () =>
            {
                Selection.activeObject = ZUniversalRenderPipeline.asset.scriptableRendererData;
                GUIUtility.ExitGUI();
            });
        }

        //internal static void DrawRenderingLayerMask(SerializedProperty property, GUIContent style)
        //{
        //    Rect controlRect = EditorGUILayout.GetControlRect(true);
        //    int renderingLayer = property.intValue;

        //    string[] renderingLayerMaskNames = UniversalRenderPipelineGlobalSettings.instance.renderingLayerMaskNames;
        //    int maskCount = (int)Mathf.Log(renderingLayer, 2) + 1;
        //    if (renderingLayerMaskNames.Length < maskCount && maskCount <= 32)
        //    {
        //        var newRenderingLayerMaskNames = new string[maskCount];
        //        for (int i = 0; i < maskCount; ++i)
        //        {
        //            newRenderingLayerMaskNames[i] = i < renderingLayerMaskNames.Length ? renderingLayerMaskNames[i] : $"Unused Layer {i}";
        //        }
        //        renderingLayerMaskNames = newRenderingLayerMaskNames;

        //        EditorGUILayout.HelpBox($"One or more of the Rendering Layers is not defined in the Universal Global Settings asset.", MessageType.Warning);
        //    }

        //    EditorGUI.BeginProperty(controlRect, style, property);

        //    EditorGUI.BeginChangeCheck();
        //    renderingLayer = EditorGUI.MaskField(controlRect, style, renderingLayer, renderingLayerMaskNames);

        //    if (EditorGUI.EndChangeCheck())
        //        property.uintValue = (uint)renderingLayer;

        //    EditorGUI.EndProperty();
        //}
    }

}

