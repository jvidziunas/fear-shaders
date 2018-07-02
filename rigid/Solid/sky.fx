#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\lightdefs.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float2	TexCoord	: TEXCOORD0;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is the standard sky material.");
DECLARE_DOCUMENATION("Shaders\\Docs\\sky\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the sky.");

//the samplers for those textures
SAMPLER_WRAP(sDiffuseMapSampler, tDiffuseMap);

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
// Translucent (sky)
//////////////////////////////////////////////////////////////////////////////

struct PSData_Sky
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

PSData_Sky Sky_VS(MaterialVertex IN)
{
	PSData_Sky OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	return OUT;
}

float4 Sky_PS(PSData_Sky IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	vResult = GetMaterialDiffuse(IN.TexCoord) * GetLightDiffuseColor();
	
	return vResult;
}

technique Translucent
{
	pass Draw
	{
		AlphaRef = 96;
		AlphaFunc = Greater;
		AlphaTestEnable = True;
		SrcBlend = One;
		DestBlend = Zero;
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Sky_VS();
		PixelShader = compile ps_3_0 Sky_PS();
	}
}

