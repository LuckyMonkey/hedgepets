extends SceneTree

## The garden, after a few seconds of life: /tmp/hedgepets-views/garden.png (and garden_raw.png without tilt-shift).
##   DISPLAY=:0 godot --path . --script tools/capture_garden.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	var scene: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	if OS.get_environment("DIST") != "":
		scene._distance = float(OS.get_environment("DIST"))
		scene._place_camera()
	for i in range(int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 90):
		await process_frame
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/garden.png")
	scene.get_node("TiltShift").visible = false
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/garden_raw.png")
	print("saved garden")
	quit()
