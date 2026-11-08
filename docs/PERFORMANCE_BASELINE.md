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

## 2026-11-08: browser/mobile render safety pass

The measured weak-GPU baseline for this pass was the Intel HD 5000 / 720×1280 SubViewport run from the performance
brief: garden **~120 ms/frame, 1100 draws, 860k primitives** and woods **~145 ms/frame, 1885 draws, 3.13M
primitives**. With directional shadows disabled it fell to **~17–24 ms / 353 draws / 243k primitives** in the
garden and **~99 ms / 1180 draws / 1.78M primitives** in the woods. A post-change renderer run is still pending in
this environment because the changed generator fingerprint forces the full live cache bake before timing.

The shipped changes are:

- Garden hedge leaf cards and woods leaves never enter the shadow map. Large static forms retain one short
  orthogonal shadow split (28 m in the garden, 24 m in the woods); lawn dapple and contact blobs preserve the soft
  miniature shade outside it.
- Woods trunk, crown-mass and leaf patch nodes are independently distance culled at 82 m, 72 m and 48 m. The near
  trail view is unchanged; far detail resolves into the existing haze and merged crown masses.
- The `Quality` autoload watches half-second median frame samples. After two seconds over 22 ms it eases through
  0.75× and 0.6× 3D scale, then eases the tilt-shift mix off and disables remaining dynamic shadows. Recovery waits
  five seconds below 15 ms. Web canvas DPR is capped at 2.

Run `tools/render_cost.gd` with an X display after the cache bake to record the after numbers. It intentionally does
not use GPU timer queries because Mesa stops drawing after a short period on the target hardware.

## 2026-11-08: round 2

The real-display measurement after round 1 was **garden ~1050 draws / 770k primitives**; with live directional
shadows disabled it was **~350 draws / 243k primitives**. The original comparison was garden **1100 / 860k** and
woods **1885 / 3.13M**, with woods at **1180 / 1.78M** when shadows were disabled. This environment has no X11 or
Wayland display, so round-2 GPU draw/primitive numbers could not be collected here; the headless renderer reports zero
for those counters and is not a valid substitute.

Round 2 removes the live sun shadow maps entirely. `tools/bake_shadows.gd` creates deterministic garden and woods
shadow atlases under `assets/baked/`, and the lawn, grass, woods ground, path and litter materials multiply them at
the same soft 0.72 opacity. The atlas is intentionally low-resolution and blurred by linear filtering to preserve
the painted miniature look; pets retain their live contact blobs.

Woods static geometry is now grouped into 24 m proximity chunks. Chunks within 43 m of the camera remain visible;
walking changes visibility only, never rebuilds geometry. `tools/render_cost.gd` disables the adaptive `Quality`
autoload while measuring so scale/tilt-shift fallback cannot hide the renderer cost.

## 2026-11-08: round 3

The display measurement after round 2 was garden **466 draws / 305k primitives / ~20 ms** and woods **1094 draws /
1.03M primitives / ~72 ms**. Round 3 aligns the offline atlas projection with each scene's actual directional-light
travel vector, and includes the garden's authored props alongside trees and crowns. The woods proximity radius is now
33 m; merged trunks, crown masses, and leaf cards resolve at 68 m, 58 m, and 36 m respectively. The near clearing
remains unchanged while distant cells and leaf detail disappear into the existing haze.

The configured offscreen capture could not produce PNGs in this environment because Godot's headless dummy renderer
returns no SubViewport texture; the woods, clipping, and yard checks all pass. A real-display capture remains the visual
verification path for the next deployment.

## 2026-11-08: round 4

Detail is now an invisible three-tier choice. High restores full 3D scale, long woods visibility, distant leaf cards,
full grass, tilt-shift, and live directional shadows; Medium is the round-3 balance; Low uses a 0.75 3D scale, shorter
woods radius, fewer leaves, and reduced grass. The initial choice uses the adapter/CPU, then a fixed startup frame
sample refines it. The result is cached in `user://settings.cfg` for 14 days per GPU and is corrected only after long
hysteresis windows. `?detail=low|medium|high` and desktop `-- --detail=...` are hidden test overrides. The selected
tier and benchmark median are included in the existing `session` telemetry event.

The Web export now omits the compiled woods scene and woods atlas from the first pack and ships a separate `woods.pck`.
On first entry the Web build downloads it to the browser's persistent user filesystem and loads it with
`ProjectSettings.load_resource_pack`; desktop/editor builds continue using `res://` directly. The deployment script
exports both artifacts. The test resource-only pack was 3.6 MB before compression by the web server. The baked garden
shadow contribution was softened to keep
the centre of the lawn closer to the live-shadow comparison.

## 2026-11-08: round 5

The round-4 real-window probe found that Low still submitted 851k woods primitives (Medium: 865k), and its 0.75 3D
scale was slower in the small Compatibility window (22.8 ms versus 14.9 ms, with machine noise). Low now keeps a
1.0 scale and bypasses the tilt-shift sampling entirely. Its savings come from geometry: a 20 m stream radius,
shorter trunk/crown/leaf ranges, and 18% distant leaf-card density (55% only within 14 m). Leaf patches are stored
around their own authored origins, so renderer range and frustum culling no longer see every full-precision patch at
the trailhead. Quality changes recurse into streamed chunks and find a nested garden through the
`hedgepets_garden` group instead of assuming it is the current scene.

`tools/tier_primitives.gd` is the display-independent guard. It embeds the garden under a harness scene, applies all
three tiers through the group lookup, and counts visible geometry plus MultiMesh instances using streamed-parent
visibility and authored ranges. The regenerated compiled woods measured:

| Tier | Estimated visible triangles | Visible leaf instances | Visible leaf patches |
|---|---:|---:|---:|
| Low | **331,643** | **17,445** | 10 |
| Medium | 418,255 | 60,751 | 10 |
| High | 1,161,999 | 180,387 | 35 |

The guard requires Low to stay below 400k triangles and below 30% of Medium's visible leaf instances. A real-window
`tools/tier_cost.gd` rerun remains the authoritative GPU timing and submitted-primitive measurement.

### LightmapGI investigation

Godot 4.7's [Compatibility renderer](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html),
including Web exports, can display [LightmapGI](https://docs.godotengine.org/en/4.7/classes/class_lightmapgi.html)
data baked on another renderer. Baking itself is editor-only and uses RenderingDevice/Vulkan compute (Forward+ or
Mobile, or a temporary RD while an editor uses Compatibility). It is not available in an exported game or the
[Web editor](https://docs.godotengine.org/en/4.7/tutorials/editor/using_the_web_editor.html). This machine cannot run
that path: its headless display driver exposes only the dummy renderer, X11/Wayland are unavailable, and `xvfb-run`
is not installed. There is no command-line lightmap bake mode.

The current woods are also not bake-ready. Their procedural ArrayMesh and PrimitiveMesh surfaces have no UV2 unwrap,
are not marked for static baked GI, and are assembled into `world/woods_compiled.scn` by a headless tool. PrimitiveMesh
surfaces cannot be baked directly. LightmapGI therefore cannot replace `tools/bake_shadows.gd` without a new offline
mesh/UV2 pipeline. Texture cost is unmeasured until that exists; for scale, one uncompressed RGBA8 1024² page is 4 MiB
and a 2048² page is 16 MiB before any extra directional/shadowmask data or pack compression. That is material beside
the round-4 3.6 MB woods resource pack.

Decision: keep the small deterministic woods shadow atlas. The next safe experiment is an offline pilot on a
Vulkan-capable editor machine: convert one 24 m static chunk to UV2-unwrapped ArrayMeshes, mark it static GI, bake a
low-density 1024-page lightmap, export it to Compatibility/Web, and compare captures, frame cost, and compressed
`woods.pck` size. Scale it beyond one chunk only if the Web result is stable and adds no more than about 4 MB.

## 2026-10-24: hitches moved behind cards (`tools/hitch_trace.gd`)

The owner reported stutter, and stalls in the wrong places: during play instead of behind loading cards. Measured
headless (CPU only) with `tools/hitch_trace.gd`, which turns off headless Godot's ~6.9 ms per-frame sleep. **Earlier
headless ms/frame numbers, `garden_fps.gd` included, were mostly that sleep.**

| Where | Before | After |
|---|---|---|
| Garden, 40 s after load (woods prebuilding in the background) | max **183 ms**, many 30-70 ms frames | max **7.4 ms** (prebuild off) |
| Walking into the woods (already built) | **~390 ms** one frame, at the start of the fade-in | ~120 ms, under the dark veil |
| Woods built on the way in | the card froze for each whole step | 40 ms slices, the card moves (~1.6 s here) |
| A pet's build (visitor, wild) | 24-40 ms (+ CPU mipmaps of its leaf sheets) | 8-11 ms rebuild, 17-28 ms first |
| `garden._process`, 6 residents | 3.3 ms | ~1.2 ms |

What changed:
- **Woods prebuild is off by default** (`hedgepets/woods_prebuild`, project setting, default false). Some build steps
  are 50-180 ms in one piece (a tree patch, the static merge), so a 5 ms Slicer budget can't hide them. The woods
  build behind their own card when you walk in (`elsewhere._build_staged`, now sliced at 40 ms).
- **Leaf sheets are shared**: `Assets.mipmapped(path)` decodes and mipmaps a sheet once. Each pet used to do it for
  its own copy (~25 ms). The paddle tail's crosshatch is painted once too.
- **Pets' colliders**: trunks, walls and things are gathered once a frame (`garden._walk_colliders`), with a
  bounding-box reject. Same circles, same order, so the same pushes.
- **Under the veil**: `elsewhere.enter()` draws 3 frames before the fade-in, so first-draw shader compiles (the web's
  slow part) happen in the dark.

Pixel checks: the garden golden views and the orbit are pixel-exact against HEAD. The woods views differ only by the
wild pets' positions (they're 3 frames further along). Tried and dropped: building every post-load pet in slices. It
left "still building" pets that regrafting and pointer-noticing don't expect (`yard_check`, `life_check` failed).
