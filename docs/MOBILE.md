# Mobile and web export: compatibility report

Audited 2026-10-08 on Godot **4.7.2.stable** (official build). HedgePets stays fully offline: no accounts, networking,
analytics, ads, subscriptions or purchases. The Android preset requests no permissions, not even INTERNET.

**Status: no Android, iOS or Web build has been produced yet.** Every attempt stopped at missing export templates
and toolchains on this machine (see "To export"). What *has* been proven is the exported game itself: the
project was packed with the real export filters (`--export-pack`, the same content an APK, IPA or web build carries)
and run from that pack alone, outside the project folder. It started, built the garden, and an arrival used
`species.json` and the plant variants, with no errors.

## What the project is

| | |
|---|---|
| Engine | Godot 4.7.2, GDScript only (no C#, no GDExtension, no native plugins) |
| Renderer | `gl_compatibility` on desktop **and** mobile (`rendering_method.mobile`), i.e. OpenGL 3.3 / OpenGL ES 3.0 / WebGL 2 |
| Graphics API on device | OpenGL ES 3.0 (Android, iOS via ANGLE/Metal in Godot's iOS template), WebGL 2 (web) |
| Shaders | 9 `.gdshader` + 2 `.gdshaderinc` (below) |
| Textures | 38 PNG sprite sheets imported **lossless** (`compress/mode=0`, no mipmaps); read at runtime as images |
| Orientation | portrait (`display/window/handheld/orientation=1`), 1080 x 1920 base, `stretch/mode=canvas_items`, aspect `keep` |
| Input | mouse, keyboard, touch (one finger: turn / tap / grab; two fingers: pan + pinch zoom) |
| Saves | `user://garden.json` (Godot's per-platform app data folder) |
| Runtime dependencies | none. Python (`tools/*.py`) only generates assets offline; nothing runs Python at runtime |

## 1. Already compatible

- **Language and engine features:** pure GDScript, no threads, no `OS.execute`, no network, no native code.
- **Python assets:** every Python-made asset is an ordinary imported Godot resource. That covers the leaf sheets, normal maps, grass, lawn detail and the glyph fonts.
  - In the exported pack only the imported versions are present: no raw `.png` sprites, no `.py`.
  - `assets/fonts/*_geometry.json` and `assets/plants/plant_profiles.json` are included by the export filter. Only the legacy 2D scene reads them.
- **Shaders (all 11 checked):** only Compatibility-renderer features: MultiMesh `INSTANCE_CUSTOM`, `discard`, `#include`, a custom `light()` (paper_ground), `hint_screen_texture` + `SCREEN_UV` (tilt_shift), `FRAGCOORD`, and a constant `int[16]` array with dynamic indexing (near_fade). That is legal GLSL ES 3.00 and WebGL 2.
  - None uses compute, the depth texture, `uint` or bitwise operations, `textureLod`, `texelFetch`, derivatives, global or instance uniforms.
  - These are the same shaders the desktop already runs in this renderer.
  - | shader | notes |
    |---|---|
    | leaf, leaf_ink_shell | MultiMesh custom data, wind include, near-fade include, `discard` |
    | ink_hull | inverted hull, `cull_front`, near-fade |
    | grass | MultiMesh custom data, `discard` |
    | lawn | two texture reads, world-space UVs |
    | water, creek | alpha blend, `discard`, fresnel from `VIEW` |
    | paper_ground | custom `light()` (viewer only) |
    | tilt_shift | screen texture, 12 x 2 taps (cost: see 4) |
    | leaf_common.gdshaderinc, near_fade.gdshaderinc | plain functions; Bayer table as a constant `int` array |
- **Saving:** `user://` works on Android, iOS and web (IndexedDB on web). The pickup cooldown uses `Time.get_unix_time_from_system()`, which every platform provides.
- **Pet files:** the hand-made pets are found by listing `res://pets`. That already handles exported `.tres.remap` names, and the pack test confirmed it.

## 2. Requires configuration (done in this pass unless noted)

- `rendering/textures/vram_compression/import_etc2_astc=true` (**done**): Android refuses to export without ETC2/ASTC. It only adds mobile copies of compressed textures; desktop textures are unchanged.
- `export_presets.cfg` (**done**): Android, iOS and Web presets.
  - Include filter: `pets/species.json`, `assets/plants/*.json`, `assets/fonts/*_geometry.json` (plain JSON isn't exported otherwise).
  - Exclude filter: `tools/*`, `docs/*`, `build/*`.
  - Android: arm64-v8a only, no permissions, immersive mode, version 0.1.0 (1).
  - iOS: `export_project_only` (an Xcode project, built on a Mac), iPhone + iPad, arm64.
  - Web: no threads (no cross-origin isolation needed, works on any static host), ETC2 + S3TC, no PWA.
- **Package / bundle id** is a placeholder: `org.hedgepets.game`. Choose the real one before any store upload.
- **Signing is left empty on purpose.**
  - Android: a debug keystore must exist at the editor setting's path (command below).
  - iOS: an Apple Developer **Team ID** is required even for `export_project_only`; signing happens in Xcode.
- **Not done:** app icons (Android launcher / adaptive, iOS icon set). They default to the Godot icon.
- **Not decided: tall phones.** The 1080 x 1920 layout is letterboxed (`aspect=keep`) on 19.5:9 screens: thin bars top and bottom, nothing cut off.
  - Using the full height would need the HUD anchored to the screen edges instead of fixed positions.
  - That's a design change for desktop too, so it was not made.

## 3. Required code or shader changes

Done in this pass. The desktop game behaves the same; every existing check still passes.

- **Asset loading, broken in every export** (desktop exports too).
  - Ten places read sprite PNGs from `res://` with `Image.load_from_file(globalize_path(...))`. Exports don't ship raw source files, so the leaf sheets, grass, lawn and falling leaves would all have failed.
  - Now `Assets.image()` (`scripts/util/assets.gd`) loads the imported texture and takes its pixels. Exact, because the sheets are lossless.
- **Touch handled twice.**
  - Godot sends every touch again as an emulated mouse event, which the HUD's buttons need. The garden and the viewer handled both: a one-finger turn ran at double speed, and a touch on a HUD button also reached the garden underneath.
  - Now both ignore emulated mouse events (`InputEvent.DEVICE_ID_EMULATION`), and a touch landing on a visible HUD control is left to the HUD (`garden_game.ui_blocks`).
  - Desktop mouse input is unchanged.
- **Startup time.** The garden took **23 s** to build on this desktop CPU (minutes on a phone), and every arriving pet stalled the game for about **2 s**.
  - Tree and hedge foliage, stone and slate meshes and every pet's native foliage are now read from a baked cache. That's `res://assets/baked/garden.res`, made by `tools/bake_cache.gd`.
  - Startup is **about 2 s**, and a pet arrives in at most **0.3 s**.
  - The bake rebuilds everything, reads it back and checks all 1,309 entries are identical. In the editor the cache is ignored automatically whenever the generator code has changed since the bake.
  - Rebake before every export.
  - The cache is **17.4 MB** (the exported pack is 28 MB).
- **Still open, needs a decision:**
  - **Emoji on the web.** The HUD's tool icons and messages use emoji. Desktop, Android and iOS fall back to system fonts; Godot's web build has no system font fallback, so emoji will show as boxes there. Fix by bundling an emoji font; it needs a licence choice, e.g. Twemoji or OpenMoji, both CC-BY.
  - **Variant and regraft hitches.** A pet arriving as a variant, or regrafted with ✂️, is built live (about 2 s here). On a phone that is a visible hitch. Options: bake all variants (about 4x the cache) or build on a worker thread.
  - **Pet viewer zoom on touch.** The viewer (`main3d.tscn`, a dev scene, not the game) only zooms with the mouse wheel. The garden has pinch.

## 4. Requires physical-device testing

- **Frame rate.** The garden is about 3.6 ms/frame on an RTX 3050. A phone GPU is roughly 10-30x slower. The main costs:
  - the full-screen tilt-shift (24 screen-texture taps per pixel at 1080 x 1920)
  - 22k grass tufts and about 4k litter leaves
  - leaf MultiMeshes with alpha-tested `discard`
  - one directional shadow map
  - Likely levers, if needed: tilt-shift at half resolution or fewer taps, fewer grass tufts, a shorter shadow distance.
- **Thermals and battery** over a long session.
- **Memory:** the startup cache plus the leaf sheets as uncompressed RGBA. Check on 2-3 GB devices.
- **Touch feel:** turn speed, two-finger pan and pinch, grab and yank strain (a "jerk" is measured in px/s, and phone screens are dense), and the strain ring's size.
- **System font fallback** for emoji on the Android and iOS versions you target.
- **Notches and gesture bars:** the letterboxed layout keeps the HUD off the edges, but check the bottom toolbar against the home indicator.
- **Saving across app suspend and kill:** the game autosaves every 8 s. Background or kill the app and confirm that's enough.
- **Web:** first-load time for a ~28 MB pack plus the engine, WebGL 2 on Safari (iOS) and Chrome Android, and whether IndexedDB saves survive.

## To export (this machine)

None of these are installed yet:

1. **Export templates, all platforms.** Download `Godot_v4.7.2-stable_export_templates.tpz` from the official Godot release page and install it.
   - Editor: Editor > Manage Export Templates > Install from File.
   - Or by hand: unzip it and move its `templates/` contents to `~/.local/share/godot/export_templates/4.7.2.stable/`.
   - That's a user-level folder, about 1 GB, and the download needs network access.
2. **Android:**
   - A JDK 17. It's a system package, so it needs sudo: `sudo apt install openjdk-17-jdk-headless`.
   - The Android SDK command-line tools, with `platform-tools`, `build-tools` and a `platforms;android-NN` matching the Godot 4.7 docs.
   - Point the editor settings `export/android/java_sdk_path` and `export/android/android_sdk_path` at them. The SDK path currently set, `~/Android/Sdk`, doesn't exist.
   - A **debug** keystore at `~/.local/share/godot/keystores/debug.keystore`. Android's documented debug convention is password `android`, alias `androiddebugkey`; release signing is yours to create:
     `keytool -genkeypair -v -keystore ~/.local/share/godot/keystores/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -validity 9999 -dname "CN=Android Debug,O=Android,C=US"`
3. **iOS:** an Apple Developer Team ID in the iOS preset. Then export the Xcode project here and build and sign on a Mac with Xcode.
4. Then:

       godot --headless --path . --script tools/bake_cache.gd        # always first
       godot --headless --path . --export-debug "Web" build/web/index.html
       godot --headless --path . --export-debug "Android" build/android/HedgePets.apk
       godot --headless --path . --export-debug "iOS" build/ios/HedgePets.ipa

## Checks that need no templates

    godot --headless --path . --export-pack "Web" build/packtest/hedgepets.pck   # the exported content
    cd /tmp && godot --main-pack ~/Projects/hedgepets/build/packtest/hedgepets.pck   # run the game from it
    godot --headless --path . --script tools/boot_time.gd                         # startup, part by part
