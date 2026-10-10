extends SceneTree

## The nursery, the woods' finds and what plants pass on:
##   - inheritance: seedlings of two plants take after both the expected way (first crosses all look like the coloured,
##     tall parent; their seedlings about a quarter pale, a quarter short, independently)
##   - self-sowing: an empty bed beside something flowering gets a seedling, with its parents' letters
##   - her lines: every id unique, every condition known, nothing that names anyone; she greets on arrival, talks on a
##     tap, never repeats within RECENT lines, gives the seeds on the third visit, buys the basket
##   - the woods: walk to the nursery from the fork; litter pays and stays gone, junk takes tugs, forage goes in the
##     basket, wild seeds go in the seed tray; forage grows back after REGROW, litter never
##   HEDGEPETS_FRESH=1 godot --headless --path . --script tools/nursery_check.gd --fixed-fps 60
const NEVER := ["potter", "mendel", "beatrix", "gregor", "b.p.", "greg m", "peter", "tiggy", "jemima", "nutkin", "brno", "mcgregor"]


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	quit(1)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	# ---- inheritance, by the numbers
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var f1: Array = []
	for k in range(400):
		f1.append(Heredity.cross(Heredity.STOCK, "cctt", rng))
	if f1.any(func(g) -> bool: return Heredity.pale(g) or Heredity.short(g)):
		return _fail("a first cross showed a hidden trait")
	var pale := 0
	var short := 0
	var both := 0
	var n := 8000
	for k in range(n):
		var g := Heredity.cross("CcTt", "CcTt", rng)
		pale += int(Heredity.pale(g))
		short += int(Heredity.short(g))
		both += int(Heredity.pale(g) and Heredity.short(g))
	print("seedlings of CcTt x CcTt: pale %.3f short %.3f both %.3f" % [float(pale) / n, float(short) / n, float(both) / n])
	if absf(float(pale) / n - 0.25) > 0.02 or absf(float(short) / n - 0.25) > 0.02 or absf(float(both) / n - 0.0625) > 0.012:
		return _fail("seedling proportions are off")
	# ---- her lines
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/talk/nursery.json"))
	var ids := {}
	var known := ["visits_min", "visits_max", "season", "hour", "grows", "flowering", "resident", "with", "carried", "wants", "volunteers", "crossed", "returned", "pale", "short", "kept"]
	for line: Dictionary in data["lines"]:
		if ids.has(line["id"]):
			return _fail("two lines called " + line["id"])
		ids[line["id"]] = true
		for k in line.get("when", {}):
			if not known.has(k):
				return _fail("line %s has an unknown condition %s" % [line["id"], k])
	for path in ["res://assets/talk/nursery.json", "res://scripts/garden/nursery.gd", "res://scripts/garden/heredity.gd", "res://scripts/garden/woods.gd", "res://scripts/garden/garden_game.gd"]:
		var text := FileAccess.get_file_as_string(path).to_lower()
		for word in NEVER:
			var re := RegEx.create_from_string("\\b" + word.replace(".", "\\.") + "\\b")
			if re.search(text) != null:
				return _fail("%s mentions '%s'" % [path, word])
	print("lines: %d, ids unique, conditions known, no names" % ids.size())
	# ---- the garden: self-sowing
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	var game: Node = garden.game
	var mother: Dictionary = game._plant("lavender", game._dig(Vector2(1.5, 2.0)), 3, 1.0, 0.0, "CCTT")
	var father: Dictionary = game._plant("lavender", game._dig(Vector2(-1.5, 2.5)), 3, 1.0, 0.0, "cctt", "nursery")
	var bed: Dictionary = game._dig(Vector2(0.0, 4.0))
	for k in range(60):
		if bed["plant"] != null:
			break
		game._self_sow()
	if bed["plant"] == null or bed["plant"]["origin"] != "volunteer":
		return _fail("nothing self-sowed in the empty bed")
	var g: String = bed["plant"]["genes"]
	if not g in ["CCTT", "CcTt", "cctt"]:
		return _fail("a seedling of CCTT/cctt with genes " + g)
	print("self-sown: %s seedling (%s)" % [bed["plant"]["species"], g])
	var line: String = game._plant_line(father)
	print("plant line: ", line)
	if not line.contains("short") or not line.contains("white"):
		return _fail("the nursery's lavender doesn't read as short and white")
	# ---- the woods and the nursery
	var woods: Node = garden.woods
	woods.enter()
	await create_timer(1.0).timeout
	var c: Dictionary = woods.nursery.context()
	print("context: season %s hour %s visits %d" % [c["season"], c["hour"], c["visits"]])
	# a find at the trailhead: litter pays and is gone
	var coins: int = game.coins
	var litter: Dictionary = woods._finds.filter(func(f) -> bool: return f["at"] == "trailhead" and f["kind"] == "can")[0]
	woods.take(litter)
	if game.coins != coins + 1 or not game.woods_finds["taken"].has(litter["id"]):
		return _fail("litter didn't pay or wasn't taken")
	var junk: Dictionary = woods._finds.filter(func(f) -> bool: return f["at"] == "trailhead" and f["kind"] == "tarp")[0]
	woods.take(junk)
	if game.woods_finds["taken"].has(junk["id"]):
		return _fail("junk came away on the first tug")
	woods.take(junk)
	woods.take(junk)
	if not game.woods_finds["taken"].has(junk["id"]):
		return _fail("junk didn't come away after its tugs")
	var cone: Dictionary = woods._finds.filter(func(f) -> bool: return f["at"] == "trailhead" and f["kind"] == "cone")[0]
	woods.take(cone)
	if int(woods.basket.get("cone", 0)) != 1:
		return _fail("the cone isn't in the basket")
	var seeds: Dictionary = woods._finds.filter(func(f) -> bool: return f["at"] == "trailhead" and f["kind"] == "seeds")[0]
	var before: int = game.keep_seeds.size()
	woods.take(seeds)
	if game.keep_seeds.size() != before + 2:
		return _fail("wild seeds didn't go in the tray")
	# forage regrows, litter doesn't
	for id in game.woods_finds["taken"]:
		game.woods_finds["taken"][id] = Time.get_unix_time_from_system() - woods.REGROW - 10.0
	woods._refresh_finds()
	if not cone["node"].visible or litter["node"].visible:
		return _fail("after a while: cone back %s, litter back %s" % [cone["node"].visible, litter["node"].visible])
	print("finds: litter +1 and gone for good, tarp after 3 tugs, cone in the basket and back later, 2 wild seeds")
	# to the fork, then the nursery
	woods.walk(woods._way_to("fork"))
	while not woods._walking.is_empty():
		await process_frame
	woods.walk(woods._way_to("nursery"))
	while not woods._walking.is_empty():
		await process_frame
	if woods._at != "nursery" or int(game.nursery["visits"]) != 1:
		return _fail("didn't arrive at the nursery (at %s, visits %d)" % [woods._at, game.nursery["visits"]])
	var said: String = woods.nursery._card_text.text
	print("greeting: ", said)
	if said == "":
		return _fail("she didn't greet us")
	# the basket
	coins = game.coins
	woods.nursery.talk()
	if not woods.basket.is_empty() or game.coins != coins + 1:
		return _fail("she didn't buy the basket")
	# talking: no repeats within RECENT
	var heard: Array = []
	for k in range(30):
		woods.nursery.talk()
		heard.append(woods.nursery._card_text.text)
	for i in heard.size():
		for j in range(i + 1, mini(heard.size(), i + 20)):
			if heard[i] == heard[j]:
				return _fail("she repeated herself within 20 lines: " + heard[i])
	print("30 lines, no repeats, e.g. ", heard[0], " / ", heard[1])
	# third visit: the seeds
	game.nursery["visits"] = 2
	woods.nursery.arrive()
	var lav: int = game.keep_seeds.filter(func(k) -> bool: return k["species"] == "lavender").size()
	woods.nursery.talk()
	if game.keep_seeds.filter(func(k) -> bool: return k["species"] == "lavender").size() != lav + 3 or not game.nursery["gave"]:
		return _fail("no seeds on the third visit")
	print("third visit: three lavender seeds. ", woods.nursery._card_text.text)
	# sowing them: free, and from the nursery
	woods.leave()
	await create_timer(1.0).timeout
	game.seed_choice = "lavender"
	var bed2: Dictionary = game._dig(Vector2(3.0, -1.0))
	coins = game.coins
	game.tool = "seeds"
	var at: Vector2 = garden.camera.unproject_position(Vector3(3.0, 0, -1.0))
	game.tap(at, null)
	if bed2["plant"] == null or bed2["plant"]["origin"] != "nursery" or game.coins != coins:
		return _fail("sowing the nursery's seed (plant %s, coins %d -> %d)" % [bed2["plant"], coins, game.coins])
	print("PASS nursery_check")
	quit(0)
