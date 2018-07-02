#include "..\sdk\basedefs.fxh"
#include "..\sdk\screencoords.fxh"
#include "..\sdk\depthencode.fxh"
#include "..\sdk\noise.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is an internal shader related to the shadow blur implementation.");

#define ZPERCENT_EPSILON (1.0/32.0)
#define POISSON_BLUR 1

//////////////////////////////////////////////////////////////////////////////
// Main shader
//////////////////////////////////////////////////////////////////////////////

float2 GetKernelOffsets(int index)
{
	const float2 vKernelSize = {1.0 / 640.0, 1.0 / 480.0};
	
	const float2 aKernelOffsets[2] = {
					float2(-vKernelSize.x / 2, -vKernelSize.y),
					float2(-vKernelSize.x, vKernelSize.y / 2)
				};

	if (index == 0)
		return aKernelOffsets[index];
	else if (index == 1)
		return aKernelOffsets[index];
	else if (index == 2)
		return -aKernelOffsets[index - 2];
	else if (index == 3)
		return -aKernelOffsets[index - 2];
	else
		return float2(0,0);
}

void Blur_VS(
		float3 iPos : POSITION, 
		out float4 oPos : POSITION, 
		out float2 oTC0 : TEXCOORD0,
		out float4 oKernelTC[4] : TEXCOORD1)
{
	oPos = float4(iPos, 1.0);
	// We know it's a screen aligned quad, so drop the projection
	oTC0 = GetScreenTexCoords(oPos).xy;
#if POISSON_BLUR == 0
	for (int loop = 0; loop < 4; ++loop)
	{
		oKernelTC[loop].xy = oTC0 + GetKernelOffsets(loop) * 1.5;
		oKernelTC[loop].zw = oTC0 + GetKernelOffsets(loop) * -3.0;
	}
#endif
}

float CalcSamples(float4 iTC[4], float fBaseValue, float fBaseDepth)
{
	float4 vDepth;
	float4 vValue;

	// XY kernel TC samples	
	for (int loop = 0; loop < 4; ++loop)
	{
		float4 vSample = tex2D(sDepthMapSampler, iTC[loop].xy);
		vDepth[loop] = DecodeDepth_Raw(vSample.xyz);
		vValue[loop] = vSample.w;
	}
	vDepth = abs(fBaseDepth - vDepth) / fBaseDepth - ZPERCENT_EPSILON;
	
	vValue = (vDepth < 0) ? vValue : fBaseValue;
		
	float fResult = dot(vValue, 0.125.xxxx);

	// ZW kernel TC samples
	for (int loop = 0; loop < 4; ++loop)
	{
		float4 vSample = tex2D(sDepthMapSampler, iTC[loop].zw);
		vDepth[loop] = DecodeDepth_Raw(vSample.xyz);
		vValue[loop] = vSample.w;
	}
	vDepth = abs(fBaseDepth - vDepth) / fBaseDepth - ZPERCENT_EPSILON;
	
	vValue = (vDepth < 0) ? vValue : fBaseValue;
		
	fResult += dot(vValue, 0.125.xxxx);
	
	return fResult;
}

float4 Blur_PS(float2 iTC0 : TEXCOORD0, float4 iKernelTC[4] : TEXCOORD1) : COLOR
{
	float4 vBaseSample = tex2D(sDepthMapSampler, iTC0);
	float fBaseDepth = DecodeDepth_Raw(vBaseSample.xyz);
	float fBaseValue = vBaseSample.w;

#if POISSON_BLUR == 0
	float fResult = CalcSamples(iKernelTC, fBaseValue, fBaseDepth);
#else
	const float2 poisson_disc[16] = {
		float2( -0.94201624, -0.39906216 ),
		float2(  0.94558609, -0.76890725 ),
		float2( -0.09418410, -0.92938870 ),
		float2(  0.34495938,  0.29387760 ),
		float2( -0.91588581,  0.45771432 ),
		float2( -0.81544232, -0.87912464 ),
		float2( -0.38277543,  0.27676845 ),
		float2(  0.97484398,  0.75648379 ),
		float2(  0.44323325, -0.97511554 ),
		float2(  0.53742981, -0.47373420 ),
		float2( -0.26496911, -0.41893023 ),
		float2(  0.79197514,  0.19090188 ),
		float2( -0.24188840,  0.99706507 ),
		float2( -0.81409955,  0.91437590 ),
		float2(  0.19974126,  0.78641367 ),
		float2(  0.14383161, -0.14100790 )
	};

	float4 vDepth;
	float4 vValue;
	float inv16 = 0.0625;
	float fResult = 0;
	float fDepthScale = max( UnAdjustZ( fBaseDepth ), 64.0 );
	const float2 aspect = float2( 0.75, 1.0 ) * ( tex2D( sNoiseMap3DSampler, iTC0 * 32.0 ).xy * 1.95 + 0.05 );
	
	[unroll]
	for ( int i = 0; i < 4; ++i ) {
		float2 uv = poisson_disc[i] * aspect / fDepthScale + iTC0;
		float4 vSample = tex2D( sDepthMapSampler, uv );
		vDepth[i] = DecodeDepth_Raw( vSample.xyz );
		vValue[i] = vSample.w;
	}
	vDepth = abs( fBaseDepth - vDepth ) / fBaseDepth - ZPERCENT_EPSILON;
	vValue = ( vDepth < 0 ) ? vValue : fBaseValue;
	fResult += dot( vValue, inv16 );
	
	[unroll]
	for ( int i = 0; i < 4; ++i ) {
		float2 uv = poisson_disc[i + 4] * aspect / fDepthScale + iTC0;
		float4 vSample = tex2D( sDepthMapSampler, uv );
		vDepth[i] = DecodeDepth_Raw( vSample.xyz );
		vValue[i] = vSample.w;
	}
	vDepth = abs( fBaseDepth - vDepth ) / fBaseDepth - ZPERCENT_EPSILON;
	vValue = ( vDepth < 0 ) ? vValue : fBaseValue;
	fResult += dot( vValue, inv16 );
	
	[unroll]
	for ( int i = 0; i < 4; ++i ) {
		float2 uv = poisson_disc[i + 8] * aspect / fDepthScale + iTC0;
		float4 vSample = tex2D( sDepthMapSampler, uv );
		vDepth[i] = DecodeDepth_Raw( vSample.xyz );
		vValue[i] = vSample.w;
	}
	vDepth = abs( fBaseDepth - vDepth ) / fBaseDepth - ZPERCENT_EPSILON;
	vValue = ( vDepth < 0 ) ? vValue : fBaseValue;
	fResult += dot( vValue, inv16 );
	
	[unroll]
	for ( int i = 0; i < 4; ++i ) {
		float2 uv = poisson_disc[i + 12] * aspect / fDepthScale + iTC0;
		float4 vSample = tex2D( sDepthMapSampler, uv );
		vDepth[i] = DecodeDepth_Raw( vSample.xyz );
		vValue[i] = vSample.w;
	}
	vDepth = abs( fBaseDepth - vDepth ) / fBaseDepth - ZPERCENT_EPSILON;
	vValue = ( vDepth < 0 ) ? vValue : fBaseValue;
	fResult += dot( vValue, inv16 );
#endif

	return fResult;
}

technique Translucent
{
	pass Blur
	{
		VertexShader = compile vs_3_0 Blur_VS();
		PixelShader = compile ps_3_0 Blur_PS();
	}
}
