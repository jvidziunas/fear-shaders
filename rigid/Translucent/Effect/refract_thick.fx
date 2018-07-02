#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\depthencode.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\curframemap.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
    float3	Normal		: NORMAL; 
    float2	TexCoord	: TEXCOORD0;
	float3	Tangent		: TANGENT;
	float3	Binormal	: BINORMAL;

	DECLARE_SKELETAL_WEIGHTS
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is a refraction shader intended for 'thick' objects, and includes chromatic separation.");
DECLARE_DOCUMENATION("Shaders\\Docs\\refract_thick\\main.htm");
DECLARE_PARENT_MATERIAL(0, "refract_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fRefractScale, 0.01, "Refraction scale");
MIPARAM_VECTOR(vChromaticSeparation, 0.9, 0.95, 1.0, "Chromatic separation per-color channel");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light refracted");
MIPARAM_TEXTURE(tNormalMap, 0, 1, "", false, "Normal map of the material. This represents the normal of each point on the surface");

//the samplers for those textures
SAMPLER_WRAP_sRGB(sDiffuseMapSampler, tDiffuseMap);
// Note : Normal maps should have at least trilinear filtering
sampler sNormalMapSampler = sampler_state
{
	texture = <tNormalMap>;
	AddressU = Wrap;
	AddressV = Wrap;
	//MipFilter = Linear;
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
	return LinearizeAlpha( tex2D(sDiffuseMapSampler, vCoord) );
}

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position		: POSITION;
	float2 TexCoord		: TEXCOORD0_centroid;
	float4 ScreenCoord	: TEXCOORD1_centroid;
	float3 TanSpace0	: TEXCOORD2_centroid;
	float3 TanSpace1	: TEXCOORD3_centroid;
	float3 TanSpace2	: TEXCOORD4_centroid;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.ScreenCoord.z = 0.25 * fScene_FarZ / OUT.ScreenCoord.z;
	float3x3 mTangentSpace = GetInverseTangentSpace(IN);
	OUT.TanSpace0 = mul(mTangentSpace, mObjectToClip[0].xyz);
	OUT.TanSpace1 = mul(mTangentSpace, mObjectToClip[1].xyz);
	OUT.TanSpace2 = mul(mTangentSpace, mObjectToClip[2].xyz);

	return OUT;
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float4 vResult = float4(0,0,0,1);

	float3 vNormal = GetSurfaceNormal(IN.TexCoord);
	
	float3x3 mTangentToClip;
	mTangentToClip[0] = IN.TanSpace0;
	mTangentToClip[1] = IN.TanSpace1;
	mTangentToClip[2] = IN.TanSpace2;
	
	float3 vTransformedNormal = normalize(mul(mTangentToClip, vNormal));
	
	float fScale = vTransformedNormal.z * IN.ScreenCoord.z * fRefractScale;
	float2 vOffset = vTransformedNormal.xy * float2(fScale,-fScale);
	
	vResult.x = tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * vChromaticSeparation.x).x;
	vResult.y = tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * vChromaticSeparation.y).y;
	vResult.z = tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * vChromaticSeparation.z).z;
	
	vResult *= GetMaterialDiffuse(IN.TexCoord);
	
	return vResult;
}

technique Translucent
{
	pass Draw
	{
		AlphaBlendEnable = False;
		GAMMA_CORRECT_WRITE;

		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}


