#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
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
DECLARE_DESCRIPTION("Material for rendering volumetric lighting shells.");
DECLARE_DOCUMENATION("Shaders\\Docs\\additive\\main.htm");

//--------------------------------------------------------------------
// Material parameters

// the textures exported for the user
MIPARAM_TEXTURE(tSliceMap, 0, 1, "", false, "Slice texture - Initialized at runtime");
MIPARAM_FLOAT(fSliceResX, 512, "Slice texture X resolution - Initialized at runtime");
MIPARAM_FLOAT(fSliceResY, 384, "Slice texture Y resolution - Initialized at runtime");
MIPARAM_FLOAT(fAlphaBlend, 1.0, "Alpha blending - Initialized at runtime");

//the samplers for those textures
SAMPLER_CLAMP(sSliceMapSampler, tSliceMap);

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
	float4 Position		: POSITION;
	float4 ScreenPos	: TEXCOORD0_centroid;
	float4 Color		: TEXCOORD1;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position	= TransformToClipSpace(GetPosition(IN));
	OUT.ScreenPos	= OUT.Position;
	OUT.Color		= IN.Color;
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	half4 vResult;
	
	float2 fInvScreenRes = 1.0f / float2(fSliceResX, fSliceResY);
	
	float2 vScreenPos = IN.ScreenPos.xy / IN.ScreenPos.w;
	vScreenPos = vScreenPos * float2(0.5, -0.5) + 0.5;

	half intensity = 0;
	intensity += dot(tex2D(sSliceMapSampler, vScreenPos + fInvScreenRes * 0.33 * float2(-1, -2)), 0.25.xxxx);
	intensity += dot(tex2D(sSliceMapSampler, vScreenPos + fInvScreenRes * 0.33 * float2(-2,  1)), 0.25.xxxx);
	intensity += dot(tex2D(sSliceMapSampler, vScreenPos + fInvScreenRes * 0.33 * float2( 1,  2)), 0.25.xxxx);
	intensity += dot(tex2D(sSliceMapSampler, vScreenPos + fInvScreenRes * 0.33 * float2( 2, -1)), 0.25.xxxx);

	intensity += dot(tex2D(sSliceMapSampler, vScreenPos + fInvScreenRes * 0.66 * float2( 1, -2)), 0.25.xxxx);
	intensity += dot(tex2D(sSliceMapSampler, vScreenPos + fInvScreenRes * 0.66 * float2(-2, -1)), 0.25.xxxx);
	intensity += dot(tex2D(sSliceMapSampler, vScreenPos + fInvScreenRes * 0.66 * float2(-1,  2)), 0.25.xxxx);
	intensity += dot(tex2D(sSliceMapSampler, vScreenPos + fInvScreenRes * 0.66 * float2( 2,  1)), 0.25.xxxx);

	intensity *= 1.0 / 8.0;
	
	intensity = saturate(intensity * IN.Color.w);
	vResult.xyz = intensity * IN.Color.xyz;
	vResult.w = LinearizeAlpha( 1.0f - (intensity * fAlphaBlend) );

	return vResult;
}

//----------------------------------------------------------------------------
// Translucent Technique
technique Translucent 
{
	pass p0 
	{
		CullMode	= CW;
		ZFunc		= Always;
		AlphaBlendEnable = True;
		SrcBlend	= One;
		DestBlend	= SrcAlpha;
		FogEnable	= False;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

