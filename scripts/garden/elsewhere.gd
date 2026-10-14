class_name Elsewhere
extends Node3D

## A place away from the garden that you go to and come back from: the burrow den (den.gd), the woods (woods.gd).
## Each is built the first time you visit, far from the lawn, with its own camera, light and HUD (a title and a way
## back). While you're there the garden waits: its pets, game and hideouts don't process, its sun is off and its HUD
## hidden, and its sounds come through filtered. Pets you take along are borrowed - borrow() remembers where each one
## was, give_back() puts it back exactly - unless the place decides otherwise (a pet set down in the woods comes home
## beside you).
##
## A subclass fills in: _build() (once), _arrive() and _depart() (each visit), TITLE and MUFFLE_HZ.

var garden: Node3D
var inside := false
var cam: Camera3D
var _built := false
var _ui: CanvasLayer
var _title: Label
var _veil: ColorRect
var _borrowed: Array = []            # {node, transform, visible, parent}


func title_text() -> String:
	return ""


## How muffled the garden sounds from here (Hz of a low-pass; 0 = not at all), and how much quieter (dB).
func muffle() -> Vector2:
	return Vector2(0.0, 0.0)


func setup(g: Node3D) -> void:
	garden = g
	visible = false
	set_process(false)
	set_process_unhandled_input(false)
	_ui = CanvasLayer.new()
	_ui.layer = 6
	_ui.visible = false
	add_child(_ui)
	var back := Button.new()
	back.text = "⬆️  Back to the garden"
	back.flat = true
	back.add_theme_font_size_override("font_size", 40)
	back.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	back.position = Vector2(300, 1790)
	back.custom_minimum_size = Vector2(480, 100)
	back.pressed.connect(leave)
	_ui.add_child(back)
	_title = Label.new()
	_title.text = title_text()
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84, 0.85))
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 0.6))
	_title.add_theme_constant_override("outline_size", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 40)
	_title.size = Vector2(1080, 80)
	_ui.add_child(_title)
	var veil_layer := CanvasLayer.new()
	veil_layer.layer = 110
	add_child(veil_layer)
	_veil = ColorRect.new()
	_veil.color = Color(0.08, 0.06, 0.04, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil_layer.add_child(_veil)


func enter() -> void:
	if inside:
		return
	inside = true
	garden.game.save()
	var out := create_tween()
	out.tween_property(_veil, "color:a", 1.0, 0.35)
	await out.finished
	if _prebuilding:
		await _wait_for_prebuild()
	elif not _built:
		await _build_staged()
	await before_away()                                  # (the garden is still lit: a place can look back at it)
	pause_garden(true)
	visible = true
	cam.make_current()
	_ui.visible = true
	set_process(true)
	set_process_unhandled_input(true)
	_arrive()
	create_tween().tween_property(_veil, "color:a", 0.0, 0.45)


## The steps of building it, [words, Callable], with a loading card between them (empty: just _build()).
func build_steps() -> Array:
	return []


## Build it in the background, a few milliseconds a frame (Slicer), while you're in the garden: the garden loads,
## then the woods. Walk in before it's done and the loading card shows how far it's got (and it hurries).
signal prebuilt
var _prebuilding := false
var _pre_step := ""
var _pre_done := 0.0


func prebuild() -> void:
	if _built or _prebuilding:
		return
	_prebuilding = true
	var steps := build_steps()
	Slicer.active = true
	Slicer.budget_us = 5000
	for i in steps.size():
		_pre_step = str(steps[i][0])
		_pre_done = float(i) / steps.size()
		await (steps[i][1] as Callable).call()
		await get_tree().process_frame
	Slicer.active = false
	_built = true
	_prebuilding = false
	prebuilt.emit()


func _wait_for_prebuild() -> void:
	var card: CanvasLayer = preload("res://scripts/garden/loading_card.gd").new()
	card.note = loading_note()
	add_child(card)
	Slicer.budget_us = 40000                             # you're waiting: bigger slices (the card still moves)
	while _prebuilding:
		card.stage(_pre_step, _pre_done)
		await get_tree().process_frame
	card.finish()


## Build it all now, in one go (the bake, and checks that don't want to wait).
func build_now() -> void:
	if not _built:
		_built = true
		_build()


func _build_staged() -> void:
	_built = true
	var steps := build_steps()
	if steps.is_empty():
		_build()
		return
	var card: CanvasLayer = preload("res://scripts/garden/loading_card.gd").new()
	card.note = loading_note()
	add_child(card)
	for i in steps.size():
		card.stage(str(steps[i][0]), float(i) / steps.size())
		await get_tree().process_frame                     # let the card draw before the work
		await get_tree().process_frame
		(steps[i][1] as Callable).call()
	card.finish()


func loading_note() -> String:
	return "The first time takes a little while."


func leave() -> void:
	if not inside:
		return
	inside = false
	fade(func() -> void:
		set_process(false)
		set_process_unhandled_input(false)
		_ui.visible = false
		visible = false
		_depart()
		give_back()
		garden.camera.make_current()
		pause_garden(false))


func fade(swap: Callable, out := 0.35, back := 0.45) -> void:
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, out)
	tw.tween_callback(swap)
	tw.tween_property(_veil, "color:a", 0.0, back)


func pause_garden(on: bool) -> void:
	garden.set_process(not on)
	garden.set_process_unhandled_input(not on)
	for n: Node in [garden.game, garden.hideouts]:
		n.set_process(not on)
	garden.game.set_ui_visible(not on)
	for c in garden.get_children():
		if c is DirectionalLight3D:
			c.visible = not on
	var bus := AudioServer.get_bus_index("Master")
	var m := muffle()
	if on and m.x > 0.0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = m.x
		AudioServer.add_bus_effect(bus, lp)
	if on:
		AudioServer.set_bus_volume_db(bus, m.y)
	else:
		for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
				AudioServer.remove_bus_effect(bus, i)
		AudioServer.set_bus_volume_db(bus, 0.0)


## Take a garden pet along: remember exactly where (and how) it was.
func borrow(node: HedgePetNode) -> void:
	_borrowed.append({"node": node, "transform": node.transform, "visible": node.visible, "parent": node.get_parent()})
	node.visible = true
	node.scale = Vector3.ONE * garden.PET_SCALE


func is_borrowed(node: HedgePetNode) -> bool:
	return _borrowed.any(func(b) -> bool: return b["node"] == node)


## Keep a borrowed pet out of give_back (the place puts it somewhere itself).
func keep(node: HedgePetNode) -> void:
	_borrowed = _borrowed.filter(func(b) -> bool: return b["node"] != node)


func give_back() -> void:
	for b in _borrowed:
		var node: HedgePetNode = b["node"]
		if node.get_parent() != b["parent"]:
			node.reparent(b["parent"], false)
		node.set_sleeping(false)
		node.walking = 0.0
		node.look_point = Vector3.INF
		node.transform = b["transform"]
		node.visible = b["visible"]
	_borrowed.clear()


func _build() -> void:
	pass


## Just before the garden is put away (veiled; still lit and drawn).
func before_away() -> void:
	pass


func _arrive() -> void:
	pass


func _depart() -> void:
	pass


## The usual look for a place's sky-less environment.
static func dark_env(bg: Color, ambient: Color, energy: float) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return env
