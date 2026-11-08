shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

uniform sampler2D shadow_map : source_color, filter_linear_mipmap;
uniform vec4 shadow_bounds = vec4(-64.0, -116.0, 44.0, 24.0);
uniform float shadow_strength = 0.72;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 shadow_uv = (world.xz - shadow_bounds.xy) / (shadow_bounds.zw - shadow_bounds.xy);
	float baked_shadow = texture(shadow_map, clamp(shadow_uv, vec2(0.0), vec2(1.0))).r;
	ALBEDO = COLOR.rgb * mix(1.0 - shadow_strength, 1.0, baked_shadow);
	ROUGHNESS = 1.0;
}
