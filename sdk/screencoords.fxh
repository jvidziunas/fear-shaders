//--------------------------------------------------------------
// ScreenCoords.fxh
//
// Provides utilities for mapping to screen space coordinates
//--------------------------------------------------------------

#ifndef __SCREENCOORDS_FXH__
#define __SCREENCOORDS_FXH__

shared float2 vScene_ScreenRes;

// Calculates the screen-texture coords for a given transformed position
float4 GetScreenTexCoords(float4 vPos)
{
	float4 vResult;
	vResult.xy = vPos.xy * (0.5 + (0.25 / vScene_ScreenRes)) + vPos.w * float2(0.5 + 0.5/vScene_ScreenRes.x, 0.5 - 0.5/vScene_ScreenRes.y);
	vResult.y = vPos.w - vResult.y;
	vResult.zw = vPos.zw;
	return vResult;
}

#endif
