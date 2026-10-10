extends Elsewhere

## The woods, over the footbridge: a dark, hilly hiking trail. You stand at a clearing and turn to look around (drag,
## anywhere); the trails out of it are marked with their names, and the one you're facing lights up. Tap and you
## walk it - up and down the hills, a little bob in your step - to the next clearing. The pets following you (🐾 in
## the garden) trail along behind and gather round when you stop; a pet you're carrying (🪣) rides in its bucket and
## sits beside you, and "Let out" turns it into one more follower.
##
## Daytime under the trees: deep blue-green shade, a blue haze between the trunks, and the morning sun coming through
## in places - sunbeams slanting down (the garden's light-shaft shader), motes drifting in them, the canopy's shadows
## dappling the trails.
##
## Clearings (NODES) and the trails between them (EDGES): the trailhead by the creek, the mossy fork (the hub, mossy
## boulders), the fern hollow down low (ferns), the ridge up high (an overlook: the land falls away to a misty valley,
## far hills, the morning sun), the creek crossing (a real creek in its channel, stepping stones where the
## trails cross it), the old oak (one huge tree alone in its glade), and the nursery (nursery.gd). Dark, but kind:
## lanterns at every clearing, sunbeams, motes in the light. Never spooky.
##
## Finds (FINDS, SPOTS): litter to pick up, dumped junk to work loose, and what the woods drop - pine cones, acorns,
## mushrooms and feathers for the basket (the nursery buys them), and wild seeds to sow. Tap them from the clearing.
## Litter stays picked up; what the woods drop grows back after a while. Saved in game.woods_finds.

const ORIGIN := Vector3(0, -300, 0)             # far below everything: nothing of the garden is ever in view
const EYE := 1.5
const WALK_SPEED := 3.2
const NODES := {
	"trailhead": {"at": Vector2(0, 0), "lift": 0.0, "name": "The trailhead"},
	"fork": {"at": Vector2(2, -24), "lift": 1.5, "name": "The mossy fork"},
	"hollow": {"at": Vector2(-22, -38), "lift": -6.0, "name": "Fern hollow"},
	"ridge": {"at": Vector2(22, -44), "lift": 10.0, "name": "The ridge"},
	"creek": {"at": Vector2(-28, -64), "lift": -3.0, "name": "Creek crossing"},
	"oak": {"at": Vector2(4, -70), "lift": 2.0, "name": "The old oak", "room": 10.0},
	"nursery": {"at": Vector2(24, -16), "lift": 0.5, "name": "The nursery", "flat": 9.0, "room": 12.0},
	"pond": {"at": Vector2(-42, -90), "lift": -3.0, "name": "Beaver pond", "room": 8.0},
	"cellar": {"at": Vector2(-40, -14), "lift": 1.0, "name": "The cellar hole", "room": 8.0},
}
const EDGES := [["trailhead", "fork"], ["fork", "hollow"], ["fork", "ridge"], ["hollow", "creek"], ["ridge", "oak"], ["creek", "oak"], ["fork", "nursery"],
	["creek", "pond"], ["trailhead", "cellar"], ["cellar", "hollow"]]
## The beaver pond (its middle, how wide), and the old farmhouse's cellar hole.
const POND_AT := Vector2(-46.0, -98.6)
const POND_R := 6.5
const CELLAR_AT := Vector2(-46.0, -17.0)
## Trails that don't lead anywhere yet: a few overgrown metres and a sign. {id: {from, toward: Vector2, name}}
const STUBS := {}
## The creek: a channel through the creek crossing's clearing (it stands on one bank; both its trails cross).
const CREEK_AT := Vector2(-23.8, -60.5)
const CREEK_DIR := Vector2(-0.643, 0.766)
## From the ridge, the way the land falls away (east-northeast, toward the moon).
const VIEW_DIR := Vector2(0.89, -0.456)
## Toward the sun: low in the morning sky, out past the ridge.
const TO_SUN := Vector3(0.55, 0.5, -0.32)
## Things to find, and what each is. what: litter (a coin, gone for good), junk (a few tugs, more coins, gone for good),
## forage (into the basket for the nursery; grows back), seeds (wild seeds to sow; grow back).
const FINDS := {
	"can": {"what": "litter", "coins": 1, "say": "A rusty can. Into the sack with it."},
	"bottle": {"what": "litter", "coins": 1, "say": "An old bottle, half full of leaves."},
	"wrapper": {"what": "litter", "coins": 1, "say": "A sweet wrapper. Somebody's been through here."},
	"tire": {"what": "junk", "coins": 6, "tugs": 3, "say": "Somebody rolled a tire into the creek. Not any more."},
	"tarp": {"what": "junk", "coins": 4, "tugs": 3, "say": "An old blue tarp, bundled up and hauled off."},
	"drum": {"what": "junk", "coins": 6, "tugs": 3, "say": "A rusted oil drum. That's been here a while. Not now."},
	"line": {"what": "junk", "coins": 3, "tugs": 2, "say": "A snarl of fishing line, cut out of the reeds. The birds will thank you."},
	"cone": {"what": "forage", "say": "A good pine cone. Into the basket."},
	"acorn": {"what": "forage", "say": "Acorns, a handful. Into the basket."},
	"mushroom": {"what": "forage", "say": "A mushroom, picked carefully. Into the basket."},
	"feather": {"what": "forage", "say": "A blue jay's feather. Into the basket."},
	"apple": {"what": "forage", "say": "An apple off the old tree. Small and sour and perfect. Into the basket."},
	"seeds": {"what": "seeds"},
}
const SPOTS := {
	"trailhead": ["can", "wrapper", "tarp", "cone", "seeds"],
	"fork": ["bottle", "can", "mushroom", "acorn", "seeds"],
	"hollow": ["wrapper", "bottle", "mushroom", "feather", "seeds"],
	"ridge": ["can", "drum", "cone", "feather", "seeds"],
	"creek": ["bottle", "tire", "line", "acorn", "seeds"],
	"oak": ["wrapper", "acorn", "mushroom", "feather", "seeds"],
	"pond": ["bottle", "can", "feather", "cone", "seeds"],
	"cellar": ["can", "bottle", "apple", "acorn", "seeds"],
}
const WILD_SEEDS := {"trailhead": "clover", "fork": "moss", "hollow": "fern", "ridge": "pine", "creek": "willow", "oak": "oak",
	"pond": "willow", "cellar": "rose"}
const REGROW := 20.0 * 60.0                      # seconds of real time before what the woods drop is back

var _noise: FastNoiseLite
var _fine: FastNoiseLite
var _paths: Array = []                # {a, b, pts: PackedVector3Array (local, a -> b)}
var _labels := {}                     # node id -> [{to, dir: Vector3, label: Label3D, edge | stub}]
var _at := "trailhead"
var _yaw := 0.0
var _goal_yaw := 0.0
var _pitch := deg_to_rad(-6.0)
var _walking: Dictionary = {}         # {pts, s, len, to}
var _press := Vector2.INF
var _moved := false
var _t := 0.0
var _fireflies: Array = []
var followers: Array = []             # HedgePetNode, in walking order
var _carried: HedgePetNode = null
var _pail: Node3D
var _let_out: Button
var _released: Array = []             # pets let out of the bucket here: they come home beside you
var _told := false
var _finds: Array = []                # {id, kind, at (node id), node: Node3D, tugs}
var _basket_label: Label
var nursery: Node3D                   # nursery.gd
var campfire: Node3D                  # fire_pit.gd, in fern hollow
var basket: Dictionary:
	get:
		return garden.game.woods_finds["basket"]


func title_text() -> String:
	return ""


func loading_note() -> String:
	return "Into the woods. The first walk in takes a little while."


func muffle() -> Vector2:
	return Vector2(2400.0, -8.0)                         # the garden's birds, far off behind the trees


func setup(g: Node3D) -> void:
	name = "Woods"
	position = ORIGIN
	super.setup(g)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.08
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	_let_out = Button.new()
	_let_out.flat = true
	_let_out.add_theme_font_size_override("font_size", 36)
	_let_out.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_let_out.position = Vector2(60, 1680)
	_let_out.custom_minimum_size = Vector2(420, 90)
	_let_out.visible = false
	_let_out.pressed.connect(let_out)
	_ui.add_child(_let_out)
	_basket_label = Label.new()
	_basket_label.add_theme_font_size_override("font_size", 40)
	_basket_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_basket_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 0.6))
	_basket_label.add_theme_constant_override("outline_size", 8)
	_basket_label.position = Vector2(60, 150)
	_basket_label.modulate.a = 0.0
	_ui.add_child(_basket_label)


# ------------------------------------------------------------------ the ground
func height(x: float, z: float) -> float:
	var v := _noise.get_noise_2d(x, z) * 9.0 + _fine.get_noise_2d(x, z) * 1.4
	for id in NODES:
		var n: Dictionary = NODES[id]
		var d := Vector2(x, z).distance_to(n["at"])
		v += float(n["lift"]) * exp(-d * d / (2.0 * 11.0 * 11.0))
		var level := _base(n["at"]) + float(n["lift"])
		var flat := float(n.get("flat", 2.5))
		v = lerpf(v, level, smoothstep(flat + 4.5, flat, d))   # a flat-ish clearing to stand in
	var rv := Vector2(x, z) - (NODES["ridge"]["at"] as Vector2)
	var s := rv.dot(VIEW_DIR)
	if s > 3.0:                                          # past the ridge's edge the land falls away
		var lat := rv.dot(VIEW_DIR.orthogonal())
		v -= 20.0 * smoothstep(3.0, 22.0, s) * exp(-lat * lat / (2.0 * 20.0 * 20.0))
	var dp := Vector2(x, z).distance_to(POND_AT)                # the pond's bowl
	v -= 1.6 * smoothstep(POND_R + 2.5, POND_R - 1.5, dp)
	var dc := (Vector2(x, z) - CELLAR_AT).abs()                 # the cellar hole: a square pit, stone-lined
	v -= 1.2 * smoothstep(3.6, 2.8, maxf(dc.x, dc.y))
	return v - _channel(x, z)


## How deep the creek's channel is here.
func _channel(x: float, z: float) -> float:
	var d := Vector2(x, z) - CREEK_AT
	var lat := absf(_creek_lat(Vector2(x, z)))
	return 1.1 * smoothstep(3.2, 1.0, lat) * smoothstep(80.0, 72.0, absf(d.dot(CREEK_DIR)))   # off the map both ways


## The water's surface here (creek or pond), or -INF on dry land.
func water_at(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var along := (q - CREEK_AT).dot(CREEK_DIR)
	if absf(_creek_lat(q)) < 2.3 and absf(along) < 72.0:
		var mid := _creek_point(along)
		return height(mid.x, mid.y) + 0.72
	if q.distance_to(POND_AT) < POND_R + 0.8:
		return pond_level()
	return -INF


var _pond_y := INF


func pond_level() -> float:
	if _pond_y == INF:
		var rim := INF
		for k in range(16):
			var r := POND_AT + Vector2.from_angle(k * TAU / 16.0) * (POND_R + 0.5)
			rim = minf(rim, height(r.x, r.y))
		_pond_y = rim - 0.25
	return _pond_y


## The creek winds: how far its middle swings to the side at a distance along it.
func _meander(along: float) -> float:
	return sin(along * 0.13) * 2.2 + sin(along * 0.31 + 1.0) * 0.7


## Where the creek's middle is, a distance along it.
func _creek_point(along: float) -> Vector2:
	return CREEK_AT + CREEK_DIR * along + CREEK_DIR.orthogonal() * _meander(along)


## How far to the side of the creek's middle a point is (signed).
func _creek_lat(p: Vector2) -> float:
	var d := p - CREEK_AT
	return d.dot(CREEK_DIR.orthogonal()) - _meander(d.dot(CREEK_DIR))


func _base(p: Vector2) -> float:
	return _noise.get_noise_2d(p.x, p.y) * 9.0


func node_pos(id: String) -> Vector3:
	var p: Vector2 = NODES[id]["at"]
	return Vector3(p.x, height(p.x, p.y), p.y)


# ------------------------------------------------------------------ building it (once)
## Built in steps (Elsewhere shows a loading card between them; the bake runs them all at once).
func build_steps() -> Array:
	return [["Finding the trails", _build_trails], ["Shaping the hills and the creek", _build_land], ["Growing the trees", _build_trees],
		["Ferns and fallen logs", _build_undergrowth], ["The old oak, the pond, the signs", _build_places], ["Letting the sun in", _build_sky],
		["Down to the nursery", _build_nursery]]


var _brng: RandomNumberGenerator


func _build() -> void:
	for step: Array in build_steps():
		(step[1] as Callable).call()


func _build_trails() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 77
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.022
	_noise.fractal_octaves = 3
	_fine = FastNoiseLite.new()
	_fine.seed = 78
	_fine.frequency = 0.11
	_brng = RandomNumberGenerator.new()
	_brng.seed = 4242
	var rng := _brng
	for e: Array in EDGES:
		_paths.append({"a": e[0], "b": e[1], "pts": _trail(node_pos(e[0]), node_pos(e[1]), rng)})
	for id in NODES:
		_labels[id] = []
	for i in _paths.size():
		var e: Dictionary = _paths[i]
		_add_way(e["a"], e["b"], e["pts"], i)
		_add_way(e["b"], e["a"], _reversed(e["pts"]), i)
	_labels["trailhead"].append({"to": "garden", "dir": Vector3(0.3, 0, 1).normalized(), "name": "Home to the garden"})
	for sid in STUBS:
		var st: Dictionary = STUBS[sid]
		var from := node_pos(st["from"])
		var to2: Vector2 = Vector2(from.x, from.z) + (st["toward"] as Vector2)
		var pts := _trail(from, Vector3(to2.x, height(to2.x, to2.y), to2.y), rng)
		_paths.append({"a": st["from"], "b": sid, "pts": pts, "stub": true})
		_labels[st["from"]].append({"to": sid, "dir": _dir_of(pts), "name": "%s (overgrown)" % st["name"], "stub": true})
		_brambles(pts[pts.size() - 1], rng)
	_index_trails()


func _build_land() -> void:
	_ground(_brng)
	for e in _paths:
		_ribbon(e["pts"], e.get("stub", false))
	_trail_litter(_brng)


func _build_trees() -> void:
	_trees(_brng)


func _build_undergrowth() -> void:
	_undergrowth(_brng)
	_forest_floor(_brng)


func _build_places() -> void:
	_clearings(_brng)
	for id in _labels:
		for way: Dictionary in _labels[id]:
			way["label"] = _sign(id, way["dir"], str(way["name"]))
			way["marks"] = _chevrons(id, way)


func _build_sky() -> void:
	var rng := _brng
	var to_sun := TO_SUN.normalized()
	var disc := MeshInstance3D.new()                      # the sun, seen from the ridge
	var ms := SphereMesh.new()
	ms.radius = 6.0
	ms.height = 12.0
	disc.mesh = ms
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color("fff6dc")
	dm.disable_fog = true
	disc.material_override = dm
	disc.position = node_pos("ridge") + to_sun * 260.0
	add_child(disc)
	_far_valley(rng)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe4b8")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	add_child(sun)
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5a86b4")
	sky.sky_horizon_color = Color("c4d4dc")
	sky.ground_bottom_color = Color("24342c")
	sky.ground_horizon_color = Color("6a8494")
	sky.sun_angle_max = 8.0
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("38506a")                 # the shade is blue
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("47637a")                     # and the distance is a blue haze
	env.fog_density = 0.016
	env.fog_sky_affect = 0.0
	env.fog_height = ORIGIN.y + node_pos("ridge").y - 9.0       # mist lies in the low ground; the ridge is above it
	env.fog_height_density = 0.06
	_sunbeams(rng, to_sun)
	cam.environment = env


func _build_nursery() -> void:
	cam.fov = 70.0
	cam.near = 0.08
	_pail = GardenProps.paint_bucket(self, Vector3.ZERO, 0.0)
	_pail.visible = false
	var way: Dictionary = _way_from("fork", "nursery")
	var e: Dictionary = _paths[int(way["edge"])]
	var pts: PackedVector3Array = e["pts"] if e["a"] == "fork" else _reversed(e["pts"])
	var arrive_dir := pts[pts.size() - 1] - pts[maxi(0, pts.size() - 6)]
	arrive_dir.y = 0.0
	nursery = preload("res://scripts/garden/nursery.gd").new()
	add_child(nursery)
	nursery.setup(self, node_pos("nursery"), arrive_dir.normalized())
	_place_finds()


func _way_from(from: String, to: String) -> Dictionary:
	for way: Dictionary in _labels[from]:
		if way["to"] == to:
			return way
	return {}


func _add_way(from: String, to: String, pts: PackedVector3Array, edge: int) -> void:
	_labels[from].append({"to": to, "dir": _dir_of(pts), "name": NODES[to]["name"], "edge": edge})


func _dir_of(pts: PackedVector3Array) -> Vector3:
	var d := pts[mini(4, pts.size() - 1)] - pts[0]
	d.y = 0.0
	return d.normalized()


func _reversed(pts: PackedVector3Array) -> PackedVector3Array:
	var out := pts.duplicate()
	out.reverse()
	return out


## A trail between two points: it wanders (two bends), and follows the ground up and down.
func _trail(a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> PackedVector3Array:
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var side := flat.orthogonal().normalized()
	var straight := flat.normalized() * minf(5.0, flat.length() * 0.2)   # leaves and arrives head-on
	var ctrl: Array[Vector2] = [Vector2(a.x, a.z) - flat * 0.2, Vector2(a.x, a.z), Vector2(a.x, a.z) + straight]
	for k in [0.38, 0.65]:
		ctrl.append(Vector2(a.x, a.z) + flat * k + side * rng.randf_range(-4.0, 4.0))
	ctrl.append(Vector2(b.x, b.z) - straight)
	ctrl.append(Vector2(b.x, b.z))
	ctrl.append(Vector2(b.x, b.z) + flat * 0.2)
	var out := PackedVector3Array()
	for i in range(1, ctrl.size() - 2):
		var p0 := ctrl[i - 1]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[i + 2]
		var steps := maxi(4, int(p1.distance_to(p2) / 0.8))
		for s in range(steps):
			var t := float(s) / steps
			var q := 0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			out.append(Vector3(q.x, maxf(height(q.x, q.y), water_at(q.x, q.y) + 0.12), q.y))   # over water: on the stones
	out.append(b)
	return out


const CELL := 2.0
var _cells := {}                      # Vector2i -> PackedVector2Array of trail points in that cell


## Trail points by 2 m cell, so "is this near a trail" looks at a few cells, not every point of every trail.
func _index_trails() -> void:
	_cells.clear()
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for i in range(0, pts.size(), 2):
			var c := Vector2i(floori(pts[i].x / CELL), floori(pts[i].z / CELL))
			if not _cells.has(c):
				_cells[c] = PackedVector2Array()
			(_cells[c] as PackedVector2Array).append(Vector2(pts[i].x, pts[i].z))


func _near_trail(p: Vector2, margin: float) -> bool:
	var r := ceili(margin / CELL)
	var c0 := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var pts = _cells.get(c0 + Vector2i(dx, dz))
			if pts == null:
				continue
			for q: Vector2 in pts:
				if q.distance_squared_to(p) < margin * margin:
					return true
	for id in NODES:
		if (NODES[id]["at"] as Vector2).distance_to(p) < margin + float(NODES[id].get("room", 3.5)):
			return true
	return false


func _ground(rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -60.0
	var z0 := -110.0
	var step := 1.6
	var nx := 76
	var nz := 85
	var moss := Color("2f3b25")
	var litter := Color("3d3022")
	var grid: Array = []
	for j in range(nz + 1):
		var row: Array = []
		for i in range(nx + 1):
			var x := x0 + i * step
			var z := z0 + j * step
			var c := moss.lerp(litter, clampf(0.5 + _fine.get_noise_2d(x * 2.0, z * 2.0) * 1.2, 0.0, 1.0)).darkened(rng.randf() * 0.08)
			row.append([Vector3(x, height(x, z), z), c])
		grid.append(row)
	for j in range(nz):
		for i in range(nx):
			for v in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				var cell: Array = grid[v[1]][v[0]]
				st.set_color(cell[1])
				st.add_vertex(cell[0])
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = m
	add_child(node)


## The worn dirt of a trail, laid over the ground (its edges a touch above it, so it never sinks in): a pale, packed
## middle where feet go, darker loose soil to each side, the edge wandering in and out; colour varies along it.
func _ribbon(pts: PackedVector3Array, faint: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.8 if not faint else 0.45
	var worn := Color("86704f")
	var loose := Color("54442f")
	var cols: Array = []                                  # across: edge, loose, worn, worn, loose, edge
	var offs := [-1.0, -0.55, -0.18, 0.18, 0.55, 1.0]
	var prev: Array = []
	for i in pts.size():
		var a := pts[maxi(0, i - 1)]
		var b := pts[mini(pts.size() - 1, i + 1)]
		var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := d.cross(Vector3.UP)
		var wobble := 1.0 + 0.18 * sin(i * 0.7) + 0.12 * _fine.get_noise_2d(pts[i].x * 3.0, pts[i].z * 3.0)
		var tint := 0.08 * _fine.get_noise_2d(pts[i].x * 1.7 + 50.0, pts[i].z * 1.7)
		var row: Array = []
		for k in offs.size():
			var o: float = offs[k] * w * (wobble if absf(offs[k]) > 0.9 else 1.0)
			var v := pts[i] + side * o
			v.y = maxf(height(v.x, v.z), pts[i].y - 0.3) + 0.05 + (0.01 if absf(offs[k]) < 0.5 else 0.0)
			var c: Color = worn if absf(offs[k]) < 0.3 else (loose if absf(offs[k]) < 0.9 else loose.darkened(0.15))
			row.append([v, c.lightened(tint) if tint > 0.0 else c.darkened(-tint)])
		if not prev.is_empty():
			for k in range(offs.size() - 1):
				for q in [prev[k], row[k], row[k + 1], prev[k], row[k + 1], prev[k + 1]]:
					st.set_color(q[1])
					st.add_vertex(q[0])
		prev = row
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = m
	add_child(node)


## Along every trail: pebbles, fallen leaves (it's autumn), and now and then a root across the path.
func _trail_litter(rng: RandomNumberGenerator) -> void:
	var pebbles: Array = []
	var leaves: Array = []
	var roots: Array = []
	var autumn := [Color("b8702e"), Color("c9923c"), Color("9a5426"), Color("a8402a"), Color("c8a848"), Color("7a6a30")]
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for i in range(1, pts.size() - 1):
			var a := pts[i - 1]
			var b := pts[i + 1]
			var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
			var side := d.cross(Vector3.UP)
			for k in range(3):
				var o := side * rng.randf_range(-1.1, 1.1) + d * rng.randf_range(-0.4, 0.4)
				var p := pts[i] + o
				var y := maxf(height(p.x, p.z), pts[i].y - 0.3) + 0.06
				if rng.randf() < 0.55:
					var sz := rng.randf_range(0.03, 0.08)
					pebbles.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(sz, sz * 0.6, sz * 0.8)), Vector3(p.x, y, p.z)), Color("8a867c").darkened(rng.randf() * 0.3)])
				var lz := rng.randf_range(0.05, 0.09)
				leaves.append([Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3(lz, 0.006, lz * 1.4)), Vector3(p.x, y + 0.005, p.z)), autumn.pick_random()])
			if rng.randf() < 0.07:                             # a root across the path
				var yaw := atan2(side.x, side.z)
				roots.append([Transform3D(Basis.from_euler(Vector3(0, yaw, PI * 0.5)).scaled(Vector3(0.05, 1.9, 0.05)), pts[i] + Vector3(0, 0.07, 0)), Color("4a3a2a")])
	var pebble := SphereMesh.new()
	pebble.radius = 1.0
	pebble.height = 2.0
	pebble.radial_segments = 6
	pebble.rings = 3
	var leaf := SphereMesh.new()
	leaf.radius = 1.0
	leaf.height = 2.0
	leaf.radial_segments = 5
	leaf.rings = 2
	var root := CylinderMesh.new()
	root.top_radius = 0.6
	root.bottom_radius = 1.0
	root.height = 1.0
	root.radial_segments = 6
	root.rings = 1
	_multimesh(pebble, pebbles)
	_multimesh(leaf, leaves)
	_multimesh(root, roots)


func _trees(rng: RandomNumberGenerator) -> void:
	var trunks: Array = []
	var crowns: Array = []
	var cones: Array = []
	for k in range(900):
		var p := Vector2(rng.randf_range(-58, 58), rng.randf_range(-108, 16))
		if _near_trail(p, 2.6) or _keep_open(p, rng):
			continue
		var y := height(p.x, p.y)
		var tall := rng.randf_range(8.0, 17.0)
		var girth := rng.randf_range(0.8, 2.0)
		trunks.append([Transform3D(Basis().scaled(Vector3(girth, tall, girth)), Vector3(p.x, y - 0.4 + tall * 0.5, p.y)), Color("3a2c22").lerp(Color("4a3e34"), rng.randf())])
		if rng.randf() < 0.45:                           # a pine: three narrowing tiers up a tall trunk
			for c in range(3):
				var s := rng.randf_range(1.9, 2.5) * (1.0 - c * 0.25)
				cones.append([Transform3D(Basis().scaled(Vector3(s, s * 2.4, s)), Vector3(p.x, y + tall * (0.42 + c * 0.2) + s * 1.2, p.y)), Color("23402c").lerp(Color("2e4a2a"), rng.randf())])
		elif _leafy < LEAFY_MAX and _near_trail(p, 11.0):    # near the trails: real leaves, like the hedgepets'
			_leafy += 1
			for c in range(rng.randi_range(2, 3)):
				var s := rng.randf_range(1.1, 1.7)
				var off := Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.5), rng.randf_range(-1.5, 1.5))
				var crown: Node3D = _crown_template(rng.randi_range(0, CROWNS.size() - 1)).duplicate()
				crown.visible = true
				crown.position = Vector3(p.x, y + tall, p.y) + off
				crown.scale = Vector3(s, s * 0.85, s)
				crown.rotation.y = rng.randf() * TAU
				add_child(crown)
		else:
			for c in range(rng.randi_range(2, 3)):
				var s := rng.randf_range(2.6, 4.4)
				var off := Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.5), rng.randf_range(-1.5, 1.5))
				crowns.append([Transform3D(Basis().scaled(Vector3(s, s * 0.8, s)), Vector3(p.x, y + tall, p.y) + off), Color("2e4424").lerp(Color("5a4a22"), rng.randf() * 0.5)])
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.26
	trunk.height = 1.0
	trunk.radial_segments = 8
	trunk.rings = 1
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 10
	crown.rings = 6
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 9
	cone.rings = 1
	_multimesh(trunk, trunks)
	_multimesh(crown, crowns)
	_multimesh(cone, cones)
	_willows(rng)


## Leafy crowns: a few made once with the hedgepets' foliage (fixed seeds, so they bake), shared by every tree near a
## trail. [leaf sheet, palette].
const CROWNS := [["hedgeoak", "autumn"], ["hedgemaple", "crimson"], ["hedgeoak", "green"], ["hedgemaple", "autumn"],
	["hedgeivy", "green"], ["hedgeboxwood", "spring"]]
const LEAFY_MAX := 110
var _leafy := 0
var _crowns: Array = []


func _crown_template(i: int, sheet := "", palette := "", radii := Vector3(2.4, 1.9, 2.4)) -> Node3D:
	if sheet == "":
		while _crowns.size() <= i:
			_crowns.append(null)
		if _crowns[i] != null:
			return _crowns[i]
		sheet = CROWNS[i][0]
		palette = CROWNS[i][1]
	var pal := SpeciesBuilder.palette_of(palette)
	var inner := Color(SpeciesBuilder.PALETTES[palette][6])
	var t: Node3D = garden._bush(Vector3.ZERO, radii, sheet, pal, inner, 0.7, 0.9, "dome", 0.0, Color(1.0, 0.98, 0.92), 9100 + i)
	t.reparent(self, false)
	t.visible = false
	if i < _crowns.size():
		_crowns[i] = t
	return t


## Weeping willows on the creek banks and round the pond: a leaning trunk, a soft crown of willow leaves, and long
## strands hanging almost to the ground, swaying.
var _willows_sway: Array = []


func _willows(rng: RandomNumberGenerator) -> void:
	var spots: Array = []
	for along: float in [-52.0, -30.0, -9.0, 14.0, 33.0, 55.0]:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		spots.append(_creek_point(along + rng.randf_range(-3, 3)) + CREEK_DIR.orthogonal() * side * rng.randf_range(3.6, 4.6))
	for k in range(2):
		spots.append(POND_AT + Vector2.from_angle(k * PI + 0.6) * (POND_R + 2.6))
	var crown_t := _crown_template(99, "hedgewillow", "spring", Vector3(2.2, 1.5, 2.2))
	var strand := CylinderMesh.new()
	strand.top_radius = 0.03
	strand.bottom_radius = 0.012
	strand.height = 1.0
	strand.radial_segments = 4
	strand.rings = 1
	for p: Vector2 in spots:
		if _near_trail(p, 2.2):
			continue
		var y := height(p.x, p.y)
		var tall := rng.randf_range(5.5, 7.0)
		var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		GardenProps.part(self, GardenProps.cyl(0.22, 0.38, tall, 9), GardenProps.mat("willowbark", Color("5a4c3a")), Vector3(p.x, y + tall * 0.5 - 0.2, p.y), Vector3(rad_to_deg(lean.z), 0, rad_to_deg(-lean.x)), 0.012)
		var top := Vector3(p.x, y + tall, p.y) + lean * tall
		var crown: Node3D = crown_t.duplicate()
		crown.visible = true
		crown.position = top
		add_child(crown)
		var hang := Node3D.new()                           # the curtain of strands, swaying as one
		hang.position = top
		add_child(hang)
		var items: Array = []
		for k in range(70):
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.2, 2.6)
			var len := rng.randf_range(2.0, tall - 1.2)
			var at := Vector3(cos(a) * r, -rng.randf_range(0.2, 0.9) - len * 0.5, sin(a) * r)
			items.append([Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))).scaled(Vector3(1.6, len, 1.6)), at), Color("9ab452").lerp(Color("6a8a3a"), rng.randf())])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = strand
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hang.add_child(mi)
		hang.set_meta("phase", rng.randf() * TAU)
		_willows_sway.append(hang)


## What lies about under the trees, off the trails: fallen logs with moss on them, old stumps, mossy boulders, and
## clusters of mushrooms.
func _forest_floor(rng: RandomNumberGenerator) -> void:
	var logs: Array = []
	var mossy: Array = []
	var stumps: Array = []
	var stones: Array = []
	var stems: Array = []
	var caps: Array = []
	var tries := 0
	var placed := 0
	while placed < 170 and tries < 3000:
		tries += 1
		var p := Vector2(rng.randf_range(-56, 56), rng.randf_range(-106, 14))
		if _near_trail(p, 1.8) or not _near_trail(p, 14.0) or _keep_open(p, rng):
			continue
		placed += 1
		var y := height(p.x, p.y)
		var kind := rng.randf()
		if kind < 0.22:
			var len := rng.randf_range(2.0, 4.5)
			var r := rng.randf_range(0.18, 0.32)
			var yaw := rng.randf() * TAU
			var b := Basis.from_euler(Vector3(0, yaw, PI * 0.5))
			logs.append([Transform3D(b.scaled(Vector3(r, len, r)), Vector3(p.x, y + r * 0.7, p.y)), Color("4a3a2c").lerp(Color("5a4a38"), rng.randf())])
			mossy.append([Transform3D(Basis.from_euler(Vector3(0, yaw + PI * 0.5, 0)).scaled(Vector3(r * 1.1, r * 0.45, len * 0.35)), Vector3(p.x, y + r * 1.5, p.y)), Color("4e6e30").lerp(Color("6a7a34"), rng.randf())])
		elif kind < 0.4:
			var r := rng.randf_range(0.25, 0.45)
			var h := rng.randf_range(0.25, 0.6)
			stumps.append([Transform3D(Basis().scaled(Vector3(r, h, r)), Vector3(p.x, y + h * 0.5 - 0.05, p.y)), Color("5a4634")])
			mossy.append([Transform3D(Basis().scaled(Vector3(r * 0.95, r * 0.25, r * 0.95)), Vector3(p.x, y + h, p.y)), Color("5a7a34")])
		elif kind < 0.65:
			var sz := rng.randf_range(0.4, 1.1)
			stones.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(sz, sz * 0.6, sz * 0.8)), Vector3(p.x, y + sz * 0.2, p.y)), Color("7e7a70").darkened(rng.randf() * 0.25)])
			mossy.append([Transform3D(Basis().scaled(Vector3(sz * 0.85, sz * 0.22, sz * 0.7)), Vector3(p.x, y + sz * 0.62, p.y)), Color("4e6e30")])
		else:
			var cap := Color("a8583a") if rng.randf() < 0.6 else (Color("d8c8a0") if rng.randf() < 0.6 else Color("c8402e"))
			for k in range(rng.randi_range(3, 7)):
				var q := p + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
				var qy := height(q.x, q.y)
				var h := rng.randf_range(0.05, 0.14)
				stems.append([Transform3D(Basis().scaled(Vector3(0.018, h, 0.018)), Vector3(q.x, qy + h * 0.5, q.y)), Color("e8dcc4")])
				var w := rng.randf_range(0.04, 0.08)
				caps.append([Transform3D(Basis().scaled(Vector3(w, w * 0.45, w)), Vector3(q.x, qy + h, q.y)), cap.darkened(rng.randf() * 0.15)])
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	_multimesh(cyl, logs)
	_multimesh(cyl, stumps)
	_multimesh(ball, mossy)
	_multimesh(ball, stones)
	_multimesh(cyl, stems)
	_multimesh(ball, caps)


## Where no tree grows: in the creek, in the ridge's view (a few deep below, their tops under you), round the old oak.
func _keep_open(p: Vector2, rng: RandomNumberGenerator) -> bool:
	if absf(_creek_lat(p)) < 3.4 and absf((p - CREEK_AT).dot(CREEK_DIR)) < 80.0:
		return true
	var rv := p - (NODES["ridge"]["at"] as Vector2)
	var s := rv.dot(VIEW_DIR)
	if s > 1.0 and absf(rv.dot(VIEW_DIR.orthogonal())) < 7.0 + s * 0.9:
		return s < 20.0 or rng.randf() < 0.75
	if p.distance_to(POND_AT) < POND_R + 2.0 or p.distance_to(CELLAR_AT) < 6.5:
		return true
	return p.distance_to(_oak_at()) < 13.0


func _oak_at() -> Vector2:
	return (NODES["oak"]["at"] as Vector2) + Vector2(1.0, -7.0)     # north of the clearing, clear of both its trails


func _multimesh(mesh: Mesh, items: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = m
	add_child(node)


## Ferns and long grass along the trails and round the clearings: the garden's own tufts, darker and bigger.
func _undergrowth(rng: RandomNumberGenerator) -> void:
	var grass: GeometryInstance3D = garden.get_node_or_null("Grass")
	if grass == null:
		return
	var buf := PackedFloat32Array()
	var n := 0
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for i in pts.size():
			for k in range(5):
				var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(1.0, 3.5)
				var p := Vector2(pts[i].x, pts[i].z) + off
				var s := rng.randf_range(0.6, 1.1)
				var b := Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)).scaled(Vector3(s * 1.3, s * rng.randf_range(0.9, 1.3), s * 1.3))
				var o := Vector3(p.x, height(p.x, p.y) - 0.05, p.y)
				var c := Color("6a8a4a").lerp(Color("8a8a50"), rng.randf() * 0.5)
				buf.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, c.r, c.g, c.b, 1.0, float(rng.randi_range(0, 7)), rng.randf() * TAU, 0.0, 0.0])
				n += 1
	var hollow: Vector2 = NODES["hollow"]["at"]
	for k in range(260):                                  # fern hollow: ferns everywhere but the path
		var p := hollow + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(3.0, 13.0)
		if _near_trail(p, 1.2) and p.distance_to(hollow) > 3.0 and rng.randf() < 0.7:
			continue
		var s := rng.randf_range(0.9, 1.6)
		var b := Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)).scaled(Vector3(s * 1.5, s * rng.randf_range(1.0, 1.4), s * 1.5))
		var o := Vector3(p.x, height(p.x, p.y) - 0.05, p.y)
		var c := Color("4e7a3a").lerp(Color("6a8a44"), rng.randf())
		buf.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, c.r, c.g, c.b, 1.0, float(rng.randi_range(0, 7)), rng.randf() * TAU, 0.0, 0.0])
		n += 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = (grass as MultiMeshInstance3D).multimesh.mesh
	mm.instance_count = n
	mm.buffer = buf
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = grass.material_override
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## Each clearing: a lantern on its hook (warm light), a few rocks and logs; fireflies drifting; its own landmark.
func _clearings(rng: RandomNumberGenerator) -> void:
	var fly := StandardMaterial3D.new()
	fly.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fly.albedo_color = Color("fff2cc")                          # motes, drifting (daytime: not fireflies)
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	for id in NODES:
		var c := node_pos(id)
		var a := rng.randf() * TAU
		if id == "nursery":                              # it has its own lamps and things (nursery.gd)
			continue
		var spot := _clear_spot(c, 3.0, rng)
		if id == "ridge":                                # behind you, not in the view
			spot = c - Vector3(VIEW_DIR.x, 0, VIEW_DIR.y) * 3.0 + Vector3(VIEW_DIR.orthogonal().x, 0, VIEW_DIR.orthogonal().y) * 1.5
			spot.y = height(spot.x, spot.z)
		elif id == "oak":
			spot = c + (c - Vector3(_oak_at().x, c.y, _oak_at().y)).normalized() * 2.5
			spot.y = height(spot.x, spot.z)
		GardenProps.lantern(self, spot, rad_to_deg(a))
		var light := OmniLight3D.new()
		light.light_color = Color("ffbe72")
		light.light_energy = 0.45                                  # lit, but it's daytime: a little warmth in the shade
		light.omni_range = 6.0
		light.position = spot + Vector3(0, 1.4, 0)
		add_child(light)
		for k in range(3):
			var r := _clear_spot(c, rng.randf_range(4.0, 6.5), rng)
			GardenProps.rock(self, r + Vector3(0, -0.1, 0), snappedf(rng.randf_range(0.5, 1.1), 0.1), rng)
		var log := _clear_spot(c, rng.randf_range(4.0, 6.0), rng)
		GardenProps.part(self, GardenProps.cyl(0.28, 0.32, rng.randf_range(2.4, 3.6), 9), GardenProps.mat("woodslog", Color("4a3a2a")), log + Vector3(0, 0.25, 0), Vector3(90, rng.randf_range(0, 180), 0), 0.012)
		for k in range(10):
			var f := MeshInstance3D.new()
			f.mesh = dot
			f.material_override = fly
			f.position = c + Vector3(rng.randf_range(-6, 6), rng.randf_range(0.5, 2.6), rng.randf_range(-6, 6))
			f.set_meta("home", f.position)
			f.set_meta("phase", rng.randf() * TAU)
			add_child(f)
			_fireflies.append(f)
	_old_oak(rng)
	_creek(rng)
	_ridge(rng)
	_mossy_fork(rng)
	_trailhead_board()
	_pond(rng)
	_cellar_hole(rng)
	var camp := node_pos("hollow") + Vector3(2.6, 0, -1.8)     # a ring of stones in fern hollow: tap it to light it
	camp.y = height(camp.x, camp.z)
	campfire = preload("res://scripts/garden/fire_pit.gd").build(self, camp, 0.0)


func _clear_spot(c: Vector3, r: float, rng: RandomNumberGenerator) -> Vector3:
	for k in range(30):
		var a := rng.randf() * TAU
		var p := Vector2(c.x + cos(a) * r, c.z + sin(a) * r)
		var on_way := false
		for e in _paths:
			var pts: PackedVector3Array = e["pts"]
			for i in range(0, pts.size(), 2):
				if Vector2(pts[i].x, pts[i].z).distance_to(p) < 1.6:
					on_way = true
					break
			if on_way:
				break
		if not on_way:
			return Vector3(p.x, height(p.x, p.y), p.y)
	return c + Vector3(r, 0, 0)


func _brambles(at: Vector3, rng: RandomNumberGenerator) -> void:
	var bramble := GardenProps.mat("bramble", Color("2a3320"))
	for k in range(9):
		var p := at + Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))
		GardenProps.part(self, GardenProps.blob(Vector3(0.9, 0.7, 0.9) * snappedf(rng.randf_range(0.7, 1.3), 0.1), "pebble"), bramble, Vector3(p.x, height(p.x, p.z) + 0.3, p.z), Vector3(0, rng.randf_range(0, 360), 0), 0.012)


## A wooden arrow sign at the mouth of a trail: a post beside the path, and a painted board turned to face the
## clearing, its pointed end aimed down the trail. Returns the painted name (the one you're facing reads brighter).
func _sign(from: String, dir: Vector3, text: String) -> Label3D:
	var c := node_pos(from)
	var right := dir.cross(Vector3.UP).normalized()
	var at := c + dir * 4.2 - right * 1.25
	at.y = height(at.x, at.z)
	var holder := Node3D.new()
	holder.name = "Sign"
	add_child(holder)
	holder.position = at
	var face := Vector3(c.x - at.x, 0, c.z - at.z).normalized()
	holder.rotation.y = atan2(face.x, face.z) + deg_to_rad(32.0)   # facing you, its right-hand point swung down the trail
	var post := GardenProps.mat("signpost", Color("5a4432"))
	var board := GardenProps.mat("signboard", Color("7a5c3e"))
	var w := clampf(0.3 + text.length() * 0.08, 0.9, 1.9)
	GardenProps.part(holder, GardenProps.cyl(0.05, 0.06, 1.75, 7), post, Vector3(-w * 0.5 + 0.12, 0.85, -0.05), Vector3(0, 0, -2), 0.008)
	GardenProps.part(holder, GardenProps.box(Vector3(w, 0.32, 0.045)), board, Vector3(0.0, 1.45, 0), Vector3(0, 0, 1.5), 0.01)
	GardenProps.part(holder, GardenProps.box(Vector3(0.2, 0.2, 0.045)), board, Vector3(w * 0.5, 1.45 + w * 0.5 * 0.026, 0), Vector3(0, 0, 45 + 1.5), 0.01)
	var paint := Color(0.78, 0.7, 0.54)
	var front := Label3D.new()
	front.text = text
	front.font_size = 44
	front.outline_size = 0
	front.pixel_size = 0.0041
	front.modulate = paint
	front.position = Vector3(-0.02, 1.45 + 0.0, 0.026)
	front.rotation_degrees.z = 1.5
	holder.add_child(front)
	var back := front.duplicate() as Label3D                # painted on both sides
	back.position.z = -0.026
	back.rotation_degrees.y = 180.0
	holder.add_child(back)
	front.set_meta("back", back)
	return front


## Three chevrons on the ground at the start of a trail, pointing along it: they glow on the one you're facing (the
## one a tap will take you down).
func _chevrons(from: String, way: Dictionary) -> Dictionary:
	var pts := PackedVector3Array()
	if way.has("edge"):
		var e: Dictionary = _paths[int(way["edge"])]
		pts = e["pts"] if e["a"] == from else _reversed(e["pts"])
	else:
		var c := node_pos(from)
		for k in range(12):
			var q: Vector3 = c + way["dir"] * (k * 0.6)
			pts.append(Vector3(q.x, height(q.x, q.z), q.z))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.94, 0.76, 0.0)
	m.no_depth_test = false
	var bar := BoxMesh.new()
	bar.size = Vector3(0.07, 0.02, 0.5)
	for want: float in [2.6, 3.7, 4.8]:
		var acc := 0.0
		for i in range(1, pts.size()):
			var seg := pts[i].distance_to(pts[i - 1])
			if acc + seg >= want:
				var at := pts[i - 1].lerp(pts[i], (want - acc) / maxf(seg, 0.001))
				var d := pts[i] - pts[i - 1]
				var chev := Node3D.new()
				chev.position = at + Vector3(0, 0.1, 0)
				chev.rotation.y = atan2(d.x, d.z)
				add_child(chev)
				for sgn: float in [-1.0, 1.0]:
					var arm := MeshInstance3D.new()
					arm.mesh = bar
					arm.material_override = m
					arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					arm.rotation.y = -sgn * deg_to_rad(38.0)            # a ^ pointing along the trail
					arm.position = Vector3(sgn * 0.15, 0, -0.12)
					chev.add_child(arm)
				break
			acc += seg
	return {"mat": m}


# ------------------------------------------------------------------ the landmarks
## The old oak: one enormous tree alone in its glade - a flared trunk with roots over the ground, a hollow, great
## limbs going out sideways, a crown wider than the clearing. A lantern hangs from it.
func _old_oak(rng: RandomNumberGenerator) -> void:
	var p := _oak_at()
	var at := Vector3(p.x, height(p.x, p.y) - 0.2, p.y)
	var bark := GardenProps.mat("oldoak", Color("4a3c30"))
	var r := GardenProps.root(self, "OldOak", at, rng.randf() * 360.0)
	GardenProps.part(r, GardenProps.cyl(1.15, 1.9, 7.5, 16), bark, Vector3(0, 3.75, 0), Vector3(0, 0, 3), 0.025)
	GardenProps.part(r, GardenProps.blob(Vector3(2.5, 1.0, 2.5), {"exponent": 2.0, "flat_bottom": 0.6}), bark, Vector3(0, 0.4, 0), Vector3.ZERO, 0.02)
	for k in range(7):                                    # roots over the ground
		var a := k * TAU / 7.0 + rng.randf_range(-0.2, 0.2)
		var len := rng.randf_range(2.2, 3.4)
		GardenProps.part(r, GardenProps.blob(Vector3(len, 0.38, 0.5), {"exponent": 2.0, "taper": 0.5}), bark, Vector3(cos(a), 0.0, sin(a)) * (1.4 + len * 0.45) + Vector3(0, 0.15, 0), Vector3(0, -rad_to_deg(a), -6), 0.015)
	for k in range(14):                                   # deep furrowed bark
		var a := k * TAU / 14.0 + rng.randf_range(-0.1, 0.1)
		var ridge := GardenProps.part(r, GardenProps.blob(Vector3(0.22, 3.4, 0.22), {"exponent": 2.0}), GardenProps.mat("oakridge", Color("3e3228")), Vector3(cos(a) * 1.45, 3.4, sin(a) * 1.45), Vector3(0, 0, 0), 0.0)
		ridge.rotation = Vector3(sin(a) * 0.08, 0, -cos(a) * 0.08)
	GardenProps.part(r, GardenProps.blob(Vector3(0.42, 0.7, 0.3), {"exponent": 2.0}), GardenProps.mat("oakhollow", Color("120e0a")), Vector3(0, 1.7, 1.62), Vector3(-6, 0, 0), 0.0)
	var crown := GardenProps.mat("oakcrown", Color("2e3c20"))
	var rust := GardenProps.mat("oakcrown2", Color("5a4a22"))
	for k in range(6):                                    # the great limbs, each with its own mass of leaves
		var a := k * TAU / 6.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var limb := GardenProps.part(r, GardenProps.cyl(0.28, 0.7, 7.0, 10), bark, Vector3(0, 7.0, 0) + out * 2.6 + Vector3(0, 1.6, 0), Vector3.ZERO, 0.015)
		limb.look_at_from_position(limb.position, limb.position + out * 0.8 + Vector3(0, 0.6, 0), Vector3.UP)
		limb.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		var tip := Vector3(0, 9.5, 0) + out * rng.randf_range(6.0, 7.5)
		GardenProps.part(r, GardenProps.blob(Vector3(4.2, 2.6, 4.2) * snappedf(rng.randf_range(0.85, 1.1), 0.05), {"exponent": 2.0}), crown if k % 3 else rust, tip, Vector3(0, rng.randf() * 360, 0), 0.0)
	GardenProps.part(r, GardenProps.blob(Vector3(7.5, 4.0, 7.5), {"exponent": 2.0}), crown, Vector3(0, 12.5, 0), Vector3.ZERO, 0.0)


## The creek: water in its channel the whole way through the woods, rocks and cattails on the banks, and stepping
## stones where the trails cross it.
func _creek(rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := CREEK_DIR.orthogonal()
	var prev: Array = []
	for i in range(-72, 73):
		var c := _creek_point(float(i))
		var y := height(c.x, c.y) + 0.72
		var l := c + side * 1.95
		var r := c - side * 1.95
		var row := [Vector3(l.x, y, l.y), Vector3(r.x, y, r.y)]
		if not prev.is_empty():
			for v in [prev[0], row[0], row[1], prev[0], row[1], prev[1]]:
				st.add_vertex(v)
		prev = row
	st.generate_normals()
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.3, 0.36, 0.92)       # dark water with the moon on it
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic_specular = 1.0
	water.emission_enabled = true
	water.emission = Color("0c161c")
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = water
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	for i in range(-70, 71, 3):                           # the banks
		for sgn: float in [-1.0, 1.0]:
			if rng.randf() < 0.45:
				var b := _creek_point(i + rng.randf_range(-1, 1)) + side * sgn * rng.randf_range(2.1, 2.8)
				if not _near_trail(b, 1.4):
					GardenProps.rock(self, Vector3(b.x, height(b.x, b.y) - 0.15, b.y), snappedf(rng.randf_range(0.35, 0.7), 0.1), rng)
			elif rng.randf() < 0.3:
				var b := _creek_point(i + rng.randf_range(-1, 1)) + side * sgn * rng.randf_range(1.6, 2.2)
				if not _near_trail(b, 1.4):
					GardenProps.cattails(self, Vector3(b.x, height(b.x, b.y), b.y), rng)
	var stone := GardenProps.mat("stepstone0", Color("7a7a72"))
	for e in _paths:                                      # stepping stones where a trail crosses
		var pts: PackedVector3Array = e["pts"]
		for i in range(pts.size()):
			var q := Vector2(pts[i].x, pts[i].z)
			var along := (q - CREEK_AT).dot(CREEK_DIR)
			if absf(_creek_lat(q)) < 2.1 and absf(along) < 72.0:
				var mid := _creek_point(along)
				var y := height(mid.x, mid.y) + 0.78
				GardenProps.part(self, GardenProps.blob(Vector3(0.42, 0.14, 0.34), "pebble"), stone, Vector3(pts[i].x, y, pts[i].z), Vector3(0, rng.randf_range(0, 180), 0), 0.006)


## The ridge: flat lichened rocks at the edge, a weathered bench looking out, a cairn.
func _ridge(rng: RandomNumberGenerator) -> void:
	var c: Vector2 = NODES["ridge"]["at"]
	var side := VIEW_DIR.orthogonal()
	var lichen := GardenProps.mat("lichenrock", Color("8a8c80"))
	for k in range(7):
		var p := c + VIEW_DIR * rng.randf_range(4.0, 6.0) + side * (k - 3) * 1.6
		GardenProps.part(self, GardenProps.blob(Vector3(1.0, 0.35, 0.8) * snappedf(rng.randf_range(0.8, 1.3), 0.1), {"exponent": 2.6, "flat_bottom": 0.5}), lichen, Vector3(p.x, height(p.x, p.y) - 0.1, p.y), Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 360), 0), 0.012)
	var bench_at := c + VIEW_DIR * 1.2 + side * 2.4
	var bench := GardenProps.root(self, "RidgeBench", Vector3(bench_at.x, height(bench_at.x, bench_at.y), bench_at.y), rad_to_deg(atan2(VIEW_DIR.x, VIEW_DIR.y)))
	var grey := GardenProps.mat("greywood", Color("6e665a"))
	GardenProps.part(bench, GardenProps.box(Vector3(1.6, 0.06, 0.4)), grey, Vector3(0, 0.45, 0), Vector3.ZERO, 0.008)
	GardenProps.part(bench, GardenProps.box(Vector3(1.6, 0.3, 0.05)), grey, Vector3(0, 0.72, -0.2), Vector3(-10, 0, 0), 0.008)
	for sx: float in [-0.7, 0.7]:
		GardenProps.part(bench, GardenProps.box(Vector3(0.07, 0.45, 0.35)), grey, Vector3(sx, 0.22, 0), Vector3.ZERO, 0.006)
	var cairn := c - side * 3.0 + VIEW_DIR * 2.0
	var cy := height(cairn.x, cairn.y)
	for k in range(5):
		var w := 0.42 - k * 0.07
		GardenProps.part(self, GardenProps.blob(Vector3(w, 0.11, w * 0.85), "pebble"), lichen, Vector3(cairn.x, cy + 0.1 + k * 0.19, cairn.y), Vector3(0, rng.randf_range(0, 360), 0), 0.006)


## What you see from the ridge, past the end of the woods: the valley floor, low hills one behind another, a few porch
## lights.
func _far_valley(rng: RandomNumberGenerator) -> void:
	var r := node_pos("ridge")
	var base := r.y - 20.0
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	floor.mesh = plane
	floor.material_override = GardenProps.mat("valleyfloor", Color("2a3a2c"))
	floor.position = Vector3(r.x, base, r.z)
	add_child(floor)
	var heading := atan2(VIEW_DIR.y, VIEW_DIR.x)
	for k in range(14):                                   # hills one behind another, paler with distance (no fog: by hand)
		var far := float(k) / 13.0
		var a := heading + rng.randf_range(-1.0, 1.0)
		var d := lerpf(80.0, 360.0, far) + rng.randf_range(-15.0, 15.0)
		var size := lerpf(40.0, 120.0, far) * rng.randf_range(0.8, 1.2)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("2c4034").lerp(Color("9cb0bc"), far * 0.85)   # paler and bluer with distance
		m.roughness = 1.0
		m.disable_fog = true
		var h := MeshInstance3D.new()
		h.mesh = GardenProps.blob(Vector3(size, size * rng.randf_range(0.3, 0.45), size * 0.7), {"exponent": 2.0}, 10, 18)
		h.material_override = m
		h.position = Vector3(r.x + cos(a) * d, base - size * 0.12, r.z + sin(a) * d)
		h.rotation.y = rng.randf() * TAU
		add_child(h)
	var mist := StandardMaterial3D.new()                  # mist lying in the valley
	mist.albedo_color = Color(0.62, 0.68, 0.72, 0.22)
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.disable_fog = true
	for k in range(3):
		var sheet := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(900, 900)
		sheet.mesh = pm
		sheet.material_override = mist
		sheet.position = Vector3(r.x, base + 3.0 + k * 2.5, r.z) + Vector3(VIEW_DIR.x, 0, VIEW_DIR.y) * 470.0
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sheet)


## Where the sun gets through: a slanting beam (two crossed cards, the garden's light-shaft shader, stronger). A couple near most clearings (off to the side, never in your face), more along
## the trails.
func _sunbeams(rng: RandomNumberGenerator, to_sun: Vector3) -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/light_shaft.gdshader")
	var spots: Array = []
	for id in NODES:
		for k in range(2 if id != "nursery" else 1):
			var c: Vector2 = NODES[id]["at"]
			spots.append(c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 8.0))
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for i in range(6, pts.size() - 6, 14):
			if rng.randf() < 0.6:
				spots.append(Vector2(pts[i].x, pts[i].z) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)))
	var side := to_sun.cross(Vector3.FORWARD if absf(to_sun.z) < 0.9 else Vector3.RIGHT).normalized()
	for p: Vector2 in spots:
		var at := Vector3(p.x, height(p.x, p.y), p.y)
		var beam := Node3D.new()
		beam.name = "Sunbeam"
		add_child(beam)
		beam.position = at
		beam.basis = Basis(side, to_sun, side.cross(to_sun).normalized())
		var mi := m.duplicate() as ShaderMaterial
		mi.set_shader_parameter("seed", rng.randf())
		mi.set_shader_parameter("strength", rng.randf_range(0.02, 0.032))
		mi.set_shader_parameter("colour", Color("ffe6b4"))
		var w := rng.randf_range(0.8, 2.0)
		for k in range(2):
			var card := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(w, 20.0)
			card.mesh = q
			card.material_override = mi
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			card.rotation.y = k * PI * 0.5
			card.position = Vector3(0, 10.0, 0)
			beam.add_child(card)
		for k in range(4):                                # motes, turning slowly in the light
			_fireflies.append(_mote(at + to_sun * rng.randf_range(0.8, 3.5) + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), rng))


func _mote(at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var f := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.018
	dot.height = 0.036
	dot.radial_segments = 4
	dot.rings = 2
	f.mesh = dot
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("fff2cc")
	f.material_override = m
	f.position = at
	f.set_meta("home", at)
	f.set_meta("phase", rng.randf() * TAU)
	add_child(f)
	return f


func _stars(rng: RandomNumberGenerator) -> void:
	var items: Array = []
	var c := node_pos("ridge")
	for k in range(260):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.12, 1.0), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(0.25, 0.7)
		items.append([Transform3D(Basis().scaled(Vector3.ONE * s), c + dir * 300.0), Color(1, 1, 0.94).lerp(Color("c8d4ff"), rng.randf())])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var dot := SphereMesh.new()
	dot.radius = 1.0
	dot.height = 2.0
	dot.radial_segments = 6
	dot.rings = 3
	mm.mesh = dot
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## The mossy fork: boulders gone green on top.
func _mossy_fork(rng: RandomNumberGenerator) -> void:
	var c := node_pos("fork")
	var moss := GardenProps.mat("forkmoss", Color("4e6e30"))
	for k in range(6):
		var p := _clear_spot(c, rng.randf_range(3.8, 6.0), rng)
		var size := snappedf(rng.randf_range(0.7, 1.4), 0.1)
		GardenProps.rock(self, p - Vector3(0, 0.2, 0), size, rng)
		GardenProps.part(self, GardenProps.blob(Vector3(size * 0.9, size * 0.28, size * 0.7), {"exponent": 2.2}), moss, p + Vector3(0, size * 0.42, 0), Vector3(0, rng.randf_range(0, 360), 0), 0.006)


## Beaver pond: still water in a bowl, the lodge (a dome of sticks and mud) out in it, a dam of sticks across the low
## end, lily pads, cattails round the edge, a few gnawed stumps.
func _pond(rng: RandomNumberGenerator) -> void:
	var y := pond_level()
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.3, 0.36, 0.92)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic_specular = 1.0
	water.emission_enabled = true
	water.emission = Color("0c161c")
	var disc := GardenProps.part(self, GardenProps.cyl(POND_R + 0.6, POND_R + 0.6, 0.04, 32), water, Vector3(POND_AT.x, y, POND_AT.y), Vector3.ZERO, 0.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sticks := GardenProps.mat("lodgesticks", Color("5a4a36"))
	var lodge := Vector3(POND_AT.x + 1.5, y, POND_AT.y - 1.0)
	GardenProps.part(self, GardenProps.blob(Vector3(1.7, 1.0, 1.5), {"exponent": 2.0, "flat_bottom": 0.6}), GardenProps.mat("lodgemud", Color("4a3c2e")), lodge, Vector3.ZERO, 0.014)
	for k in range(26):
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.1, 0.8)
		var at := lodge + Vector3(cos(a) * 1.5 * (1.0 - up * 0.6), up, sin(a) * 1.3 * (1.0 - up * 0.6))
		GardenProps.part(self, GardenProps.cyl(0.025, 0.035, rng.randf_range(0.9, 1.6), 5), sticks, at, Vector3(rng.randf_range(40, 80), rng.randf_range(0, 360), 0), 0.0)
	var low := POND_AT + Vector2(-POND_R, 1.5)                  # the dam across the low end
	for k in range(40):
		var along := rng.randf_range(-3.0, 3.0)
		var at := Vector3(low.x + rng.randf_range(-0.4, 0.4), y + rng.randf_range(-0.1, 0.4), low.y + along)
		GardenProps.part(self, GardenProps.cyl(0.03, 0.04, rng.randf_range(0.8, 1.5), 5), sticks, at, Vector3(rng.randf_range(60, 100), rng.randf_range(-30, 30), rng.randf_range(-20, 20)), 0.0)
	var pad := GardenProps.mat("lilypad", Color("4a6a34"))
	for k in range(14):
		var q := POND_AT + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.5, POND_R - 0.5)
		GardenProps.part(self, GardenProps.cyl(0.32, 0.32, 0.015, 10), pad, Vector3(q.x, y + 0.03, q.y), Vector3.ZERO, 0.0)
		if rng.randf() < 0.3:
			GardenProps.part(self, GardenProps.blob(Vector3(0.09, 0.06, 0.09), "pebble"), GardenProps.mat("lily", Color("f2ece4")), Vector3(q.x, y + 0.08, q.y), Vector3.ZERO, 0.0)
	for k in range(10):
		var q := POND_AT + Vector2.from_angle(rng.randf() * TAU) * (POND_R + rng.randf_range(0.2, 1.0))
		if not _near_trail(q, 1.2):
			GardenProps.cattails(self, Vector3(q.x, height(q.x, q.y), q.y), rng)
	for k in range(4):                                      # stumps, gnawed to a point
		var q := POND_AT + Vector2.from_angle(rng.randf() * TAU) * (POND_R + rng.randf_range(1.5, 3.0))
		var gy := height(q.x, q.y)
		GardenProps.part(self, GardenProps.cyl(0.0, 0.22, 0.55, 8), GardenProps.mat("gnawed", Color("c8a878")), Vector3(q.x, gy + 0.27, q.y), Vector3.ZERO, 0.008)


## The cellar hole: all that's left of a farmhouse - a square of dry-laid stone round a pit, a granite step, the
## chimney's base, an old lilac grown huge, and the apple tree that was in the dooryard.
func _cellar_hole(rng: RandomNumberGenerator) -> void:
	var c := Vector3(CELLAR_AT.x, height(CELLAR_AT.x, CELLAR_AT.y), CELLAR_AT.y)
	var stone := GardenProps.mat("cellarstone", Color("7e7a70"))
	for side in range(4):
		var a := side * PI * 0.5
		var along := Vector3(cos(a), 0, sin(a))
		var out := Vector3(-sin(a), 0, cos(a))
		for k in range(9):
			var at := c + out * 3.2 + along * (-3.2 + k * 0.8)
			at.y = height(at.x, at.z)
			for course in range(2):
				GardenProps.part(self, GardenProps.blob(Vector3(0.42, 0.18, 0.3) * snappedf(rng.randf_range(0.8, 1.2), 0.1), "pebble"), stone, at + Vector3(rng.randf_range(-0.1, 0.1), -0.2 - course * 0.32, 0), Vector3(0, rad_to_deg(a) + rng.randf_range(-10, 10), 0), 0.008)
	var step := c + Vector3(0, 0, 3.7)
	step.y = height(step.x, step.z)
	GardenProps.part(self, GardenProps.box(Vector3(1.3, 0.22, 0.5)), GardenProps.mat("granite", Color("9a968c")), step + Vector3(0, 0.05, 0), Vector3(0, 0, 2), 0.01)
	var chimney := c + Vector3(-1.6, 0, -1.4)
	chimney.y = height(chimney.x, chimney.z)
	GardenProps.part(self, GardenProps.box(Vector3(0.9, 1.3, 0.9)), stone, chimney + Vector3(0, 0.3, 0), Vector3(0, 8, 0), 0.012)
	var lilac := c + Vector3(-4.6, 0, -1.6)
	lilac.y = height(lilac.x, lilac.z)
	GardenProps.part(self, GardenProps.blob(Vector3(1.6, 1.4, 1.5), {"exponent": 2.0}), GardenProps.mat("lilacleaf", Color("3a5030")), lilac + Vector3(0, 1.3, 0), Vector3.ZERO, 0.01)
	for k in range(9):
		var q := lilac + Vector3(rng.randf_range(-1.3, 1.3), rng.randf_range(1.5, 2.4), rng.randf_range(-1.2, 1.2))
		GardenProps.part(self, GardenProps.blob(Vector3(0.14, 0.22, 0.14), "pebble"), GardenProps.mat("lilacbloom", Color("a98ac8")), q, Vector3.ZERO, 0.0)
	var apple := c + Vector3(-2.4, 0, 5.0)
	apple.y = height(apple.x, apple.z)
	var bark := GardenProps.mat("applebark", Color("4a3c30"))
	GardenProps.part(self, GardenProps.cyl(0.18, 0.28, 2.4, 9), bark, apple + Vector3(0, 1.2, 0), Vector3(0, 0, 8), 0.01)
	GardenProps.part(self, GardenProps.blob(Vector3(2.2, 1.4, 2.0), {"exponent": 2.0}), GardenProps.mat("applecrown", Color("3a4c28")), apple + Vector3(0.3, 3.0, 0), Vector3.ZERO, 0.0)
	for k in range(14):
		var q := apple + Vector3(rng.randf_range(-1.8, 2.2), rng.randf_range(2.2, 3.6), rng.randf_range(-1.6, 1.6))
		GardenProps.part(self, GardenProps.blob(Vector3(0.07, 0.07, 0.07), "pebble"), GardenProps.mat("redapple", Color("b8402e")), q, Vector3.ZERO, 0.0)


## The trailhead: a little roofed board where a map would go.
func _trailhead_board() -> void:
	var c := node_pos("trailhead")
	var at := c + Vector3(2.6, 0, 1.2)
	at.y = height(at.x, at.z)
	var r := GardenProps.root(self, "TrailBoard", at, -30.0)
	var wood := GardenProps.mat("boardwood", Color("6a5038"))
	for sx: float in [-0.6, 0.6]:
		GardenProps.part(r, GardenProps.box(Vector3(0.1, 1.9, 0.1)), wood, Vector3(sx, 0.95, 0), Vector3.ZERO, 0.008)
	GardenProps.part(r, GardenProps.box(Vector3(1.3, 0.85, 0.05)), GardenProps.mat("boardface", Color("8a7458")), Vector3(0, 1.3, 0.02), Vector3.ZERO, 0.008)
	GardenProps.part(r, GardenProps.box(Vector3(1.5, 0.05, 0.45)), wood, Vector3(0, 1.92, 0), Vector3(-12, 0, 0), 0.008)


# ------------------------------------------------------------------ finds
func _place_finds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909                                        # the same spots every time
	for id in SPOTS:
		var c := node_pos(id)
		var kinds: Array = SPOTS[id]
		for i in kinds.size():
			var kind: String = kinds[i]
			var at := _clear_spot(c, rng.randf_range(2.4, 5.2), rng)
			if kind in ["tire", "line"] and id == "creek":     # in the water / the reeds
				var q := Vector2(c.x, c.z)
				var b := _creek_point((q - CREEK_AT).dot(CREEK_DIR) + (2.5 if kind == "tire" else -3.0)) + CREEK_DIR.orthogonal() * (0.4 if kind == "tire" else 1.9) * signf(_creek_lat(q))
				at = Vector3(b.x, height(b.x, b.y) + (0.55 if kind == "tire" else 0.6), b.y)
			var holder := GardenProps.root(self, "Find_" + kind, at, rng.randf() * 360.0)
			_find_look(holder, kind, rng)
			_finds.append({"id": "%s:%d" % [id, i], "kind": kind, "at": id, "node": holder, "tugs": int(FINDS[kind].get("tugs", 1))})


func _find_look(h: Node3D, kind: String, rng: RandomNumberGenerator) -> void:
	match kind:
		"can":
			GardenProps.part(h, GardenProps.cyl(0.04, 0.04, 0.12, 8), GardenProps.rust_mat(), Vector3(0, 0.04, 0), Vector3(0, 0, 90), 0.004)
		"bottle":
			GardenProps.part(h, GardenProps.cyl(0.04, 0.045, 0.24, 8), GardenProps.mat("bottleglass", Color("4a7a52"), 0.2), Vector3(0, 0.045, 0), Vector3(0, 0, 90), 0.004)
		"wrapper":
			GardenProps.part(h, GardenProps.blob(Vector3(0.08, 0.015, 0.05), "pebble"), GardenProps.mat("wrapper", Color("d44a3a"), 0.4), Vector3(0, 0.02, 0), Vector3.ZERO, 0.003)
		"tire":
			GardenProps.old_tire(h, Vector3(0, -0.2, 0), 0.0).rotation_degrees.x = 25.0
		"tarp":
			GardenProps.part(h, GardenProps.blob(Vector3(0.8, 0.22, 0.6), "pebble"), GardenProps.mat("tarp", Color("3a5a9a"), 0.6), Vector3(0, 0.12, 0), Vector3.ZERO, 0.01)
		"drum":
			GardenProps.part(h, GardenProps.cyl(0.3, 0.3, 0.85, 14), GardenProps.rust_mat(), Vector3(0, 0.28, 0), Vector3(0, 0, 90), 0.01)
		"line":
			GardenProps.part(h, GardenProps.blob(Vector3(0.28, 0.16, 0.24), {"exponent": 1.6}), GardenProps.mat("fishline", Color("a8b2b4"), 0.3), Vector3(0, 0.1, 0), Vector3.ZERO, 0.0)
		"cone":
			GardenProps.part(h, GardenProps.blob(Vector3(0.05, 0.075, 0.05), {"exponent": 2.0, "taper": 0.4}), GardenProps.mat("pinecone", Color("7a5232")), Vector3(0, 0.04, 0), Vector3(80, 0, 0), 0.004)
		"acorn":
			for k in range(3):
				var o := Vector3(rng.randf_range(-0.06, 0.06), 0.02, rng.randf_range(-0.06, 0.06))
				GardenProps.part(h, GardenProps.blob(Vector3(0.022, 0.03, 0.022), "pebble"), GardenProps.mat("acorn", Color("a87a3a")), o, Vector3(80, k * 50, 0), 0.0)
		"apple":
			GardenProps.part(h, GardenProps.blob(Vector3(0.05, 0.048, 0.05), "pebble"), GardenProps.mat("redapple", Color("b8402e")), Vector3(0, 0.045, 0), Vector3.ZERO, 0.004)
		"mushroom":
			GardenProps.part(h, GardenProps.cyl(0.02, 0.028, 0.1, 8), GardenProps.mat("mushstem", Color("e6dcc4")), Vector3(0, 0.05, 0), Vector3.ZERO, 0.003)
			GardenProps.part(h, GardenProps.blob(Vector3(0.07, 0.04, 0.07), "dome"), GardenProps.mat("mushcap", Color("a8583a")), Vector3(0, 0.1, 0), Vector3.ZERO, 0.004)
		"feather":
			GardenProps.part(h, GardenProps.blob(Vector3(0.025, 0.006, 0.11), {"exponent": 2.0}), GardenProps.mat("jayfeather", Color("4a7ac0"), 0.5), Vector3(0, 0.01, 0), Vector3.ZERO, 0.0)
		"seeds":
			for k in range(3):
				var o := Vector3((k - 1) * 0.05, 0, rng.randf_range(-0.03, 0.03))
				GardenProps.part(h, GardenProps.cyl(0.004, 0.006, 0.34, 4), GardenProps.mat("seedstem", Color("8a8a5a")), o + Vector3(0, 0.17, 0), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)), 0.0)
				GardenProps.part(h, GardenProps.blob(Vector3(0.035, 0.05, 0.035), "pebble"), GardenProps.mat("seedhead", Color("cfc29a")), o + Vector3(0, 0.36, 0), Vector3.ZERO, 0.0)
	if FINDS[kind]["what"] != "junk":                    # a glint, so small things can be found at night
		var g := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.025
		dot.height = 0.05
		dot.radial_segments = 6
		dot.rings = 3
		g.mesh = dot
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("fff0c0")
		g.material_override = m
		g.position = Vector3(0, 0.22, 0)
		g.name = "Glint"
		h.add_child(g)


## What has grown back since you were last here, and what's still gone.
func _refresh_finds() -> void:
	var taken: Dictionary = garden.game.woods_finds["taken"]
	var now := Time.get_unix_time_from_system()
	for f: Dictionary in _finds:
		var gone := taken.has(f["id"])
		if gone and FINDS[f["kind"]]["what"] in ["forage", "seeds"] and now - float(taken[f["id"]]) > REGROW:
			taken.erase(f["id"])
			gone = false
		var node: Node3D = f["node"]
		if not gone and not node.visible:
			node.scale = Vector3.ONE
			node.visible = true
		elif gone:
			node.visible = false


func show_basket() -> void:
	var n := 0
	for k in basket:
		n += int(basket[k])
	if n > 0:
		_basket_label.text = "🧺 %d" % n
	Motion.fade(_basket_label, 1.0 if n > 0 else 0.0)


func _find_at(screen: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for f: Dictionary in _finds:
		var node: Node3D = f["node"]
		if not node.visible or f["at"] != _at:
			continue
		var p := node.global_position + Vector3(0, 0.1, 0)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(screen)
		var reach := 150.0 if FINDS[f["kind"]]["what"] == "junk" else 100.0
		if d < reach and d < best_d:
			best_d = d
			best = f
	return best


func take(f: Dictionary) -> void:
	var game: Node = garden.game
	var info: Dictionary = FINDS[f["kind"]]
	var node: Node3D = f["node"]
	if info["what"] == "junk" and f["tugs"] > 1:          # it takes a few goes
		f["tugs"] -= 1
		var t := Motion.channel(node, "tug")
		t.tween_property(node, "rotation_degrees:z", 7.0, Motion._d(Motion.FAST * 0.6))
		t.tween_property(node, "rotation_degrees:z", -5.0, Motion._d(Motion.FAST * 0.6))
		t.tween_property(node, "rotation_degrees:z", 0.0, Motion._d(Motion.FAST))
		game.toast(["Stuck fast. Pull again.", "It's coming. Once more."][mini(1, 3 - int(f["tugs"]))] if f["tugs"] > 1 else "Nearly...")
		return
	game.woods_finds["taken"][f["id"]] = Time.get_unix_time_from_system()
	Motion.vanish(node, false)
	match info["what"]:
		"litter", "junk":
			game.coins += int(info["coins"])
			game.toast("%s 🪙 +%d" % [info["say"], info["coins"]])
		"forage":
			basket[f["kind"]] = int(basket.get(f["kind"], 0)) + 1
			game.toast(info["say"] + " The nursery might want it.")
			show_basket()
		"seeds":
			var species: String = WILD_SEEDS.get(f["at"], "clover")
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			for k in range(2):
				game.keep_seeds.append({"species": species, "genes": _wild_genes(rng)})
			game.toast("🌱 Wild %s, gone to seed. Two to sow - they're in 🌱, under %s." % [SpeciesBuilder.PLANT_NAMES.get(species, species), species])
	game._refresh()


## Wild seeds aren't the shop's: now and then one carries something its parents didn't show.
static func _wild_genes(rng: RandomNumberGenerator) -> String:
	var out := ""
	for pair: Array in [["C", "c"], ["T", "t"]]:
		var a: String = pair[1] if rng.randf() < 0.3 else pair[0]
		var b: String = pair[1] if rng.randf() < 0.3 else pair[0]
		out += a + b if a <= b else b + a
	return out


# ------------------------------------------------------------------ wild hedgepets
## Hedgepets that don't live in your garden, out in the woods: a few at a time, off the trail ahead of you, nosing
## about and watching you. Come within a few metres and they scurry off; fall far behind and they slip away, and
## others turn up further on. You can't catch them - tap one and you learn who it was.
const WILD_COUNT := 4
const SHY := 6.0                       # closer than this, they're off
var _wild: Array = []                  # {node, pos (local), goal, speed, wait, gone}
var _wrng := RandomNumberGenerator.new()


func _wild_begin() -> void:
	_wild.clear()
	var game: Node = garden.game
	var pool: Array = garden.roster.filter(func(p) -> bool: return game.pet_state.get(p.pet_name, "") == "away" and p.pet_name != game.carried and not game.following.has(p.pet_name))
	pool.shuffle()
	for p: CharacterArtProfile in pool.slice(0, WILD_COUNT):
		var node: HedgePetNode = garden.node_for(p)
		if is_borrowed(node):
			continue
		borrow(node)
		node.visible = false
		node.set_sleeping(false)
		_wild.append({"node": node, "pos": Vector3.INF, "goal": Vector3.INF, "speed": 0.0, "wait": _wrng.randf_range(0.0, 2.0), "gone": true})


## Somewhere ahead of you, off the trail, on dry ground.
func _wild_spot() -> Vector3:
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var right := fwd.cross(Vector3.UP)
	for k in range(20):
		var q := cam.position + fwd * _wrng.randf_range(8.0, 16.0) + right * _wrng.randf_range(-8.0, 8.0)
		var p2 := Vector2(q.x, q.z)
		if p2.x < -56 or p2.x > 58 or p2.y < -106 or p2.y > 14 or _near_trail(p2, 1.4) or water_at(p2.x, p2.y) > -INF:
			continue
		return Vector3(q.x, height(q.x, q.z), q.z)
	return Vector3.INF


func _wild_tick(delta: float) -> void:
	for w: Dictionary in _wild:
		var node: HedgePetNode = w["node"]
		if w["gone"]:
			w["wait"] -= delta
			if w["wait"] <= 0.0:
				var at := _wild_spot()
				if at != Vector3.INF:
					w["gone"] = false
					w["pos"] = at
					w["goal"] = at
					node.position = to_global(at)
					node.rotation.y = _wrng.randf() * TAU
					Motion.appear(node, Vector3.ONE * garden.PET_SCALE * 0.85)
			continue
		var pos: Vector3 = w["pos"]
		var off := Vector3(pos.x - cam.position.x, 0, pos.z - cam.position.z)
		var d := off.length()
		if d > 30.0:                                     # left behind: slip away, turn up somewhere ahead later
			w["gone"] = true
			w["wait"] = _wrng.randf_range(2.0, 6.0)
			Motion.vanish(node, false)
			continue
		if d < SHY and w["speed"] < 3.0:                 # too close: off it goes, away from you
			var away := off.normalized().rotated(Vector3.UP, _wrng.randf_range(-0.7, 0.7))
			var g := pos + away * _wrng.randf_range(5.0, 8.0)
			w["goal"] = Vector3(g.x, height(g.x, g.z), g.z)
			w["speed"] = 3.8
		var to: Vector3 = w["goal"] - pos
		to.y = 0.0
		if to.length() > 0.1:
			var step := minf(to.length(), float(w["speed"]) * delta)
			pos += to.normalized() * step
			pos.y = height(pos.x, pos.z)
			node.rotation.y = lerp_angle(node.rotation.y, atan2(to.x, to.z), clampf(delta * 10.0, 0.0, 1.0))
			node.walking = 1.0
			node.look_point = Vector3.INF
		else:
			node.walking = move_toward(node.walking, 0.0, delta * 3.0)
			w["speed"] = 0.0
			w["wait"] -= delta
			node.look_point = cam.global_position         # a wary look at you
			if w["wait"] <= 0.0:                           # nose about a little
				w["wait"] = _wrng.randf_range(1.5, 4.0)
				var g := pos + Vector3(_wrng.randf_range(-1.5, 1.5), 0, _wrng.randf_range(-1.5, 1.5))
				if not _near_trail(Vector2(g.x, g.z), 1.2) and water_at(g.x, g.z) == -INF:
					w["goal"] = Vector3(g.x, height(g.x, g.z), g.z)
					w["speed"] = 0.9
		w["pos"] = pos
		node.position = to_global(pos)


func _wild_tapped(at: Vector2) -> bool:
	for w: Dictionary in _wild:
		var node: HedgePetNode = w["node"]
		if w["gone"] or not node.visible or cam.is_position_behind(node.global_position):
			continue
		if cam.unproject_position(node.global_position + Vector3(0, 0.3, 0)).distance_to(at) < 110.0:
			garden.game.toast("A wild %s, keeping its distance. It doesn't live in your garden - yet." % SpeciesBuilder.variant_name(node.profile))
			return true
	return false


# ------------------------------------------------------------------ a visit
func _arrive() -> void:
	followers.clear()
	_released.clear()
	for name: String in garden.game.following:
		var node: HedgePetNode = garden.game.node_by_name(name)
		if node == null or not garden.pet_mode(node) in ["roam", "peek", "away", "leave"]:
			continue
		borrow(node)
		node.set_sleeping(false)
		followers.append(node)
	_carried = null
	if garden.game.carried != "":
		_carried = garden.game.node_by_name(garden.game.carried)
		if _carried != null:
			borrow(_carried)
	_at = "trailhead"
	_walking = {}
	_wild_begin()
	_refresh_finds()
	show_basket()
	_yaw = _heading_of(_way_to("fork")["dir"])
	_goal_yaw = _yaw
	_settle(Vector3.INF)
	_place_camera(node_pos(_at) + Vector3(0, EYE, 0))
	if not _told:
		_told = true
		garden.game.toast("Turn to face a trail, then tap to walk it.")


func _depart() -> void:
	_walking = {}
	_wild.clear()                                        # (give_back puts them back where they were: away)
	nursery.depart()
	for node: HedgePetNode in followers + ([_carried] if _carried != null else []):
		Motion.channel(node, "woods").kill()             # nothing still easing anyone into place out here
	_pail.visible = false
	for node: HedgePetNode in _released:               # let out here: they come home with you, beside you
		garden.game.home_from_woods(node)


func _way_to(to: String) -> Dictionary:
	for way: Dictionary in _labels[_at]:
		if way["to"] == to:
			return way
	return {}


func _heading_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Everyone gathers round where you're standing: followers in a loose arc ahead (so you see them), the bucket beside.
func _settle(came_from: Vector3) -> void:
	var c := node_pos(_at)
	for i in followers.size():
		var node: HedgePetNode = followers[i]
		var a: float = _yaw + [0.6, -0.6, 1.0, -1.0, 1.4][i % 5]
		var p := c + Vector3(-sin(a), 0, -cos(a)) * (3.6 + 0.5 * (i / 2))
		p.y = height(p.x, p.z)
		var tw := Motion.channel(node, "woods")
		tw.tween_property(node, "position", to_global(p), Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_SINE)
		node.look_point = to_global(c + Vector3(0, EYE, 0))
	if _carried != null:
		var a := _yaw - 0.35
		var p := c + Vector3(-sin(a), 0, -cos(a)) * 2.4
		p.y = height(p.x, p.z)
		_pail.position = p
		_pail.visible = true
		_carried.scale = Vector3.ONE * garden.PET_SCALE * 0.55
		_carried.position = to_global(p + Vector3(0, 0.18, 0))
		_carried.rotation.y = garden._heading(p, c)
		_carried.look_point = to_global(c + Vector3(0, EYE, 0))
		_carried.visible = true
	_let_out.visible = _carried != null
	if _carried != null:
		_let_out.text = "🪣  Let %s out" % _carried.profile.pet_name
	_title.text = NODES[_at]["name"] if NODES.has(_at) else ""


## The bucket tipped: the pet hops out and walks with you from now on (and comes home with you).
func let_out() -> void:
	if _carried == null:
		return
	var node := _carried
	_carried = null
	_pail.visible = false
	node.scale = Vector3.ONE * garden.PET_SCALE
	node.position = to_global(_pail.position)
	node.tap()
	keep(node)
	_released.append(node)
	followers.append(node)
	garden.game.carried = ""
	if not garden.game.following.has(node.profile.pet_name):
		garden.game.following.append(node.profile.pet_name)
	garden.game.toast("%s hops out and shakes off. It'll walk with you now." % node.profile.pet_name)
	_settle(Vector3.INF)


# ------------------------------------------------------------------ walking a trail
func walk(way: Dictionary) -> void:
	if way.get("stub", false):
		garden.game.toast("The way to the nursery is still overgrown. Another day.")
		return
	if way["to"] == "garden":
		leave()
		return
	if _at == "nursery":
		nursery.depart()
	var e: Dictionary = _paths[int(way["edge"])]
	var pts: PackedVector3Array = e["pts"] if e["a"] == _at else _reversed(e["pts"])
	var length := 0.0
	for i in range(1, pts.size()):
		length += pts[i].distance_to(pts[i - 1])
	_walking = {"pts": pts, "s": 0.0, "len": length, "to": way["to"]}
	_pail.visible = false
	if _carried != null:
		_carried.visible = false                         # in the bucket, in your hand
	_let_out.visible = false
	_title.text = ""


func _sample(pts: PackedVector3Array, s: float) -> Vector3:
	if s <= 0.0:
		return pts[0]
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if acc + seg >= s:
			return pts[i - 1].lerp(pts[i], (s - acc) / maxf(seg, 0.0001))
		acc += seg
	return pts[pts.size() - 1]


func _step_walk(delta: float) -> void:
	var w := _walking
	var len: float = w["len"]
	var s: float = w["s"]
	var ease := clampf(minf(s, len - s) / 2.5, 0.35, 1.0)   # gentle start and stop
	s = minf(len, s + WALK_SPEED * ease * delta)
	w["s"] = s
	var pts: PackedVector3Array = w["pts"]
	var here := _sample(pts, s)
	var ahead := _sample(pts, minf(len, s + 3.0))
	var d := ahead - here
	if Vector2(d.x, d.z).length() > 0.3:
		_goal_yaw = atan2(-d.x, -d.z)
	var slope := atan2(d.y, maxf(0.5, Vector2(d.x, d.z).length()))
	_pitch = lerpf(_pitch, clampf(slope * 0.45 - 0.1, -0.3, 0.12), clampf(delta * 2.0, 0.0, 1.0))   # eyes on the trail, a little up or down with it
	var bob := sin(s * 2.6) * 0.045
	_place_camera(here + Vector3(0, EYE + bob, 0))
	for i in followers.size():                          # trailing along behind, each a little further back
		var node: HedgePetNode = followers[i]
		Motion.channel(node, "woods").kill()
		var fs := s - 2.4 - i * 1.7
		var p := _sample(pts, fs)
		var q := _sample(pts, fs + 0.8)
		node.position = to_global(p)
		if fs > 0.0 and q.distance_to(p) > 0.05:
			node.rotation.y = lerp_angle(node.rotation.y, garden._heading(p, q), clampf(delta * 6.0, 0.0, 1.0))
		node.walking = 1.0 if fs > 0.0 and s < len else move_toward(node.walking, 0.0, delta * 3.0)
		node.look_point = Vector3.INF
	if s >= len:
		_at = w["to"]
		_walking = {}
		for node: HedgePetNode in followers:
			node.walking = 0.0
		_settle(pts[pts.size() - 1])
		if _at == "nursery":
			nursery.arrive()


# ------------------------------------------------------------------ looking around
func _place_camera(at: Vector3) -> void:
	cam.position = at
	cam.rotation = Vector3(_pitch, _yaw, 0)


func facing() -> Dictionary:
	if not _walking.is_empty():
		return {}
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var best: Dictionary = {}
	var best_dot := cos(deg_to_rad(28.0))
	for way: Dictionary in _labels[_at]:
		var dt: float = fwd.dot(way["dir"])
		if dt > best_dot:
			best_dot = dt
			best = way
	return best


func _process(delta: float) -> void:
	_t += delta
	if not _walking.is_empty():
		_step_walk(delta)
	else:
		_pitch = lerpf(_pitch, clampf(_pitch, deg_to_rad(-25), deg_to_rad(12)), clampf(delta * 4.0, 0.0, 1.0))
	_yaw = lerp_angle(_yaw, _goal_yaw, clampf(delta * (5.0 if _walking.is_empty() else 3.0), 0.0, 1.0))
	if _walking.is_empty():
		_place_camera(node_pos(_at) + Vector3(0, EYE, 0))
	else:
		cam.rotation = Vector3(_pitch, _yaw, 0)
	var faced := facing()
	for way: Dictionary in _labels[_at]:                 # the sign you're facing reads bright
		var l: Label3D = way["label"]
		var want := Color(1.0, 0.95, 0.8) if way == faced else Color(0.78, 0.7, 0.54)
		l.modulate = Motion.approach(l.modulate, want, 4.0, delta)
		(l.get_meta("back") as Label3D).modulate = l.modulate
	for id in _labels:                                   # the chevrons: on the trail you're facing, here
		for way: Dictionary in _labels[id]:
			if way.has("marks"):
				var m: StandardMaterial3D = way["marks"]["mat"]
				var a := (0.7 + 0.25 * sin(_t * 4.0)) if (id == _at and way == faced) else 0.0
				m.albedo_color.a = Motion.approach(m.albedo_color.a, a, 6.0, delta)
	_wild_tick(delta)
	for h: Node3D in _willows_sway:                      # the willows' strands, swaying
		var ph: float = h.get_meta("phase")
		h.rotation = Vector3(sin(_t * 0.6 + ph) * 0.035, 0, cos(_t * 0.45 + ph * 1.3) * 0.035)
	for f: Dictionary in _finds:                         # glints twinkle
		var g: Node3D = f["node"].get_node_or_null("Glint")
		if g != null:
			g.visible = sin(_t * 2.1 + f["node"].position.x * 3.0) > 0.55
	for f: Node3D in _fireflies:
		var ph: float = f.get_meta("phase")
		f.position = f.get_meta("home") + Vector3(sin(_t * 0.5 + ph), sin(_t * 0.8 + ph * 2.0) * 0.4, cos(_t * 0.4 + ph)) * 0.6
		f.visible = sin(_t * 1.3 + ph * 3.0) > -0.3


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if pressed:
		_press = event.position
		_moved = false
	elif released and _press != Vector2.INF:
		if not _moved:
			_tap(event.position)
		_press = Vector2.INF
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _press != Vector2.INF:
		if event.position.distance_to(_press) > 10.0:
			_moved = true
		if _moved and _walking.is_empty():               # any drag looks around
			_goal_yaw -= event.relative.x * 0.0045
			_pitch = clampf(_pitch - event.relative.y * 0.002, deg_to_rad(-25), deg_to_rad(12))
	if event is InputEventKey and event.pressed and _walking.is_empty():
		if event.physical_keycode in [KEY_A, KEY_LEFT, KEY_Q]:
			_goal_yaw += 0.4
		elif event.physical_keycode in [KEY_D, KEY_RIGHT, KEY_E]:
			_goal_yaw -= 0.4
		elif event.physical_keycode in [KEY_W, KEY_UP, KEY_SPACE, KEY_ENTER] and not facing().is_empty():
			walk(facing())


func _tap(at: Vector2) -> void:
	if not _walking.is_empty():
		return
	var pets := followers.duplicate()
	if _carried != null:
		pets.append(_carried)
	for node: HedgePetNode in pets:
		if node.visible and cam.unproject_position(node.global_position + Vector3(0, 0.4, 0)).distance_to(at) < 110.0 and not cam.is_position_behind(node.global_position):
			node.tap()
			garden.game.toast(["%s sniffs the night air.", "%s's leaves rustle. It likes it out here.", "%s looks up at the trees, then at you.", "%s is right behind you."].pick_random() % node.profile.pet_name)
			return
	if _at == "nursery" and nursery.tap(at, cam):
		return
	if _wild_tapped(at):
		return
	if _at == "hollow" and not cam.is_position_behind(campfire.global_position) and cam.unproject_position(campfire.global_position + Vector3(0, 0.3, 0)).distance_to(at) < 130.0:
		campfire.tapped(garden.game)
		return
	var f := _find_at(at)
	if not f.is_empty():
		take(f)
		return
	var way := _way_tapped(at)
	if way.is_empty():
		garden.game.toast("Tap a trail (or its sign) to walk it. Drag to look around.")
	else:
		if way != facing():
			_goal_yaw = _heading_of(way["dir"])            # turn to it first, as you set off
		walk(way)


## Which trail a tap means: the one whose start (its first few metres, or its sign) is nearest the tap on screen; if
## the tap isn't near any, the one you're facing.
func _way_tapped(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 230.0
	for way: Dictionary in _labels[_at]:
		var c := node_pos(_at)
		var marks: Array = [c + way["dir"] * 4.0, c + way["dir"] * 7.0]
		if way.has("label"):
			marks.append((way["label"] as Label3D).global_position - global_position)
		for q: Vector3 in marks:
			var g := to_global(Vector3(q.x, height(q.x, q.z) + 0.3, q.z) if q.y < c.y + 1.0 else q)
			if cam.is_position_behind(g):
				continue
			var d := cam.unproject_position(g).distance_to(at)
			if d < best_d:
				best_d = d
				best = way
	return best if not best.is_empty() else facing()
