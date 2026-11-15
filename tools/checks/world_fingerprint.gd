extends SceneTree

## Proof that a refactor changed nothing in the world.
##
## Builds the garden and the woods exactly as the game does, then writes one line per node: its path, type, rounded
## transform, and the size of its mesh or multimesh. Run it on the commit before a refactor and on the refactor,
## then diff the two files. Identical files mean the same world: every tree, rock and leaf batch in the same place.
## This is stronger than comparing screenshots for code moves, and it needs no display.
##
##   HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/checks/world_fingerprint.gd -- out.txt
##
## Left out on purpose: the pets and butterflies (they move from the first frame, on the global RNG) and anything that
## follows the clock (the sun, its light shafts, the camera), which would differ between two runs of the same code.

const SKIP_TYPES := ["Camera3D", "DirectionalLight3D", "WorldEnvironment", "AudioStreamPlayer", "AudioStreamPlayer3D", "Timer"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "/tmp/hedgepets-fingerprint.txt"
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	while not garden.is_built:
		await process_frame
	var lines: PackedStringArray = []
	_walk(garden, garden, lines, garden.woods)
	var woods: Node = garden.woods
	if woods != null and woods.has_method("build_now"):
		woods.build_now()
		await process_frame
		lines.append("== woods")
		_walk(woods, woods, lines, null)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("fingerprint: %d nodes, hash %s -> %s" % [lines.size(), "\n".join(lines).sha256_text().substr(0, 16), out_path])
	quit(0)


func _walk(n: Node, top: Node, lines: PackedStringArray, skip: Node) -> void:
	if n == skip or n is HedgePetNode or n.get_class() in SKIP_TYPES or _is_butterfly(n):
		return
	var line := "%s %s" % [top.get_path_to(n), n.get_class()]
	if n is Node3D:
		var t: Transform3D = (n as Node3D).transform
		line += " " + _r(t.origin) + " " + _r(t.basis.x) + " " + _r(t.basis.y) + " " + _r(t.basis.z)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		line += " surfaces=%d aabb=%s" % [m.get_surface_count(), _r(m.get_aabb().size)]
	if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		line += " instances=%d" % mm.instance_count
		if mm.instance_count > 0:
			line += " first=" + _r(mm.get_instance_transform(0).origin) + " last=" + _r(mm.get_instance_transform(mm.instance_count - 1).origin)
	lines.append(line)
	for c in n.get_children():
		_walk(c, top, lines, skip)


func _r(v: Vector3) -> String:
	return "(%.3f,%.3f,%.3f)" % [v.x, v.y, v.z]


func _is_butterfly(n: Node) -> bool:
	var s: Script = n.get_script()
	return s != null and s.resource_path.ends_with("butterfly.gd") or str(n.name).begins_with("LightShaft")
