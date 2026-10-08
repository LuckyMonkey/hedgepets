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
