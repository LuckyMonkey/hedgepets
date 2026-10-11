extends SceneTree

## Friends and the woods:
##   - 💧 water: a resident comes to water poured beside it, then walks over to wherever you look
##   - 🪣 a water trail into a bucket: the pet climbs in; ✋ picks the bucket up (pet hidden, left alone by the visitor
##     logic) and sets it down on the lawn
##   - tapping the footbridge goes into the woods; you stand at the trailhead facing the trail; turning and tapping
##     walks it (over the hills: the camera's height follows the ground) to the mossy fork, followers trailing behind
##     and gathered round you there; then on to the nursery
##   - a pet carried in is set down in the woods with "Let out", and comes home with you
##   - back in the garden every pet that went along is home; following and the bucket are in the save
##   godot --headless --path . --script tools/woods_check.gd --fixed-fps 60
func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	quit(1)


func _frames(n: int) -> void:
	for k in range(n):
		await process_frame


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	var game: Node = garden.game
	game.coins = 50
	var a: CharacterArtProfile = garden.roster[0]
	var b: CharacterArtProfile = garden.roster[1]
	var c: CharacterArtProfile = garden.roster[2]
	game.pet_state[a.pet_name] = "resident"
	game.pet_state[b.pet_name] = "visiting"
	game.pet_state[c.pet_name] = "visiting"
	var na: HedgePetNode = game._node(a)
	var nb: HedgePetNode = game._node(b)
	var nc: HedgePetNode = game._node(c)
	for n: HedgePetNode in [na, nb, nc]:
		garden.set_pet_mode(n, "roam", true)
	# water: pour beside the resident and it comes to it, and walks with you
	game._lure(Vector2(na.position.x + 0.8, na.position.z))
	if not game.following.has(a.pet_name):
		return _fail("pouring right beside a resident didn't bring it along")
	garden._goal_target = Vector3(6.0, 0, 3.0)
	garden._target = garden._goal_target
	await create_timer(12.0).timeout
	var d := Vector2(na.position.x, na.position.z).distance_to(Vector2(6.0, 3.0))
	if d > 3.5:
		return _fail("%s didn't come over to where we're looking (%.1f m away)" % [a.pet_name, d])
	print("water: %s came to the water and along to the new view (%.1f m)" % [a.pet_name, d])

	# the bucket: a water trail into it, the visitor climbs in, pick it up, set it down, again for the woods
	for k in range(2):
		game._place("bucket", Vector2(-3.0, 2.0 + k * 0.01), 0.0)
		var bt: Dictionary = garden.things[-1]
		var spot := Vector2(bt["node"].position.x, bt["node"].position.z)
		nb.position = Vector3(spot.x + 1.0, 0, spot.y)
		garden.set_pet_mode(nb, "roam", true)
		game._lure(spot)
		await create_timer(2.0).timeout
		if not garden.hideouts.occupied(bt):
			return _fail("%s didn't follow the water into the bucket (mode %s)" % [b.pet_name, garden.pet_mode(nb)])
		game.pick_up_bucket(bt)
		if game.carried != b.pet_name or nb.visible or garden.pet_mode(nb) != "carried":
			return _fail("picking up the bucket: carried '%s', visible %s, mode %s" % [game.carried, nb.visible, garden.pet_mode(nb)])
		game._apply_mode(nb)                             # the visitor logic leaves a carried pet alone
		if garden.pet_mode(nb) != "carried":
			return _fail("the visitor logic took the pet out of the bucket")
		if k == 0:
			game.put_down(Vector3(-2.0, 0, 2.0))
			if game.carried != "" or not nb.visible or garden.pet_mode(nb) != "roam" or not garden.things.has(bt):
				return _fail("setting the bucket down on the lawn")
			game._clear(bt)
	print("bucket: a water trail in, picked up and carried, set down, carried again")

	game.following = [a.pet_name]                       # (another pet may have wandered into the poured water)
	# into the woods by the footbridge
	var bridge: Vector3 = Vector3(garden._creek_x(garden.GATES["creek"]["peek"].z), 0, garden.GATES["creek"]["peek"].z)
	if not garden.on_bridge(Vector2(bridge.x, bridge.z)):
		return _fail("the footbridge isn't where on_bridge thinks")
	garden.camera.global_position = bridge + Vector3(0, 12, 8)
	garden.camera.look_at(bridge)
	var at: Vector2 = garden.camera.unproject_position(bridge)
	game.tool = "hand"
	game.tap(at, null)
	var waited := 0.0                                    # the first time, it's built in steps behind a loading card
	while root.get_viewport().get_camera_3d() != garden.woods.cam and waited < 90.0:
		await process_frame
		waited += 1.0 / 60.0
	print("woods: built and entered in %.1f s (frames at 60 fps)" % waited)
	await create_timer(1.0).timeout
	var woods: Node = garden.woods
	if not woods.inside or root.get_viewport().get_camera_3d() != woods.cam:
		return _fail("tapping the bridge didn't take us into the woods")
	if woods._at != "trailhead" or woods.followers.size() != 1 or woods._carried != nb:
		return _fail("arrival: at %s, %d followers, carried %s" % [woods._at, woods.followers.size(), woods._carried])
	if woods.facing().get("to", "") != "fork":
		return _fail("not facing the trail up to the fork on arrival (%s)" % woods.facing().get("to", "-"))
	# look at the nursery first? it's off the fork; walk up there
	woods._tap(Vector2(540, 400))
	var low := INF
	var high := -INF
	for k in range(60 * 30):
		await process_frame
		var y: float = woods.cam.position.y
		low = minf(low, y)
		high = maxf(high, y)
		if woods._walking.is_empty():
			break
	if woods._at != "fork":
		return _fail("didn't arrive at the fork (at %s)" % woods._at)
	if high - low < 1.0:
		return _fail("the trail was flat (%.2f m up and down)" % (high - low))
	await create_timer(1.5).timeout
	var fork: Vector3 = woods.to_global(woods.node_pos("fork"))
	if na.global_position.distance_to(fork) > 4.5:
		return _fail("%s didn't keep up (%.1f m from the fork)" % [a.pet_name, na.global_position.distance_to(fork)])
	print("woods: trailhead -> mossy fork, %.1f m of hills, %s followed" % [high - low, a.pet_name])
	# the nursery: turn to it, tap
	for way: Dictionary in woods._labels["fork"]:
		if way["to"] == "nursery":
			woods._goal_yaw = woods._heading_of(way["dir"])
	await create_timer(1.0).timeout
	if woods.facing().get("to", "") != "nursery":
		return _fail("couldn't face the nursery trail")
	woods._tap(Vector2(540, 400))
	await process_frame
	if woods._walking.is_empty():
		return _fail("didn't set off down the nursery trail")
	while not woods._walking.is_empty():
		await process_frame
	if woods._at != "nursery":
		return _fail("didn't arrive at the nursery (at %s)" % woods._at)
	print("woods: mossy fork -> the nursery")
	# nothing solid stands on a trail (the camera walks the trails: it would go straight through)
	for n in woods.get_children():
		var clear: float = {"Lantern": 1.8, "Sign": 0.95, "OldOak": 4.0, "TrailBoard": 1.5, "RidgeBench": 1.5, "Sunbeam": 2.4}.get(String(n.name).trim_prefix("@").get_slice("@", 0), 0.0)
		if clear > 0.0:
			var t: Vector2 = woods._nearest_trail(Vector2(n.position.x, n.position.z))
			if t != Vector2.INF and t.distance_to(Vector2(n.position.x, n.position.z)) < clear - 0.05:
				return _fail("%s stands %.2f m from a trail (needs %.1f)" % [n.name, t.distance_to(Vector2(n.position.x, n.position.z)), clear])
	print("woods: lanterns, signs, sunbeams, the oak, the board and the bench all clear of the trails")
	# let the bucket's pet out here
	woods.let_out()
	if game.carried != "" or not woods.followers.has(nb) or not game.following.has(b.pet_name):
		return _fail("letting the bucket's pet out in the woods")
	woods.leave()
	await create_timer(1.2).timeout
	if woods.inside or root.get_viewport().get_camera_3d() != garden.camera:
		return _fail("didn't come back to the garden")
	if not nb.visible or garden.pet_mode(nb) != "roam" or nb.global_position.y < -1.0:
		return _fail("the pet let out in the woods didn't come home (visible %s, mode %s, y %.1f)" % [nb.visible, garden.pet_mode(nb), nb.global_position.y])
	if na.global_position.y < -1.0 or nc.global_position.y < -1.0 or woods.is_borrowed(nc):
		return _fail("a pet stayed in the woods (%.1f) / one that didn't go was taken (%.1f)" % [na.global_position.y, nc.global_position.y])
	var data: Dictionary = JSON.parse_string(JSON.stringify({"following": game.following, "carried": game.carried}))
	if not (data["following"] as Array).has(a.pet_name) or data["carried"] != "":
		return _fail("following / bucket not as expected for the save")
	print("PASS woods_check")
	quit(0)
