using UnityEngine;
using UnityEngine.Rendering.ZPipeline.ZUniversal;

namespace UnityEditor.Rendering.ZUniversal
{
    using CED = CoreEditorDrawer<SerializedZUniversalRenderPipelineAsset>;

    internal partial class ZUniversalRenderPipelineAssetUI
    {
        enum Expandable
        {
            Rendering = 1 << 1,
            Quality = 1 << 2,
            Lighting = 1 << 3,
            Shadows = 1 << 4,
            PostProcessing = 1 << 5,
#if ADAPTIVE_PERFORMANCE_2_0_0_OR_NEWER
            AdaptivePerformance = 1 << 6,
#endif
        }

        enum ExpandableAdditional
        {
            Rendering = 1 << 1,
            Lighting = 1 << 2,
            PostProcessing = 1 << 3,
            Shadows = 1 << 4,
            Quality = 1 << 5,
        }

        internal static void RegisterEditor(ZUniversalRenderPipelineAssetEditor editor)
        {
            k_AdditionalPropertiesState.RegisterEditor(editor);
        }

        internal static void UnregisterEditor(ZUniversalRenderPipelineAssetEditor editor)
        {
            k_AdditionalPropertiesState.UnregisterEditor(editor);
        }

        [SetAdditionalPropertiesVisibility]
        internal static void SetAdditionalPropertiesVisibility(bool value)
        {
            if (value)
                k_AdditionalPropertiesState.ShowAll();
            else
                k_AdditionalPropertiesState.HideAll();
        }



        static readonly ExpandedState<Expandable, ZUniversalRenderPipelineAsset> k_ExpandedState = new(Expandable.Rendering, "ZNPR");
        readonly static AdditionalPropertiesState<ExpandableAdditional, Light> k_AdditionalPropertiesState = new(0, "ZNPR");

        public static readonly CED.IDrawer Inspector = CED.Group(
            CED.AdditionalPropertiesFoldoutGroup(Styles.renderingSettingsText, Expandable.Rendering, k_ExpandedState, ExpandableAdditional.Rendering, k_AdditionalPropertiesState, DrawRendering, DrawRenderingAdditional),
            CED.FoldoutGroup(Styles.qualitySettingsText, Expandable.Quality, k_ExpandedState, DrawQuality)
        );

        static void DrawRendering(SerializedZUniversalRenderPipelineAsset serialized, Editor ownerEditor)
        {
            if (ownerEditor is ZUniversalRenderPipelineAssetEditor urpAssetEditor)
            {
                EditorGUILayout.Space();
                urpAssetEditor.rendererList.DoLayoutList();

                if (!serialized.asset.ValidateRendererData(-1))
                    EditorGUILayout.HelpBox(Styles.rendererMissingDefaultMessage.text, MessageType.Error, true);
                else if (!serialized.asset.ValidateRendererDataList(true))
                    EditorGUILayout.HelpBox(Styles.rendererMissingMessage.text, MessageType.Warning, true);
            }
        }

        static void DrawRenderingAdditional(SerializedZUniversalRenderPipelineAsset serialized, Editor ownerEditor)
        {
            EditorGUILayout.PropertyField(serialized.srpBatcher, Styles.srpBatcher);
            EditorGUILayout.PropertyField(serialized.supportsDynamicBatching, Styles.dynamicBatching);
        }

        static void DrawQuality(SerializedZUniversalRenderPipelineAsset serialized, Editor ownerEditor)
        {
            //DrawHDR(serialized, ownerEditor);

            serialized.renderScale.floatValue = EditorGUILayout.Slider(Styles.renderScaleText, serialized.renderScale.floatValue, ZUniversalRenderPipeline.minRenderScale, ZUniversalRenderPipeline.maxRenderScale);
        }
    }

}

