extends "res://scripts/garden/props/props_builds.gd"

## Props 4/4 - around the garden: the burying ground, the creek and footbridge, the house and porch, barrels and piles.
##
## The fixed scenery at the yard's edges. Mostly static: merged by merge_static because it never moves.
##
## Part of the props layer chain (the full order is at the top of scripts/garden/garden_props.gd). Code here was moved verbatim
## from the old single file; only its place changed.

# ------------------------------------------------------------------ the old burying ground past the fence
## A slate headstone: a thin slab with a rounded top (and shoulders), leaning a little, lichen on some.
static func headstone(parent: Node3D, at: Vector3, yaw: float, height: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Headstone", at, yaw)
	var slate := Color("555a62").lerp(Color("6e6a64"), rng.randf())
	if rng.randf() < 0.35:
		slate = slate.lerp(Color("8a9a6a"), 0.35)                  # lichen
	var stone := part(r, blob(Vector3(height * 0.34, height * 0.5, 0.05), {"exponent": 3.2, "taper": -0.12, "taper_axis": "y", "flat_bottom": 0.7}),
		mat("slate%d" % int(slate.r * 100 + slate.g * 10), slate), Vector3(0, height * 0.42, 0), Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-6, 6)), 0.01)
	stone.name = "Slate"
	return r


## A bare old tree: no leaves at all, a twisted trunk and a crown of grey limbs. Autumn, not gloom: a perch.
static func dead_tree(parent: Node3D, at: Vector3, height: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "BareTree", at, 0.0)
	var bark := mat("deadbark", Color("7a726a"))
	var limb := func(a: Vector3, b: Vector3, r0: float, r1: float) -> void:
		var node := MeshInstance3D.new()
		node.mesh = cyl(r1, r0, a.distance_to(b), 7)
		var y := (b - a).normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		node.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
		node.material_override = bark
		node.material_overlay = hull(0.015)
		r.add_child(node)
	var top := Vector3(rng.randf_range(-0.5, 0.5), height * 0.55, rng.randf_range(-0.5, 0.5))
	limb.call(Vector3.ZERO, top, 0.45, 0.25)
	var tips: Array = [[top, 0.22, 0]]
	while not tips.is_empty():
		var t: Array = tips.pop_back()
		var from: Vector3 = t[0]
		var rad: float = t[1]
		var depth: int = t[2]
		if depth >= 3:
			continue
		for k in range(3 if depth < 2 else 2):
			var a := rng.randf_range(0, TAU)
			var len := height * (0.32 - depth * 0.08) * rng.randf_range(0.7, 1.1)
			var to := from + Vector3(cos(a) * len * 0.75, len * rng.randf_range(0.45, 0.8), sin(a) * len * 0.75)
			limb.call(from, to, rad, rad * 0.55)
			tips.append([to, rad * 0.55, depth + 1])
	return r


# ------------------------------------------------------------------ around the garden
## The creek: a strip mesh following `center(z) -> x`, `width` wide, from z0 to z1, with the creek shader.
static func creek(parent: Node3D, center: Callable, z0: float, z1: float, width: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := int((z1 - z0) / 0.5)
	var along := 0.0
	var prev := Vector3.INF
	var rows: Array = []
	for i in range(steps + 1):
		var z := lerpf(z0, z1, float(i) / steps)
		var c := Vector3(center.call(z), 0.012, z)
		if prev != Vector3.INF:
			along += c.distance_to(prev)
		var nxt := Vector3(center.call(z + 0.1), 0.012, z + 0.1)
		var side := (nxt - c).normalized().cross(Vector3.UP)
		var w := width * (0.5 + 0.1 * sin(z * 0.7))
		rows.append([c - side * w, c + side * w, along])
		prev = c
	for i in range(rows.size() - 1):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var quad := [[a[0], Vector2(a[2], 0)], [a[1], Vector2(a[2], 1)], [b[1], Vector2(b[2], 1)], [b[0], Vector2(b[2], 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/creek.gdshader")
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.name = "Creek"
	parent.add_child(node)
	return node


## A plank footbridge across the creek, low and a bit crooked, with a rail on one side.
static func footbridge(parent: Node3D, from: Vector3, to: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Footbridge", Vector3.ZERO, 0.0)
	var wood := mat("bridge", Color("8a6e4e"))
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP)
	var length := from.distance_to(to)
	var yaw := rad_to_deg(atan2(-dir.z, dir.x))
	var n := int(length / 0.32)
	for k in range(n):
		var at := from + dir * (k + 0.5) * length / n + Vector3(0, 0.1 + 0.08 * sin(PI * k / n), 0)
		part(r, box(Vector3(0.26, 0.06, 1.2)), wood, at + side * rng.randf_range(-0.04, 0.04), Vector3(0, yaw + rng.randf_range(-4, 4), rng.randf_range(-3, 3)), 0.008)
	for k in range(4):
		var at := from + dir * length * (k + 0.5) / 4.0 + side * 0.62
		part(r, cyl(0.04, 0.05, 0.8, 6), wood, at + Vector3(0, 0.45, 0), Vector3.ZERO, 0.008)
	part(r, cyl(0.035, 0.035, length, 6), wood, (from + to) * 0.5 + side * 0.62 + Vector3(0, 0.82, 0), Vector3(0, yaw, 90), 0.008)
	return r


## Cattails and reeds at a creek's edge.
static func cattails(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Cattails", at, rng.randf_range(0, 360))
	var reed := mat("reed", Color("7a8a4a"))
	var head := mat("cattail", Color("6a4a2e"))
	for k in range(rng.randi_range(5, 9)):
		var p := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		var h := rng.randf_range(0.9, 1.6)
		var tilt := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
		part(r, cyl(0.015, 0.025, h, 5), reed, p + Vector3(0, h * 0.5, 0), tilt, 0.0)
		if k % 2 == 0:
			part(r, blob(Vector3(0.05, 0.16, 0.05), {"exponent": 2.0}), head, p + Vector3(0, h * 0.82, 0), tilt, 0.006)
	return r


## A New England house seen from the back: clapboard box, steep gable roof, chimney, windows with white trim, a back
## door. `porch` adds steps toward the garden.
static func house(parent: Node3D, at: Vector3, yaw: float, siding: Color, size: Vector3, porch: bool, rng: RandomNumberGenerator, door := Color("3a4a3a"), stair_x := INF) -> Node3D:
	var r := root(parent, "House", at, yaw)
	var wall := mat("siding%s" % siding.to_html(false), siding)
	var trim := mat("trim", Color("efeae0"))
	var roof_m := mat("shingles", Color("4a4440"))
	var glass := mat("window", Color("3e4a52"), 0.3)
	part(r, box(size), wall, Vector3(0, size.y * 0.5, 0), Vector3.ZERO, 0.02)
	var roof := PrismMesh.new()
	roof.size = Vector3(size.x * 1.08, size.y * 0.6, size.z * 1.1)
	part(r, roof, roof_m, Vector3(0, size.y + size.y * 0.3, 0), Vector3(0, 90, 0), 0.02)
	part(r, box(Vector3(0.7, 1.6, 0.7)), mat("brick", Color("8a4a3a")), Vector3(size.x * 0.28, size.y * 1.45, 0), Vector3.ZERO, 0.012)
	# the back wall faces -z (the garden): windows in two rows, a door
	var face := -size.z * 0.5 - 0.03
	for row in range(2):
		for k in range(3):
			var x := (k - 1) * size.x * 0.3
			if row == 0 and k == 1:
				continue
			var y := size.y * (0.3 + row * 0.42)
			part(r, box(Vector3(0.9, 1.1, 0.06)), trim, Vector3(x, y, face), Vector3.ZERO, 0.0)
			var lit := rng.randf() < 0.3
			part(r, box(Vector3(0.7, 0.9, 0.08)), mat("windowlit", Color("e8c878")) if lit else glass, Vector3(x, y, face - 0.01), Vector3.ZERO, 0.0)
	if porch:
		_back_porch(r, face, size, door, stair_x)
	else:
		part(r, box(Vector3(1.0, 2.0, 0.08)), mat("door%s" % door.to_html(false), door), Vector3(0, 1.0, face), Vector3.ZERO, 0.008)
	return r


## A battered green wheelbarrow by the gate: where hauled junk goes.
static func wheelbarrow(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Wheelbarrow", at, yaw)
	var tray := mat("barrow", Color("4a6a4a"))
	var steel := mat("steel", Color("5a5550"))
	part(r, blob(Vector3(0.75, 0.32, 0.5), {"exponent": 3.0, "taper": 0.2}), tray, Vector3(0, 0.62, 0), Vector3(180, 0, 0), 0.014)
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.12
	wheel.outer_radius = 0.26
	part(r, wheel, mat("tyre", Color("2a2622")), Vector3(0.82, 0.26, 0), Vector3(90, 0, 0), 0.01)
	for side: float in [-1.0, 1.0]:
		part(r, cyl(0.03, 0.03, 1.9, 6), steel, Vector3(-0.1, 0.5, side * 0.3), Vector3(0, 0, 82), 0.006)
		part(r, cyl(0.03, 0.03, 0.5, 6), steel, Vector3(-0.35, 0.25, side * 0.3), Vector3(0, 0, -10), 0.006)
	return r


## A dented galvanized trash barrel with its lid (child "Lid") and what's in it (child "Fill", scaled with how full).
static func trash_barrel(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "TrashBarrel", at, yaw)
	var zinc := mat("zinc", Color("9aa0a2"), 0.55)
	part(r, cyl(0.42, 0.38, 1.0, 16), zinc, Vector3(0, 0.5, 0), Vector3(0, 0, 2), 0.014)
	var rib := TorusMesh.new()
	rib.inner_radius = 0.39
	rib.outer_radius = 0.44
	for y: float in [0.22, 0.55, 0.88]:
		part(r, rib, zinc, Vector3(0, y, 0), Vector3(0, 0, 2), 0.0)
	part(r, blob(Vector3(0.12, 0.08, 0.12), {"exponent": 2.0}), mat("dent", Color("7e8486")), Vector3(0.36, 0.62, 0.1), Vector3.ZERO, 0.0)
	var fill := part(r, blob(Vector3(0.36, 0.22, 0.36), "dome"), mat("rubbish", Color("5a4a3a")), Vector3(0, 0.92, 0), Vector3.ZERO, 0.0)
	fill.name = "Fill"
	fill.scale = Vector3(1, 0.01, 1)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(-0.42, 1.02, 0)              # hinged at the back edge
	r.add_child(lid)
	part(lid, cyl(0.46, 0.46, 0.06, 16), zinc, Vector3(0.42, 0.03, 0), Vector3.ZERO, 0.01)
	part(lid, box(Vector3(0.22, 0.05, 0.06)), mat("handle", Color("2f2b28")), Vector3(0.42, 0.1, 0), Vector3.ZERO, 0.0)
	return r


## A white resin lawn chair, standing upright on its own in the grass: somebody sits here to watch.
static func chair_upright(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := lawn_chair(parent, at, yaw)
	r.name = "TheChair"
	var chair: Node3D = r.get_child(0)
	chair.rotation_degrees = Vector3.ZERO
	chair.position = Vector3.ZERO
	r.get_child(r.get_child_count() - 1).queue_free()          # no dirt stain: it hasn't fallen over
	return r


## An ironing board somebody carried out and never carried back: faded cover, rusty X legs.
## Six primitives, two materials; garden.gd bakes it into one mesh per material.
static func ironing_board(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "IroningBoard", at, yaw)
	var board := Node3D.new()
	board.rotation_degrees = Vector3(2.5, 0, -1.5)            # the lawn isn't level
	r.add_child(board)
	var cover := mat("ironcover", Color("b7c4c2"), 0.95)
	part(board, box(Vector3(0.8, 0.04, 0.38)), cover, Vector3(-0.15, 0.86, 0))
	part(board, cyl(0.19, 0.19, 0.04, 16), cover, Vector3(0.25, 0.86, 0)).scale = Vector3(2.0, 1, 1)   # the nose
	var legs := rust_mat()
	for side: float in [-1.0, 1.0]:                           # the X, one U-frame each way, seen as two rods
		for z: float in [-0.12, 0.12]:
			part(board, cyl(0.014, 0.014, 1.05, 6), legs, Vector3(-0.05, 0.42, z), Vector3(0, 0, side * 38.4), 0.006)
	return r


## A woodpile stacked against a tree: split logs in rows, a little untidy, bark out.
static func woodpile(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Woodpile", at, yaw)
	var bark := mat("logbark", Color("6a5038"))
	var cut := mat("logcut", Color("c8a678"))
	for row in range(4):
		var n := 6 - row
		for k in range(n):
			var x := (k - (n - 1) * 0.5) * 0.36 + rng.randf_range(-0.04, 0.04)
			var log := part(r, cyl(0.17, 0.17, 1.2, 8), bark, Vector3(x, 0.17 + row * 0.31, rng.randf_range(-0.06, 0.06)), Vector3(90, rng.randf_range(-6, 6), 0), 0.01)
			part(log, cyl(0.15, 0.15, 0.02, 8), cut, Vector3(0, 0.6, 0), Vector3.ZERO, 0.0)
	return r


## A brush pile at the woodland edge: branches and sticks heaped and crossed, leaves caught in it. Shy woodland
## visitors shelter here. It grows when you haul more sticks and branches onto it (garden_grab.gd).
static func brush_pile(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "BrushPile", at, rng.randf_range(0, 360))
	var wood := mat("brush", Color("5e4a36"))
	for k in range(16):
		var a := rng.randf_range(0, TAU)
		var len := rng.randf_range(1.0, 2.0)
		var y := rng.randf_range(0.1, 0.7)
		part(r, cyl(0.03, 0.05, len, 5), wood, Vector3(cos(a) * 0.2, y, sin(a) * 0.2), Vector3(rng.randf_range(-70, 70), rad_to_deg(a), rng.randf_range(60, 120)), 0.006)
	part(r, blob(Vector3(0.9, 0.45, 0.8), "dome"), mat("brushleaves", Color("8a6a3a")), Vector3(0, 0.1, 0), Vector3.ZERO, 0.0)
	return r


## The raised back porch of the house that overlooks the garden: a plank deck on posts at first-floor height, a
## railing with balusters, stairs down the side to the yard, a lattice skirt underneath, the back door opening onto
## it. (This house will keep getting more detailed.)
static func _back_porch(r: Node3D, face: float, size: Vector3, door: Color, stair_x := INF) -> void:
	var deck_h := 1.35
	var depth := 2.6
	var width := 5.2
	var sx := stair_x if stair_x != INF else width * 0.5 - 0.55   # the stairs' middle (lined up with the yard's gate)
	var wood := mat("deckwood", Color("9a7a58"))
	var post_m := mat("deckpost", Color("8a6a4a"))
	var rail_m := mat("rail", Color("efeae0"))
	var front := face - depth                                   # the deck's outer edge (toward the garden)
	# the back door, up at deck level
	part(r, box(Vector3(1.0, 2.05, 0.08)), mat("door%s" % door.to_html(false), door), Vector3(0, deck_h + 1.03, face), Vector3.ZERO, 0.008)
	part(r, box(Vector3(1.2, 0.08, 0.1)), rail_m, Vector3(0, deck_h + 2.1, face), Vector3.ZERO, 0.0)
	# deck boards
	var boards := 13
	for k in range(boards):
		var x := -width * 0.5 + (k + 0.5) * width / boards
		part(r, box(Vector3(width / boards * 0.94, 0.07, depth)), wood, Vector3(x, deck_h, face - depth * 0.5), Vector3.ZERO, 0.004)
	part(r, box(Vector3(width, 0.22, 0.1)), post_m, Vector3(0, deck_h - 0.12, front), Vector3.ZERO, 0.006)   # rim joist
	# posts down to the ground
	for x: float in [-width * 0.5 + 0.1, 0.0, width * 0.5 - 0.1]:
		part(r, box(Vector3(0.16, deck_h, 0.16)), post_m, Vector3(x, deck_h * 0.5, front + 0.1), Vector3.ZERO, 0.006)
	# lattice skirt between the posts
	var lattice := mat("lattice", Color("d8d0bc"))
	for k in range(18):
		var x := -width * 0.5 + 0.2 + k * (width - 0.4) / 17.0
		part(r, box(Vector3(0.03, deck_h * 1.1, 0.02)), lattice, Vector3(x, deck_h * 0.45, front + 0.16), Vector3(0, 0, 32), 0.0)
		part(r, box(Vector3(0.03, deck_h * 1.1, 0.02)), lattice, Vector3(x, deck_h * 0.45, front + 0.17), Vector3(0, 0, -32), 0.0)
	# railing: front and sides (an opening in the front for the stairs)
	var rail_y := deck_h + 0.95
	var runs := [[Vector3(-width * 0.5, 0, front), Vector3(sx - 0.55, 0, front)], [Vector3(sx + 0.55, 0, front), Vector3(width * 0.5, 0, front)],
		[Vector3(-width * 0.5, 0, front), Vector3(-width * 0.5, 0, face)],
		[Vector3(width * 0.5, 0, front + 0.0), Vector3(width * 0.5, 0, face)]]
	for run: Array in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var len := a.distance_to(b)
		var mid := (a + b) * 0.5
		var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
		part(r, box(Vector3(len if along_x else 0.09, 0.07, 0.09 if along_x else len)), rail_m, mid + Vector3(0, rail_y, 0), Vector3.ZERO, 0.004)
		var n := int(len / 0.17)
		for k in range(n + 1):
			var p: Vector3 = a.lerp(b, float(k) / maxf(1.0, float(n)))
			part(r, box(Vector3(0.04, 0.9, 0.04)), rail_m, p + Vector3(0, deck_h + 0.48, 0), Vector3.ZERO, 0.0)
	# stairs down to the yard, toward the garden
	var steps := 8
	var rise := deck_h / steps
	for k in range(steps):
		var z := front - 0.14 - k * 0.28
		part(r, box(Vector3(1.0, 0.06, 0.3)), wood, Vector3(sx, deck_h - (k + 1) * rise + 0.03, z), Vector3.ZERO, 0.004)
	for x: float in [sx - 0.5, sx + 0.5]:
		var top := Vector3(x, deck_h + 0.9, front)
		var bottom := Vector3(x, 0.9, front - steps * 0.28)
		var rail := MeshInstance3D.new()
		rail.mesh = box(Vector3(0.06, 0.06, top.distance_to(bottom)))
		rail.material_override = rail_m
		rail.transform = Transform3D(Basis.looking_at((bottom - top).normalized(), Vector3.UP), (top + bottom) * 0.5)
		r.add_child(rail)
		part(r, box(Vector3(0.1, 1.0, 0.1)), post_m, Vector3(x, 0.5, front - steps * 0.28), Vector3.ZERO, 0.006)
