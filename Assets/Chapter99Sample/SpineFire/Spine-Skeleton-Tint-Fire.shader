// Spine/Skeleton Tint
// - Two color tint
// - unlit
// - Premultiplied alpha blending (Optional straight alpha input)
// - No depth, no backface culling, no fog.

Shader "Spine/Skeleton Tint Fire" {
	Properties {
		_Color ("Tint Color", Color) = (1,1,1,1)
		_Black ("Black Point", Color) = (0,0,0,0)
		[NoScaleOffset] _MainTex ("MainTex", 2D) = "black" {}
		[Toggle(_STRAIGHT_ALPHA_INPUT)] _StraightAlphaInput("Straight Alpha Texture", Int) = 0
		_Cutoff ("Shadow alpha cutoff", Range(0,1)) = 0.1
		[HideInInspector] _StencilRef("Stencil Reference", Float) = 1.0
		[Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Compare", Float) = 0.0 // Disabled stencil test by default
	
		//Fire
		_DistTex("Distortion Texture", 2D) = "gray"{}
		_DistTexST("Distortion Texture Scale", Vector) = (1.0, 1.0, 0.0, 0.0)
		_DistMaskTex("Distortion Mask Texture", 2D) = "black"{}
		_DistStr("Distortion Strength", Vector) = (0.0, 0.0, 0.0, 0.0)
		_DistSpd("Distortion Speed", Vector) = (0.0, 0.0, 0.0, 0.0)
		_FireThreshold("Fire Threshold", Float) = 1.0

	}

	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }

		Fog { Mode Off }
		Cull Off
		ZWrite Off
		Blend One OneMinusSrcAlpha
		Lighting Off

		Stencil {
			Ref[_StencilRef]
			Comp[_StencilComp]
			Pass Keep
		}

		Pass {
			CGPROGRAM
			#pragma shader_feature _ _STRAIGHT_ALPHA_INPUT
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			sampler2D _MainTex;
			float4 _Color;
			float4 _Black;

			//custom
			sampler2D _DistTex;
			float4 _DistTexST;
			sampler2D _DistMaskTex;
			float2 _DistStr;
			float2 _DistSpd;
			float _FireThreshold;


			struct VertexInput {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 vertexColor : COLOR;
			};

			struct VertexOutput {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 vertexColor : COLOR;
			};

			VertexOutput vert (VertexInput v) {
				VertexOutput o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.vertexColor = v.vertexColor * float4(_Color.rgb * _Color.a, _Color.a); // Combine a PMA version of _Color with vertexColor.
				return o;
			}

			float4 frag (VertexOutput i) : COLOR {
				//歪みテクスチャスクロール用UV
				float2 uv2 = i.uv * _DistTexST.xy + _DistSpd.xy * _Time.y;

				//歪み情報テクスチャ　R:横　G:縦 B:消滅度合い
				float4 distCol = tex2D(_DistTex, uv2);
				//歪み適用マスクテクスチャ　R:消えやすい場所　G:歪みマスク
				float4 distMaskCol = tex2D(_DistMaskTex, i.uv);
				
				//UVを歪ませる
				i.uv += (distCol.rg - 0.5) * _DistStr.xy * distMaskCol.g;

				//メインテクスチャ取得
				float4 texColor = tex2D(_MainTex, i.uv);

				//distMaskCol.rとdistCol.bの合算値がしきい値以下の場合はアルファ０に
				texColor *= step(_FireThreshold, distMaskCol.r + distCol.b);

				#if defined(_STRAIGHT_ALPHA_INPUT)
				texColor.rgb *= texColor.a;
				#endif

				return (texColor * i.vertexColor) + float4(((1-texColor.rgb) * _Black.rgb * texColor.a*_Color.a*i.vertexColor.a), 0);
			}
			ENDCG
		}

		Pass {
			Name "Caster"
			Tags { "LightMode"="ShadowCaster" }
			Offset 1, 1
			ZWrite On
			ZTest LEqual

			Fog { Mode Off }
			Cull Off
			Lighting Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "UnityCG.cginc"
			sampler2D _MainTex;
			fixed _Cutoff;

			struct VertexOutput { 
				V2F_SHADOW_CASTER;
				float2 uv : TEXCOORD1;
			};

			VertexOutput vert (appdata_base v) {
				VertexOutput o;
				o.uv = v.texcoord;
				TRANSFER_SHADOW_CASTER(o)
				return o;
			}

			float4 frag (VertexOutput i) : COLOR {
				fixed4 texcol = tex2D(_MainTex, i.uv);


				clip(texcol.a - _Cutoff);
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
}
