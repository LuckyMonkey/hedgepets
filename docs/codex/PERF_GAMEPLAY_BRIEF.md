# Codex brief (2026-11-12): pan stutter, the neighbourhood's look, then garden stats and introductions

Read `AGENTS.md`, `docs/HANDOFF.md` (the owner's design rules are non-negotiable), `docs/PERFORMANCE_BASELINE.md`,
`docs/GARDEN.md`. You cannot run git: Claude reviews, commits, pushes and deploys. Offscreen Godot runs ALWAYS take
`--audio-driver Dummy` (the laptop's speakers must stay silent). Godot: `~/.local/bin/godot` (4.7.2). This laptop is a
2012 MacBook Air (Intel HD 4000): the game must hold ~30 fps on it; it is the right machine to feel the stutter.

**Do not change the hedgepets themselves** (their meshes, art, materials, animation) unless you prove one is the root
cause of a rendering problem; if so, stop and write it up in the report instead of changing it.

## Part A - the stutter when panning the garden camera (owner: "runs fine then it doesn't, very choppy")

Hypotheses found by reading the code (verify each by measurement before and after; keep what helps):

1. **The garden sky re-renders its radiance cubemap on every moving frame.** `scripts/garden/miniature_sky.gd`
   `follow()` sets the sky ShaderMaterial's `view_inv` / `tan_half_w` / `aspect` every frame the camera moves;
   `shaders/distant_sky.gdshader` has no `AT_CUBEMAP_PASS` guard, so Godot redraws the sky into its radiance cubemap
   (and filters it) whenever those change - although the garden's environment uses neither sky ambient nor sky
   reflections (`garden.gd` ~317-331). Likely fix: in the sky shader `if (AT_CUBEMAP_PASS) { COLOR = fallback; return; }`
   (or the cheapest equivalent), and set uniforms only when they actually changed. Same for the woods
   (`woods.gd` ~668 uses the same machinery).
2. **First-draw shader/pipeline compiles** when the pan brings materials into view for the first time (the web's slow
   part - `docs/PERFORMANCE_BASELINE.md` 2026-10-24 "Under the veil"). Likely fix: warm every garden material behind
   the loading card (e.g. draw a few frames with the camera turned through the views a player can reach, or render
   each material once offscreen) before the garden appears.
3. **The miniature world is redrawn every frame even when nothing moves** (`SubViewport.UPDATE_ALWAYS` in
   `show_land`). Render it only when the camera's pose (or fov / size) changed, or something in it animates (clouds
   drift: throttle those to e.g. every few frames or only when visible change exceeds a pixel). This makes the
   steady state cheaper on weak GPUs.
4. Anything else your measurements show during a pan (per-frame allocations in `_process`, LOD swaps, tilt-shift
   cost, the sun glide, `_walk_colliders`…).

**Measure:** write `tools/pan_trace.gd` (or extend `tools/hitch_trace.gd` with `TRACE_MODE=pan`): the garden with 6
residents, the camera driven exactly as the player drives it (the same functions input uses), a slow 360° pan, a fast
pan and back-and-forth, twice each (the first pass shows compile hitches, the second the steady state). Report frame
times (median, p95, max, frames > 33 ms) windowed on this laptop with the GPU (Compatibility renderer, as the web
build uses: `--rendering-method gl_compatibility`), and headless for CPU-only. Before and after every change. Put
the numbers in a new dated section of `docs/PERFORMANCE_BASELINE.md`.

## Part B - the neighbourhood's look

- **The land under the neighbours' houses is a flat green square with no texture** (`scripts/garden/neighborhood.gd`
  ~207: the ground is vertex colours only). Give it a cheap texture in keeping with the garden's lawn and the art
  direction (`docs/ART_DIRECTION.md`): e.g. a small tiling noise/grass detail or the lawn shader's look, mown-yard
  stripes, darker verges, driveways - read as distance under the fog and tilt-shift. Keep it one mesh per material.
- **Seams in the skybox:** where the miniature's picture meets the real garden (behind the back fence, the edges of
  the picture while panning - the shader falls back to a flat colour outside the picture's frame), and anywhere the
  miniature ground and the real lawn don't meet cleanly. Find them in captures; fix them (e.g. render the miniature
  with a little overscan and map the shader to it; blend the real lawn's far edge into the miniature's ground colour).
- **Optimise / consolidate:** merge static meshes that share a material, weld duplicate vertices, drop hidden faces,
  in the neighbourhood and the distant land. Report the primitive and draw-call counts before/after
  (`tools/bench_world.sh`, the existing counters).
- Keep the golden views (`docs/VISUAL_REGRESSION.md`): the garden views may change only where you intended (the
  neighbours' ground, the seams); list every changed view with a reason. Never update the baseline silently - write
  the new captures to a separate folder for Claude and the owner to look at.

## Part C - gameplay: what the garden is, and how hedgepets come (after A and B)

Today: notice → visit → resident by each pet's `wants` (`CharacterArtProfile.wants`, `pets/species.json`), capacity
2-6 by variety (`capacity()`), `grows_for`, the journal (📖) with hints and "around the neighbourhood". What's missing:
the player can't see the garden's qualities as a whole, can't see cause and effect, and a first arrival has no
introduction. Build (respecting every design rule - no timers, urgency, streaks, punishment, decay while away;
"watching is valid play"; every visible change eases through `scripts/anim/motion.gd`; `tools/motion_check.gd` passes):

1. **The garden's qualities, in the journal** (a "Your garden" page): what it offers, grouped - plants (kinds grown,
   flowering), food (feeders, apples, pumpkins), water (bath, wet soil, the sprinkler), shelter (log piles, hideouts,
   nest box), comforts (fire pit, lantern, chair…), and **room** (capacity n / 6 and exactly what raises it). Each
   offer lists the hedgepets it draws (met ones by name, unmet ones as their animal: "something that likes leaf
   piles" - keep some mystery). Derived from the same data the game already uses - never a second rule set.
2. **Cause and effect, gently:** when you plant or build something that moves a hedgepet closer (a notice/visit/
   resident wish newly met), a short caption line (the existing caption over the bar, eased) - "A fox would like a
   leaf pile like that." No pop-ups, no counters ticking.
3. **An introduction** the first time each hedgepet arrives in your garden: the camera eases toward it (never jumps;
   the player can take control back at any moment), and a small card names it - its name, its animal, the plant it's
   made of, what drew it in, and what would make it stay (its next stage's wishes, in words). It goes in the journal
   ("met in your garden"). Once per hedgepet per garden; saved like the rest of the game state.
4. Update `docs/GARDEN.md` and the in-game How to play text source if it lives in this repo (the go page
   `/hedgepets/howto` is in fridge-go, not here - list the changes it needs in the report and Claude will make them).

Checks: run every relevant `tools/*_check.gd` (yard, life, motion, nursery, hide, save_profile…) and the golden capture;
add a check for the introduction and the garden page (state is saved and restored; once per pet; no timers).

## Report

Write `docs/codex/REPORT_2026-11-12.md`: what you measured (before/after numbers), each cause found, each change,
files changed, checks run with results, golden views changed and why, anything you tried and dropped, and open
questions for the owner. Do not claim a fix you did not measure.
