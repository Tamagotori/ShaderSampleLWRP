﻿Shader "Unlit/Pallate"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_PaletteTex("Palette Texture", 2D) = "white"{}
		_PaletteOffset("Palatte Offset", Vector) = (0,0,0,0)
    }
    SubShader
    {
		Tags{ "Queue" = "Transparent" "RenderType" = "Transparent" }
        LOD 100

		ZTest LEqual
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			sampler2D _PaletteTex;
			float4 _PaletteTex_ST;
			float2 _PaletteOffset;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

			fixed getLuminance(fixed3 col) {
				return col.r * 0.2989 + col.g * 0.5866 + col.b * 0.1145;
			}

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

				fixed lumi = getLuminance(col.rgb);
				float2 palUV = float2(lumi, 0);
				palUV += _PaletteOffset;

				fixed4 palCol = tex2D(_PaletteTex, palUV);

				col *= palCol;
				// apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
