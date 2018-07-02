#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\dx9lights.fxh"
#include "..\..\sdk\screencoords.fxh"
#include "..\..\sdk\depthencode.fxh"

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
DECLARE_DESCRIPTION("This is a diffuse material. It is intended for DX9 class hardware.");
DECLARE_PARENT_MATERIAL(0, "..\\solid\\diffuse_dx8.fx");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light reflected");
MIPARAM_TEXTURE(tEmissiveMap, 0, 1, "", false, "Emissive map of the material. This represents the color of light emitted from the surface");
MIPARAM_TEXTURE(tNormalMap, 0, 2, "", false, "Normal map of the material. This represents the normal of each point on the surface");
MIPARAM_TEXTURE(tDetailNormalMap, 0, 3, "", false, "Detail normal map of the material. This represents a detail texture for the normal map");
MIPARAM_FLOAT(fDetailScale, 32.0, "Detail normal map scale");
MIPARAM_FLOAT(fDetailDepth, 0.5, "Detail depth scale");

//the samplers for those textures
SAMPLER_WRAP(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP(sEmissiveMapSampler, tEmissiveMap);
// Note : Normal maps should have at least trilinear filtering
sampler sNormalMapSampler = sampler_state
{
	texture = <tNormalMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	MipFilter = Linear;
};
sampler sDetailNormalMapSampler = sampler_state
{
	texture = <tDetailNormalMap>;
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
	float3 vNormalMap = ColorToUnitVector(tex2D(sNormalMapSampler, vCoord).xyz);
	float2 vDetailCoord = frac(vCoord * fDetailScale);
	float3 vDetail = ColorToUnitVector(tex2D(sDetailNormalMapSampler, vDetailCoord).xyz) * fDetailDepth;
	vDetail.z = 0;
	return normalize(vNormalMap + vDetail);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float2 vCoord)
{
	return tex2D(sDiffuseMapSampler, vCoord);
}

// Fetch the material emissive color at a texture coordinate
float4 GetMaterialEmissive(float2 vCoord)
{
	return tex2D(sEmissiveMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient 
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	return OUT;
}

float4 Ambient_PS(PSData_Ambient IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	float4 vDiffuseColor = GetMaterialDiffuse(IN.TexCoord);
	vResult.xyz = GetLightDiffuseColor().xyz * vDiffuseColor.xyz + GetMaterialEmissive(IN.TexCoord).xyz;
	vResult.w = vDiffuseColor.w;
	
	return vResult;
}

technique Ambient
{
	pass Draw
	{
		sRGBWriteEnable = TRUE;

		VertexShader = compile vs_3_0 Ambient_VS();
		PixelShader = compile ps_3_0 Ambient_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Point light
//////////////////////////////////////////////////////////////////////////////

struct PSData_Point 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float3 LightVector	: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	return OUT;
}

float4 Point_PS(PSData_Point IN) : COLOR
{
	// Note : Specular gets optimized out by the compiler...
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), float4(0,0,0,0), 
		GetLightDiffuseColor().xyz, float3(0,0,0), 0.0);
}

technique Point
{
	pass Draw
	{
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
	float4 Position								: POSITION;
	float2 TexCoord								: TEXCOORD0;
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD2;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	GetPointFillVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector);
	return OUT;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	return GetPointFillPixelColor(IN.LightVector, GetSurfaceNormal(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord));
}

technique PointFill
{
	pass Draw
	{
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
	// Get the pixel
	// Note : Specular gets optimized out by the compiler...
	float4 vPixelColor = GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), float4(0,0,0,0), 
		DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord), float3(0,0,0), 0);

	// Perform clipping
	return vPixelColor * DX9GetSpotProjectorClipResult(IN.ClipPlanes, IN.LightMapCoord);
}

technique SpotProjector
{
	pass Draw
	{
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
	// Get the pixel
	// Note : Specular gets optimized out by the compiler...
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), float4(0,0,0,0), 
		GetCubeProjectorDiffuseColor(IN.LightMapCoord), float3(0,0,0), 0);
}

technique CubeProjector
{
	pass Draw
	{
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
	float3 TexSpace		: TEXCOORD3;
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	float3 vDummyEye;
	GetDirectionalVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, vDummyEye, OUT.TexSpace);

	return OUT;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	return GetDirectionalLitPixelColor(normalize(IN.LightVector), IN.TexSpace, 1.0.xxx, GetSurfaceNormal(IN.TexCoord),
			GetMaterialDiffuse(IN.TexCoord), 0.0.xxxx, 1.0);
}

//----------------------------------------------------------------------------
// Directional Technique
technique Directional
{
	pass Draw
	{
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Directional_VS();
		PixelShader = compile ps_3_0 Directional_PS();
	}
}

// Depth encoding support
ENCODE_DEPTH_DEFAULT(MaterialVertex)
