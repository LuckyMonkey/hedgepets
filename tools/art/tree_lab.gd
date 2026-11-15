@tool
extends Node3D

## The tree lab: every kind of woods tree, near and in a far stand, built exactly as the woods build them
## (TreeFactory.plan + TreeFactory.build_batch). Open tools/art/tree_lab.tscn in the editor and change the values
## on the root node; the trees rebuild. The output panel prints what each tree costs (leaf cards, triangles).
##
## Headless snapshot for review:
##   DISPLAY=:77 godot --path . --audio-driver Dummy res://tools/art/tree_lab.tscn -- --shot=/tmp/tree_lab.png

@export var seed := 1:
	set(value):
		seed = value
		_dirty = true
@export_range(0, 120, 1) var far_trees := 60:
	set(value):
		far_trees = value
		_dirty = true

var _dirty := true
var _frames := 0


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	if _dirty:
		_rebuild()
	_frames += 1
	if _frames == 20 and not Engine.is_editor_hint():
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shot="):
				get_viewport().get_texture().get_image().save_png(a.trim_prefix("--shot="))
				get_tree().quit()


func _rebuild() -> void:
	_dirty = false
	for child in get_children():
		if child.name.begins_with("Lab_"):
			child.free()
	var near: Array = []
	var x := -9.0
	var total := {"cards": 0, "triangles": 0}
	var shown := 0
	for kind: String in TreeFactory.KINDS:
		if TreeFactory.KINDS[kind]["build"] == "crown":      # a crown only (the willow): shown on a bare pole
			var pl := TreeFactory.crown(kind, Vector3(x, 6.0, 0), seed)
			pl["limbs"] = [[Vector3(x, 0, 0), Vector3(x, 6.0, 0), 0.3, 0.2]]
			near.append(pl)
			x += 2.6
			continue
		for i in range(2):
			var pl := TreeFactory.plan(kind, Vector3(x, 0, 0), seed * 100 + i)
			var c := TreeFactory.cost(pl)
			print("tree lab: %-6s %-8s %5d leaf cards %6d triangles" % [kind, pl["palette"], c["cards"], c["triangles"]])
			total["cards"] += c["cards"]
			total["triangles"] += c["triangles"]
			near.append(pl)
			shown += 1
			x += 2.6
	_add("Lab_Near", TreeFactory.build_batch(near, Vector3.ZERO))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var far: Array = []
	var kinds: Array = TreeFactory.KINDS.keys().filter(func(k: String) -> bool: return TreeFactory.KINDS[k]["build"] != "crown")
	for i in range(far_trees):
		var p := Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-70, -22))
		far.append(TreeFactory.plan(kinds[i % kinds.size()], p, seed * 1000 + i))
	_add("Lab_Far", TreeFactory.build_batch(far, Vector3(0, 0, -45)))
	print("tree lab: %d near trees: %d cards, %d triangles (%.0f per tree)" % [shown, total["cards"], total["triangles"], total["triangles"] / float(shown)])


func _add(name_: String, nodes: Array[Node3D]) -> void:
	var holder := Node3D.new()
	holder.name = name_
	add_child(holder)
	for n in nodes:
		holder.add_child(n)
