using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.ZPipeline.ZUniversal
{
    public sealed partial class ZUniversalRenderPipeline
    {
        /// <summary>
        /// The shader tag used in the Universal Render Pipeline (URP)
        /// </summary>
        public const string k_ShaderTagName = "ZNPRPipeline";

        /// <summary>
        /// The minimum value allowed for render scale.
        /// </summary>
        public static float minRenderScale
        {
            get => 0.1f;
        }

        /// <summary>
        /// The maximum value allowed for render scale.
        /// </summary>
        public static float maxRenderScale
        {
            get => 2.0f;
        }

        // Holds light direction for directional lights or position for punctual lights.
        // When w is set to 1.0, it means it's a punctual light.
        static Vector4 k_DefaultLightPosition = new Vector4(0.0f, 0.0f, 1.0f, 0.0f);
        static Vector4 k_DefaultLightColor = Color.black;

        // Default light attenuation is setup in a particular way that it causes
        // directional lights to return 1.0 for both distance and angle attenuation
        static Vector4 k_DefaultLightAttenuation = new Vector4(0.0f, 1.0f, 0.0f, 1.0f);
        static Vector4 k_DefaultLightSpotDirection = new Vector4(0.0f, 0.0f, 1.0f, 0.0f);
        static Vector4 k_DefaultLightsProbeChannel = new Vector4(0.0f, 0.0f, 0.0f, 0.0f);
    }

}

