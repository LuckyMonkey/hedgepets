extends SceneTree

## The garden, after a few seconds of life: /tmp/hedgepets-views/garden.png (and garden_raw.png without tilt-shift).
##   DISPLAY=:0 godot --path . --script tools/capture_garden.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Motion.speed = 0.0                   # captures and checks: every transition instant, results deterministic
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	var scene: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	if OS.get_environment("TARGET") != "":
		var v: PackedStringArray = OS.get_environment("TARGET").split(",")
		scene._goal_target = Vector3(float(v[0]), 0, float(v[1]))
		scene._target = scene._goal_target
	if OS.get_environment("YAW") != "":
		scene._yaw = deg_to_rad(float(OS.get_environment("YAW")))
		scene._goal_yaw = scene._yaw
	if OS.get_environment("DIST") != "":
		scene._distance = float(OS.get_environment("DIST"))
		scene._goal_distance = scene._distance
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
