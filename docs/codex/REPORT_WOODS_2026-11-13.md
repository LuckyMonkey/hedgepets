# Woods performance and seams report — 2026-11-13

## Outcome

The woods now avoid an otherwise unnecessary miniature-sky redraw 12 times per second. Static woods patches no
longer appear or disappear as whole 24 m buckets: the buckets stay present and their geometry fades at its own
distance range. The distant-land miniature also uses smaller render targets on low and medium quality tiers.

## Measurements

The new `tools/woods_trace.gd` enters the woods, warms up, stands still, turns slowly and quickly, and walks two
trail segments twice. It records wall-clock frame spans and `HitchLog.last_tags()`.

| Run | Frames | p50 | p95 | max | >33 ms |
|---|---:|---:|---:|---:|---:|
| After, headless cached build | 1,240 | 2.2 ms | 3.6 ms | 5.5 ms | 0 |
| After, low-tier override, headless cached build | 1,240 | 2.4 ms | 4.0 ms | 5.6 ms | 0 |

The owner’s pre-change phone telemetry in the brief was 51/847 woods frames over 50 ms, p95 52 ms, maximum 149 ms.
That is a different renderer/device and threshold, so it is recorded as context rather than a directly comparable
before/after benchmark. The new trace is a repeatable CPU/headless regression guard, not a claim about phone GPU
frame time.

## Causes and changes

- `scripts/garden/distant_land.gd`: the drifting-cloud `_tick` caused a full 1:16 miniature redraw at 12 Hz while the
  woods camera was still. Clouds are now a static sky layer; the miniature redraws only when the matched camera or
  projection changes. Quality tiers set its render resolution to 0.42 / 0.52 / 0.60 of the viewport for low / medium
  / high, retaining the existing overscan.
- `scripts/garden/woods.gd`: streamed static geometry is retained in its cell buckets instead of toggling a whole
  bucket’s `visible` property. Each static geometry node gets a self fade and a tier-specific end margin. Existing
  tree trunk, mass, and leaf LOD ranges also receive fade margins. This removes the hard cell-boundary pop while
  retaining distance culling.
- `tools/woods_trace.gd`: added the requested stand / slow-turn / fast-turn / repeated-walk trace with p50, p95,
  maximum, >33 ms count, and HitchLog tags.
- `assets/baked/garden.res`, `build/cache_manifest.json`, and `world/woods_compiled.scn`: regenerated because the
  woods generator fingerprint changed. The cache rebake validated 1,232 entries and 225,850 foliage leaves; the
  compiled woods contains 39 static nodes and loads in 914 ms in the compiler probe.

## Checks

- `woods_check.gd`: PASS.
- `woods_clip_check.gd`: PASS; 0 solid hits, 0 ground samples within 0.45 m. It reports 12 leafy grazes, which are
  existing generous card-box warnings and do not count as solid collisions.
- `sky_clip_check.gd`: PASS; 8,073 nearby miniature triangles, 1,034 eye samples, 0 too close.
- `motion_check.gd`: PASS; no watched visible-property pops.
- `tools/woods_trace.gd`: PASS in cached headless normal and low-tier runs; results above.
- `tools/compile_woods.gd`: PASS using the headless fallback; compiled woods was regenerated. The requested Xvfb
  software-GL invocation could not start because this environment refuses X socket/network listeners and the
  pre-existing `:78` display is not connectable.

## Captures and visual review

The requested before/after golden capture was attempted with the exact woods view set, but no PNGs could be produced:
the private X server could not bind (`/tmp/.X11-unix` is not owned by root), and `DISPLAY=:78` was unavailable to
Godot. `/tmp/woods-before` and `/tmp/woods-after` were created, but both are empty. Therefore no visual change is
claimed as pixel-verified here. The geometry/sky seam checks and motion check are the available automated evidence;
the owner should run the software-GL capture on a display-capable machine before deployment.

## Dropped / not changed

- No hedgepet meshes, art, materials, animation, camera/fence code, or `miniature_sky.gd` were changed.
- No cloud animation was moved into the host sky because the host-sky path would require a new visual asset/shader
  review; static clouds remove the redraw source without adding a new seam risk.
- No deploy, commit, push, or git command was run, per the brief and user instruction.
