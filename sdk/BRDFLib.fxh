#ifndef __BRDFLIB_FXH__
#define __BRDFLIB_FXH__

float GetToksvigGlossScale( float3 vNormalVector, float fGlossExponent )
{
	float fNormalLength = 1.0f/saturate(length(vNormalVector ));
	return 1.0f/(1.0f + fGlossExponent * (fNormalLength - 1.0f) );
}

half PowerToRMSRoughness( float fSpecPower )
{
	return( 0.6h * saturate(sqrt( 2.0h/max(fSpecPower, 0.000001f) )) );
}

half GetBeckhamDistribution( half NdotH, half m )
{
	half  NdotH_pow2 = NdotH * NdotH;
	half  m2_mul_NdotH_pow2 = m * m * NdotH_pow2;
	half  tanDelta = ( 1.0 - NdotH_pow2 ) / ( m2_mul_NdotH_pow2 );
	return exp( -tanDelta ) / ( m2_mul_NdotH_pow2 * NdotH_pow2 + 0.001h );
}

half GetGaussianDistribution( half NdotH, half m )
{
	half c = 1.0h;
	half alpha = acos( NdotH );
	return( c * exp( -( alpha / (m * m) ) ) );
}

half GetReflectanceCoefficient( half fIOR )
{
	half kr = (fIOR - 1.0f) / (fIOR + 1.0f);
	return( kr * kr );
}

half GetSchlickFresnel( float fVdotH, half kr )
{
	return kr + (1.0f - kr) * pow((1.0f - fVdotH), 5.0f);
}

half GetBlinnPhongNormalizationConstant( half fSpecPower )
{
	return( (0.0397436f * fSpecPower) + 0.0856832f );
}

float3 GetKelemenSzirmayKalosSpecularColor(
		float3 vNormal, // Surface normal at the point
		float3 vLightVector, // Unit vector from the point to the light
		float3 vEyeVector, // Unit vector from the point to the eye
		float3 vMaterialSpecularColor, // Diffuse specular color at the point
		float fMaterialGloss, // Gloss value of the material (modulates maximum specular power)
		float fMaxSpecularPower,
		float3 vLightSpecularColor, // Light specular color,
		half kr
	)
{
	// Calculate the float-vector
	float3 vHalfVector = (vEyeVector + vLightVector);
	
	float fSpecularGeometric = dot( vHalfVector.xyz, vHalfVector.xyz );
	vHalfVector = normalize( vHalfVector );
	
	// Get the specular attenuation value
	float fVdotH = dot(vHalfVector, vEyeVector);

	float fNdotL = dot( vNormal, vLightVector );
	float fVdotN = dot( vNormal, vEyeVector );
	
	half fFresnel = GetSchlickFresnel( fVdotH, kr );
	float fSpecular = saturate( dot( vHalfVector, vNormal ) );
	half fSpecPower = max( (fMaterialGloss * fMaxSpecularPower), 0.00001f );
	fSpecular = pow( fSpecular, fSpecPower );
	fSpecular *= GetBlinnPhongNormalizationConstant( fSpecPower );
	fSpecular = (fFresnel/fSpecularGeometric) * fSpecular;

	// Final specular contribution
	float3 vResult = vLightSpecularColor * vMaterialSpecularColor * fSpecular;

	return vResult;
}

#endif