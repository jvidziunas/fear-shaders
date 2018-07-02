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
    float3	Normal		: NORMAL; 
    float2	TexCoord	: TEXCOORD0;
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a specular material with an environment map. This behaves exactly like the standard specular material except for an additional environment map, which is masked out by an environment map mask.");
DECLARE_DOCUMENATION("Shaders\\Docs\\specular_env\\main.htm");
DECLARE_PARENT_MATERIAL(0, "specular_mirror_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fMaxSpecularPower, 64, "Maximum specular power. This scales the gloss map so that bright white is the specified power");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light reflected");
MIPARAM_TEXTURE(tEmissiveMap, 0, 1, "", false, "Emissive map of the material. This represents the color of light emitted from the surface");
MIPARAM_TEXTURE(tSpecularMap, 0, 2, "", false, "Specular map of the material. This represents the color of light bounced off the surface");
MIPARAM_TEXTURE(tNormalMap, 0, 3, "", false, "Normal map of the material. This represents the normal of each point on the surface");
MIPARAM_TEXTURE(tReflectionMap, 0, 5, "", false, "Reflection map parameter. Set the material parameter for the render target to this parameter.");
MIPARAM_TEXTURE(tReflectionMapMask, 0, 4, "", false, "Masking map for the reflection map.  The blending value is in the alpha channel.  A discoloration value is in the color channel.");
MIPARAM_FLOAT(fReflectionBumpScale, 0.1, "The amount the reflection map will be distorted by the bump map.");

//the samplers for those textures
SAMPLER_WRAP(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP(sEmissiveMapSampler, tEmissiveMap);
SAMPLER_WRAP(sSpecularMapSampler, tSpecularMap);
// Note : Normal maps should have at least trilinear filtering
sampler sNormalMapSampler = sampler_state
{
	texture = <tNormalMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	MipFilter = Linear;
};
SAMPLER_CLAMP(sReflectionMapSampler, tReflectionMap);
SAMPLER_WRAP_LINEAR(sReflectionMapMaskSampler, tReflectionMapMask);

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
	return normalize(GetSurfaceNormal(vCoord));
}

// Fetch the material specular color at a texture coordinate
float4 GetMaterialSpecular(float2 vCoord)
{
	return tex2D(sSpecularMapSampler, vCoord);
}

// Fetch the material emissive color at a texture coordinate
float4 GetMaterialEmissive(float2 vCoord)
{
	return tex2D(sEmissiveMapSampler, vCoord);
}

// Fetch the material emissive color at a texture coordinate
float4 GetMaterialMirrorMask(float2 vCoord)
{
	return tex2D(sReflectionMapMaskSampler, vCoord);
}

float4 GetMaterialDiffuse(float2 vCoord)
{
	return tex2D(sDiffuseMapSampler, vCoord);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMirroredDiffuse(float2 vCoord, float3 vEyeVector, float3 vSurfaceNormal, float3 vTangent0, float3 vTangent1, float2 vScreenPos)
{
	float4 vDiffuse = GetLightDiffuseColor() * GetMaterialDiffuse(vCoord);

	float2x3 mTanSpace;
	mTanSpace[0] = vTangent0;//normalize(vTangent0);
	mTanSpace[1] = vTangent1;//normalize(vTangent1);
	float3 vUnitEye = normalize(vEyeVector);
	/* Math of this reflection code : 
		Reflection = V + 2N*N.V.  
		P = (0,0,1)
		Offset = V + 2N*N.V - (V + 2P*P.V) =
				 2N*N.V - 2P*P.V =
				 2(N*N.V - (0,0,V.z))
				 ^--- Removed, as this can be folded into the fReflectionBumpScale parameter
	*/
	float3 vReflectionVector = vSurfaceNormal * dot(vUnitEye, vSurfaceNormal) - float3(0.0, 0.0, vUnitEye.z);
	float2 vOffset = mul(mTanSpace, vReflectionVector);
	float4 vReflection = tex2D(sReflectionMapSampler, vScreenPos + vOffset.xy * fReflectionBumpScale);
	float4 vMask = GetMaterialMirrorMask(vCoord);

	return lerp(vDiffuse, vReflection * vMask, vMask.w);
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float4 ScreenCoord	: TEXCOORD1;
	float3 TanSpace0	: TEXCOORD2;
	float3 TanSpace1	: TEXCOORD3;
	float3 ObjEyeVector	: TEXCOORD4;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;

	float3x3 mTangentSpace = GetInverseTangentSpace(IN);
	OUT.TanSpace0 = mul(mTangentSpace, mObjectToClip[0].xyz);
	OUT.TanSpace1 = mul(mTangentSpace, mObjectToClip[1].xyz);
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.x = OUT.ScreenCoord.w - OUT.ScreenCoord.x;
	OUT.ObjEyeVector = mul(mTangentSpace, GetPosition(IN) - vObjectSpaceEyePos);

	return OUT;
}

float4 Ambient_PS(PSData_Ambient IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	float4 vDiffuseColor = GetMirroredDiffuse(IN.TexCoord, IN.ObjEyeVector, GetSurfaceNormal_Unit(IN.TexCoord), IN.TanSpace0, IN.TanSpace1, IN.ScreenCoord.xy / IN.ScreenCoord.w);
	vResult.xyz = vDiffuseColor.xyz + GetLightDiffuseColor().xyz * GetMaterialEmissive(IN.TexCoord).xyz;
	vResult.w = 1.0;
	
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0;
	float3 LightVector		: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float4 ScreenCoord		: TEXCOORD3;
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	float3x3 mTangentSpace = GetInverseTangentSpace(IN);
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.x = OUT.ScreenCoord.w - OUT.ScreenCoord.x;

	return OUT;
}

float4 Point_PS(PSData_Point IN) : COLOR
{
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), 
		GetMaterialDiffuse(IN.TexCoord), 
		GetMaterialSpecular(IN.TexCoord), 
		GetLightDiffuseColor().xyz, GetLightSpecularColor(), fMaxSpecularPower);
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
	float4 ScreenCoord							: TEXCOORD1;
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD2;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	GetPointFillVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector);

	float3x3 mTangentSpace = GetInverseTangentSpace(IN);
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.x = OUT.ScreenCoord.w - OUT.ScreenCoord.x;

	return OUT;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	return GetPointFillPixelColor(IN.LightVector, GetSurfaceNormal_Unit(IN.TexCoord), 
		GetMaterialDiffuse(IN.TexCoord));
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
	float4 Position			: POSITION;
	float4 TexCoordClip		: TEXCOORD0;
	float4 ScreenCoord		: TEXCOORD1;
	float3 LightVector		: TEXCOORD2;
	float3 EyeVector		: TEXCOORD3;
	float4 LightMapCoord	: TEXCOORD4;
};	

PSData_SpotProjector SpotProjector_VS(MaterialVertex IN) 
{
	PSData_SpotProjector OUT;

	float3 vPosition = GetPosition(IN);
	GetVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoordClip.xy, OUT.LightVector, OUT.EyeVector);

	float3x3 mTangentSpace = GetInverseTangentSpace(IN);
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.x = OUT.ScreenCoord.w - OUT.ScreenCoord.x;

	// Lightmap coord sampling position
	OUT.LightMapCoord = GetSpotProjectorTexCoord(vPosition);
	 
	// Near/far plane clipping
	OUT.TexCoordClip.zw = GetSpotProjectorClipInterpolants(vPosition);

	return OUT;
}

float4 SpotProjector_PS(PSData_SpotProjector IN) : COLOR
{
	// Get the pixel
	float4 vPixelColor = GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoordClip.xy), 
		GetMaterialDiffuse(IN.TexCoordClip.xy), 
		GetMaterialSpecular(IN.TexCoordClip.xy), 
		DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord), DX9GetSpotProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);

	// Perform clipping
	return vPixelColor * DX9GetSpotProjectorClipResult(IN.TexCoordClip.zw, IN.LightMapCoord);
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0;
	float4 ScreenCoord		: TEXCOORD1;
	float3 LightVector		: TEXCOORD2;
	float3 EyeVector		: TEXCOORD3;
	float3 LightMapCoord	: TEXCOORD4;
};	

PSData_CubeProjector CubeProjector_VS(MaterialVertex IN) 
{
	PSData_CubeProjector OUT;

	float3 vPosition = GetPosition(IN);
	GetVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	float3x3 mTangentSpace = GetInverseTangentSpace(IN);
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.x = OUT.ScreenCoord.w - OUT.ScreenCoord.x;

	// Lightmap coord sampling position
	OUT.LightMapCoord = GetCubeProjectorTexCoord(vPosition);
	 
	return OUT;
}

float4 CubeProjector_PS(PSData_CubeProjector IN) : COLOR
{
	// Get the pixel
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), 
		GetMaterialDiffuse(IN.TexCoord), 
		GetMaterialSpecular(IN.TexCoord), 
		GetCubeProjectorDiffuseColor(IN.LightMapCoord), GetCubeProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0;
	float4 ScreenCoord		: TEXCOORD1;
	float3 LightVector		: TEXCOORD2;
	float3 EyeVector		: TEXCOORD3;
	float3 TexSpace			: TEXCOORD4;
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	float3 vPosition = GetPosition(IN);
	GetDirectionalVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector, OUT.TexSpace);

	float3x3 mTangentSpace = GetInverseTangentSpace(IN);
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.x = OUT.ScreenCoord.w - OUT.ScreenCoord.x;

	return OUT;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	return GetDirectionalLitPixelColor(normalize(IN.LightVector), IN.TexSpace, IN.EyeVector, GetSurfaceNormal_Unit(IN.TexCoord),
			GetMaterialDiffuse(IN.TexCoord), 
			GetMaterialSpecular(IN.TexCoord), fMaxSpecularPower);
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
