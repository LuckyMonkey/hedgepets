shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
#include "res://shaders/near_fade.gdshaderinc"

// Inverted hull: a slightly larger copy of a shape, drawn back-faces only, reads as an ink outline round it.
uniform vec3 ink : source_color = vec3(0.15, 0.13, 0.09);
uniform float width = 0.025;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	near_fade_discard(VERTEX, FRAGCOORD.xy);
	ALBEDO = ink;
}
