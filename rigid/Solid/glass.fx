#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\dx9lights.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\object.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float3	Normal	: NORMAL; 
    float2	TexCoord	: TEXCOORD0;
	float3	Tangent	: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a glass material based on the default specular material. This allows specification of a diffuse, specular, and normal map. In addition, for DX9 level cards and higher it allows for specifying a maximum specular power.  The alpha channel of the specular map will then represent how glossy the surface is, ranging from black which is zero, to white which is the specified number. The higher the number, the shinier the surface.");
DECLARE_DOCUMENATION("Shaders\\Docs\\glass\\main.htm");
DECLARE_PARENT_MATERIAL(0, "glass_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fMaxSpecularPower, 64, "Maximum specular power. This scales the gloss map so that bright white is the specified power");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light reflected");
MIPARAM_TEXTURE(tSpecularMap, 0, 1, "", false, "Specular map of the material. This represents the color of light bounced off the surface");
MIPARAM_TEXTURE(tNormalMap, 0, 2, "", false, "Normal map of the material. This represents the normal of each point on the surface");

//the samplers for those textures
SAMPLER_WRAP(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP(sSpecularMapSampler, tSpecularMap);
// Note : Normal maps should have at least trilinear filtering
sampler sNormalMapSampler = sampler_state
{
	texture = <tNormalMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	MipFilter = Linear;
};

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

// Fetch the surface normal at a texture coordinate
float3 GetSurfaceNormal(float2 vCoord)
{
	return ColorToUnitVector(tex2D(sNormalMapSampler, vCoord).xyz);
}

float3 GetSurfaceNormal_Unit(float2 vCoord)
{
	return normalize(GetSurfaceNormal(vCoord));
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float2 vCoord)
{
	return tex2D(sDiffuseMapSampler, vCoord) * vObjectColor;
}

// Fetch the material specular color at a texture coordinate
float4 GetMaterialSpecular(float2 vCoord)
{
	return tex2D(sSpecularMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Ambient (Doesn't get to do ambient)
//////////////////////////////////////////////////////////////////////////////

technique Ambient
{
}

//////////////////////////////////////////////////////////////////////////////
// Point light
//////////////////////////////////////////////////////////////////////////////

struct PSData_Point 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float3 LightVector	: TEXCOORD1;
	float3 EyeVector	: TEXCOORD2;
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	return OUT;
}

float4 Point_PS(PSData_Point IN) : COLOR
{
	IN.LightVector.z = abs(IN.LightVector.z);
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
		GetLightDiffuseColor().xyz, GetLightSpecularColor(), fMaxSpecularPower);
}

technique Point
{
	pass Draw
	{
		AdaptiveTess_X = 0;		
		ZFunc = LessEqual;
		StencilEnable = False;
		SrcBlend = One;
		sRGBWriteEnable = TRUE;
		VertexShader = compile vs_3_0 Point_VS();
		PixelShader = compile ps_3_0 Point_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Point Fill light
//////////////////////////////////////////////////////////////////////////////

struct PSData_PointFill
{
	float4 Position							: POSITION;
	float2 TexCoord							: TEXCOORD0;
	float3 EyeVector							: TEXCOORD1;
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD2;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	//GetPointFillVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);
	GetPointFillVertexAttributesEye(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);
	return OUT;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	for (int loop = 0; loop < NUM_POINT_FILL_LIGHTS; ++loop)
		IN.LightVector[loop].z = abs(IN.LightVector[loop].z);
	return GetPointFillPixelColor(IN.LightVector, GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord));
}

technique PointFill
{
	pass Draw
	{	
		AdaptiveTess_X = 0;	
		ZFunc = LessEqual;
		StencilEnable = False;
		SrcBlend = One;
		sRGBWriteEnable = TRUE;
		VertexShader = compile vs_3_0 PointFill_VS();
		PixelShader = compile ps_3_0 PointFill_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Spot projector
//////////////////////////////////////////////////////////////////////////////

struct PSData_SpotProjector
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float3 LightVector	: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float4 LightMapCoord	: TEXCOORD3;
	float2 ClipPlanes		: TEXCOORD4;
};	

PSData_SpotProjector SpotProjector_VS(MaterialVertex IN) 
{
	PSData_SpotProjector OUT;

	float3 vPosition = GetPosition(IN);
	GetVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	// Lightmap coord sampling position
	OUT.LightMapCoord = GetSpotProjectorTexCoord(vPosition);
	 
	// Near/far plane clipping
	OUT.ClipPlanes = GetSpotProjectorClipInterpolants(vPosition);

	return OUT;
}

float4 SpotProjector_PS(PSData_SpotProjector IN) : COLOR
{
	IN.LightVector.z = abs(IN.LightVector.z);

	// Get the pixel
	float4 vPixelColor = GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
		DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord), DX9GetSpotProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);

	// Perform clipping
	return vPixelColor * DX9GetSpotProjectorClipResult(IN.ClipPlanes, IN.LightMapCoord);
}

technique SpotProjector
{
	pass Draw
	{
		AdaptiveTess_X = 0;
		ZFunc = LessEqual;
		StencilEnable = False;
		SrcBlend = One;
		sRGBWriteEnable = TRUE;

		VertexShader = compile vs_3_0 SpotProjector_VS();
		PixelShader = compile ps_3_0 SpotProjector_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Cube projector
//////////////////////////////////////////////////////////////////////////////

struct PSData_CubeProjector
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float3 LightVector	: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float3 LightMapCoord	: TEXCOORD3;
};	

PSData_CubeProjector CubeProjector_VS(MaterialVertex IN) 
{
	PSData_CubeProjector OUT;

	float3 vPosition = GetPosition(IN);
	GetVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	// Lightmap coord sampling position
	OUT.LightMapCoord = GetCubeProjectorTexCoord(vPosition);
	 
	return OUT;
}

float4 CubeProjector_PS(PSData_CubeProjector IN) : COLOR
{
	IN.LightVector.z = abs(IN.LightVector.z);
	// Get the pixel
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
		GetCubeProjectorDiffuseColor(IN.LightMapCoord), GetCubeProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);
}

technique CubeProjector
{
	pass Draw
	{
		AdaptiveTess_X = 0;		
		ZFunc = LessEqual;
		StencilEnable = False;
		SrcBlend = One;
		sRGBWriteEnable = TRUE;

 		VertexShader = compile vs_3_0 CubeProjector_VS();
		PixelShader = compile ps_3_0 CubeProjector_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Directional
//////////////////////////////////////////////////////////////////////////////

struct PSData_Directional
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float3 LightVector	: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float3 TexSpace		: TEXCOORD3;
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	GetDirectionalVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector, OUT.TexSpace);

	return OUT;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	IN.LightVector.z = abs(IN.LightVector.z);
	return GetDirectionalLitPixelColor(normalize(IN.LightVector), IN.TexSpace, IN.EyeVector, GetSurfaceNormal_Unit(IN.TexCoord),
			GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), fMaxSpecularPower);
}

//----------------------------------------------------------------------------
// Directional Technique
technique Directional
{
	pass Draw
	{
		AdaptiveTess_X = 0;		
		ZFunc = LessEqual;
		StencilEnable = False;
		SrcBlend = One;
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Directional_VS();
		PixelShader = compile ps_3_0 Directional_PS();
	}
}
