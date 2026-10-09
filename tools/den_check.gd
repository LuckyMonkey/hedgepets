extends SceneTree

## The burrow den, arranging with 🧺, and the save's newest-copy rule:
##   - going down pauses the garden, tucks the residents into the beds (asleep), muffles the sound; coming back up puts
##     every pet exactly where it was and un-pauses everything
##   - with 🧺, a drag moves something you built (and it's saved where it ended up), a tap turns it 45°, a drop
##     onto something else snaps back; a placed bucket is a hideout, and nobody's shovelled out of one
##   - WebSave.newest picks the copy with the later last_visit
##   godot --headless --path . --script tools/den_check.gd
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
	var den: Node = garden.den
	# two residents: one out in the garden, one away
	var a: CharacterArtProfile = garden.roster[0]
	var b: CharacterArtProfile = garden.roster[1]
	game.pet_state[a.pet_name] = "resident"
	game.pet_state[b.pet_name] = "resident"
	var na: HedgePetNode = garden.node_for(a)
	garden.set_pet_mode(na, "roam", true)
	den.enter()
	for k in range(60):
		await process_frame
	if not den.inside or not den.visible:
		return _fail("didn't go down into the den")
	if den._sleepers.size() != 2:
		return _fail("expected 2 sleepers, got %d" % den._sleepers.size())
	if not na.sleeping or na.global_position.y > -50.0:
		return _fail("%s isn't asleep in the den (y %.1f)" % [a.pet_name, na.global_position.y])
	if garden.is_processing() or game.is_processing():
		return _fail("the garden kept running while we were down")
	var tucked: Dictionary = den._borrowed.filter(func(sl) -> bool: return sl["node"] == na)[0]
	var before: Transform3D = tucked["transform"]
	var was_visible: bool = tucked["visible"]
	if root.get_viewport().get_camera_3d() != den.cam:
		return _fail("the den's camera isn't the one in use")
	den.leave()
	for k in range(120):                                 # until the swap behind the fade
		if not den.visible:
			break
		await process_frame
	if den.inside or den.visible:
		return _fail("didn't come back up")
	if na.position.distance_to(before.origin) > 0.1 or absf(na.position.y - before.origin.y) > 0.05 or na.visible != was_visible or na.sleeping:
		return _fail("%s isn't back where it was: %s vs %s, visible %s/%s, asleep %s" % [a.pet_name, na.position, before.origin, na.visible, was_visible, na.sleeping])
	if not garden.is_processing() or not game.is_processing():
		return _fail("the garden didn't start again")
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Master")) != 0:
		return _fail("the muffle stayed on")
	print("den: down and back up, %d asleep, everyone back in place" % 2)

	# arranging
	game.coins = 100
	game.tool = "build"
	game._place("bucket", Vector2(-2.0, 1.5), 0.0, false)
	var t: Dictionary = garden.things[-1]
	var node: Node3D = t["node"]
	if garden.hideouts.spot_of("bucket") == {} or not garden.hideouts.spots.any(func(s) -> bool: return s["thing"] == t):
		return _fail("a placed bucket isn't a hideout")
	var cam: Camera3D = garden.camera
	garden._goal_target = Vector3(-1, 0, 1.5)
	garden._target = garden._goal_target
	garden._place_camera()
	var at := cam.unproject_position(Vector3(-2.0, 0, 1.5))
	if not game.arrange_begin(at):
		return _fail("pressing on the bucket with 🧺 didn't pick it up")
	game.arrange_end(at, false)
	await create_timer(0.6).timeout
	if absf(node.rotation_degrees.y - 45.0) > 1.0:
		return _fail("a tap didn't turn it (%.1f°)" % node.rotation_degrees.y)
	var to := cam.unproject_position(Vector3(0.0, 0, 2.5))
	game.arrange_begin(at)
	game.arrange_move(to)
	game.arrange_end(to, true)
	await create_timer(0.5).timeout
	if Vector2(node.position.x, node.position.z).distance_to(Vector2(0.0, 2.5)) > 0.15 or (t["at"] as Vector2).distance_to(Vector2(0.0, 2.5)) > 0.15:
		return _fail("a drag didn't move it (at %s)" % node.position)
	var saved: Dictionary = game.placed.filter(func(p) -> bool: return p["node"] == node)[0]
	game.save()                                          # FRESH: writes nothing, but the map must read the node
	var tree_at: Vector2 = garden.obstacles[0][0]
	var onto := cam.unproject_position(Vector3(tree_at.x, 0, tree_at.y))
	game.arrange_begin(cam.unproject_position(Vector3(0.0, 0, 2.5)))
	game.arrange_move(onto)
	game.arrange_end(onto, true)
	await create_timer(0.6).timeout
	if Vector2(node.position.x, node.position.z).distance_to(Vector2(0.0, 2.5)) > 0.15:
		return _fail("dropping it on a tree didn't snap back (at %s)" % node.position)
	if saved["node"] != node:
		return _fail("lost track of the placed entry")
	var spot: Dictionary = garden.hideouts.spots.filter(func(s) -> bool: return s["thing"] == t)[0]
	spot["occupant"] = na
	var n_things: int = garden.things.size()
	game._clear(t)
	if garden.things.size() != n_things:
		return _fail("shovelled out a bucket someone was hiding in")
	spot["occupant"] = null
	game._clear(t)
	if garden.things.has(t) or garden.hideouts.spots.has(spot):
		return _fail("clearing the bucket left it (or its hideout) behind")
	print("arrange: tap turns, drag moves, a bad drop snaps back, an occupied hideout stays")

	# the newer save wins
	var path := "user://den_check_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"last_visit": 100.0, "coins": 1}))
	f.close()
	if JSON.parse_string(WebSave.newest(path))["coins"] != 1.0:
		return _fail("WebSave.newest didn't fall back to the file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS den_check")
	quit(0)
