#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\dx9lights.fxh"
#include "..\..\sdk\depthencode.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\texnormalize.fxh"

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
DECLARE_DESCRIPTION("This is a cloth material. It will fall back to diffuse-only on DX8 hardware.");
DECLARE_DOCUMENATION("Shaders\\Docs\\cloth\\main.htm");
DECLARE_PARENT_MATERIAL(0, "diffuse_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// Scale for the rim lighting
MIPARAM_FLOAT(fRimScale, 2.0, "Rim lighting scale");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light reflected");
MIPARAM_TEXTURE(tEmissiveMap, 0, 1, "", false, "Emissive map of the material. This represents the color of light emitted from the surface");
MIPARAM_TEXTURE(tRimMap, 0, 2, "", false, "Rim map of the material. This represents the color of light reflected at grazing viewing angles");
MIPARAM_TEXTURE(tNormalMap, 0, 3, "", false, "Normal map of the material. This represents the normal of each point on the surface");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP_sRGB(sEmissiveMapSampler, tEmissiveMap);
SAMPLER_WRAP(sRimMapSampler, tRimMap);
// Note : Normal maps should have at least trilinear filtering
sampler sNormalMapSampler = sampler_state
{
	texture = <tNormalMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	//MipFilter = Linear;
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
	return NormalExpand(tex2D(sNormalMapSampler, vCoord).xyz);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float2 vCoord, float3 vSurfaceNormal, float3 vUnitEye, float fFnRimScale)
{
	float4 vDiffuse = tex2D(sDiffuseMapSampler, vCoord);
	float4 vRim = tex2D(sRimMapSampler, vCoord);
	
	return LinearizeAlpha( lerp(vRim, vDiffuse, saturate(dot(vSurfaceNormal, vUnitEye) * fFnRimScale)) );
}

// Fetch the material emissive color at a texture coordinate
float4 GetMaterialEmissive(float2 vCoord)
{
	return tex2D(sEmissiveMapSampler, vCoord);
}

// Standard color calculator for this shader
float4 ShadePixel(float2 vTexCoord, float3 vLightVector, float3 vEyeVector, float3 vLightDiffuseColor, float fFnRimScale)
{
	float4 vResult = float4(0,0,0,1);

	float3 vSurfaceNormal = GetSurfaceNormal(vTexCoord);
	float3 vUnitLight = TexNormalizeVector(vLightVector); 
	float3 vUnitEye = TexNormalizeVector(vEyeVector);

	float3 vDiffuse = GetMaterialDiffuse(vTexCoord, vSurfaceNormal, vUnitEye, fFnRimScale);
	
	vResult.xyz = GetDiffuseColor(vSurfaceNormal, vUnitLight, vDiffuse, vLightDiffuseColor);

	vResult.xyz *= CalcDistanceAttenuation(vLightVector);

	return vResult;
}

// Color calculator for Directional light
float4 ShadePixel_Directional(float2 vTexCoord, float3 vLightVector, float3 vEyeVector, float3 vTexSpace, float fFnRimScale)
{
	float4 vResult = float4(0,0,0,1);

	float3 vSurfaceNormal = GetSurfaceNormal(vTexCoord);

	float3 vUnitEye = TexNormalizeVector(vEyeVector);

	float3 vLightDiffuseColor = GetDirectionalLightDiffuse(GetDirectionalLightBaseColor(vTexSpace)).xyz;

	float3 vDiffuse = GetMaterialDiffuse(vTexCoord, vSurfaceNormal, vUnitEye, fFnRimScale);
	
	vResult.xyz = GetDiffuseColor(vSurfaceNormal, vLightVector, vDiffuse, vLightDiffuseColor);
	
	return vResult;
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0_centroid;
	float3 EyeVector	: TEXCOORD1_centroid;
	float RimScale		: TEXCOORD2;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	float3 vDummy;
	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, vDummy, OUT.EyeVector);
	// Pass the rim scale through to avoid the +/- 1.0 constant clamping
	OUT.RimScale = fRimScale;
	return OUT;
}

float4 Ambient_PS(PSData_Ambient IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	float4 vDiffuseColor = GetMaterialDiffuse(IN.TexCoord, GetSurfaceNormal(IN.TexCoord), TexNormalizeVector(IN.EyeVector), IN.RimScale);
	vResult.xyz = LinearizeColor( GetLightDiffuseColor().xyz ) * vDiffuseColor.xyz + GetMaterialEmissive(IN.TexCoord).xyz;
	vResult.w = vDiffuseColor.w;
	
	return vResult;
}

technique Ambient
{
	pass Draw
	{
		GAMMA_CORRECT_WRITE;

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
	float2 TexCoord		: TEXCOORD0_centroid;
	float3 LightVector	: TEXCOORD1_centroid;
	float3 EyeVector		: TEXCOORD2_centroid;
	float RimScale		: TEXCOORD3;
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	// Pass the rim scale through to avoid the +/- 1.0 constant clamping
	OUT.RimScale = fRimScale;
	
	return OUT;
}

float4 Point_PS(PSData_Point IN) : COLOR
{
	return ShadePixel(IN.TexCoord, IN.LightVector, IN.EyeVector, GetLightDiffuseColor().xyz, IN.RimScale);
}

technique Point
{
	pass Draw
	{
		GAMMA_CORRECT_WRITE;

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
	float2 TexCoord								: TEXCOORD0_centroid;
	float3 EyeVector							: TEXCOORD1_centroid;
	float RimScale								: TEXCOORD2;
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD3_centroid;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	GetPointFillVertexAttributesEye(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	// Pass the rim scale through to avoid the +/- 1.0 constant clamping
	OUT.RimScale = fRimScale;

	return OUT;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	float3 vSurfaceNormal = GetSurfaceNormal_Unit(IN.TexCoord);
	return GetPointFillPixelColor(IN.LightVector, vSurfaceNormal, GetMaterialDiffuse(IN.TexCoord, vSurfaceNormal, normalize(IN.EyeVector), IN.RimScale));
}

technique PointFill
{
	pass Draw
	{
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 PointFill_VS();
		PixelShader = compile ps_3_0 PointFill_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Spot projector
//////////////////////////////////////////////////////////////////////////////

struct PSData_SpotProjector
{
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0_centroid;
	float3 LightVector		: TEXCOORD1_centroid;
	float3 EyeVector		: TEXCOORD2_centroid;
	float4 LightMapCoord	: TEXCOORD3_centroid;
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
	float4 vPixelColor = ShadePixel(IN.TexCoord, IN.LightVector, IN.EyeVector, DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord), fRimScale);

	// Perform clipping
	return vPixelColor * DX9GetSpotProjectorClipResult(IN.ClipPlanes, IN.LightMapCoord);
}

technique SpotProjector
{
	pass Draw
	{
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 SpotProjector_VS();
		PixelShader = compile ps_3_0 SpotProjector_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Cube projector
//////////////////////////////////////////////////////////////////////////////

struct PSData_CubeProjector
{
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0_centroid;
	float3 LightVector		: TEXCOORD1_centroid;
	float3 EyeVector		: TEXCOORD2_centroid;
	float3 LightMapCoord	: TEXCOORD3_centroid;
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
	return ShadePixel(IN.TexCoord, IN.LightVector, IN.EyeVector, GetCubeProjectorDiffuseColor(IN.LightMapCoord), fRimScale);
}

technique CubeProjector
{
	pass Draw
	{
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 CubeProjector_VS();
		PixelShader = compile ps_3_0 CubeProjector_PS();
	}
}

//////////////////////////////////////////////////////////////////////////////
// Directional
//////////////////////////////////////////////////////////////////////////////

struct PSData_Directional
{
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0_centroid;
	float3 LightVector		: TEXCOORD1_centroid;
	float3 EyeVector		: TEXCOORD2_centroid;
	float3 TexSpace			: TEXCOORD3_centroid;
	float RimScale			: TEXCOORD4;
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	GetDirectionalVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector, OUT.TexSpace);

	// Pass the rim scale through to avoid the +/- 1.0 constant clamping
	OUT.RimScale = fRimScale;
	
	return OUT;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	return ShadePixel_Directional(IN.TexCoord, TexNormalizeVector(IN.LightVector), IN.EyeVector, IN.TexSpace, IN.RimScale);
}

//----------------------------------------------------------------------------
// Directional Technique
technique Directional
{
	pass Draw
	{
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Directional_VS();
		PixelShader = compile ps_3_0 Directional_PS();
	}
}

// Depth encoding support
ENCODE_DEPTH_DEFAULT(MaterialVertex)
