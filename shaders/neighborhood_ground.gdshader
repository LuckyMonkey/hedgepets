shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

// The yards and verges beyond the back fence (scripts/garden/neighborhood.gd), seen from the garden as its skybox:
// the garden lawn's own blade grain (lawn_detail.png) at a coarser scale, slow colour patches, mown stripes across
// each yard and darker, longer grass at the verges (along the yard fences and in front of the sidewalk). Positions
// are the mesh's own metres (it is built under the 1:16 root). One material, one mesh; read through fog and blur.
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.18;        // repeats per metre (coarser than the garden's own lawn: it is further away)
uniform float stripe_width = 1.8;         // metres per mown pass
uniform float stripe_strength = 0.11;
uniform float verge_strength = 0.22;
varying vec3 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local.xz;
	vec3 base = COLOR.rgb;
	// slow patches (a yard greener here, drier there), two octaves
	float patch = noise(p * 0.07) * 0.65 + noise(p * 0.23 + 17.0) * 0.35;
	base *= mix(0.84, 1.14, patch);
	base = mix(base, base * vec3(1.08, 1.04, 0.82), smoothstep(0.62, 0.85, noise(p * 0.11 + 5.0)) * 0.5);   // dry spots
	// blade grain, two scales so it never tiles visibly
	float g = texture(detail, p * detail_scale).r;
	float g2 = texture(detail, p * detail_scale * 0.41 + vec2(0.31, 0.77)).r;
	base *= mix(1.0, g * g2 * 1.55, 0.55);
	// mown stripes in the yards (between the garden's back fence and the sidewalk, and across the road)
	float yard = (1.0 - smoothstep(27.5, 28.6, p.y)) + smoothstep(39.3, 40.2, p.y);
	float stripe = step(0.5, fract(p.x / (stripe_width * 2.0)));
	base *= 1.0 + (stripe - 0.5) * 2.0 * stripe_strength * yard;
	// verges: longer, darker grass along the yard fences (x = +-6.6) and the sidewalk's edges
	float fence = 1.0 - smoothstep(0.2, 0.9, min(abs(p.x - 6.6), abs(p.x + 6.6)));
	float fence_on = fence * (1.0 - smoothstep(25.0, 26.0, p.y)) * step(10.5, p.y);
	float walk = 1.0 - smoothstep(0.1, 0.9, min(abs(p.y - 28.6), abs(p.y - 39.4)));
	base *= 1.0 - verge_strength * max(fence_on, walk);
	ALBEDO = base;
	ROUGHNESS = 1.0;
}
