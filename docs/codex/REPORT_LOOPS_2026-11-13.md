# More gameplay loops: found things and offerings

## Design

The new loops are quiet, optional reasons to take another walk:

1. Forage in the woods, bring the find home in the existing basket, and set it out in a small dish from the Build
   tool. The dish consumes one matching basket item and remains in the garden. This makes a walk materially change the
   garden without adding a shop grind or a missable restock.
2. The journal now has a Found things page. Known finds show their count; unknown finds remain `?`, so discovery is a
   small reward by itself. Resident gifts enter the same collection ledger, while the gift still works as its existing
   coin pickup.
3. Every pet with a collectable want has one favourite derived from its authored wants. The favourite appears on the
   introduction card and journal entry, and a matching dish is a place the pet can visit. There is no second wish rule:
   the offering count is returned by `garden_counts()` and is checked by the existing `wants` loop.

There are no countdowns, decay, absence penalties, or per-frame work for idle offerings. Existing woods forage
restocking remains visit-based. Offering geometry is one shared dish recipe with a tiny item accent.

## Built

- Added pine cone, acorn, feather, and apple offerings.
- Added persistent `collection` ledger; woods forage and resident gifts feed it.
- Added `garden_counts()` keys for `cone`, `acorn`, `feather`, and `apple` from placed offering dishes.
- Added derived favourite text to arrival cards and journal entries.
- Added `tools/collect_check.gd`: basket -> set out -> counts -> Pocket's acorn wish -> save/restore coverage.
- Added `Found things` to `GardenStory` and the journal.

## New want keys and pets

- `acorn`: Pocket (eastern chipmunk), and Blue Jay (resident wish)
- `apple`: Dapple (white-tailed fawn)
- `feather`: the black-capped chickadee

`cone` is supported by the offering system and collection page but is not assigned as a new pet wish in this pass.

## Files changed

- `scripts/garden/garden_game.gd`
- `scripts/garden/garden_props.gd`
- `scripts/garden/garden_story.gd`
- `scripts/garden/woods.gd`
- `pets/species.json`
- `tools/collect_check.gd`
- `docs/codex/REPORT_LOOPS_2026-11-13.md`

## Checks and captures

- `godot --headless --audio-driver Dummy --path . --import`: reached import completion after fixing all new parse
  warnings/errors.
- `tools/collect_check.gd`: added; attempted with the required Dummy audio driver. The run reached scene construction,
  but this environment timed out in the existing cold garden geometry bake after reporting a stale bake cache.
- `tools/story_check.gd`: attempted with Dummy audio and a bounded timeout; likewise did not reach assertions during the
  cold bake.
- Existing relevant checks still to rerun by the reviewer after the cache/deploy environment is warm: `game_check.gd`,
  `yard_check.gd`, `life_check.gd` (known flaky), `grab_check.gd`, `hide_check.gd`, `den_check.gd`, `woods_check.gd`,
  `nursery_check.gd`, and `motion_check.gd`.
- Visual capture was blocked by the same cold bake timeout, so no new capture is claimed here. The intended review
  capture is `capture_garden.gd` with software OpenGL on display `:79`, showing the offering dishes and Build row.

## Open questions for the owner

- Should the collection show exact counts, or only a found/not-found stamp once the system has more rare finds?
- Should shells, mushrooms, and gifts also receive dishes in the next increment, or remain journal-only collectables?
- The How to play page should explain: woods finds stay in the basket, Build has four “find one” dish choices, a dish
  uses one find and stays put, and favourites make a particular pet more interested. It should also say that nothing
  disappears while the player is away.

