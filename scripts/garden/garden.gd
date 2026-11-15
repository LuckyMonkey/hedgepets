extends "res://scripts/garden/garden/garden_camera.gd"

## The garden: a real back garden, not an eden - patchy lawn, a broken fence, a tipped chair, a rusty grill, a
## leaking sprinkler, sticks and branches, junk - where HedgePets live. Seen from above like a miniature on a table
## (tilt-shift). Drag to pan, wheel to zoom, tap a pet for a hop.
## Art: scripts/garden/garden_props.gd (things), the pets' own renderer (scripts/pet/hedge_pet_node.gd), the same
## foliage system for the hedge and trees (scripts/art/foliage_builder.gd).

##
## This file is the top of a layer chain; each layer adds one concern and extends the one before:
##   garden_layout -> garden_sky -> garden_plants -> garden_world -> garden_pets -> garden_camera -> garden.gd (here)
## all in scripts/garden/garden/. Here: the scene's state, the staged build (BUILD_STEPS), starting the game, _process.

var _cam_yaw := {}
var _cam_elev := {}
var _cam_pan := {}
var _cam_zoom := {}
var boot_ms := {}                                 # how long each part of building the garden took (tools/perf/boot_time.gd)


## The build, step by step. In an exported game (web, phone) it's staged: a frame between steps, so a loading card
## can say what's happening and the browser never looks frozen. The editor and the headless checks build it all at
## once (HEDGEPETS_STAGED=1 stages it there too). Weights: how long each step took here, for the bar.
const BUILD_STEPS := [
	["_build_world", "Opening the back door", 1], ["_build_ground", "Rolling out the lawn", 6],
	["_build_backdrop", "Growing the woods", 14], ["_build_props", "Bringing the garden things out", 2],
	["_build_grass", "Letting the grass grow", 6], ["_spawn_pets", "Calling the hedgepets", 1],
	["_leaf_litter", "Dropping a few leaves", 2], ["_build_ambience", "Hanging the wind chimes", 1],
	["_build_sun", "Finding the sun", 1], ["_build_sounds", "Listening for birds", 1],
	["_build_tilt_shift", "Focusing", 1], ["_start_game", "Opening your garden", 6],
]


func _ready() -> void:
	add_to_group("hedgepets_garden")
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("viewer"):
		get_tree().change_scene_to_file.call_deferred("res://main3d.tscn")   # /hedgepets/?viewer: the pet viewer
		return
	Assets.web_fonts()
	_rng.seed = 20261008
	var staged := not OS.has_feature("editor") or OS.get_environment("HEDGEPETS_STAGED") != ""
	var card: Node = null
	if staged:
		set_process(false)
		set_process_unhandled_input(false)
		card = preload("res://scripts/garden/loading_card.gd").new()
		add_child(card)
	var total := 0.0
	for st: Array in BUILD_STEPS:
		total += float(st[2])
	var done := 0.0
	var start := Time.get_ticks_msec()
	for st: Array in BUILD_STEPS:
		var t0 := Time.get_ticks_msec()
		if staged:
			card.stage(str(st[1]), done / total)
			await get_tree().process_frame               # one frame to draw the card, then the work
			await get_tree().process_frame
			boot_ms["draw before " + str(st[0])] = Time.get_ticks_msec() - t0
			t0 = Time.get_ticks_msec()
		call(str(st[0]))
		boot_ms[st[0]] = Time.get_ticks_msec() - t0
		done += float(st[2])
	_place_camera()
	neighborhood.follow(camera, camera.position, 0.0)
	if staged:
		card.stage("Almost there", 1.0)
		var t1 := Time.get_ticks_msec()
		await _warm_first_draw()                         # compile reachable views and upload every leaf sheet behind the card
		boot_ms["first frames"] = Time.get_ticks_msec() - t1
		set_process(true)
		set_process_unhandled_input(true)
		card.finish()
	print("HedgePets: garden ready in %d ms at %s %s (cache %d hits, %d misses)" % [Time.get_ticks_msec() - start, DisplayServer.window_get_size(), boot_ms, BakeCache.hits, BakeCache.misses])
	is_built = true
	built.emit()
	var begin := start_place()
	if begin.begins_with("woods"):
		_start_in_woods.call_deferred(begin.get_slice(":", 1))
	elif OS.get_environment("HEDGEPETS_FRESH") == "" and OS.get_environment("HEDGEPETS_NO_PREBUILD") == "":
		get_tree().create_timer(1.5).timeout.connect(woods.prebuild)   # the garden's up: now the woods, quietly


## Safari's first draw of a shader/material can take hundreds of milliseconds. The loading card is opaque, so turn
## through the garden's reachable views and draw one leaf from every plant there; the first player pan then reuses
## those pipelines and uploaded sheets. Temporary warmers never enter game state or the pet renderer.
func _warm_first_draw() -> void:
	var warmers: Array[MeshInstance3D] = []
	var starter: HedgePetNode = _nodes.get("Gerald")
	if starter != null and starter.leaves_mat != null and game != null:
		var k := 0
		for sp: String in game.SEEDS:
			var item: Dictionary = game.SEEDS[sp]
			var m := starter.leaves_mat.duplicate() as ShaderMaterial
			m.set_shader_parameter("leaf_sheet", Assets.mipmapped("res://assets/sprites/%s.png" % item["sheet"]))
			m.set_shader_parameter("leaf_normals", Assets.mipmapped("res://assets/sprites/%s_n.png" % item["sheet"]))
			var quad := QuadMesh.new()
			quad.size = Vector2(0.18, 0.18)
			var n := MeshInstance3D.new()
			n.mesh = quad
			n.material_override = m
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.position = _target + Vector3((k % 6 - 3) * 0.22, 1.0 + (k / 6) * 0.22, 0.0)
			add_child(n)
			warmers.append(n)
			k += 1
	var rest_yaw := _yaw
	for quarter in range(4):
		_yaw = rest_yaw + quarter * PI * 0.5
		_place_camera()
		neighborhood.follow(camera, camera.position, 0.0)
		HitchLog.tag("first_draw:warmup")
		await get_tree().process_frame
	_yaw = rest_yaw
	_place_camera()
	neighborhood.follow(camera, camera.position, 0.0)
	HitchLog.tag("first_draw:warmup")
	await get_tree().process_frame
	for n: MeshInstance3D in warmers:
		n.visible = false
		n.queue_free()


## Where to start (development): `-- --start=woods:ridge` on the command line (the HedgePets editor dock uses it), or
## HEDGEPETS_START=woods:ridge. Empty: the garden, as always.
static func start_place() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--start="):
			return a.trim_prefix("--start=")
	return OS.get_environment("HEDGEPETS_START")


func _start_in_woods(place: String) -> void:
	await woods.enter()
	if woods.NODES.has(place):
		woods._at = place
		woods._settle(Vector3.INF)


var den: Node                                     # scripts/garden/den.gd: the room under the burrow (built on first visit)
func _start_game() -> void:
	hideouts = preload("res://scripts/garden/hideouts.gd").new()
	hideouts.name = "Hideouts"
	add_child(hideouts)
	hideouts.setup(self)
	perches = preload("res://scripts/garden/perches.gd").new()
	perches.name = "Perches"
	add_child(perches)
	perches.setup(self)
	den = preload("res://scripts/garden/den.gd").new()
	add_child(den)
	den.setup(self)
	woods = preload("res://scripts/garden/woods.gd").new()
	add_child(woods)
	woods.setup(self)
	game = preload("res://scripts/garden/garden_game.gd").new()
	game.name = "Game"
	add_child(game)
	game.setup(self)


var _next_bloom := 90.0


func _process(delta: float) -> void:
	for node in pets:
		_walk(node, delta)
		if node.visible and not perches.up_there(_wander[node]):
			_separate(node, delta)
	_notice_pointer()
	if not _shafts.is_empty():
		_tend_sun(delta)
	_next_bloom -= delta
	if _next_bloom <= 0.0:
		_next_bloom = _rng.randf_range(120.0, 300.0)
		if game != null:
			game.surprise_flower()
	if is_processing_unhandled_input():
		_keys(delta)
	_target = Motion.spring(_target, _goal_target, _cam_pan, 0.12, delta)
	_yaw = Motion.spring(_yaw, _goal_yaw, _cam_yaw, 0.1 if _dragged else 0.45, delta)
	_elev = Motion.spring(_elev, _goal_elev, _cam_elev, 0.1 if _dragged else 0.25, delta)
	_distance = Motion.spring(_distance, _goal_distance, _cam_zoom, 0.16, delta)
	HitchLog.camera_moving(_target.distance_squared_to(_goal_target) > 0.0001 or absf(_yaw - _goal_yaw) > 0.0001 \
		or absf(_elev - _goal_elev) > 0.0001 or absf(_distance - _goal_distance) > 0.0001)
	_place_camera()
	neighborhood.follow(camera, camera.position, delta)
