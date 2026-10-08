extends SceneTree

## Every pet in the roster, three-quarter view: /tmp/hedgepets-views/roster/<nn>_<name>.png
## (then: python3 tools/roster_sheet.py -> docs/acceptance/roster.png)
##   DISPLAY=:0 godot --path . --script tools/capture_roster.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Motion.speed = 0.0                   # captures and checks: every transition instant, results deterministic
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views/roster")
	var scene: Node = (load("res://main3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process_input(false)
	for i in range(scene.PETS.size()):
		scene._load_pet(i)
		scene.set_view("THREE_QUARTER")
		scene._yaw = 0.0
		scene._yaw_velocity = 0.0
		for f in range(6):
			await process_frame
		root.get_texture().get_image().save_png("/tmp/hedgepets-views/roster/%02d_%s.png" % [i, scene.profile.pet_name.to_lower()])
	print("saved roster %d" % scene.PETS.size())
	quit()
