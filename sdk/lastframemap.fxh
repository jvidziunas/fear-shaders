#ifndef __LASTFRAMEMAP_FXH__
#define __LASTFRAMEMAP_FXH__

#include "basedefs.fxh"

// the previous rendered frame
shared texture tLastFrameMap;
SAMPLER_CLAMP_sRGB(sLastFrameMapSampler, tLastFrameMap);

#endif
