extends SceneTree

## A walk down every trail in the woods, a frame every couple of metres: to see what's in the way, what it looks like
## on the move, and the wild hedgepets about. DISPLAY=:0 godot --path . --script tools/capture_walk.gd --disable-vsync
## Writes /tmp/hedgepets-views/walk_<edge>_<n>.png and prints anything solid the camera passes within 0.9 m of.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await create_timer(1.0).timeout
	var woods: Node = garden.woods
	woods.build_now()
	woods.enter()
	await create_timer(2.0).timeout
	woods.set_process_unhandled_input(false)
	var only := OS.get_environment("WALK_EDGES")
	for i in woods._paths.size():
		if only != "" and not only.split(",").has(str(i)):
			continue
		var e: Dictionary = woods._paths[i]
		woods._at = e["a"]
		woods._walking = {}
		woods.walk(woods._way_to(e["b"]))
		var n := 0
		var next := 0.0
		while not woods._walking.is_empty():
			await process_frame
			var s: float = woods._walking.get("s", 0.0)
			if s >= next:
				next += 2.5
				root.get_texture().get_image().save_png("/tmp/hedgepets-views/walk_%02d_%02d.png" % [i, n])
				n += 1
		print("edge %d %s -> %s: %d frames" % [i, e["a"], e["b"], n])
	quit(0)
