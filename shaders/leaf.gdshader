shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled;

// One leaf per MultiMesh instance (scripts/art/foliage_builder.gd). The quad's bottom edge is the stalk.
// INSTANCE_CUSTOM: x = sprite cell (0-7 leaves, 13 flower), y = wind phase, z = wind reach, w = rank in its
// cluster (0 = crown leaf .. 1 = smallest).
// Look: matte watercolour pigment, ink strong at the creature's silhouette and faint inside the foliage.
uniform sampler2D leaf_sheet : source_color, filter_linear_mipmap;
uniform sampler2D leaf_normals : hint_normal, filter_linear_mipmap;
uniform float cells = 16.0;
uniform float gust = 0.0;                 // a tap: every leaf shivers
uniform float lod_keep = 1.0;             // ranks above this are not drawn (detail levels)
uniform float lod_scale = 1.0;            // the kept leaves grow so the masses stay whole
uniform float detail_ink = 1.0;           // interior ink fades out at lower detail
uniform vec3 ink_color : source_color = vec3(0.15, 0.19, 0.11);
uniform float silhouette_ink = 0.85;
uniform float interior_ink = 0.30;
uniform float pool_strength = 0.10;       // watercolour pooling: slow pigment variation across the creature

varying float v_cell;
varying float v_twist;
varying float v_rim;
varying vec3 v_world;

float wind_at(float x, float t) {
	float breeze = 0.25 + 0.10 * sin(t * 0.7);
	float front = fract(t * 0.23 - x / 7.0);              // a gust rolls across him every ~4 s
	float g = pow(max(0.0, sin(front * PI)), 6.0) * (0.75 + 0.25 * sin(t * 0.31));
	return breeze + g;
}

void vertex() {
	v_cell = INSTANCE_CUSTOM.x;
	if (INSTANCE_CUSTOM.w > lod_keep) {
		VERTEX = vec3(0.0);                                  // dropped at this detail level
	}
	float phase = INSTANCE_CUSTOM.y;
	float reach = INSTANCE_CUSTOM.z;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_world = world;
	VERTEX.xy *= lod_scale;
	float w = wind_at(world.x, TIME) + gust;
	float tip = 1.0 - UV.y;
	float flutter = (sin(TIME * (5.0 + phase) + phase * 3.0) * 0.6 + sin(TIME * (11.0 + phase * 2.0)) * 0.4) * 0.07 * w * reach;
	float bend = w * 0.18 * reach;
	v_twist = max(0.0, sin(TIME * (2.6 + phase * 0.5) + phase * 5.0)) * clamp(w - 0.3, 0.0, 1.0) * reach;
	VERTEX.z += (bend + flutter) * tip * 0.45;
	VERTEX.x += flutter * tip * 0.22;
	VERTEX.x *= 1.0 - 0.45 * v_twist;
	// how edge-on this leaf is to the camera: leaves on the silhouette get the strong ink
	vec3 leaf_normal = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world);
	v_rim = 1.0 - abs(dot(leaf_normal, to_camera));
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
	vec3 albedo = COLOR.rgb * mix(1.0, fill.r, 0.6);
	// watercolour pooling: pigment gathers and thins in slow patches
	float pool = sin(v_world.x * 1.7 + v_world.z * 1.1) * sin(v_world.y * 2.3 - v_world.x * 0.7);
	albedo *= 1.0 + pool * pool_strength;
	albedo = mix(albedo, albedo + vec3(0.07, 0.08, 0.04), v_twist * 0.6);   // the paler underside as it turns
	float silhouette = smoothstep(0.55, 0.92, v_rim);
	float ink_amount = mix(interior_ink * detail_ink, silhouette_ink, silhouette);
	albedo = mix(albedo, ink_color, ink * ink_amount);
	ALBEDO = albedo;
	NORMAL_MAP = texture(leaf_normals, uv_fill).rgb;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = 1.0;
}
