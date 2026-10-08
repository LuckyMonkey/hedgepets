# Motion

Every transition in HedgePets goes through `scripts/anim/motion.gd` (`Motion`). Nothing pops, snaps or fights.

- **One spec.** `FAST` 0.16 s, `BASE` 0.32 s, `SLOW` 0.6 s and the easings live in one file.
- **One owner per channel.** `Motion.channel(node, key)` kills whatever tween held that node and key before
  starting a new one, so two animations never pull the same property. Tweens are bound to their node, so freeing a
  node stops its tweens.
- **One dial.** `Motion.speed` scales every duration and spring. 0 makes everything instant, for reduced motion and
  for every capture or check tool.

| What | How |
|---|---|
| a pet arrives / leaves | `appear` (scale in with overshoot) / walks out through the gap, then `vanish` |
| regraft (✂️, 🍃/F) | a burst of the old leaves, `shed_leaves`, `swap` (squash, change, spring back), `grow_leaves` |
| viewer ‹ › | `HedgePetNode.become`: the same as a regraft, then the camera springs to the new framing |
| detail level (LOD) | each leaf scales to its stalk over a soft band in `leaf.gdshader`; `set_detail` tweens the level |
| plant grows a stage | the new stage scales up from the old one's size while the old shrinks away underneath |
| seedbed, gift, emote | `appear`; gifts `drop` with a bounce, then bob; collected gifts and emotes `float_away` |
| cleared junk | `vanish` |
| camera (garden, viewer) | `Motion.spring`: a critically damped follow (eases in and out, no lunge); tight under a finger, a glide after a fling |
| toast | the old one fades, the new one slides in, holds, fades |
| tools, seeds | opacity and scale ease to the selection |
| seed bar, journal | `slide_in` / `fade` |
| coins | `count` rolls the number, `pulse` taps it |

Rules for new code: never set a visible property in one jump (`visible`, `scale`, `position`, `modulate`, a shader
value) when the player can see it. Use a `Motion` verb, or add one here.

## Check

    godot --headless --path . --script tools/motion_check.gd --fixed-fps 60

The check drives every transition above in real time and fails on any frame-to-frame jump over its limit.
