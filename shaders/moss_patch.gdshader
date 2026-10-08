shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled;

// A patch of short grass / moss on a pet (a snout, a marking): the region's own mesh drawn several times as shells,
// each pushed out a little further along the normal. Every shell keeps only the strands still tall enough at its
// height, so you get real fibres with depth: dark at the roots, lighter at the tips, each strand its own height.
// layer 0 is the solid base. Strands are cells of a 3D grid in the object's own space (no UV seams).
uniform float layer = 0.0;          // 0 = base, then 0..1 up the pile
uniform float pile = 0.06;          // how long the strands are (object units)
uniform float density = 22.0;       // strands per object unit
uniform vec3 tint : source_color = vec3(0.6, 0.72, 0.36);
varying vec3 v_obj;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	v_obj = VERTEX;
	// strands lean a little and droop toward their tips
	vec3 out_dir = normalize(NORMAL + vec3(0.0, -0.35 * layer, 0.0));
	VERTEX += out_dir * pile * layer;
}

void fragment() {
	vec3 p = v_obj * density;
	vec3 cell = floor(p);
	vec3 r = hash3(cell);
	float height = 0.35 + 0.65 * r.x;                    // this strand's length
	vec3 centre = cell + 0.25 + 0.5 * r;                 // where it grows inside its cell
	float d = length(p - centre);
	if (layer > 0.0) {
		float radius = 0.55 * (1.0 - layer / height);    // thinner toward the tip
		if (layer > height || d > radius) {
			discard;
		}
	}
	float shade = mix(0.42, 1.08, layer) * (0.85 + 0.3 * r.y);   // dark roots, lit tips, strand to strand variation
	ALBEDO = tint * shade;
	ROUGHNESS = 1.0;
}
