# Map compilation benchmark: procedural vs cached vs compiled

All three must build the same world: the same seed, hour, camera and golden views.

| | A: procedural | B: cached | C: compiled scenes |
|---|---|---|---|
| What it is | Generators run live (`BENCH_MODE=procedural`) | The existing BakeCache (`garden.res`) | Static props / walls / fences saved as PackedScenes |
| Garden build (headless, median of 3) | 37.4 s | 3.69 s | not built |
| Woods build | 6.37 s | 1.11 s | not built |
| Nodes | 4144 | 4144 | — |
| Steady static memory | 181 MB | 255 MB | — |
| Visual parity | **Unverified: draws more than B** (see PERFORMANCE_BASELINE) | **Golden-exact** (tests/results) | — |
| GPU garden p50 / draw calls | 9.9–12.3 ms / ~3064 | 6.4–8.1 ms / ~2785 | — |
| GPU woods p50 / draw calls | 12.8–14.1 ms / ~2600 | 11.5–16.0 ms / ~2480 | — |

## What the numbers say so far (verified)

B already removes 90% of the build time. What's left of B's 3.7 s editor-mode build is:

- grass 1.3 s (cached only in exports, so it's lower there);
- the backdrop 0.84 s, mostly node and MultiMesh construction from cached meshes;
- `_start_game` 0.4 s;
- the ground 0.3 s.

**So the most C could save is the node construction inside B's ~2 s**, and only if loading a PackedScene beats
building nodes in GDScript. It can't beat B at generation, because B does no generation.

## Hypothesis to test next (not a result)

- Compile the backdrop's static output (the `bake_static` results, the tree wall and the burying ground) to one
  PackedScene, keeping the same merged meshes and MultiMeshes so batching is preserved.
- Time `load()` + `instantiate()` against the GDScript construction, on desktop and on the web, and compare the
  golden views.
- Keep C only if it wins on the web, where GDScript is slowest.

## The woods, compiled (2026-10-14, measured)

`tools/compile_woods.gd` builds the woods once. It saves their static geometry to `res://world/woods_compiled.scn`:
the ground, trails, litter, the creek home, the trees, the undergrowth, and the 1:16 land's world (without clouds).
It also saves the generator state after each step and a fingerprint of the generator code. With that file present,
`woods.gd` loads those parts instead of generating them, and builds everything interactive by code as before.

| | Live (from the bake cache) | Compiled |
|---|---|---|
| Woods build (desktop) | 3.3 s | **0.7 s** |
| Looks | | Identical, except the colours of some trail leaves, which use Godot's global RNG and vary between live builds anyway |
| Startup cache `garden.res` | 52.7 MB | 33.9 MB (woods not baked) |
| Compiled file | — | 34.3 MB (39 MB raw is the trees' leaf cards) |
| Web package (gzip) | 67.9 MB | 84.2 MB (**+16 MB**) |

Where the woods' build time goes:

- the 1:16 land's world: 1.34 s;
- places (props, signs, clearings): 0.57 s;
- ground, trails and litter: 0.47 s;
- trees: 0.33 s;
- undergrowth: 0.12 s.

**To ship it:** `touch world/woods.lock world/woods.compile`. `deploy_web.sh` then compiles before baking, and the bake
skips the woods. `woods.lock` keeps a compiled woods even after the generator code changes (a saved version).
Without the marker files, nothing changes.

**Shrinking it:** the leaf cards are copies of a few crown templates, one per leafy tree near a trail (up to 110 of
them). Storing one transform per tree instead of every leaf would cut the file to a few MB, but expanding them at
load time needs a fast path (a GDExtension or a shader-instanced crown) to stay quick on the web.
