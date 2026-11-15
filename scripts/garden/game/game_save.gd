extends "res://scripts/garden/game/game_friends.gd"

## Game 5/7 - saving: what goes into user://garden.json (web: localStorage), loading it back, keeping old saves working.
##
## Saved every few seconds and on leaving; on the web also to localStorage (WebSave). _load() is forgiving on purpose:
## missing keys get defaults and old layouts are migrated (_moved_state), so an old save never breaks the game. Never
## change a key's meaning without a migration here.
##
## Part of the garden game layer chain (the full order is at the top of scripts/garden/garden_game.gd). Code here was moved verbatim
## from the old single file; only its place changed.

## The garden loop. Tidy, grow, attract, keep.
##   Tools  ✋ hand (pet them, look at things) · 🪏 shovel (clear junk for scrap coins; dig a seedbed on bare lawn)
##          🌱 seeds (plant ivy, clover, fern or jasmine in a seedbed) · 💧 water (watered plants grow)
##   Plants mound -> sprout -> bush -> flowering, while watered (water dries out).
##   Pets   each species NOTICES the garden (peeks through the gap in the fence), VISITS (comes in, wanders) and
##          MOVES IN (stays; brings a few coins now and then) when its wishes are met (CharacterArtProfile.wants).
##          Junk is not all bad: some visitors want sticks, a leaf pile, a puddle, the tipped chair.
##   Journal what you know about each pet: the hint for its next step, revealed as it gets closer.
##   Water  💧 hold and drag to pour. Hedgepets love water: the ones nearby trot after it, and the ones that reach it
##          walk with you a while (into the woods over the footbridge too). Pour a trail into an empty bucket and the
##          first to reach it climbs in; pick the bucket up with ✋ and carry it (tap the lawn with ✋ to set it down).
##   Saved to user://garden.json every few seconds and whenever you leave (on the web also to localStorage: WebSave).

var save_path := "user://garden.json"
var woods_finds := {"taken": {}, "basket": {}, "binoculars": {}}   # woods.gd: finds and the quiet things seen from the ridge
var shovelful := false              # the 🪏 is carrying a load of dirt
var barrow: Dictionary = {}         # the wheelbarrow's thing (garden.things), its load in barrow["load"]
func debug_coins() -> void:
	coins += 100
	toast("🪙 +100 (debug)")
	_refresh()
	save()


# ------------------------------------------------------------------ save
var _last_saved_state := ""                         # autosave serialises to detect changes, but avoids unchanged web I/O


func save(force := false) -> void:
	if OS.get_environment("HEDGEPETS_FRESH") != "":
		return                                           # captures and checks never touch the player's garden
	var save_started := HitchLog.begin("save")
	var data := {"coins": coins, "cleared": cleared, "gone": [], "beds": [], "pets": pet_state, "plants": pet_plant,
		"moved": _moved_state(),
		"mended": {"fence": range(garden.fence_sections.size()).filter(func(i) -> bool: return garden.fence_sections[i]["mended"]),
			"sprinkler": garden.things.any(func(t) -> bool: return t["kind"] == "sprinkler" and t.get("fixed", false))},
		"gifts": gifts.map(func(g) -> Dictionary: return {"x": g["at"].x, "z": g["at"].z, "icon": g["node"].text, "value": g["value"]}),
		"flowers": pet_flowers,
		"last_visit": 0.0,
		"barrel": {"contents": grab.contents, "next_pickup": grab.next_pickup},
		"following": following, "carried": carried, "nursery": nursery, "introduced": story.introduced, "keep_seeds": keep_seeds, "woods_finds": woods_finds, "collection": collection, "contraband": contraband,
		"dirt": dirt_piles.map(func(d) -> Array: return [d["at"].x, d["at"].y, d["loads"]]), "shovelful": shovelful,
		"barrow": {"x": barrow["node"].position.x, "z": barrow["node"].position.z, "load": int(barrow.get("load", 0))} if barrow.has("node") else {},
		"discovered": discovered, "placed": placed.map(func(b) -> Dictionary: return {"kind": b["kind"], "x": b["node"].position.x, "z": b["node"].position.z, "yaw": b["node"].rotation_degrees.y})}
	var present := {}
	for t in garden.things:
		present[t["id"]] = true
	for id in _all_ids:
		if not present.has(id):
			data["gone"].append(id)
	for b in seedbeds:
		var pl = b["plant"]
		data["beds"].append({"x": b["at"].x, "z": b["at"].y, "plant": null if pl == null else {"species": pl["species"], "stage": pl["stage"], "water": pl["water"], "progress": pl["progress"],
			"genes": pl["genes"], "origin": pl["origin"]}})
	var state := JSON.stringify(data)
	if not force and state == _last_saved_state:
		HitchLog.end("save", save_started)
		return
	_last_saved_state = state
	data["last_visit"] = Time.get_unix_time_from_system()
	var text := JSON.stringify(data)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	WebSave.put(save_path, text)                          # the browser's copy, written at once (web only)
	HitchLog.end("save", save_started)


## Leaving (tab hidden, app sent to the background, window closed): save right then, not up to 8 s later.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if garden != null and is_instance_valid(garden) and _loaded:
			save(true)
			Telemetry.event("hidden")
			Telemetry.flush()


var _all_ids: Array = []
## Things you've worked on (moved, yanked loose, righted, scrubbed): saved by id.
func _moved_state() -> Dictionary:
	var out := {}
	for t in garden.things:
		if t.has("lb") and (t.get("moved", false) or float(t.get("stuck", 1.0)) <= 0.0 or float(t.get("scrub", 0.0)) > 0.0 or not t.get("tipped", true)) and not t.get("placed", false):
			out[t["id"]] = {"x": t["node"].position.x, "z": t["node"].position.z, "stuck": t["stuck"], "tipped": t.get("tipped", false), "scrub": t.get("scrub", 0.0)}
	return out


func _load() -> void:
	for t in garden.things:
		_all_ids.append(t["id"])
	_loaded = true
	var text := WebSave.newest(save_path)
	if text == "" or OS.get_environment("HEDGEPETS_FRESH") != "":
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = int(data.get("coins", coins))
	cleared = int(data.get("cleared", 0))
	var gone: Array = data.get("gone", [])
	for t in garden.things.duplicate():
		if gone.has(t["id"]):
			garden.things.erase(t)
			t["node"].queue_free()
	for b in data.get("beds", []):
		var bed := _dig(Vector2(float(b["x"]), float(b["z"])))
		var pl = b.get("plant")
		if pl != null:
			_plant(str(pl["species"]), bed, int(pl["stage"]), float(pl["water"]), float(pl["progress"]), str(pl.get("genes", Heredity.STOCK)), str(pl.get("origin", "seed")))
	pet_flowers = data.get("flowers", {})
	for g in data.get("gifts", []):
		_restore_gift(str(g["icon"]), Vector3(float(g["x"]), 0, float(g["z"])), int(g["value"]))
	_away_for = Time.get_unix_time_from_system() - float(data.get("last_visit", Time.get_unix_time_from_system()))
	var mended: Dictionary = data.get("mended", {})
	for i in mended.get("fence", []):
		garden.mend_fence(int(i), true)
	if mended.get("sprinkler", false):
		for t in garden.things:
			if t["kind"] == "sprinkler":
				grab.fix_sprinkler(t, true)
	var bin: Dictionary = data.get("barrel", {})
	grab.contents = bin.get("contents", [])
	grab.next_pickup = float(bin.get("next_pickup", 0.0))
	if not grab.contents.is_empty() and grab.next_pickup > 0.0 and Time.get_unix_time_from_system() >= grab.next_pickup:
		grab._pickup(true)                              # the truck came while you were away
	grab._show_fill()
	var moved: Dictionary = data.get("moved", {})
	for t in garden.things:
		if moved.has(t["id"]):
			grab.grabbable(t)
			var m: Dictionary = moved[t["id"]]
			var node: Node3D = t["node"]
			node.position = Vector3(float(m["x"]), 0, float(m["z"]))
			t["at"] = Vector2(node.position.x, node.position.z) + t.get("offset", Vector2.ZERO)
			t["stuck"] = float(m.get("stuck", 0.0))
			t["moved"] = true
			if not m.get("tipped", true) and t.get("tipped", false):
				grab.set_chair_upright(t)
			if m.has("scrub"):
				t["scrub"] = float(m["scrub"])
				t["rusty"] = t["scrub"] < 1.0
				grab.set_rust(t, clampf(t["scrub"], 0.0, 1.0))
	pet_plant = data.get("plants", {})
	discovered = data.get("discovered", {})
	for b in data.get("placed", []):
		_place(str(b["kind"]), Vector2(float(b["x"]), float(b["z"])), float(b["yaw"]), false)
	following = (data.get("following", []) as Array).filter(func(n) -> bool: return n is String)
	carried = str(data.get("carried", ""))
	story.introduced = (data.get("introduced", []) as Array).filter(func(n) -> bool: return n is String)
	var ns = data.get("nursery", {})
	if ns is Dictionary:
		for k in ns:
			nursery[k] = ns[k]
	var wf = data.get("woods_finds", {})
	if wf is Dictionary:
		woods_finds["taken"] = wf.get("taken", {}) if wf.get("taken", {}) is Dictionary else {}
		woods_finds["basket"] = wf.get("basket", {}) if wf.get("basket", {}) is Dictionary else {}
	var saved_collection = data.get("collection", {})
	if saved_collection is Dictionary:
		collection = saved_collection
	for d in data.get("dirt", []):
		if d is Array and d.size() == 3:
			var pile := {"at": Vector2(float(d[0]), float(d[1])), "loads": int(d[2]), "node": null}
			dirt_piles.append(pile)
			_dirt_look(pile)
	shovelful = bool(data.get("shovelful", false))
	if data.get("contraband", {}) is Dictionary:
		contraband = data.get("contraband", {})
	var bw = data.get("barrow", {})
	if bw is Dictionary and bw.has("x") and barrow.has("node"):
		barrow["node"].position = Vector3(float(bw["x"]), 0, float(bw["z"]))
		barrow["at"] = Vector2(float(bw["x"]), float(bw["z"]))
		grab.barrow_load(barrow, int(bw.get("load", 0)))
	keep_seeds = (data.get("keep_seeds", []) as Array).filter(func(k) -> bool: return k is Dictionary and SEEDS.has(str(k.get("species", ""))))
	var saved: Dictionary = data.get("pets", {})
	for name in saved:
		if pet_state.has(name):
			pet_state[name] = saved[name]
	if not data.has("introduced"):                      # a garden from before introductions: whoever's in already is met
		story.introduced = pet_state.keys().filter(func(n) -> bool: return pet_state[n] in ["visiting", "resident"])
