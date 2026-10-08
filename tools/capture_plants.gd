extends SceneTree

## One pet in every plant (SpeciesBuilder.PLANTS): /tmp/hedgepets-views/plants/<pet>_<plant>.png
##   PET=0 DISPLAY=:0 godot --path . --script tools/capture_plants.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views/plants")
	var scene: Node = (load("res://main3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process_input(false)
	scene._load_pet(int(OS.get_environment("PET")) if OS.get_environment("PET") != "" else 0)
	var i := 0
	for plant in SpeciesBuilder.PLANTS:
		scene.pet_node.set_plant(plant)
		scene._show_plant()
		scene._yaw = 0.0
		scene._yaw_velocity = 0.0
		for f in range(40):
			await process_frame
		root.get_texture().get_image().save_png("/tmp/hedgepets-views/plants/%02d_%s.png" % [i, plant])
		i += 1
	print("saved plants")
	quit()
