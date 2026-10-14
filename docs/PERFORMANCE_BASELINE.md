# Performance baseline

Measured 2026-10-14 at commit 69c9791. The game code is unchanged from f72b9bd apart from no-op hooks.

**Machine:** i7-3770 (8 threads, no AVX2), RTX 3050. Firefox was using about 1.2 cores at the time; the
spread across runs stayed within ±1.5%.

**Tool:** `tools/bench_world.sh out.jsonl 3 "procedural cached"`, which runs `tools/bench_world.gd` once per
process. The raw data is in `tests/results/2026-10-14_bench_headless.jsonl`.

## Headless (build cost, nodes, memory), 3 runs each, medians

| Metric | A: procedural (BakeCache bypassed) | B: cached (as shipped) |
|---|---|---|
| Garden build | **37.4 s** (36.5–37.5) | **3.69 s** (3.66–3.71) |
| Woods build (first visit) | 6.37 s | 1.11 s |
| Largest step | backdrop 32.4 s | grass 1.31 s |
| Cache hits / misses (garden) | 958 / 1221 (958 = this run's own reuse) | 1427 / 0 |
| Nodes: garden / with woods | 1961 / 4144 | 1961 / 4144 |
| Static memory: garden / with woods | 108 MB / 181 MB | 219 MB / 255 MB |
| Peak static memory | 422 MB | 291 MB |

## Verified findings

- **The cache already gives a 10× faster garden build and a 5.7× faster woods build**, with an identical scene: the
  same node count, and pixel-exact against the golden views.
- **The cached build holds about 110 MB more memory in steady state**: `BakeCache._data` (the whole `garden.res`)
  stays loaded for the life of the game. It's still needed later (the woods, and pets arriving), so releasing it is
  an optimisation candidate, not a free win. It needs measuring: release it after the woods are built and all pets
  are cached, or split the cache per place.
- **Grass is only served from the cache in exports.** `garden.gd:842` reads the grass cache only when recording or
  when the generator source can't be read (an export). Editor and headless runs build the grass live (1.3 s), so
  editor timings overstate an exported build's cost by about that much.
- Draw calls, primitives and frame-time percentiles need a real renderer. The tool measures them with `--gpu`, which
  hasn't been run yet (it opens a window on the desktop).

## Not yet measured

- Frame times on the GPU (mean / p50 / p95 / p99 / 1% low, draw calls, primitives), garden and woods.
- The web build: load time, first-visit shader compile (about 19 s per `docs/MOBILE.md`), memory.
- Mobile browser and native export.
