extends SceneTree

## Frames of the staged loading card, the burrow den (two residents asleep) and the new things to build.
##   HEDGEPETS_STAGED=1 godot --path . --script tools/capture_den.gd     (needs a display; writes /tmp/hedgepets-views)
func _init() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/%s.png" % name)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_HOUR", "16.5")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	for k in range(6):
		await process_frame
	_shot("loading")
	if not garden.is_built:
		await garden.built
	await create_timer(1.0).timeout
	var game: Node = garden.game
	for i in range(3):
		game.pet_state[garden.roster[i].pet_name] = "resident"
	var x := -3.0
	for kind in ["scarecrow", "hay", "lantern", "stones", "bucket", "planter", "chair"]:
		game._place(kind, Vector2(x, 2.0), -20.0, false)
		x += 1.4
	garden._goal_target = Vector3(1.0, 0, 2.0)
	garden._goal_distance = 9.0
	await create_timer(2.5).timeout
	_shot("builds")
	garden.den.enter()
	await create_timer(3.0).timeout
	_shot("den")
	quit(0)
