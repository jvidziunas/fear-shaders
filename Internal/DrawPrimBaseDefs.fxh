#ifndef __DRAWPRIMBASEDEFS_FXH__
#define __DRAWPRIMBASEDEFS_FXH__

// Our matrices are all stored in row major form, so indicate that to the compiler
#pragma pack_matrix(row_major)

//this transform goes from the input vertex space to clip space
shared float4x4 mDrawPrimToClip;

//the current texture that we are rendering primitives with
shared texture  tDrawPrimTexture;

#ifndef FORCE_NO_GAMMA_CORRECTION
#	define GAMMA_CORRECT_READ		SRGBTexture = true
#	define GAMMA_CORRECT_WRITE		sRGBWriteEnable = true
#else
#	define GAMMA_CORRECT_READ		SRGBTexture = false
#	define GAMMA_CORRECT_WRITE		sRGBWriteEnable = false
#endif

float4 LinearizeAlpha( float4 srcCol ) { return srcCol; }
float LinearizeAlpha( float srcAlpha ) { return srcAlpha; }

#define GAMMA_LINEAR_DATA			SRGBTexture = false
#define GAMMA_LINEAR_RENDERTARGET	sRGBWriteEnable = false

//the samplers for our texture
sampler sDrawPrimTextureWrap = sampler_state
				{
					texture = <tDrawPrimTexture>;
					AddressU = Wrap;
					AddressV = Wrap;
					MipMapLODBias = -1.0;
					GAMMA_CORRECT_READ;
				};

#endif
