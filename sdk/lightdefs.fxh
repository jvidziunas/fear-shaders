#ifndef __LIGHTDEFS_FXH__
#define __LIGHTDEFS_FXH__

#include "basedefs.fxh"

// Position of the light in object space
shared float3 vObjectSpaceLightPos;

// Color of the light modulated by the object color
shared float4 vObjectLightColor;

// Clip planes for use with the spot projector to control near and far clipping
shared float4 vSpotProjector_ClipNear;

// Specular color of the light
shared float3 vSpecularColor;

// Inverse of the light radius (Valid for Point, Spot, SpotProjector, and CubeProjector lights)
shared float fInvLightRadius;

///////////////////////////////
// Point Fill light

//this indicates the number of point fill lights that can be rendered in a single
//pass
#define NUM_POINT_FILL_LIGHTS	3

//the object space position of each of the fill lights
shared float3	vObjectSpaceFillLightPos[NUM_POINT_FILL_LIGHTS];

//the inverse radius of each of the fill lights in object space
shared float	fInvFillLightRadius[NUM_POINT_FILL_LIGHTS];

//the color of each of the fill lights modulated by the color of the object
shared float4	vObjectFillLightColor[NUM_POINT_FILL_LIGHTS];

////////////////////////////////
// Spot Projector

// Transform that will take a point in object space and map it to the homogenous
// unit cube representing the spot projector frustum
shared float4x4 mSpotProjector_LightTransform;

// Texture emitted by the spot projector
shared texture tSpotProjector_LightMap;
SAMPLER_CLAMP(sSpotProjector_LightMapSampler, tSpotProjector_LightMap);

////////////////////////////////
// Cube Projector

// Transform that will take a point from object space and map it into the light's space
shared float3x4 mCubeProjector_LightTransform;

// Texture emitted by the cube projector
shared texture tCubeProjector_LightMap;
SAMPLER_WRAP(sCubeProjector_LightMapSampler, tCubeProjector_LightMap);

////////////////////////////////
// Directional Light

//the texture that is projected from the directional light onto the geometry
shared texture tDirectional_Projection;
SAMPLER_CLAMP(sDirectional_ProjectionSampler, tDirectional_Projection);

//the attenuation texture that controls the falloff of light as it moves away from the plane of emission
shared texture tDirectional_Attenuation;
SAMPLER_CLAMP_LINEAR(sDirectional_AttenuationSampler, tDirectional_Attenuation);

//the texture that can be used with a point projected in clip space to determine whether or not the pixel
//should be lit
shared texture tDirectional_ClipMap;
SAMPLER_CLAMP_POINT_LINEAR(sDirectional_ClipMapSampler, tDirectional_ClipMap);

//a transform that will take an object space position and map it to a unit cube in quadrant one that can be
//used for determining the texture projections
shared float4x4 mDirectional_ObjectToTex;

//the direction of projection in object space of the directional light
shared float3 vDirectional_Dir;

//the far clip plane of the directional light
shared float fDirectional_FarPlane;

//-------------------------------------------------------------------------------
// Distance attenuation calculation
//
// Given a vector that represents the offset from the light center to the sample
// this will return a floating point value in the range of [0..1] that represents
// the distance attenuation. This uses the distance attenuation function of
// (1 - d^2)^2 where d is the normalized distance relative to the light radius.
//-------------------------------------------------------------------------------
half CalcDistanceAttenuation(half3 vOffset)
{
#if 0
	half fDistanceSquared = 1 - saturate(dot(vOffset, vOffset));
	return fDistanceSquared * fDistanceSquared;
#else
	float transformedDistance = 1.2f * tan( 0.5f * 3.14159f * saturate(length(vOffset)) ) + 1.0f;
	return 1.0f / (transformedDistance * transformedDistance);
#endif
}

//-------------------------------------------------------------------------------
// Generate texture coordinates for a spot projector
//
// Given an input vertex, this will handle transforming it from object space
// to the projector space. The returned four component vector should be used
// with one of the GetSpotProjectorColor_ps_?_? functions
//-------------------------------------------------------------------------------
float4	GetSpotProjectorTexCoord(float3 vPosition)
{
	// Note that this can be optimized to 3 dot products if we drop shadow mapping support.
	return mul(mSpotProjector_LightTransform, float4(vPosition, 1));
}

//-------------------------------------------------------------------------------
// Generate texture coordinates for a cube projector
//
// Given an input vertex, this will handle transforming it from object space
// to the projector space. The returned three component vector should be used
// with the GetCubeProjectorColor function
//-------------------------------------------------------------------------------
float3	GetCubeProjectorTexCoord(float3 vPosition)
{
	//just transform the point into the light space
	 return mul(mCubeProjector_LightTransform, float4(vPosition, 1)).xyz;
}

//-------------------------------------------------------------------------------
// Gets the light color under various circumstances
//-------------------------------------------------------------------------------

//gets the light's diffuse color, modulated by the object color
half4	GetLightDiffuseColor()	{ return vObjectLightColor; }

//gets lights specular color
half3	GetLightSpecularColor()	{ return vSpecularColor; }

//given a three component vector representing the interpolated value returned from the spot
//cube texture coordinate generator, returns the cube projector's color
half3	GetCubeProjectorDiffuseColor(float3 vUVCoords)
{
	half3 vLightMapColor = texCUBE(sCubeProjector_LightMapSampler, vUVCoords).xyz;
	vLightMapColor.xyz *= GetLightDiffuseColor().xyz;
	return vLightMapColor;
}

half3	GetCubeProjectorSpecularColor(float3 vUVCoords)
{
	half fSpecularIntensity = texCUBE(sCubeProjector_LightMapSampler, vUVCoords).w;
	return GetLightSpecularColor() * fSpecularIntensity;
}

#endif
