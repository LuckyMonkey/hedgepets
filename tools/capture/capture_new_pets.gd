extends SceneTree

## Just the named pets, three-quarter view: /tmp/hedgepets-views/pet_<name>_three_quarter.png
##   PETS="Hedgerow,Moonbeam" xvfb-run -a godot --path . --script tools/capture/capture_new_pets.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Motion.speed = 0.0
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	var want := OS.get_environment("PETS").split(",", false)
	var scene: Node = (load("res://main3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process_input(false)
	for i in range(scene.PETS.size()):
		scene._load_pet(i)
		if not want.has(scene.profile.pet_name):
			continue
		scene.set_view("THREE_QUARTER")
		scene._yaw = 0.0
		scene._yaw_velocity = 0.0
		for f in range(10):
			await process_frame
		root.get_texture().get_image().save_png("/tmp/hedgepets-views/pet_%s_three_quarter.png" % scene.profile.pet_name.to_lower())
		print("saved ", scene.profile.pet_name)
	quit()
