extends Node3D

## The pet viewer: one HedgePet (scripts/pet/hedge_pet_node.gd) on paper, soft illustration light, an orbit camera.
## Drag to turn (turntable, momentum), drag up/down to tilt, wheel to zoom, tap for a hop; ‹ › or arrow keys switch
## pets. Developer view: F1 (scripts/art/art_debug.gd). The garden is res://garden.tscn.

var PETS: Array = []          # every CharacterArtProfile (CharacterArtProfile.roster())

var pet_index := 0
var pet_node: HedgePetNode
var camera: Camera3D
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var name_tag: Label
var note: Label
var plant_button: Button
var auto_detail := true
var _yaw := 0.0
var _yaw_velocity := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _view := "THREE_QUARTER"
var _press_at := Vector2.INF
var _dragged := false

# pass-throughs (the debug view and the capture tools talk to the viewer)
var profile: CharacterArtProfile:
	get: return pet_node.profile if pet_node else null
var pet: Node3D:
	get: return pet_node
var head: Node3D:
	get: return pet_node.head
var foliage_nodes: Array[MultiMeshInstance3D]:
	get: return pet_node.foliage_nodes
var cluster_debug: Array:
	get: return pet_node.cluster_debug
var leaves_mat: ShaderMaterial:
	get: return pet_node.leaves_mat


func _ready() -> void:
	PETS = CharacterArtProfile.roster()
	_build_world()
	_build_ui()
	_load_pet(0)


func _load_pet(index: int) -> void:
	pet_index = posmod(index, PETS.size())
	var p: CharacterArtProfile = PETS[pet_index]
	if pet_node == null:
		pet_node = HedgePetNode.new()
		pet_node.name = "HedgePet"
		add_child(pet_node)
	pet_node.setup(p)
	name_tag.text = p.pet_name
	_show_plant()
	note.text = "a %s · adopted %s · tap, drag to turn" % [p.species, p.adopted]
	_yaw = 0.0
	_yaw_velocity = 0.0
	_pitch = 0.0
	_zoom = 1.0
	set_view(_view)


## Cycle the pet through every plant (fonts and leaf sheets): HedgeMoss, HedgeHolly, ivy, oak...
func next_plant() -> void:
	var plants: Array = SpeciesBuilder.PLANTS.keys()
	var i := plants.find(SpeciesBuilder.plant_of(profile))
	pet_node.set_plant(plants[(i + 1) % plants.size()])
	_show_plant()


func _show_plant() -> void:
	if plant_button != null and profile != null:
		plant_button.text = "🍃 made of %s" % SpeciesBuilder.plant_of(profile)


func rebuild_foliage() -> void:
	pet_node.rebuild_foliage()


func set_detail(level: String) -> void:
	pet_node.set_detail(level)


func set_foliage(preset: String) -> void:
	pet_node.set_foliage(preset)


func _build_world() -> void:
	var p := CharacterArtProfile.gerald()   # the room's light and paper are shared by every pet
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = p.paper
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # an illustration: the paper stays the paper
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# soft illustration light: a broad warm key with soft, light shadows, and a fill from the viewer so the face
	# never falls into shadow
	sun = DirectionalLight3D.new()
	sun.light_color = p.key_color
	sun.light_energy = p.key_energy
	sun.shadow_enabled = true
	sun.shadow_blur = p.shadow_softness
	sun.directional_shadow_max_distance = 25.0
	sun.rotation_degrees = p.key_angle
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.light_color = Color(0.92, 0.95, 1.0)
	fill.light_energy = p.fill_energy
	fill.rotation_degrees = Vector3(-18.0, 35.0, 0.0)
	add_child(fill)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 40.0
	add_child(camera)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var paper_mat := ShaderMaterial.new()
	paper_mat.shader = load("res://shaders/paper_ground.gdshader")
	paper_mat.set_shader_parameter("paper", Color(p.paper.r, p.paper.g, p.paper.b))
	paper_mat.set_shader_parameter("shadow_strength", p.shadow_strength)
	ground.material_override = paper_mat
	ground.name = "Paper"
	add_child(ground)



## Camera presets (also used by the acceptance captures). The player's drag/zoom adds on top.
func set_view(view: String) -> void:
	_view = view
	_place_camera()



func _place_camera() -> void:
	if profile == null or camera == null:
		return
	var target: Vector3 = profile.frame_target
	var dir := Vector3(0.42, 0.55, 0.72)
	var distance: float = profile.frame_distance
	match _view:
		"FRONT":
			dir = Vector3(1.0, 0.35, 0.0)
		"SIDE":
			dir = Vector3(0.0, 0.3, 1.0)
		"DISTANT":
			distance *= 2.3
	var elevation := clampf(asin(dir.normalized().y) + _pitch, 0.05, 1.3)
	var flat := Vector2(dir.x, dir.z).normalized()
	var d := Vector3(flat.x * cos(elevation), sin(elevation), flat.y * cos(elevation))
	camera.position = target + d * distance * _zoom
	camera.look_at(target, Vector3.UP)


# ------------------------------------------------------------------ regions

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	name_tag = Label.new()
	name_tag.add_theme_font_size_override("font_size", 54)
	name_tag.add_theme_color_override("font_color", Color(0.36, 0.27, 0.19))
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.position = Vector2(240, 1500)
	name_tag.size = Vector2(600, 80)
	layer.add_child(name_tag)
	note = Label.new()
	note.add_theme_font_size_override("font_size", 24)
	note.add_theme_color_override("font_color", Color(0.45, 0.38, 0.30, 0.8))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.position = Vector2(90, 1578)
	note.size = Vector2(900, 40)
	layer.add_child(note)
	plant_button = Button.new()
	plant_button.flat = true
	plant_button.add_theme_font_size_override("font_size", 30)
	plant_button.add_theme_color_override("font_color", Color(0.36, 0.27, 0.19, 0.85))
	plant_button.position = Vector2(340, 1630)
	plant_button.size = Vector2(400, 70)
	plant_button.tooltip_text = "Grow this pet in another plant (F)"
	plant_button.pressed.connect(next_plant)
	layer.add_child(plant_button)
	for side in [-1, 1]:
		var b := Button.new()
		b.text = "‹" if side < 0 else "›"
		b.flat = true
		b.add_theme_font_size_override("font_size", 72)
		b.add_theme_color_override("font_color", Color(0.36, 0.27, 0.19, 0.75))
		b.add_theme_color_override("font_hover_color", Color(0.36, 0.27, 0.19, 1.0))
		b.position = Vector2(150 if side < 0 else 830, 1480)
		b.size = Vector2(100, 110)
		b.tooltip_text = "Previous pet" if side < 0 else "Next pet"
		b.pressed.connect(func() -> void: _load_pet(pet_index + side))
		layer.add_child(b)


# ------------------------------------------------------------------ life


func _process(delta: float) -> void:
	if _press_at == Vector2.INF:
		_yaw += _yaw_velocity * delta
		_yaw_velocity *= pow(0.008, delta)
	pet_node.rotation.y = _yaw
	if auto_detail:
		var top := camera.unproject_position(pet_node.global_position + Vector3(0, 2.1, 0))
		var bottom := camera.unproject_position(pet_node.global_position)
		var px := absf(bottom.y - top.y)
		var level := "CLOSE" if px > 360.0 else ("MEDIUM" if px > 170.0 else "FAR")
		if level != pet_node.detail:
			pet_node.set_detail(level)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				var dbg := get_node_or_null("ArtDebug")
				if dbg == null:
					dbg = preload("res://scripts/art/art_debug.gd").new()
					dbg.name = "ArtDebug"
					add_child(dbg)
				else:
					dbg.queue_free()
			KEY_F:
				next_plant()
			KEY_LEFT:
				_load_pet(pet_index - 1)
			KEY_RIGHT:
				_load_pet(pet_index + 1)
		return
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoom = clampf(_zoom * (0.92 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.08), 0.55, 1.8)
		_place_camera()
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if pressed:
		if event.position.y > get_viewport().get_visible_rect().size.y * 0.75:
			return                                   # the name and the ‹ › live down there
		_press_at = event.position
		_dragged = false
		_yaw_velocity = 0.0
	elif released and _press_at != Vector2.INF:
		if not _dragged:
			_tap(event.position)
		_press_at = Vector2.INF
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag):
		var size := get_viewport().get_visible_rect().size
		pet_node.look_point = camera.project_position(event.position, 4.0)
		if _press_at != Vector2.INF:
			if event.position.distance_to(_press_at) > 10.0:
				_dragged = true
			if _dragged:
				var rel: Vector2 = event.relative
				_yaw += rel.x * 0.008
				_yaw_velocity = rel.x * 0.008 * 30.0
				_pitch = clampf(_pitch + rel.y * 0.004, -0.4, 0.6)
				_place_camera()




func _tap(at: Vector2) -> void:
	var on_screen := camera.unproject_position(pet_node.global_position + Vector3(0.3, 1.0, 0.0))
	if at.distance_to(on_screen) < get_viewport().get_visible_rect().size.x * 0.45:
		pet_node.tap()
