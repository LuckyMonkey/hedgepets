# HedgePets — concise handoff

**Instructions are now centralized in [../AGENTS.md](../AGENTS.md).** Review procedure: [CODE_REVIEW.md](CODE_REVIEW.md). This file is a map and a *dated snapshot*, not a second policy. If old notes disagree with the running game, inspect code and verify. Current game behavior is the baseline; do not "fix" it to match stale prose.

## Working project
- Game: Godot 4.7.2, GL Compatibility, main `garden.tscn`; standalone pet viewer `main3d.tscn`.
- Owner's working copy as documented 2026-11-13: `~/work/hedgepets` (not the older `~/Projects/hedgepets`).
- Local Godot: `~/.local/bin/godot`. Owner workflow and environment: [OWNER_QUICKSTART.md](OWNER_QUICKSTART.md), [DEV_ENVIRONMENT.md](DEV_ENVIRONMENT.md).
- Website previously documented: `go.fridge.run/hedgepets`. A PR does not deploy there; do not assume the deployed copy matches the repo.
- The owner reported the current game working on 2026-11-15. That is **not** a claim that every test has passed.

## Code map
The full map, and why it is shaped this way: [ARCHITECTURE.md](ARCHITECTURE.md). In short, the big scripts are layer
chains (a folder of files, each extending the one before, the original file on top):
`garden.gd` (+ `garden/`), `garden_game.gd` (+ `game/`), `woods.gd` (+ `woods/`), `garden_props.gd` (+ `props/`),
`distant_land.gd` (+ `land/`), `pet/hedge_pet_node.gd` (+ `pet/node/`). Trees: `scripts/art/tree_factory.gd`.

## State on 2026-11-15
- Restructure done: layer chains, unused code and caches removed, tools grouped. Proven unchanged by
  `tools/checks/world_fingerprint.gd` (diff before/after).
- New woods trees (TreeFactory), clean trail chevrons, signs that fit, woods layers in the scene tree. Deployed as
  telemetry 2026.11.15b; check the frame-time report after the owner's next iPhone session.
- Open: an editor round trip for the woods (open a built woods view in the editor, move things, save them as
  overrides); the toy garden / garden-from-woods view was not re-checked after the land change.

## Review/test locations
- Focused check for the first extraction: `tools/checks/descriptions_check.gd`.
- Core game loop: `tools/checks/game_check.gd`. Other subsystem checks: `tools/*_check.gd`.
- Visual baseline: `tools/capture/golden_capture.gd`, `tools/capture/image_compare.py`, `tests/baseline/`.
- GitHub Actions: `.github/workflows/review.yml` for PR smoke checks; `pages.yml` for main-branch Pages exports. **PR checks do not replace visual review.**
- **How to run, check, deploy, and the traps:** [OPERATIONS.md](OPERATIONS.md). Performance and export: [PERFORMANCE_BASELINE.md](PERFORMANCE_BASELINE.md), [MOBILE.md](MOBILE.md).

## Historical observations (2026-11-13, **not re-verified**)
- Pet build slicing, sky redraw-on-change and first-draw warm-up were reported live; iPhone reportedly held 30 fps in the garden.
- Woods passes added a ridge/ravine, six binocular details, arrival views, daylight, more controlled streaming, and a world-placement editor.
- There was an open issue with old oak arrival framing, and `life_check` / `collision_check` had shown intermittent failures.
- Previous agents used worktrees `~/work/hp-<name>`; Codex could not open X, and visual captures needed a private Xvfb `:77`.
- Notes on weather, features, and docs from October or early November may be historical. Never treat an old “open” item as current without checking.
- Separate Fridge Go PHP endpoints handle access, feedback, how-to, and web telemetry; they are *not* in this repository.

## Next extraction priorities (suggestions, not approved changes)
- Garden UI/journal, provided game state stays the owner.
- Woods trail geometry/indexing, preserving path positions, terrain and seeded randomness.
- Atmosphere/camera and procedural prop families only after baseline captures.

**Keep this handoff short.** Put durable project rules in `AGENTS.md`, review procedure in `CODE_REVIEW.md`, and topic-specific detail in the corresponding topic doc. Remove superseded status lines instead of accumulating more.
