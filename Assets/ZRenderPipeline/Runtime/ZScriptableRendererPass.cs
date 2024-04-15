using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;


namespace UnityEngine.Rendering.ZPipeline
{
    [ExcludeFromPreset]
    public abstract class ZScriptableRendererPass : ScriptableObject, IDisposable
    {

        #region fields

        #endregion

        #region properties

        #endregion

        #region life cycle

        #endregion

        #region interface

        #endregion

        #region local method

        #endregion


        [SerializeField, ZCameraType]
        private int m_CameraMask = 7;

        public virtual string PassName => this.GetType().Name;

        public int CameraMaks => m_CameraMask;


        [SerializeField, HideInInspector] private bool m_Active = true;
        /// <summary>
        /// Returns the state of the ScriptableRenderFeature (true: the feature is active, false: the feature is inactive). Use the method ScriptableRenderFeature.SetActive to change the value of this variable.
        /// </summary>
        public bool isActive => m_Active;

        /// <summary>
        /// Initializes this feature's resources. This is called every time serialization happens.
        /// </summary>
        public virtual void Create() { }

        void OnEnable()
        {
            Create();
        }

        void OnValidate()
        {
            Create();
        }

        /// <summary>
        /// Sets the state of ScriptableRenderFeature (true: the feature is active, false: the feature is inactive).
        /// If the feature is active, it is added to the renderer it is attached to, otherwise the feature is skipped while rendering.
        /// </summary>
        /// <param name="active">The true value activates the ScriptableRenderFeature and the false value deactivates it.</param>
        public void SetActive(bool active)
        {
            m_Active = active;
        }

        /// <summary>
        /// Disposable pattern implementation.
        /// </summary>
        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        /// <summary>
        /// Called by Dispose().
        /// Override this function to clean up resources in your renderer.
        /// </summary>
        /// <param name="disposing"></param>
        protected virtual void Dispose(bool disposing)
        { 
        }

        public virtual bool IsValidPass()
        {
            return true;
        }

        public virtual void SetupRendererPass(CommandBuffer cmd, ref ZRenderingData renderingData) { }
        public abstract void ExecuRendererPass(ScriptableRenderContext context, CommandBuffer cmd, ref ZRenderingData renderingData);
        public virtual void OnFrameEnd(CommandBuffer cmd) { }
    }


    public enum ZRenderView
    {
        None = 0,
        Scene = 1,
        Game = 2,
        Preview = 4,
    }


    public sealed class ZCameraTypeAttribute : PropertyAttribute
    {
        public ZCameraTypeAttribute()
        {

        }
    }

#if UNITY_EDITOR

    [UnityEditor.CustomPropertyDrawer(typeof(ZCameraTypeAttribute))]
    public sealed class ZCameraTypeDrawer : UnityEditor.PropertyDrawer
    {

        static string[] g_CameraTypes = new string[] { "Game", "Scene", "Preview" }; 

        public override void OnGUI(Rect position, UnityEditor.SerializedProperty property, GUIContent label)
        {
            property.intValue = UnityEditor.EditorGUILayout.MaskField("目标相机", property.intValue, g_CameraTypes);
        }

        public override float GetPropertyHeight(UnityEditor.SerializedProperty property, GUIContent label)
        {
            return base.GetPropertyHeight(property, label) - 15;
        }
    }
#endif
}
