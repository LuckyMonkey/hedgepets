# World architecture (verified 2026-10-14, at f72b9bd)

Phase 0 of the world-editor / filmmaker / performance runbook: what the code actually does today. Verified facts
first. Hypotheses are labelled as hypotheses.

## Verified

| System | Where | How it is built |
|---|---|---|
| Entry | `garden.tscn` → `scripts/garden/garden.gd` | Tiny root scene; `BUILD_STEPS` (12 steps) builds everything in `_ready`. Staged (a frame per step behind `loading_card.gd`) in exports or with `HEDGEPETS_STAGED=1`; all at once in the editor/headless. |
| Randomness | `garden._rng` seeded `20261008` | **One shared RNG, drawn in build order.** Props, fences, walls, sticks, rocks and grass all draw from it sequentially. Changing an input or the order of an earlier call shifts every later object. |
| Garden props | `garden._build_props`, `garden_props.gd` | Each prop is a node and an entry in `garden.things`, as `{id, kind, node, at, radius, junk, value}`. `id = "<kind>_<index>"` (the index into `things`). The wheelbarrow is appended last, on purpose, "so earlier things keep their ids". Placed (player-built) things get `placed_<usec>_<rand>`. |
| Static merging | `GardenProps.bake_static(node)` | Merges a prop's child MeshInstances into one mesh per material, under the same root node. The root's transform still places it, so a merged prop can still be moved as a whole. |
| Fences / walls | `FENCE_SECTIONS` (5 sections), 2 stone walls | Baked static. The fence sections are mendable and rebuilt by `mend_fence`. |
| Grass / lawn | `_build_grass`, `_build_ground` | MultiMesh; the grass buffer is cached in BakeCache (its own 20-float layout). |
| Bush / tree foliage | `garden._bush`, `FoliageBuilder`, `HedgeAnatomy` | Cached by a key over every input (`BakeCache.key`). |
| BakeCache | `scripts/util/bake_cache.gd`, `tools/bake_cache.gd`, `assets/baked/garden.res` | **Exists as described.** Key = hash of the inputs; SALT = hash of the generator sources (editor rejects a stale bake; exports trust it). Startup from cache: 3.75 s on this machine under llvmpipe (1427 hits, 0 misses). |
| Woods | `scripts/garden/woods.gd` (1976 lines), `woods_trees.gd`, `elsewhere.gd` | `NODES` (9 places) and `EDGES` (10 trails); **matches the runbook.** Built on first visit, in steps (`build_steps()`); trees merged per 24 m patch, as MultiMesh leaf cards, with fixed-seed RNGs per builder. |
| Skybox | `scripts/garden/distant_land.gd`, `shaders/distant_sky.gdshader` | `SCALE = 16`, `RES = 0.6`, in its own SubViewport + camera copying the woods camera (position / 16), composited per pixel by direction. Built once (fixed seeds); renders only in the woods. **Matches.** |
| Camera (garden) | `garden._place_camera` | An orbit: `_target`, `_yaw`, `_elev`, `_distance` (each eased toward `_goal_*`), FOV 46, `KEEP_WIDTH`. Close zoom lowers the elevation. |
| Camera (woods) | `woods._at`, `_yaw`, `_pitch`, `_settle`, `walk()` | Eye-level, walking the trail polylines (`_paths`). |
| Sun / time | `garden.sun_at(hour)` | Follows the **wall clock**; `HEDGEPETS_HOUR` pins it. |
| Sound | `scripts/garden/soundscape.gd` | A looped wind recording plus random events (gap ranges per event), positioned at "trees" / "houses" / "road" / "town". |
| Motion | `scripts/anim/motion.gd` | Every visible transition eases; `Motion.speed = 0` makes them instant (tools). |
| Save | `garden_game.gd` `save()` / `_load()`, `user://garden.json` (+ localStorage on the web) | Holds game state (cleared junk, placed things by id, plants, pets). |
| Shaders using TIME | grass, lawn, leaf, leaf_ink_shell, creek, water, light_shaft | Their animation depends on engine time, so captures must step a fixed number of `--fixed-fps` frames. |
| Per-frame scripts | 20 files with `_process` | garden, garden_game, woods, pet nodes, soundscape, butterflies, porch watcher, … Not yet profiled. |
| Renderer | `gl_compatibility` (desktop and mobile); viewport 1080×1920, window 540×960, stretch `canvas_items` | |
| Tests | `tools/*_check.gd` (headless, `--fixed-fps 60`), `tools/capture_*.gd` | No golden-image regression existed before `tools/golden_capture.gd` + `tools/image_compare.py`. |

## Consequences for the editor

- **Stable IDs:** `things[i].id` is stable as long as `_build_props` keeps its call order. That is the existing
  contract (see the wheelbarrow comment). Objects without a `things` entry (fence sections, walls, trees, grass,
  woods trees) have no ID yet.
- **Overrides must be post-build.** Changing a prop's inputs (its position argument) would not change the RNG draws.
  But adding, removing or reordering calls would. So an authored override moves the already-built node (and
  updates `at` / obstacles); it never feeds into generation. Deleting means hiding plus `things.erase` after the
  build, never skipping the build call.
- Player-arranged things (`arrange_*`) and authored overrides are different layers: authored data is the world
  definition (res://, versioned); the player's save stays the player's.

## Hypotheses (unmeasured)

- Startup is dominated by grass (1.6 s) and backdrop (1.1 s) even from cache, under software GL. On a GPU, and on
  the web (shader compile ~19 s on first visit, per `docs/MOBILE.md`), the split will differ.
- The existing BakeCache already gives "B: precomputed world data". "C: compiled scenes" would mostly save node
  construction time, which needs measuring.
