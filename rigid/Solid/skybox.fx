#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\object.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float3	Normal		: NORMAL;
    float2	TexCoord	: TEXCOORD0;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a version of the sky material that uses a cube map projection for the texture coordinates.");
DECLARE_DOCUMENATION("Shaders\\Docs\\skybox\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the sky.");
MIPARAM_VECTOR(vTintColor, 1.0f, 1.0f, 1.0f, "This is a color that will be multiplied by the skybox color to allow for controlling the color of the sky");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float3 vCoord)
{
	return texCUBE(sDiffuseMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Translucent (sky)
//////////////////////////////////////////////////////////////////////////////

struct PSData_Sky
{
	float4 Position : POSITION;
	float3 TexCoord : TEXCOORD0_centroid;
};

PSData_Sky Sky_VS(MaterialVertex IN)
{
	PSData_Sky OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = -IN.Normal;
	return OUT;
}

float4 Sky_PS(PSData_Sky IN) : COLOR
{
	float4 vResult = float4( 0, 0, 0, 1 );

	vResult.xyz = GetMaterialDiffuse(IN.TexCoord) * LinearizeColor( vTintColor ) * vObjectColor;
	
	return vResult;
}

technique Ambient
{
	pass Draw
	{
		AlphaTestEnable = False;
		SrcBlend = One;
		DestBlend = Zero;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Sky_VS();
		PixelShader = compile ps_3_0 Sky_PS();
	}
}

