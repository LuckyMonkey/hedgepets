extends "res://scripts/garden/woods/woods_ground.gd"

## Woods 2/6 - the trails: the way home, laying out and smoothing each trail, the spatial index, trail beds, litter, signs and chevrons, and the shared multimesh helpers.
##
## A trail is a smoothed, densified line of 3D points between two clearings (_trail). The way home is the trail
## back to the footbridge. _index_trails() buckets every point into CELL-sized grid cells so "how far is the nearest
## trail?" (_nearest_trail, _off_trail) is a lookup, not a scan: trees, rocks and undergrowth use it to keep the walk
## clear. _ground() and _ribbon() make the trail beds, _trail_litter() the needles and leaves on them, _sign() and
## _chevrons() the wayfinding. _multimesh() is the one way scenery is drawn in bulk: one draw call per batch.
##
## Part of the woods layer chain (see scripts/garden/woods.gd for the full order). Code here was moved verbatim from
## the old single file; only its place changed.

var _paths: Array = []                # {a, b, pts: PackedVector3Array (local, a -> b)}
var _labels := {}                     # node id -> [{to, dir: Vector3, label: Label3D, edge | stub}]
# ------------------------------------------------------------------ the way home
## The garden's creek and its footbridge behind the trailhead - the same bridge, plank for plank (the garden's seed) -
## with the worn path running over it toward home. Its own random numbers.
func _home_way() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1775                                       # the garden's: its footbridge is built first from this
	var level := _base(Vector2.ZERO)
	var home := Vector3(HOME_DIR.x, 0, HOME_DIR.y)
	var b := Vector3(BROOK_AT.x, level, BROOK_AT.y)
	GardenProps.footbridge(self, b - home * 2.3, b + home * 2.3, rng)
	var flow := Vector3(HOME_DIR.orthogonal().x, 0, HOME_DIR.orthogonal().y)
	var brook := Node3D.new()
	brook.name = "Brook"
	brook.basis = Basis(Vector3.UP.cross(flow), Vector3.UP, flow)
	brook.position = b + Vector3(0, -0.5, 0)
	add_child(brook)
	GardenProps.creek(brook, func(z: float) -> float: return 0.35 * sin(z * 0.2), -22.0, 11.0, 2.4)
	for sgn: float in [-1.0, 1.0]:                      # a path each side, from the trailhead to the bridge and on home
		var pts := PackedVector3Array()
		var t0 := 1.0 if sgn < 0 else 9.4
		var t1 := 4.6 if sgn < 0 else 17.0
		var t := t0
		while t <= t1:
			pts.append(Vector3(HOME_DIR.x * t, height(HOME_DIR.x * t, HOME_DIR.y * t), HOME_DIR.y * t))
			t += 0.8
		_ribbon(pts, false)
	for k in range(16):                                   # cattails and stones along its banks
		var along := rng.randf_range(-14.0, 8.0)
		if absf(along) < 2.2:
			continue
		var bank := (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1.5, 2.2)
		var p := BROOK_AT + HOME_DIR.orthogonal() * along + HOME_DIR * bank
		if k % 2 == 0:
			GardenProps.cattails(self, Vector3(p.x, height(p.x, p.y), p.y), rng)
		else:
			GardenProps.rock(self, Vector3(p.x, height(p.x, p.y) - 0.1, p.y), snappedf(rng.randf_range(0.25, 0.5), 0.05), rng)


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


var _cells := {}                      # Vector2i -> PackedVector2Array of trail points in that cell
## Trail points by 2 m cell, so "is this near a trail" looks at a few cells, not every point of every trail.
func _index_trails() -> void:
	_cells.clear()
	_cells3.clear()
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for i in range(pts.size()):
			var c := Vector2i(floori(pts[i].x / CELL), floori(pts[i].z / CELL))
			# (a packed array read out of a Dictionary is a copy: append, then store it back - appending to the cast
			# alone left every cell empty, so nothing was ever kept off the trails)
			var flat: PackedVector2Array = _cells.get(c, PackedVector2Array())
			flat.append(Vector2(pts[i].x, pts[i].z))
			_cells[c] = flat
			var full: PackedVector3Array = _cells3.get(c, PackedVector3Array())
			full.append(pts[i])
			_cells3[c] = full


## Trails don't climb every little hump: their heights are smoothed along them (the ends stay at the places), and the
## ground is then shaped to them (the trail bed in height()).
func _smooth_trails() -> void:
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for pass_i in range(24):
			var ys := PackedFloat32Array()
			for p in pts:
				ys.append(p.y)
			for i in range(1, pts.size() - 1):
				pts[i].y = ys[i - 1] * 0.25 + ys[i] * 0.5 + ys[i + 1] * 0.25
		e["pts"] = pts                                   # (a packed array out of a Dictionary is a copy: store it back)


## The index holds a point every ~0.8 m along each trail; the trail bed wants them closer (so a bend never leaves a
## bump between two points): add the midpoints to the 3D index (only used for heights and clearance).
func _densify_trails() -> void:
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for i in range(1, pts.size()):
			var m := pts[i - 1].lerp(pts[i], 0.5)
			var c := Vector2i(floori(m.x / CELL), floori(m.z / CELL))
			var full: PackedVector3Array = _cells3.get(c, PackedVector3Array())
			full.append(m)
			_cells3[c] = full


## The nearest trail point to p (within 6 m), or INF.
func _nearest_trail(p: Vector2) -> Vector2:
	var best := Vector2.INF
	var c0 := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var pts = _cells.get(c0 + Vector2i(dx, dz))
			if pts == null:
				continue
			for q: Vector2 in pts:
				if best == Vector2.INF or q.distance_squared_to(p) < best.distance_squared_to(p):
					best = q
	return best


## The direction from a clearing's middle that's furthest from all its trails (the middle of the widest gap); at the
## ridge, never toward the view.
func _gap_dir(id: String) -> Vector3:
	var angles: Array = []
	for way: Dictionary in _labels[id]:
		angles.append(atan2(way["dir"].z, way["dir"].x))
	if id == "ridge":
		angles.append(atan2(VIEW_DIR.y, VIEW_DIR.x))
	elif id == "oak":
		angles.append(atan2(OAK_VIEW.y, OAK_VIEW.x))         # never in the vistas
	elif id == "fork":
		angles.append(atan2(FORK_VIEW.y, FORK_VIEW.x))
	angles.sort()
	var best := 0.0
	var best_gap := -1.0
	for i in angles.size():
		var a: float = angles[i]
		var b: float = angles[(i + 1) % angles.size()] + (TAU if i == angles.size() - 1 else 0.0)
		if b - a > best_gap:
			best_gap = b - a
			best = (a + b) * 0.5
	return Vector3(cos(best), 0, sin(best))


## A clearing's rocks and logs stay out of its vista (the ridge's, the oak's, the fork's): swung round to the side.
func _out_of_view(id: String, c: Vector3, p: Vector3) -> Vector3:
	var views := {"ridge": VIEW_DIR, "oak": OAK_VIEW, "fork": FORK_VIEW}
	if not views.has(id):
		return p
	var v: Vector2 = views[id]
	var d := Vector2(p.x - c.x, p.z - c.z)
	if d.normalized().dot(v) < 0.6:
		return p
	var side := v.orthogonal() * signf(d.dot(v.orthogonal()) + 0.001)
	var q := Vector2(c.x, c.z) + (side * 2.4 - v * 1.8).normalized() * d.length()
	return _off_trail(Vector3(q.x, 0, q.y), 1.6)


## Push a solid thing's spot off the trails until it's at least `clear` from every one (walking never goes through it).
func _off_trail(p: Vector3, clear: float) -> Vector3:
	var q := Vector2(p.x, p.z)
	for k in range(8):
		var t := _nearest_trail(q)
		if t == Vector2.INF or t.distance_to(q) >= clear:
			break
		var away := (q - t).normalized() if q.distance_to(t) > 0.01 else Vector2.RIGHT
		q = t + away * (clear + 0.1)
	var h: Vector2 = HOME_DIR * clampf(q.dot(HOME_DIR), 0.0, 18.0)   # and off the way home over the footbridge
	if q.distance_to(h) < clear:
		var away := (q - h).normalized() if q.distance_to(h) > 0.01 else HOME_DIR.orthogonal()
		q = h + away * (clear + 0.1)
	return Vector3(q.x, height(q.x, q.y), q.y)


## Whether a solid ball (centre, radius) keeps clear of the camera walking any trail: its eye from knee height to
## just over its head, all the way along.
func eye_clear(c: Vector3, r: float) -> bool:
	var reach := ceili((r + 1.0) / CELL)
	var c0 := Vector2i(floori(c.x / CELL), floori(c.z / CELL))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var pts = _cells3.get(c0 + Vector2i(dx, dz))
			if pts == null:
				continue
			for q: Vector3 in pts:
				var lo := q.y + 0.3
				var hi := q.y + EYE + 0.5
				var nearest := Vector3(q.x, clampf(c.y, lo, hi), q.z)
				if nearest.distance_to(c) < r:
					return false
	var hp := Vector2(c.x, c.z)                              # and the way home, over the footbridge
	var hq: Vector2 = HOME_DIR * clampf(hp.dot(HOME_DIR), 0.0, 17.0)
	if hq.distance_to(hp) < r + 0.1:
		var y := height(hq.x, hq.y)
		if Vector3(hq.x, clampf(c.y, y + 0.3, y + EYE + 0.5), hq.y).distance_to(c) < r:
			return false
	return true


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
	return _home_dist(p) < margin + 0.6                   # the way home over the footbridge counts as a trail


## How far p is from the way home (the trailhead, over the footbridge, on toward the garden), and from its creek.
func _home_dist(p: Vector2) -> float:
	var t := clampf(p.dot(HOME_DIR), 0.0, 18.0)
	var d := p.distance_to(HOME_DIR * t)
	var bq := p - BROOK_AT
	if bq.dot(HOME_DIR.orthogonal()) > -15.0 and bq.dot(HOME_DIR.orthogonal()) < 10.0:
		d = minf(d, maxf(absf(bq.dot(HOME_DIR)) - 1.4, 0.0))  # nothing standing in the creek
	return d


func _ground(rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -60.0
	var z0 := -110.0
	var step := 1.6
	var nx := 76
	var nz := 85
	# The shade is blue-green, but the leaf litter must still read as earth under the canopy.
	var moss := Color("465234")
	var litter := Color("604631")
	var grid: Array = []
	for j in range(nz + 1):
		await Slicer.tick(self)
		var row: Array = []
		for i in range(nx + 1):
			var x := x0 + i * step
			var z := z0 + j * step
			var c := moss.lerp(litter, clampf(0.5 + _fine.get_noise_2d(x * 2.0, z * 2.0) * 1.2, 0.0, 1.0)).darkened(rng.randf() * 0.08)
			var needles := smoothstep(PINES_R + 4.0, PINES_R - 2.0, Vector2(x, z).distance_to(NODES["pines"]["at"]))
			if needles > 0.0:                                 # the pine flats: a deep bed of orange needles
				c = c.lerp(Color("9c4f26").lerp(Color("c47c38"), clampf(0.5 + _fine.get_noise_2d(x * 1.3 + 90.0, z * 1.3) * 1.4, 0.0, 1.0)), needles)
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
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/woods_ground.gdshader")
	sm.set_shader_parameter("shadow_map", _baked_shadow("res://assets/baked/shadows_woods.png"))
	sm.set_shader_parameter("shadow_bounds", Vector4(-64.0, -116.0, 44.0, 24.0))
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = sm
	add_child(node)


## The worn dirt of a trail, laid over the ground (its edges a touch above it, so it never sinks in): a pale, packed
## middle where feet go, darker loose soil to each side, the edge wandering in and out; colour varies along it.
func _ribbon(pts: PackedVector3Array, faint: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.8 if not faint else 0.45
	var worn := Color("a08059")
	var loose := Color("6b5237")
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
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/woods_ground.gdshader")
	m.set_shader_parameter("shadow_map", _baked_shadow("res://assets/baked/shadows_woods.png"))
	m.set_shader_parameter("shadow_bounds", Vector4(-64.0, -116.0, 44.0, 24.0))
	m.set_shader_parameter("cull_disabled", true)
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
		await Slicer.tick(self)
		var pts: PackedVector3Array = e["pts"]
		for i in range(1, pts.size() - 1):
			var a := pts[i - 1]
			var b := pts[i + 1]
			var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
			var side := d.cross(Vector3.UP)
			for k in range(3):
				var o := side * rng.randf_range(-1.1, 1.1) + d * rng.randf_range(-0.4, 0.4)
				var p := pts[i] + o
				var on_path := absf(o.dot(side)) < 0.75           # on the trail's dirt, or on the ground beside it
				var y := (maxf(height(p.x, p.z), pts[i].y - 0.3) + 0.06) if on_path else height(p.x, p.z) + 0.03
				if rng.randf() < 0.55:
					var sz := rng.randf_range(0.03, 0.08)
					pebbles.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(sz, sz * 0.6, sz * 0.8)), Vector3(p.x, y, p.z)), Color("8a867c").darkened(rng.randf() * 0.3)])
				var lz := rng.randf_range(0.05, 0.09)
				leaves.append([Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3(lz, 0.006, lz * 1.4)), Vector3(p.x, y + 0.005, p.z)), autumn.pick_random()])
			if rng.randf() < 0.07:                             # a root across the path
				var yaw := atan2(side.x, side.z)
				var across := Basis(d * 0.04, side.normalized() * 1.6, d.cross(side).normalized() * 0.04)   # long axis across the path
				var ry := maxf(height(pts[i].x, pts[i].z), pts[i].y - 0.3) + 0.06   # lying on the trail's surface
				roots.append([Transform3D(across, Vector3(pts[i].x, ry, pts[i].z)), Color("5a4632")])
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


func _multimesh(mesh: Mesh, items: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/woods_ground.gdshader")
	m.set_shader_parameter("shadow_map", _baked_shadow("res://assets/baked/shadows_woods.png"))
	m.set_shader_parameter("shadow_bounds", Vector4(-64.0, -116.0, 44.0, 24.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = m
	add_child(node)


func _rock_multimesh(mesh: Mesh, items: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = RockFactory.material(Color.WHITE)
	add_child(node)


## A trail's height at a trail point (from the index).
func _trail_y(t: Vector2) -> float:
	var pts = _cells3.get(Vector2i(floori(t.x / CELL), floori(t.y / CELL)))
	if pts != null:
		for q: Vector3 in pts:
			if Vector2(q.x, q.z).distance_to(t) < 0.01:
				return q.y
	return height(t.x, t.y)


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


const SIGN_FONT := preload("res://assets/fonts/SignBookman-Demi.otf")


## A wooden arrow sign at the mouth of a trail: a post beside the path, and a painted board turned to face the
## clearing, its pointed end aimed down the trail. Returns the painted name (the one you're facing reads brighter).
func _sign(from: String, dir: Vector3, text: String) -> Label3D:
	var c := node_pos(from)
	var right := dir.cross(Vector3.UP).normalized()
	var at := _off_trail(c + dir * 4.2 - right * 1.25, 1.0)
	var holder := Node3D.new()
	holder.name = "Sign"
	add_child(holder)
	holder.position = at
	var face := Vector3(c.x - at.x, 0, c.z - at.z).normalized()
	holder.rotation.y = atan2(face.x, face.z) + deg_to_rad(32.0)   # facing you, its right-hand point swung down the trail
	var post := GardenProps.mat("signpost", Color("4a3626"))
	var board := GardenProps.mat("signboard", Color("5a3e28"))            # stained dark, like a park sign
	var w := clampf(0.3 + text.length() * 0.08, 0.9, 1.9)
	GardenProps.part(holder, GardenProps.cyl(0.05, 0.06, 1.75, 7), post, Vector3(-w * 0.5 + 0.12, 0.85, -0.05), Vector3(0, 0, -2), 0.008)
	GardenProps.part(holder, GardenProps.box(Vector3(w, 0.32, 0.045)), board, Vector3(0.0, 1.45, 0), Vector3(0, 0, 1.5), 0.01)
	GardenProps.part(holder, GardenProps.box(Vector3(0.2, 0.2, 0.045)), board, Vector3(w * 0.5, 1.45 + w * 0.5 * 0.026, 0), Vector3(0, 0, 45 + 1.5), 0.01)
	var paint := Color(0.78, 0.7, 0.54)
	var front := Label3D.new()
	front.text = text
	front.font = SIGN_FONT                                          # routed letters, painted cream
	front.font_size = 46
	front.outline_size = 7
	front.outline_modulate = Color("24180e")                         # the cut edge
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
	m.albedo_color = Color(1.0, 0.95, 0.78, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bar := BoxMesh.new()
	bar.size = Vector3(0.07, 0.02, 0.5)
	var arrow := _arrow_mesh()
	for want: float in [2.2, 3.5, 4.6, 5.7]:
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
				if want < 3.0:                                  # first, a big arrow: this way
					var a := MeshInstance3D.new()
					a.mesh = arrow
					a.material_override = m
					a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					chev.add_child(a)
					break
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


## A flat arrow on the ground pointing along +z: a shaft and a broad head.
func _arrow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.09, 0, -0.55), Vector3(0.09, 0, -0.55), Vector3(0.09, 0, 0.05), Vector3(-0.09, 0, 0.05),
		Vector3(-0.34, 0, 0.05), Vector3(0.34, 0, 0.05), Vector3(0, 0, 0.6)]
	for t: Array in [[0, 1, 2], [0, 2, 3], [4, 5, 6]]:
		for i: int in t:
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[i])
	var m := st.commit()
	return m
