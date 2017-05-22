Shader "Unlit/ShieldFX"
{
	Properties
	{
		_MainColor("MainColor", Color) = (1,1,1,1)
		_MainTex ("Texture", 2D) = "white" {}
		_Fresnel("Fresnel Intensity", Range(0,200)) = 3.0
		_FresnelWidth("Fresnel Width", Range(0,2)) = 3.0
		_Distort("Distort", Range(0, 100)) = 1.0
		_IntersectionThreshold("Highlight of intersection threshold", range(0,1)) = .1 //Max difference for intersections
		_ScrollSpeedU("Scroll U Speed",float) = 2
		_ScrollSpeedV("Scroll V Speed",float) = 0
		[ToggleOff]_CullOff("Cull Front Side Intersection",float) = 1
	}
	SubShader
	{ 
		Tags{ "Queue" = "Overlay" "IgnoreProjector" = "True" "RenderType" = "Transparent" }

		Pass
		{
			Blend One One
			Cull [_CullOff] Lighting Off ZWrite [_CullOff]

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			
			struct v2f
			{
				fixed4 vertex : SV_POSITION;
				fixed4 screenPos: TEXCOORD1;
			};

			sampler2D _CameraDepthTexture;
			fixed _IntersectionThreshold,_Fresnel;
			fixed4 _MainColor;

			v2f vert (appdata_base v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos(o.vertex);
				o.screenPos.z = -UnityObjectToViewPos(v.vertex.xyz).z;
				UNITY_TRANSFER_DEPTH(o.screenPos.z);// eye space depth of the vertex 
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				//back intersection
				fixed zBuffer = LinearEyeDepth(tex2Dproj(_CameraDepthTexture,UNITY_PROJ_COORD(i.screenPos)).r);
				fixed intersect = (abs(zBuffer - i.screenPos.z)) / _IntersectionThreshold;

				_MainColor.rgb *= 1 - saturate(intersect) ;
				return _MainColor * _Fresnel * .02;
			}
			ENDCG
		}

		GrabPass{ "_GrabTexture" }
		Pass
		{
			Lighting Off ZWrite Off
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata
			{
				fixed4 vertex : POSITION;
				fixed4 normal: NORMAL;
				fixed3 uv : TEXCOORD0;
			};

			struct v2f
			{
				fixed2 uv : TEXCOORD0;
				fixed4 vertex : SV_POSITION;
				fixed4 worldPos : TEXCOORD1;
				fixed3 rimColor :TEXCOORD2;
				fixed4 screenPos: TEXCOORD3;
			};

			sampler2D _MainTex, _CameraDepthTexture, _GrabTexture;
			fixed4 _MainTex_ST,_MainColor,_GrabTexture_ST, _GrabTexture_TexelSize;
			fixed _Fresnel, _FresnelWidth, _Distort, _IntersectionThreshold, _ScrollSpeedU, _ScrollSpeedV;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				//scroll uv
				o.uv.x += _Time * _ScrollSpeedU;
				o.uv.y += _Time * _ScrollSpeedV;

				//fresnel 
				fixed3 viewDir = normalize(ObjSpaceViewDir(v.vertex));
				fixed dotProduct = 1 - saturate(dot(v.normal, viewDir));
				o.rimColor = smoothstep(1 - _FresnelWidth, 1.0, dotProduct) * .5f;
				o.screenPos = ComputeScreenPos(o.vertex);
				COMPUTE_EYEDEPTH(o.screenPos.z);//eye space depth of the vertex 
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				//intersection
				fixed zBuffer = LinearEyeDepth(tex2Dproj(_CameraDepthTexture,UNITY_PROJ_COORD(i.screenPos)).r);
				fixed intersect = (abs(zBuffer - i.screenPos.z)) / _IntersectionThreshold;

				fixed3 main = tex2D(_MainTex, i.uv);
				if (distance(main, 0) <= 0) //discard black texture
					discard;

				//distortion
				fixed2 offset = main * _Distort * _GrabTexture_TexelSize.xy;
				i.screenPos.xy = offset + i.screenPos.xy;
				fixed3 distortColor = tex2Dproj(_GrabTexture, i.screenPos);
				distortColor *= _MainColor * _MainColor.a + 1;

				//intersect hightlight
				fixed3 col = main * _MainColor * pow(_Fresnel,i.rimColor) ;
				

				//lerp distort color & fresnel color
				col = lerp(distortColor, col, i.rimColor.r);
				col += saturate(1 - intersect) * _MainColor * _Fresnel * .02;
				return fixed4(col,1);
			}
			ENDCG
		}
	}
}