shader_type spatial;
render_mode specular_schlick_ggx;

// A pet's eye or eye glint, drawn a little toward the camera: leaves that overlap the face by a few centimetres
// can't cover it (the face reads), but the head still hides it from behind (the pull is far smaller than a head).
// glow = 1: unshaded (the glint's crisp almost-white dot).
uniform vec4 albedo : source_color = vec4(0.1, 0.07, 0.05, 1.0);
uniform float roughness_value = 0.6;
uniform float specular_value = 0.25;
uniform float glow = 0.0;
uniform float pull = 0.0;               // in the pet's own units (scaled with the pet)

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.xyz += normalize(-v.xyz) * pull * length(MODELVIEW_MATRIX[0].xyz);
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	ALBEDO = albedo.rgb * (1.0 - glow);
	EMISSION = albedo.rgb * glow;
	ROUGHNESS = mix(roughness_value, 1.0, glow);
	SPECULAR = specular_value * (1.0 - glow);
}
