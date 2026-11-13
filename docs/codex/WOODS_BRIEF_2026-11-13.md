# Codex brief (2026-11-13): the woods - lag spikes, pop-in, broken seams

Read `AGENTS.md`, `docs/HANDOFF.md` (the owner's design rules are non-negotiable), `docs/PERFORMANCE_BASELINE.md`,
`docs/codex/REPORT_2026-11-12.md` if present, and `git log -5` is NOT available to you (no git): Claude reviews,
commits and deploys. Offscreen Godot runs ALWAYS take `--audio-driver Dummy`. Godot `~/.local/bin/godot` (4.7.2).
This laptop is a 2012 MacBook Air: the game must hold ~30 fps on it. You work in this worktree only
(`~/work/hp-woods`); another Codex works on gameplay in another worktree and Claude on the garden camera/fences:
**change only the woods and its distant land** (`scripts/garden/woods.gd`, `distant_land.gd`, woods shaders/assets,
`world/`), plus `miniature_sky.gd` only if you must (keep its OVERSCAN).

**Do not change the hedgepets themselves** (meshes, art, materials, animation) unless one is the proven root cause.

## What the owner saw (iPhone, Safari, after yesterday's deploy)

"There is pop-in in the woods, a lot of broken seams, and the lag spikes are still there for that part." The garden is
now a steady 30 fps on the phone. Telemetry (`frame_time` events, quality tier "low", dpr 3, canvas 1080x1920):

- garden: p50 33.3 ms, single hitches of 110-150 ms tagged `sky` (a miniature redraw that frame; the tag is set on
  every redraw, so it may be coincidence - verify).
- **the woods (the ~30 s window around when they went in): 51 of 847 frames over 50 ms while the camera was mostly
  still, p95 52 ms**, max 149 ms. In the woods, `distant_land.gd` `_tick` asks the miniature (375 trees + 61 snags +
  hills + clouds) to redraw 12 times a second for the drifting clouds - suspect #1.

## Do

1. **Lag:** measure the woods like `tools/pan_trace.gd` does the garden (write `tools/woods_trace.gd`: enter the woods,
   stand, walk/turn the camera the way the player does, slow and fast, twice; median/p95/max/frames > 33 ms, tags
   from `HitchLog`). Headless and windowed (software GL on a private X server, see below). Then fix the biggest
   causes: e.g. the distant land redrawn only when the view changes (clouds drifting at ~1-2 Hz or moved into the
   host sky instead of the miniature), its resolution on the low tier, anything built or first-drawn while you walk
   (streaming / lazy builds -> slice them like the pets, or prebuild behind the woods' loading moment), per-frame
   allocations. Tag new suspects in `HitchLog` so the phone telemetry names them.
2. **Pop-in:** find what appears/disappears visibly as you move (visibility ranges / LOD swaps / lazy spawns / the
   distant land vs the real near woods). Fix with fades (`visibility_range_fade_mode`, dithered fade) or wider
   margins, or by having the distant land cover the gap. Every visible change eases (scripts/anim/motion.gd rule).
3. **Broken seams:** find them in captures from many woods positions (trailhead, fork, ridge, oak, creek, home,
   pines, pond, lookout, plus turning 360 at each): where the near woods' ground meets the distant land's picture,
   terrain tile edges, cracks, the sky picture's edge (fallback colour). Fix them (overlap/skirts on terrain edges,
   matching colours/fog between the near ground and the miniature, overscan).
4. Keep the woods views: capture before and after into separate folders and list every changed view with a reason.

Software-GL captures (no xvfb-run installed; a private X server is unpacked in `~/work/xvfb-local`):

```
X=~/work/xvfb-local/root; export LD_LIBRARY_PATH=$X/usr/lib/x86_64-linux-gnu
$X/usr/bin/Xvfb :78 -screen 0 540x960x24 -nolisten tcp & XP=$!; sleep 3
DISPLAY=:78 GOLDEN_OUT=$HOME/work/woods-before GOLDEN_ONLY=woods_trailhead,woods_fork,woods_ridge,woods_oak,woods_creek,woods_home,woods_pines,woods_pond,woods_lookout \
  ~/.local/bin/godot --path . --audio-driver Dummy --rendering-driver opengl3 --resolution 540x960 --fixed-fps 60 \
  --disable-vsync --script tools/golden_capture.gd
kill $XP
```

(Use display :78 - Claude may use :77.) PIL is available for image diffs; numpy is not.

If you change woods generator code, recompile the woods (`tools/compile_woods.gd`, under the X server) and if you
change foliage/anatomy code re-bake (`tools/bake_cache.gd`). Run `tools/woods_check.gd`, `tools/woods_clip_check.gd`,
`tools/sky_clip_check.gd`, `tools/motion_check.gd` and your new trace.

## Report

`docs/codex/REPORT_WOODS_2026-11-13.md`: before/after numbers, each cause, each change, files changed, checks run with
results, views changed and why, anything dropped. Do not claim a fix you did not measure.
