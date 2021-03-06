#ifndef __BASEDEFS_FXH__
#define __BASEDEFS_FXH__

// Our matrices are all stored in row major form, so indicate that to the compiler
#pragma pack_matrix(row_major)

//-------------------------------------------------------------------------------
// Common structures
//
// Defines commonly used structures used by pixel and vertex shaders
//-------------------------------------------------------------------------------

// Standard output from a pixel shader, simply represents the RGBA to output
struct PSOutput
{
	float4 Color : COLOR;
};

//-------------------------------------------------------------------------------
// Definition macros
//
// Common macros useful for defining different components of a material. 
//-------------------------------------------------------------------------------

//macro used to define the vertex format. This must occur somewhere in the material
//and takes as a parameter the structure defined as the material vertex
#define	DECLARE_VERTEX_FORMAT(VertFormat)		VertFormat MaterialVertexDef

//macro used to define the parent material. This parent material provides a 
//default set of techniques that this material can use unless they are overridden. Note
//that multiple parent materials can be specified. They start out from 0 and increase. For
//Each parent, all techniques will be taken that are not already specified.
#define DECLARE_PARENT_MATERIAL(Level, Parent)	string ParentMaterial0 = Parent

//The above should really be 'string ParentMaterial##Level = Parent', but the current tools
//don't properly handle this

//macro used to define the description string that will be associated with this material
//for tools purposes
#define DECLARE_DESCRIPTION(DescStr)			string Description = DescStr

//macro used to define the documentation link that will be associated with this material
//for tools purposes. This can be either a filename relative to the resource root or a
//web link.
#define DECLARE_DOCUMENATION(DocStr)			string DocumentationLink = DocStr


//////////////////////////////////////
// Sampler macros
//
//macros to aid in the declaration of texture samplers, each one takes a name to name the
//sampler, a default texture, and possible optional parameters

//sampler that wraps in both U and V
#define SAMPLER_WRAP(SamplerName, TextureName)					\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					AddressU = Wrap;							\
					AddressV = Wrap;							\
					SRGBTexture = true;							\
				}
//sampler that wraps in both U and V, and is not color data
#define SAMPLER_WRAP_LINEAR(SamplerName, TextureName)			\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					AddressU = Wrap;							\
					AddressV = Wrap;							\
					SRGBTexture = false;						\
				}

//sampler that wraps in both U and V and uses point sampling
#define SAMPLER_WRAP_POINT(SamplerName, TextureName)			\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					AddressU = Wrap;							\
					AddressV = Wrap;							\
					MagFilter = Point;							\
					MinFilter = Point;							\
					MipFilter = Point;							\
					SRGBTexture = true;							\
				}
//sampler that wraps in both U and V and uses point sampling
#define SAMPLER_WRAP_POINT_LINEAR(SamplerName, TextureName)		\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					AddressU = Wrap;							\
					AddressV = Wrap;							\
					MagFilter = Point;							\
					MinFilter = Point;							\
					MipFilter = Point;							\
					SRGBTexture = false;						\
				}

//sampler that uses a border color of the specified color
#define SAMPLER_BORDER(SamplerName, TextureName, BColor)		\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					BorderColor = BColor;						\
					AddressU = Border;							\
					AddressV = Border;							\
					SRGBTexture = true;							\
				}
//sampler that uses a border color of the specified color
#define SAMPLER_BORDER_LINEAR(SamplerName, TextureName, BColor)		\
				sampler SamplerName = sampler_state					\
				{													\
					texture = <TextureName>;						\
					BorderColor = BColor;							\
					AddressU = Border;								\
					AddressV = Border;								\
					SRGBTexture = false;							\
				}

//sampler that clamps in both U and V
#define SAMPLER_CLAMP(SamplerName, TextureName)					\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					AddressU = Clamp;							\
					AddressV = Clamp;							\
					SRGBTexture = true;							\
				}
//sampler that clamps in both U and V
#define SAMPLER_CLAMP_LINEAR(SamplerName, TextureName)			\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					AddressU = Clamp;							\
					AddressV = Clamp;							\
					SRGBTexture = false;						\
				}

//sampler that clamps in both U and V and uses point sampling
#define SAMPLER_CLAMP_POINT(SamplerName, TextureName)			\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					AddressU = Clamp;							\
					AddressV = Clamp;							\
					MagFilter = Point;							\
					MinFilter = Point;							\
					MipFilter = Point;							\
					SRGBTexture = true;							\
				}
//sampler that clamps in both U and V and uses point sampling
#define SAMPLER_CLAMP_POINT_LINEAR(SamplerName, TextureName)	\
				sampler SamplerName = sampler_state				\
				{												\
					texture = <TextureName>;					\
					AddressU = Clamp;							\
					AddressV = Clamp;							\
					MagFilter = Point;							\
					MinFilter = Point;							\
					MipFilter = Point;							\
					SRGBTexture = false;						\
				}

//////////////////////////////////////
// Material Instance Parameters
//
// Provides utility macros for defining different types of variables for
// material instances

#define MIPARAM_TEXTURE(Name, MappingNum, TextureLayerNum, Def, Preview, Desc) \
				texture Name < bool InstanceParam = true; int Mapping = MappingNum; int TextureLayer = TextureLayerNum; string Default = Def; bool PreviewTexture = Preview; string Description = Desc;>

#define MIPARAM_INT(Name, Def, Desc) \
				int		Name < bool InstanceParam = true; int Default = Def; string Description = Desc; > = Def

#define MIPARAM_BOOL(Name, Def, Desc) \
				bool	Name < bool InstanceParam = true; bool Default = Def; string Description = Desc; > = Def

#define MIPARAM_FLOAT(Name, Def, Desc) \
				float	Name < bool InstanceParam = true; float Default = Def; string Description = Desc; > = Def
				
#define MIPARAM_VECTOR(Name, DefX, DefY, DefZ, Desc) \
				float3	Name < bool InstanceParam = true; float3 Default = { DefX, DefY, DefZ }; string Description = Desc; > = float3(DefX, DefY, DefZ)

#define MIPARAM_VECTOR4(Name, DefX, DefY, DefZ, DefW, Desc) \
				float4	Name < bool InstanceParam = true; float4 Default = { DefX, DefY, DefZ, DefW }; string Description = Desc; > = float4(DefX, DefY, DefZ, DefW)

#define MIPARAM_MATRIX4X4(Name, Desc) \
				float4x4 Name < bool InstanceParam = true; string Description = Desc; >
				
//////////////////////////////////////
// Standard Parameters
//
// Provides the definition for standard parameters that are found in nearly all materials

//defines the surface flags parameter which is used by the world packer to extract surface information
//and apply it to the world. The shader itself should should not use this information
#define MIPARAM_SURFACEFLAGS	\
				int   SurfaceFlags  < bool InstanceParam = true; bool UseAtRuntime = false; int Default = 0; string Description = "Indicates the surface flags that will be applied to the world to determine certain behavior such as footstep sounds and impact effects"; > = 0; \
				float DefaultWidth  < bool InstanceParam = true; bool UseAtRuntime = false; int Default = 100; string Description = "Indicates the default number of units that this material should be stretched horizontally in tools"; > = 100; \
				float DefaultHeight < bool InstanceParam = true; bool UseAtRuntime = false; int Default = 100; string Description = "Indicates the default number of units that this material should be stretched vertically in tools"; > = 100; 


//-------------------------------------------------------------------------------
// Binding parameters
//
// These are the standard binding parameters provided by the renderer for use
// inside of materials 
//-------------------------------------------------------------------------------

//-------------------------------------------------------------------------------
// Vector to color space conversion
//
// Handles conversion too and from color space given for a unit length vector.
// It is assumed that the range of each component is [-1..1] for the vector and
// [0..1] for the colors.  
//-------------------------------------------------------------------------------

// Convert from the color range [0,1] to unit vector range [-1,1] 
#pragma warning (disable:4707) // Yes, we know texture coords get clamped in ps 1.1...
float  ColorToUnitVector(float fValue)  { return (fValue * 2) - 1; }
float2 ColorToUnitVector(float2 vValue) { return (vValue * 2) - 1; }
float3 ColorToUnitVector(float3 vValue) { return (vValue * 2) - 1; }
float4 ColorToUnitVector(float4 vValue) { return (vValue * 2) - 1; }
#pragma warning (enable:4707)

// Convert from the unit vector range [-1,1] to color range [0,1] 
float  UnitVectorToColor(float fValue)  { return (fValue * 0.5) + 0.5; }
float2 UnitVectorToColor(float2 vValue) { return (vValue * 0.5) + 0.5; }
float3 UnitVectorToColor(float3 vValue) { return (vValue * 0.5) + 0.5; }
float4 UnitVectorToColor(float4 vValue) { return (vValue * 0.5) + 0.5; }

//-------------------------------------------------------------------------------
// Inverse tangent space calculation
//
// Gets the inverse tangent-space matrix for a vertex given the provided basis
// vectors.
//-------------------------------------------------------------------------------
float3x3 GetInverseTangentSpace(float3 vTangent, float3 vBinormal, float3 vNormal)
{
	float3x3 mResult;
	mResult[0] = vTangent;
	mResult[1] = vBinormal;
	mResult[2] = vNormal;
	return mResult;
}

float3 sRGBToLinear(float3 color)
{
	return color.rgb <= 0.04045.rrr ? color * (1.0.rrr / 12.92.rrr) : pow( (color + 0.055.rrr) * (1.0.rrr / 1.055.rrr), 2.4.rrr );
}

float4 sRGBToLinear(float4 color)
{
	return float4( sRGBToLinear(color.rgb), color.a );
}

#endif
