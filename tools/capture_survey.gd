extends SceneTree

## Pictures for the feedback survey (go.fridge.run/hedgepets/feedback): a garden with hedgepets in it, a dug row with
## plants coming up, and pouring water with a pet coming to it (the 💧 tool chosen, its chip and caption showing).
##   DISPLAY=:0 godot --path . --script tools/capture_survey.gd --disable-vsync   (writes /tmp/hedgepets-views/survey_*.png)
func _init() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/survey_%s.png" % name)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await create_timer(1.0).timeout
	var game: Node = garden.game
	game.coins = 120
	var o := Vector2.INF
	for z in range(0, 5):
		for x in range(-4, 3):
			if o == Vector2.INF and range(5).all(func(k) -> bool: return not garden._blocked(Vector2(x + k * 0.8, z), 0.6)):
				o = Vector2(x, z)
	Motion.speed = 0.0
	for k in range(5):
		game._shovel(o + Vector2(k * 0.7, 0.0))
	for k in range(4):
		game._plant(["lavender", "clover", "rose", "fern"][k], game.seedbeds[k], [3, 2, 3, 1][k])
	for i in range(1, 5):
		var p: CharacterArtProfile = garden.roster[i]
		game.pet_state[p.pet_name] = "resident"
		var n: HedgePetNode = game._node(p)
		garden.set_pet_mode(n, "roam", true)
		n.position = Vector3(o.x + randf_range(-2.5, 3.5), 0, o.y + randf_range(-3.0, -1.0))
	Motion.speed = 1.0
	garden._goal_target = Vector3(o.x + 1.4, 0, o.y - 1.0)
	garden._target = garden._goal_target
	await create_timer(3.0).timeout
	_shot("garden")
	game.tool = "water"
	game._refresh()
	var pet: HedgePetNode = game._node(garden.roster[1])
	var spot := Vector3(o.x + 1.0, 0, o.y - 2.0)
	pet.position = spot + Vector3(2.5, 0, 0)
	var scr: Vector2 = garden.camera.unproject_position(spot)
	game.pour_begin(scr)
	for k in range(90):
		await process_frame
		game.pour_move(garden.camera.unproject_position(spot + Vector3(sin(k * 0.05) * 1.2, 0, 0)))
	_shot("water")
	game.pour_end(true)
	quit(0)
