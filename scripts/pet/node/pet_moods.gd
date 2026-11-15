extends "res://scripts/pet/node/pet_foliage.gd"

## Pet 4/4 - moods and reactions: the true scale, leaf bursts, sleep, shaking off water.
##
## How the pet reacts: a burst of leaves when it changes, falling asleep, shaking off water with droplets flying.
## Every visible change eases (Motion), never jumps.
##
## Part of the pet layer chain (the full order is at the top of scripts/pet/hedge_pet_node.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var joy := 0.0
var sleeping := false
var _shake := 0.0
var _rest_scale := Vector3.ZERO
## The pet's real size, not wherever a squash happens to have it right now: a second regraft or switch started
## mid-squash used to take the squashed size as the new normal, and the pet stayed flat.
func _true_scale() -> Vector3:
	if _rest_scale == Vector3.ZERO or not Motion.busy(self, "scale"):
		_rest_scale = scale
	return _rest_scale


## A handful of the current leaves flying off (hides the moment one plant becomes another).
func _leaf_burst() -> void:
	if leaves_mat == null:
		return
	var sheet: Texture2D = leaves_mat.get_shader_parameter("leaf_sheet")
	var m := StandardMaterial3D.new()
	m.albedo_texture = sheet
	m.uv1_scale = Vector3(1.0 / 16.0, 0.5, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 28
	p.lifetime = 1.1
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = (profile.regions["BODY"]["radii"] as Vector3).x * 0.8
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -5.0, 0)
	p.angle_max = 360.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = profile.leaf_size * 0.6
	p.scale_amount_max = profile.leaf_size * 1.0
	p.color = profile.palette["matcha"]
	var quad := QuadMesh.new()
	quad.material = m
	p.mesh = quad
	p.position = profile.regions["BODY"]["center"]
	p.emitting = true
	add_child(p)
	p.finished.connect(p.queue_free)


## Fall asleep / wake up (eased in _process). Waking from a tap is a little startled hop.
func set_sleeping(on: bool) -> void:
	sleeping = on


## After a watering: shake it off.
func shake_off() -> void:
	sleeping = false
	_shake = 1.0
	joy = maxf(joy, 0.4)
	_droplets()


func _droplets() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 30
	p.lifetime = 0.9
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = (profile.regions["BODY"]["radii"] as Vector3).x * 0.9
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -8.0, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.06
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.88, 0.98, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	var drop := SphereMesh.new()
	drop.radius = 1.0
	drop.height = 2.0
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = m
	p.mesh = drop
	p.position = profile.regions["BODY"]["center"]
	p.emitting = true
	add_child(p)
	p.finished.connect(p.queue_free)
