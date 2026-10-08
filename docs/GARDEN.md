# The garden

`res://garden.tscn` (the main scene) is a real back garden, not a show garden: a broken fence with a collapsed gap,
a tipped lawn chair, a rusty grill, a leaking sprinkler and its puddle, an old tire, a tipped pot, branches, sticks,
rocks and leaf piles, on a patchy lawn with weeds. A tilt-shift pass (`shaders/tilt_shift.gdshader`) makes it read
like a tabletop model.

## The loop

| Tool | Does |
|---|---|
| ✋ hand | pet a pet (it hops and says how it feels), look at things |
| 🪏 shovel | clear junk for coins (each thing has a scrap value); dig a seedbed on bare lawn |
| 🌱 seeds | 12 plants: ivy, clover, fern, sage, jasmine, oak, pine, maple, boxwood, willow, rose, lavender |
| 💧 water | a watered plant grows: mound → sprout → bush → flowering (~18 s a stage; water lasts ~40 s) |

Each pet has three sets of wishes in its profile (`CharacterArtProfile.wants`, with journal `hints`):

- **notice**: it peeks in through the gap in the fence,
- **visit**: it comes in and wanders around,
- **resident**: it moves in (🪙 +10), and while its wishes stay met it brings 🪙 2 every 30 s.

Pets: 32 and counting. The hand-made seven (`pets/*.tres`: Gerald, Bramble, Clover, Hazel, Juniper, Rascal,
Spruce) and 25 New England animals from data (`pets/species.json`, built by `scripts/art/species_builder.gd`): red
fox, eastern chipmunk, white-tailed fawn, black bear cub, striped skunk, opossum, woodchuck, porcupine, river otter,
bobcat, spring peeper, red eft, garter snake, wild turkey, black-capped chickadee, northern cardinal, blue jay,
American robin, mallard, barred owl, little brown bat, star-nosed mole, snowshoe hare, deer mouse, monarch
caterpillar. Some want each other: `has_<species>` counts residents (the jay wants the chipmunk to argue with).

Pacing: at most 3 guests (peeking or visiting) at once, and a new face at the fence at most every 14 s. A pet's
node is only built the first time it comes by.

**Adding a pet** = one entry in `pets/species.json`: plan (quadruped sitter bird round long snail), plant, palette,
size/leg/neck/head/eyes, ears, snout, tail, extras, colours, wants and hints. The full vocabulary is at the top of
`species_builder.gd`. Check it with `DISPLAY=:0 godot --path . --script tools/capture_roster.gd && python3
tools/roster_sheet.py` (docs/acceptance/roster.png).

A visitor whose wishes stop being met wanders off after ~20 s. Junk isn't all bad: Gerald wants sticks and the
puddle, Juniper the tipped chair, Bramble rocks. Clear everything and you lose them.

The wish keys come from `garden_game.gd:garden_counts()`: `puddle sticks branches rocks leaf_pile lawn_chair grill tire pot cleared`
and `<plant>_planted/_grown/_flowering`.

The scenery: tall oaks (leaning trunk, forked branches, a leaf clump per branch) and tiered pines whose crowns run
off the top of the screen and whose shade falls across the lawn; ankle-high grass tufts (22k, `tools/make_grass_sprites.py`)
over a lawn with fine blade grain (`shaders/lawn.gdshader`, `tools/make_lawn_detail.py`). Leaf styles for pets and plants:
ivy, clover, fern, jasmine, and `tools/make_leaf_styles.py`: oak (acorns), pine (cones), sage (lilac sprigs), maple
(winged seeds), boxwood, willow (catkins), rose, lavender; the
cell-13 bloom is tinted by `CharacterArtProfile.flower_color`.

📖 is the journal. Progress autosaves to `user://garden.json`.

## Code

- `scripts/garden/garden.gd`: world, props registry (`things`, `count()`), grass, pets walking (modes away / peek /
  roam / leave), camera pan/zoom, taps.
- `scripts/garden/garden_game.gd`: tools, plants, wishes, coins, journal, toasts, save.
- `scripts/garden/garden_props.gd`: the junk, built from primitives with ink hulls.

## Checks

    godot --headless --path . --script tools/game_check.gd     # plays the loop: clear, plant, grow, a pet moves in
    HEDGEPETS_FRESH=1 DISPLAY=:0 godot --path . --script tools/capture_garden.gd   # /tmp/hedgepets-views/garden.png
                                                               # FRAMES=700 later in time, DIST=30 zoomed out
    HEDGEPETS_FRESH=1 DISPLAY=:0 godot --path . --script tools/garden_fps.gd       # ~3.5 ms/frame on the RTX 3050

HEDGEPETS_FRESH=1 starts from a new garden and never reads or writes the player's save.
