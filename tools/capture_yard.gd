extends SceneTree

## The garden's new bits: a dug row with its dirt pile and the wheelbarrow, the tool chip and caption with 💧 in hand,
## a lit fire pit, and the porch (the stairs at the gate, the man on the deck).
##   DISPLAY=:0 godot --path . --script tools/capture_yard.gd --disable-vsync   (writes /tmp/hedgepets-views)
func _init() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/%s.png" % name)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await create_timer(1.0).timeout
	Motion.speed = 0.0
	var game: Node = garden.game
	game.coins = 100
	var o := Vector2.INF
	for z in range(1, 6):
		for x in range(-3, 4):
			if o == Vector2.INF and range(5).all(func(k) -> bool: return not garden._blocked(Vector2(x + k * 0.8, z), 0.6)):
				o = Vector2(x, z)
	for k in range(5):
		game._shovel(o + Vector2(k * 0.7, 0.0))
	for k in range(3):
		game._plant(["lavender", "clover", "rose"][k], game.seedbeds[k], 3 - k)
	game._place("fire_pit", Vector2(-2.5, 4.5), 0.0)
	garden.things[-1]["node"].tapped(game)
	game.tool = "water"
	game._refresh()
	garden._goal_target = Vector3(o.x + 1.5, 0, o.y)
	garden._target = garden._goal_target
	await create_timer(2.0).timeout
	_shot("yard_row")
	var w: Node3D = garden.get_node("PorchWatcher")
	w._state = w.INSIDE
	w._wait = 0.0
	garden._goal_target = Vector3(-1.0, 0, 11.0)
	garden._target = garden._goal_target
	garden._goal_yaw += PI
	await create_timer(3.0).timeout
	_shot("yard_porch")
	quit(0)
