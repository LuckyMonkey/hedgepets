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
	game._place("offering_acorn", Vector2(2.5, 3.0), 0.0)
	if int(game.woods_finds["basket"].get("acorn", 0)) != 0:
		return _fail("setting out did not take the acorn from the basket")
	if int(game.garden_counts().get("acorn", 0)) != 1:
		return _fail("the offering is not in garden_counts")
	var pocket: CharacterArtProfile = garden.roster.filter(func(p) -> bool: return p.pet_name == "Pocket")[0]
	if game.favourite_collectable(pocket) != "acorn":
		return _fail("Pocket has no derived acorn favourite")
	if not game._met(pocket.wants["resident"], game.garden_counts()):
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
