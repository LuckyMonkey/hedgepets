shader_type canvas_item;

// Tilt-shift: a band across the screen stays sharp, everything above and below blurs more and more, and colour
// is lifted a little - the garden reads as a miniature on a table. Screen-space, so it works on every renderer.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float focus_center = 0.56;     // where the sharp band sits (0 top .. 1 bottom)
uniform float focus_width = 0.14;      // half-height of the sharp band
uniform float falloff = 0.32;          // how quickly it blurs outside the band
uniform float max_blur = 7.0;          // pixels at the edges
uniform float saturation = 1.18;
uniform float contrast = 1.05;
uniform float vignette = 0.18;

const vec2 TAPS[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
	float d = abs(SCREEN_UV.y - focus_center);
	float amount = smoothstep(focus_width, focus_width + falloff, d);
	vec2 radius = SCREEN_PIXEL_SIZE * max_blur * amount;
	vec3 c = texture(screen, SCREEN_UV).rgb;
	if (amount > 0.01) {
		vec3 sum = c;
		for (int i = 0; i < 12; i++) {
			sum += texture(screen, SCREEN_UV + TAPS[i] * radius).rgb;
			sum += texture(screen, SCREEN_UV + TAPS[i] * radius * 0.5).rgb;
		}
		c = sum / 25.0;
	}
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(v, v) * 2.0;
	COLOR = vec4(c, 1.0);
}
