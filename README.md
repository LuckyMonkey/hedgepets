# HedgePets

A tiny Godot 4.7 (GL Compatibility, portrait 1080 × 1920) garden-creature lab. The design notes are
`hedgepets, part.md` ("we're going to care about these things way too much").

![Gerald](docs-gerald.png)

## What is here

- **Gerald**, a chibi hedge: a big round head on a small round body, standing on two terracotta pot feet (the
  left one chipped). `scripts/hedge_pet.gd` draws him in two layers: a soft watercolour base under the leaves, and
  the face, cheeks, sprout and feet on top.
- **He is alive** (`scripts/pet_life.gd` on the `Pet` node): breathes, sways a little in the breeze, blinks (sometimes
  twice), follows your pointer or finger with his eyes and glances around when you're idle, does a little shimmy
  every so often, and when you tap him he hops, squeezes his eyes shut, flushes and a heart pops out. Cheap: the
  leafy body only moves by transform; only the face layer redraws each frame.
- **The leaves** (`scripts/growth_renderer.gd`): plant profiles (`assets/plants/plant_profiles.json`), hedge glyph
  fonts (`assets/fonts`, built by `tools/generate_hedgeink.py`) and watercolour masks grow over the creature's shape
  (`scripts/creature_definition.gd`) and part around his face. Old anchors authored on the first (beaver) sketch
  are carried onto the new shape by `Creature.remap_legacy()`.
- **The renderer lab** (growth, amplitude, frequency, leaf spacing, overflow, plant): press **Tab**.

## Checking it without a window

```
xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --script tools/capture_screenshot.gd   # /tmp/hedgepets-headless.png
xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --script tools/capture_frames.gd       # 6 frames with a tap
```
