#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\lightdefs.fxh"
#include "..\..\sdk\texnormalize.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float2	TexCoord	: TEXCOORD0;
    float3	Normal		: NORMAL; 
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;
    
    DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This provides translucent support where the color is determined by taking the angle between the surface normal and the direction to the camera and looking up into an attenuation map.");
DECLARE_DOCUMENATION("Shaders\\Docs\\spectral\\main.htm");
DECLARE_PARENT_MATERIAL(0, "additive.fx");

//--------------------------------------------------------------------
// Material parameters

// the textures exported for the user
MIPARAM_SURFACEFLAGS;
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "The diffuse map of the shader. This controls the overall tint of the color across different parts of the model. The alpha channel is used to control the overall opacity of the model.");
MIPARAM_TEXTURE(tNormalMap, 0, 1, "", false, "The normal map to use for this geometry.");
MIPARAM_TEXTURE(tAttenuationMap, 0, 2, "", false, "This map controls the color of the object as the normal turns away from the light. This is a 1d texture laid out horizontally so that x=0 is when the normal is looking at the eye, and x=0.5 is when the eye is perpindicular, and x=1 is when the normal is facing away");

//the samplers for those textures
SAMPLER_WRAP(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP_LINEAR(sNormalMapSampler, tNormalMap);
SAMPLER_CLAMP_LINEAR(sAttenuationMapSampler, tAttenuationMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

float3x3 GetInverseTangentSpace(MaterialVertex Vert)
{
	return GetInverseTangentSpace(	SKIN_VECTOR(Vert.Tangent, Vert), 
									SKIN_VECTOR(Vert.Binormal, Vert), 
									SKIN_VECTOR(Vert.Normal, Vert));
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------
// Translucent Pass 1: Diffuse with the global translucent color
struct PSData_Translucent 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float3 EyeVector	: TEXCOORD1;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	float3 vPosition	= GetPosition(IN);
	float3 vEyeOffset	= normalize(vObjectSpaceEyePos - vPosition);

	PSData_Translucent OUT;
	
	OUT.Position	= TransformToClipSpace(vPosition);
	OUT.TexCoord	= IN.TexCoord;
	OUT.EyeVector	= mul(GetInverseTangentSpace(IN), vEyeOffset);
	
	return OUT;
}

PSOutput Translucent_PS(PSData_Translucent IN)
{
	PSOutput OUT;

	//get the unit surface normal, and the unit eye vector to determine the dot product between them
	float3 vUnitSurface = normalize(tex2D(sNormalMapSampler, IN.TexCoord).xyz - 0.5);
	float3 vUnitEye		= TexNormalizeVector(IN.EyeVector);
	
	//determine the dot product between the two which will be used to look up into our attenuation texture
	float fEyeDotSurface = dot(vUnitEye, vUnitSurface);
	
	//determine the actual texture coordinate to lookup (should be 0-1)
	float fTexCoord = 1.0 - clamp(fEyeDotSurface, 0.0, 1.0);
	
	//now look up our attenuation texture and our diffuse map. Our final result is the product of the two
	float4 vDiffuse = tex2D(sDiffuseMapSampler, IN.TexCoord);
	float4 vAttenuation = tex1D(sAttenuationMapSampler, fTexCoord);	

	OUT.Color = vAttenuation * vDiffuse;
	
	return OUT;
}

//----------------------------------------------------------------------------
// Translucent Technique
technique Translucent 
{
	pass p0 
	{
		CullMode	= CCW;
		SrcBlend	= SrcAlpha;
		DestBlend	= One;
		sRGBWriteEnable = TRUE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}
