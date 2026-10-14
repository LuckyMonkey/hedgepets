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

## GPU (RTX 3050, 540×960 window, 1080×1920 viewport, vsync off), 3 runs each

Raw data: `tests/results/2026-10-14_bench_gpu.jsonl`. These are 300 timed frames after a 30-frame settle. Firefox
was busy on the same desktop, so the spread is wide; ranges are given, not best runs.

| | A garden | B garden | A woods | B woods |
|---|---|---|---|---|
| Mean frame | 11.4–14.9 ms | 7.4–11.1 ms | 14.5–16.7 ms | 13.6–18.5 ms |
| p50 | 9.9–12.3 ms | 6.4–8.1 ms | 12.8–14.1 ms | 11.5–16.0 ms |
| p95 | 22.1–30.0 ms | 16.9–24.6 ms | 24.9–31.4 ms | 26.6–35.6 ms |
| p99 | 28.9–38.6 ms | 21.3–45.3 ms | 33.8–39.5 ms | 34.2–41.2 ms |
| 1% low | 24–30 fps | 19–42 fps | 23–28 fps | 21–29 fps |
| Draw calls | ~3064 | ~2785 | 2490–2760 | 2330–2560 |
| Primitives | 2.68 M | 2.39 M | 7.2–7.6 M | 6.8–7.2 M |
| Video memory | 237–243 MB | 255 MB | | |

### What this shows (verified)

- **Draw calls are high**: about 2800 in the garden and about 2500 in the woods. That's the main CPU-side rendering
  cost to investigate (batching / merging candidates), and on mobile WebGL it will dominate.
- **The woods are the heavy place**: about 7 M primitives, with 1% lows in the 20s even on the RTX 3050. A phone
  will struggle here first.
- **Frame pacing is uneven in every mode**: p95 is about 2.5× p50. The spikes need a profiler pass (per-frame
  scripts? GC? MultiMesh updates?).
- **A and B don't draw the same garden.** A (built live) issues about 280 more draw calls and about 290 k more
  primitives than B (from the cache), consistently across runs. Either the baked cache no longer matches what the
  generators produce, or live generation creates extra objects. Not yet explained. Next step: a golden capture
  with `BENCH_MODE=procedural`-style bypass compared against the cached baseline. This matters because the editor
  (live) and the shipped game (cached) may not look identical.

## Not yet measured

- Time spent per subsystem (profiler): scripts vs rendering vs audio.
- The web build: load time, first-visit shader compile (about 19 s per `docs/MOBILE.md`), memory.
- Mobile browser and native export.
