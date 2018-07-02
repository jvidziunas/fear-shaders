#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\curframemap.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float2	TexCoord	: TEXCOORD0;
#ifndef SKELETAL_MATERIAL
	float4	Color		: COLOR0;
#endif
    float3	Normal		: NORMAL; 
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a blur material. Objects behind this material will be blurry.  Per-pixel control over the blur amount is disabled on DX8 hardware.");
DECLARE_DOCUMENATION("Shaders\\Docs\\blur\\main.htm");
DECLARE_PARENT_MATERIAL(0, "blur_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// Kernel size for the blur
MIPARAM_FLOAT(fBlurScale, 1.5, "Blur kernel size");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light refracted");

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
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position 		: POSITION;
#ifndef SKELETAL_MATERIAL
	float4 Color			: COLOR0;
#endif
	float2 TexCoord			: TEXCOORD0_centroid;
	float4 ScreenCoord		: TEXCOORD2_centroid;
	float2 ResMultiplier	: TEXCOORD3;
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
	OUT.ResMultiplier = (vScene_ScreenRes.x / 800) / vScene_ScreenRes;

	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
#ifndef SKELETAL_MATERIAL
	float4 vResult = float4(0,0,0,IN.Color.w);
#else
	float4 vResult = float4(0,0,0,1);
#endif

	float4 vDiffuse = GetMaterialDiffuse(IN.TexCoord);

	float2 vOffset = (fBlurScale * vDiffuse.w) * IN.ResMultiplier;
	
	vResult.xyz += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0.707,0.707)).xyz;
	vResult.xyz += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0.707,-0.707)).xyz;
	vResult.xyz += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(-0.707,0.707)).xyz;
	vResult.xyz += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(-0.707,-0.707)).xyz;

	vResult.xyz += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0,1.0)).xyz;
	vResult.xyz += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0,-1.0)).xyz;
	vResult.xyz += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(1.0,0)).xyz;
	vResult.xyz += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(-1.0,0)).xyz;

	vResult.xyz /= 8.0;	

#ifndef SKELETAL_MATERIAL
	vResult.xyz *= vDiffuse.xyz * IN.Color.xyz;
#else
	vResult.xyz *= vDiffuse.xyz;
#endif
	
	return vResult;
}

technique Translucent
{
	pass Draw
	{
		AlphaBlendEnable = True;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

