//-----------------------------------------------------------------
// SinTable.fxh
//
// Provides utilities for accessing a sine table in texture form
//-----------------------------------------------------------------

#ifndef __SINTABLE_FXH__
#define __SINTABLE_FXH__

//-------------------------------------------------------------------------------
// Sin/Cos table access
//-------------------------------------------------------------------------------

// Sin/cos table for avoiding extra instruction overhead (1D, 16-bit on DX9 hardware)
shared texture tSinTable;
SAMPLER_WRAP(sSinTableSampler, tSinTable);

// Range is 0..1 instead of 0..2*PI
float GetSinTex(float fInput)
{
	return ColorToUnitVector(tex1D(sSinTableSampler, fInput).x);
}

#endif


