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
	for k in game.pet_state:                     # everyone else already settled: Clover is the only guest
		if not k in ["Gerald", "Clover"]:
			game.pet_state[k] = "resident"
	for i in range(4):
		game._notice_wait = 0.0
		game._visitors()
	print("after ", game.pet_state, " coins ", game.coins, " counts ", game.garden_counts())
	if game.pet_state["Clover"] != "resident":
		return _fail("Clover should have moved in")
	# favourites and gifts
	var gerald: HedgePetNode = game._node(garden.roster[0])
	var fav: Dictionary = game.favourite(gerald)
	print("Gerald's favourite: ", fav.get("emote", "none"))
	if fav.is_empty():
		return _fail("Gerald has nowhere he likes")
	game._drop_gift(gerald)
	var c0: int = game.coins
	var g: Dictionary = game.gifts[0]
	if not game._collect_gift(Vector2(g["at"].x, g["at"].z)) or game.coins <= c0:
		return _fail("gift not collected")
	print("gift +", game.coins - c0)
	# regraft
	gerald.set_plant("holly")
	if SpeciesBuilder.plant_of(gerald.profile) != "holly" or gerald.get_node_or_null("ContactShadow") == null:
		return _fail("regraft lost the plant or the contact shadow")
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
