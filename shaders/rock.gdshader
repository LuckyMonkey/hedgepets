shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 tint : source_color = vec4(0.52, 0.50, 0.45, 1.0);

void fragment() {
	float grain = sin((WORLD_MATRIX[3].x + VERTEX.x) * 17.0 + (WORLD_MATRIX[3].z + VERTEX.z) * 11.0) * 0.025;
	float top = smoothstep(0.25, 0.8, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);   // world up, not view up
	float lichen = top * smoothstep(0.55, 0.9, sin(WORLD_MATRIX[3].x * 2.0 + WORLD_MATRIX[3].z * 1.7) * 0.5 + 0.5) * 0.07;
	ALBEDO = tint.rgb * COLOR.rgb * (1.0 + grain + lichen);
	ROUGHNESS = 1.0;
}
