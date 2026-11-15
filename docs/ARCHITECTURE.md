# How HedgePets is built

A map of the code: what each part does, how the parts fit, and why they are shaped the way they are. Every script also
opens with its own description; this page is the overview. Rules for working on it: [../AGENTS.md](../AGENTS.md).
Running, checking and deploying: [OPERATIONS.md](OPERATIONS.md).

## The big picture

HedgePets is a Godot 4.7 game (GL Compatibility renderer, portrait, exported to the web for phones). There are no
hand-made 3D models and almost no hand-placed scenes: **everything is built by code when the game starts** - the
garden, the woods, the pets, the trees, the land on the horizon. That has three consequences that explain most of
the design:

1. **It must be deterministic.** Things are placed by seeded random numbers. The same code builds the same world
   every time, which is what makes saving, caching and comparing builds possible. Changing the *order* of random
   draws moves things; see "Seeds" below.
2. **It must be cheap to start.** A phone cannot spend a minute growing leaves. Expensive results are baked into a
   startup cache, and long builds are cut into small slices so the frame never freezes.
3. **The editor shows little by itself.** The scenes (`garden.tscn`, ...) hold almost nothing; their scripts build
   the world at run time. Tools that bridge this: the world editor (moves things by stable ID and saves overrides),
   the tree lab and rock lab (editable in the editor), and the woods' layers in the remote scene tree.

## The scenes

| Scene | What it is | Script |
|---|---|---|
| `garden.tscn` | The game. The back garden, and from it the woods and the den. | `scripts/garden/garden.gd` |
| `main3d.tscn` | The pet viewer (also `?viewer` on the web). | `scripts/hedge_pet_3d.gd` |
| `world_editor.tscn` | Move generated things and save it as overrides. | `scripts/world/world_editor.gd` |
| `filmmaker.tscn` | Directs the real game to render films. | `scripts/film/filmmaker.gd` |
| `tools/art/tree_lab.tscn`, `tools/art/rock_lab.tscn` | Tune trees and rocks in the editor. | `tools/art/*_lab.gd` |

## The code tree

```
scripts/
  garden/
    garden.gd            the garden scene: staged build (BUILD_STEPS), state, _process
      garden/            its layers: layout -> sky -> plants -> world -> pets -> camera
    garden_game.gd       the game loop: setup and _process
      game/              its layers: state -> plants -> visitors -> friends -> save -> ui -> tools
    garden_props.gd      GardenProps: every prop, built from simple shapes (hideouts here)
      props/             its layers: kit -> yard -> builds -> surroundings
    woods.gd             the woods: a visit, walking the trails, looking around, input
      woods/             its layers: ground -> trails -> scenery -> landmarks -> finds -> build
    woods_trees.gd       which trees stand where in the woods (the look is TreeFactory's)
    distant_land.gd      the land past the woods, a 1:16 miniature drawn as the sky
      land/              its layers: terrain -> forest -> landmarks
    elsewhere.gd         base for places you go to and come back from (woods, den)
    garden_grab.gd       hands-on yard work (drag junk, haul, mend, wheelbarrow)
    garden_story.gd      the journal, cause-and-effect captions, introductions
    nursery.gd, porch_watcher.gd, den.gd, hideouts.gd, perches.gd, soundscape.gd, ...
  pet/
    hedge_pet_node.gd    HedgePetNode: one pet, setup and its life each frame
      node/              its layers: body -> face -> foliage -> moods
  art/
    character_art_profile.gd  a pet's look as data
    species_builder.gd   pets from pets/species.json; palettes and plants
    foliage_builder.gd   leaves for any region: pets, bushes, trees all use it
    hedge_anatomy.gd     region meshes (ellipsoids and friends)
    tree_factory.gd      every tree, one way (see "Trees")
    rock_factory.gd      every rock, one way
  anim/motion.gd         every visible change eases through here
  util/                  bake cache, slicing, assets, web save, hitch log
  world/                 the world editor and its overrides
  film/                  the filmmaker
shaders/                 leaf, lawn, grass, sky, water, ...
tools/                   checks/ capture/ bake/ perf/ art/ film/, deploy_web.sh
```

### Why "layer chains"

The four biggest scripts (garden, garden game, woods, pet node) and two catalogues (props, distant land) were each
one file of 900 to 2,900 lines. They are now **layer chains**: a folder of files, each one concern, each extending the
one before, with the original file on top. `woods_trails.gd extends woods_ground.gd`, and so on up to `woods.gd`.

Why this shape instead of separate objects talking to each other:

- **Nothing outside had to change.** `woods.gd`, `garden.gd` and `HedgePetNode` keep their paths, class names and
  every method, so scenes, saves, tools and other scripts work as before.
- **The code was moved, not rewritten.** Every function is the same text in a new place; the order of calls and
  of random draws is unchanged. `tools/checks/world_fingerprint.gd` proved it: the built world was identical, node
  for node, before and after each split.
- **The direction of reading is the direction of dependency.** A layer only uses what is below it. To understand
  the trails you read `woods_ground.gd` and `woods_trails.gd`, nothing above. The rare exception is declared openly:
  `game_state.gd` declares `_refresh()` (redraw the HUD) so any layer can call it, and `game_ui.gd` fills it in.

Each layer file opens with the chain's order and what that layer is for.

## How a frame of the garden comes to be

1. `garden.gd` `_ready()` runs `BUILD_STEPS` in order, a step per frame on the web (a loading card says what is
   happening). Each step is a function in one of the garden layers: the world, the ground, the backdrop, props,
   grass, pets, leaf litter, ambience, the sun, sounds, the tilt-shift.
2. Expensive geometry (bush and tree foliage, pet anatomy) is read from the startup cache
   (`assets/baked/garden.res`, `scripts/util/bake_cache.gd`) when it is there, built live when it is not. The cache
   is not committed; the deploy bakes it. A fingerprint of the generator code tells a stale cache from a good one.
3. `garden_game.gd` takes over: the tools, the visitors, saving. Pets move in `garden_pets.gd`'s `_walk()`.
4. The camera never jumps: input moves a goal and the camera eases toward it (`scripts/anim/motion.gd`).

## The woods

You walk from clearing to clearing on fixed trails; the camera is the hiker. `woods_ground.gd` holds the map
(`NODES`, `EDGES`) and the terrain; `woods_trails.gd` lays out and indexes the trails. Everything else asks the
trail index "how far am I from the walk?" so nothing ever stands in your way (`eye_clear`, `_keep_open`).

The woods are built behind the loading card in steps (`woods_build.gd` `build_steps()`), and each step's nodes are
put in a **layer** in the scene tree: `Ground`, `Trees`, `Undergrowth`, `Places`, `Sky`, `NurseryGlade`. Static
meshes are merged within their layer (fewer draw calls) and fade out by distance (visibility ranges).

Part of the woods (ground, trail beds, undergrowth) can be compiled once into `world/woods_compiled.scn`
(`tools/bake/compile_woods.gd`, done by the deploy); `SOURCES` in `woods_build.gd` lists the files whose text
decides whether a compile is stale.

### Trees

`scripts/art/tree_factory.gd` makes every tree: oak, maple, birch, white pine, the willows' crowns and the old oak's
crown. A tree is low-poly limbs plus leaf clusters grown by the same foliage system as the pets. **Near or far it is
the same tree**: the leaf shader thins far crowns to their crown leaves, grown bigger, smoothly with distance
(`distance_lod_*` in `shaders/leaf.gdshader`). Decisions:

- *No second "far" style.* Earlier versions drew leaves only near trails and dark lumps elsewhere, and switched
  leaves off at 36 m. That looked like two worlds glued together and popped as you walked.
- *No inner "core" mass.* A core shows as a slab wherever the leaves thin (near the camera, where leaves fade so they
  never fill your face, and far off).
- *One random number per tree.* Each tree seeds its own generator from one draw, so changing a tree's recipe never
  moves anything else in the woods.
- *Budget.* About 800 to 950 triangles per tree; the woods are ~536 trees, ~214k leaf cards. The tree lab prints
  costs per tree; the woods print totals when built.

The distant land's nearer crowns use the same leaf cards (`land_forest.gd` `_leafy_crowns`), so the forest past the
woods is the same forest. Further out, simple lumps in the haze are enough.

### The sky (the "3D skybox")

`scripts/garden/miniature_sky.gd`: a 1:16 model of the land in its own SubViewport, with a camera that copies the
woods camera (position divided by 16). Its picture is projected as the woods' sky by `shaders/distant_sky.gdshader`.
Walking gives true parallax: near hills slide, far mountains barely move. It only redraws when the view changes.
The owner calls it a very important feature: check it after any change near it
(`tools/checks/skybox_check.gd`, `tools/capture/capture_land_layers.gd` to find which piece is which).

## Pets

`HedgePetNode` builds a pet from its `CharacterArtProfile` (regions, face anchors, foliage) in slices
(`pet_body.gd` `_slice`), so a pet arriving never stalls a frame. 47 species come from `pets/species.json` through
`species_builder.gd`; a few are hand-tuned profiles in `pets/*.tres`. The owner's look rules (all plant except feet
and tail, eyes with no whites, autumn, never spooky) are in [ART_DIRECTION.md](ART_DIRECTION.md).

## Seeds and determinism

- The garden and the woods each use a seeded build RNG. Any change to the *number* of random draws in a step moves
  everything built after it. To change one thing without moving others, give it its own RNG seeded from one draw
  (as `TreeFactory.plan` does).
- `tools/checks/world_fingerprint.gd` writes every node's path and transform. Diff before and after a refactor:
  identical means nothing moved.

## Performance budget

- Phones (the owner tests on an iPhone) at a steady 30 fps; the 2012 MacBook Air must stay near 30 fps too.
- Leaf cards are the biggest pool of triangles; they cast no shadows.
- Draw calls are kept low by batching: trees per 24 m patch, props merged per cell, the land as MultiMeshes.
- Quality tiers (`scripts/quality.gd`) are picked from the device and adjust ranges and leaf detail.
- Frame times are reported by telemetry (go.fridge.run/hedgepets/telemetry/report).
