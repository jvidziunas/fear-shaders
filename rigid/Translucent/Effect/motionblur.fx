#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\lastframemap.fxh"
#include "..\..\..\sdk\curframemap.fxh"

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
    float3	Normal		: NORMAL; 
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is the motion blur material, which will cause objects behind it to persist over multiple frames.  This material will fall back to the refract material on DX8 hardware.");
DECLARE_DOCUMENATION("Shaders\\Docs\\motionblur\\main.htm");
DECLARE_PARENT_MATERIAL(0, "refract_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fBlur, 0.9, "Blur amount");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light refracted");

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
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position : POSITION;
#ifndef SKELETAL_MATERIAL
	float4 Color : COLOR0;
#endif
	float2 TexCoord : TEXCOORD0;
	float4 ScreenCoord : TEXCOORD2;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
#ifndef SKELETAL_MATERIAL
	OUT.Color = IN.Color;
#endif
	OUT.TexCoord = IN.TexCoord;
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);

	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float4 vDiffuse = GetMaterialDiffuse(IN.TexCoord);
	float4 vFrame = tex2Dproj(sCurFrameMapSampler, IN.ScreenCoord);
	float4 vLastFrame = tex2Dproj(sLastFrameMapSampler, IN.ScreenCoord);

#ifndef SKELETAL_MATERIAL
	float4 vVertexColor = IN.Color;
#else
	float4 vVertexColor = float4(1,1,1,1);
#endif
	
	float4 vBlend = float4(lerp(vFrame.xyz, vLastFrame.xyz, fBlur * vDiffuse.w), vVertexColor.w);
	vBlend.xyz *= vDiffuse.xyz * vVertexColor.xyz;
	
	return vBlend;
}

technique Translucent
{
	pass Draw
	{
		AlphaBlendEnable = True;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

