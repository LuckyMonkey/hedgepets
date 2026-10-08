extends SceneTree

## Every pet from three-quarter and front: /tmp/hedgepets-views/pet_<name>_<view>.png
##   DISPLAY=:0 godot --path . --script tools/capture_pets.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Motion.speed = 0.0                   # captures and checks: every transition instant, results deterministic
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	var scene: Node = (load("res://main3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process_input(false)   # captures must not be turned by a live mouse on the window
	for i in range(scene.PETS.size()):
		scene._load_pet(i)
		for view in ["THREE_QUARTER", "FRONT"]:
			scene.set_view(view)
			scene._yaw = 0.0
			scene._yaw_velocity = 0.0
			for f in range(10):
				await process_frame
			print("%s %s yaw=%.2f vel=%.2f pressed=%s" % [scene.profile.pet_name, view, scene._yaw, scene._yaw_velocity, scene._press_at != Vector2.INF])
			root.get_texture().get_image().save_png("/tmp/hedgepets-views/pet_%s_%s.png" % [scene.profile.pet_name.to_lower(), view.to_lower()])
	print("saved pets")
	quit()
