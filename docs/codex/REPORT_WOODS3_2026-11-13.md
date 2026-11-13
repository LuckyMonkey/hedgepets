# Woods 3 report — 2026-11-13

Implemented the seven items from `WOODS3_BRIEF_2026-11-13.md`. The rock factory files were not touched.

## 1. Ridge ravine

The ridge terrain now drops immediately after a defined rim, beginning about 2.5 m in front of the lookout and deepening over the next 20 m. The old near-ground hump is therefore cut away instead of easing into the drop too late. A narrow second opening faces back toward home, below the lookout, so the garden sightline has a real gap in the near trees.

Capture poses:

- Player camera: `woods._at = "ridge"`, heading `VIEW_DIR = (0.89, 0, -0.456)`, pitch `-6°`, FOV `70°`.
- Binoculars: enter at the ridge, heading `VIEW_DIR`, pitch `-10°`, FOV `24°`; pan left/back toward the home window and dwell on the house.

## 2. Ledge strata

The five ridge ledges are now wide, thin box slabs in a grey-brown material. They are placed at successive points down the new slope and follow the ground height, reading as layered strata rather than pale blobs or rust-coloured boulders. They remain a temporary pre-`RockFactory` implementation.

Capture pose: the ridge player pose above, plus binoculars at FOV `24°` aimed down the ledge run.

## 3. Arrival props

Vista clearing props are pushed farther sideways and back from their view cones. The trailhead board moved behind the arrival camera toward `HOME_DIR`; it is still available when turning back toward the garden. This removes the log/board-like interruptions from the first few metres of the ridge and trailhead views without hiding the props.

Capture poses:

- Trailhead arrival: `woods._at = "trailhead"`, default `enter()` pose, facing the fork.
- Trailhead reverse: same position, then `woods._goal_yaw += 2.4` radians.
- Ridge arrival: `woods._at = "ridge"`, default arrival orientation before turning to `VIEW_DIR`.

## 4. Old oak crown

The oak crown masses are explicitly assigned the shared near-distance fade, including both crown colours, and the crown masses are lifted by about 1.5 m. The arrival view should read out from beneath the canopy rather than as a dark ceiling filling the upper third.

Capture poses:

- `woods._at = "oak"`, heading `OAK_VIEW = (-0.148, 0, -0.989)`, pitch `-9°`.
- Oak alternate: same place, heading `OAK_VIEW.rotated(Vector3.UP, 0.7)`, pitch `-7°`.

## 5. Clouds

The static cloud field is reduced from 14 close fuzzy clusters to six distant groups. They are now high (115–165 sky units), farther out (260–520 units), smaller, and built from low-poly flat slabs with a shallow vertical profile, giving them flatter bottoms and less screen dominance.

Capture pose: ridge `VIEW_DIR` pose, plus a 30° left and right pan at the same pitch to verify that several small clouds sit high in the sky without a close white blob over the ravine.

## 6. Home miniature

`TOY_GARDEN` now lies beyond the footbridge on the garden side of the woods (`HOME_DIR * 38`), not on the distant mountain shelf. The existing lawn, white fence, white house, and blue door remain the miniature’s identifying features. The ridge has a narrow home-facing tree gap so the miniature can be found below the lookout, and the binocular garden detail was moved to the same sky coordinate.

Capture poses:

- Ridge home window: stand at `woods._at = "ridge"`; aim from the ridge toward the garden-side vector `TOY_GARDEN - NODES["ridge"]["at"]`, approximately `(-11.1, 0, 80.4)`, with pitch about `-3°`.
- Binocular home check: enter binoculars at the ridge, pan to that same vector, FOV `24°`, and dwell until the caption identifies home.
- Trailhead orientation check: stand at the trailhead and face `HOME_DIR = (0.287, 0, 0.958)` to confirm the sign/return direction agrees with the miniature.

## 7. Trail colour

The packed path ribbon was lightened from dark umber to leaf-litter browns: worn centre `#a08059`, loose edges `#6b5237`. The path should now separate from the blue-green forest floor and read as a walkable trail rather than a hole.

Capture poses: trailhead arrival, fork after walking from the trailhead, creek crossing facing along the path, and ridge arrival; compare the foreground ribbon in each.

## Build and checks

- Recompiled `world/woods_compiled.scn` with `tools/compile_woods.gd`.
- Re-ran the cache bake with `tools/bake_cache.gd`.
- `tools/woods_check.gd`: PASS, including compiled-world use, arrival, trail movement, prop clearance, and follower behavior.
- `tools/skybox_check.gd`: PASS, 94 poses, maximum host/miniature projection error `0.000 px`.

Fresh PNG capture could not be produced in this execution environment: no X11 display is available, and Godot’s dummy renderer returns no viewport texture. The poses above are the exact visual-review targets for Claude’s capture display.
