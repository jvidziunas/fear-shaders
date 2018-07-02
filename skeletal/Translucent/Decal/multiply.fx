#define SKELETAL_MATERIAL
#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\object.fxh"

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
DECLARE_DESCRIPTION("This material will blend a translucent object into the background using a multiplicative blend");
DECLARE_DOCUMENATION("Shaders\\Docs\\multiply\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;

// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light reflected");

//the samplers for those textures
SAMPLER_CLAMP(sDiffuseMapSampler, tDiffuseMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float4 vCoord)
{
	return tex2Dproj(sDiffuseMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------
// Translucent Pass 1: Diffuse with the global translucent color
struct PSData_Translucent 
{
	float4 Position : POSITION;
	float4 DiffuseTexCoord : TEXCOORD0;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position		= TransformToClipSpace(GetPosition(IN));
	float4x4 mFullTransform = mCustomTransform;
	OUT.DiffuseTexCoord = mul(mFullTransform, float4(IN.Position, 1.0));
	return OUT;
}

PSOutput Translucent_PS(PSData_Translucent IN)
{
	PSOutput OUT;
	
	//in order to support alpha, we need to blend to white as the the alpha approaches
	//zero
	float4 vDiffuse = GetMaterialDiffuse(IN.DiffuseTexCoord) * vObjectColor;
	float3 vBlended = (vDiffuse.rgb * vDiffuse.a + float3(1.0, 1.0, 1.0) * (1.0 - vDiffuse.a));

	OUT.Color = float4(vBlended, 1.0);

	/*
	OUT.Color = float4(1.0, 1.0, IN.DiffuseTexCoord.x + IN.DiffuseTexCoord.y, 1.0);
	OUT.Color *= float4(IN.DiffuseTexCoord.x > 0 ? 1 : 0, IN.DiffuseTexCoord.y > 0 ? 1 : 0, 1.0, 1.0);
	OUT.Color *= float4(IN.DiffuseTexCoord.x < 1 ? 1 : 0, IN.DiffuseTexCoord.y < 1 ? 1 : 0, 1.0, 1.0);
	//*/
	/*
	float circle = length(IN.DiffuseTexCoord.xy * 2.0 - 1.0);
	OUT.Color = float4(IN.DiffuseTexCoord.x * 2 - 1, IN.DiffuseTexCoord.y * 2 - 1, sin(circle * 3.14159265), circle < 1.0 ? 1.0 : 0.0);
	//*/
	return OUT;
}

//----------------------------------------------------------------------------
// Translucent Technique
technique Translucent 
{
	pass p0 
	{
		CullMode = None;
		//*
		SrcBlend	= Zero;
		DestBlend	= SrcColor;
		//*/
	
		/*	
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		//*/
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

