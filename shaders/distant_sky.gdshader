shader_type sky;

// The woods' sky is a picture of the land beyond them (scripts/garden/distant_land.gd renders a 1:16 miniature in its
// own SubViewport, its camera matched to the woods camera). Each sky direction is projected through that camera to
// find its pixel (SCREEN_UV isn't the screen in the Compatibility renderer's sky pass). Drawn behind everything in
// the woods, so the two worlds never share a depth buffer.
uniform sampler2D land : source_color, filter_linear, repeat_disable;
uniform mat3 view_inv;          // world -> camera (the camera's basis, transposed)
uniform float tan_half_w = 0.7;  // tan(horizontal fov / 2)
uniform float aspect = 0.5625;   // width / height
uniform vec3 fallback : source_color = vec3(0.77, 0.83, 0.86);

void sky() {
	vec3 d = view_inv * EYEDIR;
	if (d.z >= -0.01) {
		COLOR = fallback;
	} else {
		vec2 p = d.xy / -d.z;
		vec2 uv = vec2(0.5 + 0.5 * p.x / tan_half_w, 0.5 - 0.5 * p.y / (tan_half_w / aspect));
		COLOR = (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) ? fallback : texture(land, uv).rgb;
	}
}
