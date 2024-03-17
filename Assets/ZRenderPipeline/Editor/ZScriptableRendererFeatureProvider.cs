using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.ZPipeline;


namespace UnityEditor.Rendering.ZUniversal
{
    public class ZScriptableRendererFeatureProvider : FilterWindow.IProvider
    {
        class FeatureElement : FilterWindow.Element
        {
            public Type type;
        }

        readonly ZScriptableRendererDataEditor m_Editor;
        public Vector2 position { get; set; }

        public ZScriptableRendererFeatureProvider(ZScriptableRendererDataEditor editor)
        {
            m_Editor = editor;
        }

        public void CreateComponentTree(List<FilterWindow.Element> tree)
        {
            tree.Add(new FilterWindow.GroupElement(0, "Renderer Features"));
            var types = TypeCache.GetTypesDerivedFrom<ZScriptableRendererPass>();
            var data = m_Editor.target as ZScriptableRendererData;
            foreach (var type in types)
            {
                if (data.DuplicateFeatureCheck(type))
                {
                    continue;
                }

                string path = GetMenuNameFromType(type);
                tree.Add(new FeatureElement
                {
                    content = new GUIContent(path),
                    level = 1,
                    type = type
                });
            }
        }

        public bool GoToChild(FilterWindow.Element element, bool addIfComponent)
        {
            if (element is FeatureElement featureElement)
            {
                m_Editor.AddComponent(featureElement.type.Name);
                return true;
            }

            return false;
        }

        string GetMenuNameFromType(Type type)
        {
            string path;
            if (!m_Editor.GetCustomTitle(type, out path))
            {
                path = ObjectNames.NicifyVariableName(type.Name);
            }

            if (type.Namespace != null)
            {
                if (type.Namespace.Contains("Experimental"))
                    path += " (Experimental)";
            }

            return path;
        }

    }


}

