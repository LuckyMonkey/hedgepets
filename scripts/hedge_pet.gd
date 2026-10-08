extends Node2D

## The HedgePet itself, in two layers (the same script, two nodes):
##   base      (features_only = false) - soft watercolour masses under the leaves
##   features  (features_only = true)  - face, cheeks, sprout and pot feet on top,
##                                        redrawn every frame from the life state
## Drawn in viewport pixels: the parent Pet node offsets its children so that
## (0, 0) here is the top-left of the 1080 x 1920 canvas.

@export var features_only: bool = false
@export var draw_features: bool = false   # kept for old scenes; the features node draws the face

const Creature = preload("res://scripts/creature_definition.gd")

const LINE := Color("6b5039")               # soft brown line, never black
const HEAD_WASH := Color(0.66, 0.78, 0.45, 1.0)
const BODY_WASH := Color(0.57, 0.72, 0.39, 1.0)
const MUZZLE := Color(0.97, 0.93, 0.80, 1.0)
const BLUSH := Color(0.96, 0.55, 0.52, 0.42)
const EYE_INK := Color("2e2620")
const POT := Color("c8734a")
const POT_DARK := Color("9c5333")
const POT_RIM := Color("d98a5f")
const SPROUT := Color("6f9d46")
const MASK_PATHS := [
	"res://assets/watercolor/mask_00.png", "res://assets/watercolor/mask_01.png",
	"res://assets/watercolor/mask_02.png", "res://assets/watercolor/mask_03.png",
	"res://assets/watercolor/mask_04.png", "res://assets/watercolor/mask_05.png",
	"res://assets/watercolor/mask_06.png", "res://assets/watercolor/mask_07.png",
	"res://assets/watercolor/mask_08.png", "res://assets/watercolor/mask_09.png",
]

var pigment_textures: Array[Texture2D] = []


func _ready() -> void:
	for path in MASK_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			pigment_textures.append(texture)
	queue_redraw()


func _process(_delta: float) -> void:
	if features_only:
		queue_redraw()   # the face is alive: blinks, looks around, the sprout bobs


func _life() -> Dictionary:
	var pet := get_parent()
	if pet != null and pet.has_method("life_state"):
		return pet.life_state()
	return {"blink": 0.0, "look": Vector2.ZERO, "sprout": 0.0, "joy": 0.0, "time": 0.0}


func _draw() -> void:
	if features_only:
		_draw_features(_life())
		return
	_draw_base()


# ------------------------------------------------------------------ base wash
func _draw_base() -> void:
	# ground shadow
	draw_colored_polygon(_ellipse_points(Vector2(540, Creature.FEET_Y + 14), Vector2(270, 30), 40), Color(0.40, 0.42, 0.30, 0.13))
	# body, then the bigger head over it: soft fills, a few pigment passes, a brown line
	var body := _ellipse_points(Creature.BODY_CENTER, Creature.BODY_RADII, 56)
	draw_colored_polygon(body, BODY_WASH)
	_draw_watercolor_rect(Rect2(Creature.BODY_CENTER - Creature.BODY_RADII, Creature.BODY_RADII * 2.0), [2, 7, 5],
		[Color(0.30, 0.47, 0.18, 0.30), Color(0.62, 0.72, 0.32, 0.26), Color(0.22, 0.36, 0.13, 0.20)], [Vector2(-8, 4), Vector2(10, -6), Vector2(0, 8)])
	_draw_outline(body, LINE, 7.0)
	var head := _ellipse_points(Creature.HEAD_CENTER, Creature.HEAD_RADII, 64)
	draw_colored_polygon(head, HEAD_WASH)
	_draw_watercolor_rect(Rect2(Creature.HEAD_CENTER - Creature.HEAD_RADII, Creature.HEAD_RADII * 2.0), [1, 6, 9],
		[Color(0.34, 0.52, 0.20, 0.30), Color(0.72, 0.78, 0.36, 0.24), Color(0.25, 0.40, 0.14, 0.18)], [Vector2(6, 0), Vector2(-10, 6), Vector2(4, -8)])
	_draw_painterly_blooms(Creature.HEAD_CENTER, Creature.HEAD_RADII * 0.8, [
		Color(0.86, 0.84, 0.48, 0.14), Color(0.30, 0.48, 0.17, 0.12), Color(0.60, 0.70, 0.30, 0.12)], 90)
	# a pale muzzle where the face lives, so the leaves part around it
	draw_colored_polygon(_ellipse_points(Vector2(540, 878), Vector2(168, 112), 56), Color(MUZZLE, 0.55))
	draw_colored_polygon(_ellipse_points(Vector2(540, 884), Vector2(140, 92), 48), Color(MUZZLE, 0.45))
	draw_colored_polygon(_ellipse_points(Vector2(540, 892), Vector2(104, 70), 40), Color(1.0, 0.97, 0.88, 0.35))
	_draw_outline(head, LINE, 7.0)


# ------------------------------------------------------------------ the face and friends
func _draw_features(life: Dictionary) -> void:
	var t: float = life["time"]
	var joy: float = life["joy"]
	_draw_sprout(float(life["sprout"]), joy)
	_draw_feet()
	# cheeks
	for side: float in [-1.0, 1.0]:
		var cheek := Vector2(540 + side * 150.0, 905.0)
		draw_colored_polygon(_ellipse_points(cheek, Vector2(44, 26), 24), Color(BLUSH, BLUSH.a + 0.25 * joy))
	# eyes: big, dark, two highlights; they follow the pointer and blink
	var look: Vector2 = life["look"]
	var blink: float = life["blink"]
	for eye: Vector2 in [Creature.EYE_LEFT, Creature.EYE_RIGHT]:
		_draw_eye(eye + look * 6.0, look, blink, joy)
	# nose and a small smile (a happy "w" when tapped)
	draw_colored_polygon(_ellipse_points(Creature.NOSE + look * 4.0, Vector2(16, 11), 18), Color("5a3d2b"))
	draw_circle(Creature.NOSE + look * 4.0 + Vector2(-5, -4), 3.5, Color(1, 1, 1, 0.55))
	var mouth := Creature.NOSE + look * 4.0 + Vector2(0, 26)
	var open := 4.0 + 10.0 * joy
	draw_arc(mouth + Vector2(-13, 0), 13.0, 0.15, PI - 0.15, 14, LINE, 4.5, true)
	draw_arc(mouth + Vector2(13, 0), 13.0, 0.15, PI - 0.15, 14, LINE, 4.5, true)
	if joy > 0.25:
		draw_colored_polygon(_ellipse_points(mouth + Vector2(0, 8 + open * 0.3), Vector2(10, open), 16), Color("b9574a"))
	# a little heart pops out when it is happy
	if joy > 0.05:
		var h := Vector2(700, 640 - 60.0 * (1.0 - joy))
		_draw_heart(h, 22.0 + 6.0 * sin(t * 9.0), Color(0.93, 0.42, 0.45, clampf(joy * 1.4, 0.0, 1.0)))


func _draw_eye(center: Vector2, look: Vector2, blink: float, joy: float) -> void:
	var r := Creature.EYE_RADIUS
	if joy > 0.6:
		# squeezed-shut happy eyes: ^ ^
		draw_arc(center + Vector2(0, 10), r * 0.75, PI + 0.35, TAU - 0.35, 16, EYE_INK, 7.0, true)
		return
	var open := clampf(1.0 - blink, 0.08, 1.0)
	if open < 0.2:
		draw_arc(center + Vector2(0, -6), r * 0.8, 0.3, PI - 0.3, 16, EYE_INK, 6.0, true)   # closed: a soft curve
		return
	draw_colored_polygon(_ellipse_points(center, Vector2(r, r * 1.08 * open), 32), EYE_INK)
	draw_circle(center + Vector2(-11, -13 * open) + look * 3.0, r * 0.34, Color(1, 1, 1, 0.95))
	draw_circle(center + Vector2(12, 12 * open) + look * 3.0, r * 0.14, Color(1, 1, 1, 0.8))


func _draw_sprout(phase: float, joy: float) -> void:
	# two leaves on a stem from the crown, bobbing
	var sway := sin(phase) * 0.22 + sin(phase * 2.3) * 0.06 + joy * 0.3 * sin(phase * 6.0)
	var base := Creature.SPROUT_BASE
	var tip := base + Vector2(0, -78).rotated(sway)
	draw_line(base, base.lerp(tip, 0.5) + Vector2(6, 0).rotated(sway), SPROUT.darkened(0.2), 7.0, true)
	draw_line(base.lerp(tip, 0.5) + Vector2(6, 0).rotated(sway), tip, SPROUT.darkened(0.2), 6.0, true)
	for side: float in [-1.0, 1.0]:
		var leaf_dir := Vector2(side, -0.55).normalized().rotated(sway * 1.3)
		var leaf_center := tip + leaf_dir * 34.0
		var leaf := _leaf_points(leaf_center, leaf_dir, 40.0, 19.0)
		draw_colored_polygon(leaf, SPROUT)
		_draw_outline(leaf, LINE, 4.0)
		draw_line(tip, leaf_center + leaf_dir * 22.0, Color(LINE, 0.45), 2.5, true)


func _draw_feet() -> void:
	# two little terracotta pots; the left one has a chip (it has been repotted four times)
	for side: float in [-1.0, 1.0]:
		var x: float = 540.0 + side * 98.0
		var top := Creature.FEET_Y - 52.0
		var pot := PackedVector2Array([Vector2(x - 54, top + 12), Vector2(x + 54, top + 12), Vector2(x + 40, Creature.FEET_Y), Vector2(x - 40, Creature.FEET_Y)])
		draw_colored_polygon(pot, POT)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 18, top + 12), Vector2(x + 54, top + 12), Vector2(x + 40, Creature.FEET_Y), Vector2(x + 14, Creature.FEET_Y)]), Color(POT_DARK, 0.45))
		var rim := Rect2(x - 62, top, 124, 22)
		draw_rect(rim, POT_RIM)
		draw_rect(rim, LINE, false, 4.0)
		_draw_outline(pot, LINE, 4.0)
		if side < 0:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 62, top), Vector2(x - 40, top), Vector2(x - 50, top + 14)]), Color(0.97, 0.94, 0.87))   # the chip


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40):
		var a := TAU * float(i) / 40.0
		var x := 16.0 * pow(sin(a), 3)
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		points.append(center + Vector2(x, y) * size / 16.0)
	draw_colored_polygon(points, color)


# ------------------------------------------------------------------ helpers
func _leaf_points(center: Vector2, direction: Vector2, length: float, width: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var normal := Vector2(-direction.y, direction.x)
	for i in range(16):
		var u := float(i) / 15.0 * 2.0 - 1.0
		points.append(center + direction * u * length * 0.5 + normal * sqrt(maxf(0.0, 1.0 - u * u)) * width * 0.5)
	for i in range(16):
		var u := 1.0 - float(i) / 15.0 * 2.0
		points.append(center + direction * u * length * 0.5 - normal * sqrt(maxf(0.0, 1.0 - u * u)) * width * 0.5)
	return points


func _draw_watercolor_rect(rect: Rect2, indices: Array, colors: Array, offsets: Array) -> void:
	for index in range(mini(indices.size(), colors.size())):
		var texture_index: int = indices[index]
		if texture_index < 0 or texture_index >= pigment_textures.size():
			continue
		var offset: Vector2 = offsets[index] if index < offsets.size() else Vector2.ZERO
		draw_texture_rect(pigment_textures[texture_index], Rect2(rect.position + offset, rect.size), false, colors[index])


func _draw_painterly_blooms(center: Vector2, radii: Vector2, colors: Array[Color], seed: int) -> void:
	for index in range(colors.size()):
		var ratio := 0.48 + _deterministic_unit(seed + index * 17) * 0.44
		var bloom_center := center + Vector2((_deterministic_unit(seed + index * 23 + 1) - 0.5) * radii.x * 1.1, (_deterministic_unit(seed + index * 23 + 2) - 0.5) * radii.y)
		draw_colored_polygon(_irregular_blob(bloom_center, radii * (0.2 + ratio * 0.18), seed + index * 101), colors[index])


func _irregular_blob(center: Vector2, radii: Vector2, seed: int, segments: int = 18) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		var wobble := 0.9 + 0.1 * sin(float(seed + index * 13) * 1.71)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * wobble)
	return points


func _deterministic_unit(key: int) -> float:
	return 0.5 + 0.5 * sin(float(key * 9283 + 17) * 12.9898 + 78.233)


func _ellipse_points(center: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color, width, true)
