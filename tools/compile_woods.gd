extends SceneTree

## Compile the woods' base map (see woods.gd "the compiled woods"): build them once live, keep a copy of what the
## static steps made (ground, trail beds, litter, the creek home, undergrowth) and the 1:16 land's world (not its
## clouds; trees are code-driven and never compiled), the
## generator state after each step, and a fingerprint of the generator code; save res://world/woods_compiled.scn.
## Needs a renderer (MultiMesh buffers):
##   xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . --script tools/compile_woods.gd
## Run after changing woods / tree / land / prop code (tools/deploy_web.sh does), or keep the old woods with
## res://world/woods.lock.
func _init() -> void:
	call_deferred("_run")


func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own(c, owner_node)


func _squeeze(m: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in m.get_surface_count():
		var arrays := m.surface_get_arrays(i)
		out.add_surface_from_arrays(m.surface_get_primitive_type(i), arrays, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		var mat := m.surface_get_material(i)
		if mat != null:
			out.surface_set_material(i, mat)
	return out


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_NO_COMPILED", "1")
	var t0 := Time.get_ticks_msec()
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	var w: Node3D = g.woods
	w.compiling = true
	w.build_now()
	var out := Node3D.new()
	out.name = "WoodsCompiled"
	var states := {}
	var count := 0
	for key in w.recorded:
		var group := Node3D.new()
		group.name = key
		out.add_child(group)
		for n: Node in w.recorded[key]["nodes"]:
			group.add_child(n)
			count += 1
		states[key] = w.recorded[key]["state"]
	var sky := Node3D.new()
	sky.name = "sky"
	out.add_child(sky)
	var world: Node3D = w.land.view.get_node("World").duplicate()
	for c in world.get_children():
		if c.has_meta("x0"):                             # the clouds: they drift, built live
			world.remove_child(c)
			c.free()
	sky.add_child(world)
	out.set_meta("stamp", w.source_stamp())
	out.set_meta("states", states)
	out.set_meta("trees_rejected", w.get_meta("trees_rejected", 0))
	_own(out, out)
	var ps := PackedScene.new()
	var err := ps.pack(out)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://world"))
		err = ResourceSaver.save(ps, w.COMPILED, ResourceSaver.FLAG_COMPRESS)
	var size := FileAccess.get_file_as_bytes(w.COMPILED).size() if err == OK else 0
	print("compiled woods: %d static nodes + the land's world, stamp %s, %s, %.1f MB, %d ms" % [count, out.get_meta("stamp"), error_string(err), size / 1048576.0, Time.get_ticks_msec() - t0])
	# read it back and time a build from it
	OS.set_environment("HEDGEPETS_NO_COMPILED", "")
	var g2: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g2)
	var t1 := Time.get_ticks_usec()
	g2.woods.build_now()
	print("woods built from it in %.0f ms (compiled used: %s)" % [(Time.get_ticks_usec() - t1) / 1000.0, g2.woods.compiled_used])
	quit(0 if err == OK and g2.woods.compiled_used else 1)
