extends "res://scripts/pet/node/pet_moods.gd"
class_name HedgePetNode

## One HedgePet, built from its CharacterArtProfile: regions (primitives), face (anchors), foliage (clusters of its
## plant), and its life (blinks, looks at things, a gust now and then, hops when tapped, a little step while it
## walks). Place it anywhere: the pet viewer (scripts/hedge_pet_3d.gd) holds one, the garden holds several.
## Its own space: the pet faces +X, stands on y = 0.

##
## This file is the top of a layer chain (scripts/pet/node/):
##   pet_body -> pet_face -> pet_foliage -> pet_moods -> hedge_pet_node.gd (here: setup, changing plant, its life each frame)

var time := 0.0
var hop := 0.0
var walking := 0.0                               # 0 standing .. 1 walking: a little step bounce
var look_point := Vector3.INF                    # a world point to turn the head toward (INF: glance around)
## Little moods, each 0..1 and eased (never a jump): asleep (eyes shut, slow breaths, head down, Zzz), curious (a
## head tilt when you come near), shaking (after a watering: a shiver from nose to tail, droplets flying).
var asleep := 0.0
var curious := 0.0
var noticed := false
var _hop_v := 0.0
var _next_blink := 2.0
var _blink := 0.0
var _gust := 0.0
var _next_gust := 6.0
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _next_glance := 2.0
var _rng := RandomNumberGenerator.new()
func setup(p: CharacterArtProfile) -> void:
	_setup_body(p)                                       # (never yields for a normal pet: built at once, as always)


var _pending_plant := ""
signal materialized
func _setup_body(p: CharacterArtProfile) -> void:
	profile = p
	for child in get_children():
		if child.name != "ContactShadow" and not child is CPUParticles3D:   # the garden's shadow; a leaf burst in flight
			child.queue_free()
	foliage_nodes.clear()
	eyes.clear()
	_materials.clear()
	leaves_mat = null
	shell_mat = null
	_rng.seed = profile.seed
	_next_blink = _rng.randf_range(1.0, 3.0)
	pet = Node3D.new()
	pet.name = "Pet"
	add_child(pet)
	if sliced:
		building = true
		pet.visible = false                              # whole or not at all
	head = Node3D.new()
	head.name = "Head"
	head.position = profile.regions["HEAD"]["center"]
	pet.add_child(head)
	await _build_regions()
	await _slice()
	await _build_face()
	await _slice()
	await rebuild_foliage()
	if sliced:
		sliced = false                                   # from now on it's an ordinary pet (regrafts build at once)
		building = false
		pet.visible = true
		set_detail(detail, true)
		if _pending_plant != "":
			var plant := _pending_plant
			_pending_plant = ""
			set_plant(plant, false)
		materialized.emit()


## Regrow this pet in another plant (SpeciesBuilder.PLANTS): new leaves, palette and bloom; same shape and face.
## Animated (default): the old leaves fall away in a little burst, the pet squashes, and the new plant grows in.
func set_plant(plant: String, animate := true) -> void:
	if building:                                         # still growing from its recipe: this plant when it's done
		_pending_plant = plant
		return
	if not animate or Motion.speed <= 0.0 or not is_inside_tree():
		_regrow(plant)
		return
	_leaf_burst()
	var rest := _true_scale()
	var t := Motion.shed_leaves(self)
	t.tween_callback(func() -> void:
		Motion.swap(self, rest, func() -> void:
			if _becoming != null:                        # a switch to another pet was still on its way: finish it
				var level := detail
				setup(_becoming)
				set_detail(level, true)
				_becoming = null
			_regrow(plant)
			leaf_growth = 0.0
			Motion.grow_leaves(self)))


var _becoming: CharacterArtProfile = null      # a pet switch not yet done (a regraft started meanwhile finishes it)


## Restart as `profile` (another pet: the viewer's ‹ ›) with the same transition as a regraft.
func become(p: CharacterArtProfile) -> void:
	if Motion.speed <= 0.0 or not is_inside_tree():
		setup(p)
		return
	var rest := _true_scale()
	_becoming = p
	var t := Motion.shed_leaves(self)
	t.tween_callback(func() -> void:
		Motion.swap(self, rest, func() -> void:
			var level := detail
			_becoming = null
			setup(p)
			set_detail(level, true)
			leaf_growth = 0.0
			Motion.grow_leaves(self)))


func _regrow(plant: String) -> void:
	var level := detail
	setup(SpeciesBuilder.restyle(profile, plant))
	set_detail(level, true)
	tap()


## A tap: a hop, a shiver through the leaves, a heart.
func tap() -> void:
	sleeping = false
	joy = 1.0
	if hop <= 0.0:
		_hop_v = sqrt(2.0 * 9.0 * profile.hop_height)
		hop = 0.001


# ------------------------------------------------------------------ ui: name, note, pet switcher


func life_state() -> Dictionary:
	return {"joy": joy, "time": time}


func _process(delta: float) -> void:
	if profile == null or building:                      # (still growing from its recipe, hidden: nothing to animate)
		return
	time += delta
	joy = maxf(0.0, joy - delta * 0.55)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 1.0
		_next_blink = _rng.randf_range(profile.blink_interval.x, profile.blink_interval.y)
	_blink = maxf(0.0, _blink - delta * 8.0)
	asleep = move_toward(asleep, 1.0 if sleeping else 0.0, delta * (0.5 if sleeping else 2.5))
	curious = move_toward(curious, 1.0 if noticed and not sleeping else 0.0, delta * 2.5)
	_shake = maxf(0.0, _shake - delta * 1.1)
	for eye in eyes:
		eye.scale.y = lerpf(1.0 - 0.88 * sin(_blink * PI), 0.1, asleep)
	# where to look: a point in the world, or glancing around now and then
	if look_point != Vector3.INF:
		var local := head.global_transform.affine_inverse() * look_point
		var flat := Vector2(local.x, local.z)
		_look_target = Vector2(clampf(atan2(-local.z, local.x) / 1.2, -1.0, 1.0), clampf(-local.y / maxf(flat.length(), 0.5), -1.0, 1.0))
	else:
		_next_glance -= delta
		if _next_glance <= 0.0:
			_look_target = Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.4, 0.4)) if _rng.randf() < 0.7 else Vector2.ZERO
			_next_glance = _rng.randf_range(1.5, 4.0)
	if asleep > 0.0:
		_look_target = _look_target.lerp(Vector2.ZERO, asleep)
	_look = _look.lerp(_look_target, clampf(delta * 3.0, 0.0, 1.0))
	head.rotation = Vector3(sin(time * 0.37) * 0.05 + curious * 0.24 + sin(time * 30.0) * 0.08 * _shake,
		_look.x * profile.look_strength * 1.6, -_look.y * profile.look_strength * 0.5 + sin(time * 0.9) * 0.015 - asleep * 0.22)   # a gentle, curious tilt; head down asleep
	if hop > 0.0 or _hop_v != 0.0:
		_hop_v -= 9.0 * delta
		hop += _hop_v * delta
		if hop <= 0.0:
			hop = 0.0
			_hop_v = 0.0
	var step := absf(sin(time * 9.0)) * 0.06 * walking   # a little bounce in each step
	pet.position.y = hop + step + sin(time * 1.5) * 0.004
	pet.rotation.z = sin(time * 9.0) * 0.03 * walking
	pet.rotation.x = sin(time * 34.0) * 0.1 * _shake * _shake                  # shaking off the water
	pet.scale = Vector3(1.0, 1.0 + sin(time * 1.3) * 0.025 * asleep, 1.0)       # slow breaths in sleep
	_next_gust -= delta
	if _next_gust <= 0.0:
		_gust = 1.0
		_next_gust = _rng.randf_range(7.0, 14.0)
	_gust = maxf(0.0, _gust - delta * 0.8)
	_leaf_param("gust", joy * 1.2 + _gust * 0.5 * (1.0 - asleep * 0.7) + walking * 0.4 + _shake * 1.5)
	shell_mat.set_shader_parameter("body_center", pet.to_global(profile.regions["BODY"]["center"]))
	shell_mat.set_shader_parameter("head_center", head.global_position)
	heart.modulate.a = clampf(joy * 1.4, 0.0, 1.0)
	heart.position.y = 1.1 + (1.0 - joy) * 0.5
