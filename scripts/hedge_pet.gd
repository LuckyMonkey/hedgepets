extends Node2D

## The HedgePet itself - a beaver grown over with ivy - in two layers (the same script, two nodes):
##   base      (features_only = false) - tail, far feet, fur masses and shading, under the leaves
##   features  (features_only = true)  - the face and the near feet on top, redrawn every frame from the life state
## Drawn in viewport pixels: the parent Pet node offsets its children so that (0, 0) here is the canvas top-left.

@export var features_only: bool = false
@export var draw_features: bool = false   # kept for old scenes; the features node draws the face

const Creature = preload("res://scripts/creature_definition.gd")

const LINE := Color("3b2a1c")              # dark brown ink for fur, tail, face
const FUR_DEEP := Color("4f4a26")          # the body under the ivy: dark, so gaps read as shade
const FUR := Color("8a7342")
const MUZZLE := Color("d9bf8a")
const TAIL := Color("7a5134")
const TAIL_DARK := Color("4f321f")
const FOOT := Color("6b4529")
const EYE_INK := Color("1d1612")
const NOSE := Color("3a2418")
const TOOTH := Color("f7ecd0")
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
	# the body: dark fur under the ivy, rounded by light from the upper left
	var body := _ellipse_points(Creature.BODY_CENTER, Creature.BODY_RADII, 64)
	draw_colored_polygon(body, FUR_DEEP)
	_draw_watercolor_rect(Rect2(Creature.BODY_CENTER - Creature.BODY_RADII, Creature.BODY_RADII * 2.0), [2, 7],
		[Color(0.42, 0.40, 0.18, 0.35), Color(0.30, 0.36, 0.14, 0.30)], [Vector2(-8, 4), Vector2(10, -6)])
	_shade_sphere(Creature.BODY_CENTER, Creature.BODY_RADII, 1.0)
	# the head: tan fur, a lighter muzzle at the front
	var head := _ellipse_points(Creature.HEAD_CENTER, Creature.HEAD_RADII, 56)
	draw_colored_polygon(head, FUR)
	_draw_watercolor_rect(Rect2(Creature.HEAD_CENTER - Creature.HEAD_RADII, Creature.HEAD_RADII * 2.0), [1, 6],
		[Color(0.60, 0.48, 0.26, 0.35), Color(0.42, 0.34, 0.18, 0.25)], [Vector2(6, 0), Vector2(-10, 6)])
	draw_colored_polygon(_ellipse_points(Vector2(918, 968), Vector2(84, 66), 40), MUZZLE)
	draw_colored_polygon(_ellipse_points(Vector2(908, 958), Vector2(56, 42), 32), Color(0.95, 0.87, 0.68, 0.6))
	_draw_fur_strokes(Creature.HEAD_CENTER + Vector2(40, 30), Vector2(130, 100), 70, Color(LINE, 0.22))
	_shade_sphere(Creature.HEAD_CENTER, Creature.HEAD_RADII, 0.8)
	_draw_outline(head, Color(LINE, 0.55), 5.0)
	# the ear, peeking out of the ivy
	draw_circle(Creature.EAR, 40.0, FUR)
	draw_circle(Creature.EAR + Vector2(4, 4), 22.0, Color("5e4226"))
	draw_arc(Creature.EAR, 40.0, 0.0, TAU, 32, LINE, 5.0, true)


func _draw_tail() -> void:
	# the flat paddle tail with its crosshatch, tucked behind the body
	var turn := -0.18
	var points := PackedVector2Array()
	for p in _ellipse_points(Vector2.ZERO, Creature.TAIL_RADII, 48):
		points.append(Creature.TAIL_CENTER + p.rotated(turn))
	draw_colored_polygon(points, TAIL)
	_shade_sphere(Creature.TAIL_CENTER, Creature.TAIL_RADII * 0.95, 0.7)
	for i in range(-6, 7):
		for dir: float in [1.0, -1.0]:
			var a := Vector2(float(i) * 34.0 - 120.0 * dir, -130.0)
			var b := Vector2(float(i) * 34.0 + 120.0 * dir, 130.0)
			var seg := _clip_to_ellipse(a, b, Creature.TAIL_RADII * 0.9)
			if seg.size() == 2:
				draw_line(Creature.TAIL_CENTER + seg[0].rotated(turn), Creature.TAIL_CENTER + seg[1].rotated(turn), Color(TAIL_DARK, 0.6), 3.0, true)
	_draw_outline(points, LINE, 6.0)


func _draw_foot(center: Vector2, size: float, far: bool) -> void:
	var color := FOOT.darkened(0.25) if far else FOOT
	var foot := _ellipse_points(center, Vector2(52, 26) * size, 28)
	draw_colored_polygon(foot, color)
	for t: float in [-1.0, 0.0, 1.0]:   # toes
		draw_circle(center + Vector2(34.0 + t * 4.0, 8.0 + t * 12.0) * size, 11.0 * size, color.lightened(0.08))
	_draw_outline(foot, Color(LINE, 0.8), 4.0)
	for t: float in [-1.0, 0.0, 1.0]:
		draw_line(center + Vector2(18.0, 4.0 + t * 10.0) * size, center + Vector2(40.0, 8.0 + t * 12.0) * size, Color(LINE, 0.7), 2.5, true)


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
	draw_colored_polygon(_ellipse_points(Vector2(872, 960), Vector2(30, 18), 20), Color(BLUSH, BLUSH.a + 0.3 * joy))
	_draw_eye(Creature.EYE + look * Vector2(5, 4), look, float(life["blink"]), joy)
	var nose := Creature.NOSE + look * 2.0
	var nose_shape := PackedVector2Array([nose + Vector2(-26, -12), nose + Vector2(22, -16), nose + Vector2(26, 6), nose + Vector2(2, 20), nose + Vector2(-22, 8)])
	draw_colored_polygon(_smooth(nose_shape), NOSE)
	draw_circle(nose + Vector2(-6, -7), 6.0, Color(1, 1, 1, 0.35))
	var mouth := Creature.TEETH + Vector2(0, -18)
	draw_line(nose + Vector2(0, 20), mouth, Color(LINE, 0.8), 4.0, true)
	draw_arc(mouth + Vector2(-16, -2), 16.0, 0.2, PI - 0.6, 10, Color(LINE, 0.8), 4.0, true)
	draw_arc(mouth + Vector2(16, -2), 16.0, 0.6, PI - 0.2, 10, Color(LINE, 0.8), 4.0, true)
	var drop := 6.0 * joy
	for i in range(2):
		var r := Rect2(mouth + Vector2(-17.0 + float(i) * 17.0, 2.0 + drop), Vector2(16, 34))
		draw_rect(r, TOOTH)
		draw_rect(r, LINE, false, 3.0)
	for p: Vector2 in [Vector2(-34, -8), Vector2(-26, 4), Vector2(-40, 6)]:
		draw_circle(nose + p + Vector2(0, 26), 2.5, Color(LINE, 0.5))
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
	draw_colored_polygon(_ellipse_points(center, Vector2(r, r * 1.12 * open), 28), EYE_INK)
	draw_circle(center + Vector2(-5, -6 * open) + look * 2.0, r * 0.36, Color(1, 1, 1, 0.92))
	draw_circle(center + Vector2(5, 6 * open), r * 0.15, Color(1, 1, 1, 0.7))


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
