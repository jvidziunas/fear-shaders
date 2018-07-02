#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\dx9lights.fxh"
#include "..\..\sdk\depthencode.fxh"
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
DECLARE_DESCRIPTION("This is the default specular material with alphatest and bump map support.  This will fall back to specular_alphatest on DX8 hardware.");
DECLARE_DOCUMENATION("Shaders\\Docs\\specular_alphatest_bump\\main.htm");
DECLARE_PARENT_MATERIAL(0, "specular_alphatest.fx");

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

MIPARAM_FLOAT(fBumpScale, 0.1, "Size of the bumps, which are located in the alpha channel of the normal map.");

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
	return tex2D(sDiffuseMapSampler, vCoord);
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

float2 GetDepthOffset(float2 vCoord, float3 vEye)
{
	// Sample the depth map
	float fDepth = tex2D(sNormalMapSampler, vCoord).w;
	// Offset the texture coords based on the depth and the eye direction
	float2 vHalfOffset = normalize(vEye).xy * (fDepth) * fBumpScale;
	// Sample the depth map again and use the average to converge on a better solution
	fDepth = (fDepth + tex2D(sNormalMapSampler, vCoord + vHalfOffset).w) * 0.5;
	vHalfOffset = normalize(vEye).xy * (fDepth) * fBumpScale;
	// Sample the depth map again and use the average to converge on a better solution
	fDepth = (fDepth + tex2D(sNormalMapSampler, vCoord + vHalfOffset).w) * 0.5;
	vHalfOffset = normalize(vEye).xy * (fDepth) * fBumpScale;
	
	// We're done.  (More iterations than that and it doesn't fit any more.)
	return vHalfOffset;
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient 
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float3 EyeVector : TEXCOORD1;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	float3 vTemp;
	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, vTemp, OUT.EyeVector);
	return OUT;
}

float4 Ambient_PS(PSData_Ambient IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	IN.TexCoord += GetDepthOffset(IN.TexCoord, IN.EyeVector);
	float4 vDiffuseColor = GetMaterialDiffuse(IN.TexCoord);
	vResult.xyz = GetLightDiffuseColor().xyz * vDiffuseColor.xyz + GetMaterialEmissive(IN.TexCoord).xyz;
	vResult.w = vDiffuseColor.w;
	
	return vResult;
}

technique Ambient
{
	pass Draw
	{
		AlphaRef = 96;
		AlphaFunc = Greater;
		AlphaTestEnable = True;
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
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	return OUT;
}

float4 Point_PS(PSData_Point IN) : COLOR
{
	IN.TexCoord += GetDepthOffset(IN.TexCoord, IN.EyeVector);

	float3 vSurfaceNormal = GetSurfaceNormal(IN.TexCoord);
	ApplyToksvigScale(vSurfaceNormal, fMaxSpecularPower);

	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		normalize(vSurfaceNormal), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
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
	float3 EyeVector							: TEXCOORD1;
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD2;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	GetPointFillVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector);
	float4 vTemp;
	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, vTemp, vTemp.xy, vTemp.xyz, OUT.EyeVector);
	return OUT;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	IN.TexCoord += GetDepthOffset(IN.TexCoord, IN.EyeVector);
	return GetPointFillPixelColor(IN.LightVector, GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord));
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
	float2 TexCoord			: TEXCOORD0;
	float3 LightVector		: TEXCOORD1;
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
	IN.TexCoord += GetDepthOffset(IN.TexCoord, IN.EyeVector);

	float3 vSurfaceNormal = GetSurfaceNormal(IN.TexCoord);
	ApplyToksvigScale(vSurfaceNormal, fMaxSpecularPower);

	// Get the pixel
	float4 vPixelColor = GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		normalize(vSurfaceNormal), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
		DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord), DX9GetSpotProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);

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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0;
	float3 LightVector		: TEXCOORD1;
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
	IN.TexCoord += GetDepthOffset(IN.TexCoord, IN.EyeVector);

	float3 vSurfaceNormal = GetSurfaceNormal(IN.TexCoord);
	ApplyToksvigScale(vSurfaceNormal, fMaxSpecularPower);

	// Get the pixel
	return GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		normalize(vSurfaceNormal), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
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
	float3 LightVector		: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float3 TexSpace			: TEXCOORD3;
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	GetDirectionalVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector, OUT.TexSpace);

	return OUT;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	IN.TexCoord += GetDepthOffset(IN.TexCoord, IN.EyeVector);

	float3 vSurfaceNormal = GetSurfaceNormal(IN.TexCoord);
	ApplyToksvigScale(vSurfaceNormal, fMaxSpecularPower);

	return GetDirectionalLitPixelColor(normalize(IN.LightVector), IN.TexSpace, IN.EyeVector, normalize(vSurfaceNormal),
			GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), fMaxSpecularPower);
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

//////////////////////////////////////////////////////////////////////////////
// Depth encoding support
//////////////////////////////////////////////////////////////////////////////

struct PSData_Encode_Depth												
{																				
	float4 Position : POSITION;													
	float2 DepthRG : TEXCOORD0;													
	float2 DepthBA : TEXCOORD1;	
	float2 TexCoord : TEXCOORD2;												
	float3 EyeVector : TEXCOORD3;
};																				
																				
PSData_Encode_Depth Encode_Depth_VS(MaterialVertex IN)
{																				
	PSData_Encode_Depth OUT;											
	OUT.Position = TransformToClipSpace(GetPosition(IN));						
	GetDepthEncodeCoords(OUT.Position.z, OUT.DepthRG, OUT.DepthBA);				
																				
	float3 vTemp;
	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, vTemp, OUT.EyeVector);

	return OUT;																	
}																				
																				
float4 Encode_Depth_PS(PSData_Encode_Depth IN) : COLOR
{
	float4 vResult;
	vResult.xyz = EncodeDepth(IN.DepthRG, IN.DepthBA);

	IN.TexCoord += GetDepthOffset(IN.TexCoord, IN.EyeVector);
	float4 vDiffuseColor = GetMaterialDiffuse(IN.TexCoord);
	vResult.w = vDiffuseColor.w;
	
	return vResult;
}
	
technique FogVolume_Depth														
{																				
	pass Draw																	
	{									
		AlphaRef = 96;
		AlphaFunc = Greater;
		AlphaTestEnable = True;
		sRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Encode_Depth_VS();				
		PixelShader = compile ps_3_0 Encode_Depth_PS();								
	}																			
}													

