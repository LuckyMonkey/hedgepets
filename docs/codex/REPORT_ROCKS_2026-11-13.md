# Rock system report — 2026-11-13

## Research and choice

The useful open-source options were reviewed before implementation:

- ProtonScatter is MIT-licensed and targets Godot 4.4+; it is a placement tool, not a rock-shape generator. It is a
  possible future scatter replacement, but adding it would not solve the oval silhouettes.
- Blender procedural rock generators are bake-time tooling and can make excellent meshes, but would add a Blender
  dependency to this small Godot bake pipeline and make Inspector tuning less direct.
- Voronoi fracture and SDF/marching-cubes approaches produce more detail than this game needs and cost more vertices
  or runtime code. They are better for hero rocks than dozens of low-tier props.
- The selected approach is a pure GDScript convex hull made by random plane cuts. It is deterministic, inexpensive,
  easy to cache, and naturally gives the broad fractured faces of New England fieldstone. Role-specific plane bias
  preserves wall beds, level stepping tops, and layered ledges.

The ProtonScatter license reference is the [Godot Asset Store listing](https://store.godotengine.org/asset/hungryproton/protonscatter/);
the project repository is [HungryProton/scatter](https://github.com/HungryProton/scatter). No external library was
copied into the game.

## API

`RockFactory.make(spec)` returns a cached `ArrayMesh`. The spec supports `role`, `size`, `seed`, `roughness`, `facets`,
`flatten`, and `sink`. `wall`, `crossing`, and `scatter` return fitted specs with positions. Quantised sizes and full
shape inputs form the cache key. The bake fingerprint now includes `rock_factory.gd`.

## Integration

Garden loose rocks and wall stones are routed through the factory. Woods loose rocks inherit that route; forest-floor
cobbles, creek stepping stones, and ridge outcrops are also routed directly. The old `GardenProps.fieldstone*` names
remain as compatibility wrappers for existing callers, but no longer build the old stretched anatomy mesh.

## Performance and verification

The factory uses 6–10 low-poly facets for normal roles and duplicates only triangle vertices, keeping the generated
meshes small and flat shaded. Exact before/after world triangle counters were not available in this worktree's quick
runbook, and an offscreen visual capture could not be made because the software renderer needs the owner's X server;
Claude should inspect the wall, garden, woods, ridge, and creek captures. The requested bake and compile commands are
the final handoff steps below.

Checks run during this increment:

- Godot headless scene load of `tools/rock_lab.tscn` with `--audio-driver Dummy`.
- Parser/import validation through the Godot editor startup.

The requested `tools/bake_cache.gd`, `tools/compile_woods.gd`, `woods_check`, and `yard_check` commands were attempted
headless with the required Dummy audio driver, but this sandbox ended those Godot processes without producing output;
the existing cache and compiled woods timestamps were unchanged. Claude should rerun them on the normal development
machine before shipping, then capture the lab and the affected garden/woods views. No git commands were run.
