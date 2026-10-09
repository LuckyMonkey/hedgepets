extends SceneTree

## Hideouts, played out at 60 fps: Gerald walks to the paint bucket, climbs in (no position jumps), hides (the bucket
## full of his leaves and a face), climbs back out; a burrowing pet arrives as a face in the burrow doorway, climbs
## out, and later leaves back down it. SHOTS=1 (with a display) saves frames of each stage.
##   godot --headless --path . --script tools/hide_check.gd --fixed-fps 60
func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	quit(1)


func shot(name: String) -> void:
	if OS.get_environment("SHOTS") != "":
		root.get_texture().get_image().save_png("/tmp/hedgepets-views/hide_%s.png" % name)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	var game: Node = garden.game
	var gerald: HedgePetNode = game._node(garden.roster[0])
	var w: Dictionary = garden._wander[gerald]
	var bucket: Dictionary = garden.hideouts.spot_of("bucket")
	gerald.position = garden.hideouts.approach_point(bucket, gerald) + Vector3(2.5, 0, 0)
	garden._goal_target = bucket["thing"]["node"].position
	garden._target = garden._goal_target
	garden._goal_distance = 6.0
	garden._distance = 6.0
	# send him to hide in the bucket
	bucket["occupant"] = gerald
	w["mode"] = "to_hide"
	w["hideout"] = bucket
	w["target"] = garden.hideouts.approach_point(bucket, gerald)
	w["best_d"] = INF
	var last := gerald.position
	var worst := 0.0
	var saw := {}
	for f in range(60 * 12):
		await process_frame
		if gerald.visible:
			worst = maxf(worst, gerald.position.distance_to(last))
		last = gerald.position
		saw[w["mode"]] = true
		if w["mode"] == "hiding" and not saw.has("shot_climb") and f % 3 == 0:
			saw["shot_climb"] = true
			shot("climb")
		if w["mode"] == "hidden":
			break
	if w["mode"] != "hidden" or gerald.visible:
		return _fail("never got into the bucket (mode %s, saw %s)" % [w["mode"], saw.keys()])
	await process_frame
	for i in range(60):
		await process_frame
	if bucket["fill"] == null or (bucket["fill"] as Node3D).get_node_or_null("Face") == null:
		return _fail("no fill / face in the bucket")
	shot("hidden")
	print("hid in the bucket: walked, climbed, slid in; worst frame step %.3f" % worst)
	if worst > 0.25:
		return _fail("a jump of %.2f in one frame while climbing in" % worst)
	# coax him out
	garden.hideouts.coax(bucket["thing"])
	worst = 0.0
	var emerged := false
	for f in range(60 * 4):
		await process_frame
		if gerald.visible:
			if last != Vector3.INF:
				worst = maxf(worst, gerald.position.distance_to(last))
			last = gerald.position
		if f == 20:
			shot("out")
		if w["mode"] == "roam":
			emerged = true
			break
	if not emerged or bucket["occupant"] != null or not gerald.visible:
		return _fail("didn't come out (mode %s)" % w["mode"])
	print("came out of the bucket; worst frame step %.3f" % worst)
	# the burrow gate: a burrowing pet arrives as a face in the doorway, climbs out, later goes home down it
	var digger: CharacterArtProfile = garden.roster.filter(func(p) -> bool: return garden.gate_for(p) == "burrow")[0]
	var dn: HedgePetNode = game._node(digger)
	garden.set_pet_mode(dn, "peek")
	var dw: Dictionary = garden._wander[dn]
	var burrow: Dictionary = garden.hideouts.spot_of("burrow")
	await process_frame
	if dw["mode"] != "hidden" or burrow["fill"] == null:
		return _fail("%s didn't peek out of the burrow" % digger.pet_name)
	garden._goal_target = burrow["thing"]["node"].position
	garden._target = garden._goal_target
	for i in range(60):
		await process_frame
	shot("burrow_peek")
	garden.set_pet_mode(dn, "roam")
	for f in range(60 * 3):
		await process_frame
		if dw["mode"] == "roam":
			break
	if dw["mode"] != "roam" or not dn.visible:
		return _fail("%s didn't climb out of the burrow" % digger.pet_name)
	print("%s the %s peeked out of the burrow and climbed out" % [digger.pet_name, digger.species])
	garden.set_pet_mode(dn, "leave")
	for f in range(60 * 20):
		await process_frame
		if dw["mode"] == "away":
			break
	if dw["mode"] != "away":
		return _fail("%s never went home down the burrow (mode %s)" % [digger.pet_name, dw["mode"]])
	print("and went home down it")
	print("PASS")
	quit(0)
