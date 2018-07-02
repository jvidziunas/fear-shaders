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
    float3	Normal		: NORMAL; 
    float2	TexCoord	: TEXCOORD0;
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a blur shader that uses feedback to achieve extra blur over multiple frames.");
DECLARE_DOCUMENATION("Shaders\\Docs\\feedbackblur\\main.htm");
DECLARE_PARENT_MATERIAL(0, "refract_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// Kernel size for the blur
MIPARAM_FLOAT(fBlurScale, 1.5, "Blur kernel size");
MIPARAM_FLOAT(fCenterWeight, 0.08, "Center pixel weight");
// the textures exported for the user
MIPARAM_TEXTURE(tDEditMap, 0, 0, "", true, "Convenience texture for identifying polygons with this material.");

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0_centroid;
	float4 ScreenCoord	: TEXCOORD1_centroid;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);

	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	float2 vOffset = fBlurScale / vScene_ScreenRes;
	
	vResult = tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w) * fCenterWeight;
	vResult += tex2D(sLastFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + float2(vOffset.x, 0));
	vResult += tex2D(sLastFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + float2(-vOffset.x, 0));
	vResult += tex2D(sLastFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + float2(0, vOffset.y));
	vResult += tex2D(sLastFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + float2(0, -vOffset.y));
	vResult /= 4 + fCenterWeight;
	
	return vResult;
}

technique Translucent
{
	pass Draw
	{
		AlphaBlendEnable = False;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

