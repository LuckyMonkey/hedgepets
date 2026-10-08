shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

// The lawn: soft colour patches and bald spots (macro, 60 x 60 units) with fine blade grain on top (detail,
// tools/make_lawn_detail.py) so the ground holds up at pet scale. Both mapped in world space.
uniform sampler2D macro : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.55;       // detail repeats per world unit
uniform float detail_strength = 0.6;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(macro, (world.xz + 30.0) / 60.0).rgb;
	float g = texture(detail, world.xz * detail_scale).r;
	float g2 = texture(detail, world.xz * detail_scale * 0.37 + vec2(0.31, 0.77)).r;   // a second scale, no visible tiling
	float grain = mix(1.0, g * g2 * 1.55, detail_strength);
	ALBEDO = base * grain * 1.08;
	ROUGHNESS = 1.0;
}
