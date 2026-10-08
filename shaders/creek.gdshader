shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

// A shallow creek on a strip mesh: UV.x runs along it in world units, UV.y across it (0 and 1 are the banks).
// Muddy wet banks, a darker middle, sky sheen at a glance, and ripples drifting downstream.
uniform vec3 deep : source_color = vec3(0.20, 0.33, 0.40);
uniform vec3 sky : source_color = vec3(0.66, 0.80, 0.88);
uniform vec3 mud : source_color = vec3(0.34, 0.28, 0.20);
uniform float flow = 0.9;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;                       // 0 in the middle, 1 at the banks
	float wobble = 0.06 * sin(UV.x * 1.7) + 0.04 * sin(UV.x * 4.1 + 1.3);
	float bank = smoothstep(0.62 + wobble, 0.95, across);
	if (across > 0.99) {
		discard;
	}
	float t = TIME * flow;
	float ripple = sin(UV.x * 6.0 - t * 3.0 + sin(UV.y * 9.0 + UV.x) * 1.5) * 0.5 + 0.5;
	ripple *= sin(UV.x * 2.3 - t * 1.4 + UV.y * 4.0) * 0.5 + 0.5;
	vec3 view = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(NORMAL, view), 0.0, 1.0), 3.0);
	vec3 c = mix(deep, sky, 0.28 + fres * 0.6 + ripple * 0.3 * (1.0 - bank));
	c = mix(c, mud, bank * 0.85);
	ALBEDO = c;
	ALPHA = mix(0.85, 0.6, bank) * (1.0 - smoothstep(0.93, 0.99, across));
	ROUGHNESS = mix(0.06, 0.9, bank);
	SPECULAR = 0.6;
}
