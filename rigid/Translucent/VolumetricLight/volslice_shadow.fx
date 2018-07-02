#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\depthencode.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
	float4	Color		: COLOR0;
    float4	LightPos	: TEXCOORD0;
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("Material for rendering volumetric lighting slices including shadows.");
DECLARE_DOCUMENATION("Shaders\\Docs\\additive\\main.htm");

//--------------------------------------------------------------------
// Material parameters

// the textures exported for the user
MIPARAM_TEXTURE(tCookieMap, 0, 1, "", false, "Cookie texture - Initialized at runtime");
MIPARAM_TEXTURE(tVLDepthMap, 0, 2, "", false, "Depth map - Initialized at runtime");
MIPARAM_FLOAT(fDepthScale, 1.0, "Depth Scale - Initialized at runtime");
MIPARAM_FLOAT(fDistanceAttenuationScale, 1.0, "Distance Attenuation Scale - Initialized at runtime");

//the samplers for those textures
SAMPLER_CLAMP(sCookieMapSampler, tCookieMap);
SAMPLER_CLAMP_POINT_LINEAR(sVLDepthMapSampler, tVLDepthMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return Vert.Position;
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position : POSITION;
	float4 LightPos : TEXCOORD0;
	float4 Color : TEXCOORD1;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position	= TransformToClipSpace(GetPosition(IN));
	OUT.LightPos	= IN.LightPos;
	OUT.Color		= IN.Color;
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	half4 vResult;
	
	float intensity = tex2Dproj(sCookieMapSampler, IN.LightPos).w;

	float depth = DecodeDepth(tex2Dproj(sVLDepthMapSampler, IN.LightPos)) / fScene_FarZ * fDepthScale;
	if (depth < IN.LightPos.z)
		intensity = 0;
		
	vResult.xyzw = intensity * IN.Color;

	half fDistance = saturate(length(half3(IN.LightPos.xy / IN.LightPos.w - 0.5, IN.LightPos.z)) * fDistanceAttenuationScale);
	half fAttenuation = (1.0 - fDistance * fDistance);
	vResult.xyzw *= fAttenuation * fAttenuation;
	
	return vResult;
}

//----------------------------------------------------------------------------
// Translucent Technique
technique Translucent 
{
	pass p0 
	{
		CullMode			= None;
		AlphaBlendEnable	= True;
		sRGBWriteEnable		= TRUE;
		SrcBlend			= One;
		DestBlend			= One;
		FogColor			= 0;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

