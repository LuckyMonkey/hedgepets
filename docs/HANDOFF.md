# HedgePets — concise handoff

**Instructions are now centralized in [../AGENTS.md](../AGENTS.md).** Review procedure: [CODE_REVIEW.md](CODE_REVIEW.md). This file is a map and a *dated snapshot*, not a second policy. If old notes disagree with the running game, inspect code and verify. Current game behavior is the baseline; do not "fix" it to match stale prose.

## Working project
- Game: Godot 4.7.2, GL Compatibility, main `garden.tscn`; standalone pet viewer `main3d.tscn`.
- Owner's working copy as documented 2026-11-13: `~/work/hedgepets` (not the older `~/Projects/hedgepets`).
- Local Godot: `~/.local/bin/godot`. Owner workflow and environment: [OWNER_QUICKSTART.md](OWNER_QUICKSTART.md), [DEV_ENVIRONMENT.md](DEV_ENVIRONMENT.md).
- Website previously documented: `go.fridge.run/hedgepets`. A PR does not deploy there; do not assume the deployed copy matches the repo.
- The owner reported the current game working on 2026-11-15. That is **not** a claim that every test has passed.

## Code map
| Responsibility | Entry |
| --- | --- |
| Garden world/camera/pet movement/build | `scripts/garden/garden.gd` |
| Garden state, tools, wishes, saves, HUD | `scripts/garden/garden_game.gd` |
| Stateless garden description copy | `scripts/garden/garden_descriptions.gd` |
| Procedural yard props | `scripts/garden/garden_props.gd` |
| Drag/haul/fence/wheelbarrow interactions | `scripts/garden/garden_grab.gd` |
| Woods/trails/finds/streaming | `scripts/garden/woods.gd` |
| Procedural woods trees and miniature backdrop | `scripts/garden/woods_trees.gd`, `scripts/garden/distant_land.gd` |
| Creature behavior / generated art | `scripts/pet/`, `scripts/art/`, `pets/` |
| Animation and telemetry | `scripts/anim/motion.gd`, `scripts/telemetry.gd` |
| World editor and filmmaker | `scripts/world/`, `scripts/film/`, `docs/WORLD_EDITOR.md`, `docs/FILMMAKER.md` |

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
