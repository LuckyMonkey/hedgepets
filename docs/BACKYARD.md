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

**On hold:** the wind in the leaves and the ambient bed (`WIND = false` in soundscape.gd). Synthesised, they sounded
like surf, then like static. They're waiting for a real recording.

The sounds are synthesised (no recordings, no network). Real CC0 recordings dropped into `assets/audio/` with the same
names would replace them, with no code change.
