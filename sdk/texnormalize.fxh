#ifndef __TEXNORMALIZE_FXH__
#define __TEXNORMALIZE_FXH__

#include "basedefs.fxh"

//-------------------------------------------------------------------------------
// Normalization
// 
// This allows for normalization of a vector within a pixel shader by using a
// globally accessible cubic normalization map provided by the renderer. Note
// that this does consume one texture access.
//-------------------------------------------------------------------------------
// Cubic normalization map
shared texture tNormalizationMap;
SAMPLER_WRAP_LINEAR(sNormalizationMapSampler, tNormalizationMap);

// Normalizes a texture coordinate input in a pixel shader
float3 TexNormalizeVector(float3 vValue)
{
	return ColorToUnitVector(texCUBE(sNormalizationMapSampler, vValue).xyz);
}

#endif

