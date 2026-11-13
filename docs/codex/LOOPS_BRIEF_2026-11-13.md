# Codex brief (2026-11-13): more gameplay loops - things to collect that draw hedgepets in

Read `AGENTS.md`, `docs/HANDOFF.md` (the owner's design rules are non-negotiable: no timers, urgency, streaks,
punishment or decay while away; "watching is valid play"; every visible change eases through
`scripts/anim/motion.gd`, `tools/motion_check.gd` passes; never name the nursery lady or the porch man), `docs/GARDEN.md`
(including yesterday's "garden as a whole" section), `docs/ART_DIRECTION.md`. You cannot run git: Claude reviews,
commits and deploys. Offscreen Godot runs ALWAYS take `--audio-driver Dummy`. Godot `~/.local/bin/godot` (4.7.2). The
game must hold ~30 fps on this 2012 MacBook Air and on an iPhone (low tier). You work in this worktree only
(`~/work/hp-loops`). Another Codex works on the woods' performance (woods.gd/distant_land.gd) and Claude on the garden
camera and fences (garden.gd camera code, garden_props fences, neighborhood.gd): avoid those areas; if you must touch
them, keep the change small and say so in the report.

**Do not change the hedgepets themselves** (meshes, art, materials, animation).

## The owner's words

"We have to add more gameplay loops, things to collect to attract hedgepets and get them to enter our garden etc."
The garden today: clear junk (coins), dig, sow, water, grow; build things (feeder, bath, log pile, nest box…); each
hedgepet notices -> visits -> moves in by its `wants` (`pets/species.json`, `CharacterArtProfile.wants`, the keys in
`garden_game.garden_counts()`); capacity 2-6; the journal (now with "Your garden": offers, who they draw, room);
cause-and-effect captions and first-arrival introductions (`scripts/garden/garden_story.gd`); the woods with finds
(`woods_finds`, the basket), the nursery, gifts residents leave, the contraband. Read all of it first and build on it.

## Build (design first, in the report, then the code)

Design 2-3 loops that make the garden feel more complete and give a reason to come back, each one feeding the
hedgepets' wishes - so collecting is how you draw particular hedgepets in. Directions to consider (pick the best, adapt):

1. **Foraging -> offerings.** Things to find and pick up (in the woods and around the garden's edges: acorns,
   pinecones, feathers, mushrooms, smooth stones, shells by the creek, seed heads, apples fallen from the neighbour's
   tree…), carried home in the basket and **set out as offerings** (a little dish, a stump, a windowsill, a shelf) that
   specific hedgepets love. New want keys (e.g. `acorns`, `feather`) for some pets in `species.json` so these matter,
   with hints in their words. Things found are restocked by the world gently (when you come back, not on a clock you
   can miss).
2. **A collection** - a page in the journal for everything found (each with a small line of what it is and who likes
   it, unknown ones as silhouettes "?"), so finding the rare ones is its own reward. Hedgepets' gifts can be
   collectables too.
3. **Favourites:** each hedgepet has one favourite thing; set it out and it comes closer sooner / visits more often /
   brings a better gift. Shown in its introduction card and journal entry once you've met it.

Rules: no timers or countdowns, nothing lost while away, nothing that punishes; all derived from data (one rule set:
the new things are counted in `garden_counts()`, wished for in `wants`, named in `garden_story.gd` WORDS/GROUPS so
"Your garden" and the captions pick them up automatically). Low cost: shared meshes/materials (one MultiMesh or
baked mesh per kind), no new per-frame work for idle items. Saved and restored like the rest of the game.

## Checks

Run every relevant `tools/*_check.gd` (story, game, yard, life, motion, nursery, hide, grab, den, woods…) and add
`tools/collect_check.gd` (find -> carry -> set out -> counts -> a hedgepet's wish met; saved and restored; nothing
decays while away). `life_check.gd` is known flaky (random pet life); report its result, don't chase it. Capture a few
views of the new things with software GL on a private X server (no xvfb-run here):

```
X=~/work/xvfb-local/root; export LD_LIBRARY_PATH=$X/usr/lib/x86_64-linux-gnu
$X/usr/bin/Xvfb :79 -screen 0 540x960x24 -nolisten tcp & XP=$!; sleep 3
DISPLAY=:79 <godot command with --rendering-driver opengl3 --resolution 540x960 ...>; kill $XP
```

(Use display :79.) A new `class_name` needs `godot --headless --path . --import` once before scripts can use it.

## Report

`docs/codex/REPORT_LOOPS_2026-11-13.md`: the design (each loop, why it's fun, how it feeds the wishes), what you built,
files changed, the new want keys and which pets got them, checks run with results, captures, open questions for the
owner. Also list the How to play changes the go page `/hedgepets/howto` needs (it lives in fridge-go; Claude makes them).
