extends SceneTree

## Acceptance captures for the two woodland skybox compositions.
## DISPLAY=:0 godot --path . --script tools/capture_forest_vistas.gd --disable-vsync

const OUT := "/tmp/hedgepets-views"


func _init() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	var game: Node = garden.game
	game.pet_state[garden.roster[0].pet_name] = "resident"
	garden.set_pet_mode(game._node(garden.roster[0]), "roam", true)
	game.following = [garden.roster[0].pet_name]
	var woods: Node = garden.woods
	woods.build_now()
	woods.enter()
	await create_timer(1.5).timeout
	woods.set_process_unhandled_input(false)
	woods.land.view.get_texture().get_image().save_png("%s/forest_sky_raw.png" % OUT)
	var looks := {
		"forest_old_oak": ["oak", Vector3(woods.OAK_VIEW.x, 0, woods.OAK_VIEW.y), deg_to_rad(-9.0)],
		"forest_old_oak_left": ["oak", Vector3(woods.OAK_VIEW.x, 0, woods.OAK_VIEW.y).rotated(Vector3.UP, 0.7), deg_to_rad(-7.0)],
		"forest_mossy_fork": ["fork", Vector3(woods.FORK_VIEW.x, 0, woods.FORK_VIEW.y), deg_to_rad(1.0)],
		"forest_fork_east": ["fork", Vector3(1, 0, -0.2), deg_to_rad(-2.0)],
		"forest_hollow": ["hollow", Vector3(-1, 0, 0.1), deg_to_rad(0.0)],
		"forest_ridge": ["ridge", Vector3(woods.VIEW_DIR.x, 0, woods.VIEW_DIR.y), deg_to_rad(-6.0)],
	}
	for key: String in looks:
		var shot: Array = looks[key]
		woods._at = shot[0]
		var direction: Vector3 = shot[1]
		direction.y = 0.0
		woods._yaw = woods._heading_of(direction.normalized())
		woods._goal_yaw = woods._yaw
		woods._pitch = shot[2]
		woods._refresh_finds()
		woods._settle(Vector3.INF)
		await create_timer(1.2).timeout
		woods.land.view.get_texture().get_image().save_png("%s/%s_sky_raw.png" % [OUT, key])
		_shot(key)
	print("saved forest vistas to %s" % OUT)
	quit(0)
