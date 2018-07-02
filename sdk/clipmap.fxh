#ifndef __CLIPMAP_FXH__
#define __CLIPMAP_FXH__

//-------------------------------------------------------------------------------
// Clipping
// 
// This allows clipping two vectors in the pixel pipeline using a clipping texture
//-------------------------------------------------------------------------------
// Black and white clipping texture
shared texture tClipMap;
sampler sClipMapSampler = sampler_state
{
	texture = <tClipMap>;
	MinFilter = Point;
	MagFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
};

float2 GetClipInterpolants(float4 aClipPlane0, float3 vVec0, float4 aClipPlane1, float3 vVec1)
{
	return float2(-dot(aClipPlane0, float4(vVec0, 1)) + 0.5, -dot(aClipPlane1, float4(vVec1, 1)) + 0.5);
}

// Simpler version for the common case with a spot projector..
float2 GetSpotProjectorClipInterpolants(float3 vPosition)
{
	return GetClipInterpolants(vSpotProjector_ClipNear, vPosition, float4(0,0,0,1), float3(0,0,0));
}

float GetClipResult(float2 vClipInterpolants)
{
	return tex2D(sClipMapSampler, vClipInterpolants).w;
}

#endif
