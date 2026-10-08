class_name GardenProps
extends RefCounted

## The garden's things, built from simple shapes in the same storybook style as the pets: matte, soft colours, a
## thin ink outline. Not a perfect eden - a real back garden: a tipped lawn chair, a rusty grill, a broken fence,
## a leaking sprinkler, sticks and branches, a tire, a tipped pot, leaf piles. Every builder takes a parent and a
## seeded RandomNumberGenerator and returns the prop's root node.

const INK := Color("2b2a20")
static var _mats := {}


static func mat(name: String, color: Color, roughness := 1.0) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic_specular = 0.0
	_mats[name] = m
	return m


static func rust_mat() -> StandardMaterial3D:
	if _mats.has("rust"):
		return _mats["rust"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in range(64):
		for x in range(64):
			var n := sin(x * 0.31 + y * 0.17) * 0.5 + sin(x * 0.07 - y * 0.29) * 0.5 + rng.randf_range(-0.25, 0.25)
			var base := Color("3b3633")                        # old black enamel
			var rust := Color("9a5232").lerp(Color("c97a3e"), rng.randf())
			img.set_pixel(x, y, base.lerp(rust, smoothstep(-0.2, 0.5, n)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 1.0
	m.metallic_specular = 0.1
	_mats["rust"] = m
	return m


static func hull(width: float) -> ShaderMaterial:
	var key := "hull%.3f" % width
	if _mats.has(key):
		return _mats[key]
	var h := ShaderMaterial.new()
	h.shader = load("res://shaders/ink_hull.gdshader")
	h.set_shader_parameter("ink", INK)
	h.set_shader_parameter("width", width)
	_mats[key] = h
	return h


static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg := Vector3.ZERO, outline := 0.012) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation_degrees = rot_deg
	if outline > 0.0:
		node.material_overlay = hull(outline)
	parent.add_child(node)
	return node


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(r_top: float, r_bottom: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = seg
	return c


static func blob(radii: Vector3, shape: Variant = {}) -> ArrayMesh:
	return HedgeAnatomy.build_mesh({"radii": radii, "shape": shape}, 14, 24)


static func root(parent: Node3D, name: String, at: Vector3, yaw_deg: float) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = at
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	return n


# ------------------------------------------------------------------ the things
## A white resin lawn chair, knocked over onto its side.
static func lawn_chair(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "LawnChair", at, yaw)
	var chair := Node3D.new()
	chair.rotation_degrees = Vector3(0, 0, 96)   # tipped over
	chair.position = Vector3(0.55, 0.5, 0)
	r.add_child(chair)
	var resin := mat("resin", Color("e6e2d4"), 0.7)
	part(chair, box(Vector3(0.95, 0.07, 0.85)), resin, Vector3(0, 0.82, 0))
	for i in range(5):
		part(chair, box(Vector3(0.12, 0.85, 0.05)), resin, Vector3(-0.38 + i * 0.19, 1.3, -0.42), Vector3(-12, 0, 0))
	part(chair, box(Vector3(0.95, 0.08, 0.06)), resin, Vector3(0, 1.74, -0.5), Vector3(-12, 0, 0))
	for sx: float in [-0.44, 0.44]:
		for sz: float in [-0.38, 0.38]:
			part(chair, cyl(0.04, 0.05, 0.84), resin, Vector3(sx, 0.42, sz))
		part(chair, box(Vector3(0.07, 0.06, 0.8)), resin, Vector3(sx, 1.12, 0.0))
	# a little dirt and a green stain where it has been lying
	part(r, blob(Vector3(0.7, 0.03, 0.5), "pebble"), mat("dirt", Color("7a6448")), Vector3(0.3, 0.01, 0), Vector3.ZERO, 0.0)
	return r


## A rusty kettle grill: one leg bent, its lid fallen in the grass beside it, ash spilled.
static func rusty_grill(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "RustyGrill", at, yaw)
	var rust := rust_mat()
	var bowl := part(r, blob(Vector3(0.6, 0.48, 0.6), {"exponent": 2.0, "flat_bottom": 0.02}), rust, Vector3(0, 1.0, 0), Vector3(180, 0, 6), 0.014)
	bowl.scale = Vector3(1, 0.9, 1)
	for i in range(5):   # the grate
		part(r, cyl(0.012, 0.012, 1.1, 5), mat("steel", Color("5a5550")), Vector3(-0.4 + i * 0.2, 1.02, 0), Vector3(90, 0, 0), 0.0)
	for k in range(3):
		var a := deg_to_rad(90.0 + k * 120.0)
		var foot := Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62)
		if k == 1:   # the bent leg
			part(r, cyl(0.025, 0.025, 0.55, 6), rust, Vector3(cos(a) * 0.4, 0.75, sin(a) * 0.4), Vector3(sin(a) * 25, 0, -cos(a) * 25), 0.008)
			part(r, cyl(0.025, 0.025, 0.55, 6), rust, Vector3(cos(a) * 0.62, 0.3, sin(a) * 0.62) + Vector3(0.15, 0, 0), Vector3(0, 0, 50), 0.008)
		else:
			part(r, cyl(0.025, 0.025, 1.05, 6), rust, (foot + Vector3(0, 1.0, 0)) * 0.5 + Vector3(0, 0.0, 0), Vector3(sin(a) * 18, 0, -cos(a) * 18), 0.008)
	var lid := part(r, blob(Vector3(0.6, 0.38, 0.6), {"exponent": 2.0, "flat_bottom": 0.02}), rust, Vector3(1.25, 0.18, 0.4), Vector3(0, 30, 68), 0.014)
	lid.name = "Lid"
	part(lid, cyl(0.05, 0.05, 0.18, 6), mat("handle", Color("2f2b28")), Vector3(0, 0.42, 0), Vector3.ZERO, 0.0)
	part(r, blob(Vector3(0.5, 0.025, 0.35), "pebble"), mat("ash", Color("8f8a84")), Vector3(-0.2, 0.01, 0.55), Vector3.ZERO, 0.0)
	return r


## A run of picket fence: weathered paint, pickets missing, leaning, snapped; optionally a collapsed section lying
## in the grass (where visitors come through).
static func broken_fence(parent: Node3D, from_x: float, to_x: float, z: float, rng: RandomNumberGenerator, gap := Vector2(INF, INF)) -> Node3D:
	var r := root(parent, "Fence", Vector3(0, 0, z), 0.0)
	var paint := mat("fence", Color("e3ddcb"))
	var old := mat("fence_old", Color("b9b2a0"))
	var x := from_x
	while x < to_x:
		var in_gap := x > gap.x and x < gap.y
		if not in_gap:
			part(r, box(Vector3(0.16, 1.7, 0.16)), old, Vector3(x, 0.85, 0), Vector3(0, 0, rng.randf_range(-4, 4)), 0.01)
			part(r, box(Vector3(2.2, 0.1, 0.06)), paint, Vector3(x + 1.1, 1.25, -0.1), Vector3(0, 0, rng.randf_range(-2, 2)), 0.008)
			part(r, box(Vector3(2.2, 0.1, 0.06)), paint, Vector3(x + 1.1, 0.45, -0.1), Vector3(0, 0, rng.randf_range(-2, 2)), 0.008)
			for k in range(6):
				var px := x + 0.25 + k * 0.36
				var roll := rng.randf()
				if roll < 0.14:
					continue                                     # missing
				var h := 1.45 if roll > 0.24 else rng.randf_range(0.5, 0.9)   # snapped short
				var lean := rng.randf_range(-3, 3) if roll > 0.33 else rng.randf_range(-18, 18)
				var picket := part(r, box(Vector3(0.22, h, 0.05)), paint if rng.randf() < 0.7 else old, Vector3(px, h * 0.5, -0.06), Vector3(0, 0, lean), 0.008)
				if h > 1.0:
					part(picket, box(Vector3(0.16, 0.16, 0.05)), paint, Vector3(0, h * 0.5, 0), Vector3(0, 0, 45), 0.006)
		else:
			# the collapsed section, flat in the grass
			for k in range(5):
				part(r, box(Vector3(0.22, 1.4, 0.05)), old, Vector3(x + 0.3 + k * 0.4, 0.04, 1.2 + rng.randf_range(-0.2, 0.2)), Vector3(90, rng.randf_range(-15, 15), 0), 0.008)
			part(r, box(Vector3(2.0, 0.1, 0.06)), paint, Vector3(x + 1.1, 0.06, 0.9), Vector3(90, 8, 0), 0.008)
		x += 2.2
	return r


## A fallen branch with a fork or two.
static func branch(parent: Node3D, at: Vector3, yaw: float, length: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Branch", at, yaw)
	var bark := mat("bark", Color("6b4f36"))
	part(r, cyl(0.06, 0.11, length, 8), bark, Vector3(0, 0.1, 0), Vector3(0, 0, 90), 0.008)
	for k in range(rng.randi_range(1, 3)):
		var along := rng.randf_range(-0.3, 0.35) * length
		var side := 1.0 if k % 2 == 0 else -1.0
		part(r, cyl(0.025, 0.05, length * 0.45, 6), bark, Vector3(along + length * 0.1, 0.1, side * length * 0.12), Vector3(0, side * 35, 90), 0.006)
	return r


static func stick(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Stick", at, yaw)
	part(r, cyl(0.025, 0.035, rng.randf_range(0.5, 1.1), 6), mat("stick", Color("7c5e40")), Vector3(0, 0.04, 0), Vector3(0, 0, 90), 0.005)
	return r


## An oscillating sprinkler, knocked over and leaking: a puddle, a hose snaking off to a coil.
static func broken_sprinkler(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Sprinkler", at, yaw)
	var plastic := mat("sprinkler", Color("d9b23b"), 0.6)
	var s := Node3D.new()
	s.rotation_degrees = Vector3(0, 0, 70)
	s.position = Vector3(0, 0.2, 0)
	r.add_child(s)
	part(s, box(Vector3(0.5, 0.12, 0.25)), plastic, Vector3.ZERO, Vector3.ZERO, 0.008)
	part(s, cyl(0.05, 0.05, 0.9, 8), mat("sprinkler_bar", Color("9ea4a8"), 0.5), Vector3(0, 0.15, 0), Vector3(90, 0, 0), 0.006)
	# the puddle it made
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.6, 1.8)
	var puddle := MeshInstance3D.new()
	puddle.mesh = plane
	puddle.material_override = water
	puddle.position = Vector3(0.9, 0.012, 0.4)
	puddle.rotation_degrees = Vector3(0, 20, 0)
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puddle.name = "Puddle"
	r.add_child(puddle)
	# the hose: a few lazy segments, then a coil
	var hose := mat("hose", Color("4f7a3a"), 0.8)
	var p := Vector3(-0.3, 0.05, 0)
	var dir := Vector3(-1, 0, 0.3).normalized()
	for k in range(6):
		dir = dir.rotated(Vector3.UP, sin(k * 1.3) * 0.5)
		var q := p + dir * 0.7
		var seg := part(r, cyl(0.04, 0.04, 0.72, 8), hose, (p + q) * 0.5, Vector3.ZERO, 0.0)
		seg.basis = Basis(Quaternion(Vector3.UP, dir))
		p = q
	var coil := TorusMesh.new()
	coil.inner_radius = 0.38
	coil.outer_radius = 0.5
	for k in range(3):
		part(r, coil, hose, p + Vector3(0.0, 0.06 + k * 0.08, 0.0) + dir * 0.4, Vector3(0, 0, 0), 0.0)
	return r


static func rock(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Rock", at, rng.randf_range(0, 360))
	var grey := Color("8d8a80").lerp(Color("a39e90"), rng.randf())
	part(r, blob(Vector3(size, size * 0.62, size * 0.8), {"exponent": 2.3, "taper": rng.randf_range(-0.2, 0.2), "flat_bottom": 0.4}), mat("rock%d" % int(grey.r * 100), grey), Vector3(0, size * 0.22, 0), Vector3.ZERO, 0.01)
	return r


## A New England dry-stone wall: two or three courses of field stones, no mortar, slumped and mossy in places.
static func stone_wall(parent: Node3D, from: Vector3, to: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "StoneWall", Vector3.ZERO, 0.0)
	var length := from.distance_to(to)
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP)
	var moss := Color("6e7a4a")
	for course in range(3):
		var x := rng.randf_range(0.0, 0.3)
		while x < length:
			var size := rng.randf_range(0.28, 0.42) * (1.0 - course * 0.12)
			var slump := 0.5 + 0.5 * sin(x * 0.7 + 1.3)          # a lower, tumbled stretch here and there
			if course == 2 and slump < 0.35:
				x += size * 1.6
				continue
			var at := from + dir * x + side * rng.randf_range(-0.08, 0.08) + Vector3(0, course * 0.36 * (0.75 + 0.25 * slump), 0)
			var grey := Color("8d8a80").lerp(Color("a7a294"), rng.randf())
			if course == 2 and rng.randf() < 0.3:
				grey = grey.lerp(moss, 0.6)                          # moss on the cap stones
			var stone := part(r, blob(Vector3(size, size * 0.55, size * 0.75), {"exponent": 2.4, "flat_bottom": 0.5}), mat("wall%d" % int(grey.r * 100 + grey.g * 10), grey),
				at + Vector3(0, size * 0.3, 0), Vector3(rng.randf_range(-6, 6), rad_to_deg(atan2(-dir.z, dir.x)) + rng.randf_range(-12, 12), rng.randf_range(-6, 6)), 0.01)
			stone.name = "Stone"
			x += size * 1.75
	return r


static func old_tire(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Tire", at, yaw)
	var t := TorusMesh.new()
	t.inner_radius = 0.32
	t.outer_radius = 0.62
	t.rings = 24
	part(r, t, mat("rubber", Color("3a3836")), Vector3(0, 0.1, 0), Vector3(0, 0, 8), 0.01)
	return r


## A terracotta pot on its side, its soil spilling out.
static func tipped_pot(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Pot", at, yaw)
	part(r, cyl(0.38, 0.26, 0.6, 14), mat("pot", Color("b06c48")), Vector3(0, 0.33, 0), Vector3(0, 0, 90), 0.012)
	part(r, blob(Vector3(0.55, 0.08, 0.45), "pebble"), mat("soil", Color("5a4230")), Vector3(0.55, 0.03, 0), Vector3.ZERO, 0.0)
	return r


# ------------------------------------------------------------------ things you can put in the garden (🧺)
## A wooden post with a little roofed feeder and a seed tray.
static func bird_feeder(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Feeder", at, yaw)
	var wood := mat("feederwood", Color("8a6a48"))
	part(r, cyl(0.05, 0.06, 1.5, 8), wood, Vector3(0, 0.75, 0), Vector3.ZERO, 0.008)
	part(r, box(Vector3(0.5, 0.05, 0.5)), wood, Vector3(0, 1.52, 0), Vector3.ZERO, 0.008)
	part(r, box(Vector3(0.36, 0.3, 0.36)), mat("feederglass", Color("c8d4cc")), Vector3(0, 1.7, 0), Vector3.ZERO, 0.006)
	var roof := PrismMesh.new()
	roof.size = Vector3(0.62, 0.22, 0.56)
	part(r, roof, mat("feederroof", Color("6a3a2a")), Vector3(0, 1.97, 0), Vector3.ZERO, 0.01)
	part(r, blob(Vector3(0.2, 0.04, 0.2), "dome"), mat("seed", Color("c8a060")), Vector3(0, 1.56, 0), Vector3.ZERO, 0.0)
	return r


## A concrete bird bath: pedestal and a shallow bowl of water.
static func bird_bath(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Bath", at, yaw)
	var stone := mat("bathstone", Color("b4ae9e"))
	part(r, cyl(0.12, 0.2, 0.7, 12), stone, Vector3(0, 0.35, 0), Vector3.ZERO, 0.01)
	part(r, cyl(0.5, 0.3, 0.16, 18), stone, Vector3(0, 0.76, 0), Vector3.ZERO, 0.012)
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	water.set_shader_parameter("drip", Vector2(0.5, 0.5))
	var disc := PlaneMesh.new()
	disc.size = Vector2(1.05, 1.05)
	var w := MeshInstance3D.new()
	w.mesh = disc
	w.material_override = water
	w.position = Vector3(0, 0.845, 0)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(w)
	return r


## Split logs stacked in a little pyramid.
static func log_pile(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "LogPile", at, yaw)
	var bark := mat("logbark", Color("6a5038"))
	var rows := [[-0.36, 0.0, 0.36], [-0.18, 0.18], [0.0]]
	for y in range(rows.size()):
		for x: float in rows[y]:
			part(r, cyl(0.17, 0.17, 1.1, 10), bark, Vector3(x, 0.17 + y * 0.3, 0), Vector3(90, 0, 0), 0.012)
	return r


## A nest box on a post, with a round door.
static func nest_box(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "NestBox", at, yaw)
	var wood := mat("boxwood_plank", Color("9a7a52"))
	part(r, cyl(0.05, 0.06, 1.3, 8), mat("feederwood", Color("8a6a48")), Vector3(0, 0.65, 0), Vector3.ZERO, 0.008)
	part(r, box(Vector3(0.34, 0.42, 0.32)), wood, Vector3(0, 1.45, 0), Vector3.ZERO, 0.01)
	var roof := PrismMesh.new()
	roof.size = Vector3(0.48, 0.18, 0.44)
	part(r, roof, mat("feederroof", Color("6a3a2a")), Vector3(0, 1.75, 0), Vector3.ZERO, 0.01)
	part(r, cyl(0.06, 0.06, 0.02, 12), mat("hole", Color("2a2018")), Vector3(0.17, 1.5, 0), Vector3(0, 0, 90), 0.0)
	return r


## A ribbed pumpkin with a curly stem.
static func pumpkin(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Pumpkin", at, rng.randf_range(0, 360))
	var orange := mat("pumpkin%d" % rng.randi_range(0, 2), Color("d8782a").lerp(Color("e89a3a"), rng.randf()))
	for k in range(8):
		var a := TAU * k / 8.0
		part(r, blob(Vector3(size * 0.42, size * 0.5, size * 0.3), {"exponent": 2.0}), orange, Vector3(cos(a), 0.0, sin(a)) * size * 0.32 + Vector3(0, size * 0.48, 0), Vector3(0, -rad_to_deg(a), 0), 0.01 if k % 2 == 0 else 0.0)
	part(r, cyl(0.03, 0.05, size * 0.3, 6), mat("stem", Color("5a6a2a")), Vector3(0, size * 1.02, 0), Vector3(0, 0, 14), 0.008)
	return r


## A wooden crate of windfall apples, a few spilled.
static func apple_crate(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Apples", at, yaw)
	var slat := mat("crate", Color("b08a5a"))
	for side: float in [-1.0, 1.0]:
		part(r, box(Vector3(0.9, 0.36, 0.05)), slat, Vector3(0, 0.18, side * 0.3), Vector3.ZERO, 0.008)
		part(r, box(Vector3(0.05, 0.36, 0.6)), slat, Vector3(side * 0.43, 0.18, 0), Vector3.ZERO, 0.008)
	var red := mat("apple", Color("b8322a"))
	var green := mat("apple2", Color("8aa03a"))
	for k in range(9):
		part(r, blob(Vector3(0.12, 0.11, 0.12), {"exponent": 2.0}), red if k % 4 else green, Vector3(rng.randf_range(-0.3, 0.3), 0.32 + rng.randf_range(0, 0.05), rng.randf_range(-0.2, 0.2)), Vector3.ZERO, 0.006)
	for k in range(3):
		part(r, blob(Vector3(0.12, 0.11, 0.12), {"exponent": 2.0}), red, Vector3(0.7 + k * 0.2, 0.1, rng.randf_range(-0.4, 0.5)), Vector3.ZERO, 0.006)
	return r


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


## Merge every mesh under `r` (static scenery: walls, stones, fences) into one mesh per material, keeping each
## part's outline. Hundreds of draw calls become a handful; nothing looks different.
static func bake_static(r: Node3D) -> Node3D:
	var groups := {}                 # material -> [SurfaceTool, overlay]
	var parts: Array = []
	var stack: Array = [r]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and n != r:
			parts.append(n)
	var inv := r.global_transform.affine_inverse()
	for mi: MeshInstance3D in parts:
		var key: Material = mi.material_override
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = [st, mi.material_overlay]
		var xf: Transform3D = inv * mi.global_transform
		for surf in range(mi.mesh.get_surface_count()):
			(groups[key][0] as SurfaceTool).append_from(mi.mesh, surf, xf)
	for mi: MeshInstance3D in parts:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for key in groups:
		var st: SurfaceTool = groups[key][0]
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = key
		merged.material_overlay = groups[key][1]
		r.add_child(merged)
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
static func house(parent: Node3D, at: Vector3, yaw: float, siding: Color, size: Vector3, porch: bool, rng: RandomNumberGenerator) -> Node3D:
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
	part(r, box(Vector3(1.0, 2.0, 0.08)), mat("door", Color("3a4a3a")), Vector3(0, 1.0, face), Vector3.ZERO, 0.008)
	if porch:
		for k in range(3):
			part(r, box(Vector3(1.8, 0.18, 0.4)), mat("steps", Color("9a8a74")), Vector3(0, 0.09 + k * 0.18, face - 1.1 + k * 0.38), Vector3.ZERO, 0.008)
	return r


## A garden gate standing open on its hinge.
static func open_gate(parent: Node3D, hinge: Vector3, width: float, swing_deg: float) -> Node3D:
	var r := root(parent, "Gate", hinge, swing_deg)
	var paint := mat("fence", Color("e3ddcb"))
	part(r, box(Vector3(width, 0.08, 0.06)), paint, Vector3(width * 0.5, 0.3, 0), Vector3.ZERO, 0.006)
	part(r, box(Vector3(width, 0.08, 0.06)), paint, Vector3(width * 0.5, 0.85, 0), Vector3.ZERO, 0.006)
	for k in range(6):
		part(r, box(Vector3(0.09, 1.15, 0.05)), paint, Vector3(0.1 + k * (width - 0.2) / 5.0, 0.6, 0.02), Vector3.ZERO, 0.006)
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
