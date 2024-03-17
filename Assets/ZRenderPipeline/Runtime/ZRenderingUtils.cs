using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.ZRendering
{
    /// <summary>
    /// Contains properties and helper functions that you can use when rendering.
    /// </summary>
    public static class ZRenderingUtils
    {
        internal static bool SupportsLightLayers(GraphicsDeviceType type)
        {
            // GLES2 does not support bitwise operations.
            return type != GraphicsDeviceType.OpenGLES2;
        }
    }

}
