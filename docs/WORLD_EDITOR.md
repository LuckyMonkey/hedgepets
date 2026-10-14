# World editor

`godot --path . res://world_editor.tscn`. This is the real garden, built by the real code, with authored overrides
on top. It is an in-engine mode rather than an `EditorPlugin`, because the garden only exists once
`garden.gd` has built it at runtime, so the Godot editor's scene tree never contains it (see
`WORLD_ARCHITECTURE.md`).

## How edits are stored

- `scripts/world/world_overrides.gd` (`WorldOverrides`, a Resource) saves to `res://world/garden_overrides.tres`.
- The format is `things: id -> {position: Vector3, yaw: float, scale: Vector3, hidden: bool}`.
- IDs are the garden's own stable `things[i].id` (`lawn_chair_5`, `rock_31`, …), fixed by the build order of
  `_build_props`.
- The game applies overrides in `garden_game.setup`, after every thing exists and **before** the player's save is
  read. So the player's own moves still win, and authored edits never touch the save.
- Generation is never fed an override: same calls, same order, same random numbers. A missing or empty file is a
  no-op (proven pixel-exact by the golden comparison, below).
- `HEDGEPETS_WORLD=path` uses another file (tests). An unknown ID gives a warning, not a failure.

## Controls

| Action | Input |
|---|---|
| Select | Click a thing, or pick it in the list (`*` = has an override) |
| Move | Drag (snaps to a 0.25 m grid; G toggles the grid) |
| Turn | `[` and `]` (15°) |
| Scale | `-` and `=` (uniform, 10%) |
| Hide / unhide | Delete |
| Reset to generated | R |
| Undo / redo | Ctrl+Z, then Ctrl+Y or Ctrl+Shift+Z |
| Save | Ctrl+S |
| Camera | Wheel zooms, right-drag pans; WASD / QE / RF are the garden's own keys |

## Verified

`tools/world_editor_check.gd` passes 10/10 (headless). It checks that:

- the editor opens on exactly the generated layout (38 things);
- moving and turning work;
- undo takes back one step at a time, and redo restores them;
- hiding and then resetting restores a thing;
- after saving and rebuilding the garden the way the game does, `lawn_chair_5` is where it was put and nothing
  else moved.

**Not tested by hand:** the interactive mouse dragging and the list UI (no one has run the window yet).

## Not built yet (later milestones)

- Editing things without a `things` ID: fence sections, stone walls, garden trees, grass, woods trees and the
  trail graph. Those need IDs from their generation context first (`WORLD_ARCHITECTURE.md`).
- Duplicating, and placing new prefabs.
- Multi-select, per-axis gizmos and surface snapping.
- Showing the woods graph (9 places, 10 trails) in the editor, and the skybox as a read-only context.
