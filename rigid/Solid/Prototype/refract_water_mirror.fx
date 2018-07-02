#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\depthencode.fxh"
#include "..\..\..\sdk\transforms.fxh"

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
DECLARE_DESCRIPTION("Water shader, based on refract_water, for use with mirror render targets.");
DECLARE_DOCUMENATION("Shaders\\Docs\\refract_water\\main.htm");
DECLARE_PARENT_MATERIAL(0, "refract_water_mirror_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fRefractScale, 0.03, "Refraction scale");
// Maximum depth of the water
MIPARAM_FLOAT(fWaterDepth, 20, "Water depth");
// Index of refraction
MIPARAM_FLOAT(fIndexOfRefraction, 0.75, "Index of refraction");
// Offset scaling amount for reflections
MIPARAM_FLOAT(fReflectScale, 0.2, "Reflection scale");
// Reflection plane direction
MIPARAM_VECTOR(vReflectionPlane, 0.0, 1.0, 0.0, "Reflection plane direction");

// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light refracted");
MIPARAM_TEXTURE(tReflectionMap, 0, 2, "", false, "Reflection map of the material. This should be set as the texture replaced with the mirror render target object.");
MIPARAM_TEXTURE(tRefractionMap, 0, 3, "", false, "Refraction map of the material. This should be set as the texture replaced with the refraction render target object.");
MIPARAM_TEXTURE(tFresnelTable, 0, 4, "", false, "Fresnel look-up table. This is used to determine the amount of reflection to apply based on the viewing angle.");

//the samplers for those textures
SAMPLER_WRAP(sDiffuseMapSampler, tDiffuseMap);
//SAMPLER_CLAMP(sReflectionMapSampler, tReflectionMap);
sampler sReflectionMapSampler = sampler_state
{
	texture = <tReflectionMap>;
	AddressU = Clamp;
	AddressV = Clamp;
	MagFilter = Linear;
	SRGBTexture = true;
};
sampler sRefractionMapSampler = sampler_state
{
	texture = <tRefractionMap>;
	AddressU = Clamp;
	AddressV = Clamp;
	MagFilter = Linear;
	SRGBTexture = true;
};
SAMPLER_CLAMP_LINEAR(sFresnelTableSampler, tFresnelTable);

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

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float2 vCoord)
{
	return tex2D(sDiffuseMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 ScreenCoord : TEXCOORD1;
	float4 RefractOfs : TEXCOORD2;
	float4 ReflectPos : TEXCOORD3;
	float3 EyeVector : TEXCOORD4;
	float  Flip : TEXCOORD5;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.z = OUT.ScreenCoord.z / fWaterDepth;
	OUT.Flip = dot(vReflectionPlane, vObjectSpaceEyePos);
	float3 vEyePos = vObjectSpaceEyePos;
	if (OUT.Flip < 0.0)
		vEyePos = reflect(vEyePos, vReflectionPlane);
	float3 vEyeVector = GetPosition(IN) - vEyePos;

	float3 vRefract = refract(normalize(vEyeVector), IN.Normal, fIndexOfRefraction);
	
	float3 vTransformedNormal = mul(mObjectToClip, vRefract - normalize(vEyeVector));
	OUT.RefractOfs = float4(vTransformedNormal.xy, 0,0);
	OUT.RefractOfs *= OUT.ScreenCoord.w;
	
	// Eye vector in tangent space, used by the fresnel table
	OUT.EyeVector = mul(GetInverseTangentSpace(IN), -vEyeVector);
	
	// Get the reflection sampling offset
	float4 vReflectClipOffset = mul(mObjectToClip, IN.Normal - vReflectionPlane);
	float4 vReflectOffset = float4(vReflectClipOffset.xy * fReflectScale * OUT.ScreenCoord.w, 0,0);
	
	// Location to sample the reflection map
	OUT.ReflectPos = OUT.ScreenCoord + vReflectOffset;
	OUT.ReflectPos.x = OUT.ReflectPos.w - OUT.ReflectPos.x;
	
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	// Sample the front map
	float fFront = IN.ScreenCoord.z;
	// Sample the back map
	float fBack = DecodeDepth(tex2Dproj(sDepthMapSampler, IN.ScreenCoord));
	// Get the difference
	float fDepth = saturate(fBack / fWaterDepth - fFront);
	
	// Get the texture sampling offset
	float fScale = fDepth * fRefractScale;
	float4 vOffset = IN.RefractOfs * float4(fScale, -fScale, 1,1);

	float4 vFinalCoord = IN.ScreenCoord + vOffset;
	
	if (IN.Flip > 0)
		vResult = tex2Dproj(sRefractionMapSampler, vFinalCoord);
	else
		vResult = tex2Dproj(sReflectionMapSampler, vFinalCoord);
	
	vResult *= GetMaterialDiffuse(IN.TexCoord);
	

	float3 vReflect;
	if (IN.Flip > 0)
		vReflect = tex2Dproj(sReflectionMapSampler, IN.ReflectPos);
	else
		vReflect = tex2Dproj(sRefractionMapSampler, IN.ReflectPos);

	// Do a lookup in the fresnel table to calculate the reflection opacity
	float fFresnel = tex1D(sFresnelTableSampler, normalize(IN.EyeVector).z);
	
	vResult.xyz = lerp(vResult.xyz, vReflect, fFresnel);
	
	return vResult;
}

technique FogVolume_Blend
{
	pass Draw
	{
		CullMode = None;
		AlphaBlendEnable = False;
		ZEnable = True;
		ZFunc = Less;
		ZWriteEnable = True;
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

