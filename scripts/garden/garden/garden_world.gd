extends "res://scripts/garden/garden/garden_plants.gd"

## Garden 4/6 - the world around the yard: the ground, the backdrop, the surroundings, the west woods, grass, props, ambience.
##
## Builds the yard and what surrounds it, step by step (BUILD_STEPS in garden.gd calls these by name): the ground and
## lawn, the backdrop (the woods wall, the burying ground, the neighbours), props, ambience, and the grass. Grass is a
## texture on the lawn plus 3D tufts only where it grows long (_tuft_kept): full 3D grass would not hold 30 fps on a
## phone. The tilt-shift is the miniature-on-a-table look.
##
## Part of the garden layer chain (the full order is at the top of scripts/garden/garden.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var _bald_noise: FastNoiseLite


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
	neighborhood = preload("res://scripts/garden/neighborhood.gd").new()   # beyond the back fence: a 1:16 skybox
	add_child(neighborhood)
	neighborhood.setup(self)
	env.background_mode = Environment.BG_SKY
	env.sky = neighborhood.sky_for_woods(Color("a7b37a"), 1.4)
	env.fog_sky_affect = 0.0                             # (the miniature has the garden's fog of its own)
	neighborhood.show_land(true)
	_env = env
	_fog_goal = fog_at(_hour())
	_apply_fog(_fog_goal)                                # the day's weather (weather())
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.87, 0.68)                 # afternoon: low, warm, long shadows
	sun.light_energy = 0.72
	sun.shadow_enabled = false
	sun.shadow_blur = 2.5
	sun.shadow_opacity = 0.72                          # tree shade, not a hole in the lawn
	# Static foliage is deliberately not a shadow caster (see _bush below). Keep one short split for
	# the large trunks, fence and house: the contact blobs and the lawn's painted dapple carry the soft
	# miniature shade farther out without paying for two complete caster passes.
	sun.directional_shadow_max_distance = 28.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
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
	m.set_shader_parameter("shadow_map", _baked_shadow("res://assets/baked/shadows_garden.png"))
	m.set_shader_parameter("shadow_bounds", Vector4(-32.0, -20.0, 32.0, 24.0))
	# the lawn stops just behind the back fence: past it is the neighbourhood skybox (its own yards and street) - but
	# the creek's woods, the trees east and the white house's own yard stand on real ground. Real things are always
	# drawn over the skybox, so no real ground may lie behind anything in it (next door's houses, sheds, trees): the
	# pieces west and east stop short of next door's yards.
	for piece: Array in [[Vector2(-80, -80), Vector2(80, 11.5)], [Vector2(-80, 11.5), Vector2(-18.0, 16.5)],
			[Vector2(19.0, 11.5), Vector2(80, 14.0)], [Vector2(-6.4, 11.5), Vector2(6.4, 26.0)]]:
		var lo: Vector2 = piece[0]
		var hi: Vector2 = piece[1]
		var plane := PlaneMesh.new()
		plane.size = hi - lo
		var ground := MeshInstance3D.new()
		ground.mesh = plane
		ground.material_override = m
		ground.name = "Lawn"
		ground.position = Vector3((lo.x + hi.x) * 0.5, 0, (lo.y + hi.y) * 0.5)
		add_child(ground)
	_bald_noise = big


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
	_merge_limbs()


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
	GardenProps.creek(self, _creek_x, -32.0, CREEK_END, 2.6)   # (past the fence line it runs on in the skybox)
	var bz: float = GATES["creek"]["peek"].z
	GardenProps.footbridge(west, Vector3(_creek_x(bz) - 2.3, 0, bz), Vector3(_creek_x(bz) + 2.3, 0, bz), r)
	for k in range(14):
		var z := r.randf_range(-24, 18)
		if absf(z - bz) < 2.0:
			continue
		var side := 1.0 if r.randf() < 0.5 else -1.0
		var cat := Vector3(_creek_x(z) + side * r.randf_range(1.2, 1.7), 0, z)
		if z < CREEK_END:
			GardenProps.cattails(west, cat, r)
		else:                                            # (past the fence: made the same and dropped - the same numbers)
			var dropped := Node3D.new()
			GardenProps.cattails(dropped, cat, r)
			dropped.free()
	for k in range(12):
		var z := r.randf_range(-26, 20)
		var rock := Vector3(_creek_x(z) + r.randf_range(-1.5, 1.5), 0, z)
		var size := r.randf_range(0.2, 0.45)
		if z < CREEK_END:
			GardenProps.rock(west, rock, size, r)
		else:
			var dropped := Node3D.new()
			GardenProps.rock(dropped, rock, size, r)
			dropped.free()
	GardenProps.bake_static(west)
	for k in range(4):
		var pz := -20.0 + k * 11.0
		if absf(pz - bz) < 3.0:
			pz = bz - 3.4                                    # not in the way of the trail off the bridge
		_pine(Vector3(_creek_x(-20.0 + k * 11.0) - r.randf_range(4.0, 7.0), 0, pz), r.randf_range(10.0, 13.0))
	_west_woods(bz)
	# south: the houses, backs to the garden, and a picket fence with the garden gate standing open
	var south := Node3D.new()
	south.name = "Houses"
	add_child(south)
	var gx: float = GATES["houses"]["peek"].x
	GardenProps.broken_fence(south, -16.0, 16.0, 10.0, r, Vector2(gx - 1.1, gx + 1.1))
	# the houses next door are in the neighbourhood skybox (neighborhood.gd); built here only to draw the same random
	# numbers as ever (so nothing else in the garden moves), then let go
	var gone := Node3D.new()
	GardenProps.house(gone, Vector3(-12.5, 0, 20.0), 0.0, Color("e8e2d2"), Vector3(8.0, 5.0, 6.5), false, r)
	GardenProps.house(south, Vector3(0.0, 0, GREG_Z), 0.0, Color("eeeae0"), Vector3(9.0, 5.5, 7.0), true, r, Color("3a5a8a"), gx)   # white siding, blue door: real (he comes and goes); set back so the stairs land in his yard, not the fence
	GardenProps.house(gone, Vector3(12.5, 0, 20.5), 0.0, Color("8a3a2a"), Vector3(8.0, 5.0, 6.5), false, r)
	gone.free()
	var stone := GardenProps.mat("flagstone", Color("9a968a"))
	for k in range(3):                                   # flagstones from the foot of his stairs to the gate
		GardenProps.part(south, GardenProps.cyl(0.32, 0.34, 0.05, 7), stone, Vector3(gx + (k % 2) * 0.12 - 0.06, 0.02, 10.9 + k * 0.62), Vector3(0, k * 40, 0), 0.006)
	GardenProps.bake_static(south)
	GardenProps.open_gate(self, Vector3(gx + 1.1, 0, 10.0), 2.1, 115.0)
	var watcher: Node3D = preload("res://scripts/garden/porch_watcher.gd").new()   # the man on the porch
	add_child(watcher)
	watcher.setup(self, Vector3(0.0, 0, GREG_Z))
	# east: woods past the stone wall, through the gap in it
	for k in range(12):
		var at := Vector3(r.randf_range(12.0, 28.0), 0, r.randf_range(-24.0, 16.0))
		if absf(at.z - GATES["woods"]["peek"].z) < 2.5 and at.x < 20.0:
			continue                                           # keep the woods path open
		if k % 3 == 0:
			_tree(at, r.randf_range(10.0, 13.0), SpeciesBuilder.palette_of(["autumn", "green", "crimson"][k % 3]), ["hedgeoak", "hedgemaple"][k % 2])
		else:
			_pine(at, r.randf_range(10.0, 15.0))


## Across the creek the woods begin: the same oaks, maples and pines as on the trails, close together, with a worn
## trail leading in from the footbridge (the way to the woods). Its own random numbers, so nothing in the garden moves.
func _west_woods(bz: float) -> void:
	var keep := _rng
	var crowns := _crowns.size()                          # (their crowns don't drop leaves on the lawn: litter stays as it was)
	var obstacles_before := obstacles.size()              # (and they're past the creek: no pet or grass tuft goes there)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 1914
	var x0 := _creek_x(bz) - 2.4                              # the bridge's far end
	var placed: Array = []
	for t in range(900):
		if placed.size() >= 26:
			break
		var p := Vector2(_rng.randf_range(-36.0, -19.4), _rng.randf_range(-27.0, 21.0))
		if p.x > _creek_x(p.y) - 2.4:
			continue                                          # off the bank
		if absf(p.y - _trail_z(p.x, bz)) < 2.7 and p.x > x0 - 20.0:
			continue                                          # the trail stays open
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < 3.4):
			continue
		placed.append(p)
	for i in placed.size():
		var p: Vector2 = placed[i]
		var far := p.x < -26.5
		if _rng.randf() < 0.45:
			_pine(Vector3(p.x, 0, p.y), _rng.randf_range(10.5, 14.0), far)
		else:
			_tree(Vector3(p.x, 0, p.y), _rng.randf_range(9.5, 12.5), SpeciesBuilder.palette_of(["autumn", "green", "crimson", "autumn"][i % 4]), ["hedgeoak", "hedgemaple"][i % 2], far)
	_woods_trail(x0, bz)
	_crowns.resize(crowns)
	obstacles.resize(obstacles_before)
	_rng = keep


## The worn trail from the bridge into the trees: bare earth, soft-edged, fading as it goes in.
func _woods_trail(x0: float, bz: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev: Array = []
	var steps := 28
	for i in range(steps + 1):
		var x := x0 + 0.3 - i * 0.6
		var z := _trail_z(x, bz)
		var fade := 1.0 - smoothstep(0.55, 1.0, float(i) / steps)
		var w := 0.85 + 0.15 * sin(i * 1.7)
		var row := [[Vector3(x, 0.02, z - w * 1.6), 0.0], [Vector3(x, 0.02, z - w * 0.6), fade], [Vector3(x, 0.02, z + w * 0.6), fade], [Vector3(x, 0.02, z + w * 1.6), 0.0]]
		if not prev.is_empty():
			for k in range(3):
				for v: Array in [prev[k], row[k], row[k + 1], prev[k], row[k + 1], prev[k + 1]]:
					st.set_color(Color(1, 1, 1, float(v[1]) * 0.85))
					st.set_normal(Vector3.UP)
					st.add_vertex(v[0])
		prev = row
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("6b5a40")
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.metallic_specular = 0.0
	var node := MeshInstance3D.new()
	node.name = "WoodsTrail"
	node.mesh = st.commit()
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


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
		var behind_houses := at.z > 24.0                  # (past next door: they go into the skybox, below)
		var before := get_child_count()
		var gate_path: bool = (absf(at.z - GATES["woods"]["peek"].z) < 3.0 and at.x < 26.0 and at.x > 9.0) \
			or (absf(at.z - GATES["creek"]["peek"].z) < 3.0 and at.x < -18.0) or (at.x > -0.5 and at.x < 5.5 and at.z > -20.0)
		if gate_path:
			continue
		var h := r.randf_range(15.0, 22.0)
		_limbs_loose = behind_houses
		if r.randf() < 0.45:
			_pine(at, h, true)
		else:
			_tree(at, h, palettes[r.randi() % palettes.size()], ["hedgeoak", "hedgemaple"][r.randi() % 2], true)
		_limbs_loose = false
		if behind_houses:                                 # real things draw over the skybox: these stand behind next door's
			var made: Array = []                          # houses, so they're moved into it (built the same, same numbers)
			for i in range(before, get_child_count()):
				made.append(get_child(i))
			for n: Node3D in made:
				neighborhood.adopt(n)


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
	# calico aster gone wild: along the old fence, inside the burying ground's wall, by the field wall
	var wild := [Vector3(-6.4, 0, -10.6), Vector3(-9.6, 0, -10.4), Vector3(4.4, 0, -10.7), Vector3(6.5, 0, -9.2),
		Vector3(7.0, 0, -6.6), Vector3(-3.0, 0, -13.3), Vector3(-8.6, 0, -13.4), Vector3(-14.2, 0, -13.6)]
	for i in range(wild.size()):
		aster_clump(self, wild[i], 4400 + i)
		wild_asters.append(wild[i])


var wild_asters: Array = []                        # where the garden's clumps are (butterflies visit them)


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
	out.append_array(wild_asters.filter(func(a: Vector3) -> bool: return a.z > -11.0))   # the late nectar
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
	_thing("ironing_board", GardenProps.bake_static(GardenProps.ironing_board(self, Vector3(-4.4, 0, 5.4), 115.0)), Vector2(-4.4, 5.4), 0.7, 0, false)
	_thing("brush_pile", GardenProps.brush_pile(self, Vector3(5.6, 0, -8.6), r), Vector2(5.6, -8.6), 1.2, 0, false)
	# places to hide: a paint bucket by the gate, a big pot, the old well, the burrow behind the corner tree
	_thing("bucket", GardenProps.paint_bucket(self, Vector3(5.2, 0, 7.0), 30.0), Vector2(5.2, 7.0), 0.4, 0, false)
	_thing("planter", GardenProps.pot_upright(self, Vector3(-3.6, 0, -7.6)), Vector2(-3.6, -7.6), 0.55, 0, false)
	_thing("well", GardenProps.bake_static(GardenProps.stone_well(self, Vector3(-7.4, 0, -8.8), r)), Vector2(-7.4, -8.8), 1.15, 0, false)
	_thing("burrow", GardenProps.burrow(self, BURROW_AT, 20.0, r), Vector2(BURROW_AT.x, BURROW_AT.z), 0.9, 0, false)
	for at: Array in [[Vector3(-9.0, 0, -5.8), 0.55], [Vector3(-8.2, 0, -5.2), 0.35], [Vector3(10.2, 0, 3.4), 0.7], [Vector3(9.3, 0, 4.2), 0.4], [Vector3(0.5, 0, 7.6), 0.45]]:
		_thing("rock", GardenProps.rock(self, at[0], at[1], r), Vector2(at[0].x, at[0].z), float(at[1]) + 0.4, 1)


## Grass tufts and weeds over the lawn, thinner on the bald spots, none under the junk.
func _build_grass() -> void:
	var image := Assets.image("res://assets/sprites/grass.png")
	image.generate_mipmaps()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grass.gdshader")
	m.set_shader_parameter("grass_sheet", ImageTexture.create_from_image(image))
	m.set_shader_parameter("dapple", load("res://assets/sprites/dapple.png"))
	m.set_shader_parameter("shadow_map", _baked_shadow("res://assets/baked/shadows_garden.png"))
	m.set_shader_parameter("shadow_bounds", Vector4(-32.0, -20.0, 32.0, 24.0))
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
	# always places them live, so a change here shows at once; the bake (tools/bake/bake_cache.gd) records them.
	var cached := BakeCache.recording or BakeCache.live_salt() == ""
	var key := BakeCache.key(["grass", 4, _rng.state, _grass_inputs()])
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
		var custom := Color(float(cell), _rng.randf_range(0, TAU), 0, 0)
		var keep := _tuft_kept(x, z, cell)               # (after every draw: the RNG ends where it always did)
		if keep > 0.0:
			items.append([t.scaled_local(Vector3(keep, keep, keep)), tint, custom])
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
		var custom := Color(float(cell), _rng.randf_range(0, TAU), 0, 0)
		if _hash01(p.x, p.y) < 0.35:                     # the long grass at the fences: a third as many, still a band
			items.append([t, tint, custom])


## The lawn is a texture (shaders/lawn.gdshader); 3D tufts only where grass grows long: patches the mower misses,
## round the things in the yard, a few flowers. 0 = not here, else the tuft's scale (patch grass grows taller).
var _tall_noise: FastNoiseLite


func _tuft_kept(x: float, z: float, cell: int) -> float:
	if _tall_noise == null:
		_tall_noise = FastNoiseLite.new()
		_tall_noise.seed = 4242
		_tall_noise.frequency = 0.16
	var patch := _tall_noise.get_noise_2d(x, z)
	if patch > 0.08:
		return 1.2 + clampf(patch - 0.08, 0.0, 0.3) * 1.6           # taller toward the middle of a patch
	for t in things:
		if t["kind"] != "stick" and Vector2(x, z).distance_to(t["at"]) < float(t["radius"]) + 0.55:
			return 1.1
	if cell >= 8 and cell <= 10:
		return 1.0 if _hash01(x, z) < 0.45 else 0.0
	return 1.0 if _hash01(x, z) < 0.05 else 0.0


func _blocked(p: Vector2, margin: float) -> bool:
	for o in obstacles:
		if p.distance_to(o[0]) < float(o[1]) + margin:
			return true
	for t in things:
		if t["kind"] != "stick" and p.distance_to(t["at"]) < float(t["radius"]) + margin:
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
	Quality.apply_current()
