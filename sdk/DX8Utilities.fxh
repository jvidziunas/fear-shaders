//////////////////////////////////////////////////////////////////////////////
// DX8 (ps/vs 1.1) standard utilities

#include "lightdefs.fxh"
#include "texnormalize.fxh"

// The light map sampler can't have mipmap support under DX8 because it doesn't
// clip the sides of the lighting frustum.
sampler sSpotProjector_LightMapSampler_DX8 = sampler_state
{
	texture = <tSpotProjector_LightMap>;
	AddressU = Clamp;
	AddressV = Clamp;
	MipFilter = None;
};

// PS 1.1 - Single-iteration Newton-Raphson normalize approximation
float3 ApproximateNormalize(float3 vVec)
{
	// Original equation = vVec * (1 - dot(vVec, vVec)) / 2 + vVec;
	// This way optimizes better...
	float fHalfVec = vVec / 2.0;
	return vVec + fHalfVec * (1 - saturate(dot(vVec, vVec)));
}

// Same as above, but with a color vector (range 0..1 instead of -1..1)
// Note : This is required because the compiler gets confused and introduces
// an extra instruction where it shouldn't when using the above function with
// a pre-expanded color vector.  This way it's only 2 extra ps 1.1 instructions 
// to normalize a vector instead of 3.
float3 ApproximateNormalizeColorVector(float3 vVec)
{
	float3 vHalfVec = vVec - 0.5.xxx;
	float3 vFullVec = vHalfVec * 2;
	return vFullVec + vHalfVec * (1 - saturate(dot(vFullVec, vFullVec)));
}

// VS 1.1 - Get the pseudo-half-angle used in specular calculations, given un-normalized
// lighting direction and eye direction vectors and a tangent space matrix
float3 DX8GetHalfAngle(float3 vLightVec, float3 vEyeVec, float3x3 mObjToTangent)
{
	// This is the more "correct" calculation of the half-angle vector.
	// Unfortunately that doesn't interpolate very well, since it's a normalized vector
	/*
	float3 vHalfVec = normalize(normalize(vEyeVec) + normalize(vLightVec));
	// Transform to tangent space
	return mul(mObjToTangent, vHalfVec);
	//*/

	// Using the two un-normalized eye and light vectors leads to a vector
	// that can be interpolated, and is correct enough to look acceptable
	// (It is intended to be interpolated in the pixel shader)
	return mul(mObjToTangent, vEyeVec + vLightVec);
}

// Half-intensity version of vObjectLightColor, allowing intensities up to 2.0
shared float4 vHalfObjectLightColor;
//the color of each of the fill lights modulated by the color of the object
shared float4 vHalfObjectFillLightColor[NUM_POINT_FILL_LIGHTS];

half4 DX8GetLightDiffuseColor()	{ return vHalfObjectLightColor * 2.0; }

//given a four component vector representing the interpolated value returned from the spot
//projector texture coordinate generator, returns the spot projector's color
float3	DX8GetSpotProjectorDiffuseColor(float4 vUVWCoords)
{
	float3 vLightMapColor = tex2D(sSpotProjector_LightMapSampler_DX8, vUVWCoords).xyz;
	vLightMapColor *= DX8GetLightDiffuseColor().xyz;
	return vLightMapColor;
}

float3	DX8GetSpotProjectorSpecularColor(float4 vUVWCoords)
{
	float fSpecularIntensity = tex2D(sSpotProjector_LightMapSampler_DX8, vUVWCoords).w;
	return GetLightSpecularColor() * fSpecularIntensity;
}

float3 DX8GetDirectionalLightDiffuseColor(float2 vTexCoords)
{
	float3 vLightMapColor = tex2D(sDirectional_ProjectionSampler, vTexCoords).xyz;
	return DX8GetLightDiffuseColor().xyz * vLightMapColor;
}

float3 DX8GetDirectionalLightSpecularColor(float2 vTexCoords)
{
	float fSpecularIntensity = tex2D(sDirectional_ProjectionSampler, vTexCoords).w;
	return GetLightSpecularColor() * fSpecularIntensity;
}

half3 DX8GetCubeProjectorDiffuseColor(float3 vUVCoords)
{
	half3 vLightMapColor = texCUBE(sCubeProjector_LightMapSampler, vUVCoords).xyz;
	vLightMapColor.xyz *= DX8GetLightDiffuseColor().xyz;
	return vLightMapColor;
}

half3 DX8GetCubeProjectorSpecularColor(float3 vUVCoords)
{
	float fSpecularIntensity = texCUBE(sCubeProjector_LightMapSampler, vUVCoords).w;
	return GetLightSpecularColor() * fSpecularIntensity;
}

half4 DX8GetPointFillLightDiffuseColor(int index)	{ return vHalfObjectFillLightColor[index] * 2.0; }

// Calculate the specular component of a lighting pass
// Note: If the bTexNormalize flag is set to true, vHalfVec must come from a texture coordinate, and will
// use the TexNormalizeVector function.  If set to false, ApproximateNormalize will be used instead.
float3 DX8CalcSpecular(float3 vNormal, float4 vMaterialSpecular, float3 vLightSpecular, float3 vHalfVec, uniform bool bTexNormalize = true)
{
	// N.H
	float3 vUnitHalfVec = (bTexNormalize) ? TexNormalizeVector(vHalfVec) : ApproximateNormalize(vHalfVec);
	float fSpecular = saturate(dot(vNormal, vUnitHalfVec));

	// N.H^8
	fSpecular *= fSpecular;
	fSpecular *= fSpecular;
	fSpecular *= fSpecular;
		
	// Get the specular result
	// Note : The * fSpecular here instead of later buys us a co-issued instruction
	return vLightSpecular * vMaterialSpecular.xyz * fSpecular;
}

