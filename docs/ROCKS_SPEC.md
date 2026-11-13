# Rocks: the owner's spec (2026-11-13) - this overrides the first brief where they differ

A rock is **defined, not improvised**: randomness selects plausible geological variations of a rock that already
looks right; it never decides whether the object resembles a rock. **Very low poly** (owner: "we want lower detail" - "not that many
fucking triangles please"): a rock is a handful of big facets, painterly (`docs/ART_DIRECTION.md`). The silhouette
comes from a few well-placed planes, never from triangle count.

## The five operations, in this order

1. **Mass:** NO icosphere. The convex hull of ~10-14 points spread over an irregular ellipsoid (aspect from the
   archetype) - already a rock-like polyhedron of ~16-24 triangles.
2. **Structural fractures (the missing ingredient):** a handful (3-6) of coherently oriented cutting planes that
   FLATTEN regions into large facets (project the vertices beyond a plane onto it). Role-biased: wall stones get two
   near-parallel beds and a face; stepping stones a level top; ledges stacked strata planes.
3. **Controlled low-frequency deformation:** a gentle nudge of the hull's few vertices by ONE broad coherent noise,
   capped at a small fraction of the rock's size (<= 8%). No per-vertex randomness. **No spikes, ever** (clamp, and
   reject any vertex further from the centre than the archetype's hull allows).
4. **Weathering:** blunt only the very sharpest corners (cut a tiny plane off a corner, at most 2-3 per rock - each costs
   triangles) and soften the normals a touch; keep the big flat facets. Fractured long ago, a little eroded: not a marshmallow, not a crystal.
5. **Micro detail in the shader, not the mesh:** grain, a few cracks, lichen/moss on top faces, restrained colour
   variation by world position, one rock material (`shaders/rock.gdshader`) shared by all rocks, tinted per stone
   through instance/vertex colour. The geometry handles the silhouette; the material handles the mineral.

## Budgets (hard limits)

| Archetype | Triangles (hard cap) |
|---|---|
| cobble / scree (MultiMesh) | 8-16 |
| wall_stone, cap_stone, stepping_stone | 12-30 |
| boulder | 20-48 |
| ledge / outcrop piece | 24-60 |

A rock over its cap is a bug: the generator must reject or simplify it.

Flat-ish shading (facet normals or lightly smoothed) so facets read. Merge per wall / per cell (one mesh per material).

## Rocks as data

Archetypes live in a data file (`data/rocks.json` or a `.tres`), e.g.:

```json
{"weathered_boulder": {"hull_points": 12, "aspect": [1.3, 0.85, 1.1], "fracture_planes": 5, "deformation": 0.06,
  "weathering": 0.35, "preserve_facets": true, "material": "granite", "max_triangles": 48, "max_displacement": 0.08}}
```

The rock lab (`tools/rock_lab.tscn`) edits these values live in the inspector and saves them back to the data file.

## Process (insist on this)

1. Build **ONE convincing reference rock** per archetype first - start with `wall_stone` and `weathered_boulder`.
   Lock its silhouette, fractures, weathering, normals and material. Show it in the rock lab.
2. Then introduce **one variable at a time** (seed, aspect, fracture count…) with hard constraints that stop the
   generator from destroying what already looks good (triangle cap, displacement cap, minimum facet size, no spikes,
   no slivers).
3. Only then generate the library of variations (a small number per archetype, cached, instanced) and the fitting
   functions (walls like a puzzle, crossings, scatter).

Claude judges the look in captures; Codex keeps the numbers inside the budgets.
