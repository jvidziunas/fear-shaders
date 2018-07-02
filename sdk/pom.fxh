#ifndef __POM_FXH__
#define __POM_FXH__

float2 GetPOMDepthOffset( float3 vCoord, float3 vEye, float3 vLight, float fDepthScale )
{
	const int nSamples = 16;
	float3 vDelta = normalize(vEye);
	vDelta.xy *= fDepthScale;
	vDelta.z *= nSamples;
	vDelta.xy /= vDelta.z;
	float3 vOffset = float3( 0.0f, 0.0f, 0.0f );
	float fTexHeight;
	float fOffsetScale;

	for( int i = 0; i < nSamples-1; ++i )
	{
		fTexHeight = tex2D( sNormalMapSampler, vCoord.xy + vOffset ).w;

		fOffsetScale = (fTexHeight < vOffset.z);
		vOffset += vDelta * fOffsetScale;
	}

	float fPrevHeight = fTexHeight;
	fTexHeight = tex2D( sNormalMapSampler, vCoord.xy + vOffset ).w;

	fOffsetScale = (fTexHeight < vOffset.z);
	vOffset += vDelta * fOffsetScale;
	
	float2 vTemp = float2( fStepSize + (1.0 / (float)nSamples),  );
	
	
	MOV 	R1.y, TC.z;
ADD 	R1.x, R1.y, invSteps;
ADD 	delta0, R1.x, -H0.w;
ADD 	delta1, R1.y, -H1.w;
MUL 	R2.x, R1.y, delta0;
MAD 	R2.x, R1.x, delta1, -R2.x;
ADD 	R2.y, delta1, -delta0;
RCP 	R2.y, R2.y;
MUL 	R2, R2.x, R2.y;

MUL 	R1.xy, delta, Steps;
MAD 	R1.zw, delta.xyxy, Steps, specularTC.xyxy;
MAD 	TC, -R2, R1.xyxy, R1.zwzw;

	/*
	// Sample the depth map
	float fDepth = tex2D(sNormalMapSampler, vCoord).w;
	// Offset the texture coords based on the depth and the eye direction
	float2 vHalfOffset = normalize(vEye).xy * (fDepth) * fBumpScale;
	// Sample the depth map again and use the average to converge on a better solution
	fDepth = (fDepth + tex2D(sNormalMapSampler, vCoord + vHalfOffset).w) * 0.5;
	vHalfOffset = normalize(vEye).xy * (fDepth) * fBumpScale;
	// Sample the depth map again and use the average to converge on a better solution
	fDepth = (fDepth + tex2D(sNormalMapSampler, vCoord + vHalfOffset).w) * 0.5;
	vHalfOffset = normalize(vEye).xy * (fDepth) * fBumpScale;
	
	// We're done.  (More iterations than that and it doesn't fit any more.)
	return vHalfOffset;
	*/
}

#endif