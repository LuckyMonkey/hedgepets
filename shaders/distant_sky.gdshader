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
uniform float soften = 0.0;      // a little blur, in pixels of the picture (a low-poly miniature reads as distance)

void sky() {
	vec3 d = view_inv * EYEDIR;
	if (d.z >= -0.01) {
		COLOR = fallback;
	} else {
		vec2 p = d.xy / -d.z;
		vec2 uv = vec2(0.5 + 0.5 * p.x / tan_half_w, 0.5 - 0.5 * p.y / (tan_half_w / aspect));
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = fallback;
		} else if (soften > 0.0) {
			vec2 px = soften / vec2(textureSize(land, 0));
			COLOR = (texture(land, uv).rgb * 2.0 + texture(land, uv + vec2(px.x, 0.0)).rgb + texture(land, uv - vec2(px.x, 0.0)).rgb
				+ texture(land, uv + vec2(0.0, px.y)).rgb + texture(land, uv - vec2(0.0, px.y)).rgb) / 6.0;
		} else {
			COLOR = texture(land, uv).rgb;
		}
	}
}
