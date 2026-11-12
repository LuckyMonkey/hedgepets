class_name GardenStory
extends RefCounted

## What the garden is, as a whole, and how hedgepets come to it (owner 2026-11-12). Everything here is read from the
## same data the game already runs on - each pet's `wants` (CharacterArtProfile), garden_game.garden_counts(),
## capacity(), grows_for() - never a second rule set. Three things:
##   page()     "Your garden" in the journal: what it offers, grouped, each offer with the hedgepets it draws (met ones
##              by name, unmet ones as their animal - some mystery), and the room (n / 6 and what raises it).
##   watch()    cause and effect, gently: when something you plant or build newly meets a wish of a hedgepet on its way
##              in, one caption line ("A fox would like a leaf pile like that."). No pop-ups, no counters.
##   arrived()  the first time each hedgepet comes into your garden: the camera eases toward it (the player can take it
##              back at any moment) and a small card introduces it. Once per hedgepet per garden; saved.
## No timers, no urgency, nothing lost: watching is valid play.

var game: Node                          # scripts/garden/garden_game.gd
var introduced: Array = []              # pet names met in your garden (saved)
var _wished := {}                       # pet name -> {want key: met} for its next step (cause and effect)
var _primed := false
var _card: PanelContainer

const GROUPS := [
	["🍎", "Food", ["feeder", "apples", "pumpkin", "grill"]],
	["💧", "Water", ["puddle", "bath"]],
	["🪵", "Shelter", ["log_pile", "nest_box", "leaf_pile", "brush_pile", "woodpile", "rocks", "sticks", "branches", "tire", "pot"]],
	["🪑", "Comforts", ["lawn_chair", "clearing", "cleared"]],
]
const WORDS := {"feeder": "a bird feeder", "apples": "apples", "pumpkin": "a pumpkin", "grill": "the old grill",
	"puddle": "a puddle (the sprinkler)", "bath": "a bird bath", "log_pile": "a log pile", "nest_box": "a nest box",
	"leaf_pile": "a leaf pile", "brush_pile": "a brush pile", "woodpile": "a woodpile", "rocks": "rocks", "sticks": "sticks",
	"branches": "branches", "tire": "the old tire", "pot": "flowerpots", "lawn_chair": "the lawn chair",
	"clearing": "a sunny clearing", "cleared": "junk cleared away"}


func _init(g: Node) -> void:
	game = g


## A want key in words: "a leaf pile", "3 sticks", "fern growing", "a chipmunk living here".
static func words(key: String, n := 1) -> String:
	for suffix: String in ["_planted", "_grown", "_flowering"]:
		if key.ends_with(suffix):
			var plant: String = SpeciesBuilder.PLANT_NAMES.get(key.trim_suffix(suffix), key.trim_suffix(suffix))
			return plant + {"_planted": " planted", "_grown": " grown", "_flowering": " in flower"}[suffix] + (" (%d)" % n if n > 1 else "")
	if key.begins_with("has_"):
		return "a %s living here" % key.trim_prefix("has_")
	if key == "cleared":
		return "%d bits of junk cleared away" % n if n > 1 else "junk cleared away"
	var w: String = WORDS.get(key, key.replace("_", " "))
	if n <= 1:
		return w
	if w.begins_with("a ") or w.begins_with("the "):             # one of them -> several: "2 leaf piles", "2 nest boxes"
		var one := w.trim_prefix("a ").trim_prefix("the ")
		return "%d %s" % [n, one + ("es" if one.ends_with("x") or one.ends_with("sh") else "s")]
	return "%d %s" % [n, w]


static func wish_words(wants: Dictionary) -> String:
	var parts: Array = []
	for k in wants:
		parts.append(words(k, int(wants[k])))
	if parts.is_empty():
		return "nothing in particular"
	return parts[0] if parts.size() == 1 else ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]


static func _a(word: String) -> String:
	return ("an " if word.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + word


static func _A(word: String) -> String:
	var w := _a(word)
	return w.left(1).to_upper() + w.substr(1)


func _met_before(p: CharacterArtProfile) -> bool:
	return game.pet_state.get(p.pet_name, "away") != "away" or game.discovered.has(p.pet_name)


## Who an offer draws: met hedgepets by name, the others as their animal ("a fox"), once each.
func _drawn(keys: Array) -> String:
	var names: Array = []
	var animals: Array = []
	for p: CharacterArtProfile in game.garden.roster:
		var wants_it := false
		for step in p.wants:
			for k in p.wants[step]:
				if keys.has(k):
					wants_it = true
		if not wants_it:
			continue
		if _met_before(p):
			names.append(p.pet_name)
		elif not animals.has(_a(p.species)):
			animals.append(_a(p.species))
	var all: Array = names + animals.slice(0, 3)
	if all.is_empty():
		return ""
	return " [color=#7a6a50]- draws %s%s[/color]" % [", ".join(all), "…" if animals.size() > 3 else ""]


## The journal's "Your garden" section.
func page() -> String:
	var counts: Dictionary = game.garden_counts()
	var s := "[b]Your garden[/b]\n\n"
	# plants: each kind you grow, how it's doing, and who it draws (its wants, and the pets made of it)
	var kinds: Array = []
	for sp in game.SEEDS:
		if int(counts.get(sp + "_planted", 0)) > 0:
			kinds.append(sp)
	if kinds.is_empty():
		s += "🌱 [b]Plants[/b]: nothing planted yet.\n"
	else:
		s += "🌱 [b]Plants[/b]\n"
		for sp: String in kinds:
			var state := "%d planted" % counts[sp + "_planted"]
			if int(counts[sp + "_grown"]) > 0:
				state += ", %d grown" % counts[sp + "_grown"]
			if int(counts[sp + "_flowering"]) > 0:
				state += ", %d in flower" % counts[sp + "_flowering"]
			var drawn := _drawn([sp + "_planted", sp + "_grown", sp + "_flowering"])
			var made_of: Array = game.garden.roster.filter(func(p) -> bool: return SpeciesBuilder.variants_of(p).has(sp) and _met_before(p)).map(func(p) -> String: return p.pet_name)
			s += "   %s: %s%s%s\n" % [SpeciesBuilder.PLANT_NAMES.get(sp, sp), state, drawn,
				(" [color=#7a6a50](%s made of it)[/color]" % ", ".join(made_of)) if not made_of.is_empty() else ""]
	for g: Array in GROUPS:
		var have: Array = (g[2] as Array).filter(func(k) -> bool: return int(counts.get(k, 0)) > 0)
		if have.is_empty():
			s += "%s [b]%s[/b]: none yet.\n" % [g[0], g[1]]
			continue
		s += "%s [b]%s[/b]\n" % [g[0], g[1]]
		for k: String in have:
			s += "   %s%s\n" % [words(k, int(counts[k])), _drawn([k])]
	var company: Array = counts.keys().filter(func(k) -> bool: return str(k).begins_with("has_"))
	if not company.is_empty():
		s += "🐾 [b]Company[/b]\n"
		for k: String in company:
			s += "   %s%s\n" % [words(k, int(counts[k])), _drawn([k])]
	# room: capacity, and exactly what raises it (garden_game.capacity(): 2 + every 3 kinds grown or built)
	var cap: int = game.capacity()
	var grown := {}
	for pl in game.plants:
		if pl["stage"] >= 2:
			grown[pl["species"]] = true
	var built := {}
	for b in game.placed:
		built[b["kind"]] = true
	var n := grown.size() + built.size()
	s += "\n🏡 [b]Room[/b] for %d of %d at once. " % [cap, game.MAX_PETS]
	if cap >= game.MAX_PETS:
		s += "As much room as a garden can have.\n"
	else:
		var more := 3 * (cap - 1) - n
		s += "%d kinds of plant grown and %d kinds of thing built; %d more kind%s of either makes room for one more.\n" % [grown.size(), built.size(), more, "" if more == 1 else "s"]
	return s + "\n"


## The step each pet is working towards, and its wishes for it (away pets only once something draws them).
func _next_wants(p: CharacterArtProfile) -> Dictionary:
	match str(game.pet_state.get(p.pet_name, "away")):
		"away":
			return p.wants["notice"] if game.grows_for(p) else {}
		"noticed":
			return p.wants["visit"]
		"visiting":
			return p.wants["resident"]
	return {}


## Once a second (garden_game._visitors): a wish newly met moves a hedgepet closer - say so, one line, the first only.
func watch(counts: Dictionary) -> void:
	var said := false
	for p: CharacterArtProfile in game.garden.roster:
		var wants := _next_wants(p)
		var was: Dictionary = _wished.get(p.pet_name, {})
		var now := {}
		for k in wants:
			now[k] = int(counts.get(k, 0)) >= int(wants[k])
			if _primed and not said and now[k] and was.has(k) and not was[k]:
				said = true
				game.toast(caption(p, k, int(wants[k])))
				Telemetry.event("wish_met", {"pet": p.pet_name, "want": k})
		_wished[p.pet_name] = now
	_primed = true


## "A fox would like a leaf pile like that." / "Russet would like that fern." (met hedgepets by name)
func caption(p: CharacterArtProfile, key: String, n := 1) -> String:
	var who: String = p.pet_name if _met_before(p) else _A(p.species)
	for suffix: String in ["_planted", "_grown", "_flowering"]:
		if key.ends_with(suffix):
			var plant: String = SpeciesBuilder.PLANT_NAMES.get(key.trim_suffix(suffix), key.trim_suffix(suffix))
			return "%s would like that %s%s." % [who, plant, " in flower" if suffix == "_flowering" else ""]
	if key == "cleared":
		return "%s likes it tidier, like that." % who
	if n > 1:
		return "%s would like %s like that." % [who, words(key, n)]
	return "%s would like %s like that." % [who, words(key)]


## A hedgepet came into the garden (noticed -> visiting). The first time: ease the camera to it, introduce it.
func arrived(p: CharacterArtProfile) -> void:
	if introduced.has(p.pet_name):
		return
	introduced.append(p.pet_name)
	Telemetry.event("introduced", {"pet": p.pet_name})
	var node: HedgePetNode = game._node(p)
	var g: Node3D = game.garden
	if node != null and is_instance_valid(node) and g.has_method("_clamp_target"):
		var at := node.position
		g._goal_target = g._clamp_target(Vector3(at.x, 0.0, at.z))   # the camera's spring eases there; any drag takes over
	_show_card(p)


func card_text(p: CharacterArtProfile) -> String:
	var plant_id: String = game.pet_plant.get(p.pet_name, "")
	if plant_id == "":
		plant_id = SpeciesBuilder.native_plant(p)
	var plant: String = SpeciesBuilder.PLANT_NAMES.get(plant_id, plant_id)
	var s := "[b]%s[/b]\n[color=#7a6a50]%s, made of %s[/color]\n\n" % [p.pet_name, _A(p.species), plant.to_lower()]
	s += "What drew it in: %s.\n" % wish_words(p.wants["visit"])
	if p.starts_resident:
		return s
	s += "What would make it stay: %s.\n" % wish_words(p.wants["resident"])
	if p.hints.has("resident") and str(p.hints["resident"]) != "":
		s += "[color=#7a6a50]%s[/color]\n" % p.hints["resident"]
	return s


func _show_card(p: CharacterArtProfile) -> void:
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	var ui: CanvasLayer = game._ui
	if ui == null:
		return
	_card = PanelContainer.new()
	_card.name = "IntroCard"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.9, 0.96)
	style.set_corner_radius_all(28)
	style.set_content_margin_all(28)
	_card.add_theme_stylebox_override("panel", style)
	_card.position = Vector2(60, 220)
	_card.custom_minimum_size = Vector2(960, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_card.add_child(box)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(900, 0)
	text.add_theme_font_size_override("normal_font_size", 36)
	text.add_theme_font_size_override("bold_font_size", 46)
	text.add_theme_color_override("default_color", Color(0.3, 0.24, 0.16))
	text.text = card_text(p)
	box.add_child(text)
	var ok: Button = game._button("✓", "Nice to meet you", 44)
	ok.pressed.connect(close_card)
	box.add_child(ok)
	ui.add_child(_card)
	Motion.slide_in(_card, _card.position, Vector2(0, -30))


func close_card() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var c := _card
	_card = null
	Motion.fade(c, 0.0, Motion.FAST).finished.connect(c.queue_free)
