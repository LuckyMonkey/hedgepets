shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

// One ivy leaf per MultiMesh instance. The quad's bottom edge is the stalk; the wind moves the tip.
// INSTANCE_CUSTOM: x = sprite cell (0-7 leaves, 13 flower), y = wind phase, z = reach (how much it moves), w = unused.
uniform sampler2D leaf_sheet : source_color, filter_linear_mipmap;
uniform sampler2D leaf_normals : hint_normal, filter_linear_mipmap;
uniform float cells = 16.0;
uniform float gust = 0.0;          // a tap or a gust from the pet's own life: shivers every leaf
uniform vec3 wind_dir = vec3(1.0, 0.0, -0.35);

varying float v_cell;
varying float v_twist;

float wind_at(float x, float t) {
	float breeze = 0.25 + 0.10 * sin(t * 0.7);
	float front = fract(t * 0.23 - x / 7.0);              // a gust rolls across him every ~4 s
	float g = pow(max(0.0, sin(front * PI)), 6.0) * (0.75 + 0.25 * sin(t * 0.31));
	return breeze + g;
}

void vertex() {
	v_cell = INSTANCE_CUSTOM.x;
	float phase = INSTANCE_CUSTOM.y;
	float reach = INSTANCE_CUSTOM.z;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = wind_at(world.x, TIME) + gust;
	float tip = 1.0 - UV.y;                                  // 0 at the stalk, 1 at the tip
	float flutter = (sin(TIME * (5.0 + phase) + phase * 3.0) * 0.6 + sin(TIME * (11.0 + phase * 2.0)) * 0.4) * 0.08 * w * reach;
	float bend = w * 0.22 * reach;
	v_twist = max(0.0, sin(TIME * (2.6 + phase * 0.5) + phase * 5.0)) * clamp(w - 0.3, 0.0, 1.0) * reach;
	// bend the tip back along the leaf's normal (away from the wind) and flutter sideways; twist narrows the leaf
	VERTEX.z += (bend + flutter) * tip * 0.55;
	VERTEX.x += flutter * tip * 0.25;
	VERTEX.x *= 1.0 - 0.5 * v_twist;
}

void fragment() {
	float cell = floor(v_cell + 0.5);
	vec2 uv_fill = vec2((cell + UV.x) / cells, UV.y * 0.5);
	vec2 uv_ink = vec2((cell + UV.x) / cells, 0.5 + UV.y * 0.5);
	vec4 fill = texture(leaf_sheet, uv_fill);
	float ink = texture(leaf_sheet, uv_ink).a;
	if (fill.a < 0.45 && ink < 0.5) {
		discard;
	}
	vec3 tint = COLOR.rgb;
	vec3 albedo = tint * fill.rgb;
	albedo = mix(albedo, albedo + vec3(0.10, 0.12, 0.05), v_twist * 0.6);     // the paler underside shows as it turns
	albedo = mix(albedo, vec3(0.08, 0.12, 0.05), ink * 0.85);                 // the fine dark outline
	ALBEDO = albedo;
	NORMAL_MAP = texture(leaf_normals, uv_fill).rgb;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
