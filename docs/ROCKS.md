# Rock system

`RockFactory` is a deliberately tiny, data-defined rock generator. It does not use an icosphere, ellipsoid mesh, or
runtime noise geometry. Archetypes live in [data/rocks.json](../data/rocks.json), and the lab edits the selected
archetype and saves it with the `save_archetype` Inspector toggle.

## The five geometry operations

1. Build a convex hull from 10–14 evenly distributed Fibonacci-sphere points on the archetype aspect, with <=10% jitter.
2. Project points beyond 3–6 role-biased fracture planes to flatten broad beds, tops, or strata; each plane cuts only
   10–25% into the hull.
3. Apply one coherent low-frequency vertex nudge, capped at 8%.
4. Pull at most three sharp points inward for restrained weathering; no spikes or slivers are accepted.
5. Put grain, cracks, lichen, and restrained colour variation in the shared `shaders/rock.gdshader` material.

The hull has no added detail during variation. `make()` returns the mesh with its bottom at y=0; callers apply ground
placement and sink. Wall/cap/stepping stones enforce y >= 40% of horizontal width; ledge/outcrop pieces enforce y >=
25%.

The hard triangle budgets are enforced in `make()`:

| Archetype | Reference triangles | Hard cap |
|---|---:|---:|
| cobble | 15 | 16 |
| scree | 16 | 16 |
| wall_stone | 20 | 30 |
| cap_stone | 20 | 30 |
| stepping_stone | 19 | 30 |
| boulder / weathered_boulder | 24 | 48 |
| ledge | 22 | 60 |
| outcrop | 24 | 60 |

Counts are from the lab's reference seed set (17 plus the role index); seeds can reduce the hull, never exceed the cap.

## Lab and fitting

Open `res://tools/rock_lab.tscn` in the Godot editor. The Inspector exposes role, seed, size, roughness, facets, and
flatten. The row shows every archetype; the wall and crossing below it exercise the fitting functions. Edit one
reference at a time—start with `wall_stone` and `boulder`—then toggle `save_archetype`. Only after the silhouette is
convincing should seeds and fitting variations be explored.

`wall(from, to, height, seed)` returns bottom stones, filling courses, and caps sized to slots. `crossing(points,
width)` returns level stepping stones. `scatter(area, density, role)` returns sunk ground placements. Meshes cache by
role, quantised size, seed, and archetype data. The bake fingerprint includes the factory and the data file's use is
documented in the report.

## Game usage and performance

Garden loose rocks and wall stones use the factory. Woods loose rocks inherit that route; forest-floor cobbles, creek
stepping stones, and ridge outcrops use it directly. Existing placement/RNG layout remains unchanged and static walls
still merge by material.

The prior documented renderer baseline was approximately 860k garden primitives and 3.13M woods primitives. A same-
machine before/after total could not be collected in this sandbox: headless Godot exits before `detail_census.gd`,
`woods_cost.gd`, or the world benchmark emits their totals, and no X server is available for a renderer capture. The
rock-only geometry is now bounded by the table above; Claude should run those tools on the normal machine and record
the resulting garden/woods totals in the dated report before shipping.

For visual review, run `tools/rock_shots.gd` under X with the Compatibility renderer. It writes a six-row by
three-variation grid to `docs/codex/shots/rocks_grid_v3.png`.
