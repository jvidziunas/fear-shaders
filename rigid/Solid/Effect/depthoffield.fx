#include "..\..\..\sdk\basedefs.fxh"
#include "..\..\..\sdk\skeletal.fxh"
#include "..\..\..\sdk\screencoords.fxh"
#include "..\..\..\sdk\depthencode.fxh"
#include "..\..\..\sdk\transforms.fxh"
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
DECLARE_DESCRIPTION("This is the depth of field shader.");
DECLARE_DOCUMENATION("Shaders\\Docs\\depthoffield\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// The specular power range of the material
MIPARAM_FLOAT(fMaxKernelSize, 4.0, "Maximum blur kernel size");
MIPARAM_FLOAT(fBlurStart, 100.0, "Starting blur distance, in world units");
MIPARAM_FLOAT(fBlurEnd, 1000.0, "Maximum blur distance, in world units");
// the textures exported for the user
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light refracted");

//the samplers for those textures
SAMPLER_WRAP(sDiffuseMapSampler, tDiffuseMap);

//--------------------------------------------------------------------
// Utility functions

float3 GetPosition(MaterialVertex Vert)
{
	return SKIN_POINT(Vert.Position, Vert);
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
	float2 TexCoord : TEXCOORD0;
	float2 DepthConstants : TEXCOORD1;
	float4 ScreenCoord : TEXCOORD2;
};

PSData_Translucent Translucent_VS(MaterialVertex IN)
{
	PSData_Translucent OUT;
	OUT.Position = TransformToClipSpace(GetPosition(IN));
	OUT.TexCoord = IN.TexCoord;
	OUT.ScreenCoord = GetScreenTexCoords(OUT.Position);
	OUT.DepthConstants.x = fBlurStart / fScene_FarZ;
	OUT.DepthConstants.y = fScene_FarZ / (fBlurEnd - fBlurStart);

	return OUT;
}

float2 ApplyDOF(float fDepth, float2 vDepthConstants)
{
	return fMaxKernelSize / vScene_ScreenRes * saturate((fDepth - vDepthConstants.x) * vDepthConstants.y);
}

float4 Translucent_PS(PSData_Translucent IN) : COLOR
{
	float4 vResult = float4(0,0,0,0);

	float fDepth = DecodeDepth(tex2Dproj(sDepthMapSampler, IN.ScreenCoord));
	
	float2 vOffset = ApplyDOF(fDepth, IN.DepthConstants);
	
	float fDepth0 = DecodeDepth(tex2D(sDepthMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0,1)));
	float fDepth1 = DecodeDepth(tex2D(sDepthMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(0,-1)));
	float fDepth2 = DecodeDepth(tex2D(sDepthMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(1,0)));
	float fDepth3 = DecodeDepth(tex2D(sDepthMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset * float2(-1,0)));
	
	float2 vOffset0 = ApplyDOF(fDepth0, IN.DepthConstants);
	float2 vOffset1 = ApplyDOF(fDepth1, IN.DepthConstants);
	float2 vOffset2 = ApplyDOF(fDepth2, IN.DepthConstants);
	float2 vOffset3 = ApplyDOF(fDepth3, IN.DepthConstants);
	
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset0 * float2(0,1));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset1 * float2(0,-1));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset2 * float2(1,0));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + vOffset3 * float2(-1,0));

	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + (vOffset0 + vOffset2) / 2.0 * float2(0.707,0.707));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + (vOffset2 + vOffset1) / 2.0 * float2(0.707,-0.707));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + (vOffset3 + vOffset0) / 2.0 * float2(-0.707,0.707));
	vResult += tex2D(sCurFrameMapSampler, IN.ScreenCoord.xy / IN.ScreenCoord.w + (vOffset3 + vOffset1) / 2.0 * float2(-0.707,-0.707));

	vResult /= 8.0;	

	vResult *= GetMaterialDiffuse(IN.TexCoord);
	
	return vResult;
}

technique FogVolume_Blend
{
	pass Draw
	{
		AlphaBlendEnable = False;
		ZEnable = True;
		ZFunc = LessEqual;
		ZWriteEnable = False;
		sRGBWriteEnable = TRUE;
		
		VertexShader = compile vs_3_0 Translucent_VS();
		PixelShader = compile ps_3_0 Translucent_PS();
	}
}

