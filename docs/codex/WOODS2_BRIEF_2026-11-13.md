# Codex brief (2026-11-13, pass 2): the woods - the 3D skybox, clipping, the ravine, binoculars, the garden in view

Same rules as `docs/codex/WOODS_BRIEF_2026-11-13.md` (read it and your `REPORT_WOODS_2026-11-13.md`). No git. Work only
in `~/work/hp-woods`. Another Codex is replacing how rocks are made (`scripts/art/rock_factory.gd`, `garden_props.gd`
rocks) in `~/work/hp-rocks`: don't change rock shapes; keep rock placement code where it is.

**Keep tests lean (owner: "do not overtest, it burns credits; I'd rather debug").** Measure what you change, once.

## The owner's words, after your first pass was deployed

"Woods is better. The ravine and a couple of places need work, a lot of clipping on the trail. **We're drifting and
regressing when it comes to the 3D skybox, and that is a very important feature.** We should have a binoculars mode
where you can zoom in the woods from a fixed position - or better, at the ravine, a pair of binoculars to gaze down at
different things and details in the world below. I'd also like a representation of the garden to be visible somewhere
in the woods. Fix the pop-in, the trail clipping. Watch performance."

## Do, in this order

1. **The 3D skybox must be exactly right, and stay right.** The miniature (1:16 world in a SubViewport) must line up
   with the real world at every pose, every frame, while moving - no drift, no lag, no swimming, no seams where the
   near woods' real ground meets the miniature's. Write `tools/skybox_check.gd`: for random camera poses AND during a
   scripted turn/walk, project a set of landmark points that exist in the miniature (hill tops, the church, tree tops)
   through (a) the host camera at full scale and (b) the miniature camera + `shaders/distant_sky.gdshader`'s mapping
   (`view_inv`, `tan_half_w`, `aspect`, `OVERSCAN` in `miniature_sky.gd`); they must agree within ~1 px, and the sky
   picture must be from the SAME frame's pose (check the ordering: the camera moves in `_process`, `follow()` must run
   after it, the SubViewport must render after `follow()`; `UPDATE_ONCE` vs the host frame). Check host camera
   `keep_aspect` vs the sky camera's `KEEP_WIDTH` and the fov axis. Fix what it finds. Recent changes to suspect:
   redraw-on-change (pose `is_equal_approx`), the 10% OVERSCAN, static clouds, lower resolution per tier. If a
   simplification made it worse, revert that part and find a cheaper correct way.
2. **Trail clipping:** walk every trail (all edges of the trail graph) with the player's camera and collision shape
   and log every place the camera or the walker passes through trunks, rocks, logs, ground (extend
   `tools/woods_clip_check.gd`). Fix by clearing the trail corridor at generation time, lifting the camera over
   ground, or moving props off the trail - not by hiding things.
3. **Pop-in:** whatever still appears/disappears visibly while walking (LOD swaps, visibility ranges, cells, the distant
   land vs the near woods). Fades or margins.
4. **The ravine** (the owner's word: find the place in the woods where the land drops away and you look down on the
   world below - the creek valley / ridge / lookout; name it in the report): make it read as a real ravine - steep
   ledges (ask `RockFactory` for `ledge`/`outcrop` when it lands; until then keep the current calls), a view down that
   the skybox makes deep and far, no clipping at its rim.
5. **Binoculars at the ravine:** an object there (a pair of old binoculars on a post or a rail - a mounted viewer).
   Tap it: the camera moves to a fixed spot at the rim and narrows its field of view (eased, motion.gd rules); drag
   to look around within limits; pinch/scroll to zoom (fov ~8-40°); tap again or a ✕ to step back. The miniature
   must hold up under zoom (render it at a higher resolution only while looking through the binoculars). Place a
   handful of **details to find** in the world below that only show through the binoculars (a heron in the creek, a
   hawk circling, a fox den, a deer at the treeline, the church weathervane, someone's laundry, the garden - see 6);
   when one is centred for a moment, a caption names it (once each, saved as found; a small "seen through the
   binoculars" list in the journal). No timers or urgency.
6. **The garden, seen from the woods:** a miniature of the garden in the distant land (the lawn, the fence, the white
   house and next door's roofs, the big trees - cheap, low-poly, from the same colours), placed where it really is
   relative to the woods (the woods are reached over the footbridge: work out the direction), visible from the ravine
   and the binoculars. "Home" should be recognisable.
7. Performance: the woods trace before/after each step; the phone is the target (low tier).

Captures: your sandbox can't open an X server; Claude captures. Recompile the woods (`tools/compile_woods.gd`) and
re-bake (`tools/bake_cache.gd`) at the end.

## Report

`docs/codex/REPORT_WOODS2_2026-11-13.md`: what the skybox check found and fixed (numbers), clipping spots fixed, the
ravine and binoculars (how they work, the details placed and where), the garden miniature, performance, what Claude
should capture and look at (exact positions/poses).
