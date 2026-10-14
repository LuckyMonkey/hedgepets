# HedgePets Filmmaker

This directs the real game: the real garden built by `garden.gd`, the real pets and their own behaviours, the
real shaders, sun and soundscape. Nothing is recreated. The game's own camera (`garden.camera`) is the one that
moves, after the garden's camera code each frame. So everything that listens to it (the soundscape, the tilt-shift,
the porch man) behaves as it does in play. The game's buttons and toasts are hidden in the film; the game itself
is unchanged.

## Data

```
films/demo/
├── project.tres     FilmProject: title, fps, size, seed, hour, shots (external)
├── shot_001.tres    FilmShot: duration, keys, events
└── shot_002.tres
```

- **Keys:** `{t, eye: Vector3, look: Vector3, fov, track: "<pet name>"}`. With `track`, the camera looks at that pet.
- **Interpolation:** Catmull-Rom through every key, starting and ending at rest. The FOV eases between keys. The
  camera pose is a pure function of (shot, time) (`FilmShot.camera_at`).
- **Events:** `{t, kind, pet, arg}`. The kinds are `tap` (the pet's own hop + heart), `shake`, `sleep`, `wake` and
  `emote`. These are existing behaviours only.
- **Cuts:** a cut is a shot boundary.

Make the demo with `godot --headless --path . --script tools/film_make_demo.gd`.

## Preview (interactive)

`godot --path . res://filmmaker.tscn -- --film=res://films/demo/project.tres`

| Action | Input |
|---|---|
| Play / pause | Space |
| Step one frame | ← → |
| Back to the start | Home |
| Scrub | The bar |
| Add a key at the current camera, to the current shot | K |
| New shot | N |
| Free camera | C (the garden's own WASD / QE / RF, wheel, right-drag) |
| Save | Ctrl+S |

The camera follows the timeline exactly. The world runs live: scrubbing back does not rewind pets (see below).

## Render (offline, exact)

`tools/film_render.sh res://films/demo/project.tres OUT_DIR [540x960] [30]`

This uses Godot's **Movie Maker** (`--write-movie`):

- The engine steps at the project's fixed frame rate, whatever the machine's speed.
- The audio mix is recorded in lockstep to `frame.wav`, so audio sync is by construction rather than by capture.
- It runs silently on the speakers and offscreen (xvfb).
- `ffmpeg` then assembles `film.mp4` (H.264 + AAC).

Frame n is the world simulated from the start for n fixed steps, with the project's seed and hour. That's how a
render is reproducible without evaluating Godot's particles or animation at arbitrary times: same project, same
build → the same frames (the same approach as the golden views, which are proven pixel-identical across runs).
Live screen capture is not used.

## Status

- **Built:** project and shot resources, external shot files, the Catmull-Rom camera evaluator, pet tracking,
  events, the preview UI (play, step, scrub, keys, new shot, free camera, save), the Movie Maker render and the
  ffmpeg mux.
- **Verified:** see "Acceptance run" below.
- **Not tested by hand:** the interactive preview window.

## Limits and next steps

- Scrubbing the preview doesn't rewind the world. An exact preview of frame n would mean re-simulating from 0
  (what the render does), or snapshotting.
- Transform, visibility, environment and audio tracks aren't built. Only camera and pet events exist.
- Separate audio stems are a later feature; for now there's a stereo mix.
- Places: each shot has a `place`, either `garden` or `woods:<place>` (`woods:ridge`, `woods:pines`, ...). In the woods, the keys are offsets from standing there, and the 1:16 land beyond follows the film camera every frame. The demo's third shot is the ridge, with the toy garden on the mountain.

## Acceptance run (2026-10-14, llvmpipe under xvfb, 540×960 at 30 fps)

The demo film (`films/demo`) opens on the garden and dollies down to Gerald, tracking him. At 2.6 s he hops (his own
`tap`). Then it cuts to a low side camera that arcs while he shows a 💚.

| Check | Result |
|---|---|
| Render | 211 frames (0 to 7.0 s inclusive), `frame.wav` at 48 kHz stereo, `film.mp4` H.264 + AAC, 7.03 s |
| Two renders, same project | **211/211 frames pixel-identical** (`tools/image_compare.py`) |
| Audio, first build | **Not reproducible:** the soundscape seeded its event RNG with `randomize()`, and the wind swell followed the wall clock |
| Audio fix | `HEDGEPETS_SOUND_SEED` (set by the filmmaker): seeded events and the swell on game time. The game itself keeps `randomize()` and the wall clock, so play is unchanged |
| Render speed | About 0.25 frames/s under software GL; a GPU display would be far faster |

Other `randomize()` calls that a film may need to pin later: `woods.gd:1543`, `garden_game.gd:372` and `:1374`, and
`pet_life.gd:33` (the viewer). They didn't affect the demo's frames.
