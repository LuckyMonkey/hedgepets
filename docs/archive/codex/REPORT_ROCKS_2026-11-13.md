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

## Geometry decision

The first implementation was rejected by the owner's override because repeated plane clipping started from a box and
could grow too many faces. It has been replaced by the five ordered operations in `ROCKS_SPEC.md`: a 10–14 point
convex hull from evenly distributed Fibonacci points (<=10% jitter), role-biased projection fractures only 10–25%
into the hull, one <=8% coherent nudge, <=3 corner blunts, and shader-only micro detail. No icosphere or per-vertex
noise is used. Meshes are translated so their bottom is y=0; placement applies sink.

## API

`RockFactory.make(spec)` returns a cached `ArrayMesh`. Archetype values come from `data/rocks.json`; per-call values
override role, size, seed, and sink. `wall`, `crossing`, and `scatter` return fitted specs with positions. Quantised
sizes and full archetype inputs form the cache key. The bake fingerprint includes `rock_factory.gd`.

## Integration

Garden loose rocks and wall stones are routed through the factory. Woods loose rocks inherit that route; forest-floor
cobbles, creek stepping stones, and ridge outcrops are also routed directly. The old `GardenProps.fieldstone*` names
remain as compatibility wrappers for existing callers, but no longer build the old stretched anatomy mesh.

## Triangle counts

Reference lab counts are: cobble 16/16, scree 16/16, wall_stone 20/30, cap_stone 20/30, stepping_stone 19/30,
boulder/weathered_boulder 24/48, ledge 22/60, and outcrop 24/60 (measured triangles / hard cap). The cap fallback
rejects and simplifies any edited archetype that exceeds its budget.

## Performance and verification

The previous documented renderer baseline was approximately 860k garden primitives and 3.13M woods primitives. The
after totals could not be collected here: headless Godot exited before the census/world benchmark printed, and the
software renderer needs the owner's X server for a capture. The dated table is therefore: garden 860k before / after
pending normal-machine census; woods 3.13M before / after pending normal-machine census. Rock geometry itself is
bounded by the counts above and is materially lower-poly than the former stretched anatomy meshes.

Checks run during this increment:

- Godot headless scene load of `tools/rock_lab.tscn` with `--audio-driver Dummy`.
- Parser/import validation through the Godot editor startup.
- Headless `tools/rock_lab.tscn` load: PASS; the lab printed all eight archetype counts above.

The requested `tools/bake_cache.gd`, `tools/compile_woods.gd`, `woods_check`, and `yard_check` commands were attempted
headless with the required Dummy audio driver, but this sandbox ended those Godot processes without producing output;
the existing cache and compiled woods timestamps were unchanged. Claude should rerun them on the normal development
machine before shipping, then capture the lab and the affected garden/woods views. No git commands were run.
