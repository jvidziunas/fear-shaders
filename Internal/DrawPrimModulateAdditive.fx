#include "drawprimbasedefs.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct DrawPrimVertex
{
    float3	Position	: POSITION;
	float4	Color	: COLOR0;
    float2	TexCoord	: TEXCOORD0;
};

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------
// Translucent Pass 1: Diffuse with the global translucent color
struct PSData_Translucent 
{
	float4 Position		: POSITION;
	float2 DiffuseTexCoord	: TEXCOORD0;
	float4 Color			: COLOR0;
};

PSData_Translucent Translucent_VS(DrawPrimVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position			= mul(mDrawPrimToClip, float4(IN.Position, 1.0f));
	OUT.DiffuseTexCoord	= IN.TexCoord;
	OUT.Color			= IN.Color;
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	return LinearizeAlpha(tex2D(sDrawPrimTextureWrap, IN.DiffuseTexCoord)) * IN.Color;
}

//----------------------------------------------------------------------------
// Translucent Technique
technique Translucent 
{
	pass p0 
	{
		AlphaBlendEnable	= true;
		SrcBlend			= SrcAlpha;
		DestBlend		= One;
		GAMMA_CORRECT_WRITE;

		VertexShader		= compile vs_3_0 Translucent_VS();
		PixelShader		= compile ps_3_0 Translucent_PS();
	}
}

