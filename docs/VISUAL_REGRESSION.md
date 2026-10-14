# Visual regression

## Golden baselines

**Current: `tests/baseline/ea79dad/`.** This is an intentional visual change, asked for by the owner on
2026-10-14:

- fieldstone walls and irregular rocks;
- dense woods across the creek;
- a worn trail from the footbridge.

It adds the views `garden_wall` and `garden_creek`. `tests/results/2026-10-14_f72b9bd_vs_ea79dad.json` records how
far each view moved from the old set. The layout is unchanged: the garden's shared RNG ends the build in the same
state as before. The full-frame differences are the walls, plus the shadow-map fitting that follows the new casters.

Compare against the current baseline, never the old one.

**Previous: `tests/baseline/f72b9bd/`.** holds the build at commit f72b9bd, before any runbook change. It contains 5 garden
views and a 12-frame orbit (`moving_*`), plus `views.json` (the camera poses, seed and hour).

Make a candidate set (silent, offscreen; about 4 minutes under software GL):

```
GOLDEN_OUT=/tmp/hp-cand GOLDEN_ONLY=garden_overview,garden_closeup,garden_pet,garden_to_woods,garden_east,moving \
  xvfb-run -a -s "-screen 0 540x960x24" godot --path . --audio-driver Dummy --rendering-driver opengl3 \
  --resolution 540x960 --fixed-fps 60 --disable-vsync --script tools/golden_capture.gd
python3 tools/image_compare.py tests/baseline/f72b9bd /tmp/hp-cand /tmp/hp-cand/compare
```

`image_compare.py` exits non-zero on any channel difference above `--tolerance` (default 0, so pixel-exact). It
writes `<view>_diff.png` and `comparison.json` (differing pixels, max channel difference, mean absolute difference,
and a block SSIM as a diagnostic only).

## What is pinned

- The clock: `HEDGEPETS_HOUR=16.5`.
- The global RNG: `seed(20261014)`.
- `HEDGEPETS_FRESH=1`, and `Motion.speed = 0`.
- Fixed-step frames (`--fixed-fps 60`), so the shader `TIME` is identical at each shot.
- A 540×960 viewport.
- Software GL (llvmpipe under xvfb), which is deterministic and doesn't disturb the desktop. Always pass
  `--audio-driver Dummy`, or the soundscape plays through the speakers.

## Verified

- **Determinism:** two runs of the baseline build gave 17/17 pixel-identical images.
- **No-op hook:** the build with the `WorldOverrides` hook (no override file) matches the baseline; see
  `comparison.json` in the commit that added it.

## Gaps

- **Woods views** (`woods_*`) are in the tool but not in the baseline. Under llvmpipe the woods build plus render
  ran past 10 minutes. They need a GPU run or a lighter path.
- **No GPU golden set** (NVIDIA results can differ from llvmpipe; keep the two sets separate).
- **No audio or gameplay sequence comparisons yet.**
