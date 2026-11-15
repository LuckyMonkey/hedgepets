# HedgePets — operations: run, check, deploy

How the machinery works. Rules live in [../AGENTS.md](../AGENTS.md); review procedure in [CODE_REVIEW.md](CODE_REVIEW.md).
Deploy only when the owner asks (AGENTS.md); this file says *how*.

- **Repo:** GitHub `LuckyMonkey/hedgepets` (**public**), branch `main`. Owner's working copy: `~/work/hedgepets`.
- **Godot:** `~/.local/bin/godot` (4.7.2). Main scene `garden.tscn`; pet viewer `main3d.tscn`.
- **Live:** go.fridge.run/hedgepets (WebAssembly). Members, or guests after a captcha (`/play`).

## Running

- Editor dock (`addons/hedgepets_dev`): play from any place, clickable woods map, world editor, filmmaker, checks. Doc: [DEV_ENVIRONMENT.md](DEV_ENVIRONMENT.md).
- Start anywhere: `godot --path . -- --start=woods:<place>`.
- Debug coins: 🪙+ / F9 in the editor, `?debug` on the web, `-- --debug` in a terminal. Sound settings: 🔊, saved in `user://settings.cfg`.
- **Pet viewer:** `godot --path . res://main3d.tscn`, or `go.fridge.run/hedgepets/?viewer`. ‹ › change pet, 🍃/F regrows it in the next plant, 🛠/F1 opens the developer view (`art_debug.gd`). Side-by-side tuning: `res://dev/swatches.tscn`.
- **World editor:** `godot --path . res://world_editor.tscn` (garden) or `-- --woods=<place>`. Overrides: `world/garden_overrides.tres`, `world/woods_overrides.tres`. Docs: [WORLD_EDITOR.md](WORLD_EDITOR.md), [WORLD_ARCHITECTURE.md](WORLD_ARCHITECTURE.md).
- **Filmmaker:** `res://filmmaker.tscn -- --film=res://films/demo/project.tres`; render with `tools/film_render.sh <film> <out>`. Doc: [FILMMAKER.md](FILMMAKER.md).
- The editor, filmmaker and benchmarks must never change how the game looks, sounds or plays.

## Checking

```
HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/<check>.gd --fixed-fps 60
```

- **Always** `--audio-driver Dummy` offscreen, or the soundscape plays through the owner's speakers. `HEDGEPETS_FRESH=1` keeps checks off the player's save.
- Checks: `tools/*_check.gd`. The usual ones: `game_check` (core loop), `woods_check`, `motion_check`, `nursery_check` (fails if a lore name appears), `skybox_check`, `story_check`, `collect_check`, `world_editor_check`, `descriptions_check`.
- **Flaky:** `life_check` (random pet life; fails at different points even seeded). `collision_check` is borderline: baseline 110–130 of an allowed 180.
- The owner's rule: one relevant check per change, not the whole suite.
- **Looking at things:** `DISPLAY=:0 godot --path . --script tools/capture_<x>.gd --disable-vsync` → `/tmp/hedgepets-views`. Captures: `capture_places` (woods), `capture_yard`, `capture_survey`, `capture_garden`, `capture_roster`. Judge by captures, never by "it runs".
- **Golden regression:** `tools/golden_capture.gd` + `tools/image_compare.py`; see [VISUAL_REGRESSION.md](VISUAL_REGRESSION.md). Never refresh a baseline silently. (On the owner's laptop numpy isn't installed, so `image_compare.py` fails; PIL works.)
- **Hitches / benchmarks:** `tools/hitch_trace.gd`, `tools/bench_world.sh` (`--gpu` for frame times). Docs: [PERFORMANCE_BASELINE.md](PERFORMANCE_BASELINE.md), [MAP_COMPILATION_BENCHMARK.md](MAP_COMPILATION_BENCHMARK.md).
- **No X for agents:** the laptop has no system Xvfb and no sudo; a private copy lives in `~/work/xvfb-local/root` (PATH + LD_LIBRARY_PATH; `deploy_web.sh` sets it up). Codex's sandbox can't open X: Claude renders captures on a private Xvfb (`:77`) and hands Codex the PNGs (`codex exec -i a.png -i b.png -- "prompt"`).

## Traps

- After adding a `class_name`, run `godot --headless --path . --import` once, or scripts fail to parse.
- Godot front faces wind **clockwise** (generated meshes).
- Godot 4 shaders have `MODEL_MATRIX`, not `WORLD_MATRIX`. A failed shader silently falls back — grep deploy output for `SHADER ERROR`.
- Never `Image.load_from_file` on `res://` (exports ship no raw PNG). Use `Assets.image()`.
- Changing pet/foliage/anatomy/scenery code invalidates `assets/baked/garden.res` (re-bake: `tools/bake_cache.gd`; the deploy does it). Anything built with random seeds won't cache: use fixed seeds (`garden._bush(..., fixed_seed)`).
- Changing `woods.gd` invalidates `world/woods_compiled.scn` (the deploy recompiles it; needs Xvfb).
- Checks that enter the woods call `woods.build_now()` first (the real path builds in steps behind a loading card).
- Godot core-dumps ("double free") on quit after captures. Harmless. Leaked-RID errors at exit in headless checks are harmless too.
- `Motion.speed = 0` makes transitions instant.
- Opening the editor rewrites `project.godot` and some `.import` files (comment header, key order, default values). That's noise: don't commit it with an unrelated change.

## Deploying

`tools/deploy_web.sh`:
1. compiles the woods (`world/woods_compiled.scn`, under Xvfb), bakes shadows and the startup cache;
2. exports the Web preset to `build/web` (first load ≈ 50 MB);
3. rsyncs to `fridge:/srv/apps/hedgepets/web` and restarts the `hedgepets` nginx container (needs `ssh fridge@fridge`);
4. pings the owner's phone (ntfy via go's `scripts/notify-owner.php`). `DEPLOY_NOTE="..."` sets the text; default is the last commit subject.

**Bump `VERSION` in `scripts/telemetry.gd` on every deploy** — it tags telemetry and the phone link (`?v=`).

## The pages around the game (fridge-go, not this repo)

| Route | File (fridge-go) | What |
|---|---|---|
| `/play` | `src/play.php` | Captcha; guests get a 30-day pass (cookie path `/hedgepets`) |
| `/hedgepets/feedback` (+ `/results`, `/results.json`, owner) | `src/hedgepets_feedback.php` | Survey with screenshots |
| `/hedgepets/howto` | `src/hedgepets_howto.php` | How to play — update when a loop is final |
| `POST /hedgepets/telemetry`, `/hedgepets/telemetry/report` (owner) | `src/hedgepets_telemetry.php` | Play events, "where are they stuck", frame times |

- Tests: `ops/tests/{ply,hpf,hpt}.php` via `ops/tests/test-all.sh`.
- Deploy go: push `main`, then on fridge in `/srv/apps/go`: fetch, `sudo -A git -c safe.directory=/srv/apps/go pull --ff-only`.
- **Caddy** (`/home/fridge/fridge-homepage/Caddyfile`, root-owned): `@hp_feedback` (feedback, howto, telemetry → go) **must stay above** `@hedgepets` (static game files behind `forward_auth realm=play`). Edit with `sudo -A tee` (keeps the inode for the bind mount), `caddy validate`, then `caddy reload`.

## Telemetry

- Web only: `Telemetry.event("name", {...})` in `scripts/telemetry.gd`. Names match `[a-z_]{1,24}`; keep data small.
- Events include `session`, `tool`, `dig`, `sow`, `grew`, `pour`, `build`, `clear`, `woods`, `trail`, `find`, `nursery`, `resident`, `left`, `beat` (every 60 s), `say` (every toast — refusals show where people get stuck), plus frame-time samples.
- The report's funnel is `HPT_FUNNEL` in the PHP.

## The contraband

Not a new animal: a slow, rare change to a resident (usually Clover) — "leaves look different", "smells really strong", then the journal names it (`garden_game._tend_contraband`). Leaves: glyph font `HedgeCannabis` (`tools/generate_hedgeink.py`), sheet `assets/sprites/hedgecannabis.png` (`tools/bake_leaf_sprites.py hedgecannabis` + `make_normal_maps.py`); plant `cannabis` on the `hemp` palette, never sold. ~1.2%/min while a likely resident exists, stages 10 real minutes apart; `HEDGEPETS_CONTRABAND=1` forces it. It wants the sun by the street gate in view of the porch. No meter, no penalty; water lures it back, regrafting (✂️) settles it.

## Ideas the owner has raised (not built)

- The scientists ([ideas/scientists.md](ideas/scientists.md)). The nursery lady is never on their side; the porch man is "hiding something", reserved.
- Pets carrying their plant's inheritance (white-flowered plant → pet blooms white).
- Android/iOS export: templates, JDK, SDK not installed ([MOBILE.md](MOBILE.md)).
- Never tested by hand: touch on real phones (pouring, trail choosing), the porch man's timing, wild hedgepets' feel.
