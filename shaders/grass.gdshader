shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled;

// Grass tufts and weeds (MultiMesh of crossed quads). INSTANCE_CUSTOM.x = sprite cell, .y = sway phase.
// White sprites, tinted per instance (COLOR); weeds keep their own colours. The tips sway in the garden's breeze.
uniform sampler2D grass_sheet : source_color, filter_linear_mipmap;
uniform float cells = 12.0;
varying float v_cell;

void vertex() {
	v_cell = INSTANCE_CUSTOM.x;
	float tip = 1.0 - UV.y;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.6 + INSTANCE_CUSTOM.y + world.x * 0.35) * 0.08 + sin(TIME * 0.6 + world.z * 0.2) * 0.05;
	VERTEX.x += sway * tip * tip;
}

void fragment() {
	float cell = floor(v_cell + 0.5);
	vec4 s = texture(grass_sheet, vec2((cell + UV.x) / cells, UV.y));
	if (s.a < 0.5) {
		discard;
	}
	bool weed = cell >= 8.0 && cell <= 10.0;
	vec3 base = COLOR.rgb * mix(0.82, 1.06, 1.0 - UV.y);   // a little darker at the roots
	// colour from the tint alone: the sprite's transparent edges are black, and filtering would bleed them in
	ALBEDO = weed && distance(s.rgb, vec3(s.r)) > 0.08 ? s.rgb / max(s.a, 0.01) : base;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;   // lit like the lawn it grows from, not like a card
	ROUGHNESS = 1.0;
}
