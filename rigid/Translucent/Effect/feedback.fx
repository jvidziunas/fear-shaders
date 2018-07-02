#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\transforms.fxh"
#include "..\..\..\sdk\lightdefs.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\depthencode.fxh"
#include "..\..\..\sdk\lastframemap.fxh"

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
DECLARE_DESCRIPTION("This is the feedback material, which simulates the effect of a video feedback loop for objects behind the material.  This material will fall back to the refract material on DX8 hardware.");
DECLARE_DOCUMENATION("Shaders\\Docs\\feedback\\main.htm");
DECLARE_PARENT_MATERIAL(0, "refract_dx8.fxi");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fFeedbackScale, 0.01, "Feedback scale");
// the textures exported for the user
MIPARAM_TEXTURE(tNormalMap, 0, 0, "", true, "Normal map of the material. This represents the normal of each point on the surface");

//the samplers for those textures
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

//////////////////////////////////////////////////////////////////////////////
// Translucent
//////////////////////////////////////////////////////////////////////////////

struct PSData_Translucent 
{
	float4 Position : POSITION;
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
	OUT.TexCoord = IN.TexCoord;
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
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
	
	float fScale = -vTransformedNormal.z * fFeedbackScale;
	vResult = tex2D(sLastFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vTransformedNormal.xy * float2(fScale,-fScale));
	
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

// Depth encoding support
ENCODE_DEPTH_DEFAULT(MaterialVertex)
