#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\dx9lights.fxh"
#include "..\..\sdk\transforms.fxh"

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
DECLARE_DESCRIPTION("This is a glass material with an environment map. This behaves exactly like the standard glass material except for an additional environment map, which is masked out by an environment map mask.  It will fall back to the glass shader on DX8 hardware.");
DECLARE_DOCUMENATION("Shaders\\Docs\\glass_env\\main.htm");
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
MIPARAM_TEXTURE(tEnvironmentMap, 0, 3, "", false, "Cubic environment map for the material. This represents a reflection of the environment");
MIPARAM_TEXTURE(tEnvironmentMapMask, 0, 4, "", false, "Masking map for the environment map.  The blending value is in the alpha channel.  A discoloration value is in the color channel.");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP(sSpecularMapSampler, tSpecularMap);
// Note : Normal maps should have at least trilinear filtering
sampler sNormalMapSampler = sampler_state
{
	texture = <tNormalMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	MipFilter = Linear;
};
SAMPLER_CLAMP_sRGB(sEnvironmentMapSampler, tEnvironmentMap);
SAMPLER_WRAP_sRGB(sEnvironmentMapMaskSampler, tEnvironmentMapMask);

//--------------------------------------------------------------------
// Utility functions

float3x3 GetInverseTangentSpace(MaterialVertex Vert)
{
	return GetInverseTangentSpace(	SKIN_VECTOR(Vert.Tangent, Vert), 
									SKIN_VECTOR(Vert.Binormal, Vert), 
									SKIN_VECTOR(Vert.Normal, Vert));
}

float3x3 GetTangentSpace(MaterialVertex Vert)
{
	return transpose(GetInverseTangentSpace(Vert));
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

// Fetch the material environment map for the given viewing angle and surface normal
float4 GetMaterialEnvMap(float3 vEyeVector, float3 vSurfaceNormal)
{
	float3 vCoord = reflect(vEyeVector, vSurfaceNormal);
	return texCUBE(sEnvironmentMapSampler, vCoord);
}

// Fetch the material emissive color at a texture coordinate
float4 GetMaterialEnvMapMask(float2 vCoord)
{
	return LinearizeAlpha( tex2D(sEnvironmentMapMaskSampler, vCoord) );
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float2 vCoord)
{
	return LinearizeAlpha( tex2D(sDiffuseMapSampler, vCoord) );
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float2 vCoord, float3 vEyeVector, float3 vSurfaceNormal, float3 vTangent0, float3 vTangent1, float3 vTangent2)
{
	float4 vDiffuse = GetMaterialDiffuse(vCoord);

	float3x3 mEnvSpace;
	mEnvSpace[0] = normalize(vTangent0);
	mEnvSpace[1] = normalize(vTangent1);
	mEnvSpace[2] = normalize(vTangent2);
	float3 vEnvMap = GetMaterialEnvMap(vEyeVector, mul(mEnvSpace, vSurfaceNormal));
	float4 vMask = GetMaterialEnvMapMask(vCoord);

	return float4(lerp(vDiffuse, vEnvMap * vMask.xyz, vMask.w), 1.0);
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0_centroid;
	float3 LightVector		: TEXCOORD1_centroid;
	float3 EyeVector		: TEXCOORD2_centroid;
	float3 TanSpace0		: TEXCOORD3_centroid;
	float3 TanSpace1		: TEXCOORD4_centroid;
	float3 TanSpace2		: TEXCOORD5_centroid;
	float3 ObjEyeVector		: TEXCOORD6_centroid;
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	OUT.ObjEyeVector = mul((float3x3)mObjectToWorld, GetPosition(IN) - vObjectSpaceEyePos);

	float3x3 mTangentSpace = mul((float3x3)mObjectToWorld, GetTangentSpace(IN));
	OUT.TanSpace0 = mTangentSpace[0];
	OUT.TanSpace1 = mTangentSpace[1];
	OUT.TanSpace2 = mTangentSpace[2];

	return OUT;
}

float4 Point_PS(PSData_Point IN) : COLOR
{
	IN.LightVector.z = abs(IN.LightVector.z);
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord, IN.ObjEyeVector, GetSurfaceNormal_Unit(IN.TexCoord), IN.TanSpace0, IN.TanSpace1, IN.TanSpace2), GetMaterialSpecular(IN.TexCoord), 
		GetLightDiffuseColor().xyz, GetLightSpecularColor(), fMaxSpecularPower);
}

technique Point
{
	pass Draw
	{	
		AdaptiveTess_X = 0;	
		ZFunc = LessEqual;
		StencilEnable = False;
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0_centroid;
	float3 TanSpace0		: TEXCOORD1_centroid;
	float3 TanSpace1		: TEXCOORD2_centroid;
	float3 TanSpace2		: TEXCOORD3_centroid;
	float3 ObjEyeVector		: TEXCOORD4_centroid;
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD5_centroid;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	GetPointFillVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector);
	
	OUT.ObjEyeVector = mul((float3x3)mObjectToWorld, GetPosition(IN) - vObjectSpaceEyePos);

	float3x3 mTangentSpace = mul((float3x3)mObjectToWorld, GetTangentSpace(IN));
	OUT.TanSpace0 = mTangentSpace[0];
	OUT.TanSpace1 = mTangentSpace[1];
	OUT.TanSpace2 = mTangentSpace[2];

	return OUT;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	for (int loop = 0; loop < NUM_POINT_FILL_LIGHTS; ++loop)
		IN.LightVector[loop].z = abs(IN.LightVector[loop].z);
	return GetPointFillPixelColor(IN.LightVector, GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord, IN.ObjEyeVector, GetSurfaceNormal_Unit(IN.TexCoord), IN.TanSpace0, IN.TanSpace1, IN.TanSpace2));
}

technique PointFill
{
	pass Draw
	{
		AdaptiveTess_X = 0;
		ZFunc = LessEqual;
		StencilEnable = False;
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
	// GJ to 'Lith for not thinking to pack vertex attributes-- now we don't need to use a
	// color interpolator for the third tangent-space transform basis vector
	float4 Position					: POSITION;
	float4 TexCoordAndClipPlanes	: TEXCOORD0_centroid;
	float3 LightVector				: TEXCOORD1_centroid;
	float3 EyeVector				: TEXCOORD2_centroid;
	float4 LightMapCoord			: TEXCOORD3_centroid;
	float3 TanSpace0				: TEXCOORD4_centroid;
	float3 TanSpace1				: TEXCOORD5_centroid;
	float3 TanSpace2				: TEXCOORD6_centroid;
	float3 ObjEyeVector				: TEXCOORD7_centroid;
};	

PSData_SpotProjector SpotProjector_VS(MaterialVertex IN) 
{
	PSData_SpotProjector OUT;

	float3 vPosition = GetPosition(IN);
	GetVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoordAndClipPlanes.xy, OUT.LightVector, OUT.EyeVector);

	OUT.ObjEyeVector = mul((float3x3)mObjectToWorld, GetPosition(IN) - vObjectSpaceEyePos);

	float3x3 mTangentSpace = mul((float3x3)mObjectToWorld, GetTangentSpace(IN));
	OUT.TanSpace0 = mTangentSpace[0];
	OUT.TanSpace1 = mTangentSpace[1];
	OUT.TanSpace2 = mTangentSpace[2];

	// Lightmap coord sampling position
	OUT.LightMapCoord = GetSpotProjectorTexCoord(vPosition);
	 
	// Near/far plane clipping
	OUT.TexCoordAndClipPlanes.zw = GetSpotProjectorClipInterpolants(vPosition);

	return OUT;
}

float4 SpotProjector_PS(PSData_SpotProjector IN) : COLOR
{
	IN.LightVector.z = abs(IN.LightVector.z);
	float3 vUnitSurfaceNormal = GetSurfaceNormal_Unit(IN.TexCoordAndClipPlanes.xy);
	// Get the pixel
	float4 vPixelColor = GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		vUnitSurfaceNormal, GetMaterialDiffuse(IN.TexCoordAndClipPlanes.xy, IN.ObjEyeVector, vUnitSurfaceNormal, IN.TanSpace0, IN.TanSpace1, IN.TanSpace2), GetMaterialSpecular(IN.TexCoordAndClipPlanes.xy), 
		DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord), DX9GetSpotProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);

	// Perform clipping
	return vPixelColor * DX9GetSpotProjectorClipResult(IN.TexCoordAndClipPlanes.zw, IN.LightMapCoord);
}

technique SpotProjector
{
	pass Draw
	{
		AdaptiveTess_X = 0;
		ZFunc = LessEqual;
		StencilEnable = False;
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
	float3 TanSpace0		: TEXCOORD4_centroid;
	float3 TanSpace1		: TEXCOORD5_centroid;
	float3 TanSpace2		: TEXCOORD6_centroid;
	float3 ObjEyeVector		: TEXCOORD7_centroid;
};	

PSData_CubeProjector CubeProjector_VS(MaterialVertex IN) 
{
	PSData_CubeProjector OUT;

	float3 vPosition = GetPosition(IN);
	GetVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	OUT.ObjEyeVector = mul((float3x3)mObjectToWorld, GetPosition(IN) - vObjectSpaceEyePos);

	float3x3 mTangentSpace = mul((float3x3)mObjectToWorld, GetTangentSpace(IN));
	OUT.TanSpace0 = mTangentSpace[0];
	OUT.TanSpace1 = mTangentSpace[1];
	OUT.TanSpace2 = mTangentSpace[2];

	// Lightmap coord sampling position
	OUT.LightMapCoord = GetCubeProjectorTexCoord(vPosition);
	 
	return OUT;
}

float4 CubeProjector_PS(PSData_CubeProjector IN) : COLOR
{
	IN.LightVector.z = abs(IN.LightVector.z);
	// Get the pixel
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord, IN.ObjEyeVector, GetSurfaceNormal_Unit(IN.TexCoord), IN.TanSpace0, IN.TanSpace1, IN.TanSpace2), GetMaterialSpecular(IN.TexCoord), 
		GetCubeProjectorDiffuseColor(IN.LightMapCoord), GetCubeProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);
}

technique CubeProjector
{
	pass Draw
	{		
		AdaptiveTess_X = 0;
		ZFunc = LessEqual;
		StencilEnable = False;
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
	float3 TanSpace0		: TEXCOORD4_centroid;
	float3 TanSpace1		: TEXCOORD5_centroid;
	float3 TanSpace2		: TEXCOORD6_centroid;
	float3 ObjEyeVector		: TEXCOORD7_centroid;
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	float3 vPosition = GetPosition(IN);
	GetDirectionalVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector, OUT.TexSpace);

	OUT.ObjEyeVector = mul((float3x3)mObjectToWorld, GetPosition(IN) - vObjectSpaceEyePos);

	float3x3 mTangentSpace = mul((float3x3)mObjectToWorld, GetTangentSpace(IN));
	OUT.TanSpace0 = mTangentSpace[0];
	OUT.TanSpace1 = mTangentSpace[1];
	OUT.TanSpace2 = mTangentSpace[2];

	return OUT;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	IN.LightVector.z = abs(IN.LightVector.z);
	return GetDirectionalLitPixelColor(normalize(IN.LightVector), IN.TexSpace, IN.EyeVector, GetSurfaceNormal_Unit(IN.TexCoord),
			GetMaterialDiffuse(IN.TexCoord, IN.ObjEyeVector, GetSurfaceNormal_Unit(IN.TexCoord), IN.TanSpace0, IN.TanSpace1, IN.TanSpace2), GetMaterialSpecular(IN.TexCoord), fMaxSpecularPower);
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
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Directional_VS();
		PixelShader = compile ps_3_0 Directional_PS();
	}
}
