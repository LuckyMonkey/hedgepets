extends SceneTree

## Plays the garden loop without a player: clear junk, dig, plant, water, grow, and watch visitors arrive.
##   HEDGEPETS_FRESH=1 godot --headless --path . --script tools/game_check.gd   (never touches the player's save)
func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	quit(1)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	await process_frame
	var game: Node = garden.game
	var states := {}
	for k in game.pet_state:
		states[k] = game.pet_state[k]
	print("start ", states, " coins ", game.coins)
	if game.pet_state["Gerald"] != "resident":
		return _fail("Gerald should start at home")
	# clear the tire and the pot -> coins
	var before: int = game.coins
	for t in garden.things.duplicate():
		if t["kind"] in ["tire", "pot", "grill", "branch"]:
			game._clear(t)
	print("cleared ", game.cleared, " coins ", before, " -> ", game.coins)
	# plant clover and grow it
	var bed: Dictionary = game._dig(Vector2(1.5, 2.0))
	game.coins -= 3
	var pl: Dictionary = game._plant("clover", bed, 0)
	for i in range(3):
		pl["water"] = 1.0
		game._grow(game.STAGE_SECONDS + 0.1)
	print("clover stage ", pl["stage"])
	if pl["stage"] != 3:
		return _fail("clover did not grow")
	var bed2: Dictionary = game._dig(Vector2(-2.5, 1.0))
	var pl2: Dictionary = game._plant("clover", bed2, 2)
	for i in range(4):
		game._visitors()
	print("after ", game.pet_state, " coins ", game.coins, " counts ", game.garden_counts())
	if game.pet_state["Clover"] != "resident":
		return _fail("Clover should have moved in")
	game.save_path = "user://garden_check.json"
	OS.set_environment("HEDGEPETS_FRESH", "")
	game.save()
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var text := FileAccess.get_file_as_string("user://garden_check.json")
	if not text.contains("clover"):
		return _fail("save missing plants")
	print("PASS")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://garden_check.json"))
	quit(0)
