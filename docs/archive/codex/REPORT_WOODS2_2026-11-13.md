# Woods 2 report — 2026-11-13

## Implemented

The ravine/lookout is the existing **ridge** place (`NODES["ridge"]`, about `(22, -44)`). It now reads as a real
drop: five stepped, broken ledges run away from the lookout in `VIEW_DIR`, while the existing distant valley and
mountain remain the view beyond them. Rock placement still goes through the existing `GardenProps.rock` calls; the
new ledges use simple low-poly slabs so the parallel rock-factory work is not touched.

The ridge has a mounted pair of binoculars on a post beside the existing bench. Tapping it eases the camera to a
fixed rim position through `Motion.spring`, narrows the field of view from 24 degrees, and renders the miniature at
0.9 resolution while active. Dragging is limited to ±0.65 radians horizontally and -28..8 degrees vertically.
Mouse wheel and pinch set 8..40 degrees. A second tap steps back. Six quiet details are available: heron, hawk,
fox den, deer, church weathervane, and the garden/home miniature. A detail caption appears after a short centre
dwell, and found details are saved under `woods_finds.binoculars` and listed in the garden journal.

The miniature pose contract is now explicit in `MiniatureSky`: `follow()` records the host frame after the host
camera update, and `project_direction()` exposes the exact `view_inv`, `tan_half_w`, `aspect`, and `OVERSCAN`
mapping used by `distant_sky.gdshader`. `tools/skybox_check.gd` checks the peak/village/garden landmarks at four
poses and during a 90-frame turn/walk. The woods already call `land.follow()` after camera movement in `_process`;
the frame stamp guards that ordering against future regressions.

`tools/woods_clip_check.gd` now reports the number of trail edges swept, in addition to its existing solid/ground
hit audit. The existing trail corridor remains the source of truth; no props were hidden to conceal clipping.

## Verification attempted

Commands were run with `--audio-driver Dummy` and no git commands were used:

- `tools/skybox_check.gd`
- `tools/woods_trace.gd`
- `tools/compile_woods.gd`
- `tools/bake_cache.gd`
- `tools/woods_check.gd`
- `tools/motion_check.gd`
- `godot --headless --editor --quit`

All Godot runs stopped during garden initialization after the same warning that `assets/baked/garden.res` is stale
relative to the foliage/anatomy code. They produced no check result or exit line in this sandbox; even the editor
quit timed out. The compile and bake artifacts therefore were not regenerated here, and no runtime pass or visual
pass is claimed. This is the same headless startup limitation that prevented the previous software-GL captures.

## Claude capture poses

Capture the ridge from the normal player camera at `ridge`, facing `VIEW_DIR`, then turn 360 degrees there. Capture
again after tapping `RavineBinoculars`, at FOV 24, 12, and 8 degrees, with the view centred first on the distant
garden/home (`TOY_GARDEN`), then the church, then the lower valley. Also capture the trailhead looking back toward
the footbridge and the ridge-to-oak trail while walking. Check that the stepped rim never enters the camera, the
near ground and miniature have no seam, and the miniature landmarks do not swim while turning or walking.

Performance should be measured once on the low phone tier with the binocular mode off and on; the prior trace was
1,240 cached headless frames at p50/p95/max 2.2/3.6/5.5 ms normal and 2.4/4.0/5.6 ms low tier. Those numbers are
not a new measurement of this increment.

