extends SceneTree

## Would a compiled woods load faster? Builds the woods as the game does (from the bake cache), then packs its static
## geometry (merged props, tree patches, ground, trails, litter, undergrowth: everything that never moves) into a
## PackedScene, saves it, and times loading + instancing it against the build. Needs a renderer (MultiMesh buffers):
##   xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . --script tools/woods_compile_probe.gd
const OUT := "user://woods_compiled_probe.scn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	var w: Node3D = g.woods
	var t0 := Time.get_ticks_usec()
	w.build_now()
	var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var keep := {}
	for n in w._fireflies + w._willows_sway:
		keep[n] = true
	for f: Dictionary in w._finds:
		keep[f["node"]] = true
	var pack_root := Node3D.new()
	pack_root.name = "WoodsStatic"
	var moved := 0
	for n in w.get_children():
		if keep.has(n) or not (n is MeshInstance3D or n is MultiMeshInstance3D or str(n.name) == "MergedProps"):
			continue
		if not n.get_meta_list().is_empty() or not (n as Node3D).visible:
			continue
		var d: Node = n.duplicate()
		pack_root.add_child(d)
		moved += 1
	for d in pack_root.find_children("*", "", true, false):
		d.owner = pack_root
	var ps := PackedScene.new()
	var err := ps.pack(pack_root)
	var t1 := Time.get_ticks_usec()
	err = ResourceSaver.save(ps, OUT, ResourceSaver.FLAG_COMPRESS)
	var save_ms := (Time.get_ticks_usec() - t1) / 1000.0
	var size := FileAccess.get_file_as_bytes(OUT).size()
	var t2 := Time.get_ticks_usec()
	var back := ResourceLoader.load(OUT, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var load_ms := (Time.get_ticks_usec() - t2) / 1000.0
	var t3 := Time.get_ticks_usec()
	var inst := back.instantiate()
	root.add_child(inst)
	var inst_ms := (Time.get_ticks_usec() - t3) / 1000.0
	print("PROBE woods build (cached): %.0f ms | static nodes packed: %d | save %s %.0f ms, %.1f MB | load %.0f ms + instance %.0f ms" % [build_ms, moved, error_string(err), save_ms, size / 1048576.0, load_ms, inst_ms])
	quit(0)
