//-----------------------------------------------------------------
// Noise.fxh
//
// Provides utilities for generating random noise values
//-----------------------------------------------------------------

#ifndef __NOISE_FXH__
#define __NOISE_FXH__

// Volume texture for doing a noise look-up
shared texture tNoiseMap3D;
// Note : The manual register binding fixes a bug relating to samplers in headers
sampler sNoiseMap3DSampler = sampler_state
{
	texture = <tNoiseMap3D>;
	AddressU = Wrap;
	AddressV = Wrap;
	AddressW = Wrap;
	MagFilter = Linear;
};

// 3D noise function
float4 Noise(float3 vCoord, float fPersist, int nOctaves, int nStartOctave)
{
	float4 vResult = 0.0.xxxx;
	float fBiasAccumulator = 0.0;
	for (int nCurOctave = nStartOctave; nCurOctave < (nOctaves + nStartOctave); ++nCurOctave)
	{
		float fFreq = pow(2, nCurOctave);
		float fAmp = 1.0 / pow(fPersist, nCurOctave);
		vResult += tex3D(sNoiseMap3DSampler, vCoord * fFreq) * fAmp;
		// Note : This emulates applying a -0.5 bias to all texture look-ups, which saves 1 instruction per octave
		fBiasAccumulator -= 0.5 * fAmp;
	}
	return (vResult + fBiasAccumulator) * 2.0;
}

// 2D noise function
float4 Noise(float2 vCoord, float fPersist, int nOctaves, int nStartOctave)
{
	float4 vResult = 0.0.xxxx;
	float fBiasAccumulator = 0.0;
	for (int nCurOctave = nStartOctave; nCurOctave < (nOctaves + nStartOctave); ++nCurOctave)
	{
		float fFreq = pow(2, nCurOctave);
		float fAmp = 1.0 / pow(fPersist, nCurOctave);
		vResult += tex2D(sNoiseMap3DSampler, vCoord * fFreq) * fAmp;
		fBiasAccumulator -= 0.5 * fAmp;
	}
	return (vResult + fBiasAccumulator) * 2.0;
}

// 1D noise function
float4 Noise(float fCoord, float fPersist, int nOctaves, int nStartOctave)
{
	float4 vResult = 0.0.xxxx;
	float fBiasAccumulator = 0.0;
	for (int nCurOctave = nStartOctave; nCurOctave < (nOctaves + nStartOctave); ++nCurOctave)
	{
		float fFreq = pow(2, nCurOctave);
		float fAmp = 1.0 / pow(fPersist, nCurOctave);
		vResult += tex1D(sNoiseMap3DSampler, fCoord * fFreq) * fAmp;
		fBiasAccumulator -= 0.5 * fAmp;
	}
	return (vResult + fBiasAccumulator) * 2.0;
}

#endif
