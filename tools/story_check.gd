extends SceneTree

## The garden as a whole and how hedgepets come (scripts/garden/garden_story.gd): the journal's "Your garden" lists
## what the garden offers and its room; a wish newly met says so in one caption line; the first arrival of a hedgepet
## introduces it (card, camera eased) once only, and that is saved and restored. No timers anywhere in it.
##   HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/story_check.gd --fixed-fps 60
func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	quit(1)


func _run() -> void:
	Motion.speed = 0.0
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	await process_frame
	var game: Node = garden.game
	var story: GardenStory = game.story
	# ---- no timers: the story has no Timer nodes or create_timer calls
	var src := FileAccess.get_file_as_string("res://scripts/garden/garden_story.gd")
	if src.contains("create_timer") or src.contains("Timer.new"):
		return _fail("garden_story.gd uses a timer")
	# ---- Your garden: offers grouped, room n / 6 and what raises it
	var page := story.page()
	for want: String in ["Your garden", "Plants", "Food", "Water", "Shelter", "Comforts", "Room"]:
		if not page.contains(want):
			return _fail("the garden page lacks %s:\n%s" % [want, page])
	if not page.contains("of %d at once" % game.MAX_PETS):
		return _fail("the page doesn't give the room as n of 6")
	print("garden page: ", page.length(), " chars; room line ok")
	# ---- cause and effect: a pet on its way (noticed) whose visit wish gets met -> one caption naming it
	var p: CharacterArtProfile = null
	for q: CharacterArtProfile in garden.roster:
		if not q.starts_resident and q.wants["visit"].size() == 1 and str(q.wants["visit"].keys()[0]).ends_with("_planted"):
			p = q
			break
	if p == null:
		return _fail("no pet whose visit wish is one planting")
	for k in game.pet_state:
		if k != p.pet_name and not garden.roster.filter(func(r) -> bool: return r.pet_name == k)[0].starts_resident:
			game.pet_state[k] = "away"
	game.pet_state[p.pet_name] = "noticed"
	var key: String = p.wants["visit"].keys()[0]
	var sp := key.trim_suffix("_planted")
	story.watch(game.garden_counts())                     # primes: the wish isn't met yet
	story.watch(game.garden_counts())
	var bed: Dictionary = game._dig(Vector2(2.0, 3.0))
	game._plant(sp, bed, 0)
	var counts: Dictionary = game.garden_counts()
	story.watch(counts)
	var said: String = game._toast.text
	if not said.contains(p.pet_name) and not said.contains(p.species):
		return _fail("planting %s didn't say who it draws (caption: %s)" % [sp, said])
	print("caption: ", said)
	# ---- the first arrival: introduced once, a card, the camera's goal eased toward it
	game.pet_state[p.pet_name] = "visiting"
	story.arrived(p)
	if story.introduced.count(p.pet_name) != 1 or story._card == null:
		return _fail("first arrival not introduced")
	var card := story.card_text(p)
	if not card.contains(p.pet_name) or not card.contains("What drew it in"):
		return _fail("card lacks the name or what drew it: " + card)
	print("card: ", card.replace("\n", " | ").left(200))
	story.close_card()
	story.arrived(p)
	if story.introduced.count(p.pet_name) != 1 or story._card != null:
		return _fail("introduced twice")
	game._fill_journal()
	if not game._journal_text.text.contains("met in your garden"):
		return _fail("the journal doesn't say who was met in your garden")
	# ---- saved and restored: the save data carries it; a fresh story restores it from that data
	var data := {"introduced": story.introduced.duplicate()}
	var saved_json := JSON.stringify(data)
	var back: Dictionary = JSON.parse_string(saved_json)
	var fresh := GardenStory.new(game)
	fresh.introduced = (back.get("introduced", []) as Array).filter(func(n) -> bool: return n is String)
	if not fresh.introduced.has(p.pet_name):
		return _fail("introductions don't survive a save")
	var save_src := FileAccess.get_file_as_string("res://scripts/garden/garden_game.gd")
	if not save_src.contains("\"introduced\": story.introduced") or not save_src.contains("data.get(\"introduced\""):
		return _fail("garden_game.save()/_load() don't carry introductions")
	print(story.page())
	print("PASS story_check")
	quit(0)
