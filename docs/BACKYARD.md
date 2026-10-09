# The backyard (runbook)

> HedgePets should look like magical creatures inhabiting an ordinary backyard, not an ordinary backyard inhabiting a
> magical fantasy world.

An ordinary New England backyard where suburbia gives way to the woods. Somebody actually uses it. The world is
convincingly mundane, so a little shrub with eyes bouncing out of the woods is that much more delightful.
`docs/acceptance/backyard.png`.

## In the garden now

| From the reference | Where |
|---|---|
| **The woodland boundary:** a wall of tall trees behind the fence and down the sides | `garden.gd: _tree_wall`, 15-22 m trees, cheap far versions, paths open at the gates |
| **Uneven grass:** sunlit patches, fallen leaves, weeds | lawn macro + blade grain, leaf litter, weeds, bald spots |
| **The accumulated stuff** | branches, sticks, the tipped chair, a woodpile against the pine, **one chair standing alone mid-lawn** (somebody sits here to watch Cranberry do nothing) |
| **Afternoon light** | a low warm sun with long shadows; sunflecks drifting on the lawn and grass (`dapple.png` in `lawn` / `grass` shaders) |
| **The ordinary house** | white siding, blue door, small steps, behind the garden gate |
| **Scale** | trees tower over the yard: small, sheltered, connected to something bigger |

## More of the yard

- **The house that overlooks the garden** has a raised back porch: a plank deck on posts at first-floor height, a white
  railing with balusters, stairs down the side, a lattice skirt, the blue back door at deck level (`_back_porch`).
  It will keep getting more detailed.
- **New England stone walls:** flat field stones in tight staggered courses on two faces, leaning in, big flat caps
  (`stone_wall`). Rounded slabs, not bricks; sizes snap to a grid, so meshes are shared.
- **Long grass** along every fence and wall foot and around the trunks, where the mower never reaches (`_grass_edges`).
- **The sun follows the real time of day:** east over the woods in the morning, south over the houses at midday, west
  past the creek in the evening, golden when low; at night a held soft dusk. Soft shafts of light slant through the
  trees along it, strongest when the sun is low (`_build_sun`, `shaders/light_shaft.gdshader`). `HEDGEPETS_HOUR`
  pins the hour.
- **Hiding places:** a paint bucket by the gate, a big terracotta pot, the old stone well, and the burrow behind the
  bottom-corner tree (`scripts/garden/hideouts.gd`).
  - A pet walks over, hops onto the rim and slides down inside. The opening fills with its own leaves over its moss, a
    face (two eyes with light dots) peeks out, blinks and looks around. Coming out is the same backwards.
  - Tap a hideout to coax it out.
  - The burrow is also a way in: burrowing pets (chipmunk, woodchuck, mole, mouse) arrive as a face in its doorway,
    climb out, and leave back down it.
- **Mending:** hold on the broken sprinkler or a run of the back fence (no pulling) and it's fixed in a few seconds.
  - The sprinkler stands up and sprays in slow sweeps now and then, watering plants within reach.
  - Each fence run stands straight again; the collapsed gap becomes a pair of gates standing open.
- **The barrel** is emptied by the rubbish truck a few minutes after something goes in (or while you're away). You hear
  it out front: the engine, the lift, the bang, the reversing beep. The barrel shakes.

## Habitats (natural features, not gameplay furniture)

- **Brush pile** at the woodland edge: shelter for shy woodland visitors (fawn, porcupine, fisher, bobcat). Haul
  sticks and branches onto it and it grows (an alternative to the barrel).
- **Sunlit clearing:** the middle of the lawn free of junk (`clearing`). The robin and the turkey come when the grass
  is open.
- **Woodpile:** the chipmunk moves in.
- **Woodland edge:** everywhere along the fence; the woods gate is where the woodland pets come from.

The player then adds the birdbath, flowers, a nest box... and the yard gradually becomes their garden, still a real,
slightly messy patch of New England underneath.

## The soundscape (`scripts/garden/soundscape.gd`, sounds from `tools/make_soundscape.py`)

**Birds first.** A New England backyard chorus, someone singing every few seconds, never all at once:
- chickadee ("fee-bee")
- robin (carolling)
- cardinal ("cheer cheer" / "birdy birdy")
- song sparrow (notes and a buzzy trill)
- mourning dove (the low coo)
- blue jay (a scolding "jeer")
- now and then a crow

**Wind chimes** from the neighbours' porches, often: bright metal, a deeper set, wooden bamboo.

**The neighbourhood**, far off:
- a dog a couple of houses down
- a car going by out front
- somebody's screen door
- a leaf blower now and then
- a church bell from town

Every sound comes from a place, so turning the camera turns the yard. **M** mutes.

**Wind in the leaves:** a real recording of wind in the trees at a woodland edge over gardens, one quiet minute, low
rumble filtered out, looped (credit in `docs/CREDITS.md`). The synthesised attempts sounded like surf, then static.

The sounds are synthesised (no recordings, no network). Real CC0 recordings dropped into `assets/audio/` with the same
names would replace them, with no code change.
