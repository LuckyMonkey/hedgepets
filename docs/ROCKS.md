# Rock system

`RockFactory` (`scripts/art/rock_factory.gd`) is the single source for low-poly stones. It starts with a box, cuts
it with deterministic broad planes, and triangulates the resulting convex faces. This gives fractured planes and
flat-ish beds without the spherical look of an ellipsoid. `seed`, `size`, `roughness`, `facets`, `flatten`, and
`sink` are the tuning inputs; size is the box the rock must fit.

## Lab

Open `res://tools/rock_lab.tscn` in the editor. The selected `RockLab` node exposes role, seed, size, roughness,
facets, and flatten in the Inspector. The row compares all roles; below it are a fitted dry-stone wall and a trail
crossing. Changing an Inspector value regenerates the preview. For a quick desktop preview:

```text
godot --path . res://tools/rock_lab.tscn
```

## Roles and fitting

- `wall_stone`: broad, roughly parallel faces for a dry-stone wall slot.
- `cap_stone`: flatter stones for the top course.
- `stepping_stone`: low, level stones for a trail or creek crossing.
- `boulder`: weathered, faceted glacial stone; broad cuts prevent spikes.
- `cobble` / `scree`: small stones, suitable for a shared MultiMesh.
- `ledge` / `outcrop`: layered-looking low stones for ravine edges.

`wall(from, to, height, seed)` returns positioned stone specs for bottom-to-top courses and caps. `crossing(points,
width)` returns level stepping-stone specs. `scatter(area, density, role)` returns sunk ground placements. Meshes are
cached by role, quantised size, seed, and shape inputs, and the bake cache includes the factory fingerprint.

## Game usage

Garden loose rocks and all garden wall stones now use the factory. Woods loose rocks call the same garden entry point;
forest-floor cobbles, creek stepping stones, and ridge outcrops use the factory directly. Existing placement and RNG
draws remain in their callers so the rest of the garden stays put. `GardenProps.bake_static` still merges static wall
geometry per material.

To add a role: add its name to `ROLES`, choose its initial plane bias in `make`, add a lab size, and document the
placement helper. Keep facets low (6–10 is the normal range) and use roughness for broad silhouette variation, not
high-frequency noise. Sink ground stones instead of raising them above the terrain.
