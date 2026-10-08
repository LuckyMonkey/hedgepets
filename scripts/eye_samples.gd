extends Control

## The eye sample sheet: the same pet nine times, close up, one eye style each (HedgePetNode.EYE_STYLES), numbered,
## to pick from. ‹ › (or ← →) switch the pet; tap a sample to see it bigger (tap again to go back).
##   godot --path . res://eye_samples.tscn

var roster: Array = []
var pet_index := 0
var cells: Array = []          # [SubViewport, HedgePetNode, Camera3D, Label]
var _title: Label
var _focus := -1
var _grid: GridContainer


func _ready() -> void:
	roster = CharacterArtProfile.roster()
	var bg := ColorRect.new()
	bg.color = Color(0.968, 0.945, 0.89)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 30)
	_title.size = Vector2(1080, 60)
	add_child(_title)
	var hint := Label.new()
	hint.text = "Which eyes? Tap one to see it bigger. ‹ › another pet."
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.3))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 92)
	hint.size = Vector2(1080, 40)
	add_child(hint)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.position = Vector2(24, 150)
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	add_child(_grid)
	var i := 0
	for style in HedgePetNode.EYE_STYLES:
		i += 1
		var box := VBoxContainer.new()
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.custom_minimum_size = Vector2(336, 460)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = false
		svc.add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.94, 0.92, 0.86)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.86, 0.86, 0.78)
		e.ambient_light_energy = 0.5
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.environment = e
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.light_energy = 0.75
		sun.light_color = Color(1.0, 0.95, 0.86)
		sun.rotation_degrees = Vector3(-50, -30, 0)
		vp.add_child(sun)
		var fill := DirectionalLight3D.new()
		fill.light_energy = 0.3
		fill.rotation_degrees = Vector3(-18, 35, 0)
		vp.add_child(fill)
		var pet := HedgePetNode.new()
		pet.eye_style = style
		vp.add_child(pet)
		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		svc.gui_input.connect(_on_cell_input.bind(i - 1))
		box.add_child(svc)
		var label := Label.new()
		label.text = "%d  %s" % [i, style]
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		_grid.add_child(box)
		cells.append([vp, pet, cam, label, svc])
	for side in [-1, 1]:
		var b := Button.new()
		b.text = "‹" if side < 0 else "›"
		b.flat = true
		b.add_theme_font_size_override("font_size", 80)
		b.position = Vector2(40 if side < 0 else 960, 1740)
		b.size = Vector2(90, 120)
		b.pressed.connect(func() -> void: show_pet(pet_index + side))
		add_child(b)
	show_pet(0)


func show_pet(i: int) -> void:
	pet_index = posmod(i, roster.size())
	var p: CharacterArtProfile = roster[pet_index]
	_title.text = "%s the %s" % [p.pet_name, p.species]
	for c in cells:
		var pet: HedgePetNode = c[1]
		pet.setup(p)
		pet.set_detail("CLOSE", true)
		pet.look_point = Vector3.INF
		_frame(c)


## Frame the face: from in front and a little to the side, close on the head.
func _frame(c: Array) -> void:
	var pet: HedgePetNode = c[1]
	var cam: Camera3D = c[2]
	var head: Vector3 = pet.head.global_position
	var hr: Vector3 = pet.profile.regions["HEAD"]["radii"]
	var dist := hr.length() * 3.9
	cam.position = head + Vector3(0.8, 0.42, 0.55).normalized() * dist
	cam.look_at(head + Vector3(hr.x * 0.25, -hr.y * 0.12, 0), Vector3.UP)


func _process(_delta: float) -> void:
	for c in cells:
		(c[1] as HedgePetNode).look_point = (c[2] as Camera3D).global_position   # looking at you


func _on_cell_input(event: InputEvent, i: int) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	_focus = -1 if _focus == i else i
	for k in range(cells.size()):
		var svc: SubViewportContainer = cells[k][4]
		(svc.get_parent() as Control).visible = _focus == -1 or _focus == k
		svc.custom_minimum_size = Vector2(1032, 1420) if _focus == k else Vector2(336, 460)
	_grid.columns = 1 if _focus != -1 else 3


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			show_pet(pet_index - 1)
		elif event.keycode == KEY_RIGHT:
			show_pet(pet_index + 1)
