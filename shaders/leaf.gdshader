shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled;
#include "res://shaders/near_fade.gdshaderinc"

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

#include "res://shaders/leaf_common.gdshaderinc"

void vertex() {
	v_cell = INSTANCE_CUSTOM.x;
	// leaves above the kept rank shrink to their stalk over a soft band, so detail changes and leaves growing in
	// or falling away are smooth, never a pop
	float keep = clamp((lod_keep - INSTANCE_CUSTOM.w) / 0.25 + 1.0, 0.0, 1.0);
	VERTEX *= keep * keep * (3.0 - 2.0 * keep);
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_world = world;
	VERTEX.xy *= lod_scale;
	v_twist = leaf_deform(VERTEX, UV, INSTANCE_CUSTOM, world, TIME, gust);
	// how edge-on this leaf is to the camera: leaves on the silhouette get the strong ink
	vec3 leaf_normal = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world);
	v_rim = 1.0 - abs(dot(leaf_normal, to_camera));
}

void fragment() {
	near_fade_discard(VERTEX, FRAGCOORD.xy);
	float cell = floor(v_cell + 0.5);
	vec2 uv_fill = vec2((cell + UV.x) / cells, UV.y * 0.5);
	vec2 uv_ink = vec2((cell + UV.x) / cells, 0.5 + UV.y * 0.5);
	vec4 fill = texture(leaf_sheet, uv_fill);
	// the pen lines are fine and hand-drawn; a little mip bias keeps them crisp when a leaf is small on screen
	float ink = smoothstep(0.08, 0.7, texture(leaf_sheet, uv_ink, -1.0).a);   // a fine line kept crisp, not bolded
	if (fill.a < 0.45 && ink < 0.5) {
		discard;
	}
	// leaves: the tint shaped by the sprite's tone (strong: a lit middle, darker edges, pale veins); the flower cell
	// carries its own colours (white petals, a yellow eye), tinted by the profile's flower colour
	vec3 albedo = cell > 12.5 && cell < 13.5 ? COLOR.rgb * fill.rgb : COLOR.rgb * mix(1.0, fill.r, 0.8);
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
