#include "..\..\sdk\basedefs.fxh"
#include "..\..\sdk\skeletal.fxh"
#include "..\..\sdk\transforms.fxh"
#include "..\..\sdk\dx9lights.fxh"
#include "..\..\sdk\screencoords.fxh"
#include "..\..\sdk\depthencode.fxh"
#include "..\..\sdk\time.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float3	Normal	: NORMAL; 
    float2	TexCoord	: TEXCOORD0;
	float3	Tangent	: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a version of specular_mirror specifically suited for use on the river.");
DECLARE_DOCUMENATION("Shaders\\Docs\\specular_env\\main.htm");
DECLARE_PARENT_MATERIAL(0, "river_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map. The color channels discolor the water, and the alpha channel desaturates.");
MIPARAM_TEXTURE(tNormalMap, 0, 1, "", false, "Normal map.");
MIPARAM_TEXTURE(tWaveMap, 0, 2, "", false, "Wave map.  This is a normal map that is used to animate the normal map.");
MIPARAM_TEXTURE(tReflectionMap, 0, 3, "", false, "Reflection map parameter. Set the material parameter for the render target to this parameter.");
MIPARAM_TEXTURE(tRoughnessMap, 0, 4, "", false, "Roughness map. Areas where the red channel are 1 will be rough, 0 will be calm.");
MIPARAM_FLOAT(fReflectionBumpScale, 1.25, "The amount the reflection map will be distorted by the normal map.");
MIPARAM_FLOAT(fNormalMapScale, 2.5, "Size of the normal map on the final geometry, relative to the world.");
MIPARAM_FLOAT(fNoise1Frequency, 1.0, "Noise octave #1 Frequency.");
MIPARAM_FLOAT(fNoise1Amplitude, 1.0, "Noise octave #1 Amplitude.");
MIPARAM_FLOAT(fNoise1Speed, 50.0, "Noise octave #1 Speed.");
MIPARAM_FLOAT(fNoise2Frequency, 1.0, "Noise octave #2 Frequency.");
MIPARAM_FLOAT(fNoise2Amplitude, 1.0, "Noise octave #2 Amplitude.");
MIPARAM_FLOAT(fNoise2Speed, 50.0, "Noise octave #2 Speed.");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);
sampler sWaveMapSampler = sampler_state
{
	texture = <tWaveMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	MagFilter = Linear;
	MipFilter = Linear;
};

// Note : Normal maps should have at least trilinear filtering
sampler sNormalMapSampler = sampler_state
{
	texture = <tNormalMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	MagFilter = Linear;
	MipFilter = Linear;
};
SAMPLER_CLAMP_sRGB(sReflectionMapSampler, tReflectionMap);
SAMPLER_WRAP(sRoughnessMapSampler, tRoughnessMap);

//--------------------------------------------------------------------
// Utility functions

float3x3 GetInverseTangentSpace()
{
	return float3x3( float3(1,0,0),
					float3(0,0,1),
					float3(0,1,0) );
}

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

float2 GetSurfaceNormal_Offset(float2 vCoord, float fOffsetCoordScale, float fOffsetScale, float fTimeScale)
{
	float2 vOffset = tex2D(sWaveMapSampler, vCoord * fOffsetCoordScale + float2(0, fTime * fTimeScale)).xy - 0.5;
	vOffset += tex2D(sWaveMapSampler, vCoord * fOffsetCoordScale + float2(fTime * fTimeScale, 0)).xy - 0.5;
	return vOffset * fOffsetScale;
}

float3 GetSurfaceNormal_Unit(float2 vCoord)
{
	return NormalExpand(tex2D(sNormalMapSampler, vCoord).xyz);
}

float4 GetMaterialDiffuse(float2 vCoord)
{
	return tex2D(sDiffuseMapSampler, vCoord);
}

float2 GetMirrorOffset(float3 vEyeVector, float3 vSurfaceNormal, float3 vTangent0, float3 vTangent1)
{
	float2x3 mTanSpace;
	mTanSpace[0] = vTangent0;
	mTanSpace[1] = vTangent1;
	float3 vUnitEye = normalize(vEyeVector / vEyeVector.z);
	/* Math of this reflection code : 
		Reflection = V + 2N*N.V.  
		P = (0,0,1)
		Offset = V + 2N*N.V - (V + 2P*P.V) =
				 2N*N.V - 2P*P.V =
				 2(N*N.V - (0,0,V.z))
				 ^--- Removed, as this can be folded into the fReflectionBumpScale parameter
	*/
	float3 vReflectionVector = vSurfaceNormal * dot(vUnitEye, vSurfaceNormal) - float3(0.0, 0.0, vUnitEye.z);
	float2 vOffset = mul(mTanSpace, vReflectionVector);
	return vOffset.xy * fReflectionBumpScale;
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMirror(float2 vScreenCoord)
{
	return tex2D(sReflectionMapSampler, vScreenCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Ambient 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0_centroid;
	float2 NormalCoord	: TEXCOORD1_centroid;
	float4 ScreenCoord	: TEXCOORD2_centroid;
	float3 ObjEyeVector	: TEXCOORD3_centroid;
	float3 Tangent0		: TEXCOORD4_centroid;
	float3 Tangent1		: TEXCOORD5_centroid;
};

PSData_Ambient Ambient_VS(MaterialVertex IN)
{
	PSData_Ambient OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	OUT.NormalCoord = GetPosition(IN).xz * (fNormalMapScale / 50000);

	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.x = OUT.ScreenCoord.w - OUT.ScreenCoord.x;
	OUT.ObjEyeVector = GetPosition(IN) - vObjectSpaceEyePos;
	OUT.ObjEyeVector = OUT.ObjEyeVector.xzy;

	OUT.Tangent0 = mObjectToClip[0].xzy;
	OUT.Tangent1 = mObjectToClip[1].xzy;

	return OUT;
}

float4 Ambient_PS(PSData_Ambient IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	float3 vTanSpace0 = IN.Tangent0;
	float3 vTanSpace1 = IN.Tangent1;
	
	float4 vDiffuse = GetMaterialDiffuse(IN.TexCoord);
	float fRoughness = tex2D(sRoughnessMapSampler, IN.TexCoord).x;

	float2 vNormalOffset = GetSurfaceNormal_Offset(IN.NormalCoord, 2.0 * fNoise1Frequency, 0.13 * fNoise1Amplitude, fNoise1Speed);
	vNormalOffset += GetSurfaceNormal_Offset(IN.NormalCoord, -31.415 * fNoise2Frequency, 0.07 * fNoise2Amplitude, fNoise2Speed);
	IN.NormalCoord += vNormalOffset;
	
	float3 vSurfaceNormal = GetSurfaceNormal_Unit(IN.NormalCoord);
	float2 vMirrorOffset = GetMirrorOffset(IN.ObjEyeVector, vSurfaceNormal, vTanSpace0, vTanSpace1);
	vMirrorOffset *= fRoughness.xx;
	float2 vReflectionCoord = IN.ScreenCoord.xy / IN.ScreenCoord.w + vMirrorOffset;
	float4 vReflection = GetMirror(vReflectionCoord);
	// Takes extra samples along the reflection offset, which leads to stretched light sources
	/*
	vMirrorOffset.y = -abs(vMirrorOffset.y);
	float2 vAdj = normalize(vMirrorOffset) * float2(1.0/800.0, 1.0/600.0);
	vReflection = max(vReflection, GetMirror(vReflectionCoord + vAdj * 8.0));
	vReflection = max(vReflection, GetMirror(vReflectionCoord + vAdj * 16.0));
	vReflection = max(vReflection, GetMirror(vReflectionCoord + vAdj * 24.0));
	vReflection = max(vReflection, GetMirror(vReflectionCoord + vAdj * 32.0));
	vReflection = max(vReflection, GetMirror(vReflectionCoord + vAdj * 40.0));
	vReflection = max(vReflection, GetMirror(vReflectionCoord + vAdj * 48.0));
	//*/

	vResult.xyz = lerp(dot(vReflection.xyz, float3(0.3,0.4,0.3)).xxx, vReflection.xyz, vDiffuse.w);
	vResult.xyz *= vDiffuse.xyz;
	
	return vResult;
}

technique Ambient
{
	pass Draw
	{
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Ambient_VS();
		PixelShader = compile ps_3_0 Ambient_PS();
	}
}

// Depth encoding support
ENCODE_DEPTH_DEFAULT(MaterialVertex)
