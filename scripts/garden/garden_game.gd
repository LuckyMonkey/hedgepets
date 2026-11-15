extends "res://scripts/garden/game/game_tools.gd"

##
## This file is the top of a layer chain; each layer adds one concern and extends the one before:
##   game_state -> game_plants -> game_visitors -> game_friends -> game_save -> game_ui -> game_tools -> garden_game.gd
## all in scripts/garden/game/. Here: setup and the per-frame loop (_process).

const INCOME_SECONDS := 30.0
var _income_ticks := 0

const SOW_SECONDS := 45.0           # how often an empty bed may get a self-sown seedling
var _sow := SOW_SECONDS
var _contra_check := 60.0
var _contra_told := false
var _beat := 20.0
var _beats := 0
var _lead := 0.0
var _income := INCOME_SECONDS
var _check := 0.0
var _save := 5.0
func setup(g: Node3D) -> void:
	story = GardenStory.new(self)
	garden = g
	if OS.get_environment("HEDGEPETS_SAVE") != "":
		save_path = OS.get_environment("HEDGEPETS_SAVE")      # checks use their own save file
	_build_ui()
	grab = preload("res://scripts/garden/garden_grab.gd").new()
	grab.name = "Grab"
	add_child(grab)
	grab.setup(garden, self, _ui)
	var wb := GardenProps.wheelbarrow(garden, Vector3(3.2, 0, 7.4), -30.0)   # added last: earlier things keep their ids
	garden._thing("wheelbarrow", wb, Vector2(3.2, 7.4), 0.6, 0, false)
	barrow = garden.things[-1]
	barrow["load"] = 0
	grab.grabbable(barrow)                                # its weight and grip, ready to haul
	for p: CharacterArtProfile in garden.roster:
		pet_state[p.pet_name] = "resident" if p.starts_resident else "away"
	WorldOverrides.current().apply(garden)                # the world editor's authored changes, before the player's save
	_load()
	for p: CharacterArtProfile in garden.roster:
		if pet_state[p.pet_name] != "away":
			_apply_mode(_node(p), true)
	_restore_friends()
	_refresh()
	_refresh.call_deferred()
	Telemetry.start()
	var here := pet_state.values().filter(func(s) -> bool: return s != "away").size()
	Telemetry.event("session", {"touch": DisplayServer.is_touchscreen_available(), "w": garden.get_viewport().get_visible_rect().size.x,
		"back_after_h": snappedf(_away_for / 3600.0, 0.1), "coins": coins, "here": here, "plants": plants.size(),
		"detail": Quality.tier_name(), "detail_bench_ms": snappedf(Quality.benchmark_value(), 0.1)})                 # again once the toolbar is laid out (the chip finds its tool)
	if _away_for > 6.0 * 3600.0:
		_welcome_back()
	else:
		toast("Tidy the garden, plant things, and see who comes by.")


# ------------------------------------------------------------------ the loop
func _process(delta: float) -> void:
	_grow(delta)
	_pouring(delta)
	_tend_gifts(delta)
	_sow -= delta
	if _sow <= 0.0:
		_sow = SOW_SECONDS
		_self_sow()
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_visitors()
	_lead -= delta
	if _lead <= 0.0:
		_lead = 0.7
		_lead_followers()
	_income -= delta
	if _income <= 0.0:
		_income = INCOME_SECONDS
		var counts := garden_counts()
		_income_ticks += 1
		for p: CharacterArtProfile in garden.roster:
			# a happy resident leaves something every half minute; every resident, now and then (never a dry spell:
			# coins always come in, whatever you've cleared or not grown yet)
			var happy := _met(p.wants["resident"], counts)
			if pet_state[p.pet_name] == "resident" and (happy or _income_ticks % 3 == 0) and gifts.size() < 12:
				var node: HedgePetNode = _node(p)
				if node.visible:
					_drop_gift(node)
	_contra_check -= delta
	if _contra_check <= 0.0:
		_contra_check = 60.0
		_tend_contraband()
	_beat -= delta
	if _beat <= 0.0:                                     # what the garden's like, now and then; and send what's queued
		_beat = 20.0
		_beats += 1
		if _beats % 3 == 0:
			Telemetry.event("beat", {"coins": coins, "tool": tool, "plants": plants.size(), "room": capacity(),
				"here": pet_state.values().filter(func(s) -> bool: return s != "away").size()})
		Telemetry.flush()
	_save -= delta
	if _save <= 0.0:
		_save = 8.0
		save()
