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
#ifndef SKELETAL_MATERIAL
	float4	Color		: COLOR0;
#endif
    float2	TexCoord	: TEXCOORD0;
    
    DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This material will interpolate between the diffuse texture of this object and the scene already rendered.");
DECLARE_DOCUMENATION("Shaders\\Docs\\translucent\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light reflected");

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
	return LinearizeAlpha( tex2D(sDiffuseMapSampler, vCoord) );
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------
// Translucent Pass 1: Diffuse with the global translucent color
struct PSData_Translucent 
{
	float4 Position		: POSITION;
	float2 DiffuseTexCoord	: TEXCOORD0_centroid;
#ifndef SKELETAL_MATERIAL
	float4 Color			: COLOR0;
#endif
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position		= TransformToClipSpace(GetPosition(IN));
	OUT.DiffuseTexCoord = IN.TexCoord;
#ifndef SKELETAL_MATERIAL
	OUT.Color			= IN.Color;
#endif
	return OUT;
}

PSOutput Translucent_PS(PSData_Translucent IN)
{
	PSOutput OUT;

#ifndef SKELETAL_MATERIAL
	float4 vDiffuseColor = GetMaterialDiffuse(IN.DiffuseTexCoord) * IN.Color;
#else
	float4 vDiffuseColor = GetMaterialDiffuse(IN.DiffuseTexCoord);
#endif
	OUT.Color = LinearizeAlpha( GetLightDiffuseColor() * vDiffuseColor );
	
	return OUT;
}

//----------------------------------------------------------------------------
// Translucent Technique
technique Translucent 
{
	pass p0 
	{
		CullMode		= CCW;
		SrcBlend		= SrcAlpha;
		DestBlend	= InvSrcAlpha;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

