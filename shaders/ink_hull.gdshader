shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
#include "res://shaders/near_fade.gdshaderinc"

// Inverted hull: a slightly larger copy of a shape, drawn back-faces only, reads as an ink outline round it.
uniform vec3 ink : source_color = vec3(0.15, 0.13, 0.09);
uniform float width = 0.025;
uniform float pull = 0.0;               // toward the camera, own units (the pet eyes' rim: see pet_eye.gdshader)

void vertex() {
	VERTEX += NORMAL * width;
	if (pull > 0.0) {
		vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		v.xyz += normalize(-v.xyz) * pull * length(MODELVIEW_MATRIX[0].xyz);
		POSITION = PROJECTION_MATRIX * v;
	}
}

void fragment() {
	near_fade_discard(VERTEX, FRAGCOORD.xy);
	ALBEDO = ink;
}
