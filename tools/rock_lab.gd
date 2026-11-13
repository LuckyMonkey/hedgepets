@tool
extends Node3D

## Inspector playground for the rock generator. Change the exported values on the selected specimen;
## the row below shows the complete role library for quick visual comparison.

@export_enum("wall_stone", "cap_stone", "stepping_stone", "boulder", "cobble", "scree", "ledge", "outcrop") var role := "boulder":
	set(value):
		role = value
		_dirty = true
@export var seed := 17:
	set(value):
		seed = value
		_dirty = true
@export var size := Vector3(1.2, 0.7, 0.9):
	set(value):
		size = value
		_dirty = true
@export_range(0.0, 0.5, 0.01) var roughness := 0.18:
	set(value):
		roughness = value
		_dirty = true
@export_range(2, 18, 1) var facets := 7:
	set(value):
		facets = value
		_dirty = true
@export_range(0.25, 1.0, 0.01) var flatten := 0.92:
	set(value):
		flatten = value
		_dirty = true
@export var save_archetype := false:
	set(value):
		save_archetype = value
		if value: _save_archetype()

var _dirty := true
var _last_key := ""

func _process(_delta: float) -> void:
	if _dirty:
		_rebuild()

func _rebuild() -> void:
	_dirty = false
	for child in get_children():
		if child.name.begins_with("Specimen") or child.name.begins_with("Fitting"):
			child.queue_free()
	var y := 0.0
	for i in range(RockFactory.ROLES.size()):
		print("rock archetype %s: %d triangles" % [RockFactory.ROLES[i], RockFactory.triangle_count(RockFactory.ROLES[i], seed + i * 101)])
		var item := MeshInstance3D.new()
		item.name = "Specimen_%s" % RockFactory.ROLES[i]
		var s := size
		if RockFactory.ROLES[i] == "cap_stone" or RockFactory.ROLES[i] == "stepping_stone": s = Vector3(1.25, 0.28, 0.82)
		if RockFactory.ROLES[i] == "ledge" or RockFactory.ROLES[i] == "outcrop": s = Vector3(1.2, 0.9, 0.55)
		item.mesh = RockFactory.make({"role": RockFactory.ROLES[i], "size": s, "seed": seed + i * 101, "roughness": roughness, "facets": facets, "flatten": flatten})
		item.material_override = RockFactory.material(Color("817e75").lerp(Color("a7a08d"), float(i % 3) / 3.0))
		item.position = Vector3((i - 3.5) * 1.8, s.y * 0.5, 0)
		add_child(item)
		var label := Label3D.new()
		label.text = RockFactory.ROLES[i]
		label.font_size = 24
		label.pixel_size = 0.002
		label.position = item.position + Vector3(0, s.y * 0.8 + 0.22, 0)
		add_child(label)
	var wall := Node3D.new()
	wall.name = "Fitting_Wall"
	add_child(wall)
	for spec in RockFactory.wall(Vector3(-5, 0, -2.2), Vector3(5, 0, -2.2), 1.2, seed):
		_add_specimen(wall, spec)
	var crossing := Node3D.new()
	crossing.name = "Fitting_Crossing"
	add_child(crossing)
	var points := PackedVector3Array()
	for i in range(7): points.append(Vector3(-3.0 + i, 0, -4.1 + sin(i * 0.7) * 0.12))
	for spec in RockFactory.crossing(points, 0.9, seed + 99): _add_specimen(crossing, spec)

func _add_specimen(parent: Node3D, spec: Dictionary) -> void:
	var item := MeshInstance3D.new()
	item.mesh = RockFactory.make(spec)
	item.material_override = RockFactory.material(Color("8a877c"))
	item.position = spec["at"]
	item.rotation_degrees.y = float(spec.get("yaw", 0.0))
	parent.add_child(item)

func _save_archetype() -> void:
	var all := RockFactory.archetypes()
	var key := "weathered_boulder" if role == "boulder" else role
	var current: Dictionary = all.get(key, {}).duplicate(true)
	current["aspect"] = [size.x, size.y, size.z]
	current["deformation"] = roughness
	current["hull_points"] = 10 if facets <= 6 else (14 if facets >= 10 else 12)
	all[key] = current
	var file := FileAccess.open(RockFactory.DATA_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(all, "  "))
		file.close()
	save_archetype = false
