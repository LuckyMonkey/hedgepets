# Codex brief (2026-11-13, pass 4): woods leftovers + a hand-placement editor for the woods

Same rules as before (no git, `--audio-driver Dummy`, only `~/work/hp-woods`, lean tests). Rocks now come from
`RockFactory` (merged): use its roles (`ledge`, `boulder`, `stepping_stone`…) for any rock you touch.

Attached captures after pass 3 (`docs/codex/shots/merge1_all.png`: garden wall, overview, ridge, oak, trailhead;
`woods_after3.png`: pass 3 vs a lighter ambient - oak and trailhead).

## Leftovers (each small; fix, don't redesign)

1. **The old oak's arrival view:** the top third is still a dark crown mass right over the camera. Your near fade
   didn't take in the capture: check which material the oak's crown masses actually use in the compiled woods
   (`world/woods_compiled.scn`) and that the fade uniform is set there; or move the arrival camera out from under it.
2. **The ridge's arrival view:** a log still cuts into the right of the frame. The golden capture's ridge pose is
   `tools/golden_capture.gd`'s woods view for "ridge" - make sure your clear arrival cone covers the pose the game
   and the capture actually use.
3. **The near ground reads almost black** in every woods view (the dirt hills either side of the trail, not just the
   trail). It's the ground's own vertex colours plus the canopy shadow: lift the dark earth colours toward the
   leaf-litter browns of `docs/ART_DIRECTION.md` so the floor reads in shade, still darker than the garden.
4. The trailhead: a bright blue blob by the log (a tarp? a pool?) reads as a toy. If it's dumped junk, make it a
   faded, dirty blue; if it's water, it shouldn't be a blob.

## A hand-placement editor for the woods (the owner wants to change the woods directly)

The garden has one (`docs/WORLD_EDITOR.md`, `scripts/world/world_editor.gd`, `world_overrides.gd`,
`world/garden_overrides.tres`). Give the woods the same:
- stable IDs for the woods' placed things (trees, logs, boulders, ledges, benches, signs, the binoculars, finds…)
  from their generation context (cell + kind + index), so an override survives a rebuild;
- overrides applied after generation (move / turn / scale / hide), saved to `world/woods_overrides.tres`, never fed
  back into generation (same rng draws, nothing else moves);
- the editor opens the woods at a chosen place (`res://world_editor.tscn -- --woods=<place>` or a dock button),
  same controls as the garden editor, Ctrl+S saves; the compiled woods respect overrides (recompile picks them up).
- update `docs/WORLD_EDITOR.md` and `docs/OWNER_QUICKSTART.md` (owner-facing, plain words).

Report: `docs/codex/REPORT_WOODS4_2026-11-13.md` - what changed, and the poses for Claude to capture.
