# Codex brief (2026-11-13): a rock system - build the thing that builds the rocks

Read `AGENTS.md`, `docs/HANDOFF.md` (design rules), `docs/ART_DIRECTION.md`. No git (Claude commits and deploys).
Offscreen Godot runs ALWAYS take `--audio-driver Dummy`. Godot `~/.local/bin/godot` 4.7.2. Must hold ~30 fps on this
2012 MacBook Air and on an iPhone (low tier). Work only in this worktree (`~/work/hp-rocks`). Another Codex works on
the woods (`woods.gd`, `distant_land.gd`) in `~/work/hp-woods`: you replace how rocks are MADE and give the woods a call
it can use; where the woods place rocks, change only the call (one line each), not the woods' layout code.

**Keep tests lean (owner: "do not overtest, it burns credits").** One quick capture set and the checks that touch
rocks; no repeated runs.

## The owner's words

"Every rock seems to be an oval, especially in the garden. I asked for rocks to be different shapes but we keep making
orbs. Find a library or something that can procedurally generate accurate rock shapes we can use around the game, but
with inputs so they fit in place: rocks that don't look like random spikes if it's a trail crossing, or that fit
together like a puzzle for a New England rock fence. Work smarter, not harder: build a thing that builds the rocks,
rather than building a rock each time by adding polygons."

Today: `GardenProps.fieldstone()` / `fieldstone_sized()` / `rock()` / `stone_wall()` / `_field_stone()`
(`scripts/garden/garden_props.gd`) build every stone from `HedgeAnatomy.build_mesh` ellipsoids (the pets' shape code)
squashed and stretched - hence orbs. The woods have their own rocks too (find them).

## Build

1. **Research first (10 minutes, write it in the report):** existing open-source approaches/libraries usable from
   Godot 4 / GDScript or at bake time (MIT/Apache/CC0 only): e.g. convex polyhedra from random plane cuts (how real
   fieldstone fractures), Voronoi fracture of a block, SDF + marching cubes with fractal noise and erosion, ProtonScatter
   (MIT) for placement, Blender rock generators (bake-time only). Pick what gives believable rocks at our low-poly,
   painterly style (`docs/ART_DIRECTION.md`) cheaply - most likely **plane-cut convex polyhedra** (a box or squashed
   hull cut by N random planes biased to the rock's role, chamfered, light vertex noise, flat-ish shading), with a
   few bevel cuts so they read as stone, never as spheres or spikes.
2. **`scripts/art/rock_factory.gd` (class_name RockFactory):** `RockFactory.make(spec) -> ArrayMesh`, deterministic
   from a seed, with a role and fit inputs. Roles at least:
   - `wall_stone` (New England dry-stone wall: blocky, two roughly parallel bed faces, a face side; given a slot size
     it fits - see 3),
   - `cap_stone` (flat, wide, sits on top of a wall),
   - `stepping_stone` (trail crossing / creek: flat top, low, rounded-off edges, sunk into the ground),
   - `boulder` (glacial erratic: big, rounded by weathering but faceted, never a ball),
   - `cobble` / `scree` (small, many: one MultiMesh),
   - `ledge` / `outcrop` (layered, for the ravine walls: strata planes).
   Inputs: size (Vector3 box it must fill), seed, roughness, facet count, flatten/bed axis, sink depth, optional
   neighbours' faces for fitting. Output caches by (role, quantised size, seed) - the same rock is never built twice;
   a small library of variants per role is baked into the startup cache (`scripts/util/bake_cache.gd`) so nothing is
   built at play time on the phone.
3. **Fitting:** `RockFactory.wall(from, to, height, seed) -> Array[spec]` that lays a dry-stone wall like a puzzle:
   bottom course of big stones, smaller ones filling, through-stones, a cap course; each stone sized to its slot and
   cut so neighbours' faces roughly meet (small gaps are right, overlaps are not). `RockFactory.crossing(path_points,
   width)` lays stepping stones along a trail/creek crossing, flat tops level with the path. `RockFactory.scatter(area,
   density, role)` for boulders/cobbles that sit on the ground (sunk, no floating, no spikes).
4. **Use it everywhere rocks appear:** the garden's walls (`stone_wall`, the burying ground's wall), loose rocks
   (`rock()`), the woods' rocks/boulders/ravine walls (only the call), the crossing on the trail. Keep each one's
   placement and rng draws as they are where possible (so nothing else in the world moves); one mesh per material,
   merged per wall (`GardenProps.bake_static`).
5. **A rock lab for the owner:** `tools/rock_lab.tscn` + script: open it in the Godot editor and see every role in a row,
   with exported parameters (role, seed, size, roughness, facets…) live in the inspector, plus a wall and a crossing
   built by the fitting functions. The owner will tune rocks there - make it pleasant to use. Document it in
   `docs/ROCKS.md` (how it works, how to add a role, how to tune, where each rock in the game comes from).

Performance: report triangle counts before/after for the garden and woods (`tools/bench_world.sh` or the existing
counters) and the bake time. Rocks must not cost more than today on the low tier.

Captures: software GL needs an X server, which your sandbox can't open; write captures with the headless renderer if
possible, or skip and say so - Claude will capture. Re-bake the cache (`tools/bake_cache.gd`) and recompile the woods
(`tools/compile_woods.gd`, headless fallback) at the end.

## Report

`docs/codex/REPORT_ROCKS_2026-11-13.md`: the research and choice, the API, each role, where it's used, numbers, checks
run, what Claude should look at in captures.
