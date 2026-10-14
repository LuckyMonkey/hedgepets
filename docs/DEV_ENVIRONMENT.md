# Working on HedgePets: the development environment

## Recommendation

**Use the Godot editor (4.7.2) as the SDK, with the HedgePets dock.**

The garden and woods are built by code when the game runs. A conventional map editor (Unity-style, Tiled, Hammer,
TrenchBroom) can't see that world, and moving it all into hand-placed scenes would throw away the procedural woods.
So the tools work inside the game instead:

| Tool | What it's for | How to open it |
|---|---|---|
| **HedgePets dock** (editor, right side) | Play from anywhere; a woods map; run checks | Open the project in Godot. The dock is enabled in `project.godot` |
| **Woods map** (in the dock) | The trail loop, top-down. Click a place to start the game standing there | The dock |
| **World editor** | Move, turn, scale or hide the garden's things; undo; saves to `world/garden_overrides.tres` | The dock, "World editor" |
| **Filmmaker** | Camera shots in the garden or the woods; renders video with sound | The dock, "Filmmaker". Render: `FILM_GPU=1 tools/film_render.sh res://films/demo/project.tres out/` |
| **VS Code** (optional) | Editing scripts, with tasks to run the game and checks | `code .` (Godot Tools extension; `.vscode/` is set up) |

**Debug coins:**

- In the editor, there's a 🪙+ button in the game's top bar, or press F9.
- On the web, add `?debug` to the address (`go.fridge.run/hedgepets/?debug`).
- From a terminal, add `-- --debug`.

**Start anywhere from a terminal:** `godot --path . res://garden.tscn -- --start=woods:pines --debug`. The places
are trailhead, fork, hollow, ridge, creek, oak, nursery, pond, cellar and pines.

## If you want a real map editor too

**TrenchBroom** with **func_godot** is the best free option: TrenchBroom is a Quake/Source-style brush editor, and
func_godot is a Godot add-on that imports its `.map` files. It suits hand-built, blocky set pieces: a cabin, the
cellar hole, a bridge. It would sit beside the generated woods, not replace them. It isn't installed. Say if you want
it, and it can be set up as one place in the woods.

**Blender**, for modelling single props, imports into Godot directly from `.blend` files.

## Checks

The dock runs any `tools/*_check.gd` and shows its output. From a terminal:
`HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/<check>.gd --fixed-fps 60`.

The world-specific ones are `woods_clip_check` (anything the walk passes through; it needs a renderer:
`xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . --script tools/woods_clip_check.gd`) and
`world_editor_check`.
