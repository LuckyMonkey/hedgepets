extends Node

## The garden loop. Tidy, grow, attract, keep.
##   Tools  ✋ hand (pet them, look at things) · 🪏 shovel (clear junk for scrap coins; dig a seedbed on bare lawn)
##          🌱 seeds (plant ivy, clover, fern or jasmine in a seedbed) · 💧 water (watered plants grow)
##   Plants mound -> sprout -> bush -> flowering, while watered (water dries out).
##   Pets   each species NOTICES the garden (peeks through the gap in the fence), VISITS (comes in, wanders) and
##          MOVES IN (stays; brings a few coins now and then) when its wishes are met (CharacterArtProfile.wants).
##          Junk is not all bad: some visitors want sticks, a leaf pile, a puddle, the tipped chair.
##   Journal what you know about each pet: the hint for its next step, revealed as it gets closer.
##   Saved to user://garden.json every few seconds.

var save_path := "user://garden.json"
const SEEDS := {
	"ivy": {"icon": "🌿", "price": 3, "sheet": "hedgeivy"},
	"clover": {"icon": "🍀", "price": 3, "sheet": "hedgeclover"},
	"fern": {"icon": "🌾", "price": 4, "sheet": "hedgefern"},
	"jasmine": {"icon": "🌼", "price": 6, "sheet": "hedgejasmine"},
	"sage": {"icon": "🪴", "price": 4, "sheet": "hedgesage"},
	"oak": {"icon": "🌰", "price": 6, "sheet": "hedgeoak"},
	"pine": {"icon": "🌲", "price": 8, "sheet": "hedgepine"},
	"maple": {"icon": "🍁", "price": 7, "sheet": "hedgemaple"},
	"boxwood": {"icon": "🌳", "price": 5, "sheet": "hedgeboxwood"},
	"willow": {"icon": "🎋", "price": 6, "sheet": "hedgewillow"},
	"rose": {"icon": "🌹", "price": 6, "sheet": "hedgerose"},
	"lavender": {"icon": "🪻", "price": 5, "sheet": "hedgelavender"},
	"moss": {"icon": "🍃", "price": 3, "sheet": "hedgemoss"},
	"holly": {"icon": "🎄", "price": 7, "sheet": "hedgeholly"},
}
const STAGE_SECONDS := 18.0        # watered growth time per stage
const WATER_SECONDS := 40.0        # how long one watering lasts
const INCOME_SECONDS := 30.0

var garden: Node3D
var coins := 15
var cleared := 0
var tool := "hand"
var seed_choice := "ivy"
var seedbeds: Array = []           # {at: Vector2, node, plant (or null)}
var plants: Array = []             # {species, at, stage, water, progress, node, bed}
var pet_plant := {}                # pet name -> the plant it was regrafted in with ✂️ (SpeciesBuilder.PLANTS)
var pet_state := {}                # pet name -> "away" | "noticed" | "visiting" | "resident"
var _since := {}                   # pet name -> seconds its current step's wishes have been unmet
var _income := INCOME_SECONDS
var _check := 0.0
var _save := 5.0
var _ui: CanvasLayer
var _coin_label: Label
var _toast: Label
var _toast_t := 0.0
var _tool_buttons := {}
var _seed_row: GridContainer
var _journal: PanelContainer
var _journal_text: RichTextLabel


func setup(g: Node3D) -> void:
	garden = g
	_build_ui()
	for p: CharacterArtProfile in garden.roster:
		pet_state[p.pet_name] = "resident" if p.starts_resident else "away"
	_load()
	for p: CharacterArtProfile in garden.roster:
		if pet_state[p.pet_name] != "away":
			_apply_mode(_node(p), true)
	_refresh()
	toast("Tidy the garden, plant things, and see who comes by.")


# ------------------------------------------------------------------ what the garden has
func garden_counts() -> Dictionary:
	var c := {"puddle": garden.count("sprinkler"), "sticks": garden.count("stick"), "branches": garden.count("branch"),
		"rocks": garden.count("rock"), "leaf_pile": garden.count("leaf_pile"), "lawn_chair": garden.count("lawn_chair"),
		"grill": garden.count("grill"), "tire": garden.count("tire"), "pot": garden.count("pot"),
		"cleared": cleared}
	for p: CharacterArtProfile in garden.roster:
		if pet_state.get(p.pet_name, "") == "resident":
			c["has_" + p.species] = int(c.get("has_" + p.species, 0)) + 1
	for sp in SEEDS:
		c[sp + "_planted"] = 0
		c[sp + "_grown"] = 0
		c[sp + "_flowering"] = 0
	for pl in plants:
		c[pl["species"] + "_planted"] += 1
		if pl["stage"] >= 2:
			c[pl["species"] + "_grown"] += 1
		if pl["stage"] >= 3:
			c[pl["species"] + "_flowering"] += 1
	return c


func _met(wants: Dictionary, counts: Dictionary) -> bool:
	for k in wants:
		if int(counts.get(k, 0)) < int(wants[k]):
			return false
	return true


# ------------------------------------------------------------------ the loop
func _process(delta: float) -> void:
	_grow(delta)
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_visitors()
	_income -= delta
	if _income <= 0.0:
		_income = INCOME_SECONDS
		var happy := 0
		var counts := garden_counts()
		for p: CharacterArtProfile in garden.roster:
			if pet_state[p.pet_name] == "resident" and _met(p.wants["resident"], counts):
				happy += 1
		if happy > 0:
			coins += 2 * happy
			toast("🪙 +%d from your residents" % (2 * happy))
			_refresh()
	_save -= delta
	if _save <= 0.0:
		_save = 8.0
		save()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)


const MAX_GUESTS := 3              # peeking + visiting at once: a garden is visited, not mobbed
const NOTICE_GAP := 14.0           # seconds between new faces at the fence
var _notice_wait := 4.0


func _visitors() -> void:
	var counts := garden_counts()
	_notice_wait -= 1.0
	var guests := 0
	for k in pet_state:
		if pet_state[k] == "noticed" or pet_state[k] == "visiting":
			guests += 1
	var order: Array = garden.roster.duplicate()
	order.shuffle()
	for p: CharacterArtProfile in order:
		var name := p.pet_name
		var state: String = pet_state[name]
		var next := state
		match state:
			"away":
				if guests < MAX_GUESTS and _notice_wait <= 0.0 and _met(p.wants["notice"], counts):
					guests += 1
					_notice_wait = NOTICE_GAP
					next = "noticed"
					toast("Someone's peeking through the gap in the fence…")
			"noticed":
				if _met(p.wants["visit"], counts):
					next = "visiting"
					toast("%s came in to have a look around." % name)
				elif not _met(p.wants["notice"], counts):
					next = "away"
			"visiting":
				if _met(p.wants["resident"], counts):
					next = "resident"
					coins += 10
					toast("🏡 %s moved in! (🪙 +10)" % name)
				elif not _met(p.wants["visit"], counts):
					_since[name] = float(_since.get(name, 0.0)) + 1.0
					if float(_since[name]) > 20.0:
						next = "noticed" if _met(p.wants["notice"], counts) else "away"
						toast("%s wandered off." % name)
		if next != state:
			_since[name] = 0.0
			pet_state[name] = next
			_apply_mode(_node(p))
			_refresh()


## The pet's node in the garden, grown in whatever plant you last regrafted it in.
func _node(p: CharacterArtProfile) -> HedgePetNode:
	var node: HedgePetNode = garden.node_for(p)
	var want: String = pet_plant.get(p.pet_name, "")
	if want != "" and SpeciesBuilder.plant_of(node.profile) != want:
		node.set_plant(want)
	return node


func _apply_mode(node: HedgePetNode, at_once := false) -> void:
	var state: String = pet_state[node.profile.pet_name]
	var mode: String = {"away": "away", "noticed": "peek", "visiting": "roam", "resident": "roam"}[state]
	if garden.pet_mode(node) == "roam" and mode == "away" and not at_once:
		mode = "leave"
	if garden.pet_mode(node) != mode:
		garden.set_pet_mode(node, mode, at_once)


func _grow(delta: float) -> void:
	for pl in plants:
		if pl["water"] > 0.0:
			pl["water"] = maxf(0.0, pl["water"] - delta / WATER_SECONDS)
			if pl["stage"] < 3:
				pl["progress"] += delta / STAGE_SECONDS
				if pl["progress"] >= 1.0:
					pl["progress"] = 0.0
					pl["stage"] += 1
					_build_plant(pl)
					if pl["stage"] == 3:
						toast("Your %s is flowering." % pl["species"])


# ------------------------------------------------------------------ tools
## A tap on the garden. Returns true when the game used it (the garden then does nothing else).
func tap(at: Vector2, pet: HedgePetNode) -> bool:
	if at.y > garden.get_viewport().get_visible_rect().size.y * 0.86 or at.y < 120:
		return true                                      # the toolbar and the top bar
	var g: Vector3 = garden.ground_point(at)
	if g == Vector3.INF:
		return false
	var p2 := Vector2(g.x, g.z)
	match tool:
		"hand":
			if pet != null:
				pet.tap()
				pet.look_point = garden.camera.global_position
				toast(_pet_line(pet))
				return true
			var t = _thing_at(p2)
			if t != null:
				toast(_thing_line(t))
			return true
		"shovel":
			var t = _thing_at(p2)
			if t != null:
				if not t["junk"]:
					toast("That stays.")
					return true
				_clear(t)
				return true
			if _blocked_for_bed(p2):
				toast("Not here - too close to something.")
				return true
			_dig(p2)
			return true
		"seeds":
			var bed = _bed_at(p2)
			if bed == null:
				toast("Dig a seedbed first (🪏).")
				return true
			if bed["plant"] != null:
				toast("Something's already growing there.")
				return true
			var price: int = SEEDS[seed_choice]["price"]
			if coins < price:
				toast("Not enough coins for %s seeds (🪙 %d)." % [seed_choice, price])
				return true
			coins -= price
			_plant(seed_choice, bed, 0)
			_refresh()
			return true
		"shears":
			if pet == null:
				toast("Tap a pet to regraft it in %s %s (🪙 %d)." % [SEEDS[seed_choice]["icon"], seed_choice, SEEDS[seed_choice]["price"]])
				return true
			var price: int = SEEDS[seed_choice]["price"]
			if SpeciesBuilder.plant_of(pet.profile) == seed_choice:
				toast("%s is already %s." % [pet.profile.pet_name, seed_choice])
			elif coins < price:
				toast("Regrafting in %s costs 🪙 %d." % [seed_choice, price])
			else:
				coins -= price
				pet_plant[pet.profile.pet_name] = seed_choice
				pet.set_plant(seed_choice)
				toast("✂️ %s is growing in %s now." % [pet.profile.pet_name, seed_choice])
				_refresh()
			return true
		"water":
			var pl = _plant_at(p2)
			if pl == null:
				toast("Water a plant (tap right on it).")
				return true
			pl["water"] = 1.0
			toast("💧 Watered the %s." % pl["species"])
			_splash(Vector3(pl["at"].x, 0.2, pl["at"].y))
			return true
	return false


func _thing_at(p: Vector2):
	var best = null
	var best_d := 1e9
	for t in garden.things:
		var d: float = p.distance_to(t["at"])
		if d < maxf(float(t["radius"]), 0.7) and d < best_d:
			best = t
			best_d = d
	return best


func _bed_at(p: Vector2):
	for b in seedbeds:
		if p.distance_to(b["at"]) < 0.9:
			return b
	return null


func _plant_at(p: Vector2):
	for pl in plants:
		if p.distance_to(pl["at"]) < 1.0:
			return pl
	return null


func _blocked_for_bed(p: Vector2) -> bool:
	if not garden.BOUNDS.has_point(p) or garden._blocked(p, 0.4):
		return true
	for b in seedbeds:
		if p.distance_to(b["at"]) < 1.6:
			return true
	return false


func _clear(t: Dictionary) -> void:
	garden.things.erase(t)
	cleared += 1
	coins += int(t["value"])
	var node: Node3D = t["node"]
	var tw := garden.create_tween()
	tw.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)
	toast("🪏 Cleared the %s. 🪙 +%d" % [_thing_name(t["kind"]), t["value"]])
	_refresh()


func _dig(p: Vector2) -> Dictionary:
	var bed := {"at": p, "node": null, "plant": null}
	var node := GardenProps.part(garden, GardenProps.blob(Vector3(0.7, 0.06, 0.6), "pebble"), GardenProps.mat("seedbed", Color("6a5038")), Vector3(p.x, 0.0, p.y), Vector3(0, randf() * 360.0, 0), 0.0)
	node.name = "Seedbed"
	bed["node"] = node
	seedbeds.append(bed)
	return bed


func _plant(species: String, bed: Dictionary, stage: int, water := 0.6, progress := 0.0) -> Dictionary:
	var pl := {"species": species, "at": bed["at"], "stage": stage, "water": water, "progress": progress, "node": null, "bed": bed}
	bed["plant"] = pl
	plants.append(pl)
	_build_plant(pl)
	if stage == 0:
		toast("%s Planted %s. Water it (💧)." % [SEEDS[species]["icon"], species])
	return pl


func _build_plant(pl: Dictionary) -> void:
	if pl["node"] != null:
		pl["node"].queue_free()
	var at := Vector3(pl["at"].x, 0.0, pl["at"].y)
	var stage: int = pl["stage"]
	var holder := Node3D.new()
	holder.name = "Plant_" + pl["species"]
	garden.add_child(holder)
	if stage == 0:
		GardenProps.part(holder, GardenProps.blob(Vector3(0.25, 0.12, 0.25), "dome"), GardenProps.mat("mound", Color("5c432e")), at, Vector3.ZERO, 0.0)
	else:
		var size: float = [0.0, 0.32, 0.55, 0.62][stage]
		var look: Array = SpeciesBuilder.PLANTS[pl["species"]]
		var palette := SpeciesBuilder.palette_of(look[0])
		var bush: Node3D = garden._bush(at + Vector3(0, size * 0.75, 0), Vector3(size, size * 0.85, size), SEEDS[pl["species"]]["sheet"], palette, Color(SpeciesBuilder.PALETTES[look[0]][6]), 0.22 + size * 0.2, 1.6, "dome", 1.0 if stage == 3 else 0.0)
		bush.reparent(holder)
	pl["node"] = holder


func _splash(at: Vector3) -> void:
	var drop := Label3D.new()
	drop.text = "💧"
	drop.font_size = 64
	drop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	drop.position = at + Vector3(0, 0.8, 0)
	garden.add_child(drop)
	var tw := garden.create_tween()
	tw.tween_property(drop, "position", at + Vector3(0, 1.6, 0), 0.8)
	tw.parallel().tween_property(drop, "modulate:a", 0.0, 0.8)
	tw.tween_callback(drop.queue_free)


# ------------------------------------------------------------------ words
func _thing_name(kind: String) -> String:
	return {"lawn_chair": "lawn chair", "grill": "rusty grill", "sprinkler": "broken sprinkler", "tire": "old tire",
		"pot": "flowerpot", "branch": "branch", "stick": "stick", "rock": "rock", "leaf_pile": "leaf pile"}.get(kind, kind)


func _thing_line(t: Dictionary) -> String:
	return {"lawn_chair": "A tipped-over lawn chair. Cosy underneath, if you're small.",
		"grill": "A rusty grill. Nobody's cooked on it in years.",
		"sprinkler": "The sprinkler's broken - it just leaks. There's a nice puddle, though.",
		"tire": "An old tire. Why is there always an old tire?",
		"pot": "A tipped flowerpot. The soil's all over the place.",
		"branch": "A fallen branch.", "stick": "A stick. Somebody might want this.",
		"rock": "A sun-warmed rock.", "leaf_pile": "A pile of old leaves, raked and forgotten."}.get(t["kind"], "Something in the grass.")


func _pet_line(pet: HedgePetNode) -> String:
	var p: CharacterArtProfile = pet.profile
	match pet_state[p.pet_name]:
		"resident":
			return "%s lives here. %s" % [p.pet_name, "Happy as anything." if _met(p.wants["resident"], garden_counts()) else "Something's missing: " + p.hints["resident"]]
		"visiting":
			return "%s is visiting. %s" % [p.pet_name, p.hints["resident"]]
		_:
			return "%s is peeking in. %s" % [p.pet_name, p.hints["visit"]]


# ------------------------------------------------------------------ ui
func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 4.0
	_toast.modulate.a = 1.0


func _refresh() -> void:
	_coin_label.text = "🪙 %d" % coins
	for t in _tool_buttons:
		_tool_buttons[t].modulate = Color(1, 1, 1, 1.0 if t == tool else 0.55)
	_seed_row.visible = tool == "seeds" or tool == "shears"
	for b in _seed_row.get_children():
		b.modulate = Color(1, 1, 1, 1.0 if b.name == seed_choice else 0.55)
	if _journal.visible:
		_fill_journal()


func _fill_journal() -> void:
	var lines := "[b]Journal[/b]\n\n"
	var counts := garden_counts()
	var unseen: Array = []
	for p: CharacterArtProfile in garden.roster:
		var state: String = pet_state[p.pet_name]
		if state == "away":
			unseen.append(p)
			continue
		var label: String = {"away": "not seen yet", "noticed": "peeking in", "visiting": "visiting", "resident": "lives here"}[state]
		var step: String = {"away": "notice", "noticed": "visit", "visiting": "resident", "resident": "resident"}[state]
		var hint: String = p.hints[step] if state != "away" or cleared > 0 else "???"
		if state == "away" and not _met(p.wants["notice"], counts):
			hint = p.hints["notice"]
		lines += "[b]%s[/b] the %s - %s\n%s\n\n" % [p.pet_name, p.species, label, hint]
	# rumours: a few of the ones you haven't met, the nearest to noticing first
	lines += "[b]Around the neighbourhood[/b] (%d not seen yet)\n\n" % unseen.size()
	unseen.sort_custom(func(a, b) -> bool: return _missing(a.wants["notice"], counts) < _missing(b.wants["notice"], counts))
	for p: CharacterArtProfile in unseen.slice(0, 4):
		lines += "%s %s\n\n" % ["🐾", p.hints["notice"]]
	_journal_text.text = lines


func _missing(wants: Dictionary, counts: Dictionary) -> int:
	var n := 0
	for k in wants:
		n += maxi(0, int(wants[k]) - int(counts.get(k, 0)))
	return n


func _button(text: String, tip: String, size := 64) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.flat = true
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(120, 110)
	return b


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	_ui.name = "GameUI"
	garden.add_child(_ui)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.9, 0.85)
	style.set_corner_radius_all(28)
	style.set_content_margin_all(12)
	# top: coins and the journal
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 44)
	_coin_label.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
	_coin_label.position = Vector2(40, 30)
	_ui.add_child(_coin_label)
	var jb := _button("📖", "Journal: who might come, and what they like", 52)
	jb.position = Vector2(930, 10)
	jb.pressed.connect(func() -> void:
		_journal.visible = not _journal.visible
		_refresh())
	_ui.add_child(jb)
	# a message line
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_color", Color(0.25, 0.2, 0.14))
	_toast.add_theme_stylebox_override("normal", style)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(90, 140)
	_toast.size = Vector2(900, 0)
	_ui.add_child(_toast)
	# bottom: tools
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.position = Vector2(60, 1770)
	bar.size = Vector2(960, 120)
	bar.add_theme_constant_override("separation", 14)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(120, 1760)
	panel.size = Vector2(840, 130)
	_ui.add_child(panel)
	panel.add_child(bar)
	for t: Array in [["hand", "✋", "Hand: pet them, look at things"], ["shovel", "🪏", "Shovel: clear junk for coins, or dig a seedbed"],
			["seeds", "🌱", "Seeds: plant in a seedbed"], ["shears", "✂️", "Shears: regraft a pet in the chosen plant"], ["water", "💧", "Water: watered plants grow"]]:
		var b := _button(t[1], t[2])
		var key: String = t[0]
		b.pressed.connect(func() -> void:
			tool = key
			_refresh())
		bar.add_child(b)
		_tool_buttons[key] = b
	_seed_row = GridContainer.new()
	_seed_row.columns = 7
	_seed_row.position = Vector2(68, 1560)
	_seed_row.add_theme_constant_override("h_separation", 8)
	_seed_row.add_theme_constant_override("v_separation", 6)
	for sp in SEEDS:
		var b := _button("%s%d" % [SEEDS[sp]["icon"], SEEDS[sp]["price"]], "%s seeds" % sp, 32)
		b.name = sp
		b.custom_minimum_size = Vector2(128, 90)
		b.pressed.connect(func() -> void:
			seed_choice = sp
			_refresh())
		_seed_row.add_child(b)
	_ui.add_child(_seed_row)
	_journal = PanelContainer.new()
	_journal.add_theme_stylebox_override("panel", style)
	_journal.position = Vector2(90, 260)
	_journal.size = Vector2(900, 1100)
	_journal.visible = false
	_journal_text = RichTextLabel.new()
	_journal_text.bbcode_enabled = true
	_journal_text.add_theme_font_size_override("normal_font_size", 30)
	_journal_text.add_theme_font_size_override("bold_font_size", 34)
	_journal_text.add_theme_color_override("default_color", Color(0.25, 0.2, 0.14))
	_journal_text.custom_minimum_size = Vector2(860, 1060)
	_journal.add_child(_journal_text)
	_ui.add_child(_journal)


# ------------------------------------------------------------------ save
func save() -> void:
	if OS.get_environment("HEDGEPETS_FRESH") != "":
		return                                           # captures and checks never touch the player's garden
	var data := {"coins": coins, "cleared": cleared, "gone": [], "beds": [], "pets": pet_state, "plants": pet_plant}
	var present := {}
	for t in garden.things:
		present[t["id"]] = true
	for id in _all_ids:
		if not present.has(id):
			data["gone"].append(id)
	for b in seedbeds:
		var pl = b["plant"]
		data["beds"].append({"x": b["at"].x, "z": b["at"].y, "plant": null if pl == null else {"species": pl["species"], "stage": pl["stage"], "water": pl["water"], "progress": pl["progress"]}})
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


var _all_ids: Array = []


func _load() -> void:
	for t in garden.things:
		_all_ids.append(t["id"])
	if not FileAccess.file_exists(save_path) or OS.get_environment("HEDGEPETS_FRESH") != "":
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
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
			_plant(str(pl["species"]), bed, int(pl["stage"]), float(pl["water"]), float(pl["progress"]))
	pet_plant = data.get("plants", {})
	var saved: Dictionary = data.get("pets", {})
	for name in saved:
		if pet_state.has(name):
			pet_state[name] = saved[name]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if garden != null and is_instance_valid(garden):
			save()
