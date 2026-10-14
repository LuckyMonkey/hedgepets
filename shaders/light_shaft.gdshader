shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// A shaft of sunlight slanting down through the trees: a long card glowing softly in the middle and fading at its
// edges, brightest up high, thinning out before it reaches the grass, breathing a little as the leaves overhead move.
// UV.x across the shaft, UV.y along it (0 = up in the trees, 1 = the ground).
uniform vec3 colour : source_color = vec3(1.0, 0.86, 0.6);
uniform float strength = 0.18;
uniform float seed = 0.0;

void fragment() {
	float across = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 1.6);
	// no visible top: it fades in gradually over its whole upper half, so it seems to come from the canopy
	float along = smoothstep(0.0, 0.5, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float breathe = 0.75 + 0.25 * sin(TIME * 0.35 + seed * 6.3) * sin(TIME * 0.21 + seed * 2.1);
	// a few streaks along the shaft, like light through gaps in the leaves
	float streaks = 0.7 + 0.3 * sin(UV.x * 23.0 + seed * 11.0) * sin(UV.x * 9.0 - seed * 4.0);
	// edge-on, a card would show as a hard line: fade it as it turns away
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	// plain transparency (the additive blend didn't hold its strength in the Compatibility renderer): a warm,
	// see-through glow whose opacity is exactly what's computed here
	ALBEDO = colour;
	// up close it fades away: you never walk into a column of light (in the woods the camera passes right by them)
	float near = smoothstep(2.0, 6.0, length(VERTEX));
	// looked down on (from an overlook, over the treetops) a shaft is a card in mid-air: below your eye it fades away
	float below = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y - (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	near *= 1.0 - smoothstep(2.0, 5.0, below);
	ALPHA = clamp(strength * 15.0 * across * along * breathe * streaks * smoothstep(0.1, 0.5, facing) * near, 0.0, 0.35);
}
