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

Wind in the leaves high above the fence, always. Now and then:
- a chickadee (25-80 s apart, near the trees)
- a crow somewhere behind the trees (1-3 min)
- a branch creaking (1-3 min)
- a neighbour's wind chimes, faint (45-140 s)

Then quiet again. Every sound comes from a place, so turning the camera turns the yard. **M** mutes.

The sounds are synthesised (no recordings, no network). Real CC0 recordings dropped into `assets/audio/` with the same
names would replace them, with no code change.
