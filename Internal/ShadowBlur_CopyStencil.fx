#include "..\sdk\basedefs.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is an internal shader related to the shadow blur implementation.");

//////////////////////////////////////////////////////////////////////////////
// Main shader
//////////////////////////////////////////////////////////////////////////////

float4 PassThrough_VS(float3 iPos : POSITION) : POSITION
{
	return float4(iPos, 1.0);
}

float4 White_PS() : COLOR
{
	return 1.0;
}

float4 Black_PS() : COLOR
{
	return 0.0;
}

vertexshader vsPassthrough = compile vs_3_0 PassThrough_VS();

technique Translucent
{
	pass White
	{
		VertexShader = <vsPassthrough>;
		PixelShader = compile ps_3_0 White_PS();
	}
	pass Black
	{
		StencilFunc = NotEqual;
		VertexShader = <vsPassthrough>;
		PixelShader = compile ps_3_0 Black_PS();
	}
}
