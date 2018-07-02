#include "..\..\sdk\basedefs.fxh"

// We have to define the full parameter set to make sure they can be bound by the material instance parameters
MIPARAM_FLOAT(fFogDepth, 50, "Fog depth");
MIPARAM_FLOAT(fFogBias, 0.6, "Fog bias");
MIPARAM_FLOAT(fReflectScale, 0.2, "Reflection scale");
MIPARAM_TEXTURE(tDiffuseMap, 0, 0, "", true, "Diffuse map of the material. This represents the color of the light refracted");
MIPARAM_TEXTURE(tNormalMap, 0, 1, "", false, "Normal map of the material. This represents the normal of each point on the surface");
MIPARAM_TEXTURE(tReflectionMap, 0, 2, "", false, "Reflection map of the material. This is a cube map representing the reflected environment.");
MIPARAM_TEXTURE(tFresnelTable, 0, 3, "", false, "Fresnel look-up table. This is used to determine the amount of reflection to apply based on the viewing angle.");
MIPARAM_TEXTURE(tWaveMap, 0, 4, "", false, "Wave map");
MIPARAM_FLOAT(fDiffuseWaveScale, 10.0, "Diffuse wave scale");
MIPARAM_VECTOR(vReflectionPlane, 0,1,0, "Reflection plane in object space");
MIPARAM_VECTOR(vFogColor, 0.095, 0.07, 0.01, "Fog color");
MIPARAM_FLOAT(fNoise1Frequency, 1.0, "Noise octave #1 Frequency.");
MIPARAM_FLOAT(fNoise1Amplitude, 1.4, "Noise octave #1 Amplitude.");
MIPARAM_FLOAT(fNoise1Speed, 0.3, "Noise octave #1 Speed.");
MIPARAM_FLOAT(fNoise2Frequency, 1.0, "Noise octave #2 Frequency.");
MIPARAM_FLOAT(fNoise2Amplitude, 1.0, "Noise octave #2 Amplitude.");
MIPARAM_FLOAT(fNoise2Speed, 0.3, "Noise octave #2 Speed.");
MIPARAM_FLOAT(fNoise2Rotation, 0, "Noise octave #2 Rotation.");
MIPARAM_TEXTURE(tReflectionMap_Low, 0, 5, "", false, "Reflection map of the material. This is a cube map representing the reflected environment.");
DECLARE_PARENT_MATERIAL(0, "murky_water_dx8.fxi");

technique FogVolume_Blend
	<	string High = "murky_water_mirror.fxi";
		string Medium = "murky_water_mirror.fxi";
		string Low = "murky_water_cube.fxi";
	>
{
}

