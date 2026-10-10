extends SceneTree

## Each place in the woods, facing what it's named for: the ridge's view, the creek, the old oak, the fern hollow,
## the mossy fork, the nursery (her at the bench, a line said).
##   DISPLAY=:0 godot --path . --script tools/capture_places.gd --disable-vsync   (writes /tmp/hedgepets-views)
func _init() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/%s.png" % name)


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
	var looks := {
		"ridge": Vector3(woods.VIEW_DIR.x, 0, woods.VIEW_DIR.y),
		"creek": Vector3(woods.CREEK_AT.x, 0, woods.CREEK_AT.y) - woods.node_pos("creek"),
		"oak": Vector3(woods._oak_at().x, 0, woods._oak_at().y) - woods.node_pos("oak"),
		"hollow": Vector3(1, 0, 0.3),
		"fork": Vector3(0.4, 0, -1),
		"trailhead": Vector3(1, 0, 0.6),
		"pond": Vector3(woods.POND_AT.x, 0, woods.POND_AT.y) - woods.node_pos("pond"),
		"cellar": Vector3(woods.CELLAR_AT.x, 0, woods.CELLAR_AT.y) - woods.node_pos("cellar"),
	}
	for id in looks:
		var d: Vector3 = looks[id]
		d.y = 0.0
		woods._at = id
		woods._yaw = woods._heading_of(d.normalized())
		woods._goal_yaw = woods._yaw
		woods._pitch = deg_to_rad(4.0) if id == "oak" else deg_to_rad(-6.0)
		woods._refresh_finds()
		woods._settle(Vector3.INF)
		await create_timer(1.2).timeout
		if id == "hollow":
			woods.campfire.tapped(game)
			await create_timer(0.8).timeout
		_shot("place_" + id)
	# the signs at the fork: facing the nursery's trail, and a little to one side
	woods._at = "fork"
	for k in range(2):
		woods._yaw = woods._heading_of(woods._way_to("nursery" if k == 0 else "ridge")["dir"]) + 0.25
		woods._goal_yaw = woods._yaw
		woods._pitch = deg_to_rad(-4.0)
		woods._settle(Vector3.INF)
		await create_timer(1.2).timeout
		_shot("sign_fork_%d" % k)
	# the nursery, walked into from the fork
	woods._at = "fork"
	woods.walk(woods._way_to("nursery"))
	while not woods._walking.is_empty():
		await process_frame
	await create_timer(1.5).timeout
	_shot("place_nursery")
	woods.nursery.talk()
	await create_timer(1.2).timeout
	_shot("place_nursery_talk")
	quit(0)
