#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\time.fxh"
#include "..\..\..\sdk\noise.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float2	TexCoord	: TEXCOORD0;
	float4	Color		: COLOR0;
    float3	Normal		: NORMAL; 
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a full-screen bleach effect shader");
DECLARE_DOCUMENATION("Shaders\\Docs\\screeneffect\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// Important note! These parameters are going to be controlled by script commands, and these are the names it's going to
// use.  So the use of hungarian on these parameters is discouraged.
MIPARAM_FLOAT(BleachBypass, 0.2, "Bleach bypass intensity");
MIPARAM_FLOAT(BleachBypass_Bloom, 3.5, "Bleach bypass bloom, in pixels");
MIPARAM_FLOAT(BleachBypass_Threshold, 2.0, "Bleach bypass threshold boost");

// the current frame
texture tCurFrameMap;
SAMPLER_CLAMP(sCurFrameMapSampler, tCurFrameMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

float Sin_Unit(float fValue)
{
	return sin(radians(fValue * 360.0f)) * 0.5 + 0.5;
}

float Wave_Sawtooth(float fInput, float fFrequency)
{
	return frac(fInput * fFrequency);
}

float Wave_Square(float fInput, float fOff, float fOn)
{
	return fInput < 0.5 ? fOff : fOn;
}

float3 Wave_Square(float fInput, float3 fOff, float3 fOn)
{
	return fInput < 0.5 ? fOff : fOn;
}

// Turns a sawtooth wave into a triangle wave
/*   //// ->  /\/\/\/\  */
float Wave_Tri(float fInput)
{
	return (fInput < 0.5) ? (fInput * 2.0f) : ((1.0f - fInput) * 2.0f);
}

// Sawtooth wave w/ intermediate baseline value.
// Looks like this:
//   __/\__  
//         \/
// Value is "vHigh" at high peak, "vLow" at low peak, and "vBaseline" at the flat parts.
float3 ThreeValueWave(float fWave, float3 vBaseline, float3 vHigh, float3 vLow, float fPeakScale)
{
	float fTriWave = Wave_Tri(Wave_Sawtooth(fWave, 4.0));
	float fInterpolant = Wave_Square(Wave_Sawtooth(fWave, 2), 0.0, fTriWave);
	return lerp(vBaseline, Wave_Square(Wave_Sawtooth(fWave, 1), vHigh, vLow), fInterpolant * fPeakScale);
}

float Time_Scaled(float fPeriodInSeconds)
{
	return fTime * 60.0f / fPeriodInSeconds;
}

float Monochrome(float3 vColor)
{
	return dot(vColor, float3(0.3, 0.4, 0.3));
}

float3 Saturate(float3 vColor)
{
	float fMax = max(max(vColor.x, vColor.y), vColor.z);
	float3 vSaturate = vColor / fMax;
	return pow(vSaturate, BleachBypass / 2);
}

//////////////////////////////////////////////////////////////////////////////
// Main shader
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position : POSITION;
	float2 ScreenCoord : TEXCOORD0;
	float2 BloomOffsetX : TEXCOORD1;
	float2 BloomOffsetY : TEXCOORD2;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));

	// Note: This is an overlay shader, so perspective correction is not necessary
	float4 vScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord = vScreenCoord.xy / vScreenCoord.w;
	
	// Note: The preshader generator refuses to turn this into two-component constant values.
	// If this is copied through by the preshader as constants, it turns into 4 additional
	// mov instructions, which leads to not fitting the entire shader in ps_2_0.
	OUT.BloomOffsetX = float2(1.0 / vScene_ScreenRes.x, 0) * BleachBypass_Bloom;
	OUT.BloomOffsetY = float2(0, 1.0 / vScene_ScreenRes.y) * BleachBypass_Bloom;
	
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float2 vScreenPos = IN.ScreenCoord.xy;

	float3 vScreen = tex2D(sCurFrameMapSampler, vScreenPos).xyz;

	// Bleach bypass
	//*
	float fMonochromeScreen = Monochrome(vScreen);
	float fOffsetAdj = pow(fMonochromeScreen + 0.5, 4.0);
	
	float4 vThreshold;
	vThreshold.x = Monochrome(tex2D(sCurFrameMapSampler, vScreenPos + IN.BloomOffsetX * fOffsetAdj));
	vThreshold.y = Monochrome(tex2D(sCurFrameMapSampler, vScreenPos + IN.BloomOffsetY * fOffsetAdj));
	vThreshold.z = Monochrome(tex2D(sCurFrameMapSampler, vScreenPos - IN.BloomOffsetX * fOffsetAdj));
	vThreshold.w = Monochrome(tex2D(sCurFrameMapSampler, vScreenPos - IN.BloomOffsetY * fOffsetAdj));
	vThreshold = pow(vThreshold * (BleachBypass_Threshold + BleachBypass), 2.0);
	float fBlurThreshold = dot(max(vThreshold, fMonochromeScreen.xxxx), 0.25);

	float3 fTemp = lerp(fBlurThreshold, fMonochromeScreen, 0.25);
	
	float3 vBleachBypass = lerp((fTemp + 0.75) * vScreen, fTemp.xxx, saturate(fMonochromeScreen + 0.1));
	
	vBleachBypass = lerp(vScreen, vBleachBypass, saturate(BleachBypass));
	//*/
	//float3 vBleachBypass = vScreen;
	
	// Film grain
	/*
	float4 vNoise = Noise(IN.NoiseSample, 1.0, 4, 0).x;
	float fDesaturated = Monochrome(vBleachBypass);
	float3 vFilmGrain = ThreeValueWave(vNoise.w, vBleachBypass, fDesaturated * 1.25, fDesaturated * 0.75, FilmGrain);
	//*/
	float3 vFilmGrain = vBleachBypass;

	return float4(vFilmGrain, 1.0);
}

technique Translucent
{
	pass Draw
	{
		AlphaBlendEnable = True;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		sRGBWriteEnable = TRUE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

