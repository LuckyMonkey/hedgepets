// Things right in front of the camera dissolve (an ordered dither, no transparency sorting), so the camera can pass
// through a tree crown or brush past a trunk without the screen filling with leaves. near_fade = (gone, solid) in
// distance from the camera; (0, 0) = off.
uniform vec2 near_fade = vec2(0.0, 0.0);

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i.y * 4 + i.x]) + 0.5) / 16.0;
}

void near_fade_discard(vec3 view_vertex, vec2 frag) {
	if (near_fade.y > 0.0) {
		float f = smoothstep(near_fade.x, near_fade.y, length(view_vertex));
		if (f < bayer4(frag)) {
			discard;
		}
	}
}
