# HedgePets art direction (3D)

**Gerald is a bush that happens to look like a beaver** - a storybook creature made of living plants, not a realistic
animal covered in leaves. The silhouette establishes the animal, the foliage the material, the face the personality;
the renderer builds the three separately so none can destroy the others. Acceptance is visual (see *Acceptance*).

## Architecture

| File | Role |
|---|---|
| `scripts/art/character_art_profile.gd` | `CharacterArtProfile` resource: every art number, as data. `gerald()` holds Gerald's defaults. |
| `pets/gerald.tres` | Gerald's profile (re-save with `godot --headless --path . --script tools/save_profile.gd`). Future pets = new profiles. |
| `scripts/art/hedge_anatomy.gd` | Region geometry (ellipsoid surface points and normals), head-local facial anchors, smooth face protection. |
| `scripts/art/foliage_builder.gd` | Seeded hierarchical foliage: region -> clusters -> leaves -> flowers. |
| `scripts/hedge_pet_3d.gd` | Assembles the pet from the profile: world, regions, face, foliage, life, detail levels, view presets. |
| `shaders/leaf.gdshader` | Leaf sprite + normal map; matte watercolour pigment; silhouette ink vs. faint interior ink; GPU wind; detail-level culling. |
| `shaders/paper_ground.gdshader` | The ground *is* the paper: shows the paper colour, softly darkened only by shadow. |
| `shaders/ink_hull.gdshader` | Inverted-hull ink outline for tail, feet, ears, muzzle, eyes, nose, teeth. |
| `scripts/art/art_debug.gd` | Developer inspection view (F1). |

Hierarchy: **BUSH -> CLUSTERS -> LEAVES**. Clusters are spread evenly (jittered Fibonacci sphere), kept apart
(`cluster_min_gap`, the negative space), coloured as one pigment family, then filled with a big crown leaf and smaller
leaves around it. The inner leafy mass shows in the gaps on purpose.

## Primitives (`scripts/art/hedge_anatomy.gd`)

Every region is a **blob**: a superellipsoid `|x/a|^n + |y/(b*s)|^n + |z/(c*s)|^n = 1` with `s = 1 + taper * x/a`.
`exponent` n (2 ellipsoid, 2.5-4 cushion/slab), `taper` (+ grows toward the front, - toward the back),
`flat_bottom` (cut at -flat*b so it sits on the ground). Surface points by bisection along a direction, normals from
the gradient, meshes from `HedgeAnatomy.build_mesh()`; foliage, anchors and the debug view all use the true shape.
A region's `shape` is a dictionary of numbers or a preset name:

![primitives](acceptance/primitives.png)

| Preset | Numbers | Use |
|---|---|---|
| ellipsoid | - | plain |
| bean | n 2.15, taper -0.14, flat 0.88 | Gerald's body: fuller behind, sits flat |
| pear | n 2.0, taper -0.35, flat 0.9 | a sitting body |
| egg | n 2.0, taper 0.2 | heads |
| cushion | n 2.8 | muzzles, snouts |
| paddle | n 4.0 (flat radii) | beaver tails, fins, leaves |
| dome | n 2.6, flat 0.12 | feet, caps |
| teardrop | n 2.0, taper 0.75 | ears, buds |
| pebble | n 2.3, taper -0.1, flat 0.5 | stones, toes, seeds |

Gerald: BODY bean (1.34 x 0.95 x 1.04), HEAD a big round head (0.84 x 0.78 x 0.80, baby proportions, close to the
body), MUZZLE cushion, TAIL paddle (exponent 4), EARS small cups, FEET flat domes (terracotta).

## Pets

Every pet is a `CharacterArtProfile` (`CharacterArtProfile.<name>()`, saved to `pets/<name>.tres` by
`tools/save_profile.gd`) on the same renderer (`scripts/hedge_pet_3d.gd`). Per pet: `leaf_sheet` (the plant),
`palette`, `features` (teeth, mouth style beaver/bunny/smile, cheeks, nose size), `frame_target`/`frame_distance`, and
regions with optional `shape`, `rotation`, `mirror`, `flowers` (a region made of blossom), `outline`, `color`.

![pets](acceptance/pets.png)

| Pet | Species | Plant | Built from |
|---|---|---|---|
| Gerald | beaver | ivy | bean body, big round head, cushion muzzle, paddle tail, cup ears, dome feet, teeth |
| Clover | bunny (sitting) | clover | pear body tapered along y, egg head, tall leafy ears (mirrored, rotated), a cotton tail of blossom, teeth |
| Juniper | hedgehog | fern | low bean body with fronds sweeping up (max displacement 0.32), bare cream head tapering to a snout, tiny ears |
| Bramble | tortoise | jasmine (flowering) | domed shell (flat_bottom 0.42), sage egg head, dome legs, teardrop tail |

Controls: drag to turn (turntable, momentum eases out), drag up/down to tilt, wheel to zoom, tap for a hop; ‹ › or
arrow keys switch pets. Captures ignore live input (`tools/capture_pets.gd`, `tools/capture_views.gd`);
`tools/rotation_check.gd` drives a scripted drag.

## Silhouette ink

`shaders/leaf_ink_shell.gdshader` is the leaves' next pass: each leaf gets a slightly larger ink copy just behind it,
drawn only where the leaf lies on the creature's outline (its surface faces sideways to the camera), so the ink is
thick at the silhouette and absent inside. `shell` 0.12 (line weight), threshold 0.74, `strength` from
`silhouette_ink`. Appendages keep their inverted-hull outline (widths are world units since the primitives are
built at true size: muzzle 0.016, tail 0.025, ears 0.018, feet 0.016).

## Regions (`profile.regions`)

Each: `center`, `radii` (ellipsoid), `parent` ("" or "HEAD"), `foliage`, `density`, `leaf_scale`, `max_displacement`,
`growth_up`, `material`.

| Region | Foliage | Leaf scale | Max displacement | Notes |
|---|---|---|---|---|
| BODY | dense (1.3) | 1.0 | 0.26 | rounded mass; the 80/20 silhouette: leaves lift off the surface no further than this |
| HEAD | 2.3 (protection thins it) | 0.65 | 0.11 | smaller leaves, tighter outline, distinct from the body; turns with the head |
| MUZZLE | none | - | - | moss, always clear; nose, mouth and teeth sit on it |
| TAIL | none | - | - | one paddle, restrained engraved crosshatch |
| EARS | none | - | - | small leaf-cups |
| FEET | none | - | - | four terracotta nubs, short and compact |

## Face (`profile.anchors`, `profile.protected_zones`)

Anchors are head-local directions on the HEAD or MUZZLE surface: EYE_LEFT, EYE_RIGHT, NOSE, MOUTH, TEETH, CHEEK_LEFT,
CHEEK_RIGHT. Features attach there, so they follow the head as its shape changes. Each protected zone has an angular
`radius` and a `strength`; foliage density and leaf size fall off as a smooth gaussian toward the anchor (a soft
clearing, never a hole), and no cluster is centred on the face. The muzzle is always clear. Eyes: dark, round,
slightly oversized, one restrained highlight, an ink rim. Mouth: a few strokes. Teeth: two pale boxes. Cheeks: a peach
wash.

## Tunable parameters

| Parameter | Gerald | Meaning |
|---|---|---|
| `leaf_size` | 0.40 | base leaf length (world units) |
| `leaves_per_cluster` | 20 | leaves per clump (head 75 %) |
| `cluster_spread` | 0.52 | angular size of a clump |
| `cluster_min_gap` | 0.36 | minimum angle between clump centres |
| `coverage` | 0.86 | fraction of a clump's leaves kept (gaps) |
| `face_clearing` | 1.0 | multiplier on all protected zones |
| `silhouette_scale` | 1.0 | multiplier on every `max_displacement` |
| `growth` | 1.0 | 0.35 LOW, 0.65 MEDIUM, 1.0 FULL |
| `flowering` | 0.35 | 0 none .. 1 FLOWERING (never near the face) |
| `tendrils` | 4 | short vines from the lower body |
| `palette` | deep forest, muted ivy, matcha, warm yellow-green, soft sage, pale highlight | a cluster's family comes from its exposure (up and toward the key = lighter); variation `color_variation` within it; crown leaves a touch paler |
| `inner_mass` | `#34502a` | the green in the gaps |
| `silhouette_ink` / `interior_ink` | 0.85 / 0.30 | ink on edge-on (silhouette) leaves vs. inside the foliage |
| `outline_strength` | 1.0 | inverted-hull outline width multiplier |
| `key_energy`, `key_angle`, `fill_energy`, `ambient_energy` | 0.72, (-58, -32), 0.30, 0.50 | soft illustration light; the fill comes from the viewer so the face never falls into shadow |
| `shadow_softness`, `shadow_strength` | 4.0, 0.32 | soft, light cast shadows on the paper |
| `eye_size`, `blink_interval`, `look_strength`, `hop_height` | 0.145, 2.4-5.5 s, 0.22, 0.38 | expression |
| `lod` | CLOSE 100 % leaves; MEDIUM 55 %, 1.25x, half interior ink; FAR 25 %, 1.7x, no interior ink | detail levels; chosen from his height on screen (>360 px CLOSE, >170 px MEDIUM) |

Rendering choices: linear tonemap (an illustration: the paper stays the paper), no environment reflections, matte
leaves (roughness 1, wrap diffuse, no specular), filmic photo-real look avoided on purpose.

## Developer view (F1)

Toggles: base primitives, regions, anchors, face zones, clusters, leaves, silhouette bounds, normals, lighting.
Sliders: foliage density, cluster size, leaf scale, silhouette displacement, face clearing, color variation, outline
strength, shadow softness (regrows from the same seed). Detail: AUTO / CLOSE / MEDIUM / FAR. Not in the player's view.

## Acceptance

`DISPLAY=:0 godot --path . --script tools/capture_views.gd && python3 tools/contact_sheet.py` renders FRONT, SIDE,
THREE-QUARTER, DISTANT and LOW, MEDIUM, FULL, FLOWERING into `/tmp/hedgepets-views` (copies in `docs/acceptance/`;
`phone_small.png` is the distant view at real phone-thumbnail size). Also `tools/capture_debug.gd`,
`tools/perf_levels.gd`, `tools/determinism_check.gd`.

Constraints (enforced by the data above): eyes and mouth never obscured (protected zones + clear muzzle); head
distinct (separate region, smaller leaves, tighter displacement); tail and feet carry no foliage; flowers never near
the face (protection < 0.05 and > 1.1 from the head); silhouette displacement bounded per region; foliage thins toward
facial anchors; rounded ellipsoid proportions.

## Measured (2026-10-08, RTX 3050, 540x960 window)

1,108 leaves built. 60 fps at every level with vsync; without vsync CLOSE 579 fps (1.7 ms), MEDIUM 563, FAR 624.
Deterministic: the same seed rebuilds identically; another seed differs.


## The goal-image pass (2026-10-08)

`docs/acceptance/goal_compare.png`: hedgepetsGoal.jpg beside Gerald.

- **All plant, except feet and tail.** Head, face, muzzle and ears are leaves. Only the eyes, nose and teeth are
  features. The face is younger, lighter leaves (a region `tint`, like the drawing's lighter face area). The leafy
  muzzle keeps leaves off only the nose and mouth.
- **Hand-drawn watercolour leaves** (`tools/make_ivy_sprites.py`: `HandInk`, `watercolor_cell`, shared by
  `make_leaf_styles.py`):
  - a fine pen line that wanders, swells with pressure and lifts off once or twice
  - paint slightly off the line, a darker wet edge, soft blooms, paper grain, pale veins
  - the shader keeps the fine line crisp with a small mip bias
- **Leaves you can tell apart:** bigger and fewer per cluster, with gaps showing a dark matte mass. Regions can override
  `coverage` and `leaves_per_cluster` (head and ears full, body with gaps).
- **Vines:** stems along the body, between the leaves, with fresh leaves along them and a tendril where each escapes.
- **Flowers** sit on top of the leaves, facing out, with their own colours (white petals, a yellow eye). Whether a pet
  flowers is dynamic: its flowering, the surprise flowers, the plant it's made of.
- **Eyes:** a soft vertical oval, glossy deep brown-black, a big sheen and a small sparkle, a fine outline.
- **Feet** dark brown with toes; **tail** a finer, darker crosshatch with a heavier outline.
- Any plant on any animal: the plant is separate from the shape (`SpeciesBuilder.restyle`).
