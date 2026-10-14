# HedgePets: handoff for the next agent

Read this first, then the doc for whatever you're touching. The owner calls themselves luckymonkey. Last updated
2026-10-10.

## What it is

A Godot 4.7 garden game. Creatures made of plants ("hedgepets", modelled on New England animals) come to an
ordinary backyard at the edge of the woods if you grow and build what they like.

- **Live:** go.fridge.run/hedgepets (WebAssembly). Members, or guests after a captcha (`/play`).
- **Repo:** `~/Projects/hedgepets`, private GitHub `LuckyMonkey/hedgepets`, branch `main`.
- **Godot:** `~/.local/bin/godot` (4.7.2). The main scene is `garden.tscn`; `main3d.tscn` is the pet viewer.

## Design rules the owner set (don't break these)

- **A place, not a treadmill.** No timers, urgency, streaks, daily rewards, grinding, punishment for absence or
  reflex tests. Watching is valid play. Nothing decays while you're away.
- **They aren't Pokémon.** You don't catch them all. A garden holds 2 to 6 hedgepets (`capacity()`), drawn by the
  plants you grow (`grows_for`). Every garden ends up different.
- **Looks:**
  - A hedgepet is all plant except its feet and tail.
  - Eyes have no whites, just a crisp light dot.
  - The style is autumn, "magical creatures in an ordinary backyard", and never spooky.
  - The woods are a daytime place: dark blue-green shade with sunbeams.
- **Motion:** every visible change eases through `scripts/anim/motion.gd`. Never jump a visible property.
  `tools/motion_check.gd` must pass.
- **Roster:** closed at 47 pets. Polish before adding animals. Names must not echo any franchise character.
- **Lore secrets:** the nursery lady and the porch man are never named in game text, code or comments.
  `docs/private/LORE.md` holds who they are; `docs/*` is never exported. `tools/nursery_check.gd` fails if a name
  appears.
- **Ship often:** commit, push and deploy each verified piece (the owner hits usage limits).

## Where things are

| Area | Files | Doc |
|---|---|---|
| Garden loop, tools, wishes, capacity, digging/dirt, pouring/following, bucket carry | `scripts/garden/garden_game.gd` | `docs/GARDEN.md` |
| World build, camera, input, pets' wandering, gates | `scripts/garden/garden.gd` | `docs/GARDEN.md`, `docs/BACKYARD.md` |
| Yard work: yank, haul, bin, mend, wheelbarrow | `scripts/garden/garden_grab.gd` | `docs/GARDEN.md` |
| Hideouts (bucket, pot, well, burrow) | `scripts/garden/hideouts.gd` | |
| Woods (trails, places, finds, sunbeams, wild hedgepets, chevrons) | `scripts/garden/woods.gd` | `docs/NURSERY.md` |
| Nursery + her lines | `scripts/garden/nursery.gd`, `assets/talk/nursery.json` | `docs/NURSERY.md`, `docs/private/LORE.md` |
| Plant inheritance (flower colour, height) | `scripts/garden/heredity.gd` | `docs/NURSERY.md` |
| Porch man | `scripts/garden/porch_watcher.gd` | `docs/private/LORE.md` |
| The land beyond the woods (1:16 3D skybox) | `scripts/garden/distant_land.gd`, `shaders/distant_sky.gdshader` | `docs/NURSERY.md` |
| Woods trees (oak, maple, birch, pine; batched per patch; clear of the walk) | `scripts/garden/woods_trees.gd` | `docs/NURSERY.md` |
| Fire pit / campfire | `scripts/garden/fire_pit.gd` | |
| Places away (burrow, woods): staged build behind a loading card | `scripts/garden/elsewhere.gd`, `den.gd`, `loading_card.gd` | |
| Pets: profiles, data species, art | `scripts/art/*`, `pets/*.tres`, `pets/species.json` | `docs/ART_DIRECTION.md` |
| Telemetry (web only) | `scripts/telemetry.gd` (`Telemetry.event(name, data)`) | below |
| Bake cache (startup speed) | `tools/bake_cache.gd` → `assets/baked/garden.res` | `docs/MOBILE.md` |
| Web page around the game | `deploy/web/shell.html` | `docs/MOBILE.md` |

## World editor, filmmaker, regression and benchmarks (2026-10-14 runbook)

- **The rule:** these tools must never change how the game looks, sounds or plays. The golden views prove it.
- **Architecture:** `docs/WORLD_ARCHITECTURE.md` (what's generated, the stable IDs, why overrides are post-build).
- **World editor:** `godot --path . res://world_editor.tscn`.
  - Overrides are stored in `res://world/garden_overrides.tres` (`WorldOverrides`, applied before the player's
    save).
  - The check is `tools/world_editor_check.gd`. Doc: `docs/WORLD_EDITOR.md`.
- **Filmmaker:** `res://filmmaker.tscn -- --film=res://films/demo/project.tres` (preview).
  - Render with `tools/film_render.sh <film> <out>` (Movie Maker, reproducible frames and audio).
  - Doc: `docs/FILMMAKER.md`.
- **Golden regression:** `tools/golden_capture.gd` + `tools/image_compare.py` against `tests/baseline/f72b9bd`.
  Never update the baseline silently. Doc: `docs/VISUAL_REGRESSION.md`.
- **Benchmarks:** `tools/bench_world.sh` (procedural / cached; `--gpu` for frame times).
  Docs: `docs/PERFORMANCE_BASELINE.md`, `docs/MAP_COMPILATION_BENCHMARK.md`.
- **Offscreen Godot runs always take `--audio-driver Dummy`**, or the soundscape plays through the owner's speakers.

## The pet viewer and debugger

- **Desktop:** `godot --path . res://main3d.tscn`.
- **Web:** `go.fridge.run/hedgepets/?viewer`, linked as "🔍 Pet viewer" on the page beside the game.
- **Controls:** ‹ › or arrow keys change pet, and 🍃 or F regrows it in the next plant (every leaf style). 🛠 Debug
  or F1 opens the developer view (`art_debug.gd`) with parts, regions, leaves and sliders. On the web, 🏡 Garden goes
  back.
- **Side-by-side tuning** (desktop): `godot --path . res://dev/swatches.tscn`.

## The contraband (cannabis, pet 48's look)

Your notes asked for "the weed HedgePet". It isn't a new animal; it's a slow, rare change to a resident (usually
Clover): "leaves look different", then "smells really strong", then the journal identifies it as cannabis
(`garden_game._tend_contraband`).

- **Its leaves:** the glyph font `HedgeCannabis` (`tools/generate_hedgeink.py`: fans of saw-edged leaflets, a frosty
  bud) and the sheet `assets/sprites/hedgecannabis.png`, made with
  `python3 tools/bake_leaf_sprites.py hedgecannabis` and `make_normal_maps.py`. The plant is `cannabis` in
  `SpeciesBuilder.PLANTS`, on the `hemp` palette. It's never sold.
- **Odds:** about 1.2% per minute of play while there's a likely resident; the stages are 10 real minutes apart.
  `HEDGEPETS_CONTRABAND=1` forces it, and so does `game._tend_contraband("Clover")`.
- **Behaviour:** it wants the sun by the street gate, in view of the porch, where the porch man photographs it
  furiously. No meter and no penalty. Lure it back with water, or regraft it (✂️) and it settles (stage 4).

## Running and checking

All checks run headless. Run them before every commit that touches what they cover:

```
HEDGEPETS_FRESH=1 godot --headless --path . --script tools/<check>.gd --fixed-fps 60
```

The checks are `game_check`, `woods_check`, `den_check`, `life_check`, `grab_check`, `hide_check`, `motion_check`,
`collision_check`, `nursery_check` and `yard_check`. `collision_check` is borderline flaky: its baseline is 110 to 130
of an allowed 180.

To look at something, run `DISPLAY=:0 godot --path . --script tools/capture_<x>.gd --disable-vsync`. It writes to
`/tmp/hedgepets-views`. The captures are `capture_places` (woods), `capture_yard`, `capture_survey`,
`capture_garden` and `capture_roster`. Judge by the captures, never by "it runs".

Traps:

- After adding a `class_name`, run `godot --headless --path . --import` once, or scripts fail to parse.
- Godot core-dumps ("double free") on quit after captures. It's harmless.
- `HEDGEPETS_FRESH=1` keeps checks off the player's save. `Motion.speed = 0` makes transitions instant.
- Never use `Image.load_from_file` on `res://` (exports ship no raw PNG). Use `Assets.image()`.
- Changed foliage, anatomy or scenery? The deploy rebakes the cache. Anything built with random seeds won't cache:
  use fixed seeds (`garden._bush(..., fixed_seed)`).
- Checks that enter the woods call `woods.build_now()` first (the real path builds in steps behind a loading card).

## Deploying

`tools/deploy_web.sh` bakes the cache, exports the Web preset to `build/web`, rsyncs to
`fridge:/srv/apps/hedgepets/web`, and restarts the `hedgepets` nginx container. It needs `ssh fridge@fridge`. The
first load is about 50 MB.

## The pages around the game (in the go app, not this repo)

These live in `~/Projects/fridge-go`, a PHP app on fridge.

| Route | File | What |
|---|---|---|
| `/play` | `src/play.php` | Captcha that gives guests a 30-day pass (cookie path `/hedgepets`) |
| `/hedgepets/feedback` (+ `/results`, `/results.json` for the owner) | `src/hedgepets_feedback.php` | Survey with screenshots (`public/assets/hedgepets-feedback/`) |
| `/hedgepets/howto` | `src/hedgepets_howto.php` | How to play |
| `POST /hedgepets/telemetry`, `/hedgepets/telemetry/report` (owner) | `src/hedgepets_telemetry.php` | Play events and the "where are they stuck" report |

- **Tests:** `ops/tests/ply.php`, `hpf.php` and `hpt.php`, run through `ops/tests/test-all.sh`.
- **Deploy go:** `git push origin main`, then on fridge `sudo -A git -c safe.directory=/srv/apps/go pull --ff-only`
  in `/srv/apps/go`. Fetch first. The live nightly job pushes snapshots.
- **Caddy** (`/home/fridge/fridge-homepage/Caddyfile`, root-owned):
  - `@hp_feedback` routes feedback, howto and telemetry to go. It must stay above `@hedgepets` (the game's static
    files, gated by `forward_auth realm=play`).
  - To edit: write with `sudo -A tee` (keeps the inode for the bind mount), run `caddy validate`, then
    `caddy reload`.

**Telemetry:**

- **Events:** `session`, `tool`, `dig`, `fill`, `unplant`, `sow`, `grew`, `pour`, `follow`, `bucket_in`,
  `bucket_carry`, `build`, `clear`, `yank`, `bin`, `mend`, `fire`, `journal`, `den`, `woods`, `trail`, `find`,
  `wild_tap`, `nursery`, `talk`, `noticed`, `visiting`, `resident`, `left`, `open_howto`, `open_feedback`, `hidden`,
  `beat` (every 60 s), and `say` (every toast: refusals show where people get stuck).
- **Adding an event:** call `Telemetry.event("name", {...})`. Names must match `[a-z_]{1,24}`. Keep data small.
- **The report's funnel** is `HPT_FUNNEL` in the PHP.

## Open items and ideas the owner has raised

- **The scientists** (`hedgepets, part.md`) aren't built. The nursery lady is never on their side. The porch man is
  "hiding something", reserved.
- **Pets carrying their plant's inheritance** (a white-flowered plant's pet blooms white) is reserved.
- **Weather** doesn't exist. Her weather lines wait for it.
- **Android/iOS export:** templates, JDK and SDK aren't installed (`docs/MOBILE.md`).
- **Not tested by hand:** touch on real phones (pouring, trail choosing), the porch man's timing, the wild hedgepets'
  feel, and whether telemetry arrives from real browsers (check the report after a real session).
