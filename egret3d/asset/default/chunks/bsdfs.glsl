// diffuse just use lambert

vec3 BRDF_Diffuse_Lambert(vec3 diffuseColor) {
    return RECIPROCAL_PI * diffuseColor;
}

// specular use Cook-Torrance microfacet model, http://ruh.li/GraphicsCookTorrance.html
// About RECIPROCAL_PI: referenced by http://www.joshbarczak.com/blog/?p=272

vec4 F_Schlick( const in vec4 specularColor, const in float dotLH ) {
	// Original approximation by Christophe Schlick '94
	float fresnel = pow( 1.0 - dotLH, 5.0 );

	// Optimized variant (presented by Epic at SIGGRAPH '13)
	// float fresnel = exp2( ( -5.55473 * dotLH - 6.98316 ) * dotLH );

	return ( 1.0 - specularColor ) * fresnel + specularColor;
}

// use blinn phong instead of phong
float D_BlinnPhong( const in float shininess, const in float dotNH ) {
    // ( shininess * 0.5 + 1.0 ), three.js do this, but why ???
	return RECIPROCAL_PI * ( shininess * 0.5 + 1.0 ) * pow( dotNH, shininess );
}

float G_BlinnPhong_Implicit( /* const in float dotNL, const in float dotNV */ ) {
	// geometry term is (n dot l)(n dot v) / 4(n dot l)(n dot v)
	return 0.25;
}

vec4 BRDF_Specular_BlinnPhong(vec4 specularColor, vec3 N, vec3 L, vec3 V, float shininess) {
    vec3 H = normalize(L + V);

    float dotNH = saturate(dot(N, H));
    float dotLH = saturate(dot(L, H));

    vec4 F = F_Schlick(specularColor, dotLH);

    float G = G_BlinnPhong_Implicit( /* dotNL, dotNV */ );

    float D = D_BlinnPhong(shininess, dotNH);

    return F * G * D;
}

// Microfacet Models for Refraction through Rough Surfaces - equation (33)
// http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
// alpha is "roughness squared" in Disney’s reparameterization
float D_GGX( const in float alpha, const in float dotNH ) {

	float a2 = pow2( alpha );

	float denom = pow2( dotNH ) * ( a2 - 1.0 ) + 1.0; // avoid alpha = 0 with dotNH = 1

	return RECIPROCAL_PI * a2 / pow2( denom );

}

// Microfacet Models for Refraction through Rough Surfaces - equation (34)
// http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
// alpha is "roughness squared" in Disney’s reparameterization
float G_GGX_Smith( const in float alpha, const in float dotNL, const in float dotNV ) {

	// geometry term = G(l)⋅G(v) / 4(n⋅l)(n⋅v)

	float a2 = pow2( alpha );

	float gl = dotNL + sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNL ) );
	float gv = dotNV + sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNV ) );

	return 1.0 / ( gl * gv );

}

// Moving Frostbite to Physically Based Rendering 2.0 - page 12, listing 2
// http://www.frostbite.com/wp-content/uploads/2014/11/course_notes_moving_frostbite_to_pbr_v2.pdf
float G_GGX_SmithCorrelated( const in float alpha, const in float dotNL, const in float dotNV ) {

	float a2 = pow2( alpha );

	// dotNL and dotNV are explicitly swapped. This is not a mistake.
	float gv = dotNL * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNV ) );
	float gl = dotNV * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNL ) );

	return 0.5 / max( gv + gl, EPSILON );
}

// GGX Distribution, Schlick Fresnel, GGX-Smith Visibility
vec4 BRDF_Specular_GGX(vec4 specularColor, vec3 N, vec3 L, vec3 V, float roughness) {

	float alpha = pow2( roughness ); // UE4's roughness

	vec3 H = normalize(L + V);

	float dotNL = saturate( dot(N, L) );
	float dotNV = saturate( dot(N, V) );
	float dotNH = saturate( dot(N, H) );
	float dotLH = saturate( dot(L, H) );

	vec4 F = F_Schlick( specularColor, dotLH );

	float G = G_GGX_SmithCorrelated( alpha, dotNL, dotNV );

	float D = D_GGX( alpha, dotNH );

	return F * G * D;

}

// ref: https://www.unrealengine.com/blog/physically-based-shading-on-mobile - environmentBRDF for GGX on mobile
vec4 BRDF_Specular_GGX_Environment( const in vec3 N, const in vec3 V, const in vec4 specularColor, const in float roughness ) {

	float dotNV = saturate( dot( N, V ) );

	const vec4 c0 = vec4( - 1, - 0.0275, - 0.572, 0.022 );

	const vec4 c1 = vec4( 1, 0.0425, 1.04, - 0.04 );

	vec4 r = roughness * c0 + c1;

	float a004 = min( r.x * r.x, exp2( - 9.28 * dotNV ) ) * r.x + r.y;

	vec2 AB = vec2( -1.04, 1.04 ) * a004 + r.zw;

	return specularColor * AB.x + AB.y;

}

// source: http://simonstechblog.blogspot.ca/2011/12/microfacet-brdf.html
float GGXRoughnessToBlinnExponent( const in float ggxRoughness ) {
	return ( 2.0 / pow2( ggxRoughness + 0.0001 ) - 2.0 );
}

float BlinnExponentToGGXRoughness( const in float blinnExponent ) {
	return sqrt( 2.0 / ( blinnExponent + 2.0 ) );
}