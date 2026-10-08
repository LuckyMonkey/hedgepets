extends Node2D

@export var features_only: bool = false
@export var draw_features: bool = false

const INK := Color("293326")
const BODY_GREEN := Color("78985c")
const HEAD_GREEN := Color(0.63, 0.68, 0.36, 1.0)
const BODY_UNDERWASH := Color(0.44, 0.59, 0.29, 1.0)
const TAIL_BROWN := Color("9b7652")
const TOOTH := Color("f9efd3")
const MASK_PATHS := [
	"res://assets/watercolor/mask_00.png",
	"res://assets/watercolor/mask_01.png",
	"res://assets/watercolor/mask_02.png",
	"res://assets/watercolor/mask_03.png",
	"res://assets/watercolor/mask_04.png",
	"res://assets/watercolor/mask_05.png",
	"res://assets/watercolor/mask_06.png",
	"res://assets/watercolor/mask_07.png",
	"res://assets/watercolor/mask_08.png",
	"res://assets/watercolor/mask_09.png",
]

var pigment_textures: Array[Texture2D] = []


func _ready() -> void:
	for path in MASK_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			pigment_textures.append(texture)
	queue_redraw()


func _draw() -> void:
	if features_only:
		_draw_features()
		return

	# Creature geometry stays intentionally crude. The visual upgrade is pigment,
	# not anatomy: flat base wash, translucent mask passes, then ink/features.
	var ground_shadow := _ellipse_points(Vector2(-10, 328), Vector2(420, 34), 40)
	draw_colored_polygon(ground_shadow, Color(0.40, 0.45, 0.33, 0.10))
	_draw_watercolor_rect(Rect2(-430, 286, 740, 82), [6, 9], [Color(0.34, 0.40, 0.27, 0.11), Color(0.47, 0.48, 0.32, 0.08)], [Vector2(-14, 0), Vector2(16, 4)])

	var tail := _ellipse_points(Vector2(-350, 170), Vector2(155, 88), 40)
	draw_colored_polygon(tail, TAIL_BROWN)
	_draw_watercolor_rect(Rect2(-505, 82, 310, 176), [4, 8], [Color(0.38, 0.24, 0.13, 0.25), Color(0.55, 0.33, 0.16, 0.18)], [Vector2(-5, 0), Vector2(8, 5)])
	var tail_ink := Color(INK, 0.34)
	for index in range(5):
		var start_x := -475.0 + float(index) * 46.0
		draw_line(Vector2(start_x, 118.0), Vector2(start_x + 116.0, 224.0), tail_ink, 4.0, true)
		draw_line(Vector2(start_x + 18.0, 222.0), Vector2(start_x + 122.0, 132.0), Color(INK, 0.24), 3.0, true)
	_draw_outline(tail, INK, 12.0)

	var body := _ellipse_points(Vector2(-25, 155), Vector2(330, 188), 56)
	draw_colored_polygon(body, BODY_UNDERWASH)
	_draw_watercolor_rect(
		Rect2(-355, -33, 660, 376),
		[0, 2, 5, 8, 7, 3],
		[Color(0.25, 0.42, 0.15, 0.48), Color(0.48, 0.62, 0.25, 0.40), Color(0.20, 0.34, 0.14, 0.32), Color(0.67, 0.70, 0.34, 0.24), Color(0.15, 0.28, 0.10, 0.22), Color(0.56, 0.66, 0.25, 0.28)],
		[Vector2(-12, 4), Vector2(18, -8), Vector2(2, 10), Vector2(-20, 0), Vector2(14, 12), Vector2(-5, -12)]
	)
	# Smaller overlapping washes keep the broad mass irregular instead of one
	# uniformly tinted oval. They stay inside the crude silhouette.
	_draw_watercolor_rect(Rect2(-292, 28, 270, 224), [1, 7], [Color(0.53, 0.68, 0.28, 0.24), Color(0.17, 0.31, 0.11, 0.18)], [Vector2(-6, 2), Vector2(10, -4)])
	_draw_watercolor_rect(Rect2(-72, -8, 282, 232), [3, 6], [Color(0.64, 0.72, 0.32, 0.20), Color(0.24, 0.40, 0.13, 0.22)], [Vector2(4, 9), Vector2(-10, 3)])
	_draw_watercolor_rect(Rect2(-250, 184, 430, 126), [8, 5], [Color(0.14, 0.27, 0.09, 0.20), Color(0.38, 0.52, 0.18, 0.24)], [Vector2(4, -2), Vector2(-12, 5)])
	_draw_painterly_blooms(Vector2(-50, 145), Vector2(288, 154), [
		Color(0.69, 0.74, 0.36, 0.15), Color(0.17, 0.32, 0.11, 0.15),
		Color(0.37, 0.53, 0.18, 0.13), Color(0.78, 0.73, 0.34, 0.10)
	], 40)
	_draw_painterly_blooms(Vector2(32, 170), Vector2(246, 122), [
		Color(0.24, 0.40, 0.13, 0.08), Color(0.72, 0.76, 0.34, 0.09),
		Color(0.12, 0.25, 0.08, 0.07), Color(0.48, 0.61, 0.21, 0.08)
	], 140)
	_draw_wash_bouquet(Vector2(-24, 148), Vector2(284, 156), 180, 18, [
		Color(0.16, 0.31, 0.10, 0.075), Color(0.56, 0.68, 0.25, 0.085),
		Color(0.28, 0.46, 0.14, 0.070), Color(0.76, 0.72, 0.31, 0.060)
	])
	_draw_outline(body, INK, 12.0)

	var head := _ellipse_points(Vector2(255, 18), Vector2(184, 150), 48)
	draw_colored_polygon(head, HEAD_GREEN)
	_draw_watercolor_rect(
		Rect2(71, -132, 368, 300),
		[1, 6, 9, 2],
		[Color(0.30, 0.47, 0.18, 0.38), Color(0.61, 0.68, 0.31, 0.32), Color(0.21, 0.35, 0.12, 0.24), Color(0.75, 0.73, 0.36, 0.16)],
		[Vector2(8, 0), Vector2(-12, 5), Vector2(4, -8), Vector2(16, 8)]
	)
	_draw_painterly_blooms(Vector2(258, 10), Vector2(154, 124), [
		Color(0.82, 0.77, 0.39, 0.15), Color(0.28, 0.44, 0.15, 0.14),
		Color(0.52, 0.61, 0.22, 0.12), Color(0.92, 0.80, 0.42, 0.08)
	], 90)
	_draw_wash_bouquet(Vector2(292, 20), Vector2(150, 116), 240, 8, [
		Color(0.91, 0.76, 0.36, 0.065), Color(0.44, 0.56, 0.18, 0.070),
		Color(0.72, 0.68, 0.28, 0.055)
	])
	# A small paper-colored clearing leaves negative space for the simple face.
	draw_colored_polygon(_ellipse_points(Vector2(292, 24), Vector2(116, 92), 40), Color(0.96, 0.93, 0.85, 0.34))
	draw_colored_polygon(_ellipse_points(Vector2(318, 40), Vector2(82, 66), 32), Color(0.91, 0.76, 0.42, 0.09))
	draw_colored_polygon(_ellipse_points(Vector2(344, 66), Vector2(54, 36), 28), Color(0.83, 0.54, 0.25, 0.11))
	_draw_outline(head, INK, 12.0)
	_draw_ears()

	if not draw_features:
		return

	# Simple ears, eye, nose, and the two characteristic front teeth.
	_draw_features()


func _draw_features() -> void:
	# Eye, nose, and the two characteristic front teeth remain top-priority ink.
	draw_circle(Vector2(302, 0), 18.0, INK)
	draw_circle(Vector2(296, -6), 5.0, Color(0.98, 0.97, 0.84, 0.96))
	var nose_color := Color(0.16, 0.105, 0.075, 1.0)
	draw_circle(Vector2(414, 45), 18.0, nose_color)
	draw_circle(Vector2(409, 39), 4.0, Color(0.84, 0.70, 0.48, 0.58))
	draw_line(Vector2(411, 62), Vector2(398, 76), INK, 7.0, true)
	draw_line(Vector2(411, 62), Vector2(438, 76), INK, 7.0, true)
	draw_circle(Vector2(380, 91), 3.0, Color(0.25, 0.18, 0.11, 0.68))
	draw_circle(Vector2(390, 95), 2.5, Color(0.25, 0.18, 0.11, 0.52))

	draw_rect(Rect2(365, 104, 35, 67), TOOTH)
	draw_rect(Rect2(407, 101, 35, 70), TOOTH)
	draw_rect(Rect2(393, 108, 7, 61), Color(0.80, 0.68, 0.47, 0.20))
	draw_rect(Rect2(435, 105, 7, 64), Color(0.80, 0.68, 0.47, 0.20))
	draw_rect(Rect2(365, 104, 35, 67), INK, false, 6.0)
	draw_rect(Rect2(407, 101, 35, 70), INK, false, 6.0)
	draw_line(Vector2(334, 91), Vector2(375, 102), INK, 7.0, true)
	draw_line(Vector2(334, 100), Vector2(373, 115), INK, 5.0, true)


func _draw_ears() -> void:
	draw_circle(Vector2(165, -70), 38.0, HEAD_GREEN)
	draw_circle(Vector2(165, -70), 14.0, Color(0.46, 0.29, 0.17, 0.62))
	draw_arc(Vector2(165, -70), 38.0, 0.0, TAU, 28, INK, 8.0, true)
	draw_circle(Vector2(328, -57), 34.0, HEAD_GREEN)


func _draw_watercolor_rect(rect: Rect2, indices: Array, colors: Array, offsets: Array) -> void:
	for index in range(mini(indices.size(), colors.size())):
		var texture_index: int = indices[index]
		if texture_index < 0 or texture_index >= pigment_textures.size():
			continue
		var offset: Vector2 = offsets[index] if index < offsets.size() else Vector2.ZERO
		var scale := 1.0 + 0.018 * float(index % 2)
		var painted_rect := Rect2(rect.position + offset, rect.size * scale)
		draw_texture_rect(pigment_textures[texture_index], painted_rect, false, colors[index])


func _draw_painterly_blooms(center: Vector2, radii: Vector2, colors: Array[Color], seed: int) -> void:
	# A few irregular, overlapping pigment blooms break up the large wash. They
	# are deliberately low alpha: the paper remains visible between layers.
	for index in range(colors.size()):
		var ratio := 0.48 + _deterministic_unit(seed + index * 17) * 0.44
		var bloom_center := center + Vector2(
			(_deterministic_unit(seed + index * 23 + 1) - 0.5) * radii.x * 1.25,
			(_deterministic_unit(seed + index * 23 + 2) - 0.5) * radii.y * 1.18
		)
		var bloom_radii := Vector2(
			radii.x * (0.16 + ratio * 0.16),
			radii.y * (0.15 + ratio * 0.15)
		)
		draw_colored_polygon(_irregular_blob(bloom_center, bloom_radii, seed + index * 101), colors[index])


func _draw_wash_bouquet(center: Vector2, radii: Vector2, seed: int, count: int, colors: Array[Color]) -> void:
	# Many very quiet, irregular blooms create a soft accumulated mass. They
	# stay below the ink vocabulary so the character remains readable.
	for index in range(count):
		var phase := seed + index * 37
		var bloom_center := center + Vector2(
			(_deterministic_unit(phase + 1) - 0.5) * radii.x * 1.35,
			(_deterministic_unit(phase + 2) - 0.5) * radii.y * 1.22
		)
		var bloom_radii := Vector2(
			radii.x * (0.09 + _deterministic_unit(phase + 3) * 0.11),
			radii.y * (0.08 + _deterministic_unit(phase + 4) * 0.10)
		)
		var pigment := colors[posmod(index, colors.size())]
		pigment.a *= 0.70 + _deterministic_unit(phase + 5) * 0.40
		draw_colored_polygon(_irregular_blob(bloom_center, bloom_radii, phase, 16), pigment)


func _irregular_blob(center: Vector2, radii: Vector2, seed: int, segments: int = 18) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		var wobble := 0.88 + 0.12 * sin(float(seed + index * 13) * 1.71)
		wobble += 0.05 * sin(float(seed + index * 7) * 0.43)
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
