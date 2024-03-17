using System;
using System.Reflection;
using System.Collections.Generic;

#if UNITY_EDITOR
using System.Linq;
using UnityEditor;
using ShaderKeywordFilter = UnityEditor.ShaderKeywordFilter;
#endif

namespace UnityEngine.Rendering.ZPipeline
{
    public abstract class ZScriptableRendererData : ScriptableObject
    {
        
        internal bool isInvalidated { get; set; }

        /// <summary>
        /// Class contains references to shader resources used by Rendering Debugger.
        /// </summary>
        [Serializable, ReloadGroup]
        public sealed class DebugShaderResources
        {
            ///// <summary>
            ///// Debug shader used to output interpolated vertex attributes.
            ///// </summary>
            //[Reload("Shaders/Debug/DebugReplacement.shader")]
            //public Shader debugReplacementPS;

            ///// <summary>
            ///// Debug shader used to output HDR Chromacity mapping.
            ///// </summary>
            //[Reload("Shaders/Debug/HDRDebugView.shader")]
            //public Shader hdrDebugViewPS;
        }

        /// <summary>
        /// Container for shader resources used by Rendering Debugger.
        /// </summary>
        public DebugShaderResources debugShaders;

        /// <summary>
        /// Creates the instance of the ScriptableRenderer.
        /// </summary>
        /// <returns>The instance of ScriptableRenderer</returns>
        protected abstract ZScriptableRenderer Create();

        [SerializeField] internal List<ZScriptableRendererPass> m_RendererFeatures = new List<ZScriptableRendererPass>(10);
        [SerializeField] internal List<long> m_RendererFeatureMap = new List<long>(10);

        /// <summary>
        /// List of additional render pass features for this renderer.
        /// </summary>
        public List<ZScriptableRendererPass> rendererFeatures
        {
            get => m_RendererFeatures;
        }

        /// <summary>
        /// Use SetDirty when changing seeings in the ScriptableRendererData.
        /// It will rebuild the render passes with the new data.
        /// </summary>
        public new void SetDirty()
        {
            isInvalidated = true;
        }

        internal ZScriptableRenderer InternalCreateRenderer()
        {
            isInvalidated = false;
            return Create();
        }

        /// <summary>
        /// Editor-only function that Unity calls when the script is loaded or a value changes in the Inspector.
        /// </summary>
        protected virtual void OnValidate()
        {
            SetDirty();
#if UNITY_EDITOR
            if (m_RendererFeatures.Contains(null))
                ValidateRendererFeatures();
#endif
        }

        /// <summary>
        /// This function is called when the object becomes enabled and active.
        /// </summary>
        protected virtual void OnEnable()
        {
            SetDirty();
        }

        /// <summary>
        /// Returns true if contains renderer feature with specified type.
        /// </summary>
        /// <typeparam name="T">Renderer Feature type.</typeparam>
        /// <returns></returns>
        internal bool TryGetRendererFeature<T>(out T rendererFeature) where T : ZScriptableRendererPass
        {
            foreach (var target in rendererFeatures)
            {
                if (target.GetType() == typeof(T))
                {
                    rendererFeature = target as T;
                    return true;
                }
            }
            rendererFeature = null;
            return false;
        }

#if UNITY_EDITOR
        internal virtual Material GetDefaultMaterial(ZDefaultMaterialType materialType)
        {
            return null;
        }

        internal virtual Shader GetDefaultShader()
        {
            return null;
        }

        internal bool ValidateRendererFeatures()
        {
            // Get all Subassets
            var subassets = AssetDatabase.LoadAllAssetsAtPath(AssetDatabase.GetAssetPath(this));
            var linkedIds = new List<long>();
            var loadedAssets = new Dictionary<long, object>();
            var mapValid = m_RendererFeatureMap != null && m_RendererFeatureMap?.Count == m_RendererFeatures?.Count;
            var debugOutput = $"{name}\nValid Sub-assets:\n";

            // Collect valid, compiled sub-assets
            foreach (var asset in subassets)
            {
                if (asset == null || asset.GetType().BaseType != typeof(ZScriptableRendererPass)) continue;
                AssetDatabase.TryGetGUIDAndLocalFileIdentifier(asset, out var guid, out long localId);
                loadedAssets.Add(localId, asset);
                debugOutput += $"-{asset.name}\n--localId={localId}\n";
            }

            // Collect assets that are connected to the list
            for (var i = 0; i < m_RendererFeatures?.Count; i++)
            {
                if (!m_RendererFeatures[i]) continue;
                if (AssetDatabase.TryGetGUIDAndLocalFileIdentifier(m_RendererFeatures[i], out var guid, out long localId))
                {
                    linkedIds.Add(localId);
                }
            }

            var mapDebug = mapValid ? "Linking" : "Map missing, will attempt to re-map";
            debugOutput += $"Feature List Status({mapDebug}):\n";

            // Try fix missing references
            for (var i = 0; i < m_RendererFeatures?.Count; i++)
            {
                if (m_RendererFeatures[i] == null)
                {
                    if (mapValid && m_RendererFeatureMap[i] != 0)
                    {
                        var localId = m_RendererFeatureMap[i];
                        loadedAssets.TryGetValue(localId, out var asset);
                        m_RendererFeatures[i] = (ZScriptableRendererPass)asset;
                    }
                    else
                    {
                        m_RendererFeatures[i] = (ZScriptableRendererPass)GetUnusedAsset(ref linkedIds, ref loadedAssets);
                    }
                }

                debugOutput += m_RendererFeatures[i] != null ? $"-{i}:Linked\n" : $"-{i}:Missing\n";
            }

            UpdateMap();

            if (!m_RendererFeatures.Contains(null))
                return true;

            Debug.LogError($"{name} is missing RendererFeatures\nThis could be due to missing scripts or compile error.", this);
            return false;
        }

        internal bool DuplicateFeatureCheck(Type type)
        {
            Attribute isSingleFeature = type.GetCustomAttribute(typeof(ZDisallowMultipleRendererFeature));
            if (isSingleFeature == null)
                return false;

            if (m_RendererFeatures == null)
                return false;

            for (int i = 0; i < m_RendererFeatures.Count; i++)
            {
                ZScriptableRendererPass feature = m_RendererFeatures[i];
                if (feature == null)
                    continue;

                if (feature.GetType() == type)
                    return true;
            }

            return false;
        }

        private static object GetUnusedAsset(ref List<long> usedIds, ref Dictionary<long, object> assets)
        {
            foreach (var asset in assets)
            {
                var alreadyLinked = usedIds.Any(used => asset.Key == used);

                if (alreadyLinked)
                    continue;

                usedIds.Add(asset.Key);
                return asset.Value;
            }

            return null;
        }

        private void UpdateMap()
        {
            if (m_RendererFeatureMap.Count != m_RendererFeatures.Count)
            {
                m_RendererFeatureMap.Clear();
                m_RendererFeatureMap.AddRange(new long[m_RendererFeatures.Count]);
            }

            for (int i = 0; i < rendererFeatures.Count; i++)
            {
                if (m_RendererFeatures[i] == null) continue;
                if (!AssetDatabase.TryGetGUIDAndLocalFileIdentifier(m_RendererFeatures[i], out var guid, out long localId)) continue;

                m_RendererFeatureMap[i] = localId;
            }
        }

#endif
    }

}

