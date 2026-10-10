extends Node3D

## The nursery, at the end of its trail in the woods: a lamplit glasshouse, a potting bench, a seed cabinet, beehives,
## a cold frame with a little scarecrow, and the old woman who keeps it, potting by lantern light. She doesn't stop
## working to talk. Tap her and she says one thing; tap again for another. What she says comes from
## res://assets/talk/nursery.json, picked by what's true right now (the season and hour, what you grow and who lives
## with you, who came along, what's turned up in your beds) - the more particular a line, the likelier, never the
## same one twice in a while. On the third visit she has seeds for you; she buys what you've foraged (woods.gd basket).
## There is no menu, no meter and no list of what she's said. docs/NURSERY.md.

const DATA := "res://assets/talk/nursery.json"
const RECENT := 24                       # lines she won't repeat until this many others have been said
const GIFT_VISIT := 3
const PRICES := {"cone": 1, "acorn": 1, "mushroom": 2, "feather": 2, "apple": 1}

var woods: Node3D
var game: Node
var _lines: Array = []
var _lady: Node3D
var _head: Node3D
var _arm: Node3D
var _card: PanelContainer
var _card_text: Label
var _t := 0.0
var _speaking := 0.0                     # seconds left of looking up at you
var _look := 0.0                         # 0 = at the work, 1 = up at you (eased)
var _usual: Node3D                       # your usual, waiting on the counter (from the sixth visit)
var _twist: Node3D                       # the twist of seeds, before she gives it
var _greeted := false
var _cam_hint := Vector3.ZERO


func setup(w: Node3D, centre: Vector3, toward: Vector3) -> void:
	woods = w
	game = w.garden.game
	name = "Nursery"
	position = centre
	rotation.y = atan2(toward.x, toward.z)              # local +z points away from where you stand
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f != null:
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			_lines = data.get("lines", [])
	_build()
	_build_card(w._ui)


# ------------------------------------------------------------------ the place
func _y(local: Vector3) -> float:
	var g := to_global(local) - woods.global_position
	return woods.height(g.x, g.z) - (global_position.y - woods.global_position.y)


func _on_ground(local: Vector3) -> Vector3:
	return Vector3(local.x, _y(local), local.z)


func _build() -> void:
	var wood := GardenProps.mat("benchwood", Color("7a5e40"))
	var dark := GardenProps.mat("nurseryiron", Color("2e2c28"), 0.7)
	var clay := GardenProps.mat("terracotta", Color("b46a44"))
	var stem := GardenProps.mat("stemgreen", Color("4a6a36"))
	# the potting bench, between you and her
	var bench := _on_ground(Vector3(0, 0, 5.0))
	GardenProps.part(self, GardenProps.box(Vector3(2.2, 0.07, 0.75)), wood, bench + Vector3(0, 0.92, 0), Vector3.ZERO, 0.01)
	GardenProps.part(self, GardenProps.box(Vector3(2.1, 0.05, 0.65)), wood, bench + Vector3(0, 0.3, 0), Vector3.ZERO, 0.008)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			GardenProps.part(self, GardenProps.box(Vector3(0.07, 0.92, 0.07)), wood, bench + Vector3(sx * 1.02, 0.46, sz * 0.3), Vector3.ZERO, 0.006)
	# four potted lavenders on the bench: tall and short, three purple and one white
	var looks := [[true, false], [true, false], [false, false], [true, true]]   # [tall, white]
	for i in looks.size():
		var at := bench + Vector3(-0.75 + i * 0.32, 0.96, -0.12)
		GardenProps.part(self, GardenProps.cyl(0.075, 0.055, 0.13, 10), clay, at + Vector3(0, 0.065, 0), Vector3.ZERO, 0.006)
		var h: float = 0.34 if looks[i][0] else 0.2
		var bloom := GardenProps.mat("lavbloom%s" % ("w" if looks[i][1] else "p"), Color("f2eee4") if looks[i][1] else Color("8a6ac4"))
		for k in range(5):
			var lean := Vector3((k - 2) * 7.0, 0, (k % 2) * 8.0 - 4.0)
			GardenProps.part(self, GardenProps.cyl(0.006, 0.008, h, 4), stem, at + Vector3((k - 2) * 0.012, 0.13 + h * 0.5, 0), lean, 0.0)
			GardenProps.part(self, GardenProps.blob(Vector3(0.016, 0.045, 0.016), "pebble"), bloom, at + Vector3((k - 2) * 0.012 + sin(deg_to_rad(lean.z)) * -h * 0.5, 0.13 + h, sin(deg_to_rad(lean.x)) * h * 0.5), lean, 0.0)
	# seed trays, a trowel, a dibber
	for i in range(3):
		GardenProps.part(self, GardenProps.box(Vector3(0.36, 0.06, 0.24)), GardenProps.mat("seedtray", Color("3a3430")), bench + Vector3(0.35 + (i % 2) * 0.4, 0.98 + (i / 2) * 0.0, 0.1 - (i / 2) * 0.28), Vector3.ZERO, 0.004)
	GardenProps.part(self, GardenProps.box(Vector3(0.05, 0.015, 0.2)), dark, bench + Vector3(0.9, 0.965, 0.22), Vector3(0, 30, 0), 0.0)
	# your usual: a sack of potting mix with a string tie (from the sixth visit)
	_usual = Node3D.new()
	add_child(_usual)
	GardenProps.part(_usual, GardenProps.blob(Vector3(0.16, 0.2, 0.12), {"exponent": 2.4, "flat_bottom": 0.5}), GardenProps.mat("burlapsack", Color("b49a6e")), bench + Vector3(-0.95, 1.12, 0.22), Vector3(0, -15, 0), 0.008)
	_usual.visible = false
	# the twist of seeds, in newspaper (until she gives it)
	_twist = Node3D.new()
	add_child(_twist)
	GardenProps.part(_twist, GardenProps.cyl(0.0, 0.05, 0.14, 6), GardenProps.mat("newsprint", Color("e4dccb")), bench + Vector3(-0.35, 1.0, 0.25), Vector3(80, 20, 0), 0.004)
	_twist.visible = false
	# a lantern on the bench: she's lit by it
	GardenProps.lantern(self, bench + Vector3(1.25, 0, 0.1), 180.0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffc47e")
	lamp.light_energy = 0.8
	lamp.omni_range = 8.0
	lamp.position = bench + Vector3(0.9, 1.6, 0.3)
	add_child(lamp)
	_build_lady(bench + Vector3(0, 0, 0.75))
	_build_glasshouse(_on_ground(Vector3(0.6, 0, 10.0)))
	_build_cabinet(_on_ground(Vector3(-2.4, 0, 7.4)))
	for i in range(2):
		_build_hive(_on_ground(Vector3(4.2 + i * 1.1, 0, 8.0 + i * 0.4)))
	_build_cold_frame(_on_ground(Vector3(-4.2, 0, 4.5)))
	# pots stacked by the path, and a water butt
	for i in range(6):
		GardenProps.part(self, GardenProps.cyl(0.14, 0.1, 0.22, 10), clay, _on_ground(Vector3(2.2, 0, 4.4)) + Vector3(0, 0.11 + i * 0.07, 0), Vector3(0, i * 20, 0), 0.006)
	var butt := _on_ground(Vector3(-1.6, 0, 9.8))
	GardenProps.part(self, GardenProps.cyl(0.38, 0.34, 0.95, 14), GardenProps.mat("waterbutt", Color("3e4a3a")), butt + Vector3(0, 0.47, 0), Vector3.ZERO, 0.012)


## Her: small, a little stooped, grey hair up in a bun, a cardigan, an apron, a long tweed skirt. Built from the same
## soft solids as the garden's things. Her head and her working arm are pivots (the potting, the looking up).
func _build_lady(at: Vector3) -> void:
	_lady = Node3D.new()
	_lady.name = "Lady"
	_lady.position = at
	_lady.rotation.y = PI                                # facing you across the bench
	add_child(_lady)
	var skin := GardenProps.mat("ladyskin", Color("e6c6ac"))
	var skirt := GardenProps.mat("ladytweed", Color("5c5446"))
	var cardigan := GardenProps.mat("ladycardigan", Color("5e6a4a"))
	var apron := GardenProps.mat("ladyapron", Color("b2a282"))
	var hair := GardenProps.mat("ladyhair", Color("d6d2ca"))
	var clog := GardenProps.mat("ladyclog", Color("3a2c22"))
	for side: float in [-1.0, 1.0]:
		GardenProps.part(_lady, GardenProps.blob(Vector3(0.06, 0.05, 0.11), {"exponent": 2.2, "flat_bottom": 0.6}), clog, Vector3(side * 0.08, 0.04, 0.04), Vector3.ZERO, 0.006)
	GardenProps.part(_lady, GardenProps.cyl(0.19, 0.3, 0.82, 14), skirt, Vector3(0, 0.47, 0), Vector3.ZERO, 0.012)
	var body := Node3D.new()
	body.position = Vector3(0, 0.86, 0)
	body.rotation_degrees.x = 9.0                       # a little stoop over the work
	_lady.add_child(body)
	GardenProps.part(body, GardenProps.blob(Vector3(0.2, 0.27, 0.15), {"exponent": 2.6}), cardigan, Vector3(0, 0.22, 0), Vector3.ZERO, 0.012)
	GardenProps.part(body, GardenProps.blob(Vector3(0.15, 0.24, 0.03), {"exponent": 3.0}), apron, Vector3(0, 0.12, 0.13), Vector3.ZERO, 0.006)
	GardenProps.part(body, GardenProps.blob(Vector3(0.25, 0.08, 0.17), {"exponent": 2.4}), GardenProps.mat("ladyshawl", Color("8a5848")), Vector3(0, 0.44, 0), Vector3.ZERO, 0.01)
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.21, 0.42, 0.02)
		arm.rotation_degrees = Vector3(-38, 0, side * 8)    # reaching down and forward to the bench
		body.add_child(arm)
		GardenProps.part(arm, GardenProps.cyl(0.045, 0.055, 0.46, 8), cardigan, Vector3(0, -0.22, 0), Vector3.ZERO, 0.008)
		GardenProps.part(arm, GardenProps.blob(Vector3(0.04, 0.05, 0.035), "pebble"), skin, Vector3(0, -0.48, 0), Vector3.ZERO, 0.004)
		if side > 0.0:
			_arm = arm
	_head = Node3D.new()
	_head.position = Vector3(0, 0.52, 0.02)
	body.add_child(_head)
	GardenProps.part(_head, GardenProps.blob(Vector3(0.105, 0.125, 0.11), {"exponent": 2.0}), skin, Vector3(0, 0.12, 0), Vector3.ZERO, 0.008)
	GardenProps.part(_head, GardenProps.blob(Vector3(0.115, 0.1, 0.115), {"exponent": 2.0}), hair, Vector3(0, 0.17, -0.02), Vector3.ZERO, 0.008)
	GardenProps.part(_head, GardenProps.blob(Vector3(0.06, 0.055, 0.06), "pebble"), hair, Vector3(0, 0.25, -0.08), Vector3.ZERO, 0.006)
	GardenProps.part(_head, GardenProps.blob(Vector3(0.018, 0.022, 0.02), "pebble"), skin, Vector3(0, 0.11, 0.11), Vector3.ZERO, 0.0)
	for side: float in [-1.0, 1.0]:                      # spectacles, a glint of wire
		GardenProps.part(_head, GardenProps.cyl(0.026, 0.026, 0.006, 10), GardenProps.mat("specs", Color("c8b88a"), 0.4), Vector3(side * 0.042, 0.14, 0.106), Vector3(90, 0, 0), 0.0)


func _build_glasshouse(at: Vector3) -> void:
	var g := GardenProps.root(self, "Glasshouse", at, 0.0)
	var frame := GardenProps.mat("ghframe", Color("e2dccb"))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.86, 0.92, 0.84, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.15
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var w := 4.2
	var d := 3.0
	var h := 2.0
	for x in range(6):
		for z: float in [-d * 0.5, d * 0.5]:
			GardenProps.part(g, GardenProps.box(Vector3(0.06, h, 0.06)), frame, Vector3(-w * 0.5 + x * w / 5.0, h * 0.5, z), Vector3.ZERO, 0.0)
	for z: float in [-d * 0.5, d * 0.5]:
		GardenProps.part(g, GardenProps.box(Vector3(w, 0.06, 0.06)), frame, Vector3(0, h, z), Vector3.ZERO, 0.0)
		GardenProps.part(g, GardenProps.box(Vector3(w, h, 0.02)), glass, Vector3(0, h * 0.5, z), Vector3.ZERO, 0.0)
	for x: float in [-w * 0.5, w * 0.5]:
		GardenProps.part(g, GardenProps.box(Vector3(0.02, h, d)), glass, Vector3(x, h * 0.5, 0), Vector3.ZERO, 0.0)
	for s: float in [-1.0, 1.0]:                          # the pitched roof
		var pane := GardenProps.part(g, GardenProps.box(Vector3(w, 0.02, d * 0.58)), glass, Vector3(0, h + 0.42, s * d * 0.24), Vector3(s * 32.0, 0, 0), 0.0)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	GardenProps.part(g, GardenProps.box(Vector3(w, 0.07, 0.07)), frame, Vector3(0, h + 0.8, 0), Vector3.ZERO, 0.0)
	var leaf := GardenProps.mat("ghleaves", Color("3e5a30"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1866
	for k in range(14):                                   # staging full of plants, glowing
		var p := Vector3(rng.randf_range(-1.8, 1.8), 0.0, rng.randf_range(-1.1, 1.1))
		var s := rng.randf_range(0.18, 0.4)
		GardenProps.part(g, GardenProps.blob(Vector3(s, s * 1.1, s), {"exponent": 2.0}), leaf, p + Vector3(0, s, 0), Vector3(0, rng.randf() * 360, 0), 0.008)
	var light := OmniLight3D.new()
	light.light_color = Color("ffd49a")
	light.light_energy = 1.0
	light.omni_range = 6.0
	light.position = Vector3(0, 1.4, 0)
	g.add_child(light)


## A cabinet of little seed drawers, every one labelled the same careful way.
func _build_cabinet(at: Vector3) -> void:
	var c := GardenProps.root(self, "SeedCabinet", at, 15.0)
	GardenProps.part(c, GardenProps.box(Vector3(0.9, 1.3, 0.42)), GardenProps.mat("cabinetwood", Color("5a4430")), Vector3(0, 0.65, 0), Vector3.ZERO, 0.01)
	var label := GardenProps.mat("drawerlabel", Color("ece4d0"))
	var front := GardenProps.mat("drawerfront", Color("6e5640"))
	for row in range(5):
		for col in range(4):
			var p := Vector3(-0.32 + col * 0.213, 0.2 + row * 0.24, -0.215)
			GardenProps.part(c, GardenProps.box(Vector3(0.19, 0.2, 0.02)), front, p, Vector3.ZERO, 0.0)
			GardenProps.part(c, GardenProps.box(Vector3(0.09, 0.035, 0.01)), label, p + Vector3(0, 0.04, -0.012), Vector3.ZERO, 0.0)


func _build_hive(at: Vector3) -> void:
	var h := GardenProps.root(self, "Hive", at, 20.0)
	var white := GardenProps.mat("hivewhite", Color("e8e2d2"))
	GardenProps.part(h, GardenProps.box(Vector3(0.5, 0.12, 0.5)), GardenProps.mat("hivestand", Color("4a3a2c")), Vector3(0, 0.06, 0), Vector3.ZERO, 0.006)
	for i in range(3):
		GardenProps.part(h, GardenProps.box(Vector3(0.46, 0.22, 0.46)), white, Vector3(0, 0.24 + i * 0.23, 0), Vector3.ZERO, 0.008)
	GardenProps.part(h, GardenProps.box(Vector3(0.56, 0.06, 0.56)), GardenProps.mat("hiveroof", Color("6a6a62")), Vector3(0, 0.84, 0), Vector3.ZERO, 0.008)


## The cold frame of lettuces, and a small scarecrow in a small blue coat with brass buttons, a pair of little shoes
## hung on the cross-stick.
func _build_cold_frame(at: Vector3) -> void:
	var c := GardenProps.root(self, "ColdFrame", at, -25.0)
	var wood := GardenProps.mat("framewood", Color("6a5038"))
	GardenProps.part(c, GardenProps.box(Vector3(1.6, 0.25, 0.9)), wood, Vector3(0, 0.12, 0), Vector3.ZERO, 0.008)
	var lettuce := GardenProps.mat("lettuce", Color("8ab858"))
	for i in range(8):
		GardenProps.part(c, GardenProps.blob(Vector3(0.12, 0.08, 0.12), {"exponent": 2.0}), lettuce, Vector3(-0.6 + (i % 4) * 0.4, 0.28, -0.2 + (i / 4) * 0.4), Vector3(0, i * 37, 0), 0.006)
	var stick := GardenProps.mat("feederwood", Color("8a6a48"))
	var s := Vector3(0.95, 0, 0.0)
	GardenProps.part(c, GardenProps.cyl(0.02, 0.025, 0.9, 6), stick, s + Vector3(0, 0.45, 0), Vector3.ZERO, 0.005)
	GardenProps.part(c, GardenProps.box(Vector3(0.5, 0.03, 0.03)), stick, s + Vector3(0, 0.72, 0), Vector3.ZERO, 0.005)
	GardenProps.part(c, GardenProps.blob(Vector3(0.11, 0.13, 0.07), {"exponent": 3.0}), GardenProps.mat("littlecoat", Color("3c5c92")), s + Vector3(0, 0.64, 0), Vector3.ZERO, 0.008)
	var brass := GardenProps.mat("brassbutton", Color("d4aa4a"), 0.4)
	for k in range(3):
		GardenProps.part(c, GardenProps.blob(Vector3(0.012, 0.012, 0.008), "pebble"), brass, s + Vector3(0.0, 0.58 + k * 0.05, 0.068), Vector3.ZERO, 0.0)
	for side: float in [-1.0, 1.0]:
		GardenProps.part(c, GardenProps.blob(Vector3(0.035, 0.03, 0.06), {"exponent": 2.2}), GardenProps.mat("littleshoe", Color("3a2a20")), s + Vector3(side * 0.2, 0.66, 0.02), Vector3(0, 0, 0), 0.004)


# ------------------------------------------------------------------ her words
func _build_card(ui: CanvasLayer) -> void:
	_card = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.95, 0.91, 0.82, 0.94)
	box.set_corner_radius_all(26)
	box.content_margin_left = 44
	box.content_margin_right = 44
	box.content_margin_top = 30
	box.content_margin_bottom = 30
	_card.add_theme_stylebox_override("panel", box)
	_card.position = Vector2(70, 1300)
	_card.custom_minimum_size = Vector2(940, 0)
	_card.size = Vector2(940, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_text = Label.new()
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(852, 0)
	_card_text.add_theme_font_size_override("font_size", 38)
	_card_text.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12))
	_card.add_child(_card_text)
	_card.modulate.a = 0.0
	_card.visible = false
	ui.add_child(_card)


func say(text: String) -> void:
	_card_text.text = "“%s”" % text
	_card.visible = true
	_card.size = Vector2(940, 0)
	Motion.slide_in(_card, Vector2(70, 1300), Vector2(0, 20))
	var t := Motion.channel(_card, "hold")
	t.tween_interval(Motion._d(4.0 + text.length() * 0.05))
	t.tween_property(_card, "modulate:a", 0.0, Motion._d(Motion.SLOW))
	_speaking = 2.5 + text.length() * 0.04


func hush() -> void:
	Motion.channel(_card, "hold").kill()
	Motion.fade(_card, 0.0)
	_speaking = 0.0


## What's true right now, for the lines' conditions.
func context() -> Dictionary:
	var date := Time.get_date_dict_from_system()
	var m: int = date["month"]
	var season := "winter" if m in [12, 1, 2] else ("spring" if m in [3, 4, 5] else ("summer" if m in [6, 7, 8] else "autumn"))
	var hr: int = Time.get_time_dict_from_system()["hour"]
	var hour := "morning" if hr >= 5 and hr < 11 else ("day" if hr >= 11 and hr < 17 else ("evening" if hr >= 17 and hr < 21 else "night"))
	var grows := {}
	var flowering := {}
	var pale := false
	var short := false
	var volunteers := false
	var kept := false
	for pl in game.plants:
		grows[pl["species"]] = true
		if pl["stage"] >= 3:
			flowering[pl["species"]] = true
			pale = pale or (Heredity.pale(pl["genes"]) and Heredity.shows_colour(pl["species"]))
		if pl["stage"] >= 2:
			short = short or Heredity.short(pl["genes"])
		volunteers = volunteers or pl["origin"] == "volunteer"
		kept = kept or pl["origin"] == "nursery"
	var residents: Array = []
	var wants := {}
	var counts: Dictionary = game.garden_counts()
	for p: CharacterArtProfile in game.garden.roster:
		var st: String = game.pet_state.get(p.pet_name, "away")
		if st == "resident":
			residents.append(p.species)
		elif st in ["noticed", "visiting"]:
			var step: Dictionary = p.wants["visit" if st == "noticed" else "resident"]
			for k in step:
				if int(counts.get(k, 0)) < int(step[k]):
					wants[k] = true
	var with: Array = []
	for node: HedgePetNode in woods.followers:
		with.append(node)
	return {"visits": int(game.nursery["visits"]), "season": season, "hour": hour, "grows": grows, "flowering": flowering,
		"residents": residents, "wants": wants, "with": with, "carried": woods._carried != null, "volunteers": volunteers,
		"crossed": bool(game.nursery.get("crossed", false)), "returned": bool(game.nursery.get("returned", false)),
		"pale": pale, "short": short, "kept": kept}


## Whether a line can be said now; fills {pet}/{plant} into fill when it can.
func _fits(line: Dictionary, c: Dictionary, fill: Dictionary) -> bool:
	var when: Dictionary = line.get("when", {})
	for k in when:
		var v = when[k]
		match k:
			"visits_min":
				if c["visits"] < int(v): return false
			"visits_max":
				if c["visits"] > int(v): return false
			"season", "hour":
				if c[k] != v: return false
			"grows":
				if not c["grows"].has(v): return false
			"flowering":
				var opts: Array = c["flowering"].keys() if v == "" else ([v] if c["flowering"].has(v) else [])
				if opts.is_empty(): return false
				fill["plant"] = SpeciesBuilder.PLANT_NAMES.get(opts.pick_random(), opts[0])
			"resident":
				if not c["residents"].any(func(s) -> bool: return str(s).contains(v)): return false
			"with":
				var who: Array = c["with"].filter(func(n) -> bool: return v == "" or n.profile.species.contains(v))
				if who.is_empty(): return false
				fill["pet"] = who.pick_random().profile.pet_name
			"wants":
				if not c["wants"].has(v): return false
			"carried", "volunteers", "crossed", "returned", "pale", "short", "kept":
				if bool(c[k]) != bool(v): return false
			_:
				return false                                 # a condition we don't know: never say it
	return true


func pick(kind: String) -> String:
	var c := context()
	var said: Array = game.nursery["said"]
	var once: Array = game.nursery["once"]
	var options: Array = []
	var total := 0.0
	for line: Dictionary in _lines:
		if line.get("kind", "talk") != kind or said.has(line["id"]) or once.has(line["id"]):
			continue
		var fill := {}
		if not _fits(line, c, fill):
			continue
		var w := 1.0 + 1.5 * (line.get("when", {}) as Dictionary).size()   # the more particular, the likelier
		options.append([line, fill, w])
		total += w
	if options.is_empty():
		if said.is_empty():
			return ""
		said.clear()                                     # she's said everything lately: start over
		return pick(kind)
	var r := randf() * total
	var chosen: Array = options[options.size() - 1]
	for o: Array in options:
		r -= o[2]
		if r <= 0.0:
			chosen = o
			break
	var line: Dictionary = chosen[0]
	said.append(line["id"])
	while said.size() > RECENT:
		said.pop_front()
	if line.get("once", false):
		once.append(line["id"])
	var text: String = line["text"]
	for k in chosen[1]:
		text = text.replace("{%s}" % k, str(chosen[1][k]))
	return text


# ------------------------------------------------------------------ a visit
func arrive() -> void:
	game.nursery["visits"] = int(game.nursery["visits"]) + 1
	_usual.visible = int(game.nursery["visits"]) >= 6
	_twist.visible = not game.nursery["gave"] and int(game.nursery["visits"]) >= GIFT_VISIT
	_greeted = false
	Telemetry.event("nursery", {"visits": int(game.nursery["visits"])})
	var line := pick("greet")
	if line != "":
		say(line)


func depart() -> void:
	hush()


## A tap at the nursery: on her (or the bench), she talks. Returns whether it was hers.
func tap(screen: Vector2, cam: Camera3D) -> bool:
	var head := _head.global_position + Vector3(0, 0.1, 0)
	var body := _lady.global_position + Vector3(0, 0.9, 0)
	var near := false
	for p: Vector3 in [head, body]:
		if not cam.is_position_behind(p) and cam.unproject_position(p).distance_to(screen) < 170.0:
			near = true
	if not near:
		return false
	talk()
	return true


func talk() -> void:
	Telemetry.event("talk")
	if not game.nursery["gave"] and int(game.nursery["visits"]) >= GIFT_VISIT:
		game.nursery["gave"] = true
		for k in range(3):
			game.keep_seeds.append({"species": "lavender", "genes": "cctt"})
		Motion.vanish(_twist, false)
		say(pick("gift"))
		game.toast("🌱 Three lavender seeds in a twist of newspaper. They'll be in 🌱, under lavender.")
		return
	var basket: Dictionary = woods.basket
	if not basket.is_empty():
		var paid := 0
		var kinds: Array = []
		for k in basket:
			paid += int(PRICES.get(k, 1)) * int(basket[k])
			kinds.append(k)
		basket.clear()
		game.coins += paid
		game._refresh()
		say(_trade_line(kinds))
		game.toast("🧺 She takes the basket. 🪙 +%d" % paid)
		woods.show_basket()
		return
	var line := pick("talk")
	if line != "":
		say(line)


func _trade_line(kinds: Array) -> String:
	var lines := {
		"cone": "Pine cones. Good. I'll start the wreaths early this year.",
		"acorn": "Acorns. I'll plant a few and give the rest back to the squirrels. They'll only take them anyway.",
		"mushroom": "Mind, I don't eat these. I draw them. They sit still better than birds do.",
		"feather": "A jay's feather. They drop them like they're showing off. Which they are.",
		"apple": "From the old tree at the cellar hole? Nobody's pruned that in a hundred years. Best apples in the county.",
	}
	return lines.get(kinds.pick_random(), "I'll find a use for these. I always do.")


func _process(delta: float) -> void:
	_t += delta
	_speaking = maxf(0.0, _speaking - delta)
	var up := 1.0 if _speaking > 0.0 or fmod(_t, 11.0) > 9.6 else 0.0   # now and then she glances up anyway
	_look = Motion.approach(_look, up, 3.0, delta)
	var work := (1.0 - _look) * (0.5 + 0.5 * sin(_t * 2.2))
	_arm.rotation_degrees.x = -38.0 - 14.0 * work
	_head.rotation_degrees.x = lerpf(22.0, -6.0, _look) + sin(_t * 0.7) * 1.5
	_head.rotation_degrees.y = lerpf(0.0, -8.0, _look)
	_lady.rotation_degrees.z = sin(_t * 0.5) * 0.8
