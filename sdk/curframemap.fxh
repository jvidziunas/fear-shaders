#ifndef __CURFRAMEMAP_FXH__
#define __CURFRAMEMAP_FXH__

#include "basedefs.fxh"

// the previous rendered frame
shared texture tCurFrameMap;
SAMPLER_CLAMP_sRGB(sCurFrameMapSampler, tCurFrameMap);

#endif
