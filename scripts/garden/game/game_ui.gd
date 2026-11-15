extends "res://scripts/garden/game/game_save.gd"

## Game 6/7 - the HUD: coins, tools, seed and build rows, the journal, the sound menu.
##
## Built in code (_build_ui), not a .tscn, so it scales with the portrait layout. _refresh() redraws coins, tool
## buttons and rows from the state.
##
## Part of the garden game layer chain (the full order is at the top of scripts/garden/garden_game.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var tool := "hand"
var seed_choice := "ivy"
var build_choice := "feeder"
var _bucket_badge: Label
var _ui: CanvasLayer
var _coin_label: Label
var _tool_buttons := {}
var _seed_row: GridContainer
var _build_row: GridContainer
const BUILD_AT := Vector2(36, 1560)
var _builds_shown := false
var _journal: PanelContainer
var _journal_text: RichTextLabel


# ------------------------------------------------------------------ tools
## Is there a visible, clickable piece of the HUD at this screen point? (touch input: see garden._unhandled_input)
func ui_blocks(at: Vector2) -> bool:
	var stack: Array = _ui.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			var c := n as Control
			if not c.is_visible_in_tree() or c.modulate.a < 0.05:
				continue
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(at):
				return true
		stack.append_array(n.get_children())
	return false


var _told_arrange := false


const SEEDS_AT := Vector2(44, 1460)
const JOURNAL_AT := Vector2(90, 260)
var _shown_coins := -1
var _seeds_shown := false
var _journal_open := false


## Bring the HUD to the current state, every change eased (scripts/anim/motion.gd).
func _refresh() -> void:
	if _shown_coins < 0:
		_shown_coins = coins
		_coin_label.text = "🪙 %d" % coins
	elif coins != _shown_coins:
		Motion.count(_coin_label, _shown_coins, coins, func(v: int) -> void:
			_shown_coins = v
			_coin_label.text = "🪙 %d" % v)
		Motion.pulse(_coin_label, 1.25 if coins > _shown_coins else 0.9)
	for t in _tool_buttons:
		var b: Button = _tool_buttons[t]
		Motion.channel(b, "fade").tween_property(b, "modulate:a", 1.0 if t == tool else 0.5, Motion._d(Motion.FAST))
		Motion.scale_to(b, 1.15 if t == tool else 0.92)
	_show_tool()
	var want_seeds := tool == "seeds" or tool == "shears"
	if want_seeds != _seeds_shown:
		_seeds_shown = want_seeds
		if want_seeds:
			Motion.slide_in(_seed_row, SEEDS_AT, Vector2(0, 26))
		else:
			Motion.fade(_seed_row, 0.0, Motion.FAST)
	var want_builds := tool == "build"
	if want_builds != _builds_shown:
		_builds_shown = want_builds
		if want_builds:
			Motion.slide_in(_build_row, BUILD_AT, Vector2(0, 26))
		else:
			Motion.fade(_build_row, 0.0, Motion.FAST)
	_bucket_badge.visible = carried != ""
	_bucket_badge.text = "🪣 You're carrying %s in the bucket. ✋ tap the lawn to set it down." % carried
	for b in _build_row.get_children():
		Motion.channel(b, "fade").tween_property(b, "modulate:a", 1.0 if b.name == build_choice else 0.55, Motion._d(Motion.FAST))
		Motion.scale_to(b, 1.08 if b.name == build_choice else 1.0)
	for b in _seed_row.get_children():
		Motion.channel(b, "fade").tween_property(b, "modulate:a", 1.0 if b.name == seed_choice else 0.55, Motion._d(Motion.FAST))
		Motion.scale_to(b, 1.08 if b.name == seed_choice else 1.0)
	if _journal_open:
		_fill_journal()


const TOOL_WORDS := {
	"hand": "✋ Hand - tap to look and pet · hold on junk to yank and haul it · hold on broken things to mend them",
	"shovel": "🪏 Shovel - dig (beside a hole: a row) · scoop dirt · fill a hole · dig up what you sowed",
	"seeds": "🌱 Seeds - pick a plant, then tap a hole to sow it",
	"shears": "✂️ Shears - pick a plant, then tap a pet to regraft it",
	"build": "🧺 Build - pick a thing, tap the lawn · drag one to move it · tap it to turn it",
	"water": "💧 Watering can - hold and drag to pour · hedgepets love water and follow it",
}
var _puck: Panel
var _caption: Label
var _shown_tool := ""


## The chip glides behind the tool in your hand; the caption says what it does.
func _show_tool() -> void:
	var b: Button = _tool_buttons.get(tool)
	if b == null or _puck == null:
		return
	var goal := b.global_position + b.size * 0.5 - _puck.size * 0.5
	if _shown_tool == "":
		_puck.position = goal
	else:
		Motion.channel(_puck, "move").tween_property(_puck, "position", goal, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _shown_tool != tool:
		_shown_tool = tool
		_caption.text = TOOL_WORDS.get(tool, "")
		Motion.slide_in(_caption, Vector2(40, 1672), Vector2(0, 14))


func _fill_journal() -> void:
	var lines := "[b]Journal[/b]\n\n" + story.page()
	var binoculars: Dictionary = woods_finds.get("binoculars", {})
	if binoculars.size() > 0:
		lines += "\n[b]Seen through the binoculars[/b]\n"
		for id: String in ["heron", "hawk", "fox", "deer", "church", "garden"]:
			if binoculars.has(id):
				lines += "   %s\n" % {"heron": "A heron in the creek", "hawk": "A hawk circling above the ridge", "fox": "A fox at the den", "deer": "A deer at the treeline", "church": "The church weathervane", "garden": "Home, the garden by the white house"}[id]
	lines += "[b]Found things[/b]\n"
	for kind: String in ["cone", "acorn", "feather", "apple", "mushroom", "shell", "stone", "flower", "berry"]:
		var n := int(collection.get(kind, 0))
		lines += "   %s: %s\n" % [(GardenStory.words(kind, n) if n > 0 else "?"), ("found %d" % n if n > 0 else "not found yet")]
	lines += "\n"
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
		var seen: Array = discovered.get(p.pet_name, [])
		var vs: Array = seen.map(func(v) -> String: return SpeciesBuilder.variant_name(p, v))
		var seen_as := ("\n[color=#7a6a50]seen as %s[/color]" % ", ".join(vs)) if vs.size() > 1 else ""
		var favourite: String = favourite_collectable(p)
		var favourite_line := "\n[color=#7a6a50]Favourite: %s%s[/color]" % [GardenStory.words(favourite) if favourite != "" else "nothing collected yet", " (set one out to draw it closer)" if favourite != "" else ""]
		if is_contraband(p.pet_name):
			hint = "It wants sun. Lots of sun. Preferably where nobody can see it."
		if story.introduced.has(p.pet_name):
			label += ", met in your garden"
		lines += "[b]%s[/b] the %s - %s\n%s%s%s\n\n" % [p.pet_name, SpeciesBuilder.variant_name(p, pet_plant.get(p.pet_name, "")), label, hint, seen_as, favourite_line]
	# rumours: a few of the ones you haven't met, the nearest to noticing first
	lines += "[b]Around the neighbourhood[/b]\n\n"
	unseen.sort_custom(func(a, b) -> bool: return _missing(a.wants["notice"], counts) < _missing(b.wants["notice"], counts))
	for p: CharacterArtProfile in unseen.slice(0, 4):
		var vs: Array = SpeciesBuilder.variants_of(p).map(func(v) -> String: return SpeciesBuilder.PLANT_NAMES.get(v, v))
		lines += "🐾 %s [color=#7a6a50]Seen near gardens growing %s.[/color]\n\n" % [p.hints["notice"], " or ".join(vs.slice(0, 2)) if vs.size() <= 2 else ", ".join(vs.slice(0, vs.size() - 1)) + " or " + vs[vs.size() - 1]]
	lines += "\n[url=howto]❓ How to play[/url]     [url=feedback]💬 Tell us what you think[/url]\n"
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


## Debug tools (coins on demand): in the editor, with HEDGEPETS_DEBUG=1, or on the web with ?debug in the address.
func debug_enabled() -> bool:
	if OS.has_feature("editor") or OS.get_environment("HEDGEPETS_DEBUG") != "" or "--debug" in OS.get_cmdline_user_args():
		return true
	return OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("debug")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and debug_enabled():
		debug_coins()


var _sound_menu: PanelContainer


## The sound menu: all sound, the wind in the leaves, the birds and neighbours. Remembered (user://settings.cfg).
func _toggle_sound_menu() -> void:
	var sounds: Node = garden.get_node("Soundscape")
	if _sound_menu == null:
		_sound_menu = PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.98, 0.96, 0.9, 0.95)
		style.set_corner_radius_all(28)
		style.set_content_margin_all(24)
		_sound_menu.add_theme_stylebox_override("panel", style)
		_sound_menu.position = Vector2(440, 130)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		_sound_menu.add_child(box)
		for row: Array in [["🔊  Sound", not AudioServer.is_bus_mute(0), func(on: bool) -> void: sounds.set_all(on)],
				["🍃  Wind in the leaves", sounds.wind_on, func(on: bool) -> void: sounds.set_wind(on)],
				["🐦  Birds and neighbours", sounds.events_on, func(on: bool) -> void: sounds.set_events(on)]]:
			var c := CheckButton.new()
			c.text = row[0]
			c.button_pressed = row[1]
			c.add_theme_font_size_override("font_size", 38)
			c.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
			c.add_theme_color_override("font_pressed_color", Color(0.3, 0.24, 0.16))
			c.add_theme_color_override("font_hover_color", Color(0.3, 0.24, 0.16))
			c.toggled.connect(row[2])
			box.add_child(c)
		var done := _button("✓", "Close", 44)
		done.pressed.connect(_toggle_sound_menu)
		box.add_child(done)
		_ui.add_child(_sound_menu)
		Motion.slide_in(_sound_menu, _sound_menu.position, Vector2(0, -30))
		return
	Motion.fade(_sound_menu, 0.0, Motion.FAST)
	var m := _sound_menu
	_sound_menu = null
	get_tree().create_timer(0.4).timeout.connect(m.queue_free)


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
		_journal_open = not _journal_open
		if _journal_open:
			Telemetry.event("journal")
			_fill_journal()
			Motion.slide_in(_journal, JOURNAL_AT, Vector2(0, 40))
		else:
			Motion.fade(_journal, 0.0, Motion.FAST)
		_refresh())
	_ui.add_child(jb)
	var db := _button("🕳️", "The burrow: where the pets who live here nap", 52)
	db.position = Vector2(800, 10)
	db.pressed.connect(func() -> void: garden.den.enter())
	_ui.add_child(db)
	var sb := _button("🔊", "Sound: all sound, the wind, the birds and neighbours", 52)
	sb.position = Vector2(670, 10)
	sb.pressed.connect(_toggle_sound_menu)
	_ui.add_child(sb)
	if debug_enabled():                                  # testing: coins on demand (desktop F9 too)
		var cb := _button("🪙+", "Debug: 100 coins", 40)
		cb.position = Vector2(540, 10)
		cb.pressed.connect(debug_coins)
		_ui.add_child(cb)
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
	panel.position = Vector2(50, 1760)
	panel.size = Vector2(980, 130)
	_ui.add_child(panel)
	panel.add_child(bar)
	for t: Array in [["hand", "✋", "Hand: tap to pet and look; press and drag junk to yank it loose and haul it"], ["shovel", "🪏", "Shovel: dig a seedbed, scoop up a leaf pile or something you built"],
			["seeds", "🌱", "Seeds: plant in a seedbed"], ["shears", "✂️", "Shears: regraft a pet in the chosen plant"], ["build", "🧺", "Build: put a feeder, bath, scarecrow... in the garden; drag one you built to move it, tap it to turn it"], ["water", "💧", "Watering can: hold and drag to pour"]]:
		var b := _button(t[1], t[2])
		var key: String = t[0]
		b.pressed.connect(func() -> void:
			tool = key
			Telemetry.event("tool", {"tool": key})
			if key == "build" and not _told_arrange:
				_told_arrange = true
				toast("Tap the lawn to put one down. Drag one you built to move it; tap it to turn it.")
			_refresh())
		bar.add_child(b)
		_tool_buttons[key] = b
	# which tool is in your hand: a bright rounded chip behind it that glides to the chosen one, and its name and
	# what it does just above the bar
	_puck = Panel.new()
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.36, 0.52, 0.3, 0.95)
	chip.set_corner_radius_all(30)
	chip.border_color = Color(0.98, 0.94, 0.8)
	chip.set_border_width_all(4)
	_puck.add_theme_stylebox_override("panel", chip)
	_puck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_puck.size = Vector2(128, 118)
	_ui.add_child(_puck)
	_ui.move_child(_puck, panel.get_index() + 1)
	_ui.move_child(panel, _puck.get_index())
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	_caption.add_theme_color_override("font_outline_color", Color(0.12, 0.1, 0.07, 0.75))
	_caption.add_theme_constant_override("outline_size", 9)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.position = Vector2(40, 1672)
	_caption.size = Vector2(1000, 80)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_caption)
	_seed_row = GridContainer.new()
	_seed_row.columns = 8
	_seed_row.position = SEEDS_AT
	_seed_row.add_theme_constant_override("h_separation", 8)
	_seed_row.add_theme_constant_override("v_separation", 6)
	for sp in SEEDS:
		var b := _button("%s%d" % [SEEDS[sp]["icon"], SEEDS[sp]["price"]], "%s seeds" % sp, 32)
		b.name = sp
		b.custom_minimum_size = Vector2(116, 90)
		b.pressed.connect(func() -> void:
			seed_choice = sp
			var kept := keep_seeds.filter(func(k) -> bool: return k["species"] == sp).size()
			toast("%s %s seeds (🪙 %d)%s. Tap a hole to sow." % [SEEDS[sp]["icon"], SpeciesBuilder.PLANT_NAMES.get(sp, sp), SEEDS[sp]["price"], (" - you have %d of your own, free" % kept) if kept > 0 else ""])
			_refresh())
		_seed_row.add_child(b)
	_seed_row.visible = false
	_ui.add_child(_seed_row)
	_build_row = GridContainer.new()
	_build_row.columns = 7
	_build_row.position = BUILD_AT
	_build_row.add_theme_constant_override("h_separation", 8)
	_build_row.add_theme_constant_override("v_separation", 6)
	for kind in BUILDS.keys() + OFFERINGS.keys():
		var item: Dictionary = OFFERINGS[kind] if OFFERINGS.has(kind) else BUILDS[kind]
		var cost_text := "find one" if OFFERINGS.has(kind) else "🪙 %d" % item["price"]
		var b := _button("%s%s" % [item["icon"], ("" if OFFERINGS.has(kind) else str(item["price"]))], "%s (%s)" % [item["name"], cost_text], 34)
		b.name = kind
		b.custom_minimum_size = Vector2(136, 90)
		b.pressed.connect(func() -> void:
			build_choice = kind
			toast("%s A %s (🪙 %d). Tap the lawn to put it down." % [item["icon"], item["name"], item["price"]])
			_refresh())
		_build_row.add_child(b)
	_build_row.visible = false
	_ui.add_child(_build_row)
	_bucket_badge = Label.new()
	_bucket_badge.add_theme_font_size_override("font_size", 32)
	_bucket_badge.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
	_bucket_badge.position = Vector2(40, 90)
	_bucket_badge.visible = false
	_ui.add_child(_bucket_badge)
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
	_journal_text.meta_clicked.connect(func(meta) -> void:
		if str(meta) in ["feedback", "howto"]:          # the survey / the guide, on their own pages (a new tab on the web)
			Telemetry.event("open_" + str(meta))
			OS.shell_open("https://go.fridge.run/hedgepets/" + str(meta)))
	_journal.add_child(_journal_text)
	_ui.add_child(_journal)


func set_ui_visible(on: bool) -> void:
	_ui.visible = on
