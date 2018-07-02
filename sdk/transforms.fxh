#ifndef __TRANSFORMS_FXH__
#define __TRANSFORMS_FXH__

// Full transformation from object space to the final clip space that the card uses
shared float4x4 mObjectToClip;

// Transform from object space to world space. Common for operations such as environment mapping
shared float4x4 mObjectToWorld;

// The position of the viewer in object space
shared float3 vObjectSpaceEyePos;

//-------------------------------------------------------------------------------
// Transform from object to clip space
//
// Given an input vertex, this will handle transforming it from object space
// to the clip space that the card needs
//-------------------------------------------------------------------------------
float4	TransformToClipSpace(float3	vVec)		{ return mul(mObjectToClip, float4(vVec, 1.0f)); }
float4	TransformToClipSpace(float4	vVec)		{ return mul(mObjectToClip, vVec); }

#endif

