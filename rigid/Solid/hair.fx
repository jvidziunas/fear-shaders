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
DECLARE_DESCRIPTION("This is the hair material. This behaves like the anisotropic shader with a vertical specular offset in the specular alpha channel.");
DECLARE_DOCUMENATION("Shaders\\Docs\\hair\\main.htm");
DECLARE_PARENT_MATERIAL(0, "specular_dx8.fxi");

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
MIPARAM_TEXTURE(tAnisotropyMap, 0, 4, "", false, "Anisotropic lighting map.  The color channel represents the color of the specular highlight based on the viewing angle.  The alpha channel represents the shape of the specular highlight.");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);
SAMPLER_WRAP_sRGB(sEmissiveMapSampler, tEmissiveMap);
SAMPLER_WRAP(sSpecularMapSampler, tSpecularMap);
SAMPLER_CLAMP(sAnisotropyMapSampler, tAnisotropyMap);
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
float4 GetMaterialDiffuse(float2 vCoord)
{
	return LinearizeAlpha( tex2D(sDiffuseMapSampler, vCoord) );
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

// Evaluate our lighting equation for this shader
float4 GetLitPixel(float2 vTexCoord, float3 vLightVector, float3 vEyeVector, float3 vLightDiffuse, float3 vLightSpecular)
{
	float4 vResult = float4(0,0,0,1);

	float3 vSurfaceNormal = GetSurfaceNormal_Unit(vTexCoord);
	float3 vUnitLight = normalize(vLightVector);
	float3 vUnitEye = normalize(vEyeVector);
	float3 vUnitHalf = normalize(vUnitLight + vUnitEye);

	// Diffuse contribution
	float3 vDiffuse = GetMaterialDiffuse(vTexCoord).xyz * vLightDiffuse * saturate(dot(vSurfaceNormal, vUnitLight));

	// Specular contribution

	// Get the full basis space...
	float3 vBinormal = normalize(cross(vSurfaceNormal, float3(0,1,0)));
	float3 vTangent = cross(vSurfaceNormal, vBinormal); // Normalize not required, vBinormal is already perpendicular, and both are unit vectors
	
	// Do a look-up in the anisotropy texture
	float2 vCoord;
	float4 vAnisotropySample;
	vCoord = float2(dot(vTangent, vUnitEye), dot(vBinormal, vUnitEye));
	vAnisotropySample.xyz = tex2D(sAnisotropyMapSampler, vCoord * 0.5 + 0.5.xx);
	vCoord = float2(dot(vBinormal, vUnitHalf), dot(vTangent, vUnitHalf));
	// Bais the specular look-up by the hair offset
	float2 vHairOffset = float2(0.5, GetMaterialSpecular(vTexCoord).w);
	vAnisotropySample.w = tex2D(sAnisotropyMapSampler, vCoord * 0.5 + vHairOffset).w;
	// Raise the specular highlight to the specular power....
	vAnisotropySample.w = pow(saturate(vAnisotropySample.w), fMaxSpecularPower);

	float3 vSpecular = GetMaterialSpecular(vTexCoord).xyz * vLightSpecular * vAnisotropySample.xyz * vAnisotropySample.w;

	vResult.xyz = (vDiffuse + vSpecular) * CalcDistanceAttenuation(vLightVector);

	return vResult;
}

// Evaluate our lighting equation for this shader for Directional light
float4 GetLitPixel(float2 vTexCoord, float3 vLightVector, float3 vEyeVector, float3 vTexSpace)
{
	float4 vResult = float4(0,0,0,1);

	float3 vSurfaceNormal = GetSurfaceNormal_Unit(vTexCoord);
	float3 vUnitLight = normalize(vLightVector);
	float3 vUnitEye = normalize(vEyeVector);
	float3 vUnitHalf = normalize(vUnitLight + vUnitEye);
	
	float4 vBaseLight = GetDirectionalLightBaseColor(vTexSpace);
	float3 vLightDiffuse = GetDirectionalLightDiffuse(vBaseLight).xyz;
	float3 vLightSpecular = GetDirectionalLightSpecular(vBaseLight).xyz;

	// Diffuse contribution
	float3 vDiffuse = GetMaterialDiffuse(vTexCoord).xyz * vLightDiffuse * saturate(dot(vSurfaceNormal, vUnitLight));

	// Specular contribution

	// Get the full basis space...
	float3 vBinormal = normalize(cross(vSurfaceNormal, float3(0,1,0)));
	float3 vTangent = cross(vSurfaceNormal, vBinormal); // Normalize not required, vBinormal is already perpendicular, and both are unit vectors
	
	// Do a look-up in the anisotropy texture
	float2 vCoord;
	float4 vAnisotropySample;
	vCoord = float2(dot(vTangent, vUnitEye), dot(vBinormal, vUnitEye));
	vAnisotropySample.xyz = tex2D(sAnisotropyMapSampler, vCoord * 0.5 + 0.5.xx);
	vCoord = float2(dot(vBinormal, vUnitHalf), dot(vTangent, vUnitHalf));
	vAnisotropySample.w = tex2D(sAnisotropyMapSampler, vCoord * 0.5 + 0.5.xx).w;
	// Raise the specular highlight to the specular power....
	vAnisotropySample.w = pow(saturate(vAnisotropySample.w), GetMaterialSpecular(vTexCoord).w * fMaxSpecularPower);

	float3 vSpecular = GetMaterialSpecular(vTexCoord).xyz * vLightSpecular * vAnisotropySample.xyz * vAnisotropySample.w;

	vResult.xyz = vDiffuse + vSpecular;

	return vResult;
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient 
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0_centroid;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	return OUT;
}

float4 Ambient_PS( PSData_Ambient IN ) : COLOR
{
	float4 vResult = float4( 0,0,0,1 );

	float4 vDiffuseColor = GetMaterialDiffuse(IN.TexCoord);
	clip( vDiffuseColor.w - 0.37647f );
	vResult.xyz = LinearizeColor( GetLightDiffuseColor().xyz ) * vDiffuseColor.xyz + GetMaterialEmissive(IN.TexCoord).xyz;
	vResult.w = vDiffuseColor.w;
	
	return vResult;
}

technique Ambient
{
	pass Draw
	{
		//AlphaRef = 96;
		//AlphaFunc = Greater;
		//AlphaTestEnable = True;
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
};

PSData_Point Point_VS(MaterialVertex IN)
{
	PSData_Point OUT;

	GetVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector);

	return OUT;
}

float4 Point_PS( PSData_Point IN ) : COLOR
{
	return GetLitPixel(IN.TexCoord, IN.LightVector, IN.EyeVector, GetLightDiffuseColor().xyz, GetLightSpecularColor());
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
	float4 Position							: POSITION;
	float2 TexCoord							: TEXCOORD0_centroid;
	float3 LightVector[NUM_POINT_FILL_LIGHTS]	: TEXCOORD1_centroid;
};

PSData_PointFill PointFill_VS(MaterialVertex IN)
{
	PSData_PointFill OUT;
	GetPointFillVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector);
	return OUT;
}

float4 PointFill_PS(PSData_PointFill IN) : COLOR
{
	return GetPointFillPixelColor(IN.LightVector, GetSurfaceNormal_Unit(IN.TexCoord), GetMaterialDiffuse(IN.TexCoord));
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
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0_centroid;
	float3 LightVector	: TEXCOORD1_centroid;
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
	float4 vPixelColor = GetLitPixel(IN.TexCoord, IN.LightVector, IN.EyeVector, 
		DX9GetSpotProjectorDiffuseColor(IN.LightMapCoord), DX9GetSpotProjectorSpecularColor(IN.LightMapCoord));

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
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0_centroid;
	float3 LightVector	: TEXCOORD1_centroid;
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
	return GetLitPixel(IN.TexCoord, IN.LightVector, IN.EyeVector, 
		GetCubeProjectorDiffuseColor(IN.LightMapCoord), GetCubeProjectorSpecularColor(IN.LightMapCoord));
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
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0_centroid;
	float3 LightVector	: TEXCOORD1_centroid;
	float3 EyeVector		: TEXCOORD2_centroid;
	float3 TexSpace		: TEXCOORD3_centroid;
};

PSData_Directional Directional_VS(MaterialVertex IN)
{
	PSData_Directional OUT;

	GetDirectionalVertexAttributes(GetPosition(IN), GetInverseTangentSpace(IN), IN.TexCoord, OUT.Position, OUT.TexCoord, OUT.LightVector, OUT.EyeVector, OUT.TexSpace);

	return OUT;
}

float4 Directional_PS(PSData_Directional IN) : COLOR
{
	return GetLitPixel(IN.TexCoord, normalize(IN.LightVector), IN.EyeVector, IN.TexSpace);
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

//////////////////////////////////////////////////////////////////////////////
// Depth encoding support
//////////////////////////////////////////////////////////////////////////////

struct PSData_Encode_Depth												
{																				
	float4 Position : POSITION;													
	float2 DepthRG	: TEXCOORD0_centroid;
	float2 DepthBA	: TEXCOORD1_centroid;
	float2 TexCoord : TEXCOORD2_centroid;
};																				
																				
PSData_Encode_Depth Encode_Depth_VS(MaterialVertex IN)
{																				
	PSData_Encode_Depth OUT;											
	OUT.Position = TransformToClipSpace(GetPosition(IN));						
	GetDepthEncodeCoords(OUT.Position.z, OUT.DepthRG, OUT.DepthBA);				
																				
	OUT.TexCoord = IN.TexCoord;
	
	return OUT;																	
}																				
																				
float4 Encode_Depth_PS(PSData_Encode_Depth IN) : COLOR
{
	float4 vResult;
	vResult.xyz = EncodeDepth(IN.DepthRG, IN.DepthBA);

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
		GAMMA_LINEAR_RENDERTARGET;

		VertexShader = compile vs_3_0 Encode_Depth_VS();				
		PixelShader = compile ps_3_0 Encode_Depth_PS();								
	}																			
}													

