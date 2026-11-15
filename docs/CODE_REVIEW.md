# Code review and safe refactoring

The game is working. A cleanup PR is successful only when **the same game continues to work** and a reviewer can explain the change in a few sentences. Do not add features, retune art, or rewrite unrelated files during an extraction.

## Review the diff, not the ambition

1. State the one responsibility being moved and identify its callers, exported methods, scene references, and save dependencies. Prefer a cohesive stateless group first.
2. Read the complete source of each moved method. For initial extractions, move code **verbatim** and keep delegating wrappers when a caller may depend on an old method name.
3. Confirm Godot class/script loading, type hints, preload cycles, resource paths, data keys, stable object IDs, and ownership/freeing rules. Pay special attention to seeded random streams, cache keys, and save formats.
4. Check that `git diff --check` is clean. Run one relevant fast check, including `--audio-driver Dummy` for offscreen runs. Review screenshots before and after for any visual change (see `VISUAL_REGRESSION.md`).
5. Review changed behavior manually or with a focused check. On a refactor, expected behavior changes are **none**. If there is any difference, separate it into another PR.
6. Report findings in severity order with file paths and line numbers: **blocker** (crash/data loss), **high** (behavioral regression), **medium** (maintenance/performance), **low** (clarity). Distinguish observations from guesses.
7. Record what was tested, what was *not* tested, and any known flaky checks. Never say “tests pass” merely because files were edited.

## Where to start breaking up large classes

These are candidate boundaries, **not instructions to move everything**:
- `garden_game.gd`: presentation/description text, then HUD/journal, then persistence; preserve the public-facing garden loop and saved JSON structure.
- `garden.gd`: environmental atmosphere and camera input, then scene building; preserve build order, deterministic seeds and visual snapshots.
- `woods.gd`: trail geometry/indexing before any renderer or streaming work; preserve paths, arrival views and the 3D skybox.
- `garden_props.gd`: independent families of procedural props; preserve material and bake-cache behavior.

Extract one cohesive unit per PR. Do **not** rename scene callbacks, change gameplay pacing, or move state ownership just to reduce line count.

## Minimal check commands (run in project root)

```bash
git diff --check
godot --headless --audio-driver Dummy --path . --editor --quit
HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/checks/descriptions_check.gd
HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/checks/game_check.gd --fixed-fps 60
```

Run only the tests relevant to the touched behavior, unless the risk warrants more. The PR workflow checks import, description formatting, and the garden loop. Visual review is still manual; a headless exit code is not a screenshot.

Before merging a refactor, compare the current working branch to the proposed branch, using the same test save and screenshots. Do not replace golden baselines merely to make a change appear successful.

## PR rules

- Work on a branch. **Do not push directly to `main` or deploy to the live Fridge without the owner's explicit request.**
- Keep feature requests, cleanup, visual tuning, and performance optimization in different commits/PRs when possible.
- Never change a user save format or file location without explicit migration and rollback.
- A README or handoff is not runtime proof; where documentation disagrees with working code, investigate and fix the documentation.
- Do not echo private story material into issues, PRs, commits, logs, or generated reports. The repository's `docs/private` path does **not** make tracked files private.
