extends Node

## The land beyond the woods, as a 1:16 miniature in its own world (the "3D skybox" of the Source engine's sky_camera):
## a SubViewport holds the model and a camera that copies the woods camera - same turn, same field of view, its
## position divided by SCALE - so walking a trail gives true parallax: near hills slide, far mountains barely move.
## Its picture becomes the woods' sky (shaders/distant_sky.gdshader projects each sky direction through the matched
## camera to find its pixel), drawn per pixel behind
## everything in the woods, so the two worlds never share a depth buffer. (A canvas background, the first try, drew
## over the 3D in the Compatibility renderer.)
##
## The model: rolling New England hills under forest, a valley to the east-northeast (the ridge's view) with a lake,
## an island, farm fields and a white village with a church steeple; landmarks you can find again from different
## clearings - THE MOUNTAIN (a granite dome with a bare summit) out past the ridge, the twin peaks to the north, the
## long ridge to the west with its fire tower - and a blue far range all round. Clouds, haze, the sun where the
## woods' sun is. Everything near the middle sits low, under the woods' own ground (which is drawn over it).
## Built once (fixed seeds); rendered at RES of the screen; only while you're in the woods.

const SCALE := 16.0
const RES := 0.6                                    # of the screen's resolution

var view: SubViewport
var sky_cam: Camera3D
var _clouds: Array = []
var _noise: FastNoiseLite
var _hills: FastNoiseLite
var _forest_noise: FastNoiseLite
var _forest_cluster: FastNoiseLite
var _t := 0.0
var _sky_mat: ShaderMaterial

## Landmarks, in sky units (metres / SCALE) from the woods' origin: [x, z, height, radius, kind]
const PEAKS := [
	[205.0, -150.0, 40.0, 55.0, "mountain"],         # out past the ridge, a little north: the one you'll recognise
	[-40.0, -300.0, 31.0, 40.0, "twin"],             # the twin peaks, north
	[-10.0, -318.0, 28.0, 34.0, "twin"],
	[-230.0, -70.0, 19.0, 70.0, "ridge"],            # the long ridge, west (the fire tower's on it)
	[60.0, 230.0, 14.0, 60.0, "hill"],               # behind the houses, south
	[-160.0, 190.0, 16.0, 55.0, "hill"],
]
const LAKE := Vector2(95.0, -40.0)                  # in the valley the ridge looks over
const LAKE_R := 22.0
const VILLAGE := Vector2(122.0, -18.0)
## A make-believe garden far off in the valley (seen from the ridge): the white house with the blue door, its
## neighbours, the lawn, the picket fence, the creek and its little bridge, a few autumn trees - a toy, not the real one.
const TOY_GARDEN := Vector2(180.0, -132.0)             # on a shelf high on the mountain, in the ridge's view (~3 km)
const TOY_SCALE := 5.0
var _toy_y := INF                                  # bigger than life: a make-believe garden you can pick out


var _woods: Node3D


func setup(woods: Node3D, to_sun: Vector3, compiled_world: Node3D = null) -> void:
	name = "DistantLand"
	_woods = woods
	_noise = FastNoiseLite.new()
	_noise.seed = 1716
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_hills = FastNoiseLite.new()
	_hills.seed = 1717
	_hills.frequency = 0.045
	_forest_noise = FastNoiseLite.new()
	_forest_noise.seed = 271828
	_forest_noise.frequency = 0.024
	_forest_noise.fractal_octaves = 3
	_forest_cluster = FastNoiseLite.new()
	_forest_cluster.seed = 271829
	_forest_cluster.frequency = 0.075
	_forest_cluster.fractal_octaves = 2
	view = SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.positional_shadow_atlas_size = 0
	add_child(view)
	var world := compiled_world if compiled_world != null else Node3D.new()   # (compiled: terrain, forest, village... ready made)
	world.name = "World"
	view.add_child(world)
	sky_cam = Camera3D.new()
	sky_cam.near = 0.05
	sky_cam.far = 1400.0
	sky_cam.keep_aspect = Camera3D.KEEP_WIDTH
	sky_cam.environment = _environment()
	view.add_child(sky_cam)
	_toy_y = INF
	_toy_y = _own_height_raw(TOY_GARDEN.x, TOY_GARDEN.y)
	if compiled_world == null:
		var sun := DirectionalLight3D.new()
		sun.light_color = Color("ffe4b8")
		sun.light_energy = 1.1
		sun.shadow_enabled = false
		sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
		world.add_child(sun)
		await _terrain(world)
		_lake(world)
		await _forest(world)
		_village(world)
		_toy_garden(world)
		_fire_tower(world)
	_clouds_build(world)
	woods.get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var s := get_viewport().get_visible_rect().size
	view.size = Vector2i(maxi(64, int(s.x * RES)), maxi(64, int(s.y * RES)))


func show_land(on: bool) -> void:
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		_fit()


## Follow the woods camera: same turn and field of view, its position scaled down.
func follow(cam: Camera3D, local_pos: Vector3, delta: float) -> void:
	_t += delta
	sky_cam.position = local_pos / SCALE
	sky_cam.rotation = cam.rotation
	sky_cam.fov = cam.fov
	if _sky_mat != null:                              # how the woods' sky finds this picture's pixels
		var s := get_viewport().get_visible_rect().size
		_sky_mat.set_shader_parameter("view_inv", cam.global_basis.orthonormalized().transposed())
		_sky_mat.set_shader_parameter("tan_half_w", tan(deg_to_rad(cam.fov) * 0.5))
		_sky_mat.set_shader_parameter("aspect", s.x / maxf(s.y, 1.0))
	for c: Node3D in _clouds:
		c.position.x = c.get_meta("x0") + fmod(_t * 0.35 + c.get_meta("ph"), 120.0) - 60.0


## The woods' sky: this land's picture, behind everything.
func sky_for_woods() -> Sky:
	var m := ShaderMaterial.new()
	_sky_mat = m
	m.shader = preload("res://shaders/distant_sky.gdshader")
	m.set_shader_parameter("land", view.get_texture())
	var sky := Sky.new()
	sky.sky_material = m
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	return sky


func _environment() -> Environment:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5a86b4")
	sky.sky_horizon_color = Color("c4d4dc")
	sky.ground_bottom_color = Color("2c3c34")
	sky.ground_horizon_color = Color("8aa0ac")
	sky.sun_angle_max = 8.0
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a7088")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true                            # air between you and the hills: further = bluer, paler
	env.fog_light_color = Color("b2c4ce")
	env.fog_density = 0.0012                          # (the haze is baked into the colours; this only softens the horizon)
	env.fog_sky_affect = 0.0
	env.fog_height = -2.0
	env.fog_height_density = 0.08                     # and mist in the low ground
	return env


# ------------------------------------------------------------------ the land
## Ground height (sky units) at x, z. Low and flat under the woods; rolling hills further out; the valley; the peaks.
func height(x: float, z: float) -> float:
	var own := _own_height(x, z)
	if _woods == null:
		return own
	# by the woods, the miniature's ground IS the woods' ground (scaled), so nothing steps where the playable world ends
	var mx := x * SCALE
	var mz := z * SCALE
	var out := maxf(maxf(-62.0 - mx, mx - 64.0), maxf(-112.0 - mz, mz - 28.0))   # metres outside the woods' ground
	if out > 90.0:
		return own
	var t := smoothstep(0.0, 90.0, out)
	return lerpf(_woods.height(clampf(mx, -62.0, 64.0), clampf(mz, -112.0, 28.0)) / SCALE - 0.03, own, t)


func _own_height(x: float, z: float) -> float:
	var h := _own_height_raw(x, z)
	var e := _band(x, z, FORK_SKY, FORK_DIR)
	if e > 0.0:                                       # the long woods lie level, rising only very gently
		h = lerpf(h, -0.05 + (Vector2(x, z) - FORK_SKY).dot(FORK_DIR) * 0.012, e)
	var ep := _band(x, z, PINES_SKY, PINES_DIR)
	if ep > 0.0:                                      # and so do the pines beyond the flats
		var level: float = (_woods.height(36.0, -6.0) / SCALE - 0.03) if _woods != null else -0.05
		h = lerpf(h, level + (Vector2(x, z) - PINES_SKY).dot(PINES_DIR) * 0.008, ep)
	return h


func _own_height_raw(x: float, z: float) -> float:
	var r := Vector2(x, z + 2.6).length()             # from the middle of the woods
	var out := smoothstep(6.0, 30.0, r)
	var bumpy := lerpf(2.5, 9.0, smoothstep(60.0, 220.0, r))   # gentle near, bigger hills further off
	var h := -1.3 + out * (1.5 + _noise.get_noise_2d(x, z) * bumpy + _hills.get_noise_2d(x, z) * 1.6)
	var to_lake := Vector2(x, z).distance_to(LAKE)    # the valley the ridge looks over, the lake in it
	h = lerpf(h, -1.6, smoothstep(85.0, 35.0, to_lake))
	var view := Vector2(0.89, -0.456)                 # the ridge looks down this way: keep it open to the lake and the mountain
	var rv := Vector2(x - 1.4, z + 2.75)
	if rv.dot(view) > 0.0:
		var lat := absf(rv.dot(view.orthogonal()))
		h = lerpf(h, minf(h, -1.2), smoothstep(40.0 + rv.dot(view) * 0.35, 10.0, lat) * smoothstep(170.0, 120.0, rv.dot(view)))
	for p: Array in PEAKS:
		var d := Vector2(x - p[0], z - p[1]).length()
		var k: float = d / float(p[3])
		var shape := exp(-k * k * 2.2) if p[4] != "ridge" else exp(-pow(absf(x - p[0]) / (float(p[3]) * 0.45), 2.0) * 2.0) * exp(-pow((z - p[1]) / (float(p[3]) * 2.2), 2.0))
		h += float(p[2]) * shape
	var far := smoothstep(330.0, 470.0, r)            # the blue range at the edge of the world
	h += far * (22.0 + _noise.get_noise_2d(x * 0.6 + 300.0, z * 0.6) * 18.0)
	if _toy_y != INF:                                 # a level shelf for the toy garden
		h = lerpf(h, _toy_y, smoothstep(9.0 * TOY_SCALE, 5.0 * TOY_SCALE, Vector2(x, z).distance_to(TOY_GARDEN)))
	return h


func _terrain(world: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var seg := 144
	var radii: Array = [0.0]
	var r := 3.0
	while r < 520.0:
		radii.append(r)
		r *= 1.075
	for ri in radii.size():
		await Slicer.tick(self)
		var row: Array = []
		for si in range(seg):
			var a := si * TAU / seg
			var x: float = cos(a) * radii[ri]
			var z: float = sin(a) * radii[ri] - 2.6
			var y := height(x, z)
			row.append([Vector3(x, y, z), haze(_ground_colour(x, y, z), Vector2(x, z + 2.6).length() * SCALE)])
		rings.append(row)
	for ri in range(1, rings.size()):
		for si in range(seg):
			var a: Array = rings[ri - 1][si]
			var b: Array = rings[ri - 1][(si + 1) % seg]
			var c: Array = rings[ri][si]
			var d: Array = rings[ri][(si + 1) % seg]
			for v: Array in [a, c, d, a, d, b]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)


## Forest green on the hills, farm fields in the valley, bare granite up high, a little autumn in the trees.
func _ground_colour(x: float, y: float, z: float) -> Color:
	if _band(x, z, PINES_SKY, PINES_DIR) > 0.5:       # under the white pines: a floor of orange needles
		return Color("8a4a24").lerp(Color("a85e2c"), 0.5 + _hills.get_noise_2d(x * 3.0, z * 3.0))
	if _in_endless(x, z) > 0.5:                       # under the endless canopy: leaf litter in shade
		return Color("2a2418").lerp(Color("3a3020"), 0.5 + _hills.get_noise_2d(x * 3.0, z * 3.0))
	var forest := Color("1c3022").lerp(Color("26381f"), 0.5 + _hills.get_noise_2d(x * 2.0, z * 2.0))   # the floor under a canopy: deep shade
	var autumn := Color("8a5a2a").lerp(Color("a8682c"), 0.5 + _hills.get_noise_2d(x * 3.0 + 40.0, z * 3.0))
	var c := forest.lerp(autumn, clampf(_noise.get_noise_2d(x * 2.3 + 90.0, z * 2.3) * 2.2, 0.0, 0.55))
	var to_lake := Vector2(x, z).distance_to(LAKE)
	if to_lake < 70.0 and to_lake > LAKE_R + 2.0:     # fields: patchwork, some mown, some hay
		var cell := Vector2i(floori(x / 7.0), floori(z / 5.0))
		var pick := absi(hash(cell)) % 5
		if pick < 3:
			c = [Color("8a9a4c"), Color("b4a85a"), Color("6e8a3e")][pick]
	if y > 27.0:                                      # bare granite above the trees
		c = c.lerp(Color("9a968c"), smoothstep(27.0, 33.0, y))
	return c


func _lake(world: Node3D) -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("5a7a92")
	water.roughness = 0.04
	water.metallic_specular = 1.0
	water.metallic = 0.2
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = LAKE_R
	cyl.bottom_radius = LAKE_R
	cyl.height = 0.05
	cyl.radial_segments = 40
	disc.mesh = cyl
	disc.material_override = water
	disc.scale = Vector3(1.0, 1.0, 0.62)
	disc.rotation.y = 0.5
	disc.position = Vector3(LAKE.x, -1.45, LAKE.y)
	world.add_child(disc)
	var island := MeshInstance3D.new()                # an island with three pines on it
	island.mesh = GardenProps.blob(Vector3(2.4, 0.8, 1.8), {"exponent": 2.0}, 8, 12)
	island.material_override = GardenProps.mat("skyisland", Color("34502c"))
	island.position = Vector3(LAKE.x - 5.0, -1.45, LAKE.y + 2.0)
	world.add_child(island)


## Pines and broadleaf crowns over the hills: one multimesh, thinning to nothing where it's too far to tell.
func _forest(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1718
	var cones: Array = []
	var balls: Array = []
	var tries := 0
	while cones.size() + balls.size() < 5200 and tries < 30000:
		await Slicer.tick(self)
		tries += 1
		var a := rng.randf() * TAU
		var r := pow(rng.randf(), 0.7) * 300.0 + 12.0
		var x := cos(a) * r
		var z := sin(a) * r - 2.6
		var y := height(x, z)
		if y > 26.0 or Vector2(x, z).distance_to(LAKE) < 72.0 and Vector2(x, z).distance_to(LAKE) > LAKE_R - 6.0 and rng.randf() < 0.85:
			continue                                   # not on bare rock; few among the fields
		if Vector2(x, z).distance_to(LAKE) < LAKE_R:
			continue
		var s := rng.randf_range(0.5, 1.0) * (1.0 + r / 300.0)
		var col := Color("1e3624").lerp(Color("2e4a2c"), rng.randf())
		if rng.randf() < 0.5:
			cones.append([Transform3D(Basis().scaled(Vector3(s * 0.35, s * 1.1, s * 0.35)), Vector3(x, y + s * 0.5, z)), haze(col, r * SCALE)])
		else:
			var au := rng.randf() < 0.35
			balls.append([Transform3D(Basis().scaled(Vector3(s * 0.5, s * 0.42, s * 0.5)), Vector3(x, y + s * 0.3, z)), haze(Color("9a5a24").lerp(Color("b87a30"), rng.randf()) if au else col.lightened(0.08), r * SCALE)])
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 6
	ball.rings = 3
	for pair: Array in [[cone, cones], [ball, balls]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = pair[0]
		mm.instance_count = pair[1].size()
		for i in pair[1].size():
			mm.set_instance_transform(i, pair[1][i][0])
			mm.set_instance_color(i, pair[1][i][1])
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = m
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(node)
	await _dense_forest(world)
	await _near_forest(world)
	await _endless_woods(world)


## Looking into the woods from the mossy fork, the trees go on for ever: trunk behind trunk under one closed canopy,
## on level ground, fading into the blue. Spacing widens with distance (each tree covers the same few pixels), so
## a few thousand trunks reach kilometres. The view line is woods.FORK_VIEW from the fork.
const FORK_SKY := Vector2(2.0 / 16.0, -24.0 / 16.0)
const FORK_DIR := Vector2(-0.33, -0.944)


## The pine flats' long view (woods.gd PINES_VIEW): white pines on level, needle-orange ground, on for miles.
const PINES_SKY := Vector2(36.0 / 16.0, -6.0 / 16.0)
const PINES_DIR := Vector2(0.96, 0.28)


func _band(x: float, z: float, origin: Vector2, dir: Vector2) -> float:
	var d := Vector2(x, z) - origin
	var s := d.dot(dir)
	if s < 3.0:
		return 0.0
	var lat := absf(d.dot(dir.orthogonal()))
	return smoothstep(6.0 + s * 0.42, 2.0 + s * 0.3, lat) * smoothstep(3.0, 6.0, s)


func _in_endless(x: float, z: float) -> float:
	return maxf(_band(x, z, FORK_SKY, FORK_DIR), _band(x, z, PINES_SKY, PINES_DIR))


func _endless_woods(world: Node3D) -> void:
	await _endless_band(world, FORK_SKY, FORK_DIR, 314159, false)
	await _endless_band(world, PINES_SKY, PINES_DIR, 271, true)


func _endless_band(world: Node3D, origin: Vector2, dir: Vector2, seed: int, all_pine: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var trunks: Array = []
	var crowns: Array = []
	var firs: Array = []
	var s := 3.4
	while s < 380.0:
		await Slicer.tick(self)
		var step := 0.42 + s * 0.022
		var half := 6.0 + s * 0.42
		var lat := -half
		while lat < half:
			var p := origin + dir * (s + rng.randf_range(-0.5, 0.5) * step) + dir.orthogonal() * (lat + rng.randf_range(-0.5, 0.5) * step)
			lat += step
			var mx := p.x * SCALE
			var mz := p.y * SCALE
			if mx > -60.0 and mx < 62.0 and mz > -110.0 and mz < 26.0:
				continue                                  # the woods' own trees
			if rng.randf() < 0.12:
				continue
			var y := height(p.x, p.y)
			var metres := (p - origin).length() * SCALE
			var tall := rng.randf_range(2.4, 3.3)             # old growth: tall trunks, the canopy far overhead
			var girth := (0.06 + step * 0.06) * rng.randf_range(0.8, 1.3)   # far trunks a touch thicker: they still read
			trunks.append([Transform3D(Basis().scaled(Vector3(girth, tall, girth)), Vector3(p.x, y + tall * 0.5 - 0.05, p.y)), haze(Color("3e3026").lerp(Color("54443a"), rng.randf()), metres)])
			if all_pine or rng.randf() < 0.3:             # a hemlock or a pine among the hardwoods (all white pine past the flats)
				var w := rng.randf_range(0.4, 0.6) + step * 0.2
				firs.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(w, tall * 0.7, w)), Vector3(p.x, y + tall * 0.68, p.y)), haze(Color("1e3a2a").lerp(Color("2a4a32"), rng.randf()), metres)])
			else:                                         # the canopy: crowns overlapping into one ceiling
				var w := rng.randf_range(0.8, 1.2) + step * 0.5
				var c := Color("3a5a30").lerp(Color("a0602c"), clampf(rng.randf() * 1.4 - 0.4, 0.0, 1.0)).lerp(Color("2c4a2a"), 0.35)
				crowns.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(w, w * 0.45, w)), Vector3(p.x, y + tall * 0.95, p.y)), haze(c, metres)])
		s += step
	_forest_multimesh(world, _forest_trunk_mesh(), trunks, "EndlessTrunks")
	_forest_multimesh(world, _forest_cluster_mesh(0), crowns, "EndlessCanopy")
	_forest_multimesh(world, _forest_pine_mesh(true if all_pine else false), firs, "EndlessFirs")


## Right past the edge of the woods: the forest goes on, tree by tree - trunks you look between, crowns overlapping,
## stands of pine, drifts of autumn maple, birch on the hill, now and then a dead snag, a few clearings. Clustered by
## noise (never a grid), densest by the woods, thinning into the canopy layer beyond.
func _near_forest(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 160461
	var stand := FastNoiseLite.new()                  # what grows where: pine stands, maple drifts, birch on the high ground
	stand.seed = 160462
	stand.frequency = 0.06
	var gaps := FastNoiseLite.new()
	gaps.seed = 160463
	gaps.frequency = 0.09
	var crowns := [[], [], [], []]                    # broadleaf A, broadleaf B, birch, pine
	var trunks: Array = []
	var snags: Array = []
	var autumn := [Color("a8462a"), Color("c0602c"), Color("cf8a34"), Color("8a3a24"), Color("b07a2e")]
	var green := [Color("2e5232"), Color("3a6038"), Color("4a6a3c")]
	var pines := [Color("1c3e2c"), Color("244a32"), Color("2c5438")]
	var step := 1.25
	var reach := 44.0
	var n := int(reach / step)
	for ix in range(-n, n + 1):
		await Slicer.tick(self)
		for iz in range(-n, n + 1):
			var p := Vector2(ix * step + rng.randf_range(-0.5, 0.5) * step, iz * step - 2.6 + rng.randf_range(-0.5, 0.5) * step)
			var mx := p.x * SCALE
			var mz := p.y * SCALE
			if mx > -60.0 and mx < 62.0 and mz > -110.0 and mz < 26.0:
				continue                              # the woods themselves (their own trees)
			var r := p.length()
			if r > reach:
				continue
			var g := gaps.get_noise_2d(p.x, p.y)
			if g < -0.42 or rng.randf() > lerpf(0.92, 0.55, smoothstep(10.0, reach, r)) * smoothstep(-0.42, -0.2, g):
				continue                              # a clearing, or just a gap
			var y := height(p.x, p.y)
			if y > 24.0:
				continue
			var kind := stand.get_noise_2d(p.x, p.y)
			var tall := rng.randf_range(1.0, 1.7)
			var metres := r * SCALE
			var bark := haze(Color("4a3a2c").darkened(rng.randf() * 0.2), metres)
			if rng.randf() < 0.025:                   # a dead snag: grey, bare, tall
				snags.append([Transform3D(Basis().scaled(Vector3(0.05, tall * 1.1, 0.05)), Vector3(p.x, y + tall * 0.5, p.y)), haze(Color("8a8478"), metres)])
				continue
			if r < 16.0:                              # trunks only near: further off it's all canopy
				trunks.append([Transform3D(Basis().scaled(Vector3(0.045, tall * 0.62, 0.045)), Vector3(p.x, y + tall * 0.3, p.y)), bark])
			var yaw := rng.randf() * TAU
			var full := lerpf(1.0, 1.5, smoothstep(10.0, reach, r))   # crowns widen with distance till they touch
			if kind > 0.18:                           # a pine stand
				var w := rng.randf_range(0.38, 0.56) * full
				crowns[3].append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(w, tall * 0.95, w)), Vector3(p.x, y + tall * 0.62, p.y)), haze(pines[rng.randi_range(0, 2)], metres)])
			elif kind < -0.3 and y > 0.5:             # birch on the higher ground
				var w := rng.randf_range(0.32, 0.46) * full
				crowns[2].append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(w, w * 1.6, w)), Vector3(p.x, y + tall * 0.78, p.y)), haze(Color("c8a43a").lerp(Color("a89a4a"), rng.randf()), metres)])
			else:                                     # maple and oak: autumn drifts, some still green
				var w := rng.randf_range(0.5, 0.8) * full
				var c: Color = autumn[rng.randi_range(0, 4)] if absf(stand.get_noise_2d(p.x * 2.0 + 50.0, p.y * 2.0)) > 0.12 else green[rng.randi_range(0, 2)]
				crowns[rng.randi_range(0, 1)].append([Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.1, 0.1), yaw, 0)).scaled(Vector3(w, w * 0.7, w)), Vector3(p.x, y + tall * 0.72, p.y)), haze(c, metres)])
	_forest_multimesh(world, _forest_cluster_mesh(0), crowns[0], "NearBroadleafA")
	_forest_multimesh(world, _forest_cluster_mesh(1), crowns[1], "NearBroadleafB")
	_forest_multimesh(world, _forest_cluster_mesh(2), crowns[2], "NearBirch")
	_forest_multimesh(world, _forest_pine_mesh(false), crowns[3], "NearPine")
	_forest_multimesh(world, _forest_trunk_mesh(), trunks, "NearTrunks")
	_forest_multimesh(world, _forest_trunk_mesh(), snags, "NearSnags")
	print("distant land near forest: %d trees, %d snags" % [trunks.size(), snags.size()])


## The old cone-and-ball layer is deliberately kept as a far-horizon texture. This second layer is the woodland:
## jittered cells, noise-shaped clearings and several silhouette families make the miniature read as a living forest
## instead of a field of repeated decorations. It is static, has no collision or animation, and is six instanced draws.
func _dense_forest(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 272001
	var broad_a: Array = []
	var broad_b: Array = []
	var birch: Array = []
	var pine: Array = []
	var cedar: Array = []
	var trunks: Array = []
	var understory: Array = []
	var deadwood: Array = []
	var broad_palette := [Color("2a5036"), Color("386640"), Color("47744a"), Color("5d7c4f"), Color("806b39"), Color("9a7138")]
	var pine_palette := [Color("1f4935"), Color("2b5b41"), Color("386b48"), Color("487752")]
	var birch_palette := [Color("52704a"), Color("6d8250"), Color("87905a"), Color("9a7e49")]
	var trunk_palette := [Color("4a3a2b"), Color("57432f"), Color("624e38"), Color("6a573d")]
	var cell := 7.2
	var cells := 64
	for ix in range(-cells, cells + 1):
		await Slicer.tick(self)
		for iz in range(-cells, cells + 1):
			var p := Vector2((float(ix) + rng.randf_range(-0.46, 0.46)) * cell, (float(iz) + rng.randf_range(-0.46, 0.46)) * cell - 2.6)
			var radius := p.length()
			if radius < 6.5 or radius > 455.0:
				continue
			var y := height(p.x, p.y)
			if y > 28.0:
				continue
			var lake_distance := p.distance_to(LAKE)
			if lake_distance < LAKE_R + 3.0:
				continue
			var density := lerpf(0.82, 0.38, smoothstep(25.0, 430.0, radius))
			var cluster := (_forest_noise.get_noise_2d(p.x, p.y) + 1.0) * 0.5
			var clearing := smoothstep(0.08, 0.56, cluster)
			density *= lerpf(0.38, 1.0, clearing)
			# Keep the ridge's named valley open, but let the forest close in again at its far rim.
			var rv := p - Vector2(22.0, -44.0)
			var valley_forward := rv.dot(Vector2(0.89, -0.456))
			var valley_side := absf(rv.dot(Vector2(0.456, 0.89)))
			var valley_window := smoothstep(18.0, 42.0, valley_side) * smoothstep(18.0, 185.0, valley_forward)
			density *= lerpf(1.0, 0.22, valley_window)
			# The two woodland compositions look into the north bowl: fuller here, with no artificial ring boundary.
			var north_bias := maxf(0.0, Vector2(0.0, -1.0).dot(p.normalized()))
			density *= 1.0 + north_bias * 0.16
			if rng.randf() > density:
				continue
			var local_p := p + Vector2(rng.randf_range(-2.4, 2.4), rng.randf_range(-2.4, 2.4))
			var local_y := height(local_p.x, local_p.y)
			var kind_roll := rng.randf()
			var tree_height := rng.randf_range(1.15, 1.85) * lerpf(1.0, 0.8, smoothstep(180.0, 440.0, radius))
			var yaw := rng.randf() * TAU
			var bark: Color = trunk_palette[rng.randi_range(0, trunk_palette.size() - 1)]
			# The trunk is useful in the near and middle layers; far forest is carried by its canopy silhouette.
			if radius < 22.0:                          # (further off, a trunk under a crown just reads as a lollipop)
				var trunk_r := rng.randf_range(0.07, 0.13) * (1.15 if kind_roll < 0.56 else 0.8)
				trunks.append([Transform3D(Basis().scaled(Vector3(trunk_r, tree_height, trunk_r)), Vector3(local_p.x, local_y + tree_height * 0.5, local_p.y)), bark])
			if kind_roll < 0.48:
				var crown := broad_a if rng.randf() < 0.58 else broad_b
				var crown_w := rng.randf_range(0.72, 1.18) * lerpf(1.0, 0.82, smoothstep(150.0, 420.0, radius))
				var crown_h := rng.randf_range(0.62, 1.02)
				var crown_colour: Color = broad_palette[rng.randi_range(0, broad_palette.size() - 1)]
				crown.append([Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), yaw, rng.randf_range(-0.06, 0.06))).scaled(Vector3(crown_w, crown_h, crown_w * rng.randf_range(0.86, 1.08))), Vector3(local_p.x, local_y + tree_height * 0.82, local_p.y)), _forest_tint(crown_colour, radius)])
			elif kind_roll < 0.67:
				var crown_w := rng.randf_range(0.5, 0.85) * lerpf(1.0, 0.8, smoothstep(150.0, 420.0, radius))
				var crown_colour: Color = birch_palette[rng.randi_range(0, birch_palette.size() - 1)]
				birch.append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(crown_w, rng.randf_range(0.82, 1.24), crown_w * 0.82)), Vector3(local_p.x, local_y + tree_height * 0.82, local_p.y)), _forest_tint(crown_colour, radius)])
			elif kind_roll < 0.88:
				var width := rng.randf_range(0.5, 0.86)
				pine.append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(width, tree_height * rng.randf_range(1.05, 1.3), width)), Vector3(local_p.x, local_y + tree_height * 0.66, local_p.y)), _forest_tint(pine_palette[rng.randi_range(0, pine_palette.size() - 1)], radius)])
			else:
				var width := rng.randf_range(0.42, 0.7)
				cedar.append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(width, tree_height * rng.randf_range(0.9, 1.2), width)), Vector3(local_p.x, local_y + tree_height * 0.62, local_p.y)), _forest_tint(pine_palette[rng.randi_range(0, pine_palette.size() - 1)].darkened(0.08), radius)])
			if radius < 135.0 and rng.randf() < 0.62:
				var shrub_p := local_p + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
				var shrub_colour: Color = broad_palette[rng.randi_range(0, 3)].darkened(0.16)
				understory.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(rng.randf_range(0.22, 0.46), rng.randf_range(0.18, 0.34), rng.randf_range(0.22, 0.46))), Vector3(shrub_p.x, height(shrub_p.x, shrub_p.y) + 0.18, shrub_p.y)), shrub_colour])
			if radius < 180.0 and rng.randf() < 0.035:
				var log_p := local_p + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
				deadwood.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(rng.randf_range(0.65, 1.8), rng.randf_range(0.07, 0.13), rng.randf_range(0.07, 0.13))), Vector3(log_p.x, height(log_p.x, log_p.y) + 0.07, log_p.y)), Color("342e27")])
	_forest_multimesh(world, _forest_cluster_mesh(0), broad_a, "BroadleafCanopyA")
	_forest_multimesh(world, _forest_cluster_mesh(1), broad_b, "BroadleafCanopyB")
	_forest_multimesh(world, _forest_cluster_mesh(2), birch, "BirchCanopy")
	_forest_multimesh(world, _forest_pine_mesh(false), pine, "WhitePineCanopy")
	_forest_multimesh(world, _forest_pine_mesh(true), cedar, "CedarCanopy")
	_forest_multimesh(world, _forest_trunk_mesh(), trunks, "DistantTrunks")
	_forest_multimesh(world, _forest_cluster_mesh(3), understory, "DistantUnderstory")
	_forest_multimesh(world, _forest_deadwood_mesh(), deadwood, "DistantDeadwood")
	await _forest_canopy_shelves(world)


## A few large canopy groups establish the depth bands the individual trees cannot express at thumbnail scale. They
## overlap the tree field, follow the miniature terrain, and leave the ridge's open valley as a deliberate negative
## space. The result is a forest edge that dissolves into woodland rather than a circular wall around the level.
func _forest_canopy_shelves(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 272002
	var shelf_a: Array = []
	var shelf_b: Array = []
	var vista_a: Array = []
	var vista_b: Array = []
	var bands := [[16.0, 18], [33.0, 24], [62.0, 30], [112.0, 38], [190.0, 46]]
	for band_i: int in bands.size():
		await Slicer.tick(self)
		var band: Array = bands[band_i]
		var radius: float = band[0]
		var count: int = band[1]
		for i in count:
			var angle := (float(i) / float(count)) * TAU + rng.randf_range(-0.11, 0.11)
			var p := Vector2(cos(angle), sin(angle)) * (radius + rng.randf_range(-radius * 0.16, radius * 0.16))
			if p.distance_to(LAKE) < LAKE_R + 7.0:
				continue
			var rv := p - Vector2(22.0, -44.0)
			var forward := rv.dot(Vector2(0.89, -0.456))
			var side := absf(rv.dot(Vector2(0.456, 0.89)))
			if forward > 15.0 and side < 21.0 + forward * 0.24 and rng.randf() < 0.82:
				continue
			var y := height(p.x, p.y)
			if y > 28.0:
				continue
			var far := float(band_i) / float(bands.size() - 1)
			var width := lerpf(1.25, 5.6, far) * rng.randf_range(0.78, 1.24)
			var crown_height := lerpf(0.82, 1.85, far) * rng.randf_range(0.78, 1.18)
			var crown_y := y + lerpf(0.72, 1.28, far) + rng.randf_range(-0.16, 0.22)
			var tint := Color("2f5940").lerp(Color("64806a"), rng.randf() * 0.75)
			if rng.randf() < 0.34:
				tint = tint.lerp(Color("72522b"), rng.randf_range(0.12, 0.34))
			var item := [Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), rng.randf() * TAU, rng.randf_range(-0.04, 0.04))).scaled(Vector3(width, crown_height, width * rng.randf_range(0.78, 1.18))), Vector3(p.x, crown_y, p.y)), _forest_tint(tint, radius)]
			(shelf_a if (i + band_i) % 2 == 0 else shelf_b).append(item)
	# Two overlapping north-facing lanes are intentional landmarks: the oak's rolling canopy sea and the fork's
	# view through trunks. They are high enough to meet the horizon, but sparse enough to preserve glimpses of haze.
	var lanes := [-1.43, -1.18, -0.92]
	var depths := [14.0, 27.0, 50.0, 92.0, 158.0]
	for lane_i in lanes.size():
		for depth_i in depths.size():
			var radius: float = depths[depth_i]
			var count := 6 + depth_i * 3
			for i in count:
				var angle: float = lanes[lane_i] + lerpf(-0.24, 0.24, float(i) / maxf(1.0, count - 1.0)) + rng.randf_range(-0.055, 0.055)
				var p := Vector2(cos(angle), sin(angle)) * (radius + rng.randf_range(-radius * 0.12, radius * 0.12))
				var y := height(p.x, p.y)
				if y > 28.0:
					continue
				var far := float(depth_i) / float(depths.size() - 1)
				var width := lerpf(1.2, 4.8, far) * rng.randf_range(0.82, 1.2)
				var crown_height := lerpf(0.92, 1.68, far) * rng.randf_range(0.8, 1.16)
				var crown_y := y + lerpf(0.9, 1.48, far) + rng.randf_range(-0.12, 0.2)
				var tint := Color("1d3b2b").lerp(Color("496044"), rng.randf() * 0.7)
				var item := [Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.04, 0.04))).scaled(Vector3(width, crown_height, width * rng.randf_range(0.8, 1.14))), Vector3(p.x, crown_y, p.y)), _forest_tint(tint, radius)]
				(vista_a if (i + depth_i + lane_i) % 2 == 0 else vista_b).append(item)
	_forest_multimesh(world, _forest_cluster_mesh(0), shelf_a, "CanopyShelfA")
	_forest_multimesh(world, _forest_cluster_mesh(1), shelf_b, "CanopyShelfB")
	_forest_multimesh(world, _forest_cluster_mesh(0), vista_a, "OldOakForestVista")
	_forest_multimesh(world, _forest_cluster_mesh(1), vista_b, "DeepForestVista")


func _forest_tint(colour: Color, radius: float) -> Color:
	return haze(colour, radius * SCALE)


## The air between you and a thing this many metres off, baked into its colour: the woods' own blue haze close by
## (it matches the woods' fog at the edge), paler and lighter toward the horizon, never quite swallowing the hills.
static func haze(colour: Color, metres: float) -> Color:
	var h := minf(0.8, 1.0 - exp(-metres / (150.0 + 0.6 * metres)))
	var air := Color("47637a").lerp(Color("a9bcc8"), smoothstep(150.0, 2500.0, metres))
	return colour.lerp(air, h)


func _forest_cluster_mesh(variant: int) -> Mesh:
	var source := SphereMesh.new()                   # a few pixels across: as few triangles as still read round
	source.radius = 1.0
	source.height = 2.0
	source.radial_segments = 5
	source.rings = 2
	var parts: Array
	match variant:
		0:
			parts = [[Vector3(0, 0, 0), Vector3(0.9, 0.62, 0.9)], [Vector3(-0.78, -0.02, 0.08), Vector3(0.68, 0.5, 0.72)], [Vector3(0.72, 0.08, -0.1), Vector3(0.72, 0.54, 0.66)]]
		1:
			parts = [[Vector3(0, 0.08, 0), Vector3(0.72, 0.82, 0.74)], [Vector3(-0.55, -0.12, 0.12), Vector3(0.58, 0.44, 0.58)], [Vector3(0.5, 0.0, -0.16), Vector3(0.46, 0.56, 0.5)], [Vector3(0.05, 0.42, 0.05), Vector3(0.42, 0.38, 0.42)]]
		2:
			parts = [[Vector3(0, 0.26, 0), Vector3(0.5, 0.48, 0.5)], [Vector3(-0.28, -0.08, 0.04), Vector3(0.42, 0.36, 0.38)], [Vector3(0.31, -0.08, -0.08), Vector3(0.4, 0.34, 0.36)]]
		_:
			parts = [[Vector3(0, 0, 0), Vector3(1.0, 0.46, 0.86)], [Vector3(-0.38, 0.02, 0.16), Vector3(0.56, 0.32, 0.5)], [Vector3(0.43, -0.02, -0.12), Vector3(0.52, 0.3, 0.48)]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		st.append_from(source, 0, Transform3D(Basis().scaled(part[1]), part[0]))
	st.generate_normals()
	return st.commit()


func _forest_pine_mesh(narrow: bool) -> Mesh:
	var source := CylinderMesh.new()
	source.top_radius = 0.0
	source.bottom_radius = 1.0
	source.height = 1.0
	source.radial_segments = 6
	source.rings = 0                                  # (the default 4 rings and caps were triangles nobody sees)
	source.cap_top = false
	source.cap_bottom = false
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := 4 if narrow else 5
	for i in range(tiers):
		var f := float(i) / float(tiers - 1)
		var width := lerpf(0.92, 0.25, f) if narrow else lerpf(1.05, 0.3, f)
		var y := lerpf(-0.34, 0.38, f)
		st.append_from(source, 0, Transform3D(Basis().scaled(Vector3(width, 0.42 if narrow else 0.38, width)), Vector3(0, y, 0)))
	st.generate_normals()
	return st.commit()


func _forest_trunk_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.38
	mesh.bottom_radius = 0.55
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 0
	mesh.cap_top = false
	mesh.cap_bottom = false
	return mesh


func _forest_deadwood_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	return mesh


func _forest_multimesh(world: Node3D, mesh: Mesh, items: Array, label: String) -> void:
	items = items.filter(func(it: Array) -> bool:
		var o: Vector3 = (it[0] as Transform3D).origin
		return toy_clear(Vector2(o.x, o.z)))
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	mm.custom_aabb = AABB(Vector3(-470.0, -20.0, -470.0), Vector3(940.0, 100.0, 940.0))
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)


## A white village on the lake shore: houses, a red barn, and the church with its steeple.
## A toy's material: its own colour, never hazed by the distance - it stands out the way a dollhouse would.
static func _toy_mat(key: String, colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = colour
	m.roughness = 1.0
	m.disable_fog = true
	return m


func _toy_garden(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1008
	var c := TOY_GARDEN
	var y0 := height(c.x, c.y)
	var lawn := SurfaceTool.new()                      # the lawn, lying on the land
	lawn.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 3.4 * TOY_SCALE
	var d := 2.6 * TOY_SCALE
	for j in range(6):
		for i in range(6):
			var quad: Array = []
			for q: Vector2 in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var x := c.x - w + q.x / 6.0 * w * 2.0
				var z := c.y - d + q.y / 6.0 * d * 2.0
				quad.append(Vector3(x, height(x, z) + 0.03, z))
			for v in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
				lawn.add_vertex(v)
	lawn.generate_normals()
	var ln := MeshInstance3D.new()
	ln.mesh = lawn.commit()
	ln.material_override = _toy_mat("toylawn", Color("8a9a48"))
	world.add_child(ln)
	var parts: Array = [                                # [size, offset from c, colour key, colour]
		[Vector3(0.9, 0.55, 0.7), Vector2(0.0, 2.9), "toywhite", Color("eeeae0")],        # the white house
		[Vector3(0.8, 0.5, 0.65), Vector2(-1.5, 3.1), "toycream", Color("e8e2d2")],
		[Vector3(0.8, 0.5, 0.65), Vector2(1.5, 3.2), "toyred", Color("8a3a2a")],
		[Vector3(0.14, 0.26, 0.02), Vector2(0.0, 2.54), "toydoor", Color("3a5a8a")],       # its blue door
	]
	for pt: Array in parts:
		var at: Vector2 = c + (pt[1] as Vector2) * TOY_SCALE
		var n := MeshInstance3D.new()
		var b := BoxMesh.new()
		pt[0] = (pt[0] as Vector3) * TOY_SCALE
		b.size = pt[0]
		n.mesh = b
		n.material_override = _toy_mat(pt[2], pt[3])
		n.position = Vector3(at.x, height(at.x, at.y) + (pt[0] as Vector3).y * 0.5 + (0.0 if pt[2] != "toydoor" else 0.0), at.y)
		world.add_child(n)
		if pt[2] != "toydoor":
			var r := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3((pt[0] as Vector3).x * 1.1, 0.3 * TOY_SCALE, (pt[0] as Vector3).z * 1.1)
			r.mesh = pm
			r.material_override = _toy_mat("skyroof", Color("4a4440"))
			r.position = n.position + Vector3(0, (pt[0] as Vector3).y * 0.5 + 0.15, 0)
			world.add_child(r)
	var picket := _toy_mat("toypicket", Color("f4f0e6"))
	for side: Array in [[Vector2(-w, -d), Vector2(w, -d)], [Vector2(-w, -d), Vector2(-w, d)], [Vector2(w, -d), Vector2(w, d)]]:
		var a: Vector2 = c + side[0]
		var e: Vector2 = c + side[1]
		var n := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(a.distance_to(e), 0.08, 0.03)
		n.mesh = b
		n.material_override = picket
		var mid := (a + e) * 0.5
		n.position = Vector3(mid.x, height(mid.x, mid.y) + 0.07, mid.y)
		n.rotation.y = -atan2(e.y - a.y, e.x - a.x)
		world.add_child(n)
	var creek := MeshInstance3D.new()                  # the creek down the far side, and its bridge
	var cb := BoxMesh.new()
	cb.size = Vector3(0.35, 0.02, d * 2.6)
	creek.mesh = cb
	creek.material_override = _toy_mat("toycreek", Color("4a6e86"))
	creek.position = Vector3(c.x - w - 0.5, height(c.x - w - 0.5, c.y) + 0.02, c.y)
	world.add_child(creek)
	var br := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.6, 0.03, 0.14)
	br.mesh = bb
	br.material_override = _toy_mat("toybridge", Color("8a6e4e"))
	br.position = creek.position + Vector3(0, 0.03, 0.2)
	world.add_child(br)
	for k in range(9):                                  # autumn trees round the back, a pine or two
		var a := rng.randf_range(-PI, 0.0)
		var at := c + Vector2(cos(a) * (w + rng.randf_range(0.6, 1.6)), sin(a) * (d + rng.randf_range(0.6, 1.4)))
		var t := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.35, 0.55)
		sm.height = sm.radius * 2.2
		sm.radial_segments = 8
		sm.rings = 4
		t.mesh = sm
		t.material_override = _toy_mat("toytree%d" % (k % 3), [Color("c0662c"), Color("a8402a"), Color("4e6a3a")][k % 3])
		t.position = Vector3(at.x, height(at.x, at.y) + sm.radius * 1.4, at.y)
		world.add_child(t)


## Nothing of the far forest grows over the toy garden.
static func toy_clear(p: Vector2) -> bool:
	return p.distance_to(TOY_GARDEN) > 6.5 * TOY_SCALE


func _village(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1719
	var white := GardenProps.mat("skywhite", Color("eeeae0"))
	var roof := GardenProps.mat("skyroof", Color("4a4440"))
	for k in range(9):
		var p := VILLAGE + Vector2(rng.randf_range(-7, 7), rng.randf_range(-5, 5))
		var y := height(p.x, p.y)
		var body := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 0.35, 0.38)
		body.mesh = b
		body.material_override = white if k != 3 else GardenProps.mat("skybarn", Color("8a3a2a"))
		body.position = Vector3(p.x, y + 0.17, p.y)
		body.rotation.y = rng.randf_range(-0.4, 0.4)
		world.add_child(body)
		var r := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.56, 0.22, 0.42)
		r.mesh = pm
		r.material_override = roof
		r.position = body.position + Vector3(0, 0.28, 0)
		r.rotation = body.rotation
		world.add_child(r)
	var c := VILLAGE + Vector2(2.0, -2.0)            # the church: a white box, a tall white steeple
	var cy := height(c.x, c.y)
	for part: Array in [[BoxMesh.new(), Vector3(0.5, 0.45, 0.9), Vector3(0, 0.22, 0)], [BoxMesh.new(), Vector3(0.24, 0.6, 0.24), Vector3(0, 0.55, 0.42)]]:
		var n := MeshInstance3D.new()
		(part[0] as BoxMesh).size = part[1]
		n.mesh = part[0]
		n.material_override = white
		n.position = Vector3(c.x, cy, c.y) + part[2]
		world.add_child(n)
	var spire := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.0
	sc.bottom_radius = 0.14
	sc.height = 0.7
	sc.radial_segments = 4
	spire.mesh = sc
	spire.material_override = white
	spire.position = Vector3(c.x, cy + 1.2, c.y + 0.42)
	world.add_child(spire)


## A fire tower on the long ridge to the west: a lattice of legs and a little cab on top.
func _fire_tower(world: Node3D) -> void:
	var p: Array = PEAKS[3]
	var x: float = p[0] + 4.0
	var z: float = p[1] - 6.0
	var y := height(x, z)
	var steel := GardenProps.mat("skysteel", Color("6a6a66"))
	for sx: float in [-0.25, 0.25]:
		for sz: float in [-0.25, 0.25]:
			var leg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.025
			cm.bottom_radius = 0.025
			cm.height = 2.4
			cm.radial_segments = 4
			leg.mesh = cm
			leg.material_override = steel
			leg.position = Vector3(x + sx * 0.7, y + 1.2, z + sz * 0.7)
			leg.rotation = Vector3(sz * -0.25, 0, sx * 0.25)
			world.add_child(leg)
	var cab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.35, 0.5)
	cab.mesh = bm
	cab.material_override = GardenProps.mat("skycab", Color("8a6a4a"))
	cab.position = Vector3(x, y + 2.5, z)
	world.add_child(cab)


func _clouds_build(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1720
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 10
	puff.rings = 5
	for k in range(14):
		var cloud := Node3D.new()
		var a := rng.randf() * TAU
		var r := rng.randf_range(120.0, 420.0)
		cloud.position = Vector3(cos(a) * r, rng.randf_range(70.0, 110.0), sin(a) * r)
		cloud.set_meta("x0", cloud.position.x)
		cloud.set_meta("ph", rng.randf() * 120.0)
		for p in range(rng.randi_range(4, 7)):
			var b := MeshInstance3D.new()
			b.mesh = puff
			b.material_override = m
			var s := rng.randf_range(6.0, 13.0)
			b.scale = Vector3(s * 1.6, s * 0.55, s)
			b.position = Vector3(rng.randf_range(-14, 14), rng.randf_range(-1.5, 2.0), rng.randf_range(-8, 8))
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(b)
		world.add_child(cloud)
		_clouds.append(cloud)
