#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\lightdefs.fxh"
#include "..\..\sdk\dx9lights.fxh"
#include "..\..\sdk\screencoords.fxh"
#include "..\..\sdk\texnormalize.fxh"
#include "..\..\sdk\curframemap.fxh"

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
DECLARE_DESCRIPTION("This is the exterior neon shader.");
DECLARE_DOCUMENATION("Shaders\\Docs\\neon_outside\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// float parameters
MIPARAM_FLOAT(fBlurScale, 3.0, "Blur amount");
MIPARAM_FLOAT(fNearBlur, 100.0, "Distance at which blur reaches maximum");
MIPARAM_FLOAT(fFarBlur, 300.0, "Distance at which blur reaches minimum");
MIPARAM_FLOAT(fFakeLighting, 0.125, "Amount of false viewer-oriented lighting to introduce.  This makes geometry more pronounced.");
MIPARAM_FLOAT(fBlurContribution, 0.5, "Contribution of the blurred interior portion to the pre-glow result.");
MIPARAM_FLOAT(fEmissiveContribution, 0.6, "Contribution of the emissive texture to the pre-glow result.");
MIPARAM_FLOAT(fGlowOverridePrevention, 0.25, "Amount of glow reduction based on viewing angle.  This prevents the interior portion from being overpowered by the glow on the exterior portion.");

// the textures exported for the user
MIPARAM_TEXTURE(tEmissiveMap, 0, 0, "", true, "Emissive map");
SAMPLER_WRAP(sEmissiveMapSampler, tEmissiveMap);
MIPARAM_TEXTURE(tGlowMap, 0, 1, "", false, "Glow map");
SAMPLER_WRAP(sGlowMapSampler, tGlowMap);

//--------------------------------------------------------------------
// Utility functions

float3x3 GetInverseTangentSpace(MaterialVertex Vert)
{
	return GetInverseTangentSpace(	SKIN_VECTOR(Vert.Tangent, Vert), 
									SKIN_VECTOR(Vert.Binormal, Vert), 
									SKIN_VECTOR(Vert.Normal, Vert));
}

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

// Fetch the material specular color at a texture coordinate
float4 GetMaterialGlow(float2 vCoord)
{
	return tex2D(sGlowMapSampler, vCoord);
}

// Fetch the material emissive color at a texture coordinate
float4 GetMaterialEmissive(float2 vCoord)
{
	return tex2D(sEmissiveMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

float4 Ambient_VS(MaterialVertex IN) : POSITION
{
	return TransformToClipSpace(GetPosition(IN));
}

technique Ambient
{
	pass Draw
	{
		CullMode = CW;
		VertexShader = compile vs_3_0 Ambient_VS();
		// Black fill so we don't blur what's behindthe volume.
		TextureFactor = 0;
		ColorArg1[0] = TFactor;
		ColorOp[0] = SelectArg1;
		AlphaArg1[0] = TFactor;
		AlphaOp[0] = SelectArg1;
		ColorOp[1] = Disable;
		AlphaOp[1] = Disable;
		sRGBWriteEnable = TRUE;
	}
}

//////////////////////////////////////////////////////////////////////////////
// Translucent - Blur whatever's inside the volume & add in the exterior color
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float3 EyeVector : TEXCOORD1;
	float4 ScreenCoord : TEXCOORD2;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;

	float3 vLightVector;
	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, vLightVector, OUT.EyeVector);
	
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float4 vResult = float4(0,0,0,0);
	
	float fDistanceScale = 1.0 - saturate((IN.ScreenCoord.z - fNearBlur) / (fFarBlur - fNearBlur));
	float2 vOffset = fBlurScale/vScene_ScreenRes * fDistanceScale;
	
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0.707,0.707));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0.707,-0.707));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(-0.707,0.707));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(-0.707,-0.707));

	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0,1.0));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0,-1.0));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(1.0,0));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(-1.0,0));

	vResult /= 8.0;	

	float fForwardScale = saturate(TexNormalizeVector(IN.EyeVector).z) * fFakeLighting + (1.0 - fFakeLighting);
	
	vResult.xyz = vResult.xyz * fBlurContribution + GetMaterialEmissive(IN.TexCoord).xyz * fForwardScale * fEmissiveContribution;
	
	return vResult;
}

technique Translucent
{
	pass Draw
	{
		AlphaBlendEnable = False;
		ZWriteEnable = True;
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}


