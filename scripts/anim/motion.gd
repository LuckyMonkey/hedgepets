class_name Motion
extends RefCounted

## Every transition in HedgePets goes through here, so nothing pops, snaps or fights.
##
##   One spec       durations and easings below; change the feel of the whole game in one place.
##   One owner      each animation has a channel (node + key). Starting a new one on the same channel kills the old
##                  one first, so two tweens never pull the same property in different directions; a channel's
##                  tween is bound to its node, so freeing the node stops it.
##   One dial       Motion.speed scales every duration (0 = instant, for reduced motion or tests).
##
## Vocabulary (all return the Tween, or null when instant):
##   appear / vanish        scale a 3D thing in with a little overshoot / out (and hide or free it)
##   swap                   squash, change it at the bottom (a Callable), spring back: regrafts, pet switches
##   grow_leaves / shed_leaves   a pet's foliage grows in crown-first / falls away (leaf LOD in the shader)
##   drop                   fall to the ground with a bounce: gifts
##   float_away             rise and fade, then free: emotes, collected gifts
##   fade / slide_in / pulse / count       UI: opacity, a slide with fade, a tap of scale, a number rolling
##   approach               frame-rate independent smoothing toward a goal that moves every frame
##   spring                 a critically damped follow (eases in AND out, no lunge): the camera

const FAST := 0.16
const BASE := 0.32
const SLOW := 0.6

static var speed := 1.0


static func _d(seconds: float) -> float:
	return maxf(seconds * speed, 0.0001)


## A tween that owns `key` on `node` (killing whatever had it before).
static func channel(node: Node, key: String) -> Tween:
	var meta := "motion_" + key
	if node.has_meta(meta):
		var old = node.get_meta(meta)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var t := node.create_tween()
	node.set_meta(meta, t)
	return t


static func busy(node: Node, key: String) -> bool:
	var meta := "motion_" + key
	return node.has_meta(meta) and node.get_meta(meta) is Tween and (node.get_meta(meta) as Tween).is_running()


# ------------------------------------------------------------------ 3D
static func appear(node: Node3D, rest_scale: Vector3, dur := BASE) -> Tween:
	node.visible = true
	node.scale = rest_scale * 0.01
	var t := channel(node, "scale")
	t.tween_property(node, "scale", rest_scale, _d(dur)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Scale out; then free the node (free = true) or just hide it and restore its scale (free = false).
static func vanish(node: Node3D, free := true, dur := BASE * 1.4) -> Tween:
	var rest := node.scale
	var t := channel(node, "scale")
	t.tween_property(node, "scale", rest * 0.01, _d(dur)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if free:
		t.tween_callback(node.queue_free)
	else:
		t.tween_callback(func() -> void:
			node.visible = false
			node.scale = rest)
	return t


## Squash down, do `change` at the bottom, spring back up to rest_scale. Used whenever something becomes something else.
static func swap(node: Node3D, rest_scale: Vector3, change: Callable) -> Tween:
	var t := channel(node, "scale")
	t.tween_property(node, "scale", Vector3(rest_scale.x * 1.12, rest_scale.y * 0.72, rest_scale.z * 1.12), _d(FAST)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(change)
	t.tween_property(node, "scale", rest_scale, _d(SLOW)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return t


## A pet's leaves grow in from bare (the shader keeps crown leaves first, so they sprout biggest-first).
static func grow_leaves(pet: HedgePetNode, dur := SLOW * 1.4) -> Tween:
	pet.leaf_growth = 0.0
	var t := channel(pet, "leaves")
	t.tween_property(pet, "leaf_growth", 1.0, _d(dur)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return t


static func shed_leaves(pet: HedgePetNode, dur := BASE * 1.5) -> Tween:
	var t := channel(pet, "leaves")
	t.tween_property(pet, "leaf_growth", 0.0, _d(dur)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t


## Fall from where it is to y = ground, with a bounce.
static func drop(node: Node3D, ground: float, dur := SLOW) -> Tween:
	var t := channel(node, "drop")
	t.tween_property(node, "position:y", ground, _d(dur)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return t


## Rise and fade, then free (Label3D / GeometryInstance3D with modulate or transparency).
static func float_away(node: Node3D, rise := 0.8, dur := 1.4, delay := 0.4) -> Tween:
	var t := channel(node, "float")
	t.tween_property(node, "position:y", node.position.y + rise, _d(dur)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if "modulate" in node:
		t.parallel().tween_property(node, "modulate:a", 0.0, _d(dur - delay)).set_delay(_d(delay))
	t.tween_callback(node.queue_free)
	return t


## Frame-rate independent exponential smoothing toward a goal: rate = how fast (per second).
static func approach(from: Variant, to: Variant, rate: float, delta: float) -> Variant:
	if speed <= 0.0:
		return to
	return lerp(from, to, 1.0 - exp(-rate * delta / speed))


## Critically damped spring toward `to` (Unity's SmoothDamp): `state` holds the velocity between frames, so a far
## goal starts gently, travels, and settles - never a lunge. smooth_time ~ the time to get most of the way there.
static func spring(from: Variant, to: Variant, state: Dictionary, smooth_time: float, delta: float) -> Variant:
	if speed <= 0.0:
		state["v"] = to - to
		return to
	var st := maxf(0.0001, smooth_time * speed)
	var omega := 2.0 / st
	var x := omega * delta
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var v = state.get("v", to - to)
	var change = from - to
	var temp = (v + change * omega) * delta
	state["v"] = (v - temp * omega) * e
	return to + (change + temp) * e


# ------------------------------------------------------------------ UI
static func fade(item: CanvasItem, alpha: float, dur := BASE) -> Tween:
	var t := channel(item, "fade")
	if alpha > 0.0:
		item.visible = true
	t.tween_property(item, "modulate:a", alpha, _d(dur)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if alpha <= 0.0:
		t.tween_callback(func() -> void: item.visible = false)
	return t


## Fade in while sliding from `offset` to the control's rest position.
static func slide_in(c: Control, rest: Vector2, offset := Vector2(0, -24), dur := BASE) -> Tween:
	c.visible = true
	c.position = rest + offset
	c.modulate.a = 0.0
	var t := channel(c, "slide")
	t.tween_property(c, "position", rest, _d(dur)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(c, "modulate:a", 1.0, _d(dur * 0.8))
	return t


## A quick tap of scale (about the control's centre).
static func pulse(c: Control, amount := 1.15, dur := FAST * 2.0) -> Tween:
	c.pivot_offset = c.size * 0.5
	var t := channel(c, "pulse")
	t.tween_property(c, "scale", Vector2.ONE * amount, _d(dur * 0.35)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, _d(dur * 0.65)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Hold a control at `scale` (selected tools), eased.
static func scale_to(c: Control, s: float, dur := FAST) -> Tween:
	c.pivot_offset = c.size * 0.5
	var t := channel(c, "pulse")
	t.tween_property(c, "scale", Vector2.ONE * s, _d(dur)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t


## Roll a number shown by `show` (a Callable taking an int) from `from` to `to`.
static func count(owner: Node, from: int, to: int, show: Callable, dur := BASE * 1.5) -> Tween:
	var t := channel(owner, "count")
	t.tween_method(func(v: float) -> void: show.call(int(round(v))), float(from), float(to), _d(dur)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return t
