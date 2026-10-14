# Map compilation benchmark: procedural vs cached vs compiled

All three must build the same world: the same seed, hour, camera and golden views.

| | A: procedural | B: cached | C: compiled scenes |
|---|---|---|---|
| What it is | Generators run live (`BENCH_MODE=procedural`) | The existing BakeCache (`garden.res`) | Static props / walls / fences saved as PackedScenes |
| Garden build (headless, median of 3) | 37.4 s | 3.69 s | not built |
| Woods build | 6.37 s | 1.11 s | not built |
| Nodes | 4144 | 4144 | — |
| Steady static memory | 181 MB | 255 MB | — |
| Visual parity | Golden-exact (same generators) | **Golden-exact** (tests/results) | — |
| Frame times / draw calls | needs `--gpu` | needs `--gpu` | — |

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
