//////////////////////////////////////////////////////////////////////////////
// DX9Lights (ps/vs 2.0) standard utilities
#ifndef __DX9LIGHTS_FXH__
#define __DX9LIGHTS_FXH__

//-------------------------------------------------------------------------------
#include "lightdefs.fxh"
#include "clipmap.fxh"
#include "transforms.fxh"
#include "BRDFLib.fxh"

// Forward declarations
float CalcDistanceAttenuation(float3 vVector);  // in sdk\lightdefs.fxh

// Standard diffuse color contribution calculator
half3 GetDiffuseColor(
		half3 vNormal, // Surface normal at the point
		half3 vLightVector, // Unit vector from the point to the light
		half3 vMaterialDiffuseColor, // Diffuse material color at the point
		half3 vLightDiffuseColor // Light color
	)
{
	// Angular attenuation
	half fAngularAttenuation = saturate( dot( vNormal, vLightVector ) );

	// Final diffuse contribution
	half3 vResult = vMaterialDiffuseColor * vLightDiffuseColor * fAngularAttenuation;

	return vResult;
}

half3 GetDiffuseColor(
		half3 vNormal, // Surface normal at the point
		half3 vLightVector, // Unit vector from the point to the light
		half3 vMaterialDiffuseColor, // Diffuse material color at the point
		half3 vLightDiffuseColor, // Light color
		half kr	// Reflectance at normal incidence
	)
{
	// Angular attenuation
	half fAngularAttenuation = saturate( dot( vNormal, vLightVector ) );

	// Final diffuse contribution
	half3 vResult = vMaterialDiffuseColor * vLightDiffuseColor * fAngularAttenuation;
	vResult = ( vResult * (1.0f - kr) );

	return vResult;
}

// Standard Blinn specular color contribution calculator
float3 GetBlinnSpecularColor(
		float3 vNormal, // Surface normal at the point
		float3 vLightVector, // Unit vector from the point to the light
		float3 vEyeVector, // Unit vector from the point to the eye
		float3 vMaterialSpecularColor, // Diffuse specular color at the point
		float fMaterialGloss, // Gloss value of the material (modulates maximum specular power)
		float fMaxSpecularPower,
		float3 vLightSpecularColor // Light specular color
	)
{
	// Calculate the float-vector
	float3 vHalfVector = normalize(vEyeVector + vLightVector);

	// Get the specular attenuation value
	float fSpecular = saturate(dot(vNormal, vHalfVector));
	float fFinalGloss = fMaterialGloss * fMaxSpecularPower;
	fSpecular = pow(fSpecular, fFinalGloss);
	// If we expand this out it can be computed with a single multiply-add
	float fNormalizationConstant = fFinalGloss/(8 * 3.14159265) + (1.0f/3.14159265);

	// Final specular contribution
	float3 vResult = vLightSpecularColor * vMaterialSpecularColor * fSpecular * fNormalizationConstant;

	return vResult;
}

// Standard diffuse + Blinn specular pixel color calculator
float4 GetLitPixelColor(
		float3 vLightVector, // Light radius-scaled vector from the point to the light
		float3 vEyeVector, // Vector from the point to the eye
		float3 vSurfaceNormal, // Surface normal
		float4 vMaterialDiffuseColor, // Material diffuse color
		float4 vMaterialSpecularColor, // Material specular color -- gloss value in w
		float3 vLightDiffuseColor, // Light diffuse color
		float3 vLightSpecularColor, // Light specular color
		float fMaxSpecularPower // Maximum specular power
	)
{
	float4 vResult = float4(0,0,0,1);

	float fDistanceAttenuation = CalcDistanceAttenuation(vLightVector);

	// Get the unit light vector
	float3 vUnitLightVector = normalize(vLightVector);

	// *** Diffuse ***
	vResult.xyz = GetDiffuseColor( vSurfaceNormal, vUnitLightVector, vMaterialDiffuseColor.xyz, vLightDiffuseColor );

	// *** Specular ***
	vResult.xyz += GetBlinnSpecularColor(
		vSurfaceNormal, 
		vUnitLightVector,
		normalize(vEyeVector),
		vMaterialSpecularColor.xyz,
		vMaterialSpecularColor.w,
		fMaxSpecularPower,
		vLightSpecularColor );

	// *** Distance attenuation ***
	vResult.xyz *= fDistanceAttenuation;

	return vResult;
}

// Standard vertex attribute calculator
void GetVertexAttributes(
		in float3 vObjectPosition,
		in float3x3 mObjToTangent,
		in float2 vVertTexCoord,
		out float4 vClipPosition,
		out float2 vTexCoord,
		out float3 vLightVector,
		out float3 vEyeVector
		)
{
	// Transform the position
	vClipPosition = TransformToClipSpace(vObjectPosition);
	// Pass through the texture coordinates
	vTexCoord = vVertTexCoord;

	// Calculate the light vector
	float3 vLightOffset = (vObjectSpaceLightPos - vObjectPosition);
	float3 vTangentLight = mul(mObjToTangent, vLightOffset);
	vLightVector = vTangentLight * fInvLightRadius;

	// Calculate the eye vector
	float3 vEyeOffset = (vObjectSpaceEyePos - vObjectPosition);
	vEyeVector = mul(mObjToTangent, vEyeOffset);
}

// Standard diffuse pixel color calculator for N lights
float4 GetPointFillPixelColor(
		in float3 vLightVector[NUM_POINT_FILL_LIGHTS],	// Light radius-scaled vector from the point to the light
		in float3 vUnitSurfaceNormal,					// Unit surface normal
		in float4 vMaterialDiffuseColor					// Material diffuse color
	)
{

	float4 vResult = float4(0,0,0,1);
	
	for(int nCurrLight = 0; nCurrLight < NUM_POINT_FILL_LIGHTS; nCurrLight++)
	{
		half3 vLightDiffuseColor = CorrectLight(vObjectFillLightColor[nCurrLight].xyz);
		//float3 vLightVector_pp = vLightVector[nCurrLight];
		float3 vUnitLightVector = normalize(vLightVector[nCurrLight]); //normalize(vLightVector_pp);

		// *** Diffuse ***
		half3 vLightResult = GetDiffuseColor(vUnitSurfaceNormal, vUnitLightVector, 1.0, vLightDiffuseColor);

		// *** Distance attenuation ***
		vLightResult *= CalcDistanceAttenuation(vLightVector[nCurrLight]);
		
		vResult.xyz += vLightResult;
	}
	
	vResult.xyz *= vMaterialDiffuseColor.xyz;

	return vResult;
}

// Standard vertex attribute calculator for point fill lighting techniques
void GetPointFillVertexAttributes(
		in float3 vObjectPosition,
		in float3x3 mObjToTangent,
		in float2 vVertTexCoord,
		out float4 vClipPosition,
		out float2 vTexCoord,
		out float3 vLightVector[NUM_POINT_FILL_LIGHTS]
		)
{
	// Transform the position
	vClipPosition = TransformToClipSpace(vObjectPosition);
	// Pass through the texture coordinates
	vTexCoord = vVertTexCoord;

	// Calculate the light vectors
	for(int nCurrLight = 0; nCurrLight < NUM_POINT_FILL_LIGHTS; nCurrLight++)
	{
		float3 vLightOffset = (vObjectSpaceFillLightPos[nCurrLight] - vObjectPosition);
		float3 vTangentLight = mul(mObjToTangent, vLightOffset);
		vLightVector[nCurrLight] = vTangentLight * fInvFillLightRadius[nCurrLight];
	}
}

//Same as the above, but computes the eye vector
void GetPointFillVertexAttributesEye(
		in float3 vObjectPosition,
		in float3x3 mObjToTangent,
		in float2 vVertTexCoord,
		out float4 vClipPosition,
		out float2 vTexCoord,
		out float3 vLightVector[NUM_POINT_FILL_LIGHTS],
		out float3 vEyeVector
		)
{
	GetPointFillVertexAttributes(vObjectPosition, mObjToTangent, vVertTexCoord, vClipPosition, vTexCoord, vLightVector);
	vEyeVector = mul(mObjToTangent, vObjectSpaceEyePos - vObjectPosition);
}

// Get the spot projector clipping result under DX9 (which can do the FOV clipping)
half DX9GetSpotProjectorClipResult(half2 vNearFarClip, half4 vPosition)
{
	return GetClipResult(vNearFarClip) * GetClipResult(abs(vPosition.xy / vPosition.w - 0.5));
}

//given a four component vector representing the interpolated value returned from the spot
//projector texture coordinate generator, returns the spot projector's color
half3	DX9GetSpotProjectorDiffuseColor( half4 vUVWCoords )
{
	half3 vLightMapColor = tex2Dproj(sSpotProjector_LightMapSampler, vUVWCoords).xyz;
	vLightMapColor *= GetLightDiffuseColor().xyz;
	return vLightMapColor;
}

half3	DX9GetSpotProjectorSpecularColor( half4 vUVWCoords )
{
	half3 fSpecularIntensity = (half3)tex2Dproj(sSpotProjector_LightMapSampler, vUVWCoords).w;
	return GetLightSpecularColor() * fSpecularIntensity;
}


// Directional light base color (PS)
half4 GetDirectionalLightBaseColor(half3 vTexSpace)
{
	return	tex2D(sDirectional_ProjectionSampler, vTexSpace.xy) * 
			tex1D(sDirectional_AttenuationSampler, vTexSpace.z) *
			tex2D(sDirectional_ClipMapSampler, vTexSpace.xy * 0.5 + half2(0.25, 0.25)) *
			tex2D(sDirectional_ClipMapSampler, half2(vTexSpace.z * 0.5 + 0.25, 0.5));
}

//Called to get the diffuse light color for a directional light provided an existing directional light
//color
half4 GetDirectionalLightDiffuse(half4 vBaseColor)
{
	return GetLightDiffuseColor() * vBaseColor;
}

//Called to get the specular light color for a directional light provided an existing directional light
//color
half3 GetDirectionalLightSpecular(half4 vBaseColor)
{
	return GetLightSpecularColor() * vBaseColor.xyz;
}


// Standard vertex attribute calculator for directional light
void GetDirectionalVertexAttributes(
		in float3 vObjectPosition,
		in float3x3 mObjToTangent,
		in float2 vVertTexCoord,
		out float4 vClipPosition,
		out float2 vTexCoord,
		out float3 vLightVector,
		out float3 vEyeVector,
		out float3 vTexSpace
		)
{
	// Transform the position
	vClipPosition = TransformToClipSpace(vObjectPosition);
	
	// Pass through the texture coordinates
	vTexCoord = vVertTexCoord;

	// Calculate the light vector
	vLightVector = mul(mObjToTangent, -vDirectional_Dir);

	// Calculate the eye vector
	// Note: The arbitrary scale here is to prevent issues with the half data type.  Using this value
	// seems to be sufficient for preserving image quality and precision in all observed cases.
	float3 vEyeOffset = (vObjectSpaceEyePos - vObjectPosition) / 256.0;
	vEyeVector = mul(mObjToTangent, vEyeOffset);
	
	// Calculate the position in the clip and texture spaces
	vTexSpace = mul(mDirectional_ObjectToTex, float4(vObjectPosition, 1.0)).xyz;
}

// Standard diffuse + Blinn specular pixel color calculator for directional lights
half4 GetDirectionalLitPixelColor(
		half3 vLightUnit, // Unit-length directional light direction, in tangent space
		half3 vTexSpace, // Directional texture space
		half3 vEyeVector, // Vector from the point to the eye
		half3 vSurfaceNormal, // Surface normal
		half4 vMaterialDiffuseColor, // Material diffuse color
		half4 vMaterialSpecularColor, // Material specular color -- gloss value in w
		half fMaxSpecularPower // Maximum specular power
	)
{

	half4 vResult = half4(0,0,0,1);

	//get the color to use for the lighting
	half4 vBaseColor =	GetDirectionalLightBaseColor(vTexSpace);

	// *** Diffuse ***
	vResult.xyz += GetDiffuseColor(vSurfaceNormal, vLightUnit, vMaterialDiffuseColor.xyz, GetDirectionalLightDiffuse(vBaseColor));

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

#endif
