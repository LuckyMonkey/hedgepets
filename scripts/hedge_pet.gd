extends Node2D

## The HedgePet itself - a beaver grown over with ivy - in two layers (the same script, two nodes):
##   base      (features_only = false) - tail, far feet, fur masses and shading, under the leaves
##   features  (features_only = true)  - the face and the near feet on top, redrawn every frame from the life state
## Drawn in viewport pixels: the parent Pet node offsets its children so that (0, 0) here is the canvas top-left.

@export var features_only: bool = false
@export var draw_features: bool = false   # kept for old scenes; the features node draws the face

const Creature = preload("res://scripts/creature_definition.gd")

const LINE := Color("2b2a17")              # ink: dark olive, never black
const DEEP := Color("1f3316")              # the inside of the hedge: deep leafy shade between the leaves
const DEEP_2 := Color("2c4a1e")
const MOSS := Color("6f8f3a")
const TWIG := Color("6e5536")              # woven twigs (the tail), roots (the feet)
const TWIG_DARK := Color("3f2f1c")
const TWIG_LIGHT := Color("a8875a")
const LEAF := Color("5d8a37")
const EYE_INK := Color("1a1420")           # a glossy dark berry
const NOSE := Color("3b2617")              # a seed
const TOOTH := Color("efe6c4")             # two pale seeds
const BLUSH := Color(0.90, 0.50, 0.42, 0.22)
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
		queue_redraw()   # the face is alive: blinks, looks around, smiles when tapped


func _life() -> Dictionary:
	var pet := get_parent()
	if pet != null and pet.has_method("life_state"):
		return pet.life_state()
	return {"blink": 0.0, "look": Vector2.ZERO, "joy": 0.0, "time": 0.0}


func _draw() -> void:
	if features_only:
		_draw_features(_life())
		return
	_draw_base()


# ------------------------------------------------------------------ under the leaves
func _draw_base() -> void:
	for i in range(4):   # ground shadow
		var k := float(i) / 3.0
		draw_colored_polygon(_ellipse_points(Vector2(520, Creature.FEET_Y + 6), Vector2(470.0 - k * 120.0, 46.0 - k * 14.0), 48), Color(0.30, 0.28, 0.18, 0.06))
	_draw_tail()
	for foot in Creature.FEET:
		if foot[2]:
			_draw_foot(foot[0], foot[1], true)
	# the body and head are foliage all the way through: deep leafy shade under the ivy, rounded by the light
	for mass in [[Creature.BODY_CENTER, Creature.BODY_RADII], [Creature.HEAD_CENTER, Creature.HEAD_RADII]]:
		var center: Vector2 = mass[0]
		var radii: Vector2 = mass[1]
		draw_colored_polygon(_ellipse_points(center, radii * 0.98, 64), DEEP)
		_draw_watercolor_rect(Rect2(center - radii, radii * 2.0), [2, 7], [Color(DEEP_2, 0.6), Color(0.16, 0.26, 0.10, 0.5)], [Vector2(-8, 4), Vector2(10, -6)])
		_shade_sphere(center, radii, 1.0)
	# moss over the muzzle: soft, light green, the features sit in it
	draw_colored_polygon(_ellipse_points(Vector2(905, 962), Vector2(92, 70), 40), Color(MOSS, 0.85))
	draw_colored_polygon(_ellipse_points(Vector2(895, 950), Vector2(60, 44), 32), Color(0.62, 0.72, 0.36, 0.6))
	_draw_moss_dots(Vector2(905, 962), Vector2(88, 64), 120)

func _draw_ear() -> void:
	# the ear: a cupped leaf, standing up out of the ivy
	var ear_dir := Vector2(-0.35, -1.0).normalized()
	var ear := _leaf_points(Creature.EAR + ear_dir * 6.0, ear_dir, 96.0, 64.0)
	draw_colored_polygon(ear, LEAF)
	draw_colored_polygon(_leaf_points(Creature.EAR + ear_dir * 10.0, ear_dir, 64.0, 34.0), Color(DEEP_2, 0.9))
	_draw_outline(ear, Color(LINE, 0.8), 3.5)
	draw_line(Creature.EAR - ear_dir * 36.0, Creature.EAR + ear_dir * 40.0, Color(0.75, 0.85, 0.5, 0.6), 2.5, true)


func _draw_tail() -> void:
	# the paddle tail, woven from twigs, tucked behind the body; a few leaves sprout from its edge
	var turn := -0.18
	var points := PackedVector2Array()
	for p in _ellipse_points(Vector2.ZERO, Creature.TAIL_RADII, 48):
		points.append(Creature.TAIL_CENTER + p.rotated(turn))
	draw_colored_polygon(points, TWIG_DARK)
	for i in range(-7, 8):
		for dir: float in [1.0, -1.0]:
			var a := Vector2(float(i) * 26.0 - 120.0 * dir, -130.0)
			var b := Vector2(float(i) * 26.0 + 120.0 * dir, 130.0)
			var seg := _clip_to_ellipse(a, b, Creature.TAIL_RADII * 0.97)
			if seg.size() == 2:
				var p0 := Creature.TAIL_CENTER + seg[0].rotated(turn)
				var p1 := Creature.TAIL_CENTER + seg[1].rotated(turn)
				var bow := (p1 - p0).orthogonal().normalized() * 4.0 * dir
				draw_polyline(PackedVector2Array([p0, (p0 + p1) * 0.5 + bow, p1]), TWIG, 9.0, true)
				draw_polyline(PackedVector2Array([p0, (p0 + p1) * 0.5 + bow, p1]), Color(TWIG_LIGHT, 0.55), 3.0, true)
	_shade_sphere(Creature.TAIL_CENTER, Creature.TAIL_RADII * 0.95, 1.2)
	for k in range(9):   # twig ends poking out of the weave, and a few sprouting leaves
		var a := TAU * float(k) / 9.0 + 0.3
		var rim := Creature.TAIL_CENTER + (Vector2(cos(a), sin(a)) * Creature.TAIL_RADII).rotated(turn)
		var out := (rim - Creature.TAIL_CENTER).normalized()
		draw_line(rim - out * 6.0, rim + out * 16.0, TWIG, 5.0, true)
		if k % 3 == 0:
			var leaf := _leaf_points(rim + out * 24.0, out.rotated(0.5), 34.0, 18.0)
			draw_colored_polygon(leaf, LEAF)
			_draw_outline(leaf, Color(LINE, 0.7), 2.5)


func _draw_foot(center: Vector2, size: float, far: bool) -> void:
	# a clump of roots where a foot would be: a mossy knot with roots splaying into the ground
	var color := TWIG.darkened(0.3) if far else TWIG
	for r in range(5):
		var a := lerpf(0.15, PI - 0.15, float(r) / 4.0)
		var tip := center + Vector2(cos(a) * 58.0, 10.0 + sin(a) * 14.0) * size
		var mid := center.lerp(tip, 0.5) + Vector2(0, 6) * size
		draw_polyline(PackedVector2Array([center, mid, tip]), color, (7.0 - absf(float(r) - 2.0)) * size, true)
		draw_polyline(PackedVector2Array([mid, mid + Vector2((float(r) - 2.0) * 8.0, 12.0) * size]), color, 3.0 * size, true)
	var knot := _ellipse_points(center + Vector2(0, -4) * size, Vector2(26, 15) * size, 24)
	draw_colored_polygon(knot, MOSS.darkened(0.25) if not far else MOSS.darkened(0.5))
	_draw_moss_dots(center + Vector2(0, -4) * size, Vector2(22, 12) * size, 12)
	_draw_outline(knot, Color(LINE, 0.5), 3.0)


func _draw_moss_dots(center: Vector2, radii: Vector2, count: int) -> void:
	for i in range(count):
		var a := TAU * _deterministic_unit(i * 7 + 3)
		var r := sqrt(_deterministic_unit(i * 11 + 5))
		var p := center + Vector2(cos(a) * radii.x * r, sin(a) * radii.y * r)
		draw_circle(p, 2.0 + 2.5 * _deterministic_unit(i * 3), Color(0.78, 0.86, 0.48, 0.35) if i % 3 else Color(0.22, 0.34, 0.12, 0.35))


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


## Light from the upper left: soft layers make a flat ellipse read as a round mass.
func _shade_sphere(center: Vector2, radii: Vector2, amount: float) -> void:
	for i in range(7):   # shade gathers toward the lower right
		var k := float(i) / 6.0
		var c := center + Vector2(radii.x * 0.12, radii.y * 0.16) * (1.0 + k * 1.5)
		draw_colored_polygon(_ellipse_points(c, radii * (1.0 - k * 0.45), 48), Color(0.05, 0.08, 0.02, 0.05 * amount))
	for i in range(5):   # light pools toward the upper left
		var k := float(i) / 4.0
		var c := center + Vector2(-radii.x * 0.30, -radii.y * 0.36) * (0.6 + k * 0.4)
		draw_colored_polygon(_ellipse_points(c, radii * (0.58 - k * 0.40), 40), Color(1.0, 0.96, 0.74, 0.05 * amount))


# ------------------------------------------------------------------ on top: the face and the near feet
func _draw_features(life: Dictionary) -> void:
	var t: float = life["time"]
	var joy: float = life["joy"]
	var look: Vector2 = life["look"]
	for foot in Creature.FEET:
		if not foot[2]:
			_draw_foot(foot[0], foot[1], false)
	_draw_ear()
	draw_colored_polygon(_ellipse_points(Vector2(870, 962), Vector2(26, 15), 20), Color(BLUSH, BLUSH.a + 0.3 * joy))   # a pink flush in the moss
	_draw_eye(Creature.EYE + look * Vector2(5, 4), look, float(life["blink"]), joy)
	# the nose: a dark seed with a little cap
	var nose := Creature.NOSE + look * 2.0
	draw_colored_polygon(_ellipse_points(nose, Vector2(22, 16), 24), NOSE)
	draw_arc(nose + Vector2(0, -10), 20.0, PI + 0.5, TAU - 0.5, 10, TWIG_LIGHT, 4.0, true)
	draw_circle(nose + Vector2(-7, -4), 5.0, Color(1, 1, 1, 0.35))
	# a thin vine for a mouth, and two pale seeds for teeth
	var mouth := Creature.TEETH + Vector2(0, -18)
	draw_line(nose + Vector2(0, 16), mouth, Color(LINE, 0.8), 3.0, true)
	draw_arc(mouth + Vector2(-15, -2), 15.0, 0.2, PI - 0.6, 10, Color(LINE, 0.8), 3.0, true)
	draw_arc(mouth + Vector2(15, -2), 15.0, 0.6, PI - 0.2, 10, Color(LINE, 0.8), 3.0, true)
	var drop := 6.0 * joy
	for i in range(2):
		var seed := _ellipse_points(mouth + Vector2(-8.5 + float(i) * 17.0, 20.0 + drop), Vector2(8, 17), 18)
		draw_colored_polygon(seed, TOOTH)
		_draw_outline(seed, Color(LINE, 0.8), 2.5)
	if joy > 0.05:
		var h := Vector2(910, 760 - 70.0 * (1.0 - joy))
		_draw_heart(h, 22.0 + 5.0 * sin(t * 9.0), Color(0.93, 0.42, 0.45, clampf(joy * 1.4, 0.0, 1.0)))


func _draw_eye(center: Vector2, look: Vector2, blink: float, joy: float) -> void:
	var r := Creature.EYE_RADIUS
	if joy > 0.6:
		draw_arc(center + Vector2(0, 6), r * 1.1, PI + 0.4, TAU - 0.4, 14, EYE_INK, 5.0, true)   # happy: ^
		return
	var open := clampf(1.0 - blink, 0.08, 1.0)
	if open < 0.2:
		draw_arc(center + Vector2(0, -4), r, 0.3, PI - 0.3, 14, EYE_INK, 4.5, true)
		return
	# a glossy berry: dark, a deep purple sheen, two highlights, a tiny calyx on top
	draw_colored_polygon(_ellipse_points(center, Vector2(r, r * 1.08 * open), 28), EYE_INK)
	draw_colored_polygon(_ellipse_points(center + Vector2(3, 4), Vector2(r * 0.7, r * 0.6 * open), 20), Color(0.30, 0.12, 0.32, 0.5))
	draw_circle(center + Vector2(-6, -6 * open) + look * 2.0, r * 0.32, Color(1, 1, 1, 0.92))
	draw_circle(center + Vector2(6, 7 * open), r * 0.13, Color(1, 1, 1, 0.7))
	for k in range(3):
		var a := -PI * 0.5 + (float(k) - 1.0) * 0.6
		draw_line(center + Vector2(0, -r * open), center + Vector2(0, -r * open) + Vector2(cos(a), sin(a)) * 9.0, Color(LEAF.darkened(0.2), 0.9), 3.0, true)


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40):
		var a := TAU * float(i) / 40.0
		points.append(center + Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * size / 16.0)
	draw_colored_polygon(points, color)


# ------------------------------------------------------------------ helpers
func _draw_fur_strokes(center: Vector2, radii: Vector2, count: int, color: Color) -> void:
	for i in range(count):
		var a := TAU * _deterministic_unit(i * 7 + 1)
		var r := sqrt(_deterministic_unit(i * 11 + 3))
		var p := center + Vector2(cos(a) * radii.x * r, sin(a) * radii.y * r)
		var d := Vector2(0.6, 1.0).normalized().rotated((_deterministic_unit(i * 13 + 5) - 0.5) * 0.8)
		draw_line(p, p + d * (8.0 + 8.0 * _deterministic_unit(i)), color, 2.0, true)


func _clip_to_ellipse(a: Vector2, b: Vector2, radii: Vector2) -> PackedVector2Array:
	var inside := PackedVector2Array()
	for i in range(41):
		var p := a.lerp(b, float(i) / 40.0)
		if (p / radii).length() <= 1.0:
			inside.append(p)
	if inside.size() < 2:
		return PackedVector2Array()
	return PackedVector2Array([inside[0], inside[inside.size() - 1]])


func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		out.append(a.lerp(b, 0.25))
		out.append(a.lerp(b, 0.75))
	return out


func _draw_watercolor_rect(rect: Rect2, indices: Array, colors: Array, offsets: Array) -> void:
	for index in range(mini(indices.size(), colors.size())):
		var texture_index: int = indices[index]
		if texture_index < 0 or texture_index >= pigment_textures.size():
			continue
		var offset: Vector2 = offsets[index] if index < offsets.size() else Vector2.ZERO
		draw_texture_rect(pigment_textures[texture_index], Rect2(rect.position + offset, rect.size), false, colors[index])


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
