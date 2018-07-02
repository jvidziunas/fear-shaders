//-----------------------------------------------------------------
// FogVolumes.fxh
//
// Provides variables and functions used for manipulating fog volumes
//-----------------------------------------------------------------

#ifndef __FOGVOLUMES_FXH__
#define __FOGVOLUMES_FXH__

#include "basedefs.fxh"

// Depth map for the non-fog volume geometry
shared texture tFogVolume_DepthMap;
SAMPLER_CLAMP_POINT(sFogVolume_DepthMapSampler, tFogVolume_DepthMap);

// Encoding map for fog volume depth values
shared texture tFogVolume_EncodeMapRG;
SAMPLER_WRAP_POINT(sFogVolume_EncodeMapRGSampler, tFogVolume_EncodeMapRG);

shared texture tFogVolume_EncodeMapBA;
SAMPLER_WRAP_POINT(sFogVolume_EncodeMapBASampler, tFogVolume_EncodeMapBA);

// Scene description values
shared float fScene_FarZ;

//-------------------------------------------------------------------------------
// Fog volume support functions
//-------------------------------------------------------------------------------

// Gets the depth value scaled to the proper range for the fog volume encoding
float GetFogVolumeDepth(float fDepth)
{
	return fDepth / fScene_FarZ;
}

// Encodes a depth value as 2 sets of texture coords
void GetFogVolumeEncodeCoords(float fValue, out float2 vCoordRG : TEXCOORD0, out float2 vCoordBA : TEXCOORD1)
{
	fValue = min(GetFogVolumeDepth(fValue), 16.0);
	vCoordRG = fValue * float2(1.0, 16.0);
	vCoordBA = fValue * float2(1.0/16.0, 256.0);
}

// Converts 2 sets of pre-encoded texture coords to an encoded RGBA depth value
float4 GetFogVolumeEncodeRGBA(float2 vCoordRG : TEXCOORD0, float2 vCoordBA : TEXCOORD1) : COLOR
{
	return tex2D(sFogVolume_EncodeMapRGSampler, vCoordRG) + tex2D(sFogVolume_EncodeMapBASampler, vCoordBA);
}

// Decodes a depth encoded RGBA value
float GetFogVolumeDecodeRGBA(float4 vValue)
{
	return dot(vValue, float4(1.0, 16.0, 1.0/16.0, 256.0));
}

#endif
