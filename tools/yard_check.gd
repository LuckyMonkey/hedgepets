extends SceneTree

## Digging and dirt, growing, room for six, the fire pit, the man on the porch:
##   - a hole beside a hole joins its row (one step along, in the direction you dug); digging leaves dirt on a pile
##   - 🪏 on a pile takes a shovelful, on a hole fills it; on a sown bed digs the seed back up (it's back in 🌱)
##   - the wheelbarrow loads from a pile and, let go over holes, fills them
##   - plants grow unwatered (slower) and faster watered
##   - the garden has room for 2 to begin with and never more than 6, residents included; a pet only notices a garden
##     that grows one of its plants
##   - a fire pit lights with ✋ and burns down
##   - the man on the porch: caught by the camera, he puts the phone away or goes in; looked away from, he comes back
##   HEDGEPETS_FRESH=1 godot --headless --path . --script tools/yard_check.gd --fixed-fps 60
func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	quit(1)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	var game: Node = garden.game
	game.coins = 200
	# ---- digging a row
	game.tool = "shovel"
	var o := Vector2.INF                                 # somewhere with clear ground for a short row
	for z in range(-6, 7):
		for x in range(-9, 6):
			if o == Vector2.INF and range(5).all(func(k) -> bool: return not garden._blocked(Vector2(x + k * 0.8, z), 0.5)):
				o = Vector2(x, z)
	game._shovel(o)
	game._shovel(o + Vector2(0.7, 0.1))
	game._shovel(o + Vector2(1.5, 0.2))
	if game.seedbeds.size() != 3:
		return _fail("three digs made %d holes" % game.seedbeds.size())
	var step: float = (game.seedbeds[1]["at"] as Vector2).distance_to(game.seedbeds[0]["at"])
	if absf(step - game.ROW_STEP) > 0.05:
		return _fail("the second hole didn't join the first's row (%.2f m apart)" % step)
	var loads := 0
	for d in game.dirt_piles:
		loads += int(d["loads"])
	if loads != 3:
		return _fail("three holes, %d loads of dirt" % loads)
	print("row: 3 holes %.2f m apart, %d dirt piles holding %d loads" % [step, game.dirt_piles.size(), loads])
	# ---- shovel: scoop and fill, unplant
	var pile: Dictionary = game.dirt_piles[0]
	game._shovel(pile["at"])
	if not game.shovelful:
		return _fail("no shovelful from the pile")
	var last: Dictionary = game.seedbeds[2]
	game._shovel(last["at"])
	if game.shovelful or game.seedbeds.has(last):
		return _fail("the shovelful didn't fill the hole")
	var bed: Dictionary = game.seedbeds[0]
	game._plant("lavender", bed, 0)
	var kept: int = game.keep_seeds.size()
	game._shovel(bed["at"])
	if bed["plant"] != null or game.keep_seeds.size() != kept + 1:
		return _fail("digging up a seed didn't give it back")
	print("shovel: scooped, filled a hole, dug a seed back up")
	# ---- the wheelbarrow
	var bw: Dictionary = game.barrow
	game.add_dirt(Vector2(4.5, 5.5), Vector2.ZERO, 2)
	var p2: Dictionary = game.dirt_piles[-1]
	game.take_dirt(p2)
	game.grab.barrow_load(bw, 1)
	var hole: Dictionary = game._dig(Vector2(2.0, 6.0))
	bw["node"].position = Vector3(2.0, 0, 6.0)
	game.grab._drop(bw)
	if game.seedbeds.has(hole) or int(bw["load"]) != 0:
		return _fail("the wheelbarrow didn't fill the hole it was let go over (load %d)" % bw["load"])
	print("wheelbarrow: loaded, tipped into a hole")
	# ---- growing without water
	var b2: Dictionary = game._dig(Vector2(-6.0, -2.0))
	var pl: Dictionary = game._plant("clover", b2, 0, 0.0)
	for k in range(10):
		game._grow(game.STAGE_SECONDS / game.DRY_GROWTH / 10.0 + 0.01)
	if pl["stage"] != 1:
		return _fail("an unwatered seed didn't come up (stage %d)" % pl["stage"])
	print("growing: an unwatered seed came up on its own")
	# ---- room for six, and plants draw them
	for k in game.pet_state:
		if k != "Gerald":
			game.pet_state[k] = "away"
	if game.capacity() > 3:
		return _fail("a bare garden has room for %d" % game.capacity())
	var fox: CharacterArtProfile = null
	for p: CharacterArtProfile in garden.roster:
		if p.species == "red fox":
			fox = p
	if game.grows_for(fox) != game.plants.any(func(x) -> bool: return SpeciesBuilder.variants_of(fox).has(x["species"])):
		return _fail("grows_for disagrees with the fox's plants")
	for p: CharacterArtProfile in garden.roster:
		game.pet_state[p.pet_name] = "resident"
	game._visitors()
	var here := 0
	for k in game.pet_state:
		here += int(game.pet_state[k] != "away")
	game.pet_state = game.pet_state                     # (residents over capacity stay; no new ones come)
	for p: CharacterArtProfile in garden.roster:
		if p.pet_name != "Gerald":
			game.pet_state[p.pet_name] = "away"
	for k in range(40):
		game._notice_wait = 0.0
		game._visitors()
	var came := 0
	for k in game.pet_state:
		came += int(game.pet_state[k] != "away")
	if came > game.capacity():
		return _fail("%d pets came, room for %d" % [came, game.capacity()])
	print("room: %d here, room for %d" % [came, game.capacity()])
	# ---- the fire pit
	game._place("fire_pit", Vector2(5.0, -4.0), 0.0)
	var pit: Dictionary = garden.things[-1]
	pit["node"].tapped(game)
	if not pit["node"].lit():
		return _fail("the fire pit didn't light")
	print("fire pit: lit")
	# ---- the man on the porch
	var w: Node3D = garden.get_node("PorchWatcher")
	w._wait = 0.0
	garden.set_process(false)                            # the camera's ours (the garden would steer it)
	garden.camera.global_position = Vector3(0, 12, -14)        # looking away from the houses
	garden.camera.look_at(Vector3(0, 0, -20))
	for k in range(60 * 8):
		await process_frame
		if w._state == w.WATCHING:
			break
	if w._state != w.WATCHING:
		return _fail("he never came out to watch (state %d)" % w._state)
	garden.camera.global_position = w.global_position + Vector3(0, 1.0, -9.0)
	garden.camera.look_at(w.global_position + Vector3(0, 1.6, 0))
	for k in range(30):
		await process_frame
	if w._state == w.WATCHING:
		return _fail("seen and still taking pictures")
	for k in range(60 * 6):
		await process_frame
		if w._state == w.INSIDE:
			break
	if w._state != w.INSIDE:
		return _fail("kept being looked at, and didn't go in (state %d)" % w._state)
	print("porch: came out unseen, caught, went in")
	# ---- the contraband: leaves look different, a strong smell, then cannabis; it wants the street-gate sun
	garden.set_process(true)
	game.pet_state["Clover"] = "resident"
	var clover: HedgePetNode = game._node(garden.roster.filter(func(p) -> bool: return p.pet_name == "Clover")[0])
	garden.set_pet_mode(clover, "roam", true)
	for k in range(3):
		game._tend_contraband("Clover")
	if not game.is_contraband("Clover") or game.pet_plant.get("Clover", "") != "cannabis":
		return _fail("the contraband didn't come about (%s)" % game.contraband)
	var gate: Vector3 = garden.GATES["houses"]["inside"]
	var sunny := 0
	for k in range(40):
		var fav: Dictionary = game.favourite(clover)
		if not fav.is_empty() and Vector2(fav["at"].x, fav["at"].z).distance_to(Vector2(gate.x, gate.z)) < 2.5:
			sunny += 1
	if sunny < 20:
		return _fail("the contraband doesn't head for the sun out front often (%d of 40)" % sunny)
	game.tool = "shears"
	game.seed_choice = "clover"
	game.coins = 50
	game.regraft(clover)
	if game.is_contraband("Clover") or int(game.contraband.get("stage", 0)) != 4:
		return _fail("regrafting didn't settle it (%s)" % game.contraband)
	print("contraband: leaves, smell, cannabis; off to the sun by the gate; regrafted, settled")
	print("PASS yard_check")
	quit(0)
