// This is an empty shader designed for the explicit purpose of making worldmodels without any geometry in them
#include "..\sdk\basedefs.fxh"

//--------------------------------------------------------------------
// Input/output formats

// Represents a single input vertex that will be fed into each vertex shader
struct MaterialVertex
{
    float3	Position	: POSITION;
};
DECLARE_VERTEX_FORMAT(MaterialVertex);
DECLARE_DESCRIPTION("This is the null material.  It does not perform any rendering.");
DECLARE_DOCUMENATION("Shaders\\Docs\\null\\main.htm");

//--------------------------------------------------------------------
// Material parameters

MIPARAM_SURFACEFLAGS;
// the textures exported for the user
MIPARAM_TEXTURE(tDEditMap, 0, 0, "", true, "Representative texture map for viewing in DEdit.");

technique Stub
{
}

