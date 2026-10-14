extends SceneTree

## The world editor's acceptance test: move one existing thing, turn it, undo / redo, save, rebuild the garden the
## way the game does, and check it stayed where it was put and nothing else moved. Also: no overrides = the
## generated layout, exactly.
##   HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/world_editor_check.gd --fixed-fps 60
const PATH := "user://world_editor_check.tres"
const ID := "lawn_chair_5"
var fails := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _layout(things: Array) -> Dictionary:
	var out := {}
	for t in things:
		var n: Node3D = t["node"]
		out[t["id"]] = [n.position, snappedf(n.rotation.y, 0.0001), n.scale, t["at"], n.visible]
	return out


func _garden() -> Node:
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	if not g.is_built:
		await g.built
	return g


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	OS.set_environment("HEDGEPETS_WORLD", PATH)
	# a plain game garden with no override file: the generated layout
	var plain: Node = await _garden()
	var generated := _layout(plain.things)
	plain.queue_free()
	await process_frame
	var ed: Node = (load("res://world_editor.tscn") as PackedScene).instantiate()
	root.add_child(ed)
	if not ed.is_ready:
		await ed.ready_to_edit
	_check(_layout(ed.garden.things) == generated, "editor opens on exactly the generated layout (%d things)" % generated.size())
	var start: Vector3 = generated[ID][0]
	var moved := start + Vector3(1.25, 0, -0.75)
	ed.select(ID)
	ed.edit(ID, {"position": moved})
	var node: Node3D = ed.thing(ID)["node"]
	_check(node.position == moved, "edit moves the selected thing")
	ed.edit(ID, {"yaw": 1.0})
	_check(is_equal_approx(node.rotation.y, 1.0), "edit turns it")
	ed.undo()
	_check(is_equal_approx(node.rotation.y, generated[ID][1]) and node.position == moved, "undo takes back only the turn")
	ed.undo()
	_check(node.position == start, "undo again: back to generated")
	ed.redo()
	ed.redo()
	_check(node.position == moved and is_equal_approx(node.rotation.y, 1.0), "redo twice: moved and turned")
	ed.edit("rock_31", {"hidden": true})
	ed.edit("rock_31", null)
	_check(ed.thing("rock_31")["node"].visible and not ed.overrides.things.has("rock_31"), "hide then reset restores a thing")
	_check(ed.save() == OK, "save")
	ed.queue_free()
	await process_frame
	# the game builds the garden and applies the saved overrides
	var g: Node = await _garden()
	var after := _layout(g.things)
	_check(after.has(ID) and after[ID][0] == moved and is_equal_approx(after[ID][1], 1.0), "after reload %s is where it was put" % ID)
	var others := 0
	for id in generated:
		if id != ID and after.get(id) != generated[id]:
			others += 1
			print("  changed: %s %s -> %s" % [id, generated[id], after.get(id)])
	_check(others == 0, "nothing else moved")
	g.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("world_editor_check: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	quit(0 if fails == 0 else 1)
