extends SceneTree

## Frames per second at each detail level (3 s each), and how many leaves are built.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(10):
		await process_frame
	var leaves := 0
	for node in scene.foliage_nodes:
		leaves += node.multimesh.instance_count
	scene.auto_detail = false
	for level in ["CLOSE", "MEDIUM", "FAR"]:
		scene.set_detail(level)
		var t0 := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec() - t0 < 3000000:
			await process_frame
			frames += 1
		print("%s: %.0f fps (%.1f ms/frame cpu+gpu)" % [level, frames / 3.0, 3000.0 / frames])
	print("leaves built: %d" % leaves)
	quit()
