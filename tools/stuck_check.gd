extends SceneTree

## Pets never get stuck: Gerald and eleven others live in the garden for 90 s (60 fps). A pet is STUCK when it is
## trying to walk somewhere (not standing, peeking or leaving) but gets no closer than ~0.3 m in 4 s: wobbling against
## something, spinning in place, or pinned. Also counts how walks end (arrived / close enough / gave up): fails if
## more than 15% are abandoned or any pet gives up more than 3 times in a row.
##   godot --headless --path . --script tools/stuck_check.gd --fixed-fps 60
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	Motion.speed = 1.0
	var game: Node = garden.game
	var n := 0
	for p: CharacterArtProfile in garden.roster:
		if n >= int(OS.get_environment("PETS")) if OS.get_environment("PETS") != "" else n >= 12:
			break
		game.pet_state[p.pet_name] = "resident"
		game._apply_mode(game._node(p), true)
		n += 1
	var best := {}        # pet -> [closest distance this window, time since it last got 0.3 m closer, target]
	var episodes: Array = []
	var walking_time := 0.0
	for f in range(60 * 90):
		await process_frame
		for node in garden.pets:
			if not node.visible:
				continue
			var w: Dictionary = garden._wander[node]
			var to: Vector3 = w["target"] - node.position
			to.y = 0.0
			if w["mode"] != "roam" or to.length() < 0.2:
				best.erase(node)
				continue
			walking_time += 1.0 / 60.0
			var b: Array = best.get(node, [to.length(), 0.0, w["target"]])
			if b[2] != w["target"]:
				b = [to.length(), 0.0, w["target"]]
			if to.length() < float(b[0]) - 0.3:
				b[0] = to.length()
				b[1] = 0.0
			else:
				b[1] = float(b[1]) + 1.0 / 60.0
			if float(b[1]) > 4.0:
				episodes.append("%s at (%.1f, %.1f) heading for (%.1f, %.1f)" % [node.profile.pet_name, node.position.x, node.position.z, w["target"].x, w["target"].z])
				b = [to.length(), -1e9, w["target"]]        # count each stuck stretch once
			best[node] = b
	var ws: Dictionary = garden.walk_stats
	var walks: int = ws["arrived"] + ws["close_enough"] + ws["gave_up"]
	print("walking: %.0f pet-seconds; stuck stretches: %d" % [walking_time, episodes.size()])
	print("walks ended: arrived %d, close enough %d, gave up %d (%.0f%%), most give-ups in a row %d" % [ws["arrived"], ws["close_enough"], ws["gave_up"], 100.0 * ws["gave_up"] / maxf(1, walks), ws["most_in_a_row"]])
	if ws["gave_up"] > walks * 0.15 or ws["most_in_a_row"] > 3:
		episodes.append("too many walks abandoned")
	for e in episodes.slice(0, 10):
		print("  STUCK ", e)
	if episodes.is_empty():
		print("PASS")
		quit(0)
	else:
		print("FAIL")
		quit(1)
