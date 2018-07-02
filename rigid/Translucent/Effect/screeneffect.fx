#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\time.fxh"
#include "..\..\..\sdk\noise.fxh"
#include "..\..\..\sdk\curframemap.fxh"

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
DECLARE_DESCRIPTION("This is the full-screen effect shader for FEAR, and is only intended for use in OverlayFX");
DECLARE_DOCUMENATION("Shaders\\Docs\\screeneffect\\main.htm");
DECLARE_PARENT_MATERIAL(0, "screeneffect_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// Important note! These parameters are going to be controlled by script commands, and these are the names it's going to
// use.  So the use of hungarian on these parameters is discouraged.
MIPARAM_FLOAT(Intensity, 1.0, "Final effect intensity");
MIPARAM_FLOAT(Sharpen, 1.0, "Sharpen filter kernel size, in pixels");
MIPARAM_FLOAT(RadialBlur, 1.0, "Radial blur scale (arbitrary value)");
MIPARAM_FLOAT(Gradient, 1.0, "Radial blur/sharpen interpolation scale");
MIPARAM_FLOAT(ColorIntensity, 1.0, "Color intensity scale");

// Number of samples performed as part of the radial blur
#define NUM_RADIAL_BLUR_SAMPLES 16 
// Radius of the radial blur
#define RADIAL_BLUR_RADIUS 64
// Offset of the radial blur per sample
#define RADIAL_BLUR_OFFSET (RADIAL_BLUR_RADIUS / NUM_RADIAL_BLUR_SAMPLES)
// Brightness of the sharpening effect
#define SHARPEN_BRIGHTNESS 0.96

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

//////////////////////////////////////////////////////////////////////////////
// Main shader
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position		: POSITION;
	float2 ScreenCoord	: TEXCOORD0_centroid;
	float2 BlurOffsetX	: TEXCOORD1_centroid;
	float2 BlurOffsetY	: TEXCOORD2_centroid;
	float2 RadialScale	: TEXCOORD3;
	float4 Color		: TEXCOORD4;
	float4 InvColor		: TEXCOORD5;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));

	// Note: This is an overlay shader, so perspective correction is not necessary
	float4 vScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord = vScreenCoord.xy / vScreenCoord.w;

	// General note:
	// This shader is mostly for passing calculated constants down to the pixel shader,
	// since the preshader doesn't handle vector constants very well.  (The color's
	// actually even a constant as well, it's just passed in the vertex stream
	// instead of the constant table...)
		
	OUT.BlurOffsetX = float2(Sharpen * Intensity / vScene_ScreenRes.x, 0);
	OUT.BlurOffsetY = float2(0, Sharpen * Intensity / vScene_ScreenRes.x);
	OUT.BlurOffsetX.y += OUT.BlurOffsetY.y * 0.5;
	OUT.BlurOffsetY.x += OUT.BlurOffsetX.x * 0.5;
	
	// Note: Not using screen resolution, since this controls the distance in screen space
	// of the radial blur effect.  Using resolution for this would make the radial blur
	// less pronounced at lower resolutions.
	OUT.RadialScale = float2(4.0/800, 4.0/600) * RadialBlur * Intensity;

	OUT.Color = IN.Color * ColorIntensity;
	OUT.InvColor = lerp(1.0.xxxx, float4(1.0 / OUT.Color.xyz, OUT.Color.w), Intensity);
	
	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float2 vScreenPos = IN.ScreenCoord.xy;

	float4 vScreen = tex2D(sCurFrameMapSampler, vScreenPos);
	
	// Radial blur filter
	float2 vScreenOffset = vScreenPos * 2.0 - 1.0;
	float fRadiality = length(vScreenOffset);
	float2 vRadialOffset = vScreenOffset * IN.RadialScale * fRadiality;
	float4 vRadialBlur = vScreen;
	for (int loop = 0; loop < NUM_RADIAL_BLUR_SAMPLES; ++loop)
	{
		vRadialBlur += tex2D(sCurFrameMapSampler, vScreenPos - vRadialOffset * (float)loop) * (float)loop;
	}
	vRadialBlur /= (NUM_RADIAL_BLUR_SAMPLES * (NUM_RADIAL_BLUR_SAMPLES + 1)) / 2 + 1;
	// Discoloration
	vRadialBlur.xyz *= IN.Color;
	
	// Sharpen filter
	float4 vSharpen = vScreen * lerp(5.0, 5.0 * SHARPEN_BRIGHTNESS, Intensity);
	vSharpen -= tex2D(sCurFrameMapSampler, vScreenPos + IN.BlurOffsetY);
	vSharpen -= tex2D(sCurFrameMapSampler, vScreenPos + IN.BlurOffsetX);
	vSharpen -= tex2D(sCurFrameMapSampler, vScreenPos - IN.BlurOffsetY);
	vSharpen -= tex2D(sCurFrameMapSampler, vScreenPos - IN.BlurOffsetX);
	// Inverse discoloration
	vSharpen *= IN.InvColor;
	
	// Blend between the two
	return LinearizeAlpha( lerp(vSharpen, vRadialBlur, fRadiality * Gradient * Intensity) );
}

technique Translucent <
		string Low = "screeneffect_dx8.fxi";
	>
{
	pass Draw
	{
		AlphaBlendEnable = True;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

