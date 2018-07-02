#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\lightdefs.fxh"
#include "..\..\sdk\object.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float2	TexCoord	: TEXCOORD0;
    float3	Normal		: NORMAL;
    
    DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a version of the additive material with a view-dependent fallof factor.");
DECLARE_DOCUMENATION("Shaders\\Docs\\additive_falloff\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material.");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float2 vCoord)
{
	return tex2D(sDiffuseMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------
// Translucent Pass 1: Diffuse with the global translucent color
struct PSData_Translucent 
{
	float4 Position			: POSITION;
	float2 DiffuseTexCoord	: TEXCOORD0_centroid;
	float3 EyePos			: TEXCOORD1_centroid;
	float3 Normal			: TEXCOORD2_centroid;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	float3 vPos = GetPosition(IN);

	PSData_Translucent OUT;
	OUT.Position		= TransformToClipSpace(vPos);
	OUT.DiffuseTexCoord = IN.TexCoord;
	OUT.EyePos			= vObjectSpaceEyePos - vPos;
	OUT.Normal			= IN.Normal;
	return OUT;
}

PSOutput Translucent_PS(PSData_Translucent IN)
{
	PSOutput OUT;
	
	float3 vUnitEyePos = normalize(IN.EyePos);
	float3 vUnitNormal = normalize(IN.Normal);
	
	float4 Diffuse = GetLightDiffuseColor();
	float4 Tint = float4(Diffuse.xyz, Diffuse.w * clamp(dot(vUnitEyePos, vUnitNormal), 0, 1));
	float4 Texture = GetMaterialDiffuse(IN.DiffuseTexCoord);

	OUT.Color = LinearizeAlpha( Texture * Tint );
	return OUT;
}

//----------------------------------------------------------------------------
// Translucent Technique
technique Translucent 
{
	pass p0 
	{
		CullMode	= CCW;
		SrcBlend	= SrcAlpha;
		DestBlend	= One;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

