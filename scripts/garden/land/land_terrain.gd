extends MiniatureSky

## Distant land 1/3 - the terrain: the 1:16 height field, its colours, the lake, the haze.
##
## The land is a height field in miniature units (SCALE in MiniatureSky). height() blends the woods' own ground near
## the middle into the land's (_own_height) so the seam hides under the woods' floor. toy_clear() keeps the land
## flat where the toy garden sits. haze() fades a colour into the air with distance, everywhere in the land.
##
## Part of the distant land layer chain (the full order is at the top of scripts/garden/distant_land.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var _noise: FastNoiseLite
var _hills: FastNoiseLite
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
## A make-believe garden far off in the valley (seen from the ridge): the white house with the blue door, its
## neighbours, the lawn, the picket fence, the creek and its little bridge, a few autumn trees - a toy, not the real one.
const TOY_GARDEN := Vector2(0.287, 0.958) * 38.0       # beyond the footbridge, on the garden side of the woods
const TOY_SCALE := 5.0
var _toy_y := INF                                  # bigger than life: a make-believe garden you can pick out


var _woods: Node3D


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
	# under the woods themselves (out < 0) it sinks well below their ground, which is always drawn over it: the sky
	# camera (the woods camera / SCALE) must never end up under it, or the sky goes dark (tools/checks/sky_clip_check.gd)
	var under := 0.03 + 0.5 * smoothstep(0.0, -12.0, out)
	return lerpf(_woods.height(clampf(mx, -62.0, 64.0), clampf(mz, -112.0, 28.0)) / SCALE - under, own, t)


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
	var r := 0.25
	while r < 8.0:                                    # dense across the woods (they reach ~7.5 out): it follows their ground
		radii.append(r)
		r += 0.25
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


## The air between you and a thing this many metres off, baked into its colour: the woods' own blue haze close by
## (it matches the woods' fog at the edge), paler and lighter toward the horizon, never quite swallowing the hills.
static func haze(colour: Color, metres: float) -> Color:
	var h := minf(0.8, 1.0 - exp(-metres / (150.0 + 0.6 * metres)))
	var air := Color("47637a").lerp(Color("a9bcc8"), smoothstep(150.0, 2500.0, metres))
	return colour.lerp(air, h)


## Nothing of the far forest grows over the toy garden.
static func toy_clear(p: Vector2) -> bool:
	return p.distance_to(TOY_GARDEN) > 6.5 * TOY_SCALE
