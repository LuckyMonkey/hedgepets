extends Node3D

## The garden: a real back garden, not an eden - patchy lawn, a broken fence, a tipped chair, a rusty grill, a
## leaking sprinkler, sticks and branches, junk - where HedgePets live. Seen from above like a miniature on a table
## (tilt-shift). Drag to pan, wheel to zoom, tap a pet for a hop.
## Art: scripts/garden/garden_props.gd (things), the pets' own renderer (scripts/pet/hedge_pet_node.gd), the same
## foliage system for the hedge and trees (scripts/art/foliage_builder.gd).

const BOUNDS := Rect2(-12.0, -8.5, 24.0, 17.0)    # x, z where pets may walk
const PET_SCALE := 0.62
const PAPER := Color(0.968627, 0.945098, 0.890196)

var camera: Camera3D
var sun: DirectionalLight3D
var pets: Array[HedgePetNode] = []
var obstacles: Array = []                         # fixed: [Vector2 centre (x, z), radius] (trees)
var things: Array = []                            # the garden's props: {id, kind, node, at (Vector2), radius, junk, value}
var _target := Vector3(0.0, 0.0, -0.8)
var _distance := 12.5
## The camera eases toward these (Motion.approach): input moves the goal, never the camera itself; a drag that ends
## moving keeps gliding a little.
var _goal_target := Vector3(0.0, 0.0, -0.8)
## Orbit: the camera circles the middle of the garden. Drag sideways to spin (with a glide after a fling), drag up and
## down to tilt a little, wheel / pinch to zoom. Springs on all three (Motion.spring).
const CENTER := Vector3(0.0, 0.0, -0.8)
var _yaw := 0.0
var _goal_yaw := 0.0
var _elev := deg_to_rad(49.5)
var _goal_elev := deg_to_rad(49.5)
var _cam_yaw := {}
var _cam_elev := {}
var _goal_distance := 12.5
var _cam_pan := {}
var _cam_zoom := {}
var _press_at := Vector2.INF
var _dragged := false
var _rng := RandomNumberGenerator.new()
var roster: Array = []                            # every CharacterArtProfile; pets holds the ones built so far
var _nodes := {}                                  # pet name -> HedgePetNode
var _wander := {}                                 # pet -> {target, wait, mode}
var game: Node                                    # scripts/garden/garden_game.gd
const GAP := Vector3(2.5, 0.0, -11.0)             # the collapsed bit of fence (the burying-ground side)
## Ways in. Each pet comes by the one that fits it (gate_for): the creek's footbridge, the gap in the woods wall, the
## garden gate from the houses, or the broken fence by the burying ground. out = where it waits unseen, peek = where
## it stands looking in, inside = its first steps in the garden.
const GATES := {
	"fence": {"out": Vector3(2.5, 0, -17.0), "peek": Vector3(2.5, 0, -11.7), "inside": Vector3(2.5, 0, -8.5)},
	"woods": {"out": Vector3(17.0, 0, -2.0), "peek": Vector3(10.2, 0, -2.0), "inside": Vector3(6.5, 0, -2.0)},
	"creek": {"out": Vector3(-23.0, 0, 1.5), "peek": Vector3(-14.2, 0, 1.5), "inside": Vector3(-10.0, 0, 1.5)},
	"houses": {"out": Vector3(-1.0, 0, 17.0), "peek": Vector3(-1.0, 0, 10.6), "inside": Vector3(-1.0, 0, 7.0)},
	# the burrow behind the bottom-corner tree: burrowing pets peek out of it and climb out (hideouts.gd)
	"burrow": {"out": Vector3(-12.3, -1.0, 4.9), "peek": Vector3(-11.6, 0, 4.9), "inside": Vector3(-9.0, 0, 3.8)},
}
const BURROW_AT := Vector3(-12.3, 0, 4.9)
## The back fence, in runs you can mend one at a time; the collapsed bit (FENCE_GAP) becomes a gate when mended.
const FENCE_SECTIONS := [Vector2(-16.0, -7.2), Vector2(-7.2, 1.6), Vector2(1.6, 6.0), Vector2(6.0, 10.4), Vector2(10.4, 16.0)]   # on the 2.2 m post grid
const FENCE_GAP := Vector2(0.5, 4.5)
var fence_sections: Array = []


## Rebuild one section of the back fence, mended (animated unless at_once: loading a save).
func mend_fence(i: int, at_once := false) -> void:
	var sec: Dictionary = fence_sections[i]
	if sec["mended"]:
		return
	sec["mended"] = true
	var old: Node3D = sec["node"]
	var r := RandomNumberGenerator.new()
	var fresh := GardenProps.bake_static(GardenProps.broken_fence(self, sec["from"], sec["to"], -11.0, r, FENCE_GAP, true))
	sec["node"] = fresh
	if at_once:
		old.queue_free()
		return
	fresh.scale = Vector3(1, 0.02, 1)
	var t := Motion.channel(old, "mend")
	t.tween_property(old, "scale", Vector3(1, 0.02, 1), Motion._d(Motion.BASE)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(old.queue_free)
	var t2 := Motion.channel(fresh, "mend")
	t2.tween_interval(Motion._d(Motion.BASE * 0.6))
	t2.tween_property(fresh, "scale", Vector3.ONE, Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
const GATE_WORDS := {
	"burrow": ["mole", "chipmunk", "woodchuck", "mouse"],
	"creek": ["otter", "mink", "peeper", "bullfrog", "turtle", "mallard", "duck", "loon", "seal", "puffin", "eft", "beaver", "mole"],
	"woods": ["fox", "coyote", "fisher", "bobcat", "fawn", "moose", "bear", "porcupine", "turkey", "owl", "woodpecker", "chipmunk", "hedgehog"],
	"houses": ["raccoon", "opossum", "skunk", "mouse", "bunny", "robin", "cardinal", "jay", "chickadee", "dove", "bluebird", "squirrel"],
}


func gate_for(p: CharacterArtProfile) -> String:
	for gate in GATE_WORDS:
		for word: String in GATE_WORDS[gate]:
			if p.species.contains(word):
				return gate
	return "fence"
var _leaf_mats := {}
var _bald_noise: FastNoiseLite


var walk_stats := {"arrived": 0, "close_enough": 0, "gave_up": 0, "most_in_a_row": 0}   # tools/stuck_check.gd
var boot_ms := {}                                 # how long each part of building the garden took (tools/boot_time.gd)


signal built                                      # the garden is up and playable (after a staged build)
var is_built := false

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
	if staged:
		card.stage("Almost there", 1.0)
		var t1 := Time.get_ticks_msec()
		for k in range(3):                               # the first frames draw everything once (shaders warm up) behind the card
			await get_tree().process_frame
		boot_ms["first frames"] = Time.get_ticks_msec() - t1
		set_process(true)
		set_process_unhandled_input(true)
		card.finish()
	print("HedgePets: garden ready in %d ms %s (cache %d hits, %d misses)" % [Time.get_ticks_msec() - start, boot_ms, BakeCache.hits, BakeCache.misses])
	is_built = true
	built.emit()


# ------------------------------------------------------------------ the sun
## The sun follows the real time of day: up in the east over the woods in the morning, round the south over the
## houses at midday, down in the west past the creek in the evening, golden when it's low. At night it holds a soft
## dusk (nothing goes dark: no punishing a late visit). Shafts of light slant down through the trees along it,
## strongest when the sun is low. HEDGEPETS_HOUR=16.5 pins the hour (captures, checks).
var _shafts: Array = []
var _sun_goal := Basis.IDENTITY
var _sun_check := 0.0


func _hour() -> float:
	if OS.get_environment("HEDGEPETS_HOUR") != "":
		return float(OS.get_environment("HEDGEPETS_HOUR"))
	var t := Time.get_datetime_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0


## Where the sun is (a unit vector toward it), how low it is (0 = horizon .. 1 = noon), for an hour of the day.
func sun_at(hour: float) -> Array:
	var day := clampf((hour - 6.0) / 14.0, 0.04, 0.96)         # 06:00 .. 20:00; outside that, a held dusk / dawn
	var theta := day * PI                                       # east (+x) .. south (+z) .. west (-x)
	var el := deg_to_rad(lerpf(9.0, 58.0, sin(day * PI)))
	var to_sun := Vector3(cos(theta) * cos(el), sin(el), sin(theta) * cos(el)).normalized()
	return [to_sun, sin(day * PI)]


func _build_sun() -> void:
	var s: Array = sun_at(_hour())
	_aim_sun(s, true)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/light_shaft.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2210
	for i in range(5):
		# where light gets through the canopy: near the edges of the yard, under the trees
		var a := rng.randf() * TAU
		var hit := Vector3(cos(a) * rng.randf_range(7.0, 11.0), 0, sin(a) * rng.randf_range(5.5, 8.5) - 1.0)
		var shaft := Node3D.new()
		shaft.name = "LightShaft"
		add_child(shaft)
		var mat_i := m.duplicate() as ShaderMaterial
		mat_i.set_shader_parameter("seed", rng.randf())
		for k in range(2):                                      # two crossed cards: a shaft from any side
			var card := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(rng.randf_range(0.6, 1.3), 18.0)
			card.mesh = q
			card.material_override = mat_i
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			card.rotation.y = k * PI * 0.5
			card.position = Vector3(0, 9.0, 0)
			shaft.add_child(card)
		_shafts.append({"node": shaft, "hit": hit, "mat": mat_i})
	_place_shafts(s)


func _aim_sun(s: Array, at_once: bool) -> void:
	var to_sun: Vector3 = s[0]
	var low: float = 1.0 - float(s[1])
	_sun_goal = Basis.looking_at(-to_sun, Vector3.UP)
	if at_once:
		sun.basis = _sun_goal
	sun.light_color = Color(1.0, 0.93, 0.82).lerp(Color(1.0, 0.72, 0.45), low * low)
	sun.light_energy = lerpf(0.55, 0.78, float(s[1]))


func _place_shafts(s: Array) -> void:
	var to_sun: Vector3 = s[0]
	var low: float = 1.0 - float(s[1])
	for sh in _shafts:
		var node: Node3D = sh["node"]
		node.position = sh["hit"]
		# the shaft's long axis points back up toward the sun
		var up := to_sun
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		node.basis = Basis(side, up, side.cross(up).normalized())
		(sh["mat"] as ShaderMaterial).set_shader_parameter("strength", lerpf(0.008, 0.028, low))   # a hint, not a searchlight
		(sh["mat"] as ShaderMaterial).set_shader_parameter("colour", sun.light_color)


func _tend_sun(delta: float) -> void:
	_sun_check -= delta
	if _sun_check <= 0.0:
		_sun_check = 30.0
		var s: Array = sun_at(_hour())
		_aim_sun(s, false)
		_place_shafts(s)
	sun.basis = sun.basis.orthonormalized().slerp(_sun_goal.orthonormalized(), clampf(delta * 0.05, 0.0, 1.0))   # glides, never jumps (re-squared: slerping drifts)


## The backyard, heard (scripts/garden/soundscape.gd).
func _build_sounds() -> void:
	var sounds := preload("res://scripts/garden/soundscape.gd").new()
	sounds.name = "Soundscape"
	add_child(sounds)
	sounds.setup(self)


var hideouts: Node
var den: Node                                     # scripts/garden/den.gd: the room under the burrow (built on first visit)
var woods: Node                                   # scripts/garden/woods.gd: the trails over the footbridge


func _start_game() -> void:
	hideouts = preload("res://scripts/garden/hideouts.gd").new()
	hideouts.name = "Hideouts"
	add_child(hideouts)
	hideouts.setup(self)
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


# ------------------------------------------------------------------ world
func _build_world() -> void:
	var p := CharacterArtProfile.gerald()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7b37a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = 0.32
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true                               # a little air between the near and far garden
	env.fog_light_color = Color("a7b37a")
	env.fog_density = 0.01
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.87, 0.68)                 # afternoon: low, warm, long shadows
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.shadow_opacity = 0.72                          # tree shade, not a hole in the lawn
	sun.directional_shadow_max_distance = 60.0
	sun.rotation_degrees = Vector3(-33.0, -38.0, 0.0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.92, 0.95, 1.0)
	fill.light_energy = p.fill_energy
	fill.rotation_degrees = Vector3(-25.0, 20.0, 0.0)
	add_child(fill)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 46.0
	add_child(camera)


func _place_camera() -> void:
	# up close the camera comes down toward eye level, so a close-up shows faces, not tops of heads
	var close := clampf((12.5 - _distance) / (12.5 - ZOOM_MIN), 0.0, 1.0)
	var el := _elev - close * close * 0.45
	var dir := Vector3(sin(_yaw) * cos(el), sin(el), cos(_yaw) * cos(el))
	camera.position = _target + dir * _distance
	camera.look_at(_target, Vector3.UP)


## A real lawn: soft patches of greens, bald dirt spots, a worn track from the gate to the grill.
func _build_ground() -> void:
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var big := FastNoiseLite.new()
	big.seed = 11
	big.frequency = 0.012
	big.fractal_octaves = 3
	var fine := FastNoiseLite.new()
	fine.seed = 23
	fine.frequency = 0.08
	var grass_a := Color("5f7a3e")
	var grass_b := Color("7a8f4c")
	var grass_dry := Color("8e9258")
	var dirt := Color("7d6a4e")
	for y in range(size):
		for x in range(size):
			var n := big.get_noise_2d(x, y)          # -1..1, soft patches
			var f := fine.get_noise_2d(x, y)
			var c := grass_a.lerp(grass_b, clampf(n * 0.9 + 0.5 + f * 0.25, 0.0, 1.0))
			c = c.lerp(grass_dry, clampf((f - 0.2) * 0.8, 0.0, 0.4))
			var u := float(x) / size * 60.0 - 30.0
			var v := float(y) / size * 60.0 - 30.0
			var bald := smoothstep(0.38, 0.62, n + f * 0.15)
			var track := exp(-pow((u - (5.5 - v * 0.15)) / 1.0, 2.0)) * smoothstep(-9.0, 3.0, -v)
			c = c.lerp(dirt, clampf(bald * 0.8 + track * 0.45, 0.0, 0.85))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var detail := Assets.image("res://assets/sprites/lawn_detail.png")
	detail.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/lawn.gdshader")
	m.set_shader_parameter("macro", ImageTexture.create_from_image(img))
	m.set_shader_parameter("detail", ImageTexture.create_from_image(detail))
	m.set_shader_parameter("dapple", load("res://assets/sprites/dapple.png"))
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = m
	ground.name = "Lawn"
	add_child(ground)
	_bald_noise = big


func _leaf_material(sheet: String) -> ShaderMaterial:
	if _leaf_mats.has(sheet):
		return _leaf_mats[sheet]
	var image := Assets.image("res://assets/sprites/%s.png" % sheet)
	var normals := Assets.image("res://assets/sprites/%s_n.png" % sheet)
	image.generate_mipmaps()
	normals.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/leaf.gdshader")
	m.set_shader_parameter("leaf_sheet", ImageTexture.create_from_image(image))
	m.set_shader_parameter("leaf_normals", ImageTexture.create_from_image(normals))
	m.set_shader_parameter("interior_ink", 0.2)
	m.set_shader_parameter("silhouette_ink", 0.5)
	m.set_shader_parameter("near_fade", GardenProps.NEAR_FADE)
	_leaf_mats[sheet] = m
	return m


## A leafy mass (hedge, tree crown, leaf pile) grown with the pets' foliage system.
func _bush(center: Vector3, radii: Vector3, sheet: String, palette: Dictionary, inner: Color, leaf_size: float, density: float, shape: Variant = {}, flowering := 0.0) -> Node3D:
	var seed := _rng.randi()
	var holder := Node3D.new()
	add_child(holder)
	# the mass and the leaves are pure functions of these inputs: read them from the bake cache when it has them
	var k := BakeCache.key(["bush", center, radii, sheet, palette, inner, leaf_size, density, shape, flowering, seed])
	var cached = BakeCache.fetch(k)
	var mass_mesh: Mesh
	var mm: MultiMesh
	if cached != null:
		mass_mesh = cached[0]
		mm = cached[1]
	else:
		var p := CharacterArtProfile.new()
		p.seed = seed
		p.leaf_size = leaf_size
		p.growth = 1.0
		p.flowering = flowering
		p.leaves_per_cluster = 16
		p.palette = palette
		p.anchors = {}
		p.protected_zones = {}
		p.regions = {
			"BODY": {"center": center, "radii": radii, "parent": "", "foliage": true, "density": density, "leaf_scale": 1.0,
				"max_displacement": 0.2, "growth_up": 0.4, "material": "foliage", "shape": shape},
			"HEAD": {"center": Vector3(0, -100, 0), "radii": Vector3(0.1, 0.1, 0.1), "parent": "", "foliage": false},
		}
		mass_mesh = HedgeAnatomy.build_mesh(p.regions["BODY"], 16, 28)
		var built := FoliageBuilder.build(p, "BODY", Vector3(0, -100, 0), Vector3(0.5, -0.8, 0.3).normalized())
		var items: Array = built["items"]
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		var quad := QuadMesh.new()
		quad.center_offset = Vector3(0, 0.5, 0)
		mm.mesh = quad
		mm.instance_count = items.size()
		for i in range(items.size()):
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
			mm.set_instance_custom_data(i, items[i][2])
		BakeCache.store(k, [mass_mesh, mm])
	var mass := MeshInstance3D.new()
	mass.mesh = mass_mesh
	mass.position = center
	mass.scale = Vector3.ONE * 0.96
	mass.material_override = GardenProps.mat("inner%s" % inner.to_html(), inner)
	holder.add_child(mass)
	var leaves := MultiMeshInstance3D.new()
	leaves.multimesh = mm
	leaves.material_override = _leaf_material(sheet)
	holder.add_child(leaves)
	return holder


func _build_backdrop() -> void:
	var hedge_palette := {"deep_forest": Color("2c4628"), "muted_ivy": Color("3f6234"), "matcha": Color("5d8440"),
		"warm_yellow_green": Color("7a9246"), "soft_sage": Color("647e5e"), "pale_highlight": Color("9fb47a")}
	# a ragged hedge along the back, behind the fence, with a gap where it has thinned
	_burying_ground()
	_surroundings()
	_tree_wall()
	_bush(Vector3(12.5, 1.2, -12.8), Vector3(4.6, 1.4, 1.3), "hedgeivy", hedge_palette, Color("2a4223"), 0.7, 0.55, "cushion")
	# tall trees: their crowns go off the top of the screen, their shadows fall across the lawn
	_tree(Vector3(-12.6, 0, 6.5), 12.0, hedge_palette)          # by the creek: its shade reaches the lawn
	_pine(Vector3(5.5, 0, -15.0), 14.0)
	_pine(Vector3(9.0, 0, -12.5), 11.0)
	_pine(Vector3(-9.5, 0, -7.0), 12.0)
	# autumn leaf piles, raked once and then forgotten
	var autumn := {"deep_forest": Color("7a4a24"), "muted_ivy": Color("9a5e2c"), "matcha": Color("b9803a"),
		"warm_yellow_green": Color("c99a46"), "soft_sage": Color("8e6a48"), "pale_highlight": Color("d8b066")}
	for at: Vector3 in [Vector3(8.5, 0.0, -6.5), Vector3(-9.5, 0.0, -6.8)]:
		_bush(at + Vector3(0, 0.15, 0), Vector3(1.3, 0.5, 1.1), "hedgeivy", autumn, Color("7a5332"), 0.45, 0.9, "dome")
		_thing("leaf_pile", get_child(get_child_count() - 1), Vector2(at.x, at.z), 1.4, 3)


## The creek's course (x for a given z), down the west side.
func _creek_x(z: float) -> float:
	return -17.0 + 1.5 * sin(z * 0.15)


## On the footbridge over the creek (the way to the woods).
func on_bridge(p: Vector2) -> bool:
	var bz: float = GATES["creek"]["peek"].z
	return absf(p.y - bz) < 1.4 and absf(p.x - _creek_x(bz)) < 2.6


func _in_creek(p: Vector2) -> bool:
	return absf(p.x - _creek_x(p.y)) < 1.7


## What surrounds the garden, one world on each side, each with its way in (GATES): the burying ground behind the
## broken fence (north), woods past the stone wall (east), a creek with a footbridge (west), the houses and the
## garden gate (south). They sit far enough out that the tilt-shift keeps them soft.
func _surroundings() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1775
	# west: the creek, a footbridge where the creek gate is, cattails along the banks
	var west := Node3D.new()
	west.name = "Creekside"
	add_child(west)
	GardenProps.creek(self, _creek_x, -32.0, 24.0, 2.6)
	var bz: float = GATES["creek"]["peek"].z
	GardenProps.footbridge(west, Vector3(_creek_x(bz) - 2.3, 0, bz), Vector3(_creek_x(bz) + 2.3, 0, bz), r)
	for k in range(14):
		var z := r.randf_range(-24, 18)
		if absf(z - bz) < 2.0:
			continue
		var side := 1.0 if r.randf() < 0.5 else -1.0
		GardenProps.cattails(west, Vector3(_creek_x(z) + side * r.randf_range(1.2, 1.7), 0, z), r)
	for k in range(12):
		var z := r.randf_range(-26, 20)
		GardenProps.rock(west, Vector3(_creek_x(z) + r.randf_range(-1.5, 1.5), 0, z), r.randf_range(0.2, 0.45), r)
	GardenProps.bake_static(west)
	for k in range(4):
		_pine(Vector3(_creek_x(-20.0 + k * 11.0) - r.randf_range(4.0, 7.0), 0, -20.0 + k * 11.0), r.randf_range(10.0, 13.0))
	# south: the houses, backs to the garden, and a picket fence with the garden gate standing open
	var south := Node3D.new()
	south.name = "Houses"
	add_child(south)
	var gx: float = GATES["houses"]["peek"].x
	GardenProps.broken_fence(south, -16.0, 16.0, 10.0, r, Vector2(gx - 1.1, gx + 1.1))
	GardenProps.house(south, Vector3(-12.5, 0, 20.0), 0.0, Color("e8e2d2"), Vector3(8.0, 5.0, 6.5), false, r)
	GardenProps.house(south, Vector3(0.0, 0, 18.5), 0.0, Color("eeeae0"), Vector3(9.0, 5.5, 7.0), true, r, Color("3a5a8a"))   # white siding, blue door, small steps
	GardenProps.house(south, Vector3(12.5, 0, 20.5), 0.0, Color("8a3a2a"), Vector3(8.0, 5.0, 6.5), false, r)
	GardenProps.bake_static(south)
	GardenProps.open_gate(self, Vector3(gx + 1.1, 0, 10.0), 2.1, 115.0)
	# east: woods past the stone wall, through the gap in it
	for k in range(12):
		var at := Vector3(r.randf_range(12.0, 28.0), 0, r.randf_range(-24.0, 16.0))
		if absf(at.z - GATES["woods"]["peek"].z) < 2.5 and at.x < 20.0:
			continue                                           # keep the woods path open
		if k % 3 == 0:
			_tree(at, r.randf_range(10.0, 13.0), SpeciesBuilder.palette_of(["autumn", "green", "crimson"][k % 3]), ["hedgeoak", "hedgemaple"][k % 2])
		else:
			_pine(at, r.randf_range(10.0, 15.0))


## The woods all around: a wall of tall trees behind the back fence and down the sides, so the yard feels small and
## sheltered at the edge of something much bigger. Far trees are cheap (fewer, bigger leaf masses) and soft in the
## tilt-shift. Paths stay open where the gates are.
func _tree_wall() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1636
	var spots: Array = []
	for k in range(15):                                           # behind the back fence (right of the burying ground)
		spots.append(Vector3(1.0 + k * 1.6 + r.randf_range(-0.6, 0.6), 0, r.randf_range(-15.5, -23.0)))
	for k in range(8):                                            # behind the burying ground
		spots.append(Vector3(-20.0 + k * 2.6 + r.randf_range(-0.8, 0.8), 0, r.randf_range(-27.0, -32.0)))
	for k in range(11):                                           # past the creek
		spots.append(Vector3(r.randf_range(-23.0, -30.0), 0, -24.0 + k * 4.0 + r.randf_range(-1.0, 1.0)))
	for k in range(9):                                            # deeper in the east woods
		spots.append(Vector3(r.randf_range(20.0, 30.0), 0, -24.0 + k * 4.6 + r.randf_range(-1.0, 1.0)))
	for k in range(5):                                            # behind the houses
		spots.append(Vector3(-18.0 + k * 9.0 + r.randf_range(-2.0, 2.0), 0, r.randf_range(26.0, 30.0)))
	var palettes := [SpeciesBuilder.palette_of("autumn"), SpeciesBuilder.palette_of("green"), SpeciesBuilder.palette_of("crimson"), SpeciesBuilder.palette_of("golden")]
	for at: Vector3 in spots:
		var gate_path: bool = (absf(at.z - GATES["woods"]["peek"].z) < 3.0 and at.x < 26.0 and at.x > 9.0) \
			or (absf(at.z - GATES["creek"]["peek"].z) < 3.0 and at.x < -18.0) or (at.x > -0.5 and at.x < 5.5 and at.z > -20.0)
		if gate_path:
			continue
		var h := r.randf_range(15.0, 22.0)
		if r.randf() < 0.45:
			_pine(at, h, true)
		else:
			_tree(at, h, palettes[r.randi() % palettes.size()], ["hedgeoak", "hedgemaple"][r.randi() % 2], true)


## Past the back fence on the left: an old New England burying ground. Slate stones in uneven rows inside a low
## field-stone wall, a big sugar maple gone crimson, one bare old tree, and leaves over everything. Autumn, not spooky:
## warm light, pumpkins, birds' perches.
func _burying_ground() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1692
	var ground := Node3D.new()
	ground.name = "BuryingGround"
	add_child(ground)
	GardenProps.stone_wall(ground, Vector3(-16.0, 0, -12.6), Vector3(-0.6, 0, -12.6), r)
	GardenProps.stone_wall(ground, Vector3(-0.6, 0, -12.6), Vector3(-0.2, 0, -24.0), r)
	for row in range(4):
		for k in range(6):
			if r.randf() < 0.2:
				continue
			var at := Vector3(-14.0 + k * 2.1 + r.randf_range(-0.4, 0.4), 0, -15.0 - row * 2.2 + r.randf_range(-0.3, 0.3))
			GardenProps.headstone(ground, at, r.randf_range(-8, 8), r.randf_range(0.8, 1.35), r)
	var crimson := SpeciesBuilder.palette_of("crimson")
	_tree(Vector3(-12.0, 0, -20.0), 13.0, crimson, "hedgemaple")
	GardenProps.dead_tree(ground, Vector3(-5.5, 0, -18.5), 9.0, r)
	GardenProps.bake_static(ground)
	for at: Vector3 in [Vector3(-1.4, 0, -11.6), Vector3(-2.2, 0, -11.9), Vector3(5.6, 0, -10.4)]:
		_thing("pumpkin", GardenProps.pumpkin(self, at, r.randf_range(0.5, 0.75), r), Vector2(at.x, at.z), 0.5, 1)


## Fallen leaves lying on the ground everywhere, thickest under the trees (one MultiMesh of flat leaf cards).
func _leaf_litter() -> void:
	var image := Assets.image("res://assets/sprites/hedgemaple.png")
	var tex := ImageTexture.create_from_image(image.get_region(Rect2i(0, 0, 160 * 8, 160)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = Vector3(1.0 / 8.0, 1.0, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.metallic_specular = 0.0
	var quad := PlaneMesh.new()
	quad.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	var sources: Array = _crowns.duplicate()
	sources.append(Vector3(-12.0, 0, -20.0))
	var items: Array = []
	var colors := [Color("c9923c"), Color("b8702e"), Color("9a3428"), Color("c0482e"), Color("d8a848"), Color("8a6a3a")]
	for i in range(4200):
		var under := i % 3 != 0
		var p: Vector3
		if under:
			var c: Vector3 = sources.pick_random()
			var rr := sqrt(_rng.randf()) * 5.5
			var a := _rng.randf() * TAU
			p = Vector3(c.x + cos(a) * rr, 0, c.z + sin(a) * rr)
		else:
			p = Vector3(_rng.randf_range(-18, 18), 0, _rng.randf_range(-24, 10))
		if _in_puddle(Vector2(p.x, p.z)) or _in_creek(Vector2(p.x, p.z)):
			continue
		var s := _rng.randf_range(0.22, 0.4)
		var b := Basis.from_euler(Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf() * TAU, _rng.randf_range(-0.25, 0.25))).scaled(Vector3(s, s, s))
		items.append([Transform3D(b, p + Vector3(0, 0.015 + _rng.randf() * 0.02, 0)), (colors.pick_random() as Color).darkened(_rng.randf() * 0.15)])
	mm.instance_count = items.size()
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.name = "LeafLitter"
	add_child(node)


## A limb from a to b (a tapered cylinder with an ink hull).
func _limb(a: Vector3, b: Vector3, r0: float, r1: float, m: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = GardenProps.cyl(r1, r0, a.distance_to(b), 8)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	node.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	node.material_override = m
	node.material_overlay = GardenProps.hull(0.02)
	add_child(node)
	return node


## A big broadleaf tree: a leaning trunk, a few branches forking up and out, a leaf clump at each branch end.
func _tree(at: Vector3, height: float, palette: Dictionary, sheet := "hedgeoak", far := false) -> void:
	var bark := GardenProps.mat("bark", Color("5c4634"))
	var lean := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	var top := at + Vector3(0, height * 0.62, 0) + lean
	_limb(at, top, 0.55, 0.3, bark).name = "Trunk"
	_limb(at + Vector3(0, 0.2, 0), at + Vector3(0.9, 0.0, 0.3), 0.3, 0.12, bark)       # a root
	_limb(at + Vector3(0, 0.2, 0), at + Vector3(-0.6, 0.0, -0.7), 0.28, 0.1, bark)
	var n := 3 if far else 5                                 # far trees (out of focus): fewer, bigger leaf masses
	var leaf := 1.3 if far else 0.8
	var dens := 0.32 if far else 0.5
	var grow := height / 12.0 if far else 1.0
	for i in range(n):
		var a := TAU * float(i) / float(n) + _rng.randf_range(-0.4, 0.4)
		var from := at.lerp(top, _rng.randf_range(0.55, 0.95))
		var reach := _rng.randf_range(2.2, 3.6)
		var to := from + Vector3(cos(a) * reach, _rng.randf_range(1.6, 3.2), sin(a) * reach)
		_limb(from, to, 0.24, 0.08, bark)
		var twig := to + Vector3(cos(a + 0.8) * 0.9, 0.7, sin(a + 0.8) * 0.9)
		_limb(to, twig, 0.08, 0.03, bark)
		var r := _rng.randf_range(1.6, 2.3) * grow
		_bush(to + Vector3(0, 0.6, 0), Vector3(r, r * 0.72, r), sheet, palette, Color(palette["deep_forest"]).darkened(0.2), leaf, dens, "egg")
	_bush(top + Vector3(0, 2.6, 0) * grow, Vector3(2.6, 2.0, 2.6) * grow, sheet, palette, Color(palette["deep_forest"]).darkened(0.2), leaf * 1.06, dens, "egg")
	if not far:
		_crowns.append(top + Vector3(0, 1.5, 0))
	obstacles.append([Vector2(at.x, at.z), 1.0])


## A pine: a straight thin trunk and tiers of needles, wide at the bottom, narrowing to a point.
func _pine(at: Vector3, height: float, far := false) -> void:
	var pine := {"deep_forest": Color("1c3529"), "muted_ivy": Color("28493a"), "matcha": Color("3b6046"),
		"warm_yellow_green": Color("557349"), "soft_sage": Color("4f6b5e"), "pale_highlight": Color("7f9a7c")}
	_limb(at, at + Vector3(0, height, 0), 0.4, 0.08, GardenProps.mat("pinebark", Color("4e3a2c"))).name = "Trunk"
	var tiers := 5
	for i in range(tiers):
		var t := float(i) / float(tiers - 1)
		var y := lerpf(height * 0.28, height * 0.9, t)
		var r := lerpf(3.0, 0.9, t) * height / 12.0 * _rng.randf_range(0.82, 1.12)
		var off := Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.35, 0.35))
		_bush(at + Vector3(0, y, 0) + off, Vector3(r, r * _rng.randf_range(0.48, 0.62), r * _rng.randf_range(0.85, 1.0)), "hedgepine", pine, Color("1d3326"), 1.25 if far else 0.8, 0.35 if far else 0.55,
			{"exponent": 2.0, "taper": -0.75, "taper_axis": "y", "flat_bottom": 0.5})
	obstacles.append([Vector2(at.x, at.z), 0.7])


var _crowns: Array = []                           # broadleaf crowns: where falling leaves come from


## Life in the garden: leaves drifting down from the oaks, butterflies over the lawn.
func _build_ambience() -> void:
	var image := Assets.image("res://assets/sprites/hedgemaple.png")
	var leaf := ImageTexture.create_from_image(image.get_region(Rect2i(0, 0, 160, 160)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = leaf
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ramp := Gradient.new()
	ramp.set_color(0, Color("c9923c"))
	ramp.set_color(1, Color("9a3428"))
	ramp.add_point(0.5, Color("b8702e"))
	for at: Vector3 in _crowns:
		var p := CPUParticles3D.new()
		p.amount = 10
		p.lifetime = 14.0
		p.preprocess = 14.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(3.0, 1.0, 3.0)
		p.direction = Vector3(1, -0.2, 0.3)
		p.spread = 40.0
		p.initial_velocity_min = 0.1
		p.initial_velocity_max = 0.4
		p.gravity = Vector3(0.18, -0.55, 0.12)
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -90.0
		p.angular_velocity_max = 90.0
		p.scale_amount_min = 0.09
		p.scale_amount_max = 0.14
		p.color_initial_ramp = ramp
		var quad := QuadMesh.new()
		quad.material = m
		p.mesh = quad
		p.position = at
		p.name = "FallingLeaves"
		add_child(p)
	var colors := [Color("f4f0dc"), Color("f2e27a"), Color("f0b860"), Color("f4f0dc"), Color("e8eef6"), Color("f2e27a")]
	for i in range(colors.size()):
		var b := preload("res://scripts/garden/butterfly.gd").new()
		add_child(b)
		b.setup(self, colors[i], Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 4)))


## Where butterflies like to go: flowering plants, and a few fixed flowery patches.
func butterfly_spots() -> Array:
	var out: Array = [Vector3(-3, 0, 1), Vector3(3.5, 0, -2), Vector3(0, 0, 4)]
	if game != null:
		for pl in game.plants:
			if pl["stage"] >= 3:
				out.append(Vector3(pl["at"].x, 0, pl["at"].y))
	return out


## Every prop is a thing in the garden: what it is, where, how big, whether the shovel can clear it and what it
## is worth as scrap. Some junk is worth keeping - some visitors like it (scripts/garden/garden_game.gd).
func _thing(kind: String, node: Node3D, at: Vector2, radius: float, value: int, junk := true) -> void:
	things.append({"id": "%s_%d" % [kind, things.size()], "kind": kind, "node": node, "at": at, "radius": radius, "junk": junk, "value": value})


func _build_props() -> void:
	var r := _rng
	# the back fence in sections, each one mendable (garden_grab.gd: hold on it with ✋)
	for sec: Vector2 in FENCE_SECTIONS:
		var node := GardenProps.bake_static(GardenProps.broken_fence(self, sec.x, sec.y, -11.0, r, FENCE_GAP))
		fence_sections.append({"from": sec.x, "to": sec.y, "node": node, "mended": false})
	# the old field wall down the east side, with a gap where the woods path comes in
	GardenProps.bake_static(GardenProps.stone_wall(self, Vector3(7.2, 0, -10.2), Vector3(8.3, 0, -3.2), r))
	GardenProps.bake_static(GardenProps.stone_wall(self, Vector3(8.6, 0, -0.8), Vector3(9.6, 0, 5.0), r))
	obstacles.append([Vector2(8.0, -5.0), 0.6])
	obstacles.append([Vector2(8.8, 0.0), 0.6])
	_thing("lawn_chair", GardenProps.lawn_chair(self, Vector3(-5.2, 0, -3.2), 28), Vector2(-5.0, -3.2), 1.3, 6)
	_thing("grill", GardenProps.rusty_grill(self, Vector3(5.8, 0, -4.5), -20), Vector2(6.3, -4.3), 1.6, 9)
	_thing("sprinkler", GardenProps.broken_sprinkler(self, Vector3(-1.8, 0, 3.6), 10), Vector2(-1.8, 3.6), 0.8, 5)
	_thing("tire", GardenProps.old_tire(self, Vector3(-9.8, 0, 1.8), 0), Vector2(-9.8, 1.8), 1.0, 4)
	_thing("pot", GardenProps.tipped_pot(self, Vector3(2.0, 0, -7.6), 40), Vector2(2.0, -7.6), 0.8, 2)
	_thing("branch", GardenProps.branch(self, Vector3(3.2, 0, 2.4), 25, 2.8, r), Vector2(3.2, 2.4), 1.2, 2)
	_thing("branch", GardenProps.branch(self, Vector3(-7.0, 0, 6.5), -60, 2.0, r), Vector2(-7.0, 6.5), 1.0, 2)
	for i in range(12):
		var at := Vector3(r.randf_range(-11, 11), 0, r.randf_range(-8, 8))
		_thing("stick", GardenProps.stick(self, at, r.randf_range(0, 360), r), Vector2(at.x, at.z), 0.4, 1)
	# the ordinary stuff: a woodpile against the pine, the one chair standing alone in the grass, a brush pile
	_thing("woodpile", GardenProps.woodpile(self, Vector3(-8.3, 0, -5.6), 20.0, r), Vector2(-8.3, -5.6), 1.1, 0, false)
	_thing("chair", GardenProps.chair_upright(self, Vector3(1.8, 0, 2.8), -150.0), Vector2(1.8, 2.8), 0.9, 2, false)
	_thing("brush_pile", GardenProps.brush_pile(self, Vector3(5.6, 0, -8.6), r), Vector2(5.6, -8.6), 1.2, 0, false)
	# places to hide: a paint bucket by the gate, a big pot, the old well, the burrow behind the corner tree
	_thing("bucket", GardenProps.paint_bucket(self, Vector3(5.2, 0, 7.0), 30.0), Vector2(5.2, 7.0), 0.4, 0, false)
	_thing("planter", GardenProps.pot_upright(self, Vector3(-3.6, 0, -7.6)), Vector2(-3.6, -7.6), 0.55, 0, false)
	_thing("well", GardenProps.stone_well(self, Vector3(-7.4, 0, -8.8), r), Vector2(-7.4, -8.8), 1.15, 0, false)
	_thing("burrow", GardenProps.burrow(self, BURROW_AT, 20.0, r), Vector2(BURROW_AT.x, BURROW_AT.z), 0.9, 0, false)
	for at: Array in [[Vector3(-9.0, 0, -5.8), 0.55], [Vector3(-8.2, 0, -5.2), 0.35], [Vector3(10.2, 0, 3.4), 0.7], [Vector3(9.3, 0, 4.2), 0.4], [Vector3(0.5, 0, 7.6), 0.45]]:
		_thing("rock", GardenProps.rock(self, at[0], at[1], r), Vector2(at[0].x, at[0].z), float(at[1]) + 0.4, 1)


func count(kind: String) -> int:
	var n := 0
	for t in things:
		if t["kind"] == kind:
			n += 1
	return n


## Grass tufts and weeds over the lawn, thinner on the bald spots, none under the junk.
func _build_grass() -> void:
	var image := Assets.image("res://assets/sprites/grass.png")
	image.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grass.gdshader")
	m.set_shader_parameter("grass_sheet", ImageTexture.create_from_image(image))
	m.set_shader_parameter("dapple", load("res://assets/sprites/dapple.png"))
	# a tuft = two crossed quads
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.0, PI * 0.5]:
		var dx := Vector3(cos(a), 0, sin(a)) * 0.5
		var corners := [-dx, dx, dx + Vector3.UP, -dx + Vector3.UP]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])
	var tuft := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = tuft
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.name = "Grass"
	add_child(node)
	# The tufts come from the seeded RNG and what's in the way, so they're the same every time: an exported game reads
	# them from the startup cache (with the RNG's state after them) instead of placing ~31k one by one. The editor
	# always places them live, so a change here shows at once; the bake (tools/bake_cache.gd) records them.
	var cached := BakeCache.recording or BakeCache.live_salt() == ""
	var key := BakeCache.key(["grass", 2, _rng.state, _grass_inputs()])
	var hit = BakeCache.fetch(key) if cached else null
	if hit is Array:
		mm.instance_count = int(hit[0])
		mm.buffer = hit[1]
		_rng.state = int(hit[2])
		return
	var items: Array = []
	for i in range(26000):
		var x := _rng.randf_range(-19, 19)
		var z := _rng.randf_range(-11, 11)
		if _blocked(Vector2(x, z), 0.12) or _in_puddle(Vector2(x, z)) or _in_creek(Vector2(x, z)):
			continue
		var bald := _bald_noise.get_noise_2d((x + 30.0) / 60.0 * 512.0, (z + 30.0) / 60.0 * 512.0)
		if bald > 0.4 and _rng.randf() < 0.8:
			continue
		var cell := _rng.randi_range(0, 7)
		var roll := _rng.randf()
		if roll < 0.012:
			cell = 8          # dandelion
		elif roll < 0.03:
			cell = 9          # clover
		elif roll < 0.038:
			cell = 10         # daisy
		elif roll < 0.07:
			cell = 11         # seed heads
		var s := _rng.randf_range(0.32, 0.6) * (1.5 if cell == 11 else (1.25 if cell >= 8 else 1.0))   # ankle-high to a pet
		var t := Transform3D(Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(Vector3(s, s, s)), Vector3(x, 0, z))
		var tint := Color("86a050").lerp(Color("a9ad62"), _rng.randf() * 0.6).darkened(_rng.randf() * 0.12)
		items.append([t, tint, Color(float(cell), _rng.randf_range(0, TAU), 0, 0)])
	_grass_edges(items)
	# one buffer in MultiMesh's own layout (a transform's three rows, then colour, then custom data: 20 floats each),
	# made here rather than read back from the GPU, so the cache holds real data even when baked headless
	var buf := PackedFloat32Array()
	buf.resize(items.size() * 20)
	for i in range(items.size()):
		var t: Transform3D = items[i][0]
		var b := t.basis
		var c: Color = items[i][1]
		var d: Color = items[i][2]
		var o := i * 20
		buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = t.origin.x
		buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = t.origin.y
		buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = t.origin.z
		buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a
		buf[o + 16] = d.r; buf[o + 17] = d.g; buf[o + 18] = d.b; buf[o + 19] = d.a
	mm.instance_count = items.size()
	mm.buffer = buf
	if cached:
		BakeCache.store(key, [items.size(), buf, _rng.state])


## What the grass depends on besides the RNG: the trunks and things it grows around, and the puddle.
func _grass_inputs() -> String:
	var parts: Array = [obstacles]
	for t in things:
		var puddle: Node3D = t["node"].get_node_or_null("Puddle") if t["kind"] == "sprinkler" else null
		parts.append([t["kind"], t["at"], t["radius"], puddle.global_transform if puddle != null else null])
	return var_to_str(parts)


## The sprinkler's puddle (garden_props.gd: offset 0.9, 0.4 from the sprinkler, 2.6 x 1.8, turned 20°).
func _in_puddle(p: Vector2) -> bool:
	for t in things:
		if t["kind"] == "sprinkler":
			var node: Node3D = t["node"]
			var puddle := node.get_node_or_null("Puddle") as Node3D
			if puddle != null:
				var local := puddle.global_transform.affine_inverse() * Vector3(p.x, 0, p.y)
				if Vector2(local.x / 1.15, local.z / 0.8).length() < 1.0:
					return true
	return false


## Where the mower never reaches: a band of taller, thicker grass along every fence and wall foot and around the
## tree trunks (one more pass of the same tufts: cheap).
func _grass_edges(items: Array) -> void:
	var lines: Array = [
		[Vector2(-16, -11.0), Vector2(16, -11.0)],               # the back fence
		[Vector2(-16, 10.0), Vector2(16, 10.0)],                 # the fence along the houses
		[Vector2(7.2, -10.2), Vector2(8.3, -3.2)], [Vector2(8.6, -0.8), Vector2(9.6, 5.0)],   # the east wall
	]
	var seeds: Array = []
	for l: Array in lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var n := int(a.distance_to(b) * 160)
		for k in range(n):
			var p := a.lerp(b, _rng.randf()) + (b - a).normalized().orthogonal() * _rng.randf_range(-0.7, 0.7) * absf(_rng.randfn(0.0, 0.6))
			seeds.append(p)
	for o in obstacles:                                          # around the trunks
		for k in range(60):
			var ang := _rng.randf() * TAU
			seeds.append((o[0] as Vector2) + Vector2(cos(ang), sin(ang)) * (float(o[1]) + _rng.randf_range(0.05, 0.9)))
	for p: Vector2 in seeds:
		if absf(p.x) > 19.0 or p.y < -11.6 or p.y > 11.0 or _blocked(p, 0.05) or _in_puddle(p) or _in_creek(p):
			continue
		var cell := _rng.randi_range(0, 7) if _rng.randf() > 0.12 else 11
		var s := _rng.randf_range(0.5, 0.85)                     # long grass
		var t := Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(0, TAU), _rng.randf_range(-0.12, 0.12))).scaled(Vector3(s, s * _rng.randf_range(1.0, 1.4), s)), Vector3(p.x, 0, p.y))
		var tint := Color("7e9a4a").lerp(Color("b0a860"), _rng.randf() * 0.7).darkened(_rng.randf() * 0.1)
		items.append([t, tint, Color(float(cell), _rng.randf_range(0, TAU), 0, 0)])


func _blocked(p: Vector2, margin: float) -> bool:
	for o in obstacles:
		if p.distance_to(o[0]) < float(o[1]) + margin:
			return true
	for t in things:
		if t["kind"] != "stick" and p.distance_to(t["at"]) < float(t["radius"]) + margin:
			return true
	return false


# ------------------------------------------------------------------ pets
func _spawn_pets() -> void:
	roster = CharacterArtProfile.roster()


var _shadow_mat: StandardMaterial3D


## A soft dark pool on the grass under a pet: it sits on the lawn instead of hovering over it.
func _contact_shadow(node: Node3D, p: CharacterArtProfile) -> void:
	if _shadow_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.5))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.albedo_texture = tex
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var r: Vector3 = p.regions["BODY"]["radii"]
	var plane := PlaneMesh.new()
	plane.size = Vector2(r.x * 2.6 + 0.6, r.z * 2.6 + 0.4)
	var s := MeshInstance3D.new()
	s.mesh = plane
	s.material_override = _shadow_mat
	s.position = Vector3(0.2, 0.02, 0)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.name = "ContactShadow"
	node.add_child(s)


## A pet's node, built the first time it comes by (a garden of thirty pets only pays for the ones in it).
func node_for(p: CharacterArtProfile) -> HedgePetNode:
	if _nodes.has(p.pet_name):
		return _nodes[p.pet_name]
	var node := HedgePetNode.new()
	node.name = "Pet_" + p.pet_name
	add_child(node)
	node.setup(p)
	node.scale = Vector3.ONE * PET_SCALE
	node.rotation.y = _rng.randf_range(-PI, PI)
	node.set_detail("MEDIUM", true)
	node.visible = false
	node.position = GATES[gate_for(p)]["out"]
	_contact_shadow(node, p)
	pets.append(node)
	_nodes[p.pet_name] = node
	_wander[node] = {"target": node.position, "wait": _rng.randf_range(0.5, 3.0), "mode": "away", "gate": gate_for(p)}
	return node


## How a pet is in the garden: "away" (out of sight), "peek" (at the fence gap, looking in), "roam" (wandering),
## "leave" (walking back out through the gap).
func set_pet_mode(node: HedgePetNode, mode: String, at_once := false) -> void:
	var w: Dictionary = _wander[node]
	if w["mode"] == "carried":
		return                                           # in the bucket: only uncarry() lets it out
	var was: String = w["mode"]
	w["mode"] = mode
	var g: Dictionary = GATES[w.get("gate", "fence")]
	var side := Vector3(g["peek"] - g["out"]).normalized().cross(Vector3.UP)
	match mode:
		"away":
			if node.visible and not at_once:             # out through the gap: shrink away, then park outside
				Motion.vanish(node, false).tween_callback(func() -> void: node.position = g["out"])
			else:
				node.visible = false
				node.position = g["out"]
		"peek":
			var bs: Dictionary = hideouts.spot_of("burrow") if hideouts != null else {}
			if w.get("gate", "") == "burrow" and was == "away" and not bs.is_empty() and bs["occupant"] == null:
				hideouts.place_hidden(node, bs, 9999.0)          # a face in the burrow doorway, looking out
				w["mode"] = "hidden"
				w["peeking"] = true
				return
			if was == "away":
				node.position = g["out"].lerp(g["peek"], 0.55) + side * _rng.randf_range(-1.0, 1.0)
				Motion.appear(node, Vector3.ONE * PET_SCALE, Motion.SLOW)
			w["target"] = _fit(g["peek"] + side * _rng.randf_range(-1.2, 1.2), node, w)
		"roam":
			if w.get("peeking", false) and w.get("hideout") != null:
				w["peeking"] = false
				hideouts.exit(node)                          # climbs out of the burrow into the garden
				return
			if was == "away":
				Motion.appear(node, Vector3.ONE * PET_SCALE, Motion.SLOW)
				node.position = _fit(g["peek"].lerp(g["inside"], 0.5), node, w)
				if at_once:                              # already living here when the garden opens
					for k in range(20):
						var spot := Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-2, 3))
						if not _blocked(spot, 0.8):
							node.position = Vector3(spot.x, 0, spot.y)
							break
			w["target"] = _fit(g["inside"] + side * _rng.randf_range(-1.0, 1.0), node, w)
			w["wait"] = 0.5
		"leave":
			w["target"] = g["out"].lerp(g["peek"], 0.2)
			w["best_d"] = INF


## Into the bucket (🪣): out of the garden's hands until uncarry().
func carry(node: HedgePetNode) -> void:
	var w: Dictionary = _wander[node]
	w["mode"] = "carried"
	w["following"] = false
	node.set_sleeping(false)
	node.visible = false


## Out of the bucket at a spot on the lawn: it hops out and carries on as a visitor or resident would.
func uncarry(node: HedgePetNode, at: Vector3, animate := true) -> void:
	var w: Dictionary = _wander[node]
	w["mode"] = "roam"
	node.position = Vector3(at.x, 0, at.z)
	node.scale = Vector3.ONE * PET_SCALE
	w["target"] = node.position
	w["wait"] = 1.5
	node.visible = true
	if animate:
		Motion.appear(node, Vector3.ONE * PET_SCALE)
		node.tap()


func pet_mode(node: HedgePetNode) -> String:
	return _wander[node]["mode"]


var _hover := Vector2.INF                         # the pointer over the garden (mouse only; touch has no hover)
var _next_bloom := 90.0


func _process(delta: float) -> void:
	for node in pets:
		_walk(node, delta)
		if node.visible:
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
	_place_camera()


func _clamp_target(t: Vector3) -> Vector3:
	return Vector3(clampf(t.x, -15.0, 15.0), 0.0, clampf(t.z, -14.0, 12.0))


## Wander: stand a while, look around, pick a free spot, walk there with a little step, turning to face the way.
func _walk(node: HedgePetNode, delta: float) -> void:
	var w: Dictionary = _wander[node]
	if w["mode"] == "away" or w["mode"] == "carried":
		return
	if w["mode"] in ["hiding", "hidden", "emerging"]:
		hideouts.tend(node, w, delta)                    # climbing in / tucked away / climbing out
		return
	var to: Vector3 = w["target"] - node.position
	to.y = 0.0
	if to.length() < 0.15:
		if w["mode"] == "roam" and float(w.get("best_d", INF)) != INF:
			walk_stats["arrived"] += 1                  # reached the spot it was going for
			w["give_ups"] = 0
		w["best_d"] = INF
		node.walking = move_toward(node.walking, 0.0, delta * 3.0)
		if w["mode"] == "peek":
			node.rotation.y = lerp_angle(node.rotation.y, _heading(node.position, CENTER), clampf(delta * 3.0, 0.0, 1.0))   # looking in
			return
		if w["mode"] == "leave":
			var b: Dictionary = hideouts.spot_of("burrow")
			if w.get("gate", "") == "burrow" and not b.is_empty() and b["occupant"] == null:
				hideouts.enter(node, b, true)            # home: back down the burrow
				return
			set_pet_mode(node, "away")
			return
		if w["mode"] == "to_hide":
			hideouts.enter(node, w["hideout"])
			return
		w["wait"] = float(w["wait"]) - delta
		if node.sleeping:
			# asleep wherever it settled: a slow Zzz now and then; it wakes by itself (or when you tap it)
			w["zzz"] = float(w.get("zzz", 0.0)) - delta
			if float(w["zzz"]) <= 0.0:
				w["zzz"] = _rng.randf_range(3.5, 6.0)
				emote(node, "💤")
			if float(w["wait"]) <= 0.0:
				node.set_sleeping(false)
				w["wait"] = _rng.randf_range(1.5, 3.0)
			return
		# standing: turn three-quarters toward the viewer, so you see faces, not backs (or toward a napping friend)
		var face: float = w.get("face", 0.0)
		var look_at: Vector3 = w["friend"].position if w.get("friend") != null and is_instance_valid(w["friend"]) else camera.position
		node.rotation.y = lerp_angle(node.rotation.y, _heading(node.position, look_at) + face, clampf(delta * 2.0, 0.0, 1.0))
		if w.get("fav", "") != "":
			emote(node, str(w["fav"]))                   # got to a favourite thing: enjoy it
			w["fav"] = ""
		if w.get("friend") != null:
			if is_instance_valid(w["friend"]):
				emote(node, "💕")
			w["friend"] = null
			node.set_sleeping(true)                      # curled up beside its friend
			w["wait"] = _rng.randf_range(25.0, 45.0)
			return
		var free: bool = w["mode"] == "roam" and not w.get("following", false)    # a follower stays with you
		if float(w["wait"]) <= 0.0 and free and _rng.randf() < 0.18:
			node.set_sleeping(true)                      # a nap, right here, however inconvenient
			w["wait"] = _rng.randf_range(20.0, 40.0)
			w["face"] = _rng.randf_range(-1.2, 1.2)
			return
		if float(w["wait"]) <= 0.0 and free and _rng.randf() < 0.15 and _curl_up(node, w):
			return
		if float(w["wait"]) <= 0.0 and free and _rng.randf() < 0.12 and hideouts.go_hide(node, w):
			return
		if float(w["wait"]) <= 0.0:
			var fav: Dictionary = game.favourite(node) if game != null and _rng.randf() < 0.55 else {}
			if not fav.is_empty():
				var at: Vector3 = fav["at"]
				# beside it, where this pet actually fits (its own size, not a fixed margin)
				var off := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * (float(fav["radius"]) * 0.8 + pet_radius(node) + 0.3)
				var spot := free_spot(Vector2(at.x + off.x, at.z + off.z), pet_radius(node))
				if BOUNDS.has_point(spot) and not _path_blocked(Vector2(node.position.x, node.position.z), spot, pet_radius(node)):
					w["target"] = Vector3(spot.x, 0, spot.y)
					w["best_d"] = INF
					w["fav"] = fav["emote"]
					w["wait"] = _rng.randf_range(5.0, 10.0)
					w["face"] = _rng.randf_range(-0.9, 0.9)
					return
			_pick_target(node, w)
			w["wait"] = _rng.randf_range(2.0, 6.0)
			w["face"] = [-0.8, 0.8].pick_random() + _rng.randf_range(-0.3, 0.3)
		return
	var speed := 1.1 * (0.6 if node.profile.species == "tortoise" else 1.0)
	# steering is smoothed so avoidance can't flip sides every frame (no spinning in place)
	var want := _steer(node, to.normalized())
	var dir: Vector3 = (w.get("dir", want) as Vector3).lerp(want, clampf(delta * 5.0, 0.0, 1.0))
	dir = dir.normalized() if dir.length() > 0.01 else want
	w["dir"] = dir
	var heading := atan2(-dir.z, dir.x)
	node.rotation.y = lerp_angle(node.rotation.y, heading, clampf(delta * 4.0, 0.0, 1.0))
	# keep shuffling forward while turning, slower the more it has to turn
	var align := clampf(1.0 - absf(angle_difference(node.rotation.y, heading)) / 1.4, 0.15, 1.0)
	node.position += dir * minf(speed * align * delta, to.length())
	node.walking = move_toward(node.walking, 0.3 + 0.7 * align, delta * 3.0)
	# progress, not movement: if it hasn't got 0.25 m closer in 1.5 s it is blocked (by a pet on the spot, junk parked
	# in the way, a corner). Near the goal that counts as arriving; far from it, pick somewhere else.
	var d := to.length()
	if d < float(w.get("best_d", INF)) - 0.25:
		w["best_d"] = d
		w["stall"] = 0.0
	else:
		w["stall"] = float(w.get("stall", 0.0)) + delta
	if float(w["stall"]) > 1.5:
		w["stall"] = 0.0
		w["best_d"] = INF
		if d < pet_radius(node) + 1.2 or w["mode"] != "roam":
			w["target"] = node.position                 # close enough: stop here (peek / leave also end here)
			walk_stats["close_enough"] += 1
			w["give_ups"] = 0
		else:
			_pick_target(node, w)
			walk_stats["gave_up"] += 1
			w["give_ups"] = int(w.get("give_ups", 0)) + 1
			walk_stats["most_in_a_row"] = maxi(walk_stats["most_in_a_row"], w["give_ups"])


# ------------------------------------------------------------------ collisions
## Pets are round: this one's footprint radius in the garden.
func pet_radius(node: HedgePetNode) -> float:
	var r: Vector3 = node.profile.regions["BODY"]["radii"]
	return maxf(r.x, r.z) * node.scale.x * 0.85


## Everything solid on the lawn as circles [centre, radius]: trunks and walls, junk and things you built (not sticks
## or leaf piles - pets walk over those), and the other pets.
func colliders(skip: Variant = null, with_pets := true, with_things := true) -> Array:
	var out: Array = []
	for o in obstacles:
		out.append([o[0], float(o[1])])
	for t in (things if with_things else []):
		if t["kind"] in ["stick", "leaf_pile"] or (skip is Dictionary and t == skip):
			continue
		out.append([t["at"], float(t["radius"]) * 0.8])
	for n in pets:
		if with_pets and n.visible and n != skip:
			out.append([Vector2(n.position.x, n.position.z), pet_radius(n)])
	return out


## Walk around whatever is ahead instead of into it: each nearby solid in front pushes the heading sideways.
func _steer(node: HedgePetNode, want: Vector3) -> Vector3:
	var p := Vector2(node.position.x, node.position.z)
	var w2 := Vector2(want.x, want.z)
	var avoid := Vector2.ZERO
	var pr := pet_radius(node)
	for c in colliders(node):
		var off: Vector2 = p - c[0]
		var gap := off.length() - float(c[1]) - pr
		if gap > 1.4 or off.length() < 0.001:
			continue
		if w2.dot(-off.normalized()) <= 0.0:
			continue                                   # behind or beside: no need
		var side := Vector2(-off.y, off.x).normalized()
		if side.dot(w2) < 0.0:
			side = -side                               # go round on the side we're already heading
		avoid += (off.normalized() * 0.5 + side) * (1.4 - gap) / 1.4
	var d := (w2 + avoid * 1.6).normalized()
	return Vector3(d.x, 0, d.y)


## Nothing overlaps: a pet inside a solid (walked in, or had a wheelbarrow-full of junk hauled into it) is pushed
## out, gently, every frame.
func _separate(node: HedgePetNode, delta: float) -> void:
	var p := Vector2(node.position.x, node.position.z)
	var pr := pet_radius(node)
	var push := Vector2.ZERO
	for c in colliders(node):
		var off: Vector2 = p - c[0]
		var depth := float(c[1]) + pr - off.length()
		if depth > 0.0:
			push += (off.normalized() if off.length() > 0.001 else Vector2.RIGHT) * depth
	if push != Vector2.ZERO:
		var step := push * clampf(delta * 12.0, 0.0, 1.0)
		node.position += Vector3(step.x, 0, step.y)


## A little thought above a pet's head (an emoji), rising and fading.
func emote(node: Node3D, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = node.position + Vector3(0, 1.7 * node.scale.y * 2.0, 0)
	add_child(l)
	l.scale = Vector3.ONE * 0.01
	Motion.appear(l, Vector3.ONE, Motion.FAST)
	Motion.float_away(l, 0.7, 1.6, 0.6)


## Go and curl up beside another pet that's napping (then nap too). False if nobody is.
func _curl_up(node: HedgePetNode, w: Dictionary) -> bool:
	var sleepers: Array = pets.filter(func(n) -> bool: return n != node and n.visible and n.sleeping and _wander[n]["mode"] == "roam")
	if sleepers.is_empty():
		return false
	var friend: HedgePetNode = sleepers.pick_random()
	var pr := pet_radius(node)
	var side := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	var spot := friend.position + side * (pet_radius(friend) + pr + 0.05)
	var p2 := Vector2(spot.x, spot.z)
	if _blocked(p2, pr) or not BOUNDS.has_point(p2):
		return false
	w["target"] = spot
	w["friend"] = friend
	w["best_d"] = INF
	w["wait"] = 0.1
	return true


## A random free spot it can walk straight to (falls back to staying put).
func _pick_target(node: HedgePetNode, w: Dictionary) -> void:
	var pr := pet_radius(node)
	var from := Vector2(node.position.x, node.position.z)
	for attempt in range(16):
		var p := Vector2(_rng.randf_range(BOUNDS.position.x, BOUNDS.end.x), _rng.randf_range(BOUNDS.position.y, BOUNDS.end.y))
		if not _blocked(p, pr + 0.4) and not _path_blocked(from, p, pr):
			w["target"] = Vector3(p.x, 0, p.y)
			w["best_d"] = INF
			return
	w["target"] = node.position


## The nearest point to `p` where a pet of radius `pr` fits: pushed out of every solid it lands in (a few passes,
## since getting out of one can put it in another). Pets don't count: they move.
## A gate spot moved to where this pet fits (and its progress tracking reset for the new goal).
func _fit(v: Vector3, node: HedgePetNode, w: Dictionary) -> Vector3:
	var p := free_spot(Vector2(v.x, v.z), pet_radius(node))
	w["best_d"] = INF
	w["stall"] = 0.0
	return Vector3(p.x, 0, p.y)


func free_spot(p: Vector2, pr: float) -> Vector2:
	for pass_i in range(4):
		var moved := false
		for c in colliders(null, false):
			var off: Vector2 = p - c[0]
			var need := float(c[1]) + pr + 0.15
			if off.length() < need:
				p = (c[0] as Vector2) + (off.normalized() if off.length() > 0.001 else Vector2.RIGHT) * need
				moved = true
		if not moved:
			break
	return p


## The pet nearest the pointer looks up at you, with a curious tilt; the rest go back to what they were doing.
func _notice_pointer() -> void:
	var near: HedgePetNode = null
	if _hover != Vector2.INF:
		var best := 150.0
		for node in pets:
			if not node.visible or node.sleeping:
				continue
			var d := camera.unproject_position(node.global_position + Vector3(0, 0.7, 0)).distance_to(_hover)
			if d < best:
				best = d
				near = node
	for node in pets:
		var was: bool = node.noticed
		node.noticed = node == near
		if node.noticed:
			node.look_point = camera.global_position
		elif was:
			node.look_point = Vector3.INF


## The yaw that points a pet (it faces +x) from `from` toward `to`.
func _heading(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.z - from.z), to.x - from.x)


func _path_blocked(a: Vector2, b: Vector2, pr := 0.7) -> bool:
	var steps := maxi(4, int(a.distance_to(b) / 0.5))
	for k in range(1, steps + 1):
		if _blocked(a.lerp(b, float(k) / steps), pr):
			return true
	return false


# ------------------------------------------------------------------ the miniature look
func _build_tilt_shift() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	layer.name = "TiltShift"
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/tilt_shift.gdshader")
	rect.material = m
	layer.add_child(rect)


# ------------------------------------------------------------------ input: pan, zoom, tap a pet
## Controls. Touch: one finger on the top half of the screen turns around the garden and tilts a little; on the bottom
## half it pans, the ground following your hand (an invisible line; nobody needs to be told). Two fingers: pan and
## pinch to zoom. Mouse: left drag turns, right drag pans. Wheel / pinch: zoom, from close-up to the whole garden.
## Keys: WASD or arrows pan, Q / E turn, R / F zoom.
const TURN_PER_PX := 0.0025
const ZOOM_MIN := 4.5
const ZOOM_MAX := 24.0
var _touches := {}                 # touch index -> position
var _holder := ""                  # what this press works: "arrange" (moving something you built), "grab" (junk), ""
var _pan_drag := false             # this finger started on the bottom half: it pans
var _pinch := 0.0


func _unhandled_input(event: InputEvent) -> void:
	# On touch screens Godot also sends each touch as a mouse event (the HUD's buttons rely on that). The garden takes
	# the touch itself and ignores the copy, or a one-finger turn would count twice.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	# a touch that lands on the HUD belongs to the HUD (its button got the mouse copy), not to the garden under it
	if event is InputEventScreenTouch and event.pressed and game != null and game.ui_blocks(event.position):
		return
	if event is InputEventMagnifyGesture:
		_zoom_by(1.0 / event.factor)
		return
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoom_by(0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.12)
		return
	# two fingers: pan with their midpoint, pinch to zoom; a single finger never turns while two are down
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch = _touch_spread()
		if _touches.size() >= 2:
			_press_at = Vector2.INF              # a second finger cancels the tap / turn
			return
	if event is InputEventScreenDrag and _touches.size() >= 2:
		var before := _touch_mid()
		_touches[event.index] = event.position
		_pan_by((_touch_mid() - before))
		var spread := _touch_spread()
		if _pinch > 1.0 and spread > 1.0:
			_zoom_by(_pinch / spread)
		_pinch = spread
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
	if event is InputEventMouseMotion:
		_hover = event.position
	# right mouse button: pan
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_pan_by(event.relative)
		return
	if _touches.size() >= 2:
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if pressed:
		_press_at = event.position
		_dragged = false
		_pan_drag = event is InputEventScreenTouch and event.position.y > get_viewport().get_visible_rect().size.y * 0.5
		_holder = ""
		if game != null and game.arrange_begin(event.position):     # something you built, with 🧺: move or turn it
			_holder = "arrange"
		elif game != null and game.grab.begin(event.position):      # on a piece of junk: work it, don't turn
			_holder = "grab"
	elif released and _press_at != Vector2.INF:
		if _holder == "arrange":
			game.arrange_end(event.position, _dragged)
		elif _holder == "grab":
			if not game.grab.end(event.position):
				_tap(event.position)
		elif not _dragged:
			_tap(event.position)
		_press_at = Vector2.INF
		_holder = ""
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _press_at != Vector2.INF:
		if event.position.distance_to(_press_at) > 10.0:
			_dragged = true
		if _holder == "arrange":
			game.arrange_move(event.position)
			return
		if _holder == "grab":
			game.grab.move(event.position)
			return
		if _dragged and _pan_drag:
			_pan_by(event.relative)
		elif _dragged:
			_goal_yaw -= event.relative.x * TURN_PER_PX
			_goal_elev = clampf(_goal_elev + event.relative.y * 0.002, deg_to_rad(28), deg_to_rad(72))


func _touch_mid() -> Vector2:
	var m := Vector2.ZERO
	for k in _touches:
		m += _touches[k]
	return m / maxf(1.0, _touches.size())


func _touch_spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


## Move the view by a screen drag: the ground follows the hand (drag right, the garden moves right).
func _pan_by(screen: Vector2) -> void:
	var k := _goal_distance * 0.0016
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var toward_camera := Vector3(sin(_yaw), 0, cos(_yaw))
	_goal_target = _clamp_target(_goal_target - right * screen.x * k - toward_camera * screen.y * k)


func _zoom_by(factor: float) -> void:
	_goal_distance = clampf(_goal_distance * factor, ZOOM_MIN, ZOOM_MAX)


func _keys(delta: float) -> void:
	var pan := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A): pan.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): pan.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): pan.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): pan.y += 1.0
	if pan != Vector2.ZERO:
		_pan_by(-pan.limit_length(1.0) * 520.0 * delta)
	if Input.is_physical_key_pressed(KEY_Q): _goal_yaw += 0.9 * delta
	if Input.is_physical_key_pressed(KEY_E): _goal_yaw -= 0.9 * delta
	if Input.is_physical_key_pressed(KEY_R): _zoom_by(1.0 - 1.2 * delta)
	if Input.is_physical_key_pressed(KEY_F): _zoom_by(1.0 + 1.2 * delta)


func _tap(at: Vector2) -> void:
	var best: HedgePetNode = null
	var best_d := 90.0
	for node in pets:
		if not node.visible:
			continue
		var d := camera.unproject_position(node.global_position + Vector3(0, 0.6, 0)).distance_to(at)
		if d < best_d:
			best_d = d
			best = node
	if game != null and game.tap(at, best if best_d < 90.0 else null):
		return
	if best != null:
		best.tap()
		best.look_point = camera.global_position


## Where a screen point lands on the lawn (y = 0).
func ground_point(at: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(at)
	var dir := camera.project_ray_normal(at)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := -origin.y / dir.y
	return origin + dir * t if t > 0.0 else Vector3.INF
