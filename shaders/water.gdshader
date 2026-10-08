shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

// A shallow puddle on a flat plane (UV 0..1): an irregular outline from a few sines (no texture), a muddy wet rim,
// a darker middle that mirrors the sky, a soft sheen, and slow ripple rings from the leaking sprinkler.
uniform vec3 deep : source_color = vec3(0.26, 0.33, 0.36);
uniform vec3 sky : source_color = vec3(0.72, 0.80, 0.82);
uniform vec3 mud : source_color = vec3(0.36, 0.30, 0.22);
uniform vec2 drip = vec2(0.22, 0.45);     // where the drops land (UV)
uniform float seed = 1.7;

float outline(vec2 p) {
	float a = atan(p.y, p.x);
	float r = 0.40 + 0.045 * sin(a * 3.0 + seed) + 0.03 * sin(a * 5.0 + seed * 2.3) + 0.018 * sin(a * 9.0 + seed * 0.7);
	return length(p) / r;           // < 1 inside
}

void fragment() {
	vec2 p = UV - 0.5;
	float d = outline(p);
	if (d > 1.12) {
		discard;
	}
	float water = 1.0 - smoothstep(0.86, 1.0, d);        // 1 in the water, 0 on the wet rim
	float rim = smoothstep(0.8, 1.0, d) * (1.0 - smoothstep(1.0, 1.12, d));
	// ripples: rings spreading from the drip point, fading out
	float t = TIME * 0.6;
	float ring = 0.0;
	for (int i = 0; i < 3; i++) {
		float age = fract(t + float(i) / 3.0);
		float dist = length(UV - drip);
		ring += exp(-pow((dist - age * 0.45) * 40.0, 2.0)) * (1.0 - age);
	}
	vec3 view = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(NORMAL, view), 0.0, 1.0), 3.0);
	vec3 c = mix(deep, sky, 0.25 + fres * 0.6 + ring * 0.25);
	c = mix(c, mud, rim * 0.8);
	ALBEDO = c;
	ALPHA = clamp(water * 0.82 + rim * 0.55, 0.0, 0.95);
	ROUGHNESS = mix(0.05, 0.9, rim);
	SPECULAR = 0.6;
	NORMAL = normalize(NORMAL + vec3(ring * 0.15, 0.0, ring * 0.15));
}
