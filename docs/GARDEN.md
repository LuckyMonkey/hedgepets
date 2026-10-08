# The garden

`res://garden.tscn` (the main scene) is a real back garden, not a show garden: a broken fence with a collapsed gap,
a tipped lawn chair, a rusty grill, a leaking sprinkler and its puddle, an old tire, a tipped pot, branches, sticks,
rocks and leaf piles, on a patchy lawn with weeds. A tilt-shift pass (`shaders/tilt_shift.gdshader`) makes it read
like a tabletop model.

## The loop

| Tool | Does |
|---|---|
| ✋ hand | tap: pet a pet, look at things. Press and drag on junk: yank it loose, haul it (see Yard work) |
| 🪏 shovel | dig a seedbed on bare lawn; scoop up a leaf pile or something you built (junk is too heavy: haul it) |
| 🌱 seeds | 17 plants: ivy, Boston ivy, Virginia creeper, variegated ivy, clover, fern, sage, jasmine, oak, pine, maple, boxwood, willow, rose, lavender, moss, holly |
| ✂️ shears | regraft a pet in the chosen seed's plant (its price) |
| 🧺 build | bird feeder 8, bird bath 10, log pile 6, nest box 7, pumpkin 3, crate of apples 5 (shovel them back for half) |
| 💧 water | a watered plant grows: mound → sprout → bush → flowering (~18 s a stage; water lasts ~40 s) |

## Yard work (`scripts/garden/garden_grab.gd`)

Everything is heavier than it looks, in pounds: stick 2, pot 15, branch 15, chair 25, tire 25, rocks 20-130, grill
90, and of what you can build, bird bath 120, log pile 80.

- **Yank.** Most junk is stuck: bedded in the lawn, sunk in mud, rusted in place. Hold and pull. Strain builds (a ring
  at your finger, yellow to red), the thing leans toward you and shakes. A steady pull works on light things; heavy
  ones need **jerks** (fast flicks count for nearly three times a steady pull), and a big rock won't come for a
  steady pull at all. Ease off and the strain relaxes. At full strain it tears free: dirt flies, it hops, and it
  leaves a bare patch where it lay.
- **Haul.** Once free it follows your hand on a spring that's stiffer the lighter it is: light things lift and swing,
  heavy ones scrape along the ground, tilted, slow, kicking up dust. Let go and it thuds down there.
- **Bin it.** Drop junk in the **trash barrel** by the garden gate. It only holds **100 lb** (the lid rides up as it
  fills; a tag over it says how full), so a 132 lb rock never goes in: find it a place instead. Tap the barrel for its
  status, tap again to **call the pickup**: 🪙 8, the hauler pays scrap for what's inside, and the next pickup can't
  come for **3 minutes** (real time, so it runs while the game is closed). Fill it well before you call. You can't
  clear the whole yard at once.
- **Fix.** The tipped lawn chair rights itself when you yank it free. Work the rusty grill in circles while you hold
  it and the rust scrubs off (three turns): a clean grill sells for 12 more.

**Collisions.** Everything solid is a circle: trunks, walls, junk, things you built, the barrel, every pet (sticks
and leaf piles you walk over). Pets steer around what's ahead, give up on a spot they're boxed out of, and are pushed
out of anything they end up in, including junk you haul into them. Hauled junk stops against trunks, walls and other
things. `tools/collision_check.gd`: a dozen pets roam for 40 s and never sit inside anything.

**Camera vs trees.** Everything in the garden dissolves right in front of the camera (an ordered dither,
`shaders/near_fade.gdshaderinc`, and StandardMaterial's pixel-dither distance fade), so the camera can pass a trunk or
through a crown without a screenful of leaves.

Moved, loosened, righted and scrubbed things, and the barrel, are saved. `tools/grab_check.gd --fixed-fps 60` drives all of it like
a real hand: a stick yanked and binned, a full barrel refusing a rock, a pickup with its fee and cooldown, a 132 lb rock that holds against a steady pull but comes with jerks, the chair,
the grill.

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

**Camera:**
- **Left drag / one finger:** turn slowly around the point you're looking at, with no glide afterward, and tilt a little.
- **Right drag / two fingers:** pan. The ground follows your hand.
- **Wheel / pinch:** zoom from 4.5 (a pet's-eye close-up) to 24 (the whole garden). Up close, the camera drops toward
  eye level, so you see faces.
- **Keys:** WASD / arrows pan, Q / E turn, R / F zoom.

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
