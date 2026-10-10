# The garden

`res://garden.tscn` (the main scene) is a real back garden, not a show garden: a broken fence with a collapsed gap,
a tipped lawn chair, a rusty grill, a leaking sprinkler and its puddle, an old tire, a tipped pot, branches, sticks,
rocks and leaf piles, on a patchy lawn with weeds. A tilt-shift pass (`shaders/tilt_shift.gdshader`) makes it read
like a tabletop model.

## The loop

| Tool | Does |
|---|---|
| ✋ hand | tap: pet a pet, look at things (broken things say how to fix them). Press and drag on junk: yank it loose, haul it (see Yard work). Hold on the broken sprinkler or a broken run of fence: it mends. Tap a fire pit: light it. Tap a bucket with a pet in it: pick it up and carry it; tap the lawn to set it down |
| 🪏 shovel | dig a hole anywhere clear; dig beside a hole and it joins it, one step along in that direction (rows, curves, plots). The dirt goes on a pile beside it. Tap a pile: a shovelful; then tap a hole to fill it (or the lawn to put it down). Tap a sown hole: dig it back up (seeds and sprouts come back as seeds). Tap junk: clear it |
| 🌱 seeds | sow in a hole. Seeds you were given (the nursery, the woods) are sown first, free |
| ✂️ shears | regraft a pet in the chosen seed's plant (its price) |
| 🧺 build | bird feeder 8, bird bath 10, log pile 6, birdhouse 7, pumpkin 3, crate of apples 5, bucket, clay pot, lawn chair, hay bale, scarecrow, lantern, stepping stones, **fire pit 6** (shovel them back for half) |
| 💧 water | **hold and drag to pour.** Plants under it are watered; a wet trail darkens the grass and dries in 25 s. Hedgepets love water: visitors and residents within 7 m trot after it, and the ones that reach it walk with you for a while (up to 3; into the woods too). Pour a trail into an empty bucket and the first to reach it climbs in. A quick tap still waters one plant or splashes a pet |

The chosen tool has a green chip behind it that glides from tool to tool, and a caption over the bar says what it
does. Picking a seed or a thing to build says its name and price.

**Growing.** Everything planted grows: slowly on its own, three times as fast while watered (wet soil looks dark). The
fixed sprinkler waters whatever it reaches every minute. mound → sprout → bush → flowering, about 18 s a stage watered.

**Dirt and the wheelbarrow.** Dirt piles (up to 4 loads each) are saved. The wheelbarrow (by the houses' gate) hauls
with ✋: rolled over a pile it shovels the pile in (up to 4 loads, heaped in its tray), and let go over holes it
fills them. 🪏 on the wheelbarrow takes a shovelful out of it (or puts one in).

**Room for six.** The garden holds 2 hedgepets at once to begin with, residents included, and one more for every three
kinds of plants grown or things built, up to 6 (`capacity()`). A hedgepet only notices a garden that grows one of its
plants (`grows_for`: its own or a related one, `SpeciesBuilder.variants_of`). The journal's "around the neighbourhood"
says which plants each is seen near. A resident whose wishes go unmet for 10 minutes moves on (it may come back
another day; Gerald never leaves). They aren't a collection: every garden ends up with its own.

**The fire pit** (`fire_pit.gd`): ✋ lights it; it burns 4 minutes, then embers for 1.5, and residents like to sit by
it (🔥). There's another in the woods, in fern hollow.

**The porch** (`porch_watcher.gd`): the house with the blue door has a raised back porch whose stairs come down to the
gate in the picket fence. A man comes out onto it when you're not looking and photographs the hedgepets (a flash now
and then at the edge of your view). When the camera finds him he either pockets the phone and studies the sky, or
hurries back in.

## Yard work (`scripts/garden/garden_grab.gd`)

Everything is heavier than it looks, in pounds: stick 2, pot 15, branch 15, chair 25, tire 25, rocks 20-130, grill
90, and of what you can build, bird bath 120, log pile 80.

- **Yank.** Most junk is stuck: bedded in the lawn, sunk in mud, rusted in place. Hold and pull. Strain builds (a ring
  at your finger, yellow to red), the thing leans toward you and shakes. A steady pull works on light things; heavy
  ones take longer. A **slow, steady pull frees anything** (a 132 lb rock in about 5 s); quick jerks are an optional
  shortcut (about 1.5 s), never required. Ease off and the strain relaxes. At full strain it tears free: dirt flies, it hops, and it
  leaves a bare patch where it lay.
- **Haul.** Once free it follows your hand on a spring that's stiffer the lighter it is: light things lift and swing,
  heavy ones scrape along the ground, tilted, slow, kicking up dust. Let go and it thuds down there.
- **Bin it.** Drop junk in the **trash barrel** by the garden gate. It only holds **100 lb** (the lid rides up as it
  fills; a tag over it says how full), so a 132 lb rock never goes in: find it a place instead. The **rubbish truck
  comes by on its own** a few minutes after something goes in (or while you're away) and empties it, paying a little
  scrap. No fee, no countdown, nothing to call: the yard just gets cleared gradually.
- **Fix.** The tipped lawn chair rights itself when you yank it free. Work the rusty grill in circles while you hold
  it and the rust scrubs off (three turns): a clean grill sells for 12 more.

**Collisions.** Everything solid is a circle: trunks, walls, junk, things you built, the barrel, every pet (sticks
and leaf piles you walk over). Pets steer around what's ahead, give up on a spot they're boxed out of, and are pushed
out of anything they end up in, including junk you haul into them. Hauled junk stops against trunks, walls and other
things. `tools/collision_check.gd`: a dozen pets roam for 40 s and never sit inside anything.

**Never stuck.** Every place a pet heads for (a random spot, beside a favourite thing, a gate's first steps) is
moved to where *that* pet fits (`free_spot`, by its own radius), and straight-line paths are checked at its size.
Steering is smoothed so it can't flip sides every frame, and pets shuffle forward while turning (no spinning in
place). Progress, not motion, decides when it's blocked: no 0.25 m closer in 1.5 s means "close enough" near the goal,
or a new goal far from it. `tools/stuck_check.gd`: 12 pets for 90 s, no stuck stretch over 4 s, under 15% of walks
abandoned, never more than 3 in a row (Gerald alone: none).

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
bobs in the grass until you tap it (any tool). Gifts never disappear (they're saved); at most 12 lie about.

## Small moments (the design: docs say "a place, not a treadmill")

- **It notices you.** The pet nearest the pointer looks up at you with a curious head tilt (mouse; on touch, tap).
- **Naps.** Residents sometimes fall asleep wherever they happen to be, however inconvenient: eyes shut, slow breaths,
  head down, a 💤 now and then. Sometimes one curls up beside a friend who's already napping (💕). They wake on their own,
  or when you tap them.
- **Shaking off.** Water a pet with 💧 and it shakes the water off, droplets flying.
- **A flower, just because.** Every few minutes a resident may grow a single flower somewhere unexpected (up to three
  each). They're saved, and stay through a regraft.
- **Coming back.** Nothing decays while you're away. After a long absence the garden welcomes you, a resident or two may
  have flowered, the truck has been, gifts are where they fell.
- **No scores.** The journal shows who you've met and the variants you've seen them as, by name: no totals.

`tools/life_check.gd` checks all of it (17 naps and 5 curl-ups in 3 minutes with six residents; a 3-day absence).

A visitor whose wishes stop being met lingers a long while (4 minutes inside, 1.5 at the fence) before wandering home for now. Junk isn't all bad: Gerald wants sticks and the
puddle, Juniper the tipped chair, Bramble rocks. Clear everything and you lose them.

The wish keys come from `garden_game.gd:garden_counts()`: `puddle sticks branches rocks leaf_pile lawn_chair grill tire pot cleared`
and `<plant>_planted/_grown/_flowering`.

**Camera:**
- **One finger:** where it lands decides. The top half of the screen turns slowly around the point you're looking at
  (no glide afterward) and tilts a little; the bottom half pans, the ground following your hand. The line between
  them is invisible and never explained: you just find it works.
- **Mouse:** left drag turns, right drag pans.
- **Two fingers:** pan with their midpoint and pinch to zoom.
- **Wheel / pinch:** zoom from 4.5 (a pet's-eye close-up) to 24 (the whole garden). Up close, the camera drops toward
  eye level, so you see faces.
- **Keys:** WASD / arrows pan, Q / E turn, R / F zoom.

**Building and arranging (🧺):** 13 things to put out - feeder, bird bath, log pile, nest box, pumpkin, apples,
steel bucket, clay pot, lawn chair, hay bale, scarecrow, garden lantern, stepping stones. Tap the lawn to put the
chosen one down. With 🧺 out, **drag** something you built to move it and **tap** it to turn it an eighth; a drop
onto something else eases back. A placed bucket or clay pot is a hideout like the others, and nobody gets shovelled
out of one. Where everything stands is saved from where it really is (moved with 🧺 or hauled with ✋).

**The burrow** (`den.gd`): tap the burrow with ✋ when nobody's in the doorway, or the 🕳️ button. Down below is a round
room with roots through the ceiling, a jar of fireflies for a lamp and daylight down the tunnel; up to five residents
curl up asleep on moss beds, and a tap makes one stir. The garden waits while you're down there (paused, its sounds
muffled overhead) and every pet is back exactly where it was when you come up. `tools/den_check.gd` checks the visit,
arranging and the save rule.

**Friends:** the 🐾 tool is gone; water does it now (see 💧). Followers keep near whatever you're looking at when you
aren't pouring. A pet in a bucket you're carrying is out of the garden's hands until you set the bucket down. Both are
saved.

**The woods** (`woods.gd`, over the footbridge: tap the bridge): a dark, hilly hiking trail at night - lanterns at
every clearing, fireflies, the moon over the ridge. You stand in a clearing and turn (drag anywhere); the trails out of
it are signed, and the one you're facing lights up. Tap and you walk it, up and down the hills, to the next clearing:
the trailhead, the mossy fork (the hub), fern hollow, the ridge (an overlook), creek crossing (a real creek), the old oak,
and the nursery off the fork, where the lady potting at her bench has something to say and seeds for you. Each clearing
has things to find: litter and dumped junk (coins), forage for the nursery's basket, and wild seeds. See docs/NURSERY.md. Your followers trail behind you and gather round when you stop; a pet in the
bucket sits beside you in it, and *Let out* makes it one more follower, home with you afterwards.
The burrow and the woods share `elsewhere.gd` (going, coming back, borrowing pets); `tools/woods_check.gd`.

**Saving:** every 8 s and the moment you leave (tab hidden, app backgrounded, window closed). On the web the save also
goes to the browser's localStorage, written at once; loading takes whichever copy is newer (`WebSave`).

**Loading:** in an exported game the garden is built a step at a time behind a card ("Letting the grass grow...") that
continues the browser's splash, so nothing ever looks frozen. The grass comes from the startup cache. Measured in a
desktop browser: 24 s on a first visit, almost all of it WebGL compiling shaders the first time they're drawn; 9 s on
a repeat visit, when the browser has kept them. Every launch prints `HedgePets: garden ready in ... ms {per step}`.

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
