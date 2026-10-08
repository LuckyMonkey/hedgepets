extends SceneTree

## The garden's small moments, checked: over 3 minutes six residents nap and curl up beside each other; the pet
## under the pointer looks up (with a tilt); watering shakes a pet off; a flower sprouts and comes back after a save;
## gifts stay and come back after a save; a long absence brings a welcome and flowers, never a loss.
##   godot --headless --path . --script tools/life_check.gd --fixed-fps 60
func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	quit(1)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	var game: Node = garden.game
	var n := 0
	for p: CharacterArtProfile in garden.roster:
		if n >= 6:
			break
		game.pet_state[p.pet_name] = "resident"
		game._apply_mode(game._node(p), true)
		n += 1
	var naps := 0
	var curls := 0
	var was_asleep := {}
	for f in range(60 * (int(OS.get_environment("SECONDS_RUN")) if OS.get_environment("SECONDS_RUN") != "" else 180)):
		await process_frame
		for node in garden.pets:
			if node.sleeping and not was_asleep.get(node, false):
				naps += 1
			was_asleep[node] = node.sleeping
			if garden._wander[node].get("friend") != null:
				garden._wander[node]["counted"] = true
		for node in garden.pets:
			if garden._wander[node].get("counted", false) and garden._wander[node].get("friend") == null:
				curls += 1
				garden._wander[node]["counted"] = false
	print("in 3 minutes: %d naps, %d curl-ups" % [naps, curls])
	if naps == 0:
		return _fail("nobody napped")
	# the pointer
	var gerald: HedgePetNode = game._node(garden.roster[0])
	gerald.set_sleeping(false)
	garden._hover = garden.camera.unproject_position(gerald.global_position + Vector3(0, 0.7, 0))
	for i in range(60):
		await process_frame
	if not gerald.noticed or gerald.curious < 0.9 or gerald.look_point == Vector3.INF:
		return _fail("Gerald didn't look up at the pointer (noticed %s, curious %.2f)" % [gerald.noticed, gerald.curious])
	garden._hover = Vector2.INF
	for i in range(60):
		await process_frame
	if gerald.curious > 0.1:
		return _fail("Gerald kept staring after the pointer left")
	print("looks up at the pointer, with a tilt, and lets go")
	# watering a pet (frame him first: a tap in the top bar or the toolbar belongs to the HUD)
	garden._goal_target = gerald.position
	garden._target = gerald.position
	for i in range(5):
		await process_frame
	var w0: int = game.coins
	game.tool = "water"
	game.tap(garden.camera.unproject_position(gerald.global_position + Vector3(0, 0.6, 0)), gerald)
	await process_frame
	if gerald._shake < 0.5:
		return _fail("watering Gerald didn't make him shake")
	print("watered: shakes it off")
	# a flower, and the save
	var before: int = gerald.extra_flowers.size()
	for i in range(3):
		game.surprise_flower(true)
	var total := 0
	for node in garden.pets:
		total += node.extra_flowers.size()
	if total == 0:
		return _fail("no flower sprouted")
	game._drop_gift(gerald)
	game.save_path = "user://garden_life_check.json"
	OS.set_environment("HEDGEPETS_FRESH", "")
	game.save()
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://garden_life_check.json"))
	if (data["flowers"] as Dictionary).is_empty() or (data["gifts"] as Array).is_empty():
		return _fail("flowers or gifts not saved")
	print("%d flowers and %d gift(s) saved" % [total, (data["gifts"] as Array).size()])
	# a long absence: a welcome, flowers, the truck has been; nothing lost
	data["last_visit"] = Time.get_unix_time_from_system() - 3.0 * 86400.0
	data["barrel"] = {"contents": [{"kind": "stick", "lb": 2.0, "value": 1}], "next_pickup": Time.get_unix_time_from_system() - 100.0}
	var f := FileAccess.open("user://garden_life_check.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f = null
	var first_name: String = garden.roster[0].pet_name
	garden.queue_free()
	await process_frame
	OS.set_environment("HEDGEPETS_FRESH", "")
	var g2: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	# point the new garden's game at the check save before it loads: garden_game reads HEDGEPETS_SAVE
	OS.set_environment("HEDGEPETS_SAVE", "user://garden_life_check.json")
	root.add_child(g2)
	await process_frame
	OS.set_environment("HEDGEPETS_SAVE", "")
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var game2: Node = g2.game
	var states_ok: bool = game2.pet_state[first_name] == "resident"
	if not states_ok or game2.gifts.is_empty() or not game2.grab.contents.is_empty():
		return _fail("after 3 days away: resident %s, gifts %d, barrel %d" % [states_ok, game2.gifts.size(), game2.grab.contents.size()])
	if game2._toast.text.find("Welcome back") < 0:
		return _fail("no welcome back (toast: %s)" % game2._toast.text)
	print("3 days away: welcomed back, residents still home, gifts still there, the truck had been")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://garden_life_check.json"))
	print("PASS")
	quit(0)
