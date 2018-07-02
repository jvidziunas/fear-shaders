#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\noise.fxh"
#include "..\..\..\sdk\time.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
	float4	Color		: COLOR0;
    float4	LightPos	: TEXCOORD0;
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("Material for rendering volumetric lighting slices including noise.");
DECLARE_DOCUMENATION("Shaders\\Docs\\additive\\main.htm");

//--------------------------------------------------------------------
// Material parameters

// the textures exported for the user
MIPARAM_TEXTURE(tCookieMap, 0, 1, "", false, "Cookie texture - Initialized at runtime");
MIPARAM_FLOAT(fNoiseScale, 1.0, "Noise Scale - Initialized at runtime");
MIPARAM_FLOAT(fNoiseIntensity, 0.5, "Noise Intensity - Initialized at runtime");
MIPARAM_FLOAT(fDistanceAttenuationScale, 1.0, "Distance Attenuation Scale - Initialized at runtime");

//the samplers for those textures
SAMPLER_CLAMP(sCookieMapSampler, tCookieMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return Vert.Position;
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------
// Translucent Pass 1: Diffuse with the global translucent color
struct PSData_Translucent 
{
	float4 Position : POSITION;
	float4 LightPos : TEXCOORD0_centroid;
	float4 Color	: TEXCOORD1;
	float4 NoisePos : TEXCOORD2_centroid;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position	= TransformToClipSpace(GetPosition(IN));
	OUT.LightPos	= IN.LightPos;
	OUT.Color		= IN.Color;
	
	OUT.NoisePos	= IN.LightPos;
	OUT.NoisePos.z	-= sin(fTime * 3.1415926535 / 5.0) * 0.2;
	// Note: using /40, z*4, w*40 instead of /float4(40,40,10,1) is to work around a bug in the April FXC
	OUT.NoisePos	/= 40 * fNoiseScale;
	OUT.NoisePos.z	*= 4;
	OUT.NoisePos.w	*= 40;
	
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	half4 vResult;
	
	float fTime_Wave = sin(fTime * 3.1415926535 / 5.0);
	
	float intensity = tex2Dproj(sCookieMapSampler, IN.LightPos).w;

	float4 noise1 = Noise(float3(IN.NoisePos.xy / IN.NoisePos.w, IN.NoisePos.z), 1.0, 2, 0);
	float4 noise2 = Noise(noise1.xyz / 100.0 + float3(sin(fTime_Wave + noise1.y), cos(fTime_Wave + noise1.x), noise1.w) * 0.5, 2.0, 2, 0);
	intensity *= noise2.x * fNoiseIntensity + 1.0;

	vResult.xyzw = intensity * IN.Color;

	half fDistance = saturate(length(half3(IN.LightPos.xy / IN.LightPos.w - 0.5, IN.LightPos.z)) * fDistanceAttenuationScale);
	half fAttenuation = (1.0 - fDistance * fDistance);
	vResult.xyzw *= fAttenuation * fAttenuation;
	
	return LinearizeAlpha(vResult);
}

//----------------------------------------------------------------------------
// Translucent Technique
technique Translucent 
{
	pass p0 
	{
		CullMode	= None;
		AlphaBlendEnable = True;
		SrcBlend	= One;
		DestBlend	= One;
		FogColor	= 0;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}
