using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.ZRendering.NPR;

namespace UnityEditor.Rendering.ZRendering.NPR
{
    /// <summary>
    /// Editor script for a <c>UniversalRendererData</c> class.
    /// </summary>
    [CustomEditor(typeof(ZNPRRendererData), true)]
    public class ZNPRRendererDataEditor : ZScriptableRendererDataEditor
    {
        private static class Styles
        {
            public static readonly GUIContent RendererTitle = EditorGUIUtility.TrTextContent("Universal Renderer", "Custom Universal Renderer for Universal RP.");
            public static readonly GUIContent PostProcessIncluded = EditorGUIUtility.TrTextContent("Enabled", "Enables the use of post processing effects within the scene. If disabled, Unity excludes post processing renderer Passes, shaders and textures from the build.");
            public static readonly GUIContent PostProcessLabel = EditorGUIUtility.TrTextContent("Data", "The asset containing references to shaders and Textures that the Renderer uses for post-processing.");
            public static readonly GUIContent FilteringSectionLabel = EditorGUIUtility.TrTextContent("Filtering", "Settings that controls and define which layers the renderer draws.");
            public static readonly GUIContent OpaqueMask = EditorGUIUtility.TrTextContent("Opaque Layer Mask", "Controls which opaque layers this renderer draws.");
            public static readonly GUIContent TransparentMask = EditorGUIUtility.TrTextContent("Transparent Layer Mask", "Controls which transparent layers this renderer draws.");

            public static readonly GUIContent RenderingSectionLabel = EditorGUIUtility.TrTextContent("Rendering", "Settings related to rendering and lighting.");
            public static readonly GUIContent RenderingModeLabel = EditorGUIUtility.TrTextContent("Rendering Path", "Select a rendering path.");
            public static readonly GUIContent DepthPrimingModeLabel = EditorGUIUtility.TrTextContent("Depth Priming Mode", "With depth priming enabled, Unity uses the depth buffer generated in the depth prepass to determine if a fragment should be rendered or skipped during the Base Camera opaque pass. Disabled: Unity does not perform depth priming. Auto: If there is a Render Pass that requires a depth prepass, Unity performs the depth prepass and depth priming. Forced: Unity performs the depth prepass and depth priming.");
            public static readonly GUIContent DepthPrimingModeInfo = EditorGUIUtility.TrTextContent("On Android, iOS, and Apple TV, Unity performs depth priming only in the Forced mode. On tiled GPUs, which are common to those platforms, depth priming might reduce performance when combined with MSAA.");
            public static readonly GUIContent CopyDepthModeLabel = EditorGUIUtility.TrTextContent("Depth Texture Mode", "Controls after which pass URP copies the scene depth. It has a significant impact on mobile devices bandwidth usage. It also allows to force a depth prepass to generate it.");
            public static readonly GUIContent RenderPassLabel = EditorGUIUtility.TrTextContent("Native RenderPass", "Enables URP to use RenderPass API. Has no effect on OpenGLES2");

            public static readonly GUIContent RenderPassSectionLabel = EditorGUIUtility.TrTextContent("RenderPass", "This section contains properties related to render passes.");
            public static readonly GUIContent ShadowsSectionLabel = EditorGUIUtility.TrTextContent("Shadows", "This section contains properties related to rendering shadows.");
            public static readonly GUIContent PostProcessingSectionLabel = EditorGUIUtility.TrTextContent("Post-processing", "This section contains properties related to rendering post-processing.");

            public static readonly GUIContent OverridesSectionLabel = EditorGUIUtility.TrTextContent("Overrides", "This section contains Render Pipeline properties that this Renderer overrides.");

            public static readonly GUIContent accurateGbufferNormalsLabel = EditorGUIUtility.TrTextContent("Accurate G-buffer normals", "Normals in G-buffer use octahedron encoding/decoding. This improves visual quality but might reduce performance.");
            public static readonly GUIContent defaultStencilStateLabel = EditorGUIUtility.TrTextContent("Default Stencil State", "Configure the stencil state for the opaque and transparent render passes.");
            public static readonly GUIContent shadowTransparentReceiveLabel = EditorGUIUtility.TrTextContent("Transparent Receive Shadows", "When disabled, none of the transparent objects will receive shadows.");
            public static readonly GUIContent invalidStencilOverride = EditorGUIUtility.TrTextContent("Error: When using the deferred rendering path, the Renderer requires the control over the 4 highest bits of the stencil buffer to store Material types. The current combination of the stencil override options prevents the Renderer from controlling the required bits. Try changing one of the options to Replace.");
            public static readonly GUIContent intermediateTextureMode = EditorGUIUtility.TrTextContent("Intermediate Texture", "Controls when URP renders via an intermediate texture.");
        }


        SerializedProperty m_Shaders;

        private void OnEnable()
        {
            m_Shaders = serializedObject.FindProperty("shaders");
        }

        /// <inheritdoc/>
        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUILayout.Space();

            serializedObject.ApplyModifiedProperties();

            base.OnInspectorGUI(); // Draw the base UI, contains ScriptableRenderFeatures list

            // Add a "Reload All" button in inspector when we are in developer's mode
            if (EditorPrefs.GetBool("DeveloperMode"))
            {
                EditorGUILayout.Space();
                EditorGUILayout.PropertyField(m_Shaders, true);

                if (GUILayout.Button("Reload All"))
                {
                    var resources = target as ZNPRRendererData;
                    resources.shaders = null;
                    ResourceReloader.ReloadAllNullIn(target, ZNPRRenderPipelineAsset.packagePath);
                }
            }
        }
    }

}

