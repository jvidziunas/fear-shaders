//-----------------------------------------------------------------
// DepthEncode.fxh
//
// Provides variables and functions used for encoding/decoding depth values
//-----------------------------------------------------------------

#ifndef __DEPTHENCODE_FXH__
#define __DEPTHENCODE_FXH__

#include "basedefs.fxh"

// Depth map 
// RGB = depth.  A = stencil
shared texture tDepthMap;
SAMPLER_CLAMP_POINT_LINEAR(sDepthMapSampler, tDepthMap);

// Encoding map for depth values (rg)
shared texture tDepth_EncodeMapRG;
SAMPLER_WRAP_POINT_LINEAR(sDepth_EncodeMapRGSampler, tDepth_EncodeMapRG);

// Encoding map for depth values (ba)
shared texture tDepth_EncodeMapBA;
SAMPLER_WRAP_POINT_LINEAR(sDepth_EncodeMapBASampler, tDepth_EncodeMapBA);

// Scene description values
shared float fScene_FarZ;

//-------------------------------------------------------------------------------
// Depth encoding support functions
//-------------------------------------------------------------------------------

// Overlap to the scale to allow the Z-values to range from 0..FarZ * FARZ_OVERLAP
// This prevents wrapping issues with the encoding textures when dealing with scenes
// that don't fit entirely within their FarZ.
#define FARZ_OVERLAP (4.0)

// Convert a world-space-Z into encode-space Z
float AdjustZ(float fZ)
{
	return fZ / (fScene_FarZ * FARZ_OVERLAP);
}

// Convert a encode-space-Z into world-space Z
float UnAdjustZ(float fAdjustedZ)
{
	return fAdjustedZ * (fScene_FarZ * FARZ_OVERLAP);
}

// Encodes a depth value as 2 sets of texture coords
void GetDepthEncodeCoords(float fClipZ, out float2 vCoordRG : TEXCOORD0, out float2 vCoordBA : TEXCOORD1)
{
	float fSceneZ = AdjustZ(fClipZ);
	vCoordRG = float2(fSceneZ, fSceneZ * 256.0);
	vCoordBA = float2(fSceneZ * 65536.0, 0.5);
}

// Converts 2 sets of pre-encoded texture coords to an encoded RGB depth value
float4 EncodeDepth(float2 vCoordRG : TEXCOORD0, float2 vCoordBA : TEXCOORD1) : COLOR
{
	return tex2D(sDepth_EncodeMapRGSampler, vCoordRG) + tex2D(sDepth_EncodeMapBASampler, vCoordBA);
}

// Decodes a depth encoded RGB value w/out Z adjustments.  (Returned values are not in world space!)
float DecodeDepth_Raw(float3 vValue)
{
	return dot(vValue, float3(1.0, 1/256.0, 1.0/65536.0));
}

// Decodes a depth encoded RGB value
float DecodeDepth(float3 vValue)
{
	return UnAdjustZ(DecodeDepth_Raw(vValue));
}


// Internal macro for the default depth encoding -- VS->PS data structure
#define ENCODE_DEPTH_DEFAULT_PSDATA													\
	struct PSData_Encode_Depth_Default												\
	{																				\
		float4 Position : POSITION;													\
		float2 DepthRG : TEXCOORD0;													\
		float2 DepthBA : TEXCOORD1;													\
	};																				

// Internal macro for the default depth encoding -- VS function
#define ENCODE_DEPTH_DEFAULT_VS(VertexStruct)										\
	PSData_Encode_Depth_Default Encode_Depth_Default_VS(VertexStruct IN)			\
	{																				\
		PSData_Encode_Depth_Default OUT;											\
		OUT.Position = TransformToClipSpace(GetPosition(IN));						\
		GetDepthEncodeCoords(OUT.Position.z, OUT.DepthRG, OUT.DepthBA);				\
																					\
		return OUT;																	\
	}

// Internal macro for the default depth encoding -- Technique definition for DX9
#define ENCODE_DEPTH_DEFAULT_DX9_TECHNIQUE											\
	technique FogVolume_Depth														\
	{																				\
		pass Draw																	\
		{																			\
			VertexShader = compile vs_3_0 Encode_Depth_Default_VS();				\
			PixelShader = compile ps_3_0 EncodeDepth();								\
			sRGBWriteEnable = FALSE;												\
		}																			\
	}

// Internal macro for the default depth encoding -- Technique definition for DX8
#define ENCODE_DEPTH_DEFAULT_DX8_TECHNIQUE											\
	technique FogVolume_Depth														\
	{																				\
		pass Draw																	\
		{																			\
			VertexShader = compile vs_3_0 Encode_Depth_Default_VS();				\
			PixelShader = compile ps_3_0 EncodeDepth();								\
			sRGBWriteEnable = FALSE;												\
		}																			\
	}

// Default depth encoding
// Note : Uses DX9 to avoid issues with fixed-precision implementations of ps_1_1
#define ENCODE_DEPTH_DEFAULT(VertexStruct)	\
	ENCODE_DEPTH_DEFAULT_PSDATA				\
	ENCODE_DEPTH_DEFAULT_VS(VertexStruct)	\
	ENCODE_DEPTH_DEFAULT_DX9_TECHNIQUE

// DX8 depth encoding
#define ENCODE_DEPTH_DX8(VertexStruct)		\
	ENCODE_DEPTH_DEFAULT_PSDATA				\
	ENCODE_DEPTH_DEFAULT_VS(VertexStruct)	\
	ENCODE_DEPTH_DEFAULT_DX8_TECHNIQUE

#endif
