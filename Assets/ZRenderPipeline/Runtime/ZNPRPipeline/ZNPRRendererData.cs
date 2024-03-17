using System;

#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
using ShaderKeywordFilter = UnityEditor.ShaderKeywordFilter;
#endif

namespace UnityEngine.Rendering.ZRendering.NPR
{
    [Serializable, ReloadGroup, ExcludeFromPreset]
    public class ZNPRRendererData : ZScriptableRendererData, ISerializationCallbackReceiver
    {

#if UNITY_EDITOR
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]
        internal class CreateUniversalRendererAsset : EndNameEditAction
        {
            public override void Action(int instanceId, string pathName, string resourceFile)
            {
                var instance = ZNPRRenderPipelineAsset.CreateRendererAsset(pathName, ZRendererType.ZNRPRenderer, false) as ZNPRRendererData;
                Selection.activeObject = instance;
            }
        }

        [MenuItem("Assets/Create/Rendering/ZNPR Renderer", priority = CoreUtils.Sections.section3 + CoreUtils.Priorities.assetsCreateRenderingMenuPriority + 2)]
        static void CreateUniversalRendererData()
        {
            ProjectWindowUtil.StartNameEditingIfProjectWindowExists(0, CreateInstance<CreateUniversalRendererAsset>(), "New Custom ZNPR Renderer Data.asset", null, null);
        }

#endif

        /// <summary>
        /// Class containing shader resources used in URP.
        /// </summary>
        [Serializable, ReloadGroup]
        public sealed class ShaderResources
        {
            // todo:
            public string todo = "todo";

            //// Core blitter shaders, adapted from HDRP
            //// TODO: move to core and share with HDRP
            //[Reload("Shaders/Utils/CoreBlit.shader"), SerializeField]
            //internal Shader coreBlitPS;
            //[Reload("Shaders/Utils/CoreBlitColorAndDepth.shader"), SerializeField]
            //internal Shader coreBlitColorAndDepthPS;
        }

        /// <summary>
        /// Shader resources used in URP.
        /// </summary>
        public ShaderResources shaders = null;

        protected override ZScriptableRenderer Create()
        {
            if (!Application.isPlaying)
            {
                ReloadAllNullProperties();
            }
            return new ZNRPRenderer(this);
        }

        /// <inheritdoc/>
        protected override void OnEnable()
        {
            base.OnEnable();

            // Upon asset creation, OnEnable is called and `shaders` reference is not yet initialized
            // We need to call the OnEnable for data migration when updating from old versions of UniversalRP that
            // serialized resources in a different format. Early returning here when OnEnable is called
            // upon asset creation is fine because we guarantee new assets get created with all resources initialized.
            if (shaders == null)
                return;

            ReloadAllNullProperties();
        }

        private void ReloadAllNullProperties()
        {
#if UNITY_EDITOR
            ResourceReloader.TryReloadAllNullIn(this, ZNPRRenderPipelineAsset.packagePath);
#endif
        }

        /// <inheritdoc/>
        void ISerializationCallbackReceiver.OnBeforeSerialize()
        {
            //m_AssetVersion = k_LatestAssetVersion;
        }

        /// <inheritdoc/>
        void ISerializationCallbackReceiver.OnAfterDeserialize()
        {
            //m_AssetVersion = k_LatestAssetVersion;
        }
    }

}
