#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\depthencode.fxh"


//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float3	Normal		: NORMAL; 
    float2	TexCoord	: TEXCOORD0;
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a mirror shader.  It is intended for use with mirror rendertargets.");
DECLARE_DOCUMENATION("Shaders\\Docs\\mirror\\main.htm");
DECLARE_PARENT_MATERIAL(0, "mirror_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;

// Kernel size for the blur
MIPARAM_FLOAT(fBlurScale, 1.5, "Blur kernel size");

// the textures exported for the user
MIPARAM_TEXTURE(tMirrorMap, 0, 0, "", true, "The mirror texture to be used. This should be set as the texture replaced with the mirror render target object.");
MIPARAM_TEXTURE(tTintMap, 0, 0, "", false, "This texture will modulate the mirror texture, allowing for parts of the mirror to be tinted.");

//the samplers for those textures
SAMPLER_WRAP(sMirrorMapSampler, tMirrorMap);
SAMPLER_WRAP_LINEAR(sTintMapSampler, tTintMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialTint(float2 vCoord)
{
	return tex2D(sTintMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 ScreenCoord : TEXCOORD2;
	float2 BlurScale : TEXCOORD3;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.BlurScale = fBlurScale * (vScene_ScreenRes.x / 800) / vScene_ScreenRes;

	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float4 vResult = float4(0, 0, 0, 0);
	float2 vOffset = IN.BlurScale * GetMaterialTint(IN.TexCoord).w;	
	
	float2 vCenter;
	vCenter.x = -IN.ScreenCoord.x / IN.ScreenCoord.w;
	vCenter.y = IN.ScreenCoord.y / IN.ScreenCoord.w;
	
	vResult += tex2D(sMirrorMapSampler, vCenter + vOffset * float2(0.707,0.707));
	vResult += tex2D(sMirrorMapSampler, vCenter + vOffset * float2(0.707,-0.707));
	vResult += tex2D(sMirrorMapSampler, vCenter + vOffset * float2(-0.707,0.707));
	vResult += tex2D(sMirrorMapSampler, vCenter + vOffset * float2(-0.707,-0.707));

	vResult += tex2D(sMirrorMapSampler, vCenter + vOffset * float2(0,1.0));
	vResult += tex2D(sMirrorMapSampler, vCenter + vOffset * float2(0,-1.0));
	vResult += tex2D(sMirrorMapSampler, vCenter + vOffset * float2(1.0,0));
	vResult += tex2D(sMirrorMapSampler, vCenter + vOffset * float2(-1.0,0));

	vResult /= 8.0;	

	vResult.xyz *= GetMaterialTint(IN.TexCoord).xyz;
	vResult.w   = GetLightDiffuseColor().a;
	
	return vResult;
}

technique Translucent
{
	pass Draw
	{
		sRGBWriteEnable = TRUE;
		SrcBlend	= SrcAlpha;
		DestBlend	= InvSrcAlpha;
		
		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

technique Ambient
{
	pass Draw
	{
		sRGBWriteEnable = TRUE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

// Depth encoding support
ENCODE_DEPTH_DEFAULT(MaterialVertex)
