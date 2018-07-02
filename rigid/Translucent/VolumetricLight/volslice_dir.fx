#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"

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
DECLARE_DESCRIPTION("Material for rendering volumetric lighting slices.");
DECLARE_DOCUMENATION("Shaders\\Docs\\additive\\main.htm");

//--------------------------------------------------------------------
// Material parameters

// the textures exported for the user
MIPARAM_TEXTURE(tCookieMap, 0, 1, "", false, "Cookie texture - Initialized at runtime");
MIPARAM_TEXTURE(tAttenuationMap, 0, 2, "", false, "Attenuation texture - Initialized at runtime");
MIPARAM_FLOAT(fDistanceAttenuationScale, 1.0, "Distance Attenuation Scale - Initialized at runtime");

//the samplers for those textures
SAMPLER_CLAMP(sCookieMapSampler, tCookieMap);
SAMPLER_CLAMP(sAttenuationMapSampler, tAttenuationMap);

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
	float4 Position	: POSITION;
	float4 LightPos	: TEXCOORD0_centroid;
	float4 Color		: TEXCOORD1;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position	= TransformToClipSpace( GetPosition(IN) );
	OUT.LightPos	= IN.LightPos;
	OUT.Color	= IN.Color;
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	half4 vResult;
	
	float intensity = tex2Dproj(sCookieMapSampler, IN.LightPos).w;

	vResult.xyzw = intensity * IN.Color;

	float fDistance = IN.LightPos.z * fDistanceAttenuationScale;
	float fAttenuation = tex1D( sAttenuationMapSampler, fDistance ).x;
	vResult.xyzw *= fAttenuation;
	
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

