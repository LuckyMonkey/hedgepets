extends Node2D

const HedgeGlyph = preload("res://scripts/hedge_glyphs.gd")
const Creature = preload("res://scripts/creature_definition.gd")

@export_range(0.0, 1.0, 0.01) var growth: float = 0.78
@export_range(0.0, 190.0, 1.0) var amplitude: float = 96.0
@export_range(0.3, 2.5, 0.01) var frequency: float = 1.05
@export_range(24.0, 120.0, 1.0) var leaf_spacing: float = 68.0
@export_range(0.0, 1.0, 0.01) var overflow: float = 0.68
@export_range(5, 9, 1) var shoot_count: int = 7
@export var profile_id: String = "ivy"

const PROFILE_CATALOG_PATH := "res://assets/plants/plant_profiles.json"
const BODY_CENTER := Creature.BODY_CENTER
const PET_SEED := 1977
const INK := Color("293326")
const STEM_SHADOW := Color(0.15, 0.24, 0.11, 0.14)
const STEM_INK := Color("426633")
const SHOOT_ORIGINS := [
	Vector2(350.0, 1060.0),
	Vector2(420.0, 875.0),
	Vector2(535.0, 820.0),
	Vector2(660.0, 845.0),
	Vector2(800.0, 920.0),
	Vector2(785.0, 1065.0),
	Vector2(485.0, 1180.0),
	Vector2(690.0, 1140.0),
	Vector2(585.0, 900.0),
]
const SHOOT_LENGTHS := [360.0, 350.0, 430.0, 400.0, 380.0, 315.0, 300.0, 285.0, 325.0]
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
const OCCUPANCY_COLUMNS := 36
const OCCUPANCY_ROWS := 40
const COMPOSITION_BOUNDS := Rect2(35.0, 360.0, 1010.0, 1120.0)
const DETAIL_BUDGET_MAX := 1800.0

var profiles: Array[PlantProfile] = []
var profile: PlantProfile
var profile_index := 0
var leaf_font: Font
var glyph_geometry: Array = []
var mask_images: Array[Image] = []
var mask_textures: Array[Texture2D] = []
var current_shoot_paths: Array = []
var composition_marks: Array[Dictionary] = []
var occupancy: Array[float] = []
var collecting_marks := false
var remaining_detail_budget := 0.0


func _ready() -> void:
	profiles = PlantProfile.load_catalog(PROFILE_CATALOG_PATH)
	_load_masks()
	_bind_plant_selector()
	_select_profile_by_id(profile_id)
	queue_redraw()


const SPRITE_CELL := 160
var leaf_sheet: Texture2D = null
var cached_lines: Array = []       # [a, b, color, width] stems, branches and rim stalks
var _built_signature := ""
var _time := 0.0
var _frame_accumulator := 0.0
const LIGHT := Vector3(-0.52, -0.62, 0.59)   # from the upper left, toward the viewer


func _process(delta: float) -> void:
	_time += delta
	_frame_accumulator += delta
	if _frame_accumulator >= 1.0 / 30.0:   # leaves rustle at 30 fps; that is plenty, and cheap
		_frame_accumulator = 0.0
		queue_redraw()


func _draw() -> void:
	if profile == null:
		return
	var signature := "%s|%s|%s|%s|%s|%s|%s" % [growth, amplitude, frequency, leaf_spacing, overflow, shoot_count, profile_index]
	if signature != _built_signature:
		_build()
		_built_signature = signature
	for line in cached_lines:
		draw_line(line[0], line[1], line[2], line[3], true)
	var gust := _life_value("gust")
	for mark in composition_marks:
		_paint_hedge_glyph(mark, gust)


## The composition: where every stem and leaf goes. Runs only when a setting changes.
func _build() -> void:
	current_shoot_paths.clear()
	composition_marks.clear()
	cached_lines.clear()
	occupancy.clear()
	remaining_detail_budget = lerpf(36.0, DETAIL_BUDGET_MAX, growth)
	for index in range(OCCUPANCY_COLUMNS * OCCUPANCY_ROWS):
		occupancy.append(0.0)
	var count := mini(shoot_count, mini(profile.primary_shoot_count, SHOOT_ORIGINS.size()))
	for shoot_id in range(count):
		var path := _make_shoot_path(shoot_id)
		if not path.is_empty():
			current_shoot_paths.append({"id": shoot_id, "points": path})
	# Paint-stack order: invisible curves inform composition, selected stem
	# fragments sit behind foliage, then accepted marks are depth-sorted.
	for shoot in current_shoot_paths:
		_draw_stem_fragments(shoot["id"], shoot["points"])
	collecting_marks = true
	_draw_crown_foliage()
	_draw_major_canopy_clusters()
	_draw_canopy_mass()
	_draw_interior_botanical_texture()
	for shoot in current_shoot_paths:
		_draw_structural_marks(shoot["id"], shoot["points"])
	_draw_accent_flowers()
	_draw_silhouette_foliage()
	collecting_marks = false
	_draw_tendrils()
	composition_marks.sort_custom(Callable(self, "_sort_marks"))
	for mark in composition_marks:
		_light_mark(mark)
		_prepare_mark(mark)


## The ivy cover: big shingled leaves over the whole body and the back of the head, pointing out and a little up,
## parting round the face. Rim leaves are the fullest and catch the most wind (hedgepetsGoal.jpg).
func _draw_crown_foliage() -> void:
	var masses := [[Creature.BODY_CENTER, Creature.BODY_RADII, 340.0], [Creature.HEAD_CENTER, Creature.HEAD_RADII, 60.0]]
	var rng := RandomNumberGenerator.new()   # a real generator: a sine hash over consecutive keys lays leaves on a spiral
	rng.seed = PET_SEED * 31 + 7
	for m_index in range(masses.size()):
		var center: Vector2 = masses[m_index][0]
		var radii: Vector2 = masses[m_index][1]
		var count := int(float(masses[m_index][2]) * growth * clampf(profile.interior_density + 0.3, 0.6, 1.4))
		for index in range(count):
			var key := 9100 + m_index * 5000 + index * 37
			var angle := rng.randf() * TAU
			var r := pow(rng.randf(), 0.55) * 1.02
			var point := center + Vector2(cos(angle) * radii.x * r, sin(angle) * radii.y * r)
			if point.y > Creature.FEET_Y - 40.0:
				continue
			var face_factor := _face_clear_factor(point)
			if face_factor < (0.32 if m_index == 0 else 0.55):
				continue
			var outward := (point - center).normalized()
			var tangent := outward.lerp(Vector2.UP, 0.35).normalized().rotated((rng.randf() - 0.5) * 1.0)
			var glyph_index: int = rng.randi_range(0, 7)
			if rng.randf() < 0.035 * (1.0 + profile.flower_probability * 6.0):
				glyph_index = 13
			var size := lerpf(52.0, 84.0, rng.randf()) * (1.06 if r > 0.85 else 1.0)
			var side := -1.0 if index % 2 == 0 else 1.0
			var depth := 3 if r > 0.86 else 2
			_draw_hedge_glyph(point, tangent, side, glyph_index, size, key, (rng.randf() - 0.5) * 0.5, 1.05 * face_factor, false, depth)


## Ivy tendrils: little curls where the vines run off the edge.
func _draw_tendrils() -> void:
	for shoot in current_shoot_paths:
		var points: PackedVector2Array = shoot["points"]
		if points.size() < 3:
			continue
		var end := points[points.size() - 1]
		if _creature_sdf(end) < 0.0:
			continue
		var dir := (end - points[points.size() - 2]).normalized()
		var curl := PackedVector2Array([end])
		var turn := 1.0 if int(shoot["id"]) % 2 == 0 else -1.0
		for i in range(1, 22):
			var t := float(i) / 21.0
			dir = dir.rotated(turn * (0.18 + t * 0.32))
			curl.append(curl[curl.size() - 1] + dir * (7.0 - t * 4.0))
		for i in range(curl.size() - 1):
			_line(curl[i], curl[i + 1], Color(STEM_INK, 0.75), 3.0)


func _line(a: Vector2, b: Vector2, color: Color, width: float, _antialiased: bool = true) -> void:
	cached_lines.append([a, b, color, width])


func _life_value(key: String) -> float:
	var pet := get_parent()
	if pet != null and pet.has_method("life_state"):
		return float(pet.life_state().get(key, 0.0))
	return 0.0


## Each leaf sits on a round mass: light it by where it faces, and foreshorten the ones turning away at the rim.
func _light_mark(mark: Dictionary) -> void:
	var center: Vector2 = mark["center"]
	var c := _mass_center(center)
	var radii := Creature.HEAD_RADII if c == Creature.HEAD_CENTER else Creature.BODY_RADII
	var n2 := (center - c) / radii
	var r := minf(n2.length(), 1.0)
	var nz := sqrt(maxf(0.0, 1.0 - r * r))
	var n3 := Vector3(n2.x, n2.y, nz).normalized() if n2.length() > 0.001 else Vector3(0, 0, 1)
	var lambert := n3.dot(LIGHT.normalized())
	mark["light"] = clampf(0.62 + 0.5 * lambert, 0.32, 1.12)
	mark["turn"] = lerpf(0.58, 1.0, nz)              # rim leaves face away: thinner across
	mark["radial"] = n2.angle() if n2.length() > 0.001 else 0.0
	mark["rim"] = smoothstep(0.55, 1.05, r)          # rim leaves catch more wind
	mark["phase"] = _deterministic_unit(int(mark["mask_key"]) * 7 + 3) * TAU


func _make_shoot_path(shoot_id: int) -> PackedVector2Array:
	var full_length: float = SHOOT_LENGTHS[shoot_id] * _habit_length_scale()
	var visible_t := _shoot_extent_fraction(shoot_id) * growth
	var visible_length := full_length * visible_t
	if visible_length < 2.0:
		return PackedVector2Array()
	var path := PackedVector2Array()
	var point_count := clampi(int(visible_length / 22.0) + 2, 2, 24)
	for index in range(point_count):
		var t := visible_t * float(index) / float(point_count - 1)
		path.append(_shoot_point(shoot_id, t, full_length))
	return path


func _draw_stem_fragments(shoot_id: int, points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	for index in range(points.size() - 1):
		var a := points[index]
		var b := points[index + 1]
		var midpoint := (a + b) * 0.5
		var distance := _creature_sdf(midpoint)
		var outside := distance > 0.0
		var reveal := _deterministic_unit(shoot_id * 401 + index * 17 + 19)
		var visible_threshold := 0.78 if not outside else 0.30
		if reveal < visible_threshold:
			continue
		var shadow := STEM_SHADOW
		shadow.a = 0.025 if not outside else 0.06
		_line(a, b, shadow, 9.0 if not outside else 11.0, true)
		var stem_color := STEM_INK
		stem_color.a = (0.075 + 0.04 * overflow) if not outside else (0.20 + 0.12 * overflow)
		_line(a, b, stem_color, 3.0 if not outside else 4.0, true)


func _draw_canopy_mass() -> void:
	# A broad middle scale: a few overlapping glyphs imply the many leaves
	# inside the watercolor wash without turning the renderer into a particle
	# system. These are deliberately stemless and deterministic.
	var total := int(170.0 * profile.interior_density * growth)
	for index in range(total):
		var sample := _interior_sample(index + 4000)
		var point: Vector2 = sample[0]
		var face_factor := _face_clear_factor(point)
		var key := 5000 + index * 29
		var regional_density := _regional_density(point, key)
		if face_factor <= 0.18 or _deterministic_unit(index * 17 + 4101) > face_factor * regional_density:
			continue
		var flow := _interior_flow(point)
		var side := -1.0 if index % 2 == 0 else 1.0
		var glyph_index: int = int([0, 1, 2, 3, 4, 5][posmod(index + 2, 6)])
		var size := lerpf(38.0, 62.0, _deterministic_unit(key))
		var center := point + Vector2(_deterministic_unit(key + 1) - 0.5, _deterministic_unit(key + 2) - 0.5) * 12.0
		_draw_hedge_glyph(center, flow, side, glyph_index, size, key, (_deterministic_unit(key + 3) - 0.5) * 0.7, 1.08 * face_factor, true, 0)


func _draw_major_canopy_clusters() -> void:
	# Authored composition points keep the back, shoulder, and crown visually
	# important. They are not a new asset system; they are the illustrator's
	# handful of deliberate large gestures.
	var anchors := [
		Vector2(320.0, 970.0), Vector2(392.0, 900.0), Vector2(490.0, 858.0),
		Vector2(590.0, 872.0), Vector2(676.0, 902.0), Vector2(728.0, 832.0),
		Vector2(792.0, 812.0), Vector2(368.0, 1082.0), Vector2(486.0, 1142.0),
		Vector2(630.0, 1152.0), Vector2(748.0, 1088.0),
		Vector2(410.0, 1018.0), Vector2(520.0, 982.0), Vector2(620.0, 1016.0),
		Vector2(694.0, 964.0), Vector2(570.0, 1106.0), Vector2(458.0, 1102.0),
	]
	for index in range(anchors.size()):
		if _deterministic_unit(8300 + index * 31) < 0.12:
			continue
		var center: Vector2 = Creature.remap_legacy(anchors[index])
		var face_factor := _face_clear_factor(center)
		if face_factor < 0.35:
			continue
		var key := 8300 + index * 47
		var tangent := _interior_flow(center)
		var side := -1.0 if index % 2 == 0 else 1.0
		var glyph_index := 5 if index % 3 != 0 else 7
		var size := 54.0 + _deterministic_unit(key + 5) * 24.0
		_draw_hedge_glyph(center, tangent, side, glyph_index, size, key, (_deterministic_unit(key + 9) - 0.5) * 0.30, 1.12 * face_factor, false, 2)
		if index % 4 == 1:
			_draw_cluster(center + tangent * 14.0, tangent, -side, size * 0.66, key + 93)


func _draw_structural_marks(shoot_id: int, points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	var full_length: float = SHOOT_LENGTHS[shoot_id] * _habit_length_scale()
	var spacing := _profile_leaf_spacing()
	var visible_length := full_length * _shoot_extent_fraction(shoot_id) * growth
	var leaf_count := clampi(int(visible_length / spacing), 1, 12)
	for leaf_index in range(leaf_count):
		var distance := minf(30.0 + float(leaf_index) * spacing, visible_length - 8.0)
		if distance <= 0.0:
			continue
		var t := distance / full_length
		var point := _shoot_point(shoot_id, t, full_length)
		var tangent := _shoot_tangent(shoot_id, t, full_length)
		var normal := Vector2(-tangent.y, tangent.x)
		var side := -1.0 if (leaf_index + shoot_id) % 2 == 0 else 1.0
		var key := shoot_id * 101 + leaf_index * 17
		var jitter := _deterministic_unit(key) - 0.5
		var reach := 12.0 + _profile_overflow() * 62.0
		var leaf_center := point + normal * side * reach * (0.82 + _deterministic_unit(key + 31) * 0.30)
		var leaf_size := lerpf(profile.leaf_scale_range.x, profile.leaf_scale_range.y, _deterministic_unit(key + 9))
		var event_roll := _deterministic_unit(key + 57)
		var glyph_index := _choose_structural_glyph(event_roll, key)
		var face_factor := _face_clear_factor(leaf_center)
		if face_factor < 0.24 or _creature_sdf(leaf_center) < -36.0:
			continue
		_draw_hedge_glyph(leaf_center, tangent, side, glyph_index, leaf_size, key, jitter, lerpf(0.62, 1.0, face_factor), false, 2)

		if event_roll < profile.cluster_probability:
			_draw_cluster(leaf_center, tangent, side, leaf_size * 0.84, key + 3)
		if event_roll > 0.55 and profile.flower_probability > _deterministic_unit(key + 63):
			_draw_hedge_glyph(leaf_center + normal * side * 14.0, tangent, side, 13, leaf_size * 0.78, key + 11, jitter, 1.15, true, 4)

		if profile.branch_depth > 0 and profile.branch_probability > _deterministic_unit(key + 88) and leaf_index == int(leaf_count * 0.55):
			_draw_branch(shoot_id, point, tangent, leaf_index, key)


func _draw_accent_flowers() -> void:
	if growth < 0.42:
		return
	var positions := [
		Vector2(420.0, 982.0), Vector2(548.0, 930.0), Vector2(628.0, 1115.0),
		Vector2(716.0, 842.0), Vector2(760.0, 1045.0), Vector2(340.0, 1105.0),
	]
	var flower_count := clampi(3 + int(profile.flower_probability * 18.0), 3, positions.size())
	for index in range(flower_count):
		var point: Vector2 = Creature.remap_legacy(positions[index])
		var face_factor := _face_clear_factor(point)
		if face_factor < 0.35:
			continue
		var key := 7200 + index * 41
		var tangent := _interior_flow(point)
		var jitter := (_deterministic_unit(key) - 0.5) * 0.22
		_draw_hedge_glyph(point, tangent, 1.0, 13, 50.0 + _deterministic_unit(key + 2) * 16.0, key, jitter, 1.18 * face_factor, false, 4)


func _draw_cluster(center: Vector2, tangent: Vector2, side: float, size: float, key: int) -> void:
	var normal := Vector2(-tangent.y, tangent.x)
	var first := center + normal * side * 20.0
	var second := center - tangent * 13.0 - normal * side * 16.0
	_draw_hedge_glyph(first, tangent.rotated(side * 0.18), side, 5, size, key, 0.0, 0.92, false, 2)
	_draw_hedge_glyph(second, tangent.rotated(-side * 0.24), -side, 6, size * 0.90, key + 1, 0.0, 0.88, false, 2)


func _draw_branch(shoot_id: int, origin: Vector2, tangent: Vector2, branch_index: int, key: int) -> void:
	var direction := tangent.rotated(-0.72 + (_deterministic_unit(shoot_id + 71) - 0.5) * 0.25)
	var points := PackedVector2Array([origin, origin + direction * 52.0, origin + direction * 94.0])
	var branch_color := STEM_INK
	branch_color.a = 0.18 + 0.16 * _profile_overflow()
	for segment_index in range(points.size() - 1):
		var branch_midpoint := (points[segment_index] + points[segment_index + 1]) * 0.5
		if _creature_sdf(branch_midpoint) < -24.0 and _deterministic_unit(key + segment_index * 13) < 0.68:
			continue
		_line(points[segment_index], points[segment_index + 1], branch_color, 3.0, true)
	var normal := Vector2(-direction.y, direction.x)
	for index in range(2):
		var branch_point := points[index + 1]
		var branch_side := -1.0 if index == 0 else 1.0
		_draw_hedge_glyph(branch_point + normal * branch_side * 23.0, direction, branch_side, 5 + index, 30.0, key + index, 0.0, 1.0, false, 2)


func _draw_silhouette_foliage() -> void:
	if growth < 0.35:
		return
	var anchors := [
		Vector2(205, 955), Vector2(220, 1090), Vector2(260, 1195), Vector2(365, 1245),
		Vector2(500, 1260), Vector2(635, 1255), Vector2(760, 1210), Vector2(850, 1145),
		Vector2(930, 1075), Vector2(1000, 1000), Vector2(1008, 900), Vector2(970, 815),
		Vector2(865, 770), Vector2(735, 755), Vector2(590, 775), Vector2(445, 790),
		Vector2(315, 825), Vector2(245, 885),
	]
	for index in range(anchors.size()):
		if _deterministic_unit(index * 43 + 9) > 0.62:
			continue
		var anchor: Vector2 = Creature.remap_legacy(anchors[index])
		var outward := (anchor - _mass_center(anchor)).normalized()
		var tangent := Vector2(-outward.y, outward.x)
		var key := 600 + index * 31
		var offset := outward * (6.0 + _profile_overflow() * (25.0 + _deterministic_unit(key) * 35.0))
		var event_roll := _deterministic_unit(key + 7)
		var glyph_index: int = 5 if event_roll < profile.cluster_probability else _choose_structural_glyph(event_roll, key)
		var center := anchor + offset
		var size := lerpf(profile.leaf_scale_range.x, profile.leaf_scale_range.y, _deterministic_unit(key + 4)) * 0.92
		if _face_clear_factor(center) < 0.20:
			continue
		# A second, quieter mark just inside the boundary makes the watercolor
		# mass transition into foliage instead of ending as a perfect oval.
		if index % 3 != 1:
			var inner_center := anchor - outward * (16.0 + _deterministic_unit(key + 18) * 14.0)
			var inner_glyph := 5 if index % 2 == 0 else 7
			_draw_hedge_glyph(inner_center, tangent, -1.0, inner_glyph, size * 0.74, key + 19, 0.0, 0.72, true, 1)
		_line(anchor - outward * 8.0, center, Color(STEM_INK, 0.30), 3.0, true)
		_draw_hedge_glyph(center, outward, 1.0, glyph_index, size, key, 0.0, 1.15, false, 3)
		if event_roll > 0.72:
			_draw_hedge_glyph(center + tangent * 22.0 - outward * 5.0, outward.rotated(0.20), -1.0, 12, size * 0.62, key + 4, 0.0, 1.0, true, 3)


func _draw_interior_botanical_texture() -> void:
	var total := int(400.0 * profile.interior_density * growth)
	for index in range(total):
		var sample := _interior_sample(index)
		var point: Vector2 = sample[0]
		var face_factor := _face_clear_factor(point)
		var key := 1000 + index * 23
		var regional_density := _regional_density(point, key)
		if face_factor <= 0.06 or _deterministic_unit(index * 19 + 7) > face_factor * regional_density:
			continue
		var flow := _interior_flow(point)
		var side := -1.0 if index % 2 == 0 else 1.0
		var glyph_index: int = int([0, 1, 2, 3, 4, 5, 6][posmod(index + int(profile.interior_density * 10.0), 7)])
		var size := lerpf(28.0, 50.0, _deterministic_unit(key))
		var center := point + Vector2(_deterministic_unit(key + 1) - 0.5, _deterministic_unit(key + 2) - 0.5) * 9.0
		_draw_hedge_glyph(center, flow, side, glyph_index, size, key, (_deterministic_unit(key + 3) - 0.5) * 0.9, 1.05 * face_factor, true, 1)


func _interior_sample(index: int) -> Array:
	var head := index % 5 == 0
	# the head is the bigger mass now, so it gets most of the interior leaves
	head = index % 5 != 0
	var center := Creature.HEAD_CENTER if head else Creature.BODY_CENTER
	var radii := Creature.HEAD_RADII * 0.9 if head else Creature.BODY_RADII * 0.9
	var angle := TAU * _deterministic_unit(index * 29 + 5)
	# Keep a broad uniform distribution inside the wash. The explicit edge pass
	# supplies the silhouette rhythm; the interior still needs a few leaves in
	# the middle so the creature reads as a botanical mass rather than a ring.
	var radius := sqrt(_deterministic_unit(index * 31 + 11))
	return [center + Vector2(cos(angle) * radii.x * radius, sin(angle) * radii.y * radius), head]


func _interior_flow(point: Vector2) -> Vector2:
	var nearest_distance := INF
	var nearest_tangent := Vector2.UP
	for shoot in current_shoot_paths:
		var points: PackedVector2Array = shoot["points"]
		for index in range(points.size() - 1):
			var distance := point.distance_squared_to(points[index])
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_tangent = (points[index + 1] - points[index]).normalized()
	var radial := (point - _mass_center(point)).normalized()
	var blended := nearest_tangent.lerp(radial, 0.24)
	return blended.normalized() if blended.length_squared() > 0.01 else Vector2.UP


func _regional_density(point: Vector2, key: int) -> float:
	# Broad bands make the interior feel composed rather than uniformly tiled.
	# The field is intentionally only a small modulation on top of the wash.
	var low_frequency := 0.5 + 0.5 * sin(point.x * 0.013 + point.y * 0.009 + float(key) * 0.017)
	var crown_bias := 1.0 + clampf((1160.0 - point.y) / 520.0, -0.12, 0.16)
	var belly_quiet := 0.84 if point.y > 1150.0 else 1.0
	return clampf((0.70 + low_frequency * 0.30) * crown_bias * belly_quiet, 0.54, 1.08)


func _face_clear_factor(point: Vector2) -> float:
	var protection := 0.0
	for anchor in Creature.feature_anchors():
		var normalized_distance: float = point.distance_to(anchor["center"]) / float(anchor["radius"])
		var gaussian := exp(-0.5 * normalized_distance * normalized_distance)
		protection = maxf(protection, gaussian * float(anchor["weight"]))
	return clampf(1.0 - protection * 0.92, 0.08, 1.0)


func _choose_structural_glyph(event_roll: float, key: int) -> int:
	if event_roll < profile.cluster_probability:
		return 5
	if event_roll > 0.92 and profile.growth_habit == "frond":
		return 7
	if event_roll > 0.86:
		return 12
	return [0, 1, 2, 3, 4][posmod(key, 5)]


func _draw_hedge_glyph(center: Vector2, tangent: Vector2, side: float, glyph_index: int, size: float, mask_key: int, jitter: float, strength: float, interior: bool, depth: int = -1) -> void:
	if glyph_geometry.is_empty():
		return
	if depth < 0:
		depth = 1 if interior else (4 if glyph_index == 13 else 2)
	if collecting_marks:
		_queue_mark(center, tangent, side, glyph_index, size, mask_key, jitter, strength, interior, depth)
		return
	_paint_hedge_glyph({
		"center": center,
		"tangent": tangent,
		"side": side,
		"glyph": glyph_index,
		"size": size,
		"mask_key": mask_key,
		"jitter": jitter,
		"strength": strength,
		"interior": interior,
		"depth": depth,
	})


func _queue_mark(center: Vector2, tangent: Vector2, side: float, glyph_index: int, size: float, mask_key: int, jitter: float, strength: float, interior: bool, depth: int) -> void:
	if not COMPOSITION_BOUNDS.has_point(center):
		return
	var sdf := _creature_sdf(center)
	var outside_limit := 145.0 if depth >= 3 else 42.0
	if sdf > outside_limit:
		return
	var outside_survival := 1.0 if sdf <= 0.0 else exp(-sdf / 42.0)
	var face_factor := _face_clear_factor(center)
	if face_factor < (0.20 if depth >= 2 else 0.12):
		return
	var edge_factor := 1.0 - smoothstep(-130.0, 45.0, sdf)
	var cell := _occupancy_cell(center)
	var local_occupancy: float = occupancy[cell]
	var crowd_limit := 3.6 if depth < 2 else 5.0
	if local_occupancy > crowd_limit and edge_factor < 0.72:
		return
	var score := 0.52 + edge_factor * 0.27 + outside_survival * 0.22 + face_factor * 0.16
	score -= minf(local_occupancy, 3.5) * 0.10
	if depth >= 3:
		score += 0.08
	if score < 0.48:
		return
	var detail_cost := 0.55 if depth == 0 else (0.85 if depth == 1 else (2.2 if glyph_index >= 5 else 1.15))
	if glyph_index == 13:
		detail_cost += 2.5
	if remaining_detail_budget < detail_cost and depth < 4:
		return
	remaining_detail_budget -= detail_cost
	var occupancy_cost := 0.55 if depth == 0 else (0.72 if depth == 1 else 1.0)
	occupancy[cell] += occupancy_cost
	var mark_strength := outside_survival
	if depth >= 3:
		# Exterior marks are rare, but once selected they are intentional
		# foreground ink—not faded construction lines.
		mark_strength = maxf(mark_strength, 0.72)
	composition_marks.append({
		"center": center,
		"tangent": tangent,
		"side": side,
		"glyph": glyph_index,
		"size": size,
		"mask_key": mask_key,
		"jitter": jitter,
		"strength": strength * mark_strength,
		"interior": interior,
		"depth": depth,
		"sdf": sdf,
		"score": score,
	})


func _paint_hedge_glyph(mark: Dictionary, gust: float = 0.0) -> void:
	if not mark.has("polys"):
		_prepare_mark(mark)
	_paint_mark(mark, gust)


## Everything about a leaf that does not move: its colours and angle, worked out once at build time.
## Its shape is a baked sprite (assets/sprites/<font>.png, tools/bake_leaf_sprites.py + make_ivy_sprites.py),
## so painting a frame is two tinted sprite draws per leaf, which the GPU batches.
func _prepare_mark(mark: Dictionary) -> void:
	var glyph_index: int = mark["glyph"]
	if glyph_index >= 8 and glyph_index != 13:
		glyph_index = posmod(glyph_index, 8)
	var interior: bool = mark["interior"]
	var depth: int = mark["depth"]
	var depth_factors := [0.70, 0.86, 1.0, 1.04, 1.08]
	var strength: float = clampf(float(mark["strength"]) * depth_factors[clampi(depth, 0, depth_factors.size() - 1)], 0.0, 1.0)
	var mask_key: int = mark["mask_key"]
	var light: float = mark.get("light", 1.0)
	var pigment := _lit(profile.pigment(mask_key, 1.0), light)
	pigment.a = clampf(0.55 + 0.45 * strength, 0.0, 1.0) * (0.85 if interior and depth == 0 else 1.0)
	if glyph_index == 13:
		pigment = Color(0.99, 0.97, 0.90, 0.95 * strength + 0.05)
	var ink_color := INK.lerp(Color(0.10, 0.16, 0.08), 0.3)
	ink_color.a = (0.38 if interior and depth == 0 else (0.55 if interior else 0.85)) * clampf(strength + 0.2, 0.0, 1.0)
	mark["pigment"] = pigment
	mark["ink_color"] = ink_color
	mark["base_angle"] = float(mark["tangent"].angle()) + PI * 0.5 + float(mark["side"]) * (0.12 if interior else 0.17) + float(mark["jitter"])
	mark["flower"] = glyph_index == 13
	mark["paint_strength"] = strength
	var cell := float(SPRITE_CELL)
	mark["fill_src"] = Rect2(posmod(glyph_index, 16) * cell, 0.0, cell, cell)
	mark["ink_src"] = Rect2(posmod(glyph_index, 16) * cell, cell, cell, cell)
	var size: float = mark["size"]
	mark["dest"] = Rect2(-0.6 * size, -1.15 * size, 1.2 * size, 1.2 * size)
	mark["polys"] = true


## The wind where a leaf is: a light breeze always, and gusts that roll across the hedge from left to right.
static func wind_at(x: float, t: float) -> float:
	var breeze := 0.25 + 0.10 * sin(t * 0.7)
	var front := fposmod(t * 0.23 - x / 2400.0, 1.0)            # a gust every ~4.3 s, travelling ~550 px/s
	var gust := pow(maxf(0.0, sin(front * PI)), 6.0) * (0.75 + 0.25 * sin(t * 0.31))
	return breeze + gust


func _paint_mark(mark: Dictionary, gust: float) -> void:
	var center: Vector2 = mark["center"]
	var phase: float = mark.get("phase", 0.0)
	var rim: float = mark.get("rim", 0.5)
	var wind := wind_at(center.x, _time) + gust
	var reach := 0.35 + 0.65 * rim                       # leaves at the rim move most; deep ones barely
	# bend with the wind, flutter on the stem, and twist so the edge shows for a moment in a gust
	var bend := wind * 0.16 * reach
	var flutter := (sin(_time * (5.0 + phase) + phase * 3.0) * 0.6 + sin(_time * (11.0 + phase * 2.0)) * 0.4) * 0.07 * wind * reach
	var twist := maxf(0.0, sin(_time * (2.6 + phase * 0.5) + phase * 5.0)) * clampf(wind - 0.3, 0.0, 1.0) * reach
	var angle: float = mark["base_angle"] + bend + flutter
	var lift := Vector2(wind * 6.0 * reach, -wind * 3.0 * reach)
	var turn: float = mark.get("turn", 1.0)
	var scale_x := turn * (1.0 - 0.55 * twist)
	if leaf_sheet == null:
		return
	# a soft shadow on whatever is beneath this leaf (drawn first, so later leaves cover it)
	if int(mark["depth"]) >= 2 and float(mark.get("sdf", 0.0)) < 6.0:   # only leaves lying on him cast; strays over the paper don't
		draw_set_transform(center + lift + Vector2(7.0, 10.0) * (0.7 + 0.6 * rim), angle, Vector2(scale_x * 1.06, 1.06))
		draw_texture_rect_region(leaf_sheet, mark["dest"], mark["fill_src"], Color(0.04, 0.08, 0.02, 0.30))
	draw_set_transform(center + lift, angle, Vector2(scale_x, 1.0))
	var pigment: Color = mark["pigment"]
	if twist > 0.05:
		pigment = pigment.lightened(0.18 * twist)          # the paler underside shows as it turns
	draw_texture_rect_region(leaf_sheet, mark["dest"], mark["fill_src"], pigment)
	draw_texture_rect_region(leaf_sheet, mark["dest"], mark["ink_src"], mark["ink_color"])
	if mark["flower"]:
		var size: float = mark["size"]
		draw_circle(Vector2(0.0, -0.62 * size), size * 0.085, Color(0.86, 0.62, 0.16, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _load_leaf_sheet() -> void:
	leaf_sheet = null
	if profile == null:
		return
	var name: String = profile.geometry_path.get_file().replace("_geometry.json", "")
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % name))
	if image == null or image.is_empty():
		return
	# the sheet plus its normal map (tools/make_normal_maps.py): Godot's 2D lights shape every leaf, and leaves
	# glint as they turn in the wind
	var lit := CanvasTexture.new()
	lit.diffuse_texture = ImageTexture.create_from_image(image)
	var normals := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s_n.png" % name))
	if normals != null and not normals.is_empty():
		lit.normal_texture = ImageTexture.create_from_image(normals)
	lit.specular_color = Color(1.0, 0.98, 0.85, 1.0)
	lit.specular_shininess = 0.35
	leaf_sheet = lit


## Light a pigment: shade toward deep green in shadow, toward warm yellow-green in the light.
func _lit(color: Color, light: float) -> Color:
	var a := color.a
	var lit := color.darkened(clampf(1.0 - light, 0.0, 0.6) * 0.9) if light < 1.0 else color.lerp(Color(0.86, 0.90, 0.52), clampf(light - 1.0, 0.0, 0.2) * 2.0)
	lit.a = a
	return lit


func _sort_marks(a: Dictionary, b: Dictionary) -> bool:
	if a["depth"] == b["depth"]:
		return a["sdf"] < b["sdf"]
	return a["depth"] < b["depth"]


func _occupancy_cell(point: Vector2) -> int:
	var normalized := Vector2(
		clampf((point.x - COMPOSITION_BOUNDS.position.x) / COMPOSITION_BOUNDS.size.x, 0.0, 0.9999),
		clampf((point.y - COMPOSITION_BOUNDS.position.y) / COMPOSITION_BOUNDS.size.y, 0.0, 0.9999)
	)
	var column := clampi(int(normalized.x * OCCUPANCY_COLUMNS), 0, OCCUPANCY_COLUMNS - 1)
	var row := clampi(int(normalized.y * OCCUPANCY_ROWS), 0, OCCUPANCY_ROWS - 1)
	return row * OCCUPANCY_COLUMNS + column


func _local_polygon(points: PackedVector2Array, scale: float, bend: float = 0.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		var warped_x := point.x + bend * sin(PI * clampf(point.y, 0.0, 1.0))
		result.append(Vector2(warped_x * scale, -point.y * scale))
	return result


func _local_path(points: PackedVector2Array, scale: float, bend: float = 0.0) -> PackedVector2Array:
	return _local_polygon(points, scale, bend)


func _scale_polygon(points: PackedVector2Array, scale: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * scale)
	return result


func _polygon_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(0.50 + point.x * 0.92, 0.98 - point.y * 0.92))
	return result


func _select_profile_by_id(id: String) -> void:
	for index in range(profiles.size()):
		if profiles[index].id == id:
			_select_profile(index)
			return
	if not profiles.is_empty():
		_select_profile(0)


func _select_profile(index: int) -> void:
	if profiles.is_empty():
		return
	profile_index = clampi(index, 0, profiles.size() - 1)
	profile = profiles[profile_index]
	profile_id = profile.id
	shoot_count = profile.primary_shoot_count
	leaf_font = load(profile.font_path) as Font
	_load_geometry(profile.geometry_path)
	_load_leaf_sheet()
	_update_plant_selector()
	var specimen := get_node_or_null("../../SpecimenPanel")
	if specimen != null and specimen.has_method("set_profile"):
		specimen.set_profile(profile)
	queue_redraw()


func _load_geometry(path: String = "") -> void:
	glyph_geometry.clear()
	var geometry_path := path if not path.is_empty() else "res://assets/fonts/hedgeink_geometry.json"
	var file := FileAccess.open(geometry_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for item in parsed.get("glyphs", []):
		var fill_polygons: Array[PackedVector2Array] = []
		for polygon_data in item.get("fill", []):
			var polygon := PackedVector2Array()
			for pair in polygon_data:
				polygon.append(Vector2(float(pair[0]), float(pair[1])))
			fill_polygons.append(polygon)
		var ink_paths: Array[PackedVector2Array] = []
		for path_data in item.get("ink", []):
			var path_points := PackedVector2Array()
			for pair in path_data:
				path_points.append(Vector2(float(pair[0]), float(pair[1])))
			ink_paths.append(path_points)
		glyph_geometry.append({"fill": fill_polygons, "ink": ink_paths})


func _load_masks() -> void:
	for path in MASK_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			mask_textures.append(texture)
			mask_images.append(texture.get_image())


func _mask_value(key: int) -> float:
	if mask_images.is_empty():
		return 0.5
	var image: Image = mask_images[posmod(key, mask_images.size())]
	var x := posmod(PET_SEED + key * 37, image.get_width())
	var y := posmod(PET_SEED * 3 + key * 53, image.get_height())
	return image.get_pixel(x, y).a


func _habit_length_scale() -> float:
	match profile.growth_habit:
		"low":
			return 0.72
		"climbing":
			return 1.04
		"frond":
			return 0.92
		_:
			return 1.0


func _shoot_direction(shoot_id: int) -> Vector2:
	var raw: Vector2 = (Creature.remap_legacy(SHOOT_ORIGINS[shoot_id]) - _mass_center(Creature.remap_legacy(SHOOT_ORIGINS[shoot_id]))).normalized()
	if profile.growth_habit == "climbing":
		raw = raw.lerp(Vector2.UP, 0.14).normalized()
	elif profile.growth_habit == "low":
		raw = raw.lerp(Vector2(0.0, 0.45), 0.16).normalized()
	return raw.rotated((_deterministic_unit(shoot_id * 73 + 5) - 0.5) * (0.11 if profile.growth_habit == "frond" else 0.17))


## The centre of whichever mass (head or body) a point belongs to: leaves on the rim point away from it.
func _mass_center(point: Vector2) -> Vector2:
	var head_delta := (point - Creature.HEAD_CENTER) / Creature.HEAD_RADII
	var body_delta := (point - Creature.BODY_CENTER) / Creature.BODY_RADII
	return Creature.HEAD_CENTER if head_delta.length() < body_delta.length() else Creature.BODY_CENTER


func _creature_sdf(point: Vector2) -> float:
	var body_delta := (point - Creature.BODY_CENTER) / Creature.BODY_RADII
	var head_delta := (point - Creature.HEAD_CENTER) / Creature.HEAD_RADII
	var body_distance := (body_delta.length() - 1.0) * minf(Creature.BODY_RADII.x, Creature.BODY_RADII.y)
	var head_distance := (head_delta.length() - 1.0) * minf(Creature.HEAD_RADII.x, Creature.HEAD_RADII.y)
	return minf(body_distance, head_distance)


func _shoot_extent_fraction(shoot_id: int) -> float:
	var full_length: float = SHOOT_LENGTHS[shoot_id] * _habit_length_scale()
	var surface_t := 1.0
	for sample_index in range(1, 25):
		var t := float(sample_index) / 24.0
		if _creature_sdf(_shoot_point(shoot_id, t, full_length)) > 0.0:
			surface_t = t
			break
	var is_tendril := _deterministic_unit(shoot_id * 97 + 23) > 0.82
	var overshoot := (0.14 + _deterministic_unit(shoot_id * 113 + 7) * 0.11) if is_tendril else (0.025 + _deterministic_unit(shoot_id * 113 + 7) * 0.040)
	return clampf(surface_t + overshoot, 0.24, 1.0)


func _shoot_point(shoot_id: int, t: float, full_length: float) -> Vector2:
	var direction := _shoot_direction(shoot_id)
	var normal := Vector2(-direction.y, direction.x)
	var phase := _deterministic_unit(shoot_id * 11 + 2) * TAU
	var normalized_amplitude := clampf(amplitude / 190.0, 0.0, 1.0)
	var local_frequency := lerpf(profile.frequency_range.x, profile.frequency_range.y, clampf(frequency / 2.5, 0.0, 1.0))
	var max_amplitude := lerpf(profile.amplitude_range.x, profile.amplitude_range.y, normalized_amplitude)
	var bounded_amplitude := minf(max_amplitude * 0.46, 78.0)
	var sway := sin(t * PI * local_frequency + phase) * minf(bounded_amplitude, 14.0 + bounded_amplitude * 0.78 * t)
	var slow_curve := (_deterministic_unit(shoot_id * 131 + 41) - 0.5) * 58.0
	return Creature.remap_legacy(SHOOT_ORIGINS[shoot_id]) + direction * (t * full_length) + normal * (sway + slow_curve * t * t)


func _shoot_tangent(shoot_id: int, t: float, full_length: float) -> Vector2:
	var ahead := _shoot_point(shoot_id, minf(t + 0.012, 1.0), full_length)
	var behind := _shoot_point(shoot_id, maxf(t - 0.012, 0.0), full_length)
	var tangent := (ahead - behind).normalized()
	return tangent if tangent.length_squared() > 0.01 else _shoot_direction(shoot_id)


func _profile_leaf_spacing() -> float:
	return profile.leaf_spacing * lerpf(1.25, 0.72, clampf(leaf_spacing / 120.0, 0.0, 1.0))


func _profile_overflow() -> float:
	return clampf(lerpf(0.30, 1.0, overflow) * (0.66 + profile.overflow_tendency * 0.42), 0.0, 1.0)


func _is_inside_mass(point: Vector2) -> bool:
	return _creature_sdf(point) <= 0.0


func _deterministic_unit(key: int) -> float:
	return 0.5 + 0.5 * sin(float(PET_SEED + key) * 12.9898 + 78.233)


func _bind_plant_selector() -> void:
	var selector := get_node_or_null("../../DebugPanel/VBox/HeaderRow/PlantOption") as OptionButton
	if selector == null:
		return
	selector.clear()
	for item in profiles:
		selector.add_item(item.label)
	selector.item_selected.connect(_on_plant_selected)


func _update_plant_selector() -> void:
	var selector := get_node_or_null("../../DebugPanel/VBox/HeaderRow/PlantOption") as OptionButton
	if selector != null and selector.item_count > profile_index:
		selector.select(profile_index)


func _on_plant_selected(index: int) -> void:
	_select_profile(index)


func _on_growth_changed(value: float) -> void:
	growth = clampf(value, 0.0, 1.0)
	queue_redraw()


func _on_amplitude_changed(value: float) -> void:
	amplitude = clampf(value, 0.0, 190.0)
	queue_redraw()


func _on_frequency_changed(value: float) -> void:
	frequency = clampf(value, 0.3, 2.5)
	queue_redraw()


func _on_spacing_changed(value: float) -> void:
	leaf_spacing = clampf(value, 24.0, 120.0)
	queue_redraw()


func _on_overflow_changed(value: float) -> void:
	overflow = clampf(value, 0.0, 1.0)
	queue_redraw()
