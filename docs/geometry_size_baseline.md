# Geometry size baseline and results (parametric / chirality runbook, 2026-10-14)

All numbers were measured on this machine (i7-3770, RTX 3050, Godot 4.7.2), at commit 0ff627f plus the uncommitted
changes listed below. MB = 10^6 bytes.

## Phase A: what the download is made of

| Artifact (production export, 0ff627f) | Raw | gzip-6 | Brotli-9 | Measured transfer from fridge (nginx gzip) |
|---|---:|---:|---:|---:|
| index.pck | 74,983,664 | 68,279,970 | 61,052,620 | **68,425,398** |
| index.wasm (engine) | 39,514,754 | 10,114,291 | 7,996,785 | **11,747,624** |
| index.js, html, worklets | 302,329 | 76,969 | 72,084 | ~88,114 |
| **First load** | | | | **≈ 80.3 MB** |

**The cache.** `index.pck` is almost all `assets/baked/garden.res` (50.7 MB, already zstd-compressed inside, so
gzip barely touches it). By label and generator (build/cache_manifest.json, tools/bake_cache.gd):

- garden: 24.8 MB zstd (FoliageBuilder 14.0, HedgeAnatomy 4.6, bushes 4.4, grass 1.5)
- woods: 13.7 MB (tree patches 11.9)
- 47 pets: 13.7 MB (HedgeAnatomy 11.4, FoliageBuilder 2.2); the largest is 0.39 MB, the smallest 0.13 MB.

**Used vs shipped** (tools/cache_usage.gd: every runtime path – garden build, woods build, all 47 pets – with fetch
tracking):

- **21.0 MB zstd (998 entries) is never read.** These are the pieces of composite builds: a garden bush is cached
  whole (core + leaves) by `garden._bush`, and the FoliageBuilder and HedgeAnatomy results inside it were cached
  again; the same applies to the meshes inside `GardenProps.blob`.
- The game reads the composite only. The 1.5 MB grass entry is read only in exports, so it stays.

## Phase C: symmetry and repetition

- **Pets.** Mirrored regions are built from one mesh placed at mirrored positions: all 9 mirrored pairs located
  share a single mesh (no negative-scale instances). Across 47 pets there are 2,327 mesh instances and 926 distinct
  meshes, so primitive sharing already happens.
- **Leaf sets.** Each leaf set is seeded per region and is deliberately asymmetric. Mirroring them would change the
  look: not done.
- **Trees.** 519 trees use 15 crown templates placed 1,535 times, but the patches store every placement expanded.
  This is the biggest remaining repetition (12.7 MB zstd). Instancing it would mean a leaf-shader variant and
  regrouped batching: a rendering change, deferred.
- **Bushes.** Each bush is unique per seed. The saving was the duplicated pieces, not symmetry.

## Changes (uncommitted, all reversible)

| File | Change |
|---|---|
| `scripts/util/bake_cache.gd` | Composite builds don't record their pieces (`begin_composite` / `end_composite`); entry labels + fetch tracking for diagnostics (never shipped); fingerprint extended to `garden.gd`, `woods.gd`, `woods_trees.gd` (the generators whose keys don't capture everything) |
| `scripts/garden/garden.gd` | `_bush` marks its build as a composite; `node_for` builds visitors lazily in the compact profile |
| `scripts/garden/garden_props.gd` | `blob` marks its build as a composite |
| `scripts/pet/hedge_pet_node.gd` | Lazy, budgeted, hidden recipe materialisation (`sliced`), used only when `hedgepets/pets_baked = "starters"`; default `all` (unchanged behaviour) |
| `tools/bake_cache.gd` | Labels, `build/cache_manifest.json`, starters-only bake in the compact profile |
| `tools/cache_usage.gd`, `tools/pet_parity_check.gd`, `tools/visitor_stall.gd`, `tools/size_manifest.py` | New diagnostics and gates |

## Phase F: A/B results

| Metric | Production (0ff627f) | BASELINE (pieces dropped, all pets baked) | COMPACT (starter pets only) | Method |
|---|---:|---:|---:|---|
| garden.res | 50.7 MB | **35.8 MB** | 22.8 MB | bake_cache.gd |
| index.pck raw | 74.98 MB | 59.38 MB | 45.73 MB | export |
| First load, gzip-6 | 79.3 MB (80.3 measured on fridge) | **62.9 MB** (~64.5 at nginx's gzip level) | 49.8 MB (~51.4) | size_manifest.py |
| First load, Brotli-9 (not served) | 69.9 MB | 53.6 MB | 44.0 MB | size_manifest.py |
| Cached garden start (headless) | 3.46 s | 2.84–2.94 s | — | bake_cache.gd |
| Firefox headless, local, cache off: to playable | 15.1 s (build 8.7 s) | 14.1 s (8.2 s) | 14.1 s (8.2 s) | `garden ready` log |
| Visitor first appearance, worst frame (GPU) | — | 32–51 ms | **150–330 ms** (whole after 0.5–0.8 s) | visitor_stall.gd |
| Woods entry with 6 wild pets, worst frame | — | 437 ms | **669–759 ms** (whole after 5 s) | visitor_stall.gd |

## Parity

- **Golden garden views (llvmpipe, `tests/baseline/3a21a13`):** BASELINE gives 17/17 still views pixel-identical.
  The 4 late orbit frames (`moving_08`–`11`) differ by a butterfly, and they differ just as much between two runs of
  the same build, so this is a pre-existing harness flaw: butterflies draw from the global RNG every frame.
  COMPACT against BASELINE: 21/21 identical.
- **Cache contents:** every kept entry is byte-identical to before (1,343 of 1,343 after the first step); only
  never-read entries were dropped. A rebake with an unchanged generator gives identical content.
- **Pets built from their recipe against the baked ones:** 47/47 identical across mesh streams, MultiMesh buffers
  and transforms (pet_parity_check.gd).
- **Checks, BASELINE profile:** game, yard, life, den, hide and motion all pass.
- **Checks, COMPACT profile:** `yard_check` FAILS. A regraft right after a pet appears is queued until the pet has
  finished growing.

## Decision

- **BASELINE: adopt.** About 16 MB less on the first load, with identical output and a faster start.
- **COMPACT: do not ship.** First-appearance stalls of 0.15–0.76 s on a desktop (a phone would be worse) and a timing
  change to regrafts. It stays behind `hedgepets/pets_baked` (default `all`). Making it viable means slicing inside
  `FoliageBuilder.build`, where a single region takes up to ~300 ms.

## Not tested

- Real phone and mobile browser: NOT TESTED.
- Network-throttled load: NOT TESTED; the local Firefox runs show build time only.
- Memory, GPU frame pacing on the web: NOT TESTED.

## Foliage restoration (2026-10-14): the same forest, kept exactly

### Root cause of the missing leaves, and prevention
- **Cause:** `tools/bake_cache.gd` runs headless, and headless Godot keeps no MultiMesh instance data. Every MultiMesh
  saved into `garden.res` (garden bushes, woods tree patches) was saved empty, so production's cached bushes and
  trees showed only their dark cores. The bake's "round trip identical" was vacuous: both sides read back empty. A
  MultiMesh loaded from a resource also reads back zeros to scripts on a GPU, so readback can't verify it either.
- **Fix:** foliage is cached as numbers, never as a MultiMesh. Bushes store `[leaf floats, count, mass vertices,
  mass normals]`; woods patches store `["leaves", floats, sheet, count, origin]`. `HedgeAnatomy.grid_mesh()` puts
  back the exact mass mesh (the uvs and triangles are the same for every grid).
- **Prevention:** `tools/foliage_validate.gd` runs inside the bake, before saving and after reloading. It rejects
  any MultiMesh with instances, any empty or degenerate leaf set, and any mismatch between the leaves the
  generators made and the leaves read back (the bake exits 1). `tools/foliage_bake_check.gd` reopens the bake in a
  separate process, checks it against the counts the bake recorded (`build/cache_manifest.json` "foliage"), and
  self-tests that a populated headless MultiMesh is caught. On the old production bake it reports 483 problems; on
  this one, 0 (484 leaf sets, 432,117 leaves).

### Precision: exact by default
- `hedgepets/foliage_precision` = `full` (default) or `half`. Half floats about each bush's centre were 1.6 MB
  smaller but not equivalent: leaf-card edges flipped across canopies (mean pixel difference 0.04–0.64 of 255).
- Exact mode against the original procedural build (A: HEAD code, BakeCache off; B: new bake), same seeds, hour
  and cameras, 30 golden views:
  - garden still views: 1–5 pixels, each off by 1/255;
  - canopies: identical;
  - woods: a few litter finds differ. They come from Godot's global `randf()` (woods.gd 2183–2192), which
    differs between any live and cached run, even with identical code (measured).
- Exact-baked against exact-rebuilt (below): identical in every view.

### Experiment (accepted): woods patch masses rebuilt from their clusters
`hedgepets/woods_mass` = `rebuilt` (default) or `baked`. A patch's dark-mass mesh is copies of 15 cluster masses,
1,535 placements. The trees are planned even when a patch is cached, so `finish()` appends the same clusters in
the same order, one patch at a time (low peak memory), with the same `SurfaceTool` calls.

| | baked | rebuilt |
|---|---|---|
| `garden.res` | 64.6 MB | 48.6 MB |
| 139 woods meshes, sha256 of vertices, normals and indices | 6c749ce0… | 6c749ce0… (identical) |
| Woods build, synchronous (GPU bench) | 621 ms | 962 ms |
| Background prebuild total / worst frame | 1.46 s / 70–80 ms | 1.81 s / 68 ms |
| Woods frame p99 / memory / peak | 20.0 ms / 260 MB / 321 MB | 20.6 ms / 260 MB / 321 MB |

The first attempt kept every patch's SurfaceTool alive (peak +155 MB) and failed the memory criterion. The fix
builds one patch at a time. `finish()` is now time-sliced (`Slicer.tick`) in both modes.

### Sizes (decimal MB)

| | Production (leafless) | Now (full foliage) |
|---|---|---|
| `garden.res` | 53.1 | 48.6 |
| First load, gzip-6, local export | 78.4 | see below |
| First load, live transfer (nginx) | 80.3 | not deployed |

Composition now (each piece zstd-compressed alone): garden bushes 16.9 (leaves 32-bit and exact masses), pet region
meshes 12.0, woods patch leaves 9.3, pet foliage items 2.3, grass 1.6, woods props 1.0, woods trunks 0.85, woods
cluster bushes 0.42. Woods patch masses: 0 (rebuilt).

### Runtime (RTX 3050, GPU window, cached; two runs each)

| | Production | Now |
|---|---|---|
| Garden startup | 5.27–5.41 s | 4.06–4.11 s |
| Garden draw calls / primitives | 3,240 / 1.87 M | 3,720 / 2.33 M (the leaves are back) |
| Garden frame p99 | 17.3 ms | 24.9–25.7 ms (the leaves are back) |
| Woods entry worst frame | 479–613 ms | 426–431 ms (pre-existing hitch) |
| Memory / peak | 263 / 321 MB | 265 / 322 MB |
| Uncached (procedural) startup | 58.1 s | 60.5 s |

### Fixes made alongside (owner reports)
- **Woods sky going dark, an edge across it:** the 1:16 land's ground was a coarse fan under the woods. In 271 of
  1,034 trail samples the sky camera was *below* it (by up to 5.4 m). The miniature ground now sinks well under
  the woods' own ground (drawn over it) and meets it exactly at the woods' edge, with dense rings across the woods.
  `tools/sky_clip_check.gd`: 0 of 1,034.
- **Garden skybox square edge:** real lawn pieces behind the fence painted over next door's houses (real things
  draw over the skybox). The east and west pieces now stop short of next door's yards. The real creek ends at the
  fence line and continues in the skybox (neighborhood.gd `_creek`); next door's shed and house moved off its
  course. The five tall trees behind the houses are built as before, then moved into the skybox (`adopt`).
- **The nursery:** the pine flats' plateau (4.4 m higher) cut through its clearing, and its trail to the pines ran
  through the layout. The nursery now faces away from both its trails, onto level ground; the glasshouse moved to
  8 m; the camera turns to it on arrival.

### Next
1. Pet region meshes (12.0 MB): keep vertices and normals only, through `grid_mesh` (lossless; estimated −5 MB).
2. Woods patch leaves (9.3 MB): copies of the cluster leaf sets. Rebuilding them is a GDScript loop over 189k leaves
   (cost not measured yet).
3. The woods-entry hitch (430–610 ms, pre-existing).

Not tested: phones, mobile browsers, throttled networks, web memory and frame pacing.
