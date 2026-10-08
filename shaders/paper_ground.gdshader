shader_type spatial;
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

// The ground is the paper: it shows exactly the paper colour, darkened only where a shadow falls on it (softly,
// never black). Lights do not brighten it, so it always matches the background.
uniform vec3 paper : source_color = vec3(0.968627, 0.945098, 0.890196);
uniform vec3 shadow_tint : source_color = vec3(0.46, 0.47, 0.38);
uniform float shadow_strength = 0.32;

void fragment() {
	ALBEDO = vec3(1.0);
	EMISSION = paper;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// only shadowed light matters: subtract a tinted share of the paper where the key light is blocked
		float blocked = 1.0 - ATTENUATION;
		DIFFUSE_LIGHT -= paper * (vec3(1.0) - shadow_tint) * shadow_strength * blocked * 2.0;
	}
}
