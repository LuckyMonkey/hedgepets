extends Node

## The HedgePets world editor (MVP): the real garden, built by the real code, with authored overrides on top.
##   godot --path . res://world_editor.tscn
## The garden is generated exactly as in the game; edits are stored by stable id in WorldOverrides
## (res://world/garden_overrides.tres) and applied to the built objects, so nothing else in the world moves.
##
## Controls: click a thing to select it (or pick it in the list) · drag it to move · [ ] turn 15° · - = scale ·
## Delete hides it · R resets it to the generated layout · G toggles the 0.25 m grid · Ctrl+Z / Ctrl+Y undo / redo ·
## Ctrl+S saves · wheel zooms · right-drag pans · WASD / QE / RF move the camera (the garden's own keys).

const GRID := 0.25
const TURN := PI / 12.0

var garden: Node
var overrides: WorldOverrides
var selected := ""
var snap := true
var _orig := {}                    # id -> {position, yaw, scale} as generated
var _undo: Array = []              # [id, before (Dictionary or null), after (Dictionary or null)]
var _redo: Array = []
var _dragging := false
var _drag_from := Vector3.ZERO
var _drag_start := {}
var _list: ItemList
var _info: Label
var _ring: MeshInstance3D
var dirty := false
signal ready_to_edit
var is_ready := false


func _ready() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")        # the editor never reads or writes the player's save
	Motion.speed = 0.0
	overrides = WorldOverrides.current()
	var keep := OS.get_environment("HEDGEPETS_WORLD")
	OS.set_environment("HEDGEPETS_WORLD", "res://world/__generated__.tres")   # no such file: build it as generated
	garden = (load("res://garden.tscn") as PackedScene).instantiate()
	add_child(garden)
	if not garden.is_built:
		await garden.built
	OS.set_environment("HEDGEPETS_WORLD", keep)
	garden.set_process_unhandled_input(false)
	if garden.game != null:
		garden.game.set_process_unhandled_input(false)
		garden.game.set_process(false)                # no wishes, toasts or saves while editing
	for t in garden.things:
		var n: Node3D = t["node"]
		_orig[t["id"]] = {"position": n.position, "yaw": n.rotation.y, "scale": n.scale, "at": t["at"]}
	for id in overrides.things:                       # then the authored layer, exactly as the game applies it
		_put(str(id), overrides.things[id])
	dirty = false
	_build_ui()
	_refresh_list()
	is_ready = true
	ready_to_edit.emit()


func thing(id: String) -> Dictionary:
	for t in garden.things:
		if t["id"] == id:
			return t
	return {}


## The transform an id has now (override or generated).
func current(id: String) -> Dictionary:
	var o: Dictionary = _orig.get(id, {}).duplicate()
	o.erase("at")
	if overrides.things.has(id):
		o.merge(overrides.things[id], true)
	return o


func select(id: String) -> void:
	selected = id
	var t := thing(id)
	if t.is_empty():
		_ring.visible = false
	else:
		_ring.visible = true
		_ring.position = (t["node"] as Node3D).position + Vector3(0, 0.03, 0)
		_ring.scale = Vector3.ONE * maxf(float(t["radius"]), 0.4)
	_show_info()


## One edit, undoable: merge `changes` into the thing's override (null = back to generated).
func edit(id: String, changes: Variant) -> void:
	var before = overrides.things.get(id)
	var after = null
	if changes != null:
		after = (before.duplicate() if before != null else {})
		after.merge(changes, true)
	_put(id, after)
	_undo.append([id, before, after])
	_redo.clear()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var e: Array = _undo.pop_back()
	_put(e[0], e[1])
	_redo.append(e)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var e: Array = _redo.pop_back()
	_put(e[0], e[2])
	_undo.append(e)
	return true


func _put(id: String, o: Variant) -> void:
	var t := thing(id)
	if t.is_empty():
		return
	if o == null:
		overrides.things.erase(id)
	else:
		overrides.things[id] = o
	var node: Node3D = t["node"]
	var g: Dictionary = _orig[id]                      # always from the generated transform: edits never accumulate
	node.position = g["position"]
	node.rotation.y = g["yaw"]
	node.scale = g["scale"]
	t["at"] = g["at"]
	node.visible = true
	t["hidden"] = false
	if o != null:
		WorldOverrides.apply_one(t, o)
	dirty = true
	if id == selected:
		select(id)
	_refresh_list()


func save(path := "") -> Error:
	var err := WorldOverrides.save_to(overrides, path)
	if err == OK:
		dirty = false
	_show_info("saved" if err == OK else "save failed: " + error_string(err))
	return err


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			garden._zoom_by(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			garden._zoom_by(1.1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var p: Vector3 = garden.ground_point(mb.position)
				var id := _pick(Vector2(p.x, p.z))
				select(id)
				if id != "":
					_dragging = true
					_drag_from = p
					_drag_start = current(id)
			elif _dragging:
				_dragging = false
				var t := thing(selected)
				if not t.is_empty():
					var now: Vector3 = (t["node"] as Node3D).position
					(t["node"] as Node3D).position = _drag_start["position"]
					if now != _drag_start["position"]:
						edit(selected, {"position": now})
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			garden._pan_by(mm.relative)
		elif _dragging and selected != "":
			var p: Vector3 = garden.ground_point(mm.position)
			var to: Vector3 = _drag_start["position"] + (p - _drag_from)
			if snap:
				to = Vector3(snappedf(to.x, GRID), to.y, snappedf(to.z, GRID))
			(thing(selected)["node"] as Node3D).position = to
			_ring.position = to + Vector3(0, 0.03, 0)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.ctrl_pressed and k.keycode == KEY_Z:
			redo() if k.shift_pressed else undo()
		elif k.ctrl_pressed and k.keycode == KEY_Y:
			redo()
		elif k.ctrl_pressed and k.keycode == KEY_S:
			save()
		elif k.keycode == KEY_G:
			snap = not snap
			_show_info()
		elif selected != "":
			var c := current(selected)
			match k.keycode:
				KEY_BRACKETLEFT: edit(selected, {"yaw": float(c["yaw"]) + TURN})
				KEY_BRACKETRIGHT: edit(selected, {"yaw": float(c["yaw"]) - TURN})
				KEY_MINUS: edit(selected, {"scale": c["scale"] * 0.9})
				KEY_EQUAL: edit(selected, {"scale": c["scale"] / 0.9})
				KEY_DELETE: edit(selected, {"hidden": not c.get("hidden", false)})
				KEY_R: edit(selected, null)


func _pick(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for t in garden.things:
		var d: float = p.distance_to(Vector2((t["node"] as Node3D).position.x, (t["node"] as Node3D).position.z))
		if d < maxf(float(t["radius"]), 0.5) and d < best_d:
			best = t["id"]
			best_d = d
	return best


# ------------------------------------------------------------------ ui
func _build_ui() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.3)
	m.no_depth_test = true
	ring.material = m
	_ring = MeshInstance3D.new()
	_ring.mesh = ring
	_ring.visible = false
	add_child(_ring)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.custom_minimum_size = Vector2(300, 520)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "World editor"
	box.add_child(title)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(290, 360)
	_list.item_selected.connect(func(i: int) -> void: select(str(_list.get_item_metadata(i))))
	box.add_child(_list)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size = Vector2(290, 120)
	box.add_child(_info)
	_show_info()


func _refresh_list() -> void:
	if _list == null:
		return
	_list.clear()
	var ids: Array = _orig.keys()
	ids.sort()
	for id in ids:
		var mark := "* " if overrides.things.has(id) else "  "
		var i := _list.add_item(mark + str(id))
		_list.set_item_metadata(i, id)
		if id == selected:
			_list.select(i)


func _show_info(note := "") -> void:
	if _info == null:
		return
	var s := "%d overrides%s · grid %s\n" % [overrides.things.size(), " (unsaved)" if dirty else "", "on" if snap else "off"]
	if selected != "":
		var c := current(selected)
		s += "%s\npos %s\nyaw %.0f° scale %s%s\n" % [selected, c["position"], rad_to_deg(float(c["yaw"])), c["scale"], " HIDDEN" if c.get("hidden", false) else ""]
	_info.text = s + note
