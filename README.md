# HedgePets

A tiny Godot 4.7 (GL Compatibility, portrait 1080 × 1920) garden-creature lab. The design notes are
`hedgepets, part.md` ("we're going to care about these things way too much").

![Gerald](docs-gerald.png)

## What is here

- **Gerald**, a beaver grown over with ivy, three-quarters view (the target is `hedgepetsGoal.jpg`). Base layer
  (`scripts/hedge_pet.gd`): the crosshatched paddle tail, far feet, dark fur under the ivy, tan head and muzzle, ear,
  light from the upper left. Top layer: eye, nose, teeth, cheek, near feet.
- **The ivy** (`scripts/growth_renderer.gd`): an ivy cover over the body and the back of the head, vines from the
  growth curves trailing off the edges with curling tendrils, white flowers. Every leaf is lit by where it sits on the
  round body and foreshortened at the rim. The layout is built once; every frame the leaves rustle in a wind that
  rolls across him (rim leaves most; a tap shivers them all). Leaves are baked sprites
  (`assets/sprites/*.png` from `tools/bake_leaf_sprites.py`; real lobed ivy from `tools/make_ivy_sprites.py`), so 670
  rustling leaves run at the display's frame rate.
- **He is alive** (`scripts/pet_life.gd`): breathes (barely), blinks, follows your pointer with his eye and glances
  around when you're idle; every so often a gust goes through his leaves; tap him and he hops, his eye squeezes shut,
  his cheek flushes and a heart pops out. He himself does not sway - the leaves do.
- **The renderer lab** (growth, amplitude, frequency, leaf spacing, overflow, plant): press **Tab**.

## Checking it without a window

```
xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --script tools/capture_screenshot.gd   # /tmp/hedgepets-headless.png
xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --script tools/capture_frames.gd       # 6 frames with a tap
DISPLAY=:0 godot --path . --script tools/fps_check.gd                                                                        # frame rate on the real GPU
```
