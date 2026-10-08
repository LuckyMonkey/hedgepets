extends Node3D

## A cabbage-white (or sulphur, or skipper) drifting over the lawn: two flat wings that flap, a lazy looping path
## that wanders between the places it likes (garden.butterfly_spots(): flowering plants, flowers in the grass).

var garden: Node3D
var wings: Array[MeshInstance3D] = []
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _t := 0.0
var _phase := 0.0


func setup(g: Node3D, color: Color, at: Vector3) -> void:
	garden = g
	_home = at
	_target = at
	_phase = randf() * TAU
	position = at + Vector3(0, 0.8, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	var dark := m.duplicate() as StandardMaterial3D
	dark.albedo_color = color.darkened(0.55)
	for side: float in [1.0, -1.0]:
		var hinge := MeshInstance3D.new()
		var wing := PrismMesh.new()               # a rounded-ish triangle reads as a wing at this size
		wing.size = Vector3(0.16, 0.12, 0.004)
		var w := MeshInstance3D.new()
		w.mesh = wing
		w.material_override = m
		w.position = Vector3(0.0, 0.0, side * 0.08)
		w.rotation_degrees = Vector3(90, 0, 0)
		hinge.add_child(w)
		add_child(hinge)
		wings.append(hinge)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.012
	cap.height = 0.09
	body.mesh = cap
	body.material_override = dark
	body.rotation_degrees = Vector3(0, 0, 90)
	add_child(body)


func _process(delta: float) -> void:
	_t += delta
	var flap := sin(_t * 18.0 + _phase) * 0.9 + 0.2
	wings[0].rotation.x = flap
	wings[1].rotation.x = -flap
	var to := _target - position
	if to.length() < 0.4 or randf() < delta * 0.05:
		var spots: Array = garden.butterfly_spots()
		var base: Vector3 = spots.pick_random() if not spots.is_empty() else _home
		_target = base + Vector3(randf_range(-1.5, 1.5), randf_range(0.35, 1.3), randf_range(-1.5, 1.5))
	var drift := Vector3(sin(_t * 2.1 + _phase), sin(_t * 3.3 + _phase) * 0.6, cos(_t * 1.7 + _phase)) * 0.35
	var v := to.normalized() * 0.7 + drift
	position += v * delta
	position.y = clampf(position.y, 0.25, 2.2)
	if v.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-v.z, v.x), clampf(delta * 3.0, 0.0, 1.0))
