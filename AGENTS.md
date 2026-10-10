# HedgePets: agents start here

Read `docs/HANDOFF.md` first. It covers the design rules (the owner's, non-negotiable), the file map, the checks,
deploys, the go pages (feedback, how-to, telemetry) and open items.

- Run the relevant `tools/*_check.gd` before every commit. Judge visuals by captures.
- Ship each verified increment: commit, push, `tools/deploy_web.sh`.
- Never name the nursery lady or the porch man in game text, code or comments (`docs/private/LORE.md`).
