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


func setup(woods: Node3D, to_sun: Vector3) -> void:
	name = "DistantLand"
	_noise = FastNoiseLite.new()
	_noise.seed = 1716
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_hills = FastNoiseLite.new()
	_hills.seed = 1717
	_hills.frequency = 0.045
	view = SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.positional_shadow_atlas_size = 0
	add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	sky_cam = Camera3D.new()
	sky_cam.near = 0.05
	sky_cam.far = 1400.0
	sky_cam.keep_aspect = Camera3D.KEEP_WIDTH
	sky_cam.environment = _environment()
	view.add_child(sky_cam)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe4b8")
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	world.add_child(sun)
	_terrain(world)
	_lake(world)
	_forest(world)
	_village(world)
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
	env.fog_density = 0.0055
	env.fog_sky_affect = 0.0
	env.fog_height = -2.0
	env.fog_height_density = 0.08                     # and mist in the low ground
	return env


# ------------------------------------------------------------------ the land
## Ground height (sky units) at x, z. Low and flat under the woods; rolling hills further out; the valley; the peaks.
func height(x: float, z: float) -> float:
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
		var row: Array = []
		for si in range(seg):
			var a := si * TAU / seg
			var x: float = cos(a) * radii[ri]
			var z: float = sin(a) * radii[ri] - 2.6
			var y := height(x, z)
			row.append([Vector3(x, y, z), _ground_colour(x, y, z)])
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
	var forest := Color("2e4a2c").lerp(Color("3c5530"), 0.5 + _hills.get_noise_2d(x * 2.0, z * 2.0))
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
			cones.append([Transform3D(Basis().scaled(Vector3(s * 0.35, s * 1.1, s * 0.35)), Vector3(x, y + s * 0.5, z)), col])
		else:
			var au := rng.randf() < 0.35
			balls.append([Transform3D(Basis().scaled(Vector3(s * 0.5, s * 0.42, s * 0.5)), Vector3(x, y + s * 0.3, z)), Color("9a5a24").lerp(Color("b87a30"), rng.randf()) if au else col.lightened(0.08)])
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


## A white village on the lake shore: houses, a red barn, and the church with its steeple.
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
