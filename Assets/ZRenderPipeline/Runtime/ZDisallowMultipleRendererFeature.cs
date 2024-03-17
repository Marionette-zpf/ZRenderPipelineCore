
using System;

namespace UnityEngine.Rendering.ZRendering
{
    /// <summary>
    ///   <para>Prevents <c>ScriptableRendererFeatures</c> of same type to be added more than once to a Scriptable Renderer.</para>
    /// </summary>
    [AttributeUsage(AttributeTargets.Class)]
    public class ZDisallowMultipleRendererFeature : Attribute
    {
        /// <summary>
        /// Set the custom title for renderer feature.
        /// </summary>
        public string customTitle { private set; get; }

        /// <summary>
        /// Constructor for the attribute to prevent <c>ScriptableRendererFeatures</c> of same type to be added more than once to a Scriptable Renderer.
        /// </summary>
        /// <param name="customTitle">Sets the custom title for renderer feature.</param>
        public ZDisallowMultipleRendererFeature(string customTitle = null)
        {
            this.customTitle = customTitle;
        }
    }

}

