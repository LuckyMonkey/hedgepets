// Shared by leaf.gdshader and leaf_ink_shell.gdshader so a leaf and its ink shell move as one.
float wind_at(float x, float t) {
	float breeze = 0.25 + 0.10 * sin(t * 0.7);
	float front = fract(t * 0.23 - x / 7.0);              // a gust rolls across him every ~4 s
	float g = pow(max(0.0, sin(front * PI)), 6.0) * (0.75 + 0.25 * sin(t * 0.31));
	return breeze + g;
}

// Bend, flutter and twist a leaf quad (stalk at the bottom edge). Returns the twist (0..1) for shading.
float leaf_deform(inout vec3 v, vec2 uv, vec4 custom, vec3 world, float t, float gust_amount) {
	float phase = custom.y;
	float reach = custom.z;
	float w = wind_at(world.x, t) + gust_amount;
	float tip = 1.0 - uv.y;
	float flutter = (sin(t * (5.0 + phase) + phase * 3.0) * 0.6 + sin(t * (11.0 + phase * 2.0)) * 0.4) * 0.07 * w * reach;
	float bend = w * 0.18 * reach;
	float twist = max(0.0, sin(t * (2.6 + phase * 0.5) + phase * 5.0)) * clamp(w - 0.3, 0.0, 1.0) * reach;
	v.z += (bend + flutter) * tip * 0.45;
	v.x += flutter * tip * 0.22;
	v.x *= 1.0 - 0.45 * twist;
	return twist;
}
