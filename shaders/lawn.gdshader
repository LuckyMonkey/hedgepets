shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

// The lawn: soft colour patches and bald spots (macro, 60 x 60 units) with fine blade grain on top (detail,
// tools/make_lawn_detail.py) so the ground holds up at pet scale. Both mapped in world space.
uniform sampler2D macro : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.55;       // detail repeats per world unit
uniform float detail_strength = 0.85;    // (most of the lawn is this texture now; 3D tufts only in the long grass)
// afternoon light through the canopy: soft sunflecks drifting slowly as the leaves overhead move
uniform sampler2D dapple : filter_linear_mipmap, repeat_enable;
uniform float dapple_strength = 0.8;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(macro, (world.xz + 30.0) / 60.0).rgb;
	float g = texture(detail, world.xz * detail_scale).r;
	float g2 = texture(detail, world.xz * detail_scale * 0.37 + vec2(0.31, 0.77)).r;   // a second scale, no visible tiling
	float grain = mix(1.0, g * g2 * 1.55, detail_strength);
	float d1 = texture(dapple, world.xz * 0.055 + vec2(TIME * 0.006, TIME * 0.003)).r;
	float d2 = texture(dapple, world.xz * 0.09 - vec2(TIME * 0.004, -TIME * 0.005) + vec2(0.37, 0.11)).r;
	float fleck = smoothstep(0.25, 0.75, d1 * 0.65 + d2 * 0.55);
	vec3 light = mix(vec3(0.8, 0.84, 0.88), vec3(1.16, 1.07, 0.88), fleck);   // cool shade, warm sun
	ALBEDO = base * grain * 1.08 * mix(vec3(1.0), light, dapple_strength);
	ROUGHNESS = 1.0;
}
