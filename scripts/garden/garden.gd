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
var _target := Vector3(0.0, 0.0, -0.5)
var _distance := 12.5
## The camera eases toward these (Motion.approach): input moves the goal, never the camera itself; a drag that ends
## moving keeps gliding a little.
var _goal_target := Vector3(0.0, 0.0, -0.5)
## Orbit: the camera circles the middle of the garden. Drag sideways to spin (with a glide after a fling), drag up and
## down to tilt a little, wheel / pinch to zoom. Springs on all three (Motion.spring).
const CENTER := Vector3(0.0, 0.0, -0.8)
var _yaw := 0.0
var _goal_yaw := 0.0
var _yaw_velocity := 0.0
var _elev := deg_to_rad(49.5)
var _goal_elev := deg_to_rad(49.5)
var _cam_yaw := {}
var _cam_elev := {}
var _goal_distance := 12.5
var _pan_velocity := Vector3.ZERO
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
}
const GATE_WORDS := {
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


func _ready() -> void:
	_rng.seed = 20261008
	_build_world()
	_build_ground()
	_build_backdrop()
	_build_props()
	_build_grass()
	_spawn_pets()
	_leaf_litter()
	_build_ambience()
	_build_tilt_shift()
	game = preload("res://scripts/garden/garden_game.gd").new()
	game.name = "Game"
	add_child(game)
	game.setup(self)
	_place_camera()


# ------------------------------------------------------------------ world
func _build_world() -> void:
	var p := CharacterArtProfile.gerald()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7b37a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = 0.36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true                               # a little air between the near and far garden
	env.fog_light_color = Color("a7b37a")
	env.fog_density = 0.01
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = p.key_color
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.shadow_opacity = 0.72                          # tree shade, not a hole in the lawn
	sun.directional_shadow_max_distance = 60.0
	sun.rotation_degrees = p.key_angle
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
	var dir := Vector3(sin(_yaw) * cos(_elev), sin(_elev), cos(_yaw) * cos(_elev))
	camera.position = CENTER + dir * _distance
	camera.look_at(CENTER, Vector3.UP)


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
	var detail := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/lawn_detail.png"))
	detail.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/lawn.gdshader")
	m.set_shader_parameter("macro", ImageTexture.create_from_image(img))
	m.set_shader_parameter("detail", ImageTexture.create_from_image(detail))
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
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % sheet))
	var normals := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s_n.png" % sheet))
	image.generate_mipmaps()
	normals.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/leaf.gdshader")
	m.set_shader_parameter("leaf_sheet", ImageTexture.create_from_image(image))
	m.set_shader_parameter("leaf_normals", ImageTexture.create_from_image(normals))
	m.set_shader_parameter("interior_ink", 0.2)
	m.set_shader_parameter("silhouette_ink", 0.5)
	_leaf_mats[sheet] = m
	return m


## A leafy mass (hedge, tree crown, leaf pile) grown with the pets' foliage system.
func _bush(center: Vector3, radii: Vector3, sheet: String, palette: Dictionary, inner: Color, leaf_size: float, density: float, shape: Variant = {}, flowering := 0.0) -> Node3D:
	var p := CharacterArtProfile.new()
	p.seed = _rng.randi()
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
	var holder := Node3D.new()
	add_child(holder)
	var mass := MeshInstance3D.new()
	mass.mesh = HedgeAnatomy.build_mesh(p.regions["BODY"], 16, 28)
	mass.position = center
	mass.scale = Vector3.ONE * 0.96
	mass.material_override = GardenProps.mat("inner%s" % inner.to_html(), inner)
	holder.add_child(mass)
	var built := FoliageBuilder.build(p, "BODY", Vector3(0, -100, 0), Vector3(0.5, -0.8, 0.3).normalized())
	var items: Array = built["items"]
	var mm := MultiMesh.new()
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
	GardenProps.house(south, Vector3(0.0, 0, 18.5), 0.0, Color("c8a050"), Vector3(9.0, 5.5, 7.0), true, r)
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
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/hedgemaple.png"))
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
func _tree(at: Vector3, height: float, palette: Dictionary, sheet := "hedgeoak") -> void:
	var bark := GardenProps.mat("bark", Color("5c4634"))
	var lean := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	var top := at + Vector3(0, height * 0.62, 0) + lean
	_limb(at, top, 0.55, 0.3, bark).name = "Trunk"
	_limb(at + Vector3(0, 0.2, 0), at + Vector3(0.9, 0.0, 0.3), 0.3, 0.12, bark)       # a root
	_limb(at + Vector3(0, 0.2, 0), at + Vector3(-0.6, 0.0, -0.7), 0.28, 0.1, bark)
	var n := 5
	for i in range(n):
		var a := TAU * float(i) / float(n) + _rng.randf_range(-0.4, 0.4)
		var from := at.lerp(top, _rng.randf_range(0.55, 0.95))
		var reach := _rng.randf_range(2.2, 3.6)
		var to := from + Vector3(cos(a) * reach, _rng.randf_range(1.6, 3.2), sin(a) * reach)
		_limb(from, to, 0.24, 0.08, bark)
		var twig := to + Vector3(cos(a + 0.8) * 0.9, 0.7, sin(a + 0.8) * 0.9)
		_limb(to, twig, 0.08, 0.03, bark)
		var r := _rng.randf_range(1.6, 2.3)
		_bush(to + Vector3(0, 0.6, 0), Vector3(r, r * 0.72, r), sheet, palette, Color(palette["deep_forest"]).darkened(0.2), 0.8, 0.5, "egg")
	_bush(top + Vector3(0, 2.6, 0), Vector3(2.6, 2.0, 2.6), sheet, palette, Color(palette["deep_forest"]).darkened(0.2), 0.85, 0.5, "egg")
	_crowns.append(top + Vector3(0, 1.5, 0))
	obstacles.append([Vector2(at.x, at.z), 1.0])


## A pine: a straight thin trunk and tiers of needles, wide at the bottom, narrowing to a point.
func _pine(at: Vector3, height: float) -> void:
	var pine := {"deep_forest": Color("1c3529"), "muted_ivy": Color("28493a"), "matcha": Color("3b6046"),
		"warm_yellow_green": Color("557349"), "soft_sage": Color("4f6b5e"), "pale_highlight": Color("7f9a7c")}
	_limb(at, at + Vector3(0, height, 0), 0.4, 0.08, GardenProps.mat("pinebark", Color("4e3a2c"))).name = "Trunk"
	var tiers := 5
	for i in range(tiers):
		var t := float(i) / float(tiers - 1)
		var y := lerpf(height * 0.28, height * 0.9, t)
		var r := lerpf(3.0, 0.9, t) * height / 12.0 * _rng.randf_range(0.82, 1.12)
		var off := Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.35, 0.35))
		_bush(at + Vector3(0, y, 0) + off, Vector3(r, r * _rng.randf_range(0.48, 0.62), r * _rng.randf_range(0.85, 1.0)), "hedgepine", pine, Color("1d3326"), 0.8, 0.55,
			{"exponent": 2.0, "taper": -0.75, "taper_axis": "y", "flat_bottom": 0.5})
	obstacles.append([Vector2(at.x, at.z), 0.7])


var _crowns: Array = []                           # broadleaf crowns: where falling leaves come from


## Life in the garden: leaves drifting down from the oaks, butterflies over the lawn.
func _build_ambience() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/hedgemaple.png"))
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
	GardenProps.bake_static(GardenProps.broken_fence(self, -16.0, 16.0, -11.0, r, Vector2(0.5, 4.5)))
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
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/grass.png"))
	image.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grass.gdshader")
	m.set_shader_parameter("grass_sheet", ImageTexture.create_from_image(image))
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
	var items: Array = []
	for i in range(22000):
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
	mm.instance_count = items.size()
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
		mm.set_instance_custom_data(i, items[i][2])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.name = "Grass"
	add_child(node)


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
			if was == "away":
				node.position = g["out"].lerp(g["peek"], 0.55) + side * _rng.randf_range(-1.0, 1.0)
				Motion.appear(node, Vector3.ONE * PET_SCALE, Motion.SLOW)
			w["target"] = g["peek"] + side * _rng.randf_range(-1.2, 1.2)
		"roam":
			if was == "away":
				Motion.appear(node, Vector3.ONE * PET_SCALE, Motion.SLOW)
				node.position = g["peek"].lerp(g["inside"], 0.5)
				if at_once:                              # already living here when the garden opens
					for k in range(20):
						var spot := Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-2, 3))
						if not _blocked(spot, 0.8):
							node.position = Vector3(spot.x, 0, spot.y)
							break
			w["target"] = g["inside"] + side * _rng.randf_range(-1.0, 1.0)
			w["wait"] = 0.5
		"leave":
			w["target"] = g["out"].lerp(g["peek"], 0.2)


func pet_mode(node: HedgePetNode) -> String:
	return _wander[node]["mode"]


func _process(delta: float) -> void:
	for node in pets:
		_walk(node, delta)
	if _press_at == Vector2.INF and absf(_yaw_velocity) > 0.001:     # keep turning a little after a fling
		_goal_yaw += _yaw_velocity * delta
		_yaw_velocity *= pow(0.04, delta)
	_yaw = Motion.spring(_yaw, _goal_yaw, _cam_yaw, 0.07 if _dragged else 0.45, delta)   # tight under a finger, unhurried otherwise
	_elev = Motion.spring(_elev, _goal_elev, _cam_elev, 0.1 if _dragged else 0.25, delta)
	_distance = Motion.spring(_distance, _goal_distance, _cam_zoom, 0.16, delta)
	_place_camera()


func _clamp_target(t: Vector3) -> Vector3:
	return Vector3(clampf(t.x, -12.0, 12.0), 0.0, clampf(t.z, -9.0, 8.0))


## Wander: stand a while, look around, pick a free spot, walk there with a little step, turning to face the way.
func _walk(node: HedgePetNode, delta: float) -> void:
	var w: Dictionary = _wander[node]
	if w["mode"] == "away":
		return
	var to: Vector3 = w["target"] - node.position
	to.y = 0.0
	if to.length() < 0.15:
		node.walking = move_toward(node.walking, 0.0, delta * 3.0)
		if w["mode"] == "peek":
			node.rotation.y = lerp_angle(node.rotation.y, _heading(node.position, CENTER), clampf(delta * 3.0, 0.0, 1.0))   # looking in
			return
		if w["mode"] == "leave":
			set_pet_mode(node, "away")
			return
		w["wait"] = float(w["wait"]) - delta
		# standing: turn three-quarters toward the viewer, so you see faces, not backs
		var face: float = w.get("face", 0.0)
		node.rotation.y = lerp_angle(node.rotation.y, _heading(node.position, camera.position) + face, clampf(delta * 2.0, 0.0, 1.0))
		if w.get("fav", "") != "":
			emote(node, str(w["fav"]))                   # got to a favourite thing: enjoy it
			w["fav"] = ""
		if float(w["wait"]) <= 0.0:
			var fav: Dictionary = game.favourite(node) if game != null and _rng.randf() < 0.55 else {}
			if not fav.is_empty():
				var at: Vector3 = fav["at"]
				var off := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * (float(fav["radius"]) + 0.45)
				var spot := Vector2(at.x + off.x, at.z + off.z)
				if BOUNDS.has_point(spot) and not _path_blocked(Vector2(node.position.x, node.position.z), spot):
					w["target"] = Vector3(spot.x, 0, spot.y)
					w["fav"] = fav["emote"]
					w["wait"] = _rng.randf_range(5.0, 10.0)
					w["face"] = _rng.randf_range(-0.9, 0.9)
					return
			for attempt in range(12):
				var p := Vector2(_rng.randf_range(BOUNDS.position.x, BOUNDS.end.x), _rng.randf_range(BOUNDS.position.y, BOUNDS.end.y))
				if not _blocked(p, 0.9) and not _path_blocked(Vector2(node.position.x, node.position.z), p):
					w["target"] = Vector3(p.x, 0, p.y)
					break
			w["wait"] = _rng.randf_range(2.0, 6.0)
			w["face"] = [-0.8, 0.8].pick_random() + _rng.randf_range(-0.3, 0.3)
		return
	var speed := 1.1 * (0.6 if node.profile.species == "tortoise" else 1.0)
	var heading := atan2(-to.z, to.x)
	node.rotation.y = lerp_angle(node.rotation.y, heading, clampf(delta * 4.0, 0.0, 1.0))
	if absf(angle_difference(node.rotation.y, heading)) < 0.6:
		node.position += to.normalized() * minf(speed * delta, to.length())
		node.walking = move_toward(node.walking, 1.0, delta * 3.0)
	else:
		node.walking = move_toward(node.walking, 0.3, delta * 3.0)


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


## The yaw that points a pet (it faces +x) from `from` toward `to`.
func _heading(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.z - from.z), to.x - from.x)


func _path_blocked(a: Vector2, b: Vector2) -> bool:
	for k in range(1, 8):
		if _blocked(a.lerp(b, float(k) / 8.0), 0.7):
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
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_goal_distance = clampf(_goal_distance / event.factor, 8.0, 24.0)
		return
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_goal_distance = clampf(_goal_distance * (0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.12), 8.0, 24.0)
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if pressed:
		_press_at = event.position
		_dragged = false
		_yaw_velocity = 0.0
	elif released and _press_at != Vector2.INF:
		if not _dragged:
			_tap(event.position)
		_press_at = Vector2.INF
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _press_at != Vector2.INF:
		if event.position.distance_to(_press_at) > 10.0:
			_dragged = true
		if _dragged:
			var turn: float = -event.relative.x * 0.006
			_goal_yaw += turn
			_yaw_velocity = lerpf(_yaw_velocity, turn * 60.0, 0.5)
			_goal_elev = clampf(_goal_elev + event.relative.y * 0.003, deg_to_rad(28), deg_to_rad(72))


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
