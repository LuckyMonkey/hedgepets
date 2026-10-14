shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// The garden, seen back over the footbridge from the trailhead: a picture of the real garden taken as you walk into
// the woods (woods.gd snaps it), shown like the miniature skybox - tilt-shifted (sharp in a band across the lawn,
// soft above and below, from the picture's own mipmaps), a little of the woods' blue haze over it, the edges
// dissolving into the trees and the sky.
uniform sampler2D view : source_color, filter_linear_mipmap;
uniform vec3 haze : source_color = vec3(0.278, 0.388, 0.478);
uniform float haze_amount = 0.2;
uniform float focus = 0.62;

void fragment() {
	float blur = clamp(abs(UV.y - focus) * 10.0 - 0.7, 0.0, 4.5);
	vec3 c = textureLod(view, UV, blur).rgb;
	ALBEDO = mix(c, haze, haze_amount);
	ALPHA = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x) * smoothstep(0.08, 0.42, UV.y) * smoothstep(1.0, 0.9, UV.y);
}
