#ifndef __DRAWPRIMBASEDEFS_FXH__
#define __DRAWPRIMBASEDEFS_FXH__

// Our matrices are all stored in row major form, so indicate that to the compiler
#pragma pack_matrix(row_major)

//this transform goes from the input vertex space to clip space
shared float4x4 mDrawPrimToClip;

//the current texture that we are rendering primitives with
shared texture  tDrawPrimTexture;

//the samplers for our texture
sampler sDrawPrimTextureWrap = sampler_state
				{
					texture = <tDrawPrimTexture>;
					AddressU = Wrap;
					AddressV = Wrap;
					MipMapLODBias = -1.0;
					SRGBTexture	= true;
				};

float3 sRGBToLinear(float3 color)
{
	return color.rgb <= 0.04045.rrr ? color * (1.0.rrr / 12.92.rrr) : pow( (color + 0.055.rrr) * (1.0.rrr / 1.055.rrr), 2.4.rrr );
}

float4 sRGBToLinear(float4 color)
{
	return float4( sRGBToLinear(color.rgb), color.a );
}

#endif
