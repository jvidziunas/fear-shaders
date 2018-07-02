#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\lightdefs.fxh"
#include "..\..\sdk\time.fxh"
#include "..\..\sdk\object.fxh"

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
    float2	TexCoord2	: TEXCOORD1;
    
    DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This material is intended for cloud rendering.  It has two textures, which modulate both color and alpha, one of which includes UV panning.  NOTE: This shader will not be affected by lighting.");
DECLARE_DOCUMENATION("Shaders\\Docs\\clouds\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the main color of the clouds");
MIPARAM_TEXTURE(tControlMap, 1, 1, "", false, "Control map for determining how thick and what color the clouds will be");

MIPARAM_FLOAT(fPanSpeedU, 0, "Diffuse texture panning speed in the U direction");
MIPARAM_FLOAT(fPanSpeedV, 0, "Diffuse texture panning speed in the V direction");
MIPARAM_VECTOR4(vBaseColor, 1, 1, 1, 1, "Base cloud color & alpha");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP(sControlMapSampler, tControlMap);

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

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialControl(float2 vCoord)
{
	return tex2D(sControlMapSampler, vCoord);
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
	float2 ControlTexCoord	: TEXCOORD1_centroid;
	float4 Color			: COLOR0;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position		= TransformToClipSpace(GetPosition(IN));
	float2 vPan = fTime * float2(fPanSpeedU, fPanSpeedV);
	OUT.DiffuseTexCoord = IN.TexCoord + vPan;
	OUT.ControlTexCoord = IN.TexCoord2;
#ifndef SKELETAL_MATERIAL
	OUT.Color			= IN.Color * vBaseColor * vObjectColor;
#else
	OUT.Color			= vBaseColor * vObjectColor;
#endif
	return OUT;
}

PSOutput Translucent_PS(PSData_Translucent IN)
{
	PSOutput OUT;

	float4 vDiffuseColor = GetMaterialDiffuse(IN.DiffuseTexCoord) * GetMaterialControl(IN.ControlTexCoord) * IN.Color;
	OUT.Color = LinearizeAlpha(vDiffuseColor);
	
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
		DestBlend	= InvSrcAlpha;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

