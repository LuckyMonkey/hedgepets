extends SceneTree

## The cost of a pet's first appearance: a visitor arriving at the fence, then the woods' wild hedgepets. Records
## every frame's time from the moment the pet node is made until it's whole (lazy) or made (baked); prints the
## worst frame and how long it took. GPU window:
##   HEDGEPETS_PETS_BAKED=starters|all godot --path . --audio-driver Dummy --resolution 540x960 --disable-vsync --script tools/visitor_stall.gd
func _init() -> void:
	call_deferred("_run")


func _frames_until(done: Callable, limit := 900) -> Array:
	var times: Array = []
	var last := Time.get_ticks_usec()
	var t0 := last
	for i in range(limit):
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		if done.call():
			break
	return [times, (Time.get_ticks_usec() - t0) / 1000.0]


func _report(what: String, r: Array, made_ms: float) -> void:
	var t: Array = r[0]
	var worst := made_ms
	for x in t:
		worst = maxf(worst, x)
	print("STALL %-26s node made in %6.1f ms | then %3d frames, %7.1f ms to whole | worst frame %6.1f ms" % [what, made_ms, t.size(), r[1], worst])


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	g.set_process_unhandled_input(false)
	for i in range(60):
		await process_frame
	var game: Node = g.game
	print("STALL mode ", HedgePetNode.pets_baked())
	for name in ["Spruce", "Monarch", "Tuppence"]:
		var p: CharacterArtProfile = null
		for q in g.roster:
			if q.pet_name == name:
				p = q
		var t0 := Time.get_ticks_usec()
		game.pet_state[name] = "noticed"
		var node: HedgePetNode = game._node(p)
		game._apply_mode(node)
		var made := (Time.get_ticks_usec() - t0) / 1000.0
		var r: Array = await _frames_until(func() -> bool: return not node.building)
		_report("visitor " + name, r, made)
	g.woods.build_now()
	var t1 := Time.get_ticks_usec()
	g.woods.enter()
	var r2: Array = await _frames_until(func() -> bool:
		if not g.woods.inside:
			return false
		for w: Dictionary in g.woods._wild:
			if (w["node"] as HedgePetNode).building:
				return false
		return g.woods._wild.size() > 0, 1200)
	_report("woods wild x%d" % g.woods._wild.size(), r2, 0.0)
	quit(0)
