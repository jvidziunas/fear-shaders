#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\depthencode.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float3	Normal		: NORMAL;
    float2	TexCoord	: TEXCOORD0;
    float4	Color		: COLOR0;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a flat emissive material that is not affected by lighting");
DECLARE_DOCUMENATION("Shaders\\Docs\\emissive\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tEmissiveMap, 0, 0, "", true, "Emissive map of the material. This represents the color of the emissive contribution.");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sEmissiveMapSampler, tEmissiveMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

// Fetch the material Emissive color at a texture coordinate
float4 GetMaterialEmissive(float2 vCoord)
{
	return tex2D(sEmissiveMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Emissive (Ambient)
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0_centroid;
	float4 Color	: COLOR0;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	
	OUT.Position	= TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord	= IN.TexCoord;
	OUT.Color	= IN.Color;
	
	return OUT;
}

float4 Ambient_PS(PSData_Ambient IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	vResult.xyz = GetMaterialEmissive(IN.TexCoord).xyz * IN.Color.xyz;
	
	return vResult;
}

technique Ambient
{
	pass Draw
	{
		AlphaTestEnable = False;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Ambient_VS();
		PixelShader = compile ps_3_0 Ambient_PS();
	}
}

// Depth encoding support
ENCODE_DEPTH_DEFAULT(MaterialVertex)
