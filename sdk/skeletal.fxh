//-----------------------------------------------------------------------------------
// Skeletal.fxh
//
// Provides macros to allow for setting up shaders to be conditionally compiled for
// either rigid or skeletal shaders. In order to do this, add DECLARE_SKELETAL_WEIGHTS
// to the vertex declaration, and then whenever a vertex point or vector is used, use
// the macro SKIN_POINT or SKIN_VECTOR to get the skinned version.
//-----------------------------------------------------------------------------------

#ifndef __SKELETAL_FXH__
#define __SKELETAL_FXH__

//if we are compiling for skeletal animation we also want to include the skeletal header
//and definitions
#ifdef SKELETAL_MATERIAL

	#define SKELETAL_INDEX_COLOR
	
	// When defined, SKELETAL_INDEX_COLOR indicates that the shaders should use D3DCOLOR input instead of UBYTE4 input
	#ifdef SKELETAL_INDEX_COLOR
		#define SKELETAL_INDEX_TYPE float4
		#define SKELETAL_INDEX_CONVERT(a) D3DCOLORtoUBYTE4(a)
	#else
		#define SKELETAL_INDEX_TYPE int4
		#define SKELETAL_INDEX_CONVERT(a) (a)
	#endif
	
	//-------------------------------------------------------------------------------
	// Skeletal Binding parameters
	//
	// These are the standard binding parameters provided by the renderer for use
	// inside of materials 
	//-------------------------------------------------------------------------------

	//The bone transforms affecting the current mesh being rendered
	shared float3x4 mModelObjectNodes[24];

	//-------------------------------------------------------------------------------
	// Skinning Functions
	//
	// Utility functions that handle taking in different objects and skinning them
	// based upon the provided weights
	//-------------------------------------------------------------------------------

	//transforms a position based upon the blend weights specified
	float3 SkinPoint(float3 vPosition, float4 vWeight, int4 vIndices)
	{
		return	mul(mModelObjectNodes[vIndices.x], float4(vPosition, 1)) * vWeight.x +
				mul(mModelObjectNodes[vIndices.y], float4(vPosition, 1)) * vWeight.y +
				mul(mModelObjectNodes[vIndices.z], float4(vPosition, 1)) * vWeight.z;
	}

	float4 SkinPoint(float4 vPosition, float4 vWeight, int4 vIndices)
	{
		return	
			float4(
				mul(mModelObjectNodes[vIndices.x], vPosition) * vWeight.x +
				mul(mModelObjectNodes[vIndices.y], vPosition) * vWeight.y +
				mul(mModelObjectNodes[vIndices.z], vPosition) * vWeight.z, 1.0);
	}

	//transforms a vector using the fact that as long as there is no scaling, a vector
	//can be transformed by simply treating it as a homogenous coordinate with W=0
	float3 SkinVector(float3 vVector, float4 vWeight, int4 vIndices)
	{
		return	mul((float3x3)mModelObjectNodes[vIndices.x], vVector).xyz * vWeight.x +
				mul((float3x3)mModelObjectNodes[vIndices.y], vVector).xyz * vWeight.y +
				mul((float3x3)mModelObjectNodes[vIndices.z], vVector).xyz * vWeight.z;
	}

	//we are building a skeletal material, create our macros for skeletal animation
	//note : BlendIndex should be changed to int4 and packed with UBYTE4 as soon as we can drop DX8 hardware support
	#define	DECLARE_SKELETAL_WEIGHTS	float4	BlendWeight	: BLENDWEIGHT;  \
										SKELETAL_INDEX_TYPE	BlendIndex : BLENDINDICES;
	#define	SKIN_POINT(Point, Vert)		SkinPoint(Point, Vert.BlendWeight, SKELETAL_INDEX_CONVERT(Vert.BlendIndex))
	#define SKIN_VECTOR(Vector, Vert)	SkinVector(Vector, Vert.BlendWeight, SKELETAL_INDEX_CONVERT(Vert.BlendIndex))

#else

	//we aren't supporting skeletal animation, so stub out the skeletal macros
	#define	DECLARE_SKELETAL_WEIGHTS			
	#define	SKIN_POINT(Point, Vert)		(Point)
	#define SKIN_VECTOR(Vector, Vert)	(Vector)

#endif


#endif //__SKELETAL_FXH__
