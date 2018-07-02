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
DECLARE_DESCRIPTION("This shader is intended for two tone metallic looking paint such as that seen on certain types of cars.");
DECLARE_DOCUMENATION("Shaders\\Docs\\twotonepaint\\main.htm");
DECLARE_PARENT_MATERIAL(0, "specular_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fMaxSpecularPower, 64, "Maximum specular power. This scales the gloss map so that bright white is the specified power");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light reflected. The alpha channel controls where the paint will be used (white) and where normal shading should be used (black)");
MIPARAM_TEXTURE(tEmissiveMap, 0, 1, "", false, "Emissive map of the material. This represents the color of light emitted from the surface");
MIPARAM_TEXTURE(tSpecularMap, 0, 2, "", false, "Specular map of the material. This represents the color of light bounced off the surface");
MIPARAM_TEXTURE(tNormalMap, 0, 3, "", false, "Normal map of the material. This represents the normal of each point on the surface");

//the different paint colors for the car
MIPARAM_VECTOR(vBaseColor, 0.0, 0.0, 0.1, "The base color that is applied to the paint regardless of the view angle.");
MIPARAM_VECTOR(vPaintColor0, 0.0, 0.0, 0.1, "This is the top layer paint color. This color is the most visible color and is largely visible from almost any viewing angle.");
MIPARAM_VECTOR(vPaintColor1, 0.0, 0.0, 0.15, "This is the middle layer of paint color, this can be viewed from a range of angles that doesn't need to be straight on, but moreso than the top layer color");
MIPARAM_VECTOR(vPaintColor2, 0.0, 0.3, 0.1, "This is the bottom most layer of paint color, typically only visible when viewing the surface straight on");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP_sRGB(sEmissiveMapSampler, tEmissiveMap);
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

float3x3 GetInverseTangentSpace(in MaterialVertex Vert)
{
	return GetInverseTangentSpace(	SKIN_VECTOR(Vert.Tangent, Vert), 
									SKIN_VECTOR(Vert.Binormal, Vert), 
									SKIN_VECTOR(Vert.Normal, Vert));
}

float3 GetPosition(in MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

// Fetch the surface normal at a texture coordinate
float3 GetSurfaceNormal_Unit(in float2 vCoord)
{
	return normalize(tex2D(sNormalMapSampler, vCoord).xyz - 0.5);
}

// Fetch the surface normal at a texture coordinate
float3 GetSurfaceNormal(in float2 vCoord)
{
	return ColorToUnitVector(tex2D(sNormalMapSampler, vCoord).xyz);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(in float2 vCoord)
{
	return LinearizeAlpha( tex2D(sDiffuseMapSampler, vCoord) );
}

// Fetch the material specular color at a texture coordinate
float4 GetMaterialSpecular(in float2 vCoord)
{
	return tex2D(sSpecularMapSampler, vCoord);
}

// Fetch the material emissive color at a texture coordinate
float4 GetMaterialEmissive(in float2 vCoord)
{
	return tex2D(sEmissiveMapSampler, vCoord);
}

//Given texture coordinates and unit vectors for the surface normal and eye vectors, this will
//determine the appropriate paint color
float3 GetPaintColor(in float2 vCoord, in float3 vUnitEye, in float3 vUnitSurface)
{
	//determine the normal after the microflake has influenced it
	float3 vSurfaceNormal		= vUnitSurface;

	//we now need to determine our diffuse color
	float fSurfDotView		= dot(vSurfaceNormal, vUnitEye);
	float fSurfDotView2nd	= fSurfDotView * fSurfDotView;
	float fSurfDotView4th	= fSurfDotView2nd * fSurfDotView2nd;
	
	//determine the color of paint given the viewing angle
	float3 vPaint	=	vBaseColor +
						vPaintColor0 * fSurfDotView + 
						vPaintColor1 * fSurfDotView2nd + 
						vPaintColor2 * fSurfDotView4th;
	
	//and now contribute that to the diffuse
	float4 vDiffuse = GetMaterialDiffuse(vCoord);
	
	//and interpolate between the paint and diffuse based upon the alpha channel
	return lerp(vDiffuse.xyz, vDiffuse.xyz * vPaint, vDiffuse.w); 
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0_centroid;
	float3 EyeVector	: TEXCOORD1_centroid;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	
	float3 vObjPosition = GetPosition(IN);
	OUT.Position = TransformToClipSpace(vObjPosition);
	OUT.TexCoord = IN.TexCoord;
	
	// Calculate the eye vector
	float3 vEyeOffset = (vObjectSpaceEyePos - vObjPosition);
	OUT.EyeVector = mul(GetInverseTangentSpace(IN), vEyeOffset);

	return OUT;
}

float4 Ambient_PS(PSData_Ambient IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);
	float3 vUnitEyeVector	= TexNormalizeVector(IN.EyeVector);
	float3 vUnitNormal		= GetSurfaceNormal(IN.TexCoord);

	vResult.xyz = GetLightDiffuseColor().xyz * GetPaintColor(IN.TexCoord, vUnitEyeVector, vUnitNormal) + GetMaterialEmissive(IN.TexCoord).xyz;
	vResult.w = 0.0;
	
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0_centroid;
	float3 LightVector		: TEXCOORD1_centroid;
	float3 EyeVector		: TEXCOORD2_centroid;
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	return OUT;
}

float4 Point_PS(PSData_Point IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	//Extract out the relevant vectors from the data provided
	float3 vUnitLightVector = normalize(IN.LightVector);
	float3 vUnitEyeVector	= normalize(IN.EyeVector);
	float3 vUnitNormal		= GetSurfaceNormal_Unit(IN.TexCoord);
	
	// *** Diffuse ***
	vResult.xyz = GetDiffuseColor(vUnitNormal, vUnitLightVector, GetPaintColor(IN.TexCoord, vUnitEyeVector, vUnitNormal), GetLightDiffuseColor().xyz);

	// *** Specular ***
	float4 vMaterialSpecularColor = GetMaterialSpecular(IN.TexCoord);
	vResult.xyz += GetBlinnSpecularColor(
		vUnitNormal, 
		vUnitLightVector,
		vUnitEyeVector,
		vMaterialSpecularColor.xyz,
		vMaterialSpecularColor.w,
		fMaxSpecularPower,
		GetLightSpecularColor());

	// *** Distance attenuation ***
	vResult.xyz *= CalcDistanceAttenuation(IN.LightVector);

	return vResult;
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
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD2_centroid;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	GetPointFillVertexAttributesEye(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);
	return OUT;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	//Extract out the relevant vectors from the data provided
	float3 vUnitEyeVector	= normalize(IN.EyeVector);
	float3 vUnitNormal		= GetSurfaceNormal(IN.TexCoord);
	
	float3 vDiffuse = GetPaintColor(IN.TexCoord, vUnitEyeVector, vUnitNormal);

	return GetPointFillPixelColor(IN.LightVector, vUnitNormal, float4(vDiffuse, 1.0));
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
	float4 vResult = float4(0,0,0,1);

	//Extract out the relevant vectors from the data provided
	float3 vUnitLightVector = normalize(IN.LightVector);
	float3 vUnitEyeVector	= normalize(IN.EyeVector);
	float3 vUnitNormal		= GetSurfaceNormal_Unit(IN.TexCoord);
	
	// *** Diffuse ***
	vResult.xyz = GetDiffuseColor(	vUnitNormal, 
									vUnitLightVector, 
									GetPaintColor(IN.TexCoord, vUnitEyeVector, vUnitNormal), 
									DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord).xyz);

	// *** Specular ***
	float4 vMaterialSpecularColor = GetMaterialSpecular(IN.TexCoord);
	vResult.xyz += GetBlinnSpecularColor(
		vUnitNormal, 
		vUnitLightVector,
		vUnitEyeVector,
		vMaterialSpecularColor.xyz,
		vMaterialSpecularColor.w,
		fMaxSpecularPower,
		DX9GetSpotProjectorSpecularColor(IN.LightMapCoord));

	// *** Distance attenuation ***
	vResult.xyz *= CalcDistanceAttenuation(IN.LightVector);

	return vResult * DX9GetSpotProjectorClipResult(IN.ClipPlanes, IN.LightMapCoord);
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
	float4 vResult = float4(0,0,0,1);

	//Extract out the relevant vectors from the data provided
	float3 vUnitLightVector = normalize(IN.LightVector);
	float3 vUnitEyeVector	= normalize(IN.EyeVector);
	float3 vUnitNormal		= GetSurfaceNormal_Unit(IN.TexCoord);
	
	// *** Diffuse ***
	vResult.xyz = GetDiffuseColor(	vUnitNormal, 
									vUnitLightVector, 
									GetPaintColor(IN.TexCoord, vUnitEyeVector, vUnitNormal), 
									GetCubeProjectorDiffuseColor(IN.LightMapCoord).xyz);

	// *** Specular ***
	float4 vMaterialSpecularColor = GetMaterialSpecular(IN.TexCoord);
	vResult.xyz += GetBlinnSpecularColor(
		vUnitNormal, 
		vUnitLightVector,
		vUnitEyeVector,
		vMaterialSpecularColor.xyz,
		vMaterialSpecularColor.w,
		fMaxSpecularPower,
		GetCubeProjectorSpecularColor(IN.LightMapCoord));

	// *** Distance attenuation ***
	vResult.xyz *= CalcDistanceAttenuation(IN.LightVector);

	return vResult;
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
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	GetDirectionalVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector, OUT.TexSpace);

	return OUT;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);
	
	//Extract out the relevant vectors from the data provided
	float3 vUnitLightVector = normalize(IN.LightVector);
	float3 vUnitEyeVector	= normalize(IN.EyeVector);
	float3 vUnitNormal		= GetSurfaceNormal_Unit(IN.TexCoord);

	//get the color to use for the lighting
	float4 vBaseColor =	GetDirectionalLightBaseColor(IN.TexSpace);

	// *** Diffuse ***
	vResult.xyz += GetDiffuseColor(	vUnitNormal, 
									vUnitLightVector, 
									GetPaintColor(IN.TexCoord, vUnitEyeVector, vUnitNormal), 
									GetDirectionalLightDiffuse(vBaseColor));

	// *** Specular ***
	float4 vMaterialSpecularColor = GetMaterialSpecular(IN.TexCoord);
	vResult.xyz += GetBlinnSpecularColor(
		vUnitNormal, 
		vUnitLightVector,
		vUnitEyeVector,
		vMaterialSpecularColor.xyz,
		vMaterialSpecularColor.w,
		fMaxSpecularPower,
		GetDirectionalLightSpecular(vBaseColor));

	return vResult;
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
