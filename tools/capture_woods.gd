extends SceneTree

## Frames of the woods: the trailhead on arrival (a follower, a pet in the bucket), mid-walk, the mossy fork facing
## the nursery's trail.  godot --path . --script tools/capture_woods.gd --disable-vsync   (writes /tmp/hedgepets-views)
func _init() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/%s.png" % name)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	await process_frame
	var game: Node = garden.game
	game.coins = 50
	for i in range(2):
		game.pet_state[garden.roster[i].pet_name] = "resident"
		garden.set_pet_mode(game._node(garden.roster[i]), "roam", true)
	game.following = [garden.roster[0].pet_name]
	game._place("bucket", Vector2(-3.0, 2.0), 0.0)
	var bt: Dictionary = garden.things[-1]
	var nb: HedgePetNode = game._node(garden.roster[1])
	nb.position = bt["node"].position + Vector3(1.0, 0, 0)
	game._lure(Vector2(bt["node"].position.x, bt["node"].position.z))
	await create_timer(2.0).timeout
	game.pick_up_bucket(bt)
	await create_timer(1.5).timeout
	garden.woods.build_now()
	garden.woods.enter()
	await create_timer(2.0).timeout
	_shot("woods_trailhead")
	garden.woods._goal_yaw += 2.4
	await create_timer(1.0).timeout
	_shot("woods_look")
	garden.woods._goal_yaw -= 2.4
	await create_timer(0.8).timeout
	garden.woods.walk(garden.woods.facing())
	await create_timer(3.5).timeout
	_shot("woods_walk")
	while not garden.woods._walking.is_empty():
		await process_frame
	await create_timer(1.5).timeout
	_shot("woods_fork")
	quit(0)
