# The nursery, the woods' finds, and what plants pass on

Before you change the nursery lady or her lines, also read `docs/private/LORE.md`. It is development-only and never
shipped (`docs/*` is excluded from every export preset).

## The nursery (`scripts/garden/nursery.gd`)

The nursery is at the end of its trail off the mossy fork in the woods. It has a lamplit glasshouse, a potting bench,
a cabinet of labelled seed drawers, two beehives, a cold frame of lettuces with a small scarecrow, a stack of pots and
a water butt. She stands behind the bench, potting by lantern light, and now and then she glances up.

- **Talking.** Tap her for one line. Tap again for another. There are no menus or choices, no relationship meter, and
  no log of what she's said. She greets you once when you arrive.
- **Lines.** They live in `assets/talk/nursery.json`. Each has an `id`, a `kind` (`greet`, `talk` or `gift`), optional
  `when` conditions, `text`, and optional `once`. The conditions are:
  - `visits_min`, `visits_max`
  - `season`: the real date
  - `hour`: the real clock (morning, day, evening or night)
  - `grows` and `flowering`: a plant kind; `flowering: ""` means any, and fills `{plant}`
  - `resident`: a word from a resident's species, such as `fox`
  - `with`: a word from a following pet's species, or `""` for any; fills `{pet}`
  - `carried`, `wants` (a wish key some peeking or visiting pet is still missing), `volunteers`, `crossed`,
    `returned`, `pale`, `short`, `kept`

  A line whose condition the game doesn't know is never said. The more particular a line, the likelier it is to be
  picked. She won't repeat any of her last 24 lines (`game.nursery.said`).
- **Familiarity, shown rather than scored.** From the sixth visit, your usual sack of potting mix is waiting on the
  counter. On the third visit a twist of newspaper sits on the bench. Your next tap gets three seeds of her old
  lavender, which is white-flowered and short (`cctt`).
- **The basket.** She buys what you've foraged in the woods: cones and acorns 🪙1 each, mushrooms and feathers 🪙2
  each, with a line about what she'll do with them.
- **Adding lines.** Keep her a person: practical, dry and observant, with the occasional strange specific. She is
  not an oracle, a quest-giver or a tutorial. She never explains herself. Run `tools/nursery_check.gd`; it fails on
  any name in the list at its top.

## What plants pass on (`scripts/garden/heredity.gd`)

Every garden plant carries `genes`, a four-letter string such as `CcTt`. It holds two pairs:

| Pair | Shows as |
|---|---|
| `C` / `c` | coloured flowers, or near-white flowers (only noticeable on kinds that bloom in colour) |
| `T` / `t` | full size, or short (`Heredity.SHORT` = 0.66 of the size, from the bush stage) |

One capital is enough to show the trait. Shop packets are `CCTT`.

- **Self-sowing.** Every 45 s, an empty seedbed within 5 m of a flowering plant may get a seedling of its own (40%).
  It takes one letter of each pair from that plant and one from any flowering plant of the same kind, which may be
  the same plant. You get a toast, and the seedling grows like any other.
- **Wild seeds** from the woods have random letters: each is small with p = 0.3.
- **Showing it.** The garden never shows the letters. ✋ on a plant says what you'd see: "A short lavender, in
  flower - white ones. It came up on its own." Flowers on garden plants now take their kind's own bloom colour (until
  now every bush had cream flowers).
- **Saved:** `beds[].plant.genes` and `.origin` (`seed`, `volunteer` or `nursery`). `game.nursery.crossed` is set when
  parents with different letters made a seedling. `game.nursery.returned` is set when a seedling shows a trait
  neither parent showed.

## The woods' finds (`woods.gd`: FINDS, SPOTS)

Each clearing except the nursery has five things to find, in the same spots every visit. Tap one from the clearing.
Small things glint.

| What | Kinds | Does |
|---|---|---|
| litter | can, bottle, wrapper | 🪙 1, gone for good |
| junk | tarp (trailhead), oil drum (ridge), tire in the creek, fishing line in the reeds | 2-3 tugs, 🪙 3-6, gone for good |
| forage | cone, acorn, mushroom, feather | into the 🧺 basket (top left); the nursery buys it |
| seeds | one per clearing: clover, moss, fern, pine, willow, oak | two wild seeds into the 🌱 tray |

Forage and seeds grow back after 20 minutes of real time (`REGROW`). Nothing expires, and nothing is lost by staying
away. The 🌱 tool sows a kept seed (from the nursery or the woods) before buying a packet of that kind.

## Daytime in the woods

The woods are always a bright morning outside and deep blue-green shade under the trees. There's a sky with the sun
out past the ridge, a blue haze between the trunks, canopy shadows, and about 40 slanting sunbeams (the garden's
`light_shaft.gdshader`, stronger) with motes turning in them. The lanterns are lit but low.

## Walking, choosing, loading

- **Choosing a trail.** A tap picks the trail whose first few metres (or sign) is nearest the tap on screen. Away from
  all of them, it picks the one you're facing. Three chevrons glow on the ground along the trail a tap would take.
- **Spacing.** Trails leave and reach every clearing straight on, for the first 5 m (`_trail`), so they never bunch
  up.
- **Water.** No trail dips under water: over the creek or the pond it rides on the stones (`water_at`). The creek runs
  off the map at both ends.
- **Building.** The first visit builds in steps (`build_steps`) behind a loading card (`Elsewhere._build_staged`,
  the garden's `loading_card.gd`). The woods are in the bake (`tools/bake_cache.gd`: `woods.build_now()`), so with the
  cache they build in about 0.5 s on desktop (9.9 s without).

## Detail

- **Trails:** a pale worn middle, loose darker soil to the sides, and a wandering edge. Pebbles, fallen autumn leaves,
  and now and then a root across the path.
- **Trees:** the 110 trees nearest the trails have leafy crowns made with the hedgepets' foliage. There are six
  shared templates with fixed seeds, oak, maple, ivy and box leaves (`CROWNS`). The rest stay simple.
- **Weeping willows:** seven, on the creek banks and by the pond, each with a curtain of strands swaying as one.
- **Forest floor:** about 170 things off the trails (logs with moss on top, stumps, mossy boulders, clusters of
  mushrooms), all in multimeshes.
- **Wild hedgepets** (`WILD_COUNT` 4): pets that don't live in your garden appear off the trail ahead of you and nose
  about, watching you. Closer than 6 m, they scurry off. Left 30 m behind, they slip away and turn up further on. A
  tap tells you who it was. They're borrowed garden nodes, given back when you leave.

## The places look like their names

- **Mossy fork:** mossy boulders.
- **Fern hollow:** thick ferns.
- **Ridge:** the land falls away to the east-northeast. You look out past lichened rocks over a misty valley, hills
  behind hills, a few porch lights and the moon. There's a weathered bench and a cairn.
- **Creek crossing:** a winding creek in its channel, about 90 m long, with banks of rocks and cattails. Both trails
  cross it on stepping stones.
- **Old oak:** one huge tree alone in a glade, with furrowed bark, roots, a hollow and a crown of six great limbs.
- **Trailhead:** a roofed board.
- **Beaver pond** (a dead end south of the creek crossing): still water in a bowl, a lodge of sticks and mud, a dam,
  lily pads, cattails, and stumps gnawed to a point.
- **Cellar hole** (off the trailhead and fern hollow): the stone-lined pit of a long-gone farmhouse, with a granite
  step, a chimney base, a huge old lilac, and the dooryard apple tree (apples for the basket, wild rose seeds).
- **Campfire** in fern hollow: tap it to light it.

Checks: `tools/nursery_check.gd --fixed-fps 60` (headless) and `tools/woods_check.gd`. To see each place:
`DISPLAY=:0 godot --path . --script tools/capture_places.gd --disable-vsync`.
