#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\noise.fxh"
#include "..\..\..\sdk\time.fxh"
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
DECLARE_DESCRIPTION("Material for rendering volumetric lighting slices including noise and shadows.");
DECLARE_DOCUMENATION("Shaders\\Docs\\additive\\main.htm");

//--------------------------------------------------------------------
// Material parameters

// the textures exported for the user
MIPARAM_TEXTURE(tCookieMap, 0, 1, "", false, "Cookie texture - Initialized at runtime");
MIPARAM_TEXTURE(tAttenuationMap, 0, 2, "", false, "Attenuation texture - Initialized at runtime");
MIPARAM_TEXTURE(tVLDepthMap, 0, 3, "", false, "Depth map - Initialized at runtime");
MIPARAM_FLOAT(fDepthScale, 1.0, "Depth Scale - Initialized at runtime");
MIPARAM_FLOAT(fNoiseScale, 1.0, "Noise Scale - Initialized at runtime");
MIPARAM_FLOAT(fNoiseIntensity, 0.5, "Noise Intensity - Initialized at runtime");
MIPARAM_FLOAT(fDistanceAttenuationScale, 1.0, "Distance Attenuation Scale - Initialized at runtime");

//the samplers for those textures
SAMPLER_CLAMP(sCookieMapSampler, tCookieMap);
SAMPLER_CLAMP_LINEAR(sAttenuationMapSampler, tAttenuationMap);
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

//----------------------------------------------------------------------------
// Translucent Pass 1: Diffuse with the global translucent color
struct PSData_Translucent 
{
	float4 Position : POSITION;
	float4 LightPos : TEXCOORD0;
	float4 Color : TEXCOORD1;
	float4 NoisePos : TEXCOORD2;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position	= TransformToClipSpace(GetPosition(IN));
	OUT.LightPos	= IN.LightPos;
	OUT.Color		= IN.Color;

	float fTime_Wave = sin(fTime * 3.1415926535 / 5.0);
	OUT.NoisePos	= float4(IN.LightPos.x, IN.LightPos.y, IN.LightPos.z - fTime_Wave * 0.2, IN.LightPos.w) / (float4(40,40,10.0,1) * fNoiseScale);

	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	half4 vResult;
	
	float fTime_Wave = sin(fTime * 3.1415926535 / 5.0);
	
	float intensity = tex2Dproj(sCookieMapSampler, IN.LightPos).w;

	float4 noise1 = Noise(float3(IN.NoisePos.xy / IN.NoisePos.w, IN.NoisePos.z), 1.0, 2, 0);
	float4 noise2 = Noise(noise1.xyz / 100.0 + float3(sin(fTime_Wave + noise1.y), cos(fTime_Wave + noise1.x), noise1.w) * 0.5, 2.0, 2, 0);
	intensity *= noise2.x * fNoiseIntensity + 1.0;

	float depth = DecodeDepth(tex2Dproj(sVLDepthMapSampler, IN.LightPos)) / fScene_FarZ * fDepthScale;
	if (depth < IN.LightPos.z)
		intensity = 0;
		
	vResult.xyzw = intensity * IN.Color;

	half fDistance = IN.LightPos.z * fDistanceAttenuationScale;
	half fAttenuation = tex1D(sAttenuationMapSampler, fDistance).x;
	vResult.xyzw *= fAttenuation;
	
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

