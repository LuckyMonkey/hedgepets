# Codex brief (2026-11-13, pass 3): the woods - what Claude saw in captures

Same rules as the earlier woods briefs (no git; `--audio-driver Dummy`; work only in `~/work/hp-woods`; another Codex
owns rock SHAPES in `~/work/hp-rocks` - don't touch `rock_factory.gd`/`garden_props.gd` rocks). **Lean tests: one
quick run of what you change.** Pass 2 is live; the owner is testing on an iPhone.

Captures (software GL, clear weather) are attached: `docs/codex/shots/all.png` (creek, fork, oak, pine flats, ridge,
trailhead) and `docs/codex/shots/oak_ridge.png` (full size). Fix, in order:

1. **The ridge doesn't read as a ravine.** From the lookout, a hump of the near ground (5-15 m out along `VIEW_DIR`)
   hides the drop: you see dirt, then far treetops. Shape the land so that from the bench/lookout the ground falls
   away in front of you within a few metres (a rim), and the valley floor is visibly far below; the stepped ledges go
   down that drop (on the slope, not standing on top of the hump). Check with the player's camera at the ridge and
   through the binoculars.
2. **The ledges read as blobs** (pale ovals, rust-coloured lumps). Until `RockFactory` lands, make them flat layered
   slabs: wide, thin, horizontal, grey-brown, stacked in steps down the slope - strata, not boulders. (When the rock
   factory merges, they'll switch to its `ledge` role.)
3. **Props in the camera's face at arrival:** the ridge's arrival view has a log cutting into the right side of the
   frame (it dithers through the near fade). Keep a clear cone in front of every place's arrival camera (several
   metres) - move props, don't hide them. Same for the trailhead (a dark shape cuts the right foreground).
4. **The old oak:** the camera stands under a crown whose dark mass fills the top third of the frame. Give the crown
   masses (not just the leaf cards) the near fade (`shaders/near_fade.gdshaderinc`, as the leaf shader does), or
   lift/move the crown so the arrival view looks out from under it.
5. **Clouds:** since pass 1 they're static, and in the sky they read as fuzzy white blobs, one big and close over the
   ridge. Make them read as distant, flat-bottomed, low-poly clouds high up and far away (smaller on screen, a few,
   not in your face), or drop them.
6. **The garden from the woods:** `TOY_GARDEN` sits on a mountain shelf ~3 km away - that's not where home is. Put the
   miniature home where the garden really lies relative to the woods (you walk back over the footbridge to it: work
   out the direction from the trailhead/"Home to the garden" sign) and make it visible from the ridge (through a gap
   in the trees, below and not far), recognisable: the lawn, the white fence, the white house with the blue door.
7. The trail itself: the trail ground is very dark brown in the foreground of every view - lighten it toward the
   art direction's leaf-litter browns so it reads as a path, not a hole.

Recompile the woods and re-bake at the end. Report: `docs/codex/REPORT_WOODS3_2026-11-13.md` - each item, what you
changed, and the exact poses Claude should capture to check it.
