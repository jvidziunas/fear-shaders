#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\dx9lights.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\time.fxh"
#include "..\..\sdk\object.fxh"
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
DECLARE_DESCRIPTION("This is a glass material based on the default specular material. This allows specification of a diffuse, specular, and normal map. In addition, for DX9 level cards and higher it allows for specifying a maximum specular power.  The alpha channel of the specular map will then represent how glossy the surface is, ranging from black which is zero, to white which is the specified number. The higher the number, the shinier the surface.");
DECLARE_DOCUMENATION("Shaders\\Docs\\glass\\main.htm");
DECLARE_PARENT_MATERIAL(0, "dissolve_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fMaxSpecularPower, 64, "Maximum specular power. This scales the gloss map so that bright white is the specified power");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light reflected");
MIPARAM_TEXTURE(tSpecularMap, 0, 1, "", false, "Specular map of the material. This represents the color of light bounced off the surface");
MIPARAM_TEXTURE(tNormalMap, 0, 2, "", false, "Normal map of the material. This represents the normal of each point on the surface");
MIPARAM_TEXTURE(tDissolveMap, 0, 3, "", false, "Cubic dissolve map.  Only the red channel is used.");
MIPARAM_FLOAT(fGhostBias, 0.2, "Bias toward either ghost (positive) or ambient (negative).");

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
SAMPLER_WRAP_LINEAR(sDissolveMapSampler, tDissolveMap);

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

float GetAlpha(float3 vCoord)
{
	float fScale = 3.0 * (1 + abs(fGhostBias));
	float fBias = fScale / 2.0;
	return texCUBE(sDissolveMapSampler, vCoord).x + vObjectColor.x * fScale - fBias;
}

//////////////////////////////////////////////////////////////////////////////
// Ambient (Doesn't get to do ambient)
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient 
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float3 Fade		: TEXCOORD1;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	OUT.Fade = -GetPosition(IN);
	return OUT;
}

float4 Ambient_PS(PSData_Ambient IN) : COLOR
{
	//return float4(IN.DebugVec, 1);
	
	float4 vResult = float4(0,0,0,1);

	float4 vDiffuseColor = GetMaterialDiffuse(IN.TexCoord);
	vResult.xyz = GetLightDiffuseColor().xyz * vDiffuseColor.xyz / vObjectColor.xyz;
	vResult.w = GetAlpha(IN.Fade);
	
	return vResult;
}

technique Ambient
{
	pass Draw
	{
		AlphaRef = 254;
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
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float3 LightVector	: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float3 Fade			: TEXCOORD3;
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	OUT.Fade = -GetPosition(IN);
	return OUT;
}

float4 Point_PS(PSData_Point IN) : COLOR
{
	float4 vResult = GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
		GetLightDiffuseColor().xyz / vObjectColor.xyz, GetLightSpecularColor(), fMaxSpecularPower);
		
	return vResult * saturate(GetAlpha(IN.Fade) + fGhostBias);
}

technique Point
{
	pass Draw
	{		
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
	float3 Fade								: TEXCOORD1;
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD2;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	GetPointFillVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector);
	OUT.Fade = -GetPosition(IN);
	return OUT;
}

// Standard diffuse pixel color calculator for N lights w/o object discoloration
float4 GetDissolvePointFillPixelColor(
		in float3 vLightVector[NUM_POINT_FILL_LIGHTS],	// Light radius-scaled vector from the point to the light
		in float3 vUnitSurfaceNormal,					// Unit surface normal
		in float4 vMaterialDiffuseColor					// Material diffuse color
	)
{

	half4 vResult = half4(0,0,0,1);

	for(int nCurrLight = 0; nCurrLight < NUM_POINT_FILL_LIGHTS; nCurrLight++)
	{
		half3 vLightDiffuseColor = vObjectFillLightColor[nCurrLight].xyz / vObjectColor.xyz;
		half3 vUnitLightVector = normalize(vLightVector[nCurrLight]);

		// *** Diffuse ***
		half3 vLightResult = GetDiffuseColor(vUnitSurfaceNormal, vUnitLightVector, 1.0, vLightDiffuseColor);

		// *** Distance attenuation ***
		vLightResult *= CalcDistanceAttenuation(vLightVector[nCurrLight]);
		
		vResult.xyz += vLightResult;
	}
	
	vResult.xyz *= vMaterialDiffuseColor.xyz;

	return vResult;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	float4 vResult = GetDissolvePointFillPixelColor(IN.LightVector, GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord));
	
	return vResult * saturate(GetAlpha(IN.Fade) + fGhostBias);
}

technique PointFill
{
	pass Draw
	{		
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0;
	float3 LightVector		: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float4 LightMapCoord	: TEXCOORD3;
	float2 ClipPlanes		: TEXCOORD4;
	float3 Fade				: TEXCOORD5;
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

	OUT.Fade = -GetPosition(IN);

	return OUT;
}

float4 SpotProjector_PS(PSData_SpotProjector IN) : COLOR
{
	// Get the pixel
	float4 vPixelColor = GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
		DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord) / vObjectColor.xyz, DX9GetSpotProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);

	// Perform clipping
	return vPixelColor * DX9GetSpotProjectorClipResult(IN.ClipPlanes, IN.LightMapCoord) * saturate(GetAlpha(IN.Fade) + fGhostBias);
}

technique SpotProjector
{
	pass Draw
	{
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0;
	float3 LightVector		: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float3 LightMapCoord	: TEXCOORD3;
	float3 Fade				: TEXCOORD4;
};	

PSData_CubeProjector CubeProjector_VS(MaterialVertex IN) 
{
	PSData_CubeProjector OUT;

	float3 vPosition = GetPosition(IN);
	GetVertexAttributes(vPosition, GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	// Lightmap coord sampling position
	OUT.LightMapCoord = GetCubeProjectorTexCoord(vPosition);
	 
	OUT.Fade = -GetPosition(IN);

	return OUT;
}

float4 CubeProjector_PS(PSData_CubeProjector IN) : COLOR
{
	// Get the pixel
	float4 vResult = GetLitPixelColor(IN.LightVector, IN.EyeVector, 
		GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), 
		GetCubeProjectorDiffuseColor(IN.LightMapCoord) / vObjectColor.xyz, GetCubeProjectorSpecularColor(IN.LightMapCoord), fMaxSpecularPower);

	return vResult * saturate(GetAlpha(IN.Fade) + fGhostBias);
}

technique CubeProjector
{
	pass Draw
	{		
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
	float4 Position			: POSITION;
	float2 TexCoord			: TEXCOORD0;
	float3 LightVector		: TEXCOORD1;
	float3 EyeVector		: TEXCOORD2;
	float3 TexSpace			: TEXCOORD3;
	float3 Fade				: TEXCOORD4;
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	GetDirectionalVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector, OUT.TexSpace);

	OUT.Fade = -GetPosition(IN);

	return OUT;
}

// Standard diffuse + Blinn specular pixel color calculator for directional lights w/o object color modulate
float4 GetDissolveDirectionalLitPixelColor(
		float3 vLightUnit, // Unit-length directional light direction, in tangent space
		float3 vTexSpace, // Directional texture space
		float3 vEyeVector, // Vector from the point to the eye
		float3 vSurfaceNormal, // Surface normal
		float4 vMaterialDiffuseColor, // Material diffuse color
		float4 vMaterialSpecularColor, // Material specular color -- gloss value in w
		float fMaxSpecularPower // Maximum specular power
	)
{

	float4 vResult = float4(0,0,0,1);

	//get the color to use for the lighting
	float4 vBaseColor =	GetDirectionalLightBaseColor(vTexSpace);

	// *** Diffuse ***
	vResult.xyz += GetDiffuseColor(vSurfaceNormal, vLightUnit, vMaterialDiffuseColor.xyz, GetDirectionalLightDiffuse(vBaseColor) / vObjectColor.xyz);

	// *** Specular ***
	vResult.xyz += GetBlinnSpecularColor(
		vSurfaceNormal, 
		vLightUnit,
		normalize(vEyeVector),
		vMaterialSpecularColor.xyz,
		vMaterialSpecularColor.w,
		fMaxSpecularPower,
		GetDirectionalLightSpecular(vBaseColor));

	return vResult;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	float4 vResult = GetDissolveDirectionalLitPixelColor(normalize(IN.LightVector), IN.TexSpace, IN.EyeVector, GetSurfaceNormal_Unit(IN.TexCoord),
			GetMaterialDiffuse(IN.TexCoord), GetMaterialSpecular(IN.TexCoord), fMaxSpecularPower);
			
	return vResult * saturate(GetAlpha(IN.Fade) + fGhostBias);			
}

//----------------------------------------------------------------------------
// Directional Technique
technique Directional
{
	pass Draw
	{		
		ZFunc = LessEqual;
		StencilEnable = False;
		SrcBlend = One;
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
	float3 Fade		: TEXCOORD2;
};																				
																				
PSData_Encode_Depth Encode_Depth_VS(MaterialVertex IN)
{																				
	PSData_Encode_Depth OUT;											
	OUT.Position = TransformToClipSpace(GetPosition(IN));						
	GetDepthEncodeCoords(OUT.Position.z, OUT.DepthRG, OUT.DepthBA);				
																				
	OUT.Fade = -GetPosition(IN);
	
	return OUT;																	
}																				
																				
float4 Encode_Depth_PS(PSData_Encode_Depth IN) : COLOR
{
	float4 vResult;
	vResult.xyz = EncodeDepth(IN.DepthRG, IN.DepthBA);
	vResult.w = GetAlpha(IN.Fade);
	return vResult;
}
	
technique FogVolume_Depth														
{																				
	pass Draw																	
	{																			
		AlphaRef = 254;
		AlphaFunc = Greater;
		AlphaTestEnable = True;
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Encode_Depth_VS();				
		PixelShader = compile ps_3_0 Encode_Depth_PS();
	}																			
}													

