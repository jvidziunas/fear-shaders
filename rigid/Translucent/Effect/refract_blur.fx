#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\curframemap.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
#ifndef SKELETAL_MATERIAL
	float4  Color		: COLOR0;
#endif
    float3	Normal		: NORMAL; 
    float2	TexCoord	: TEXCOORD0;
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a refraction shader that uses the normal map for a variable kernel size blur.");
DECLARE_DOCUMENATION("Shaders\\Docs\\refract_blur\\main.htm");
DECLARE_PARENT_MATERIAL(0, "refract_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fInnerRefractScale, 0.3, "Refraction scale for the central pixel");
MIPARAM_FLOAT(fOuterRefractScale, 0.03, "Refraction scale for the outer pixels");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light refracted");
MIPARAM_TEXTURE(tNormalMap, 0, 1, "", false, "Normal map of the material. This represents the normal of each point on the surface");

//the samplers for those textures
SAMPLER_WRAP(sDiffuseMapSampler, tDiffuseMap);
// Note : Normal maps should have at least trilinear filtering
sampler sNormalMapSampler = sampler_state
{
	texture = <tNormalMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	MipFilter = Linear;
};

//--------------------------------------------------------------------
// Utility functions

float3x3 GetInverseTangentSpace(MaterialVertex Vert)
{
	return GetInverseTangentSpace(	SKIN_VECTOR(Vert.Tangent, Vert), 
									SKIN_VECTOR(Vert.Binormal, Vert), 
									SKIN_VECTOR(Vert.Normal, Vert));
}

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
}

// Fetch the surface normal at a texture coordinate
float3 GetSurfaceNormal(float2 vCoord)
{
	float3 vTexture = tex2D(sNormalMapSampler, vCoord).xyz;
	return ColorToUnitVector(vTexture);
}

// Fetch the material diffuse color at a texture coordinate
float4 GetMaterialDiffuse(float2 vCoord)
{
	return tex2D(sDiffuseMapSampler, vCoord);
}

//////////////////////////////////////////////////////////////////////////////
// Ambient
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position : POSITION;
#ifndef SKELETAL_MATERIAL
	float4 Color	: COLOR0;
#endif
	float2 TexCoord : TEXCOORD0;
	float4 ScreenCoord : TEXCOORD2;
	float3 TanSpace0 : TEXCOORD3;
	float3 TanSpace1 : TEXCOORD4;
	float3 TanSpace2 : TEXCOORD5;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
#ifndef SKELETAL_MATERIAL
	OUT.Color = IN.Color;
#endif
	OUT.TexCoord = IN.TexCoord;
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	float3x3 mTangentSpace = GetInverseTangentSpace(IN);
	OUT.TanSpace0 = normalize(mul(mTangentSpace, mObjectToClip[0].xyz));
	OUT.TanSpace1 = normalize(mul(mTangentSpace, mObjectToClip[1].xyz));
	OUT.TanSpace2 = normalize(mul(mTangentSpace, mObjectToClip[2].xyz));

	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	//determine the normal at this point
	float4 vNormalMap	= tex2D(sNormalMapSampler, IN.TexCoord);
	float3 vNormal		= ColorToUnitVector(vNormalMap.xyz);
	
	float3x3 mTangentToClip;
	mTangentToClip[0] = IN.TanSpace0;
	mTangentToClip[1] = IN.TanSpace1;
	mTangentToClip[2] = IN.TanSpace2;
	
	float3 vTransformedNormal = mul(mTangentToClip, vNormal - float3(0,0,1));
	
	//determine the offset we want to use for the pixel, scale it by the alpha of the pixel and also our normal map alpha channel
#ifndef SKELETAL_MATERIAL
	float fVertAlpha = IN.Color.w * vObjectLightColor.w;
#else
	float fVertAlpha = vObjectLightColor.w;
#endif
	
	float fScale = vTransformedNormal.z * fOuterRefractScale * vNormalMap.w * fVertAlpha;
	float2 uv    = IN.ScreenCoord.xy / IN.ScreenCoord.w;
	// float2 vOffset	= vTransformedNormal.xy * float2(fScale,-fScale);
	float2 vOffset = float2( fScale, -fScale ) * refract( uv, vTransformedNormal.xy, 0.5f );

	float fMiddleScale = vTransformedNormal.z * fInnerRefractScale * vNormalMap.w * fVertAlpha;
	// float2 vMiddleOffset = vTransformedNormal.xy * float2(fMiddleScale,-fMiddleScale);
	float2 vMiddleOffset = float2( fMiddleScale, -fMiddleScale ) * refract( uv, vTransformedNormal.xy, 0.5f );
	
	// vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vMiddleOffset) * 2.0;
	// vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0.0,1.0));
	// vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0.0,-1.0));
	// vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(1.0,0.0));
	// vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(-1.0,0.0));
	
	vResult.x += tex2D( sCurFrameMapSampler, uv + vMiddleOffset * 0.9 ).x * 2.0;
	vResult.x += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  0.0,  0.9 ) ).x;
	vResult.x += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  0.0, -0.9 ) ).x;
	vResult.x += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  0.9,  0.0 ) ).x;
	vResult.x += tex2D( sCurFrameMapSampler, uv + vOffset * float2( -0.9,  0.0 ) ).x;

	vResult.y += tex2D( sCurFrameMapSampler, uv + vMiddleOffset ).y * 2.0;
	vResult.y += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  0.0,  1.0 ) ).y;
	vResult.y += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  0.0, -1.0 ) ).y;
	vResult.y += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  1.0,  0.0 ) ).y;
	vResult.y += tex2D( sCurFrameMapSampler, uv + vOffset * float2( -1.0,  0.0 ) ).y;
	
	vResult.z += tex2D( sCurFrameMapSampler, uv + vMiddleOffset * 1.1 ).z * 2.0;
	vResult.z += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  0.0,  1.1 ) ).z;
	vResult.z += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  0.0, -1.1 ) ).z;
	vResult.z += tex2D( sCurFrameMapSampler, uv + vOffset * float2(  1.1,  0.0 ) ).z;
	vResult.z += tex2D( sCurFrameMapSampler, uv + vOffset * float2( -1.1,  0.0 ) ).z;

	vResult /= 6.0;	
	
	//and now modulate that by the diffuse, which fades out based upon the alpha
	float4 vDiffuseMap = GetMaterialDiffuse(IN.TexCoord);
	vResult *= lerp(float4(1, 1, 1, 1), vDiffuseMap, vDiffuseMap.w * fVertAlpha);
	
	return vResult;
}

technique Translucent
{
	pass Draw
	{
		AlphaBlendEnable = False;
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}