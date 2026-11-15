# HedgePets — engineering instructions (canonical)

**Current premise:** HedgePets is a working Godot 4.7.2 garden game. The current working game is the reference behavior. Protect it. This file is the single entry point for coding agents; do not create competing "agent rules" in handoffs or reports.

## Read in this order
1. `AGENTS.md` (this file): rules and working assumptions.
2. `docs/CODE_REVIEW.md`: review and safe extraction protocol.
3. Documentation for the exact part being changed (index below).
4. The actual implementation, its callers, and one relevant check. Existing behavior wins over a stale document.
5. `docs/HANDOFF.md`: compact location map and dated observations, **not** a second instructions file.

## Non-negotiable design rules
- **A place, not a treadmill.** Watching is valid play. No urgency, streaks, daily chores, grinding or punishment for absence; nothing decays while the player is away.
- Hedgepets are botanical creatures, not collectible Pokémon. Garden capacity is 2–6. The roster is closed at 47; polish existing pets before adding any.
- Botanical body/head; feet and tail may use roots or twigs. Eyes have no whites, only a small crisp light dot. Autumn, ordinary New England backyard, gently magical, never spooky.
- Woods are **daytime**, with deep blue-green shade and sunbeams. Preserve the **3D skybox** and the arrival views.
- Visible changes ease with `scripts/anim/motion.gd`, no visible pops.
- The nursery lady and porch man must not be named in game text, code, or comments. Story details live in `docs/private/LORE.md` and must not be copied into reviews or logs.

## Engineering boundaries
- No broad rewrite, scene rearrangement, asset rebake, mass rename, gameplay rebalance, or "cleanup while here." One behavior-preserving extraction at a time.
- Separate state/logic from presentation with dedicated classes where it **reduces responsibilities**; preserve old entrypoints with wrappers until all callers/tests are verified. Do not move an entire monolithic file in one shot.
- Keep save compatibility (`user://garden.json`, web localStorage), generated geometry ordering, seeded RNG calls, stable IDs, bake caches, rendering settings and mobile frame-time budget intact.
- Treat the currently working scene as the baseline: `garden.tscn`; viewer `main3d.tscn`. Godot GL Compatibility, portrait 1080×1920.
- Codex may implement engineering; Claude may judge art. Neither may declare a visual change safe without before/after captures.
- The `docs/private` directory is **tracked in the public repository**; do not assume it offers secrecy or add more sensitive material there.

## How to ship a reviewable change
- Default to a **branch and pull request**. Do not push to `main`, deploy, or modify live Fridge services without explicit instruction from the owner.
- Read `docs/CODE_REVIEW.md` and fill out the PR template. Inspect the diff and report blocker/high/medium/low findings with file/line, rationale and proof. Distinguish unverified risks.
- Perform a local Godot import/parse check and **the one relevant behavior check**. Use `HEDGEPETS_FRESH=1` so tests do not touch the player's save. Offscreen runs always use `--audio-driver Dummy`.
- For visual code, capture the same view before and after; see `docs/VISUAL_REGRESSION.md`. Never silently refresh golden baselines. Do not overtest unrelated systems.
- After a change, state precisely: files changed, intended effect, verification actually run, untested items, and rollback.
- Preserve a functioning build over neat-looking abstractions. If a low-risk extraction unexpectedly fails, revert the extraction.

## Documentation map
| Work | Read |
| --- | --- |
| How the code is built (layer chains, trees, sky, seeds, budget) | `docs/ARCHITECTURE.md` |
| Garden gameplay, economy, save, pet wishes | `docs/GARDEN.md` |
| Garden world/props/camera | `docs/BACKYARD.md`, `docs/GARDEN.md` |
| Woods, nursery, lore boundaries | `docs/NURSERY.md` |
| Pet art and materials | `docs/ART_DIRECTION.md` |
| Animation behavior | `docs/MOTION.md` |
| Visual and performance regression | `docs/VISUAL_REGRESSION.md`, `docs/PERFORMANCE_BASELINE.md` |
| Generated world/editor | `docs/WORLD_ARCHITECTURE.md`, `docs/WORLD_EDITOR.md` |
| Running, checks, traps, deploy, go pages, telemetry | `docs/OPERATIONS.md` |
| Device/export | `docs/MOBILE.md`, `docs/OWNER_QUICKSTART.md` |
| Owner's unbuilt ideas | `docs/ideas/` |
| Old Codex briefs/reports (dated, historical) | `docs/archive/codex/` |

Do not edit dated documents to pretend old tests or deployments happened today. Update only the live rules and the documentation affected by the change.
