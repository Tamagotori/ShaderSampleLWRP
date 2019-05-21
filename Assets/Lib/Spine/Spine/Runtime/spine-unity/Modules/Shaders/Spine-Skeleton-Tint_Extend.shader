// Spine/Skeleton Tint
// - Two color tint
// - unlit
// - Premultiplied alpha blending (Optional straight alpha input)
// - No depth, no backface culling, no fog.

Shader "Spine/Skeleton Tint Extend" {
	Properties {
		_Color ("Tint Color", Color) = (1,1,1,1)
		_Black ("Black Point", Color) = (0,0,0,0)
		[NoScaleOffset] _MainTex ("MainTex", 2D) = "black" {}
		[Toggle(_STRAIGHT_ALPHA_INPUT)] _StraightAlphaInput("Straight Alpha Texture", Int) = 0
		_Cutoff ("Shadow alpha cutoff", Range(0,1)) = 0.1
		[HideInInspector] _StencilRef("Stencil Reference", Float) = 1.0
		[Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Compare", Float) = 0.0 // Disabled stencil test by default
		
		//Custom
		_Value("Value", Range(0,1)) = 0.0
		_MapTex("MapTex", 2D) = "white"{}
		_SwapTex("SwapTex", 2D) = "black"{}
		_Distortion("Distortion", Float) = 0.0
		_DistSpeed("Dist Speed", Float) = 0.0
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
			float _Value;
			sampler2D _MapTex;
			sampler2D _SwapTex;
			float _Distortion;
			float _DistSpeed;

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
				float2 uv2 = i.uv;
				uv2 += _DistSpeed * _Time.y;

				float4 mapCol = tex2D(_MapTex, uv2);

				float value = 1.0 - saturate((mapCol.r + 1.0) - _Value * 2.0);
				float thread = step(0.5, value);

				i.uv += mapCol.g * _Distortion * thread;

				float4 texColor = tex2D(_MainTex, i.uv);
				float4 swapCol = tex2D(_SwapTex, i.uv);

				
				texColor = lerp(texColor, swapCol, thread);

				#if defined(_STRAIGHT_ALPHA_INPUT)
				texColor.rgb *= texColor.a;
				#endif

				float4 col = (texColor * i.vertexColor) + float4(((1-texColor.rgb) * _Black.rgb * texColor.a*_Color.a*i.vertexColor.a), 0);

				return col;
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
			sampler2D _MapTex;
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
