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
| 🌱 seeds | 17 plants: ivy, Boston ivy, Virginia creeper, variegated ivy, clover, fern, sage, jasmine, oak, pine, maple, boxwood, willow, rose, lavender, moss, holly |
| ✂️ shears | regraft a pet in the chosen seed's plant (its price) |
| 🧺 build | bird feeder 8, bird bath 10, log pile 6, nest box 7, pumpkin 3, crate of apples 5 (shovel them back for half) |
| 💧 water | a watered plant grows: mound → sprout → bush → flowering (~18 s a stage; water lasts ~40 s) |

Each pet has three sets of wishes in its profile (`CharacterArtProfile.wants`, with journal `hints`):

- **notice**: it peeks in through the gap in the fence,
- **visit**: it comes in and wanders around,
- **resident**: it moves in (🪙 +10), and while its wishes stay met it brings 🪙 2 every 30 s.

Pets: 47. The hand-made seven (`pets/*.tres`: Gerald, Bramble, Clover, Hazel, Juniper, Smudge,
Spruce) and 40 New England animals from data (`pets/species.json`, built by `scripts/art/species_builder.gd`): red
fox, eastern chipmunk, white-tailed fawn, black bear cub, striped skunk, opossum, woodchuck, porcupine, river otter,
bobcat, spring peeper, red eft, garter snake, wild turkey, black-capped chickadee, northern cardinal, blue jay,
American robin, mallard, barred owl, little brown bat, star-nosed mole, snowshoe hare, deer mouse, monarch
caterpillar. Names are our own: nothing that echoes another game's or show's characters (checked 2026-10-08; e.g. no Hoot,
Waddle, Chip, Woody, Ruby, Rascal). The roster is closed for now: polish before more animals. Some want each other: `has_<species>` counts residents (the jay wants the chipmunk to argue with).

**Attracting more.** *Appeal* = kinds of plants grown + kinds of things built + residents. More appeal means more
guests at once (3, up to 6) and new faces at the fence sooner (every 14 s, down to 5). Many wishes use the built things:
feeders bring the chickadee, cardinal, dove and jay; apples bring the bear cub and fawn; pumpkins the woodchuck and
the luna moth; the bath the robin; the nest box the bluebird; log piles the chipmunk, skunk, woodpecker and bobcat.

**Variants.** Every pet can come in up to four related plants (`SpeciesBuilder.GROUPS`), each with its own name: the
plant's word + the animal ("Maple Fox", "Creeper Fox", "Mossback Turtle", "Frostleaf Beaver", "Briar Bunny"). When a
pet arrives, it often comes made of one of its variant plants that you grow (stage 2+). New variants go in the
journal's collection (📖: appeal ★, variants found / total, each pet's row of variants, ? for unseen). Regrafting
with ✂️ doesn't count.

Pacing: at most 3 guests (peeking or visiting) at once, and a new face at the fence at most every 14 s. A pet's
node is only built the first time it comes by.

**Adding a pet** = one entry in `pets/species.json`: plan (quadruped sitter bird round long snail), plant, palette,
size/leg/neck/head/eyes, ears, snout, tail, extras, colours, wants and hints. The full vocabulary is at the top of
`species_builder.gd`. Check it with `DISPLAY=:0 godot --path . --script tools/capture_roster.gd && python3
tools/roster_sheet.py` (docs/acceptance/roster.png).

Residents live in it: they wander to the things and plants they wished for (`garden_game.gd:favourite()`) and
show it (💧 at the puddle, 💤 in the chair or tire, 🍂 in the leaves, 🌸 at a flowering plant). When idle they turn
three-quarters to the viewer. A happy resident leaves a **gift** every 30 s (🌰 🪶 🍄 🐚 💎 🌼 🫐, 2-6 coins) that
bobs in the grass until you tap it (any tool; gone after two minutes, at most 12 lying about).

A visitor whose wishes stop being met wanders off after ~20 s. Junk isn't all bad: Gerald wants sticks and the
puddle, Juniper the tipped chair, Bramble rocks. Clear everything and you lose them.

The wish keys come from `garden_game.gd:garden_counts()`: `puddle sticks branches rocks leaf_pile lawn_chair grill tire pot cleared`
and `<plant>_planted/_grown/_flowering`.

**Camera:** it orbits the middle of the garden. Drag sideways to spin it around (a fling keeps it turning a little),
drag up or down to tilt, wheel or pinch to zoom (8 to 24). There's no panning: the garden stays put and you walk
around it. The garden itself is still rectangular.

**All around it,** soft in the tilt-shift, each with its own way in (`garden.gd: GATES`, `gate_for`):

| side | world | gate | who comes that way |
|---|---|---|---|
| north | the burying ground | the broken fence | moths, bats, the woodchuck, snakes, the rest |
| east | woods (oaks, maples, pines) | the gap in the stone wall | fox, coyote, bobcat, fawn, moose, bear, owl, turkey... |
| west | a creek with cattails and rocks | the plank footbridge | otter, mink, frogs, turtles, ducks, the loon, Gerald |
| south | three houses (backs to the garden) | the garden gate, standing open | raccoon, opossum, skunk, mouse, bunny, songbirds |

Past the back fence: an old New England burying ground, autumn and not spooky. Slate stones in uneven rows, a low
field-stone wall, a big sugar maple gone crimson, one bare old tree, pumpkins along the fence, and fallen leaves
over the lawn (`_leaf_litter`). Static scenery is merged into one mesh per material (`GardenProps.bake_static`).

The scenery: a real puddle (`shaders/water.gdshader`: muddy rim, sky sheen, drip ripples; no grass in it), a New
England dry-stone wall down the side, maple leaves drifting from the oak crowns, six butterflies that visit flowering
plants, and a soft contact shadow under every pet. Tall oaks (leaning trunk, forked branches, a leaf clump per branch) and tiered pines whose crowns run
off the top of the screen and whose shade falls across the lawn; ankle-high grass tufts (22k, `tools/make_grass_sprites.py`)
over a lawn with fine blade grain (`shaders/lawn.gdshader`, `tools/make_lawn_detail.py`). Leaf styles for pets and plants:
ivy, clover, fern, jasmine, and `tools/make_leaf_styles.py`: oak (acorns), pine (cones), sage (lilac sprigs), maple
(winged seeds), boxwood, willow (catkins), rose, lavender; the
cell-13 bloom is tinted by `CharacterArtProfile.flower_color`.

Plants as fonts: the leaf sheets are baked from glyph fonts in `assets/fonts` (`tools/generate_hedgeink.py`, then
`tools/bake_leaf_sprites.py <name>`). HedgeMoss (star-moss tufts, feather moss, spore capsules as blooms) and HedgeHolly
(spined leaves, red berries) are the newest. Any pet can be regrown in any plant: 🍃 / F in the viewer, ✂️ shears in
the garden (regraft a pet in the chosen seed's plant for its price; saved). `SpeciesBuilder.PLANTS` gives each plant
its palette and bloom; `tools/capture_plants.gd` -> docs/acceptance/plants.png.

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
    HEDGEPETS_FRESH=1 DISPLAY=:0 godot --path . --script tools/garden_fps.gd       # ~3.5 ms/frame on the RTX 3050 (close other game windows first)

HEDGEPETS_FRESH=1 starts from a new garden and never reads or writes the player's save.
