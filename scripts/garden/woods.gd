extends Elsewhere

## The woods, over the footbridge: a dark, hilly hiking trail. You stand at a clearing and turn to look around (drag,
## anywhere); the trails out of it are marked with their names, and the one you're facing lights up. Tap and you
## walk it - up and down the hills, a little bob in your step - to the next clearing. The pets following you (🐾 in
## the garden) trail along behind and gather round when you stop; a pet you're carrying (🪣) rides in its bucket and
## sits beside you, and "Let out" turns it into one more follower.
##
## Clearings (NODES) and the trails between them (EDGES): the trailhead by the creek, the mossy fork (the hub: the
## nursery's trail goes off it too, still overgrown), the fern hollow down low, the ridge up high under the moon, the
## creek crossing and the old oak. Dark, but kind: lanterns at every clearing, fireflies, moonlight. Never spooky.

const ORIGIN := Vector3(0, -300, 0)             # far below everything: nothing of the garden is ever in view
const EYE := 1.5
const WALK_SPEED := 3.2
const NODES := {
	"trailhead": {"at": Vector2(0, 0), "lift": 0.0, "name": "The trailhead"},
	"fork": {"at": Vector2(2, -24), "lift": 1.5, "name": "The mossy fork"},
	"hollow": {"at": Vector2(-22, -38), "lift": -6.0, "name": "Fern hollow"},
	"ridge": {"at": Vector2(22, -44), "lift": 8.0, "name": "The ridge"},
	"creek": {"at": Vector2(-28, -64), "lift": -3.0, "name": "Creek crossing"},
	"oak": {"at": Vector2(4, -70), "lift": 2.0, "name": "The old oak"},
}
const EDGES := [["trailhead", "fork"], ["fork", "hollow"], ["fork", "ridge"], ["hollow", "creek"], ["ridge", "oak"], ["creek", "oak"]]
## Trails that don't lead anywhere yet: a few overgrown metres and a sign.
const STUBS := {"nursery": {"from": "fork", "toward": Vector2(-6, -12), "name": "The nursery"}}

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


func title_text() -> String:
	return ""


func muffle() -> Vector2:
	return Vector2(2400.0, -8.0)                         # the garden's birds, far off behind the trees


func setup(g: Node3D) -> void:
	name = "Woods"
	position = ORIGIN
	super.setup(g)
	_let_out = Button.new()
	_let_out.flat = true
	_let_out.add_theme_font_size_override("font_size", 36)
	_let_out.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_let_out.position = Vector2(60, 1680)
	_let_out.custom_minimum_size = Vector2(420, 90)
	_let_out.visible = false
	_let_out.pressed.connect(let_out)
	_ui.add_child(_let_out)


# ------------------------------------------------------------------ the ground
func height(x: float, z: float) -> float:
	var v := _noise.get_noise_2d(x, z) * 9.0 + _fine.get_noise_2d(x, z) * 1.4
	for id in NODES:
		var n: Dictionary = NODES[id]
		var d := Vector2(x, z).distance_to(n["at"])
		v += float(n["lift"]) * exp(-d * d / (2.0 * 11.0 * 11.0))
		var level := _base(n["at"]) + float(n["lift"])
		v = lerpf(v, level, smoothstep(7.0, 2.5, d))   # a flat-ish clearing to stand in
	return v


func _base(p: Vector2) -> float:
	return _noise.get_noise_2d(p.x, p.y) * 9.0


func node_pos(id: String) -> Vector3:
	var p: Vector2 = NODES[id]["at"]
	return Vector3(p.x, height(p.x, p.y), p.y)


# ------------------------------------------------------------------ building it (once)
func _build() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 77
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.022
	_noise.fractal_octaves = 3
	_fine = FastNoiseLite.new()
	_fine.seed = 78
	_fine.frequency = 0.11
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
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
	_ground(rng)
	for e in _paths:
		_ribbon(e["pts"], e.get("stub", false))
	_trees(rng)
	_undergrowth(rng)
	_clearings(rng)
	for id in _labels:
		for way: Dictionary in _labels[id]:
			var at: Vector3 = node_pos(id) + way["dir"] * 5.5
			way["label"] = _sign(Vector3(at.x, height(at.x, at.z) + 1.6, at.z), str(way["name"]))
	var moon := MeshInstance3D.new()
	var ms := SphereMesh.new()
	ms.radius = 7.0
	ms.height = 14.0
	moon.mesh = ms
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color("ece6cc")
	mm.disable_fog = true
	moon.material_override = mm
	moon.position = node_pos("ridge") + Vector3(0.55, 0.42, -0.72).normalized() * 160.0
	add_child(moon)
	var moonlight := DirectionalLight3D.new()
	moonlight.light_color = Color("c4cede")
	moonlight.light_energy = 0.18
	moonlight.rotation_degrees = Vector3(-35, 145, 0)
	add_child(moonlight)
	var env := dark_env(Color("0c130e"), Color("4a5a44"), 0.7)
	env.fog_enabled = true
	env.fog_light_color = Color("101a12")
	env.fog_density = 0.03
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.08
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.environment = env
	add_child(cam)
	_pail = GardenProps.paint_bucket(self, Vector3.ZERO, 0.0)
	_pail.visible = false


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
	var ctrl: Array[Vector2] = [Vector2(a.x, a.z) - flat * 0.2, Vector2(a.x, a.z)]
	for k in [0.35, 0.68]:
		ctrl.append(Vector2(a.x, a.z) + flat * k + side * rng.randf_range(-5.0, 5.0))
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
			out.append(Vector3(q.x, height(q.x, q.y), q.y))
	out.append(b)
	return out


func _near_trail(p: Vector2, margin: float) -> bool:
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for i in range(0, pts.size(), 2):
			if Vector2(pts[i].x, pts[i].z).distance_squared_to(p) < margin * margin:
				return true
	for id in NODES:
		if (NODES[id]["at"] as Vector2).distance_to(p) < margin + 3.5:
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


## The worn dirt of a trail, laid over the ground (its edges a touch above it, so it never sinks in).
func _ribbon(pts: PackedVector3Array, faint: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.75 if not faint else 0.45
	var col := Color("6a5642") if not faint else Color("4a4234")
	var prev_l := Vector3.INF
	var prev_r := Vector3.INF
	for i in pts.size():
		var a := pts[maxi(0, i - 1)]
		var b := pts[mini(pts.size() - 1, i + 1)]
		var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := d.cross(Vector3.UP) * w * (1.0 + 0.15 * sin(i * 0.7))
		var l := pts[i] + side
		var r := pts[i] - side
		l.y = height(l.x, l.z) + 0.05
		r.y = height(r.x, r.z) + 0.05
		if prev_l != Vector3.INF:
			for v in [prev_l, l, r, prev_l, r, prev_r]:
				st.set_color(col)
				st.add_vertex(v)
		prev_l = l
		prev_r = r
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = m
	add_child(node)


func _trees(rng: RandomNumberGenerator) -> void:
	var trunks: Array = []
	var crowns: Array = []
	var cones: Array = []
	for k in range(900):
		var p := Vector2(rng.randf_range(-58, 58), rng.randf_range(-108, 16))
		if _near_trail(p, 2.6):
			continue
		var y := height(p.x, p.y)
		var tall := rng.randf_range(8.0, 17.0)
		var girth := rng.randf_range(0.8, 2.0)
		trunks.append([Transform3D(Basis().scaled(Vector3(girth, tall, girth)), Vector3(p.x, y - 0.4 + tall * 0.5, p.y)), Color("3a2c22").lerp(Color("4a3e34"), rng.randf())])
		if rng.randf() < 0.45:                           # a pine: three narrowing tiers up a tall trunk
			for c in range(3):
				var s := rng.randf_range(1.9, 2.5) * (1.0 - c * 0.25)
				cones.append([Transform3D(Basis().scaled(Vector3(s, s * 2.4, s)), Vector3(p.x, y + tall * (0.42 + c * 0.2) + s * 1.2, p.y)), Color("23402c").lerp(Color("2e4a2a"), rng.randf())])
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
	fly.albedo_color = Color("fff2a0")
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	for id in NODES:
		var c := node_pos(id)
		var a := rng.randf() * TAU
		var spot := _clear_spot(c, 3.0, rng)
		GardenProps.lantern(self, spot, rad_to_deg(a))
		var light := OmniLight3D.new()
		light.light_color = Color("ffbe72")
		light.light_energy = 1.6
		light.omni_range = 9.0
		light.position = spot + Vector3(0, 1.4, 0)
		add_child(light)
		for k in range(3):
			var r := _clear_spot(c, rng.randf_range(4.0, 6.5), rng)
			GardenProps.rock(self, r + Vector3(0, -0.1, 0), rng.randf_range(0.5, 1.1), rng)
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
	# the landmarks
	var oak := node_pos("oak") + Vector3(-4.5, 0, -3.0)
	GardenProps.part(self, GardenProps.cyl(1.0, 1.7, 9.0, 14), GardenProps.mat("oldoak", Color("4a3a2c")), oak + Vector3(0, 4.0, 0), Vector3.ZERO, 0.02)
	GardenProps.part(self, GardenProps.blob(Vector3(6.5, 4.0, 6.5), {"exponent": 2.0}), GardenProps.mat("oakcrown", Color("2c3a1e")), oak + Vector3(0, 10.5, 0), Vector3.ZERO, 0.0)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.12, 0.2, 0.24, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	var cr := node_pos("creek")
	var brook := GardenProps.part(self, GardenProps.box(Vector3(30.0, 0.05, 2.2)), water, cr + Vector3(0, 0.08, 1.6), Vector3(0, 25, 0), 0.0)
	brook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in range(4):
		GardenProps.part(self, GardenProps.blob(Vector3(0.4, 0.12, 0.32), "pebble"), GardenProps.mat("stepstone0", Color("7a7a72")), cr + Vector3(-0.8 + k * 0.5, 0.12, 0.6 + k * 0.8), Vector3(0, rng.randf_range(0, 180), 0), 0.006)


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
		GardenProps.part(self, GardenProps.blob(Vector3(0.9, 0.7, 0.9) * rng.randf_range(0.7, 1.3), "pebble"), bramble, Vector3(p.x, height(p.x, p.z) + 0.3, p.z), Vector3(0, rng.randf_range(0, 360), 0), 0.012)


func _sign(at: Vector3, text: String) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.05, 0.04, 0.8)
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.modulate = Color(0.98, 0.92, 0.78, 0.35)
	l.position = at
	add_child(l)
	return l


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
	_yaw = _heading_of(_way_to("fork")["dir"])
	_goal_yaw = _yaw
	_settle(Vector3.INF)
	_place_camera(node_pos(_at) + Vector3(0, EYE, 0))
	if not _told:
		_told = true
		garden.game.toast("Turn to face a trail, then tap to walk it.")


func _depart() -> void:
	_walking = {}
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
	for way: Dictionary in _labels[_at]:
		var l: Label3D = way["label"]
		var want := 1.0 if way == faced else (0.35 if _walking.is_empty() else 0.0)
		l.modulate.a = move_toward(l.modulate.a, want, delta * 3.0)
	for id in _labels:
		if id != _at:
			for way: Dictionary in _labels[id]:
				var l: Label3D = way["label"]
				l.modulate.a = move_toward(l.modulate.a, 0.0, delta * 3.0)
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
	var way := facing()
	if way.is_empty():
		garden.game.toast("Turn to face a trail - its name lights up - then tap.")
	else:
		walk(way)
