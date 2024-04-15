using System;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Panda.ShaderPropertiesGUI
{
    public class GroupDrawer : MaterialPropertyDrawer
    {
#if UNITY_STANDALONE
        private static readonly string s_PlatformInfo = "目标平台" + " => PC 平台";
#else
	private static readonly string s_PlatformInfo = "目标平台" + " => Mobile 平台";
#endif

        private static readonly float s_BoxHeight = 25.0f;
        private static readonly float s_TipHeight = 20.0f;

        private bool m_IsFolding;
        private bool m_IsKey;

        private float m_Top;

        private string m_Key;

        private Material m_TargetMat;

        public GroupDrawer()
        {

        }
        public GroupDrawer(string key)
        {
            m_Key = key;
        }

        public GroupDrawer(float top)
        {
            m_Top = top;
        }

        public GroupDrawer(float top, string key)
        {
            m_Top = top;
            m_Key = key;
        }

        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            m_TargetMat = editor.target as Material;

            m_IsKey = !string.IsNullOrEmpty(m_Key) && !DrawerUtilities.IsKeyEnable(m_TargetMat, m_Key);

            if (m_IsKey)
            {
                prop.floatValue = 0.0f;

                return;
            }


            if (IsGuiTop())
            {
                GUI.Label(position, s_PlatformInfo, new GUIStyle("flow varPin tooltip"));

                position.y += s_TipHeight;
            }

            var style = new GUIStyle("ShurikenModuleTitle");
            style.border	  = new RectOffset(15, 7, 4, 4);
            style.fixedHeight = s_BoxHeight;
            style.font		  = new GUIStyle(EditorStyles.boldLabel).font;
            style.fontStyle   = FontStyle.Bold;
            style.fontSize    = (int)(style.fontSize * 1.2f);
            style.alignment   = TextAnchor.MiddleCenter;


            var rect = position;
            m_IsFolding = prop.floatValue == 1.0f;

            GUI.backgroundColor = m_IsFolding ? Color.white : new Color(0.85f, 0.85f, 0.85f);
            GUI.Box(rect, label, style);
            GUI.backgroundColor = Color.white;

            if (IsGuiTop())
                rect.height -= s_TipHeight;

            var e = Event.current;
            if (e.type == EventType.MouseDown && rect.Contains(e.mousePosition))
            {
                m_IsFolding = !m_IsFolding;
                e.Use();
            }

            prop.floatValue = m_IsFolding ? 1.0f : 0.0f;
        }

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return IsGuiTop() ? (s_TipHeight + (m_IsFolding ? s_BoxHeight : s_BoxHeight - 5)) : (m_IsKey ? 0.0f : s_BoxHeight);
        }

        private bool IsGuiTop()
        {
            return m_Top == 1.0f;
        }
    }
    public class SubGroupDrawer : MaterialPropertyDrawer
    {
        protected bool m_IsFolding;

        protected string m_BindGroup;
        protected string m_BindKey;

        protected Material m_TargetMat;

        public SubGroupDrawer(string bingGroup)
        {
            m_BindGroup = bingGroup;
        }

        public SubGroupDrawer(string bindGroup, string bindKey)
        {
            m_BindGroup = bindGroup;
            m_BindKey   = bindKey;
        }


        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            m_TargetMat = editor.target as Material;

            EditorGUI.indentLevel++;

            m_IsFolding = DrawerUtilities.IsFloatValueEqualsOne(m_TargetMat, m_BindGroup);

            if (!string.IsNullOrEmpty(m_BindKey))
            {
                m_IsFolding &= DrawerUtilities.IsKeyEnable(m_TargetMat, m_BindKey);
            }

            if (m_IsFolding)
            {
                OnPropertyGUI(position, prop, label, editor);
            }

            EditorGUI.indentLevel--;
        }

        protected virtual void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            if (prop.type == MaterialProperty.PropType.Texture)
            {
                editor.TexturePropertySingleLine(label, prop);
            }
            else
            {
                editor.DefaultShaderProperty(prop, label.text);
            }
        }

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return DrawerUtilities.s_DefaultPropertyHeight;
        }
    }
    public class SubGroupDrawer_MapExt : SubGroupDrawer
    {
        protected string m_MapKey;

        protected float m_ScaleOffset;

        public SubGroupDrawer_MapExt(string bindGroup) : base(bindGroup) { }
        public SubGroupDrawer_MapExt(string bindGroup, float scaleOffset) : base(bindGroup) 
        {
            m_ScaleOffset = scaleOffset;
        }
        public SubGroupDrawer_MapExt(string bindGroup, string mapKey) : base(bindGroup)
        {
            m_MapKey = mapKey;
        }
        public SubGroupDrawer_MapExt(string bindGroup, string mapKey, float scaleOffset) : base(bindGroup)
        {
            m_MapKey      = mapKey;
            m_ScaleOffset = scaleOffset;
        }

        protected override void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            if (m_ScaleOffset == 1.0f)
            {
                editor.DefaultShaderProperty(prop, label.text);
            }
            else
            {
                editor.TexturePropertySingleLine(label, prop);
            }

            DrawerUtilities.EnableKey(m_TargetMat, m_MapKey, prop.textureValue != null);
        }
    }
    public class SubGroupDrawer_SurfaceExt : SubGroupDrawer
    {
        private static readonly string[] s_SurfaceTypeNames = Enum.GetNames(typeof(SurfaceType));

        private string m_SrcBlend;
        private string m_DstBlend;
        private string m_ZWrite;

        public SubGroupDrawer_SurfaceExt(string bingGroup) : base(bingGroup) { }

        public SubGroupDrawer_SurfaceExt(string bingGroup, string srcBlend, string dstBlend) : base(bingGroup)
        {
            m_SrcBlend = srcBlend;
            m_DstBlend = dstBlend;
        }

        public SubGroupDrawer_SurfaceExt(string bingGroup, string srcBlend, string dstBlend, string zWrite) : base(bingGroup)
        {
            m_SrcBlend = srcBlend;
            m_DstBlend = dstBlend;

            m_ZWrite = zWrite;
        }
        protected override void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            EditorGUI.BeginChangeCheck();

            editor.PopupShaderProperty(prop, label, s_SurfaceTypeNames, DrawerUtilities.s_SpaceIndent);

            if (EditorGUI.EndChangeCheck())
            {
                var type = (SurfaceType)prop.floatValue;

                SetRenderQueue(type);
                SetBlendMode(type);
                SetZWrite(type);
            }
        }

        private void SetRenderQueue(SurfaceType type)
        {
            m_TargetMat.renderQueue = type == SurfaceType.Opaque ? 2000 : type == SurfaceType.AlphaTest ? 2450 : 3000;
        }

        private void SetBlendMode(SurfaceType type)
        {
            if (string.IsNullOrEmpty(m_SrcBlend) || string.IsNullOrEmpty(m_DstBlend))
                return;

            m_TargetMat.SetFloat(m_SrcBlend, type == SurfaceType.Transparent ? 5  : 1);
            m_TargetMat.SetFloat(m_DstBlend, type == SurfaceType.Transparent ? 10 : 0);
        }

        private void SetZWrite(SurfaceType type)
        {
            if (string.IsNullOrEmpty(m_ZWrite))
                return;

            m_TargetMat.SetFloat(m_ZWrite, type == SurfaceType.Transparent ? 0 : 1);
        }

    }
    public class SubGroupDrawer_MaskKeysExt : SubGroupDrawer
    {
        protected string m_Key0;
        protected string m_Key1;
        protected string m_Key2;
        protected string m_Key3;
        protected string m_Key4;
        protected string m_Key5;
        protected string m_Key6;
        protected string m_Key7;
        protected string m_Key8;
        protected string m_Key9;

        protected string[] m_Keys;

        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0) : base(bingGroup)
        {
            m_Key0 = key0;

            m_Keys = new string[1] { m_Key0 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;

            m_Keys = new string[2] { m_Key0, m_Key1 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1, string key2) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;
            m_Key2 = key2;

            m_Keys = new string[3] { m_Key0, m_Key1, m_Key2 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1, string key2, string key3) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;
            m_Key2 = key2;
            m_Key3 = key3;

            m_Keys = new string[4] { m_Key0, m_Key1, m_Key2, m_Key3 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;
            m_Key2 = key2;
            m_Key3 = key3;
            m_Key4 = key4;

            m_Keys = new string[5] { m_Key0, m_Key1, m_Key2, m_Key3, m_Key4 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;
            m_Key2 = key2;
            m_Key3 = key3;
            m_Key4 = key4;
            m_Key5 = key5;

            m_Keys = new string[6] { m_Key0, m_Key1, m_Key2, m_Key3, m_Key4, m_Key5 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5, string key6) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;
            m_Key2 = key2;
            m_Key3 = key3;
            m_Key4 = key4;
            m_Key5 = key5;
            m_Key6 = key6;

            m_Keys = new string[7] { m_Key0, m_Key1, m_Key2, m_Key3, m_Key4, m_Key5, m_Key6 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5, string key6, string key7) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;
            m_Key2 = key2;
            m_Key3 = key3;
            m_Key4 = key4;
            m_Key5 = key5;
            m_Key6 = key6;
            m_Key7 = key7;

            m_Keys = new string[8] { m_Key0, m_Key1, m_Key2, m_Key3, m_Key4, m_Key5, m_Key6, m_Key7 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5, string key6, string key7, string key8) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;
            m_Key2 = key2;
            m_Key3 = key3;
            m_Key4 = key4;
            m_Key5 = key5;
            m_Key6 = key6;
            m_Key7 = key7;
            m_Key8 = key8;

            m_Keys = new string[9] { m_Key0, m_Key1, m_Key2, m_Key3, m_Key4, m_Key5, m_Key6, m_Key7, m_Key8 };
        }
        public SubGroupDrawer_MaskKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5, string key6, string key7, string key8, string key9) : base(bingGroup)
        {
            m_Key0 = key0;
            m_Key1 = key1;
            m_Key2 = key2;
            m_Key3 = key3;
            m_Key4 = key4;
            m_Key5 = key5;
            m_Key6 = key6;
            m_Key7 = key7;
            m_Key8 = key8;
            m_Key9 = key9;

            m_Keys = new string[10] { m_Key0, m_Key1, m_Key2, m_Key3, m_Key4, m_Key5, m_Key6, m_Key7, m_Key8, m_Key9 };
        }

        protected override void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            if (m_Keys == null)
                return;

            var displayInfos = label.text.Split(DrawerUtilities.s_SplitChar);

            GUILayout.BeginHorizontal();

            GUILayout.Space(DrawerUtilities.s_SpaceIndent);
            GUILayout.Label(displayInfos[0], GUILayout.Width(100));

            prop.floatValue = EditorGUILayout.MaskField((int)prop.floatValue, displayInfos.Skip(1).ToArray());

            GUILayout.EndHorizontal();

            EnableKeys((int)prop.floatValue);
        }


        protected virtual void EnableKeys(int mask)
        {
            if (m_TargetMat == null)
                return;

            EnableKey(mask, 1 << 0, m_Key0);
            EnableKey(mask, 1 << 1, m_Key1);
            EnableKey(mask, 1 << 2, m_Key2);
            EnableKey(mask, 1 << 3, m_Key3);
            EnableKey(mask, 1 << 4, m_Key4);
            EnableKey(mask, 1 << 5, m_Key5);
            EnableKey(mask, 1 << 6, m_Key6);
            EnableKey(mask, 1 << 7, m_Key7);
            EnableKey(mask, 1 << 8, m_Key8);
            EnableKey(mask, 1 << 9, m_Key9);
        }

        protected virtual void EnableKey(int mask, int keyValue, string keyMap)
        {
            if (string.IsNullOrEmpty(keyMap))
                return;

            DrawerUtilities.EnableKey(m_TargetMat, keyMap, (mask & keyValue) != 0);
        }
    }

    public class SubGroupDrawer_EnumKeysExt : SubGroupDrawer_MaskKeysExt
    {
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0) : base(bingGroup, key0)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1) : base(bingGroup, key0, key1)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1, string key2) : base(bingGroup, key0, key1, key2)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1, string key2, string key3) : base(bingGroup, key0, key1, key2, key3)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4) : base(bingGroup, key0, key1, key2, key3, key4)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5) : base(bingGroup, key0, key1, key2, key3, key4, key5)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5, string key6) : base(bingGroup, key0, key1, key2, key3, key4, key5, key6)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5, string key6, string key7) : base(bingGroup, key0, key1, key2, key3, key4, key5, key6, key7)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5, string key6, string key7, string key8) : base(bingGroup, key0, key1, key2, key3, key4, key5, key6, key7, key8)
        {
        }
        public SubGroupDrawer_EnumKeysExt(string bingGroup, string key0, string key1, string key2, string key3, string key4, string key5, string key6, string key7, string key8, string key9) : base(bingGroup, key0, key1, key2, key3, key4, key5, key6, key7, key8, key9)
        {
        }

        protected override void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            //editor.PopupShaderProperty(prop, label, m_Keys, DrawerUtilities.s_SpaceIndent);

            var displayInfos = label.text.Split(DrawerUtilities.s_SplitChar);

            GUILayout.BeginHorizontal();

            //GUILayout.Space(DrawerUtilities.s_SpaceIndent);
            //GUILayout.Label(displayInfos[0], GUILayout.Width(100));

            prop.floatValue = editor.PopupShaderProperty(prop, new GUIContent(displayInfos[0]), displayInfos.Skip(1).ToArray(), DrawerUtilities.s_SpaceIndent);

            GUILayout.EndHorizontal();

            EnableKeys((int)prop.floatValue);
        }

        protected override void EnableKeys(int mask)
        {
            if (m_TargetMat == null)
                return;

            EnableKey(mask, 0, m_Key0);
            EnableKey(mask, 1, m_Key1);
            EnableKey(mask, 2, m_Key2);
            EnableKey(mask, 3, m_Key3);
            EnableKey(mask, 4, m_Key4);
            EnableKey(mask, 5, m_Key5);
            EnableKey(mask, 6, m_Key6);
            EnableKey(mask, 7, m_Key7);
            EnableKey(mask, 8, m_Key8);
            EnableKey(mask, 9, m_Key9);
        }

        protected override void EnableKey(int mask, int keyValue, string keyMap)
        {
            if (string.IsNullOrEmpty(keyMap))
                return;

            DrawerUtilities.EnableKey(m_TargetMat, keyMap, mask == keyValue);
        }

    }

    public class SubGroupDrawer_VectorExt : SubGroupDrawer
    {
        private float m_RangeX0;
        private float m_RangeX1;
        private float m_RangeY0;
        private float m_RangeY1;
        private float m_RangeZ0;
        private float m_RangeZ1;
        private float m_RangeW0;
        private float m_RangeW1;

        private bool m_IsRange;

        public SubGroupDrawer_VectorExt(string bingGroup) : base(bingGroup)
        {
            m_IsRange = false;
        }

        public SubGroupDrawer_VectorExt(string bingGroup, float rangex0, float rangex1, float rangey0, float rangey1, float rangez0, float rangez1, float rangew0, float rangew1) : base(bingGroup)
        {
            m_RangeX0 = rangex0;
            m_RangeX1 = rangex1;
            m_RangeY0 = rangey0;
            m_RangeY1 = rangey1;
            m_RangeZ0 = rangez0;
            m_RangeZ1 = rangez1;
            m_RangeW0 = rangew0;
            m_RangeW1 = rangew1;

            m_IsRange = true;
        }

        protected override void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            var labels = label.text.Split(DrawerUtilities.s_SplitChar);

            var vec4Value = prop.vectorValue;

            if (m_IsRange)
            {
                vec4Value.x = HorizontalSlider(labels[0], vec4Value.x, m_RangeX0, m_RangeX1);
                vec4Value.y = HorizontalSlider(labels[1], vec4Value.y, m_RangeY0, m_RangeY1);
                vec4Value.z = HorizontalSlider(labels[2], vec4Value.z, m_RangeZ0, m_RangeZ1);
                vec4Value.w = HorizontalSlider(labels[3], vec4Value.w, m_RangeW0, m_RangeW1);
            }
            else
            {
                vec4Value.x = EditorGUILayout.FloatField(labels[0], vec4Value.x);
                vec4Value.y = EditorGUILayout.FloatField(labels[1], vec4Value.y);
                vec4Value.z = EditorGUILayout.FloatField(labels[2], vec4Value.z);
                vec4Value.w = EditorGUILayout.FloatField(labels[3], vec4Value.w);
            }

            prop.vectorValue = vec4Value;
        }

        private float HorizontalSlider(string label, float value, float min, float max)
        {
            GUILayout.BeginHorizontal();

            GUILayout.Space(DrawerUtilities.s_SpaceIndent);

            GUILayout.Label(label, GUILayout.Width(100));

            value = EditorGUILayout.Slider(value, min, max);

            GUILayout.EndHorizontal();

            return value;
        }
    }
    public class SubGroupDrawer_HDRColorExt : SubGroupDrawer
    {
        public SubGroupDrawer_HDRColorExt(string bingGroup) : base(bingGroup)
        {

        }

        public SubGroupDrawer_HDRColorExt(string bindGroup, string bindKey) : base(bindGroup, bindKey)
        {
        }

        protected override void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            position.height = 18.0f;

            prop.colorValue = EditorGUI.ColorField(position, label, prop.colorValue, true, true, true);
        }

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return m_IsFolding ? 16.0f : DrawerUtilities.s_DefaultPropertyHeight;
        }
    }
    public class SubGroupDrawer_CullExt : SubGroupDrawer
    {
        private static readonly string[] s_CullTypeNames = Enum.GetNames(typeof(CullMode));

        public SubGroupDrawer_CullExt(string bingGroup) : base(bingGroup)
        {

        }

        protected override void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            editor.PopupShaderProperty(prop, label, s_CullTypeNames, DrawerUtilities.s_SpaceIndent);
        }
    }
    public class SubGroupDrawer_TestExt : SubGroupDrawer
    {
        private static readonly string[] s_ZTestTypeNames = Enum.GetNames(typeof(ZTestMode));

        public SubGroupDrawer_TestExt(string bingGroup) : base(bingGroup)
        {

        }

        protected override void OnPropertyGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            editor.PopupShaderProperty(prop, label, s_ZTestTypeNames, DrawerUtilities.s_SpaceIndent);
        }
    }

    public class TextureWrapDrawer : MaterialPropertyDrawer
    {
        private string title1 = string.Empty;
        private string title2 = string.Empty;
		
        public TextureWrapDrawer()
        {
        }
        public TextureWrapDrawer(string tit1)
        {
            title1 = tit1;
        }
        public TextureWrapDrawer(string tit1,string tit2)
        {
            title1 = tit1;
            title2 = tit2;
        }


        public override void OnGUI(Rect position, MaterialProperty prop, string label, MaterialEditor editor)
        {
			
            editor.SetDefaultGUIWidths();
            if (string.IsNullOrEmpty(title1) && string.IsNullOrEmpty(title2))
            {
                var mod = Vec2WrapMode(new Vector2(prop.vectorValue.x,prop.vectorValue.y));
                EditorGUI.BeginChangeCheck();
                mod =  (WrapMode)EditorGUI.EnumPopup(position,label,mod);
                if (EditorGUI.EndChangeCheck())
                {
                    var getMod = WarpMode2Vec(mod);
					prop.vectorValue = new Vector4(getMod.x,getMod.y,0,0);
                }
            }

            if (string.IsNullOrEmpty(title2)&&!string.IsNullOrEmpty(title1))
            {
                var mod = Vec2WrapMode(new Vector2(prop.vectorValue.x,prop.vectorValue.y));
                EditorGUI.BeginChangeCheck();
                mod =  (WrapMode)EditorGUI.EnumPopup(position,title1,mod);
                if (EditorGUI.EndChangeCheck())
                {
                    var getMod = WarpMode2Vec(mod);
                    prop.vectorValue = new Vector4(getMod.x,getMod.y,0,0);
                }
            }

            if (!string.IsNullOrEmpty(title2)&&!string.IsNullOrEmpty(title1))
            {
                var mod1 = Vec2WrapMode(new Vector2(prop.vectorValue.x,prop.vectorValue.y));
                var mod2 = Vec2WrapMode(new Vector2(prop.vectorValue.z,prop.vectorValue.w));
                EditorGUI.BeginChangeCheck();
                mod1 =  (WrapMode)EditorGUI.EnumPopup(new Rect(position.position.x,position.position.y,position.size.x,position.size.y/2), title1,mod1);
                mod2 = (WrapMode)EditorGUI.EnumPopup(new Rect(position.position.x,position.position.y+position.size.y/2,position.size.x,position.size.y/2), title2,mod2);
                if (EditorGUI.EndChangeCheck())
                {
                    var getMod1 = WarpMode2Vec(mod1);
                    var getMod2 = WarpMode2Vec(mod2);
                    prop.vectorValue = new Vector4(getMod1.x,getMod1.y,getMod2.x,getMod2.y);
                }
            }
        }

        public WrapMode Vec2WrapMode(Vector2 data)
        {
            switch (data.x + data.y)
            {
                case 0:
                    return WrapMode.ClampAll;
                case  1:
                    if (data.x == 1) 
                        return WrapMode.RepeatU;
                    else 
                        return WrapMode.RepeatV;
                case 2:
                    return WrapMode.RepeatAll;
                default:
                    return WrapMode.ClampAll;
            }
        }

        public Vector2 WarpMode2Vec(WrapMode mod)
        {
            switch (mod)
            {
                case WrapMode.ClampAll:
                    return Vector2.zero;
                case WrapMode.RepeatAll:
                    return Vector2.one;
                case WrapMode.RepeatU:
                    return new Vector2(1,0);
                case WrapMode.RepeatV:
                    return new Vector2(0,1);
                default:
                    return Vector2.zero;
            }
        }

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            if (!string.IsNullOrEmpty(title2) && !string.IsNullOrEmpty(title1))
            {
                return base.GetPropertyHeight(prop, label, editor)*2f;
            }
            else
            {
                return base.GetPropertyHeight(prop, label, editor);
            }
        }
    }
	
    public static class DrawerUtilities
    {
        public static readonly float s_DefaultPropertyHeight = -2.0f;

        public static readonly int s_SpaceIndent = 14;

        public static readonly string s_SplitChar = "##";

        public static bool IsFloatValueEqualsOne(Material material, string foldKey)
        {
            return material.GetFloat(foldKey) == 1.0f;
        }

        public static bool IsKeyEnable(Material material, string key)
        {
            return material.IsKeywordEnabled(key);
        }

        public static void EnableKey(Material material, string key, bool isEnable)
        {
            if (isEnable)
                material.EnableKeyword(key);
            else
                material.DisableKeyword(key);
        }


        static Rect GetRect(MaterialProperty prop)
        {
            return EditorGUILayout.GetControlRect(true, MaterialEditor.GetDefaultPropertyHeight(prop), EditorStyles.layerMaskField);
        }

        /// <summary>
        /// Draw an integer slider for a range shader property.
        /// </summary>
        /// <param name="editor"><see cref="MaterialEditor"/></param>
        /// <param name="prop">The MaterialProperty to make a field for</param>
        /// <param name="label">Label for the property</param>
        public static void IntSliderShaderProperty(this MaterialEditor editor, MaterialProperty prop, GUIContent label)
        {
            var limits = prop.rangeLimits;
            editor.IntSliderShaderProperty(prop, (int)limits.x, (int)limits.y, label);
        }

        /// <summary>
        /// Draw an integer slider for a float shader property.
        /// </summary>
        /// <param name="editor"><see cref="MaterialEditor"/></param>
        /// <param name="prop">The MaterialProperty to make a field for</param>
        /// <param name="min">The value at the left end of the slider</param>
        /// <param name="max">The value at the right end of the slider</param>
        /// <param name="label">Label for the property</param>
        public static void IntSliderShaderProperty(this MaterialEditor editor, MaterialProperty prop, int min, int max, GUIContent label)
        {
            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;
            int newValue = EditorGUI.IntSlider(GetRect(prop), label, (int)prop.floatValue, min, max);
            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
            {
                editor.RegisterPropertyChangeUndo(label.text);
                prop.floatValue = newValue;
            }
        }

        /// <summary>
        /// Draw a popup selection field for a float shader property.
        /// </summary>
        /// <param name="editor"><see cref="MaterialEditor"/></param>
        /// <param name="prop">The MaterialProperty to make a field for</param>
        /// <param name="label">Label for the property</param>
        /// <param name="displayedOptions">An array with the options shown in the popup</param>
        /// <returns>The index of the option that has been selected by the user</returns>
        public static int PopupShaderProperty(this MaterialEditor editor, MaterialProperty prop, GUIContent label, string[] displayedOptions, int space = 0)
        {
            int val = (int)prop.floatValue;

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;

            GUILayout.BeginHorizontal();
            GUILayout.Space(space);
            GUILayout.Label(label, GUILayout.Width(100));

            int newValue = EditorGUILayout.Popup(val, displayedOptions);

            GUILayout.EndHorizontal();

            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck() && (newValue != val || prop.hasMixedValue))
            {
                editor.RegisterPropertyChangeUndo(label.text);
                prop.floatValue = val = newValue;
            }

            return val;
        }

        /// <summary>
        /// Draw an integer popup selection field for a float shader property.
        /// </summary>
        /// <param name="editor"><see cref="MaterialEditor"/></param>
        /// <param name="prop">The MaterialProperty to make a field for</param>
        /// <param name="label">Label for the property</param>
        /// <param name="displayedOptions">An array with the options shown in the popup</param>
        /// <param name="optionValues">An array with the values for each option</param>
        /// <returns>The value of the option that has been selected by the user</returns>
        public static int IntPopupShaderProperty(this MaterialEditor editor, MaterialProperty prop, string label, string[] displayedOptions, int[] optionValues)
        {
            int val = (int)prop.floatValue;

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;
            int newValue = EditorGUILayout.IntPopup(label, val, displayedOptions, optionValues);
            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck() && (newValue != val || prop.hasMixedValue))
            {
                editor.RegisterPropertyChangeUndo(label);
                prop.floatValue = val = newValue;
            }

            return val;
        }
    }
    public enum SurfaceType
    {
        Opaque = 0,
        AlphaTest = 1,
        Transparent = 2
    }
    public enum WrapMode
    {
        RepeatAll ,
        ClampAll ,
        RepeatU ,
        RepeatV ,
    }
    public enum RenderFace
    {
        Front = 2,
        Back  = 1,
        Both  = 0
    }
    enum ZTestMode  // the values here match UnityEngine.Rendering.CompareFunction
    {
        Disabled = 0,
        Never = 1,
        Less = 2,
        Equal = 3,
        LEqual = 4,     // default for most rendering
        Greater = 5,
        NotEqual = 6,
        GEqual = 7,
        Always = 8,
    }
}