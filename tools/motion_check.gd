extends SceneTree

## No pops: drives every transition at a fixed 60 fps and fails if any watched value jumps between two frames by
## more than its limit (fraction of its range, per frame). Pet arrival/leaving, regraft, plant stage, pet switch in
## the viewer, camera pan/zoom, toast, coins.
##   godot --headless --path . --script tools/motion_check.gd --fixed-fps 60
var failures: Array = []
var watched: Array = []        # [label, Callable -> float, max step per frame]
var _last := {}


func _init() -> void:
	call_deferred("_run")


func watch(label: String, getter: Callable, max_step: float) -> void:
	watched.append([label, getter, max_step])
	_last[label] = getter.call()


func frames(n: int) -> void:
	for i in range(n):
		await process_frame
		for w in watched:
			var v: float = w[1].call()
			var step := absf(v - float(_last[w[0]]))
			if step > float(w[2]):
				failures.append("%s jumped %.3f in one frame (limit %.3f)" % [w[0], step, w[2]])
			_last[w[0]] = v


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 1.0
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	await frames(2)
	var game: Node = garden.game
	var gerald: HedgePetNode = game._node(garden.roster[0])
	var rest: float = garden.PET_SCALE
	watch("gerald scale", func() -> float: return gerald.scale.y / rest, 0.2)
	watch("gerald leaves", func() -> float: return gerald.leaf_growth, 0.12)
	watch("camera x", func() -> float: return garden.camera.position.x, 0.5)
	watch("camera distance", func() -> float: return garden._distance, 0.6)
	watch("toast alpha", func() -> float: return game._toast.modulate.a, 0.35)
	await frames(60)
	print("regraft…")
	gerald.set_plant("holly")
	await frames(90)
	print("camera pan + zoom…")
	garden._goal_target = Vector3(6, 0, 3)
	garden._goal_distance = 20.0
	await frames(90)
	print("a plant grows a stage…")
	var bed: Dictionary = game._dig(Vector2(1.5, 2.0))
	var pl: Dictionary = game._plant("clover", bed, 1)
	var holder: Node3D = pl["node"]
	await frames(40)
	pl["stage"] = 2
	game._build_plant(pl)
	var grown: Node3D = pl["node"]
	watch("plant size", func() -> float: return grown.scale.y * game.STAGE_SIZE[2] if is_instance_valid(grown) else 0.55, 0.06)
	await frames(60)
	print("a visitor arrives and leaves…")
	var clover_p: CharacterArtProfile = garden.roster.filter(func(p) -> bool: return p.pet_name == "Clover")[0]
	var clover: HedgePetNode = game._node(clover_p)
	garden.set_pet_mode(clover, "roam")
	watch("clover scale", func() -> float: return clover.scale.y / rest if clover.visible else 0.0, 0.25)
	await frames(80)
	garden.set_pet_mode(clover, "away")
	await frames(40)
	print("coins…")
	game.coins += 40
	game._refresh()
	watch("coins shown", func() -> float: return float(game._shown_coins), 6.0)
	await frames(60)
	print("viewer: switch pets, cycle plants…")
	garden.queue_free()
	watched.clear()
	var viewer: Node = (load("res://main3d.tscn") as PackedScene).instantiate()
	root.add_child(viewer)
	viewer.set_process_input(false)
	await frames(10)
	watch("viewer camera", func() -> float: return viewer.camera.position.length(), 0.35)
	watch("viewer pet scale", func() -> float: return viewer.pet_node.scale.y, 0.2)
	watch("viewer leaves", func() -> float: return viewer.pet_node.leaf_growth, 0.12)
	for i in range(3):
		viewer._load_pet(viewer.pet_index + 7)          # a very different pet each time
		await frames(70)
	viewer.next_plant()
	await frames(70)
	viewer._zoom = 1.6
	viewer._place_camera()
	await frames(50)
	if failures.is_empty():
		print("PASS: no pops (%d values watched)" % watched.size())
		quit(0)
	else:
		for f in failures.slice(0, 12):
			print("POP: ", f)
		print("FAIL: %d pops" % failures.size())
		quit(1)
