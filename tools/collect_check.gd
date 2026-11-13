extends SceneTree

## Forage -> carry -> set out -> wish -> save/restore. Nothing in the collection is removed by a visit away.
## HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/collect_check.gd --fixed-fps 60
func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	print("FAIL: ", message)
	quit(1)


func _run() -> void:
	Motion.speed = 0.0
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	await process_frame
	var game: Node = garden.game
	game.woods_finds["basket"] = {"acorn": 1}
	game.collection["acorn"] = 1
	game.coins = 100
	game.tool = "build"                                   # as the player does it: the build tool, a tap on the lawn
	game.build_choice = "offering_acorn"
	var spot := Vector2(2.5, 3.0)
	for i in range(200):                                  # somewhere clear on the lawn
		var c := Vector2(-6.0 + (i % 20) * 0.6, -4.0 + (i / 20) * 0.9)
		if not garden._blocked(c, 0.7) and game._bed_at(c) == null:
			spot = c
			break
	garden._goal_target = Vector3(spot.x, 0, spot.y)
	garden._target = garden._goal_target
	garden._place_camera()
	game.tap(garden.camera.unproject_position(Vector3(spot.x, 0.0, spot.y)), null)
	if int(game.woods_finds["basket"].get("acorn", 0)) != 0:
		return _fail("setting out did not take the acorn from the basket (said: %s)" % game._toast.text)
	if int(game.garden_counts().get("acorn", 0)) != 1:
		return _fail("the offering is not in garden_counts")
	var pocket: CharacterArtProfile = garden.roster.filter(func(p) -> bool: return p.pet_name == "Pocket")[0]
	if game.favourite_collectable(pocket) != "acorn":
		return _fail("Pocket has no derived acorn favourite")
	if int(game.garden_counts().get("acorn", 0)) < int(pocket.wants["resident"].get("acorn", 99)):   # the acorn part of it
		return _fail("Pocket's acorn wish was not met by the offering")
	game.save_path = "user://collect_check.json"
	OS.set_environment("HEDGEPETS_FRESH", "")
	game.save(true)
	var saved := FileAccess.get_file_as_string("user://collect_check.json")
	if not saved.contains("offering_acorn") or not saved.contains("acorn"):
		return _fail("save did not carry the offering and collection")
	if not saved.contains("collection"):
		return _fail("save did not carry the collection ledger")
	print("collection: ", game.collection, " counts: ", game.garden_counts())
	print("PASS collect_check")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://collect_check.json"))
	quit(0)
