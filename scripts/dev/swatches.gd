extends Control

## Developer tool: nine swatches, pick the best. The same pet nine times with one feature varied (the middle one is
## where it is now, four steps smaller and four larger around it). Click the best: it becomes the pet's setting, the
## grid re-centres on it with finer steps, and you hone in. Saved to res://pets/tuning.json, used everywhere.
##   godot --path . res://dev/swatches.tscn
## Keys: ← → pet · ↑ ↓ feature · R reset this feature · 1-9 pick. Buttons do the same.

var roster: Array = []                # base profiles (without tuning)
var tuning := {}
var pet_index := 0
var feature_index := 0
var step := 0.08
var cells: Array = []                 # [SubViewport, HedgePetNode, Camera3D, Label, value]
var _title: Label
var _sub: Label
var _queue: Array = []                # cells still to build (one per frame: the tool stays responsive)


func _ready() -> void:
	Motion.speed = 0.0
	tuning = SpeciesBuilder.load_tuning()
	var all: Array = []
	for p: CharacterArtProfile in CharacterArtProfile.roster():
		all.append(p)
	roster = all
	var bg := ColorRect.new()
	bg.color = Color(0.968, 0.945, 0.89)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title = _label(Vector2(0, 20), 40)
	_sub = _label(Vector2(0, 76), 26)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(24, 128)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for i in range(9):
		var box := VBoxContainer.new()
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.custom_minimum_size = Vector2(336, 440)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		svc.add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.94, 0.92, 0.86) if i != 4 else Color(0.9, 0.93, 0.84)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.86, 0.86, 0.78)
		e.ambient_light_energy = 0.5
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.environment = e
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.light_energy = 0.75
		sun.rotation_degrees = Vector3(-50, -30, 0)
		vp.add_child(sun)
		var pet := HedgePetNode.new()
		vp.add_child(pet)
		var cam := Camera3D.new()
		cam.fov = 34.0
		vp.add_child(cam)
		svc.gui_input.connect(_on_cell_input.bind(i))
		box.add_child(svc)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		grid.add_child(box)
		cells.append([vp, pet, cam, label, 1.0])
	var bar := HBoxContainer.new()
	bar.position = Vector2(24, 1560)
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	for b: Array in [["‹ pet", func() -> void: _pet(-1)], ["pet ›", func() -> void: _pet(1)], ["‹ feature", func() -> void: _feature(-1)],
			["feature ›", func() -> void: _feature(1)], ["reset", _reset]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", 30)
		btn.custom_minimum_size = Vector2(196, 90)
		btn.pressed.connect(b[1])
		bar.add_child(btn)
	_refresh()


func _label(at: Vector2, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = at
	l.size = Vector2(1080, 50)
	add_child(l)
	return l


func _base(i: int) -> CharacterArtProfile:
	# the pet without its tuning, rebuilt from source
	var name: String = roster[i].pet_name
	for f in ["gerald", "clover", "juniper", "bramble", "spruce", "hazel", "smudge"]:
		if name.to_lower() == f:
			return Callable(CharacterArtProfile, f).call()
	for p: CharacterArtProfile in SpeciesBuilder.load_all():
		if p.pet_name == name:
			return p
	return roster[i]


func _feature_name() -> String:
	return SpeciesBuilder.FEATURES[feature_index]


func _current() -> Variant:
	var t: Dictionary = tuning.get(roster[pet_index].pet_name, {})
	var f := _feature_name()
	if f == "plant":
		return t.get(f, SpeciesBuilder.native_plant(_base(pet_index)))
	return float(t.get(f, 0.0 if f == "hue" else 1.0))


func _values() -> Array:
	var f := _feature_name()
	var c = _current()
	if f == "plant":
		var plants: Array = SpeciesBuilder.PLANTS.keys()
		var at: int = plants.find(c)
		var out: Array = []
		for k in range(-4, 5):
			out.append(plants[posmod(at + k, plants.size())])
		return out
	var out: Array = []
	for k in range(-4, 5):
		out.append(float(c) + k * (step * 0.5 if f == "hue" else step))
	return out


func _refresh() -> void:
	var p: CharacterArtProfile = roster[pet_index]
	_title.text = "%s the %s" % [p.pet_name, p.species]
	_sub.text = "%s  (step %s)  · click the best · ← → pet · ↑ ↓ feature · R reset" % [_feature_name(), ("%.3f" % step) if _feature_name() != "plant" else "-"]
	var vals := _values()
	_queue.clear()
	for i in range(9):
		cells[i][4] = vals[i]
		(cells[i][3] as Label).text = ("%d  %s" % [i + 1, vals[i]]) if vals[i] is String else ("%d  ×%.2f" % [i + 1, vals[i]] if _feature_name() != "hue" else "%d  %+.3f" % [i + 1, vals[i]])
		_queue.append(i)


func _process(_delta: float) -> void:
	if _queue.is_empty():
		return
	var i: int = _queue.pop_front()
	var t: Dictionary = (tuning.get(roster[pet_index].pet_name, {}) as Dictionary).duplicate()
	t[_feature_name()] = cells[i][4]
	var prof := SpeciesBuilder.tune(_base(pet_index), t)
	var pet: HedgePetNode = cells[i][1]
	pet.setup(prof)
	pet.set_detail("CLOSE", true)
	var cam: Camera3D = cells[i][2]
	cam.position = prof.frame_target + Vector3(0.55, 0.42, 0.72).normalized() * prof.frame_distance * 1.3
	cam.look_at(prof.frame_target, Vector3.UP)
	pet.look_point = cam.global_position


func _on_cell_input(event: InputEvent, i: int) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		_pick(i)


func _pick(i: int) -> void:
	var name: String = roster[pet_index].pet_name
	var t: Dictionary = tuning.get(name, {})
	t[_feature_name()] = cells[i][4]
	tuning[name] = t
	if _feature_name() != "plant":
		step *= 0.6 if i != 4 else 0.5                    # hone in: finer steps around the pick
	_save()
	_refresh()


func _save() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(SpeciesBuilder.TUNING_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(tuning, "\t", true))


func _pet(d: int) -> void:
	pet_index = posmod(pet_index + d, roster.size())
	step = 0.08
	_refresh()


func _feature(d: int) -> void:
	feature_index = posmod(feature_index + d, SpeciesBuilder.FEATURES.size())
	step = 0.08
	_refresh()


func _reset() -> void:
	var name: String = roster[pet_index].pet_name
	var t: Dictionary = tuning.get(name, {})
	t.erase(_feature_name())
	tuning[name] = t
	step = 0.08
	_save()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_LEFT: _pet(-1)
		KEY_RIGHT: _pet(1)
		KEY_UP: _feature(-1)
		KEY_DOWN: _feature(1)
		KEY_R: _reset()
		_:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				_pick(event.keycode - KEY_1)
