# The People Who Came Before (development only, never shipped)

This file must stay out of every build. `docs/*` is in `exclude_filter` for every export preset. Its contents must
never appear in player-facing text, UI, data files, code comments or credits. `tools/nursery_check.gd` fails if a
name from its `NEVER` list shows up in the dialogue or the garden scripts.

## The two influences

The brief named them only as **B.P.** (the elderly woman at the nursery) and **Greg M.** (an unseen influence on the
botany). The implementation reads them as **Beatrix Potter** and **Gregor Mendel**. *If that reading is wrong,* the
lines and props tagged below are the ones to change. Everything else stands on its own.

### B.P.: the nursery lady (on screen, unnamed)

The game never shows her name, initials or significance. In game she is "the lady at the nursery", and she has no
name label even on her speech card. The reveal is reserved for later. It should feel like recognition, not a twist.
The design notes' rule still holds: she is never evil, and there is no betrayal.

Fingerprints placed now, all deniable and all in `assets/talk/nursery.json` or the nursery set:

| Where | What | Reads to a knowledgeable player as |
|---|---|---|
| `t-hedgehog-train` | took a hedgehog on a train | travelled with her pet hedgehog |
| `t-drawing` | "always drawn things... to look at them properly" | naturalist illustrator |
| `t-code` (visits 5+) | diary kept in a code as a girl | the coded journal |
| `t-spores` (visits 9+, once) | grew spores on a windowsill; "a man had to read it out for me" | the 1897 fungi paper, read for her |
| `t-lichen` (visits 6+) | lichen is two things; "a roomful of gentlemen" | her support of lichen symbiosis |
| `t-sheep` (visits 4+) | hill lambs are born black and go grey | Herdwick sheep |
| `t-land` (visits 10+, once) | "unless it needs saving, then buy all of it" | the farms she bought and left to be preserved |
| `t-jacket` (visits 8+) + the cold frame | a small blue coat with brass buttons and little shoes on the scarecrow, left behind "in a hurry" | the garden-gate escape |
| `r-fox` | "a gentleman with sandy whiskers. Ask any duck." | |
| `r-squirrel` | squirrels would go to sea | |
| `r-mouse` | mice finish the sewing, "never the last buttonhole" | |
| `r-owl` | don't ask an owl a riddle | |
| `r-frog` | frogs go fishing, never catch a thing | |
| `r-duck` | ducks take nesting advice from anyone | |
| `r-hare` | rabbits always find the lettuces | |
| `t-coldframe` | something neat at the cold frame, took only the best ones | |
| the 🧺 trade | "I don't eat these. I draw them." (mushrooms) | |

Lines that are hers in spirit but unattributable: everything about patience, leaves over flowers, untidy corners,
and "Somebody paid attention."

### Greg M.: the unseen influence (never on screen)

He is never named, never a character, and never in books, plaques or credits. He exists only in how plants behave:

- **The rules themselves** (`heredity.gd`): paired factors, a dominant and a recessive form, one of each pair from
  each parent, and two traits that assort independently. Flower colour (coloured/white) and stature (tall/short)
  are two of the seven traits in the original pea experiments, and purple over white was one of them.
- **What a player can live through without being told:** her white, short lavender crossed with shop lavender gives
  self-sown children that are all purple and tall. Their children bring white back in about a quarter (3:1), short
  in about a quarter, and both in about a sixteenth (9:3:3:1). `tools/nursery_check.gd` verifies the proportions.
- **The bench tableau:** four potted lavenders, three purple and one white, tall and short mixed.
- **The setting:** a seed cabinet of identically labelled drawers ("unusually systematic"), and beehives.
- **Her lines that touch it** (she never explains): `t-bees` (beekeeping), `t-count`, `t-many` (large samples),
  `t-parents` (record the parents), `t-hawkweed` (the failed hawkweed experiments: hawkweed sets seed without
  fertilisation, so it never bred true to the rules), `t-peas`, `t-long-sum`, `t-crossed` ("Give it a year"), `t-returned`,
  `t-one-in-four` (once), `t-pale` ("didn't get the purple from either side"), `t-short`, and `g-holly` (holly needs a
  male and a female).

There is no claim that the two knew each other, and nothing in the game should imply it. That is open for future
writing.

## The three kinds of attention

- **Casual players:** a kind old woman, a nice lit glasshouse, free seeds and white lavender.
- **Curious players:** white flowers that vanish and come back, the odd specificity of some lines, and the scarecrow's
  coat.
- **Knowledgeable players:** 3:1, hawkweed, the spores paper, the sandy whiskers.

No clue inventory, no mystery meter, and nothing acknowledges that the player noticed.

## Reserved for later

- Her name and the reveal: when, how, and whether a player ever reads it in words.
- Her own ancient plants, and a cutting from one for a long-time visitor (from the design notes).
- Her history with the scientists, if any. She is never on their side.
- Pets carrying their plant's traits: a pet that arrives from a white-flowered plant could bloom white.
- Weather. The garden has no weather system yet. She covers season and hour of day; weather lines wait for it.
- More lines tied to the den, the woods' places, gifts, regrafts, and long absences.
