using System;
using System.IO;
using System.Linq;

#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
using UnityEditorInternal;
using ShaderKeywordFilter = UnityEditor.ShaderKeywordFilter;
#endif

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    [ExcludeFromPreset]
    public class ZUniversalRenderPipelineAsset : RenderPipelineAsset, ISerializationCallbackReceiver
    {
        Shader m_DefaultShader;
        ZScriptableRenderer[] m_Renderers = new ZScriptableRenderer[1];

        // Default values set when a new UniversalRenderPipeline asset is created
        [SerializeField] int k_AssetVersion = 11;
        [SerializeField] int k_AssetPreviousVersion = 11;

        // Deprecated settings for upgrading sakes
        //[SerializeField] ZRendererType m_RendererType = ZRendererType.ZNRPRenderer;

        // Renderer settings
        [SerializeField] internal ZScriptableRendererData[] m_RendererDataList = new ZScriptableRendererData[1];
        [SerializeField] internal int m_DefaultRendererIndex = 0;


        // Quality settings
        [SerializeField] bool m_SupportsHDR = true;
        [SerializeField] ZHDRColorBufferPrecision m_HDRColorBufferPrecision = ZHDRColorBufferPrecision._32Bits;
        [SerializeField] float m_RenderScale = 1.0f;

        // Post-processing settings
        [SerializeField] bool m_UseFastSRGBLinearConversion = false;

        // Advanced settings
        [SerializeField] bool m_UseSRPBatcher = true;
        //[SerializeField] bool m_SupportsDynamicBatching = false;


#if UNITY_EDITOR
        [NonSerialized]
        internal ZUniversalRenderPipelineEditorResources m_EditorResourcesAsset;

        public static readonly string packagePath = string.Empty;
        public static readonly string editorResourcesGUID = string.Empty;

        public static ZUniversalRenderPipelineAsset Create(ZScriptableRendererData rendererData = null)
        {
            // Create Universal RP Asset
            var instance = CreateInstance<ZUniversalRenderPipelineAsset>();
            if (rendererData != null)
                instance.m_RendererDataList[0] = rendererData;
            else
                instance.m_RendererDataList[0] = CreateInstance<ZUniversalRendererData>();

            // Initialize default Renderer
            instance.m_EditorResourcesAsset = instance.editorResources;

            ResourceReloader.ReloadAllNullIn(instance, packagePath);

            return instance;
        }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]
        internal class CreateUniversalPipelineAsset : EndNameEditAction
        {
            public override void Action(int instanceId, string pathName, string resourceFile)
            {
                //Create asset
                AssetDatabase.CreateAsset(Create(CreateRendererAsset(pathName, ZRendererType.ZNRPRenderer)), pathName);
            }
        }

        [MenuItem("Assets/Create/Rendering/ZRP Asset (with NPR Renderer)", priority = CoreUtils.Sections.section2 + CoreUtils.Priorities.assetsCreateRenderingMenuPriority + 1)]
        static void CreateUniversalPipeline()
        {
            ProjectWindowUtil.StartNameEditingIfProjectWindowExists(0, CreateInstance<CreateUniversalPipelineAsset>(),
                "New ZNPR Render Pipeline Asset.asset", null, null);
        }


        internal static ZScriptableRendererData CreateRendererAsset(string path, ZRendererType type, bool relativePath = true, string suffix = "Renderer")
        {
            ZScriptableRendererData data = CreateRendererData(type);
            string dataPath;
            if (relativePath)
                dataPath =
                    $"{Path.Combine(Path.GetDirectoryName(path), Path.GetFileNameWithoutExtension(path))}_{suffix}{Path.GetExtension(path)}";
            else
                dataPath = path;
            AssetDatabase.CreateAsset(data, dataPath);
            ResourceReloader.ReloadAllNullIn(data, packagePath);
            return data;
        }

        static ZScriptableRendererData CreateRendererData(ZRendererType type)
        {
            switch (type)
            {
                case ZRendererType.ZNRPRenderer:
                default:
                    {
                        var rendererData = CreateInstance<ZUniversalRendererData>();
                        return rendererData;
                    }
            }
        }

        ZUniversalRenderPipelineEditorResources editorResources
        {
            get
            {
                if (m_EditorResourcesAsset != null && !m_EditorResourcesAsset.Equals(null))
                    return m_EditorResourcesAsset;

                string resourcePath = AssetDatabase.GUIDToAssetPath(editorResourcesGUID);
                var objs = InternalEditorUtility.LoadSerializedFileAndForget(resourcePath);
                m_EditorResourcesAsset = objs != null && objs.Length > 0 ? objs.First() as ZUniversalRenderPipelineEditorResources : null;
                return m_EditorResourcesAsset;
            }
        }

#endif

        /// <summary>
        /// Creates a <c>UniversalRenderPipeline</c> from the <c>UniversalRenderPipelineAsset</c>.
        /// </summary>
        /// <returns>Returns a <c>UniversalRenderPipeline</c> created from this UniversalRenderPipelineAsset.</returns>
        /// <see cref="RenderPipeline"/>
        protected override RenderPipeline CreatePipeline()
        {
            if (m_RendererDataList == null)
                m_RendererDataList = new ZScriptableRendererData[1];

            // If no default data we can't create pipeline instance
            if (m_RendererDataList[m_DefaultRendererIndex] == null)
            {
                // If previous version and current version are miss-matched then we are waiting for the upgrader to kick in
                if (k_AssetPreviousVersion != k_AssetVersion)
                    return null;

                Debug.LogError(
                    $"Default Renderer is missing, make sure there is a Renderer assigned as the default on the current ZNPR RP asset:{ZUniversalRenderPipeline.asset.name}",
                    this);
                return null;
            }

            DestroyRenderers();
            var pipeline = new ZUniversalRenderPipeline(this);
            CreateRenderers();


            // todo : 
            // Blitter can only be initialized after renderers have been created and ResourceReloader has been
            // called on potentially empty shader resources
            //foreach (var data in m_RendererDataList)
            //{
            //    if (data is ZNPRRendererData universalData)
            //    {
            //        Blitter.Initialize(universalData.shaders.coreBlitPS, universalData.shaders.coreBlitColorAndDepthPS);
            //        break;
            //    }
            //}

            return pipeline;
        }

        internal void DestroyRenderers()
        {
            if (m_Renderers == null)
                return;

            for (int i = 0; i < m_Renderers.Length; i++)
                DestroyRenderer(ref m_Renderers[i]);
        }

        void DestroyRenderer(ref ZScriptableRenderer renderer)
        {
            if (renderer != null)
            {
                renderer.Dispose();
                renderer = null;
            }
        }

        /// <summary>
        /// Unity calls this function when it loads the asset or when the asset is changed with the Inspector.
        /// </summary>
        protected override void OnValidate()
        {
            DestroyRenderers();

            // This will call RenderPipelineManager.CleanupRenderPipeline that in turn disposes the render pipeline instance and
            // assign pipeline asset reference to null
            base.OnValidate();
        }

        /// <summary>
        /// Unity calls this function when the asset is disabled.
        /// </summary>
        protected override void OnDisable()
        {
            DestroyRenderers();

            // This will call RenderPipelineManager.CleanupRenderPipeline that in turn disposes the render pipeline instance and
            // assign pipeline asset reference to null
            base.OnDisable();
        }

        void CreateRenderers()
        {
            if (m_Renderers != null)
            {
                for (int i = 0; i < m_Renderers.Length; ++i)
                {
                    if (m_Renderers[i] != null)
                        Debug.LogError($"Creating renderers but previous instance wasn't properly destroyed: m_Renderers[{i}]");
                }
            }

            if (m_Renderers == null || m_Renderers.Length != m_RendererDataList.Length)
                m_Renderers = new ZScriptableRenderer[m_RendererDataList.Length];

            for (int i = 0; i < m_RendererDataList.Length; ++i)
            {
                if (m_RendererDataList[i] != null)
                    m_Renderers[i] = m_RendererDataList[i].InternalCreateRenderer();
            }
        }

        Material GetMaterial(ZDefaultMaterialType materialType)
        {
#if UNITY_EDITOR
            if (scriptableRendererData == null || editorResources == null)
                return null;

            var material = scriptableRendererData.GetDefaultMaterial(materialType);
            if (material != null)
                return material;

            switch (materialType)
            {
                case ZDefaultMaterialType.Standard:
                    return editorResources.materials.lit;

                case ZDefaultMaterialType.Particle:
                    return editorResources.materials.particleLit;

                case ZDefaultMaterialType.Terrain:
                    return editorResources.materials.terrainLit;

                case ZDefaultMaterialType.Decal:
                    return editorResources.materials.decal;

                // Unity Builtin Default
                default:
                    return null;
            }
#else
            return null;
#endif
        }

        /// <summary>
        /// Returns the default renderer being used by this pipeline.
        /// </summary>
        public ZScriptableRenderer scriptableRenderer
        {
            get
            {
                if (m_RendererDataList?.Length > m_DefaultRendererIndex && m_RendererDataList[m_DefaultRendererIndex] == null)
                {
                    Debug.LogError("Default renderer is missing from the current Pipeline Asset.", this);
                    return null;
                }

                if (scriptableRendererData.isInvalidated || m_Renderers[m_DefaultRendererIndex] == null)
                {
                    DestroyRenderer(ref m_Renderers[m_DefaultRendererIndex]);
                    m_Renderers[m_DefaultRendererIndex] = scriptableRendererData.InternalCreateRenderer();
                }

                return m_Renderers[m_DefaultRendererIndex];
            }
        }

        /// <summary>
        /// Returns a renderer from the current pipeline asset
        /// </summary>
        /// <param name="index">Index to the renderer. If invalid index is passed, the default renderer is returned instead.</param>
        /// <returns></returns>
        public ZScriptableRenderer GetRenderer(int index)
        {
            if (index == -1)
                index = m_DefaultRendererIndex;

            if (index >= m_RendererDataList.Length || index < 0 || m_RendererDataList[index] == null)
            {
                Debug.LogWarning(
                    $"Renderer at index {index.ToString()} is missing, falling back to Default Renderer {m_RendererDataList[m_DefaultRendererIndex].name}",
                    this);
                index = m_DefaultRendererIndex;
            }

            // RendererData list differs from RendererList. Create RendererList.
            if (m_Renderers == null || m_Renderers.Length < m_RendererDataList.Length)
            {
                DestroyRenderers();
                CreateRenderers();
            }

            // This renderer data is outdated or invalid, we recreate the renderer
            // so we construct all render passes with the updated data
            if (m_RendererDataList[index].isInvalidated || m_Renderers[index] == null)
            {
                DestroyRenderer(ref m_Renderers[index]);
                m_Renderers[index] = m_RendererDataList[index].InternalCreateRenderer();
            }

            return m_Renderers[index];
        }

        internal ZScriptableRendererData scriptableRendererData
        {
            get
            {
                if (m_RendererDataList[m_DefaultRendererIndex] == null)
                    CreatePipeline();

                return m_RendererDataList[m_DefaultRendererIndex];
            }
        }


#if UNITY_EDITOR
        internal GUIContent[] rendererDisplayList
        {
            get
            {
                GUIContent[] list = new GUIContent[m_RendererDataList.Length + 1];
                list[0] = new GUIContent($"Default Renderer ({RendererDataDisplayName(m_RendererDataList[m_DefaultRendererIndex])})");

                for (var i = 1; i < list.Length; i++)
                {
                    list[i] = new GUIContent($"{(i - 1).ToString()}: {RendererDataDisplayName(m_RendererDataList[i - 1])}");
                }
                return list;
            }
        }

        string RendererDataDisplayName(ZScriptableRendererData data)
        {
            if (data != null)
                return data.name;

            return "NULL (Missing RendererData)";
        }

#endif

        internal int[] rendererIndexList
        {
            get
            {
                int[] list = new int[m_RendererDataList.Length + 1];
                for (int i = 0; i < list.Length; i++)
                {
                    list[i] = i - 1;
                }
                return list;
            }
        }

        /// <summary>
        /// When enabled, the camera renders to HDR buffers. This setting can be overridden per camera.
        /// </summary>
        /// <see href="https://docs.unity3d.com/Manual/HDR.html"/>
        public bool supportsHDR
        {
            get { return m_SupportsHDR; }
            set { m_SupportsHDR = value; }
        }

        /// <summary>
        /// Graphics format requested for HDR color buffers.
        /// </summary>
        public ZHDRColorBufferPrecision hdrColorBufferPrecision
        {
            get { return m_HDRColorBufferPrecision; }
            set { m_HDRColorBufferPrecision = value; }
        }

        /// <summary>
        /// Specifies the render scale which scales the render target resolution used by this <c>UniversalRenderPipelineAsset</c>.
        /// </summary>
        public float renderScale
        {
            get { return m_RenderScale; }
            set { m_RenderScale = ValidateRenderScale(value); }
        }

        /// <summary>
        /// Specifies if SRPBacher is used by this <c>UniversalRenderPipelineAsset</c>.
        /// </summary>
        /// <see href="https://docs.unity3d.com/Manual/SRPBatcher.html"/>
        public bool useSRPBatcher
        {
            get { return m_UseSRPBatcher; }
            set { m_UseSRPBatcher = value; }
        }

        /// <summary>
        /// Returns true if fast approximation functions are used when converting between the sRGB and Linear color spaces, false otherwise.
        /// </summary>
        public bool useFastSRGBLinearConversion
        {
            get { return m_UseFastSRGBLinearConversion; }
        }

        #region todo : default materials and shaders

        //        /// <summary>
        //        /// Returns the default Material.
        //        /// </summary>
        //        /// <returns>Returns the default Material.</returns>
        //        public override Material defaultMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.Standard); }
        //        }

        //        /// <summary>
        //        /// Returns the default particle Material.
        //        /// </summary>
        //        /// <returns>Returns the default particle Material.</returns>
        //        public override Material defaultParticleMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.Particle); }
        //        }

        //        /// <summary>
        //        /// Returns the default line Material.
        //        /// </summary>
        //        /// <returns>Returns the default line Material.</returns>
        //        public override Material defaultLineMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.Particle); }
        //        }

        //        /// <summary>
        //        /// Returns the default terrain Material.
        //        /// </summary>
        //        /// <returns>Returns the default terrain Material.</returns>
        //        public override Material defaultTerrainMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.Terrain); }
        //        }

        //        /// <summary>
        //        /// Returns the default UI Material.
        //        /// </summary>
        //        /// <returns>Returns the default UI Material.</returns>
        //        public override Material defaultUIMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.UnityBuiltinDefault); }
        //        }

        //        /// <summary>
        //        /// Returns the default UI overdraw Material.
        //        /// </summary>
        //        /// <returns>Returns the default UI overdraw Material.</returns>
        //        public override Material defaultUIOverdrawMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.UnityBuiltinDefault); }
        //        }

        //        /// <summary>
        //        /// Returns the default UIETC1 supported Material for this asset.
        //        /// </summary>
        //        /// <returns>Returns the default UIETC1 supported Material.</returns>
        //        public override Material defaultUIETC1SupportedMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.UnityBuiltinDefault); }
        //        }

        //        /// <summary>
        //        /// Returns the default material for the 2D renderer.
        //        /// </summary>
        //        /// <returns>Returns the material containing the default lit and unlit shader passes for sprites in the 2D renderer.</returns>
        //        public override Material default2DMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.Sprite); }
        //        }

        //        /// <summary>
        //        /// Returns the default sprite mask material for the 2D renderer.
        //        /// </summary>
        //        /// <returns>Returns the material containing the default shader pass for sprite mask in the 2D renderer.</returns>
        //        public override Material default2DMaskMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.SpriteMask); }
        //        }

        //        /// <summary>
        //        /// Returns the Material that Unity uses to render decals.
        //        /// </summary>
        //        /// <returns>Returns the Material containing the Unity decal shader.</returns>
        //        public Material decalMaterial
        //        {
        //            get { return GetMaterial(ZDefaultMaterialType.Decal); }
        //        }

        //        /// <summary>
        //        /// Returns the default shader for the specified renderer. When creating new objects in the editor, the materials of those objects will use the selected default shader.
        //        /// </summary>
        //        /// <returns>Returns the default shader for the specified renderer.</returns>
        //        public override Shader defaultShader
        //        {
        //            get
        //            {
        //#if UNITY_EDITOR
        //                // TODO: When importing project, AssetPreviewUpdater:CreatePreviewForAsset will be called multiple time
        //                // which in turns calls this property to get the default shader.
        //                // The property should never return null as, when null, it loads the data using AssetDatabase.LoadAssetAtPath.
        //                // However it seems there's an issue that LoadAssetAtPath will not load the asset in some cases. so adding the null check
        //                // here to fix template tests.
        //                if (scriptableRendererData != null)
        //                {
        //                    Shader defaultShader = scriptableRendererData.GetDefaultShader();
        //                    if (defaultShader != null)
        //                        return defaultShader;
        //                }

        //                if (m_DefaultShader == null)
        //                {
        //                    string path = AssetDatabase.GUIDToAssetPath(ShaderUtils.GetShaderGUID(ShaderPathID.Lit));
        //                    m_DefaultShader = AssetDatabase.LoadAssetAtPath<Shader>(path);
        //                }
        //#endif

        //                if (m_DefaultShader == null)
        //                    m_DefaultShader = Shader.Find(ShaderUtils.GetShaderPath(ShaderPathID.Lit));

        //                return m_DefaultShader;
        //            }
        //        }

        //#if UNITY_EDITOR
        //        /// <summary>
        //        /// Returns the Autodesk Interactive shader that this asset uses.
        //        /// </summary>
        //        /// <returns>Returns the Autodesk Interactive shader that this asset uses.</returns>
        //        public override Shader autodeskInteractiveShader
        //        {
        //            get { return editorResources?.shaders.autodeskInteractivePS; }
        //        }

        //        /// <summary>
        //        /// Returns the Autodesk Interactive transparent shader that this asset uses.
        //        /// </summary>
        //        /// <returns>Returns the Autodesk Interactive transparent shader that this asset uses.</returns>
        //        public override Shader autodeskInteractiveTransparentShader
        //        {
        //            get { return editorResources?.shaders.autodeskInteractiveTransparentPS; }
        //        }

        //        /// <summary>
        //        /// Returns the Autodesk Interactive mask shader that this asset uses.
        //        /// </summary>
        //        /// <returns>Returns the Autodesk Interactive mask shader that this asset uses</returns>
        //        public override Shader autodeskInteractiveMaskedShader
        //        {
        //            get { return editorResources?.shaders.autodeskInteractiveMaskedPS; }
        //        }

        //        /// <summary>
        //        /// Returns the terrain detail lit shader that this asset uses.
        //        /// </summary>
        //        /// <returns>Returns the terrain detail lit shader that this asset uses.</returns>
        //        public override Shader terrainDetailLitShader
        //        {
        //            get { return editorResources?.shaders.terrainDetailLitPS; }
        //        }

        //        /// <summary>
        //        /// Returns the terrain detail grass shader that this asset uses.
        //        /// </summary>
        //        /// <returns>Returns the terrain detail grass shader that this asset uses.</returns>
        //        public override Shader terrainDetailGrassShader
        //        {
        //            get { return editorResources?.shaders.terrainDetailGrassPS; }
        //        }

        //        /// <summary>
        //        /// Returns the terrain detail grass billboard shader that this asset uses.
        //        /// </summary>
        //        /// <returns>Returns the terrain detail grass billboard shader that this asset uses.</returns>
        //        public override Shader terrainDetailGrassBillboardShader
        //        {
        //            get { return editorResources?.shaders.terrainDetailGrassBillboardPS; }
        //        }

        //        /// <summary>
        //        /// Returns the default SpeedTree7 shader that this asset uses.
        //        /// </summary>
        //        /// <returns>Returns the default SpeedTree7 shader that this asset uses.</returns>
        //        public override Shader defaultSpeedTree7Shader
        //        {
        //            get { return editorResources?.shaders.defaultSpeedTree7PS; }
        //        }

        //        /// <summary>
        //        /// Returns the default SpeedTree8 shader that this asset uses.
        //        /// </summary>
        //        /// <returns>Returns the default SpeedTree8 shader that this asset uses.</returns>
        //        public override Shader defaultSpeedTree8Shader
        //        {
        //            get { return editorResources?.shaders.defaultSpeedTree8PS; }
        //        }

        //        /// <inheritdoc/>
        //        public override string renderPipelineShaderTag => ZNPRRenderPipeline.k_ShaderTagName;
        //#endif

        #endregion


        /// <summary>
        /// Unity raises a callback to this method before it serializes the asset.
        /// </summary>
        public void OnBeforeSerialize()
        {
        }

        /// <summary>
        /// Unity raises a callback to this method after it deserializes the asset.
        /// </summary>
        public void OnAfterDeserialize()
        {
        }

        float ValidateRenderScale(float value)
        {
            return Mathf.Max(ZUniversalRenderPipeline.minRenderScale, Mathf.Min(value, ZUniversalRenderPipeline.maxRenderScale));
        }

        /// <summary>
        /// Check to see if the RendererData list contains valid RendererData references.
        /// </summary>
        /// <param name="partial">This bool controls whether to test against all or any, if false then there has to be no invalid RendererData</param>
        /// <returns></returns>
        internal bool ValidateRendererDataList(bool partial = false)
        {
            var emptyEntries = 0;
            for (int i = 0; i < m_RendererDataList.Length; i++) emptyEntries += ValidateRendererData(i) ? 0 : 1;
            if (partial)
                return emptyEntries == 0;
            return emptyEntries != m_RendererDataList.Length;
        }

        internal bool ValidateRendererData(int index)
        {
            // Check to see if you are asking for the default renderer
            if (index == -1) index = m_DefaultRendererIndex;
            return index < m_RendererDataList.Length ? m_RendererDataList[index] != null : false;
        }

    }



    /// <summary>
    /// Options to select the type of Renderer to use.
    /// </summary>
    public enum ZRendererType
    {

        ZNRPRenderer,
    }

}

