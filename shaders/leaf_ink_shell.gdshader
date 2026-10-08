shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// The ink silhouette of the whole bush. Drawn as the leaf material's next pass: every leaf gets a slightly larger
// dark copy just behind it, but only where the leaf lies on the creature's outline (its surface faces sideways to
// the camera). Leaves facing you get no shell, so the ink is thick at the silhouette and absent inside.
#include "res://shaders/leaf_common.gdshaderinc"

uniform sampler2D leaf_sheet : source_color, filter_linear_mipmap;
uniform float cells = 16.0;
uniform float gust = 0.0;
uniform float lod_keep = 1.0;
uniform float lod_scale = 1.0;
uniform vec3 ink_color : source_color = vec3(0.15, 0.19, 0.11);
uniform float shell = 0.12;          // how much bigger than its leaf (the line weight)
uniform float strength = 1.0;        // 0 turns the silhouette ink off
uniform vec3 body_center;            // world space, updated by the pet each frame
uniform vec3 head_center;
uniform float body_radius = 1.15;
uniform float head_radius = 0.8;

varying float v_rim;
varying float v_cell;

void vertex() {
	v_cell = INSTANCE_CUSTOM.x;
	if (INSTANCE_CUSTOM.w > lod_keep) {
		VERTEX = vec3(0.0);
	}
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX.xy = (VERTEX.xy - vec2(0.0, 0.5)) * (1.0 + shell) + vec2(0.0, 0.5);
	VERTEX.xy *= lod_scale;
	leaf_deform(VERTEX, UV, INSTANCE_CUSTOM, world, TIME, gust);
	VERTEX.z -= 0.05;                                     // just behind its own leaf
	// the creature's surface normal here, from whichever mass this leaf belongs to
	float to_head = length(world - head_center) / head_radius;
	float to_body = length(world - body_center) / body_radius;
	vec3 n = normalize(world - (to_head < to_body ? head_center : body_center));
	v_rim = 1.0 - abs(dot(n, normalize(CAMERA_POSITION_WORLD - world)));
}

void fragment() {
	float cell = floor(v_cell + 0.5);
	float shape = texture(leaf_sheet, vec2((cell + UV.x) / cells, UV.y * 0.5)).a;
	if (shape < 0.45 || v_rim * strength < 0.74) {
		discard;
	}
	ALBEDO = mix(ink_color, vec3(0.30, 0.38, 0.22), 0.25);   // ink, softened toward the foliage
}
