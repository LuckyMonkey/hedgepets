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
	near_fade(m)
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
	near_fade(m)
	_mats["rust"] = m
	return m


## Everything in the garden dissolves right in front of the camera (near_fade.gdshaderinc; StandardMaterial's own
## pixel-dither distance fade), so the camera never sits inside a trunk or a crown.
const NEAR_FADE := Vector2(1.0, 3.2)


static func near_fade(m: BaseMaterial3D) -> BaseMaterial3D:
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = NEAR_FADE.x
	m.distance_fade_max_distance = NEAR_FADE.y
	return m


static func hull(width: float) -> ShaderMaterial:
	var key := "hull%.3f" % width
	if _mats.has(key):
		return _mats[key]
	var h := ShaderMaterial.new()
	h.shader = load("res://shaders/ink_hull.gdshader")
	h.set_shader_parameter("ink", INK)
	h.set_shader_parameter("width", width)
	h.set_shader_parameter("near_fade", NEAR_FADE)
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


static func blob(radii: Vector3, shape: Variant = {}, rings := 14, segments := 24) -> ArrayMesh:
	var k := BakeCache.key(["blob", radii, shape, rings, segments])
	var cached = BakeCache.fetch(k)
	if cached != null:
		return cached
	BakeCache.begin_composite()                          # (the blob's entry is what's kept, not the mesh build inside it)
	var m := HedgeAnatomy.build_mesh({"radii": radii, "shape": shape}, rings, segments)
	BakeCache.end_composite()
	BakeCache.store(k, m)
	return m


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
static func broken_fence(parent: Node3D, from_x: float, to_x: float, z: float, rng: RandomNumberGenerator, gap := Vector2(INF, INF), mended := false) -> Node3D:
	var r := root(parent, "Fence", Vector3(0, 0, z), 0.0)
	if mended:
		return _mended_fence(r, from_x, to_x, gap)
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


## The same run of fence after you've fixed it: every picket upright and painted; the gap is a little gate standing
## open (visitors still come through it).
static func _mended_fence(r: Node3D, from_x: float, to_x: float, gap: Vector2) -> Node3D:
	var paint := mat("fence", Color("e3ddcb"))
	var post_m := mat("fencepost", Color("d8d2c0"))
	var x := from_x
	while x < to_x:
		if x > gap.x and x < gap.y:
			x += 2.2
			continue
		part(r, box(Vector3(0.16, 1.7, 0.16)), post_m, Vector3(x, 0.85, 0), Vector3.ZERO, 0.01)
		part(r, box(Vector3(2.2, 0.1, 0.06)), paint, Vector3(x + 1.1, 1.25, -0.1), Vector3.ZERO, 0.008)
		part(r, box(Vector3(2.2, 0.1, 0.06)), paint, Vector3(x + 1.1, 0.45, -0.1), Vector3.ZERO, 0.008)
		for k in range(6):
			var picket := part(r, box(Vector3(0.22, 1.45, 0.05)), paint, Vector3(x + 0.25 + k * 0.36, 0.725, -0.06), Vector3.ZERO, 0.008)
			part(picket, box(Vector3(0.16, 0.16, 0.05)), paint, Vector3(0, 0.725, 0), Vector3(0, 0, 45), 0.006)
		x += 2.2
	var mid := (gap.x + gap.y) * 0.5
	if gap.x != INF and mid >= from_x and mid < to_x:              # the gap: a pair of gates standing open
		part(r, box(Vector3(0.16, 1.7, 0.16)), post_m, Vector3(from_x, 0.85, 0), Vector3.ZERO, 0.01)
		part(r, box(Vector3(0.16, 1.7, 0.16)), post_m, Vector3(to_x, 0.85, 0), Vector3.ZERO, 0.01)
		open_gate(r, Vector3(from_x + 0.1, 0, 0), 1.9, -75.0)
		open_gate(r, Vector3(to_x - 0.1, 0, 0), 1.9, 255.0)
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
	var shape := int((rng.randf_range(-0.2, 0.2) + 0.2) * 29.9)    # (the draw that once set its taper)
	part(r, fieldstone_sized((Vector3(size, size * 0.62, size * 0.8) / 0.03).round() * 0.03, shape % 3), mat("rock%d" % int(grey.r * 100), grey), Vector3(0, size * 0.3, 0), Vector3.ZERO, 0.01)
	return r


## A New England fieldstone wall: no mortar and no courses. Stones of every size, cleared from the fields, stacked
## the way a farmer stacked them: big ones at the bottom, each stone settled into the lowest gap along the wall,
## small ones chinked into the narrow gaps, two faces leaning in toward a tumbled top of wide flat stones, a few
## fallen at its foot. Each face is packed against a height profile, so every stone sits on the ones below it.
## Its own random numbers (seeded by where it stands); the garden's `rng` is advanced exactly as the old coursed
## wall did, so nothing else in the garden moves.
static func stone_wall(parent: Node3D, from: Vector3, to: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "StoneWall", Vector3.ZERO, 0.0)
	var length := from.distance_to(to)
	_old_wall_draws(length, rng)
	var wr := RandomNumberGenerator.new()
	wr.seed = hash([snappedf(from.x, 0.01), snappedf(from.z, 0.01), snappedf(to.x, 0.01), snappedf(to.z, 0.01)])
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP)
	var yaw := rad_to_deg(atan2(-dir.z, dir.x))
	var tall := wr.randf_range(0.78, 0.9)
	const BIN := 0.04
	var n := int(length / BIN)
	var tops := []
	for face: float in [-1.0, 1.0]:
		var prof := PackedFloat32Array()
		prof.resize(n)
		var aim := PackedFloat32Array()
		aim.resize(n)
		var ph := wr.randf() * TAU
		for i in range(n):
			var x := i * BIN
			var ends := 0.62 + 0.38 * smoothstep(0.0, 0.9, minf(x, length - x))   # the ends slump
			aim[i] = tall * ends * (0.9 + 0.1 * sin(x * 1.3 + ph) + 0.04 * sin(x * 4.1 + ph * 2.0))
		for guard in range(4000):
			var i := -1
			for k in range(n):
				if prof[k] < aim[k] - 0.05 and (i < 0 or prof[k] < prof[i]):
					i = k
			if i < 0:
				break
			var floor_y := prof[i]
			var lo := i
			var hi := i
			while lo > 0 and prof[lo - 1] <= floor_y + 0.03:
				lo -= 1
			while hi < n - 1 and prof[hi + 1] <= floor_y + 0.03:
				hi += 1
			var gap := (hi - lo + 1) * BIN
			var up := floor_y / tall
			var w := maxf(minf(wr.randf_range(0.7, 1.3) * lerpf(1.0, 0.7, up), gap + 0.12), 0.3)
			var start := lo * BIN + (wr.randf() * (gap - w) if gap > w else (gap - w) * 0.5)
			var h := minf(w * wr.randf_range(0.45, 0.7), lerpf(0.6, 0.38, up))      # boulders at the foot, smaller up top
			var s0 := clampi(int(start / BIN), 0, n - 1)
			var s1 := clampi(int((start + w) / BIN), 0, n - 1)
			var base := 0.0
			for k in range(s0, s1 + 1):
				base = maxf(base, prof[k])
			base -= h * 0.12                                    # it settles into the stones below
			var mid := (s0 + s1) * 0.5
			var halfspan := maxf((s1 - s0) * 0.5, 0.5)
			for k in range(s0, s1 + 1):
				var u := (k - mid) / halfspan
				prof[k] = maxf(prof[k], base + h * (0.92 - 0.25 * u * u))
			var y := base + h * 0.5
			var d := wr.randf_range(0.3, 0.42)
			var half_t := lerpf(0.44, 0.27, clampf(y / tall, 0.0, 1.0))    # the faces lean in as they rise
			var at := from + dir * (start + w * 0.5) + side * face * (half_t - d * 0.5 + wr.randf_range(-0.01, 0.02)) + Vector3(0, y, 0)
			_field_stone(r, at, Vector3(w * 0.56, h * 0.58, d * 0.5), yaw, wr, false)
		tops.append(prof)
	# the hearting between the faces: dark rubble, so the gaps between stones look deep, never see-through
	var core := part(r, box(Vector3(maxf(length - 1.4, 0.2), tall * 0.62, 0.34)), mat("wallcore", Color("4a4844")), from.lerp(to, 0.5) + Vector3(0, tall * 0.31, 0), Vector3(0, yaw, 0), 0.0)
	core.name = "Hearting"
	# the top: wide flat stones across both faces, a few missing where it has tumbled
	var x := wr.randf_range(0.0, 0.15)
	while x < length - 0.25:
		var w := wr.randf_range(0.7, 1.1)
		if wr.randf() < 0.78:
			var s0 := clampi(int(x / BIN), 0, n - 1)
			var s1 := clampi(int((x + w) / BIN), 0, n - 1)
			var base := 0.0
			for k in range(s0, s1 + 1):
				base = maxf(base, maxf(tops[0][k], tops[1][k]))
			var h := wr.randf_range(0.16, 0.26)
			var at := from + dir * (x + w * 0.5) + side * wr.randf_range(-0.05, 0.05) + Vector3(0, base + h * 0.3, 0)
			_field_stone(r, at, Vector3(w * 0.55, h * 0.5, wr.randf_range(0.2, 0.27)), yaw, wr, true)
		x += w * 0.94
	# fallen at its foot, on either side
	for k in range(int(length * 0.25)):
		var along := wr.randf_range(0.2, length - 0.2)
		var sz := wr.randf_range(0.1, 0.2)
		var at := from + dir * along + side * (1.0 if wr.randf() < 0.5 else -1.0) * wr.randf_range(0.5, 0.85) + Vector3(0, sz * 0.4, 0)
		_field_stone(r, at, Vector3(sz * 1.2, sz * 0.7, sz), wr.randf_range(0, 360), wr, false)
	return r


## Consume exactly the random numbers the old coursed wall drew (5 courses x 2 faces, then the caps), so the rest of
## the garden - built after the walls from the same generator - stays exactly where it was.
static func _old_wall_draws(length: float, rng: RandomNumberGenerator) -> void:
	for course in range(5):
		var ch := rng.randf_range(0.13, 0.17)
		for face in range(2):
			var x := (0.0 if course % 2 == 0 else 0.25) + rng.randf_range(-0.05, 0.05)
			while x < length - 0.1:
				var half := rng.randf_range(0.18, 0.32)
				rng.randf_range(0.85, 1.0)
				rng.randf_range(-0.02, 0.02)
				rng.randf_range(0.11, 0.15)
				rng.randf_range(-5, 5)
				rng.randf()
				rng.randf()
				rng.randf_range(-3, 3)
				rng.randf_range(-3, 3)
				x += half * 2.0 * 0.97
	var x := rng.randf_range(0.0, 0.2)
	while x < length - 0.15:
		var half := rng.randf_range(0.22, 0.38)
		rng.randf_range(0.2, 0.25)
		rng.randf_range(-6, 6)
		rng.randf()
		rng.randf()
		rng.randf()
		rng.randf_range(-3, 3)
		rng.randf_range(-3, 3)
		x += half * 2.0 * 0.96


static func _wall_stone(r: Node3D, at: Vector3, radii: Vector3, yaw: float, rng: RandomNumberGenerator, moss: Color, cap: bool) -> void:
	var q := (radii / 0.02).round() * 0.02                        # sizes snap to a grid: shared, cached meshes
	var grey := Color("8a877e").lerp(Color("a8a396"), rng.randf())
	if rng.randf() < 0.18:
		grey = grey.lerp(Color("b8b29e"), 0.5)                   # lichen
	if cap and rng.randf() < 0.4:
		grey = grey.lerp(moss, 0.55)                             # moss on the cap
	var stone := part(r, blob(q, {"exponent": 2.7, "flat_bottom": 0.75}, 8, 12), mat("wall%d" % int(grey.r * 100 + grey.g * 10), grey),
		at, Vector3(rng.randf_range(-3, 3), yaw, rng.randf_range(-3, 3)), 0.008)
	stone.name = "Stone"


## New England field stone: granite and gneiss greys, some warm, some with pale lichen; moss on the top stones.
const FIELD_GREYS := ["7e7c76", "8f8c84", "a09d94", "6f6d68", "978d7f", "aaa69b", "868a7f"]


static func _field_stone(r: Node3D, at: Vector3, radii: Vector3, yaw: float, rng: RandomNumberGenerator, cap: bool) -> void:
	var q := (radii / 0.03).round() * 0.03                     # sizes snap to a grid: shared, cached meshes
	q = q.max(Vector3(0.03, 0.03, 0.03))
	var g := rng.randi() % FIELD_GREYS.size()
	var m := mat("fieldstone%d" % g, Color(FIELD_GREYS[g]))
	if cap and rng.randf() < 0.45:
		m = mat("fieldstone_moss%d" % (g % 3), Color(FIELD_GREYS[g]).lerp(Color("6e7a4a"), 0.3))
	var stone := part(r, fieldstone_sized(q, rng.randi() % 3), m, at,
		Vector3(rng.randf_range(-7, 7), yaw + rng.randf_range(-12, 12), rng.randf_range(-9, 9)), 0.008)
	stone.name = "Stone"


static var _sized := {}


## One of the unit stones stretched to `radii`: its vertex arrays scaled (normals by the inverse), made at runtime in
## a moment and shared by every stone of that size and shape. Nothing is stored in the bake.
static func fieldstone_sized(radii: Vector3, variant: int) -> ArrayMesh:
	var key := [radii, variant % 3]
	if _sized.has(key):
		return _sized[key]
	var arrays := fieldstone(variant).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inv := Vector3.ONE / radii.max(Vector3(0.001, 0.001, 0.001))
	for i in verts.size():
		verts[i] *= radii
		norms[i] = (norms[i] * inv).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sized[key] = m
	return m


## A unit stone (radius 1; fieldstone_sized stretches it): the world's own chonky shape - a soft cushion, flat-ish
## underneath, low-poly - so stones match everything else. Three shapes (rounder to boxier); the variety is in their
## colours and sizes. Built once per run, never stored in the bake.
static var _fieldstones := {}


static func fieldstone(variant: int) -> ArrayMesh:
	var v := variant % 3
	if _fieldstones.has(v):
		return _fieldstones[v]
	var mesh := HedgeAnatomy.build_mesh({"radii": Vector3.ONE, "shape": {"exponent": [2.4, 2.8, 3.2][v], "flat_bottom": 0.6, "taper": [0.05, -0.08, 0.0][v]}}, 4, 6)
	_fieldstones[v] = mesh
	return mesh


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



## A hay bale: a straw block with two twine bands and a few loose wisps.
static func hay_bale(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "HayBale", at, yaw)
	var straw := mat("straw", Color("d6b862"))
	part(r, blob(Vector3(0.52, 0.26, 0.32), {"exponent": 5.0}), straw, Vector3(0, 0.26, 0), Vector3.ZERO, 0.012)
	var twine := mat("twine", Color("8a6a3a"))
	for x: float in [-0.22, 0.22]:
		part(r, blob(Vector3(0.025, 0.275, 0.335), {"exponent": 5.0}), twine, Vector3(x, 0.26, 0), Vector3.ZERO, 0.0)
	var wisp := mat("strawwisp", Color("e2c876"))
	for k in range(7):
		part(r, cyl(0.006, 0.01, rng.randf_range(0.15, 0.3), 4), wisp, Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.05, 0.5), rng.randf_range(-0.3, 0.3)) * Vector3(1, 1, 1), Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-70, 70)), 0.0)
	return r


## A friendly scarecrow: a post and crossbar, a patched red shirt, a burlap head with button eyes and a stitched
## smile, a floppy straw hat, straw poking out of the cuffs. Keeps nobody away.
static func scarecrow(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Scarecrow", at, yaw)
	var wood := mat("feederwood", Color("8a6a48"))
	part(r, cyl(0.045, 0.055, 1.9, 8), wood, Vector3(0, 0.95, 0), Vector3.ZERO, 0.008)
	part(r, box(Vector3(1.2, 0.06, 0.06)), wood, Vector3(0, 1.42, 0), Vector3.ZERO, 0.008)
	var shirt := mat("scareshirt", Color("b4483a"))
	part(r, blob(Vector3(0.27, 0.32, 0.15), {"exponent": 3.0}), shirt, Vector3(0, 1.22, 0), Vector3.ZERO, 0.012)
	part(r, blob(Vector3(0.5, 0.09, 0.1), {"exponent": 3.0}), shirt, Vector3(0, 1.4, 0), Vector3.ZERO, 0.01)
	part(r, box(Vector3(0.14, 0.14, 0.02)), mat("patch", Color("d8b46a")), Vector3(0.1, 1.16, 0.15), Vector3(0, 0, 12), 0.0)
	var straw := mat("strawwisp", Color("e2c876"))
	for side: float in [-1.0, 1.0]:
		part(r, cyl(0.02, 0.07, 0.14, 6), straw, Vector3(side * 0.58, 1.4, 0), Vector3(0, 0, side * 90), 0.0)
	var head := part(r, blob(Vector3(0.19, 0.21, 0.18), {"exponent": 2.0}), mat("burlap", Color("cdb48a")), Vector3(0, 1.74, 0), Vector3.ZERO, 0.01)
	var dark := mat("button", Color("2a2420"))
	for side: float in [-1.0, 1.0]:
		part(head, cyl(0.03, 0.03, 0.02, 10), dark, Vector3(side * 0.07, 0.03, 0.17), Vector3(90, 0, 0), 0.0)
	for k in range(5):
		var x := (k - 2) * 0.035
		part(head, box(Vector3(0.022, 0.006, 0.01)), dark, Vector3(x, -0.07 + absf(x) * 0.6, 0.175), Vector3(0, 0, x * 260), 0.0)
	var hat := mat("hat", Color("b89a52"))
	part(r, cyl(0.34, 0.34, 0.025, 18), hat, Vector3(0, 1.9, 0), Vector3(6, 0, -4), 0.01)
	part(r, cyl(0.14, 0.17, 0.17, 14), hat, Vector3(0, 1.99, 0), Vector3(6, 0, -4), 0.01)
	return r


## A lantern on a shepherd's hook, glowing warm (it shows best at dusk).
static func lantern(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Lantern", at, yaw)
	var iron := mat("iron", Color("2e2c2a"), 0.6)
	part(r, cyl(0.02, 0.025, 1.5, 6), iron, Vector3(0, 0.75, 0), Vector3.ZERO, 0.006)
	part(r, box(Vector3(0.3, 0.025, 0.025)), iron, Vector3(0.14, 1.5, 0), Vector3.ZERO, 0.006)
	part(r, cyl(0.006, 0.006, 0.1, 4), iron, Vector3(0.28, 1.45, 0), Vector3.ZERO, 0.0)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd88a")
	glow.emission_enabled = true
	glow.emission = Color("ffc060")
	glow.emission_energy_multiplier = 1.4
	part(r, box(Vector3(0.14, 0.18, 0.14)), glow, Vector3(0.28, 1.31, 0), Vector3.ZERO, 0.0)
	part(r, cyl(0.02, 0.11, 0.07, 4), iron, Vector3(0.28, 1.43, 0), Vector3(0, 45, 0), 0.006)
	part(r, box(Vector3(0.16, 0.02, 0.16)), iron, Vector3(0.28, 1.21, 0), Vector3.ZERO, 0.006)
	return r


## Three flat stepping stones in a little curve, sunk into the lawn.
static func stepping_stones(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Stones", at, yaw)
	for k in range(3):
		var g := Color("8a8a82").lerp(Color("a49a88"), rng.randf())
		part(r, blob(Vector3(0.3, 0.035, 0.24) * rng.randf_range(0.85, 1.1), "pebble"), mat("stepstone%d" % k, g), Vector3((k - 1) * 0.62, 0.01, (k - 1) * (k - 1) * 0.18), Vector3(0, rng.randf_range(0, 180), 0), 0.006)
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


## Merge many static things into a few meshes: every MeshInstance3D under `roots` (with its material and ink overlay),
## grouped by `cell`-metre patch and material, becomes one mesh per group under `parent`/MergedProps. Same look, a
## fraction of the draw calls. Only for things that never move again. Returns the number of meshes made.
static func merge_static(parent: Node3D, roots: Array, cell := 24.0) -> int:
	var inv := parent.global_transform.affine_inverse()
	var groups := {}
	var parts: Array = []
	for r: Node in roots:
		if r is MeshInstance3D:
			parts.append(r)
		parts.append_array(r.find_children("*", "MeshInstance3D", true, false))
	for mi: MeshInstance3D in parts:
		await Slicer.tick(parent)
		if mi.mesh == null:
			continue
		var xf: Transform3D = inv * mi.global_transform
		var c := Vector2i(floori(xf.origin.x / cell), floori(xf.origin.z / cell))
		var key := "%d_%d_%d_%d_%d" % [c.x, c.y, mi.material_override.get_instance_id() if mi.material_override else 0,
			mi.material_overlay.get_instance_id() if mi.material_overlay else 0, mi.cast_shadow]
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = [st, mi.material_override, mi.material_overlay, mi.cast_shadow]
		for surf in range(mi.mesh.get_surface_count()):
			(groups[key][0] as SurfaceTool).append_from(mi.mesh, surf, xf)
	for r: Node in roots:
		r.get_parent().remove_child(r)
		r.queue_free()
	var holder := Node3D.new()
	holder.name = "MergedProps"
	parent.add_child(holder)
	for key in groups:
		await Slicer.tick(parent)
		var g: Array = groups[key]
		var merged := MeshInstance3D.new()
		merged.mesh = (g[0] as SurfaceTool).commit()
		merged.material_override = g[1]
		merged.material_overlay = g[2]
		merged.cast_shadow = g[3]
		holder.add_child(merged)
	return groups.size()


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


## An ironing board somebody carried out and never carried back: faded cover, rusty X legs, the iron still on its
## rest. Nine primitives, three materials; garden.gd bakes it into one mesh per material.
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
	part(board, box(Vector3(0.04, 0.1, 0.3)), legs, Vector3(-0.62, 0.86, 0), Vector3.ZERO, 0.006)   # the iron rest
	var iron := mat("wire", Color("4a4e50"))
	part(board, box(Vector3(0.24, 0.05, 0.12)), iron, Vector3(-0.58, 0.94, 0), Vector3(0, 0, 70), 0.008)
	part(board, box(Vector3(0.05, 0.12, 0.04)), iron, Vector3(-0.53, 0.98, 0), Vector3(0, 0, 70), 0.008)
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


# ------------------------------------------------------------------ hideouts (pets climb in: hideouts.gd)
## A steel paint bucket: a slightly tapered pail, a rolled rim, a wire bail handle, an old drip of paint down one side.
static func paint_bucket(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Bucket", at, yaw)
	var steel := mat("pail", Color("a9aeb0"), 0.45)
	var pail := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.26
	c.height = 0.52
	c.cap_top = false                                   # open: you can see in (and climb in)
	c.radial_segments = 20
	pail.mesh = c
	pail.material_override = steel
	pail.position = Vector3(0, 0.26, 0)
	r.add_child(pail)
	var inside := steel.duplicate() as StandardMaterial3D
	inside.cull_mode = BaseMaterial3D.CULL_FRONT
	inside.albedo_color = Color("6e7274")
	var inner := MeshInstance3D.new()
	inner.mesh = c
	inner.material_override = inside
	inner.position = pail.position
	r.add_child(inner)
	part(r, cyl(0.26, 0.26, 0.02, 20), mat("pailfloor", Color("5a5e60")), Vector3(0, 0.02, 0), Vector3.ZERO, 0.0)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.29
	rim.outer_radius = 0.32
	rim.ring_segments = 20
	part(r, rim, steel, Vector3(0, 0.52, 0), Vector3.ZERO, 0.0)
	var bail := TorusMesh.new()
	bail.inner_radius = 0.3
	bail.outer_radius = 0.315
	part(r, bail, mat("wire", Color("4a4e50")), Vector3(0, 0.52, 0), Vector3(90, 0, 0), 0.0).scale = Vector3(1, 1, 1.2)
	part(r, box(Vector3(0.06, 0.22, 0.01)), mat("paintdrip", Color("3a6a8a")), Vector3(0.2, 0.42, 0.2), Vector3(0, 45, 0), 0.0)
	return r


## A big terracotta pot, standing upright, empty except for a little old soil.
static func pot_upright(parent: Node3D, at: Vector3) -> Node3D:
	var r := root(parent, "Planter", at, 0.0)
	var clay := mat("terracotta2", Color("b0623e"))
	var c := CylinderMesh.new()
	c.top_radius = 0.42
	c.bottom_radius = 0.3
	c.height = 0.6
	c.cap_top = false
	c.radial_segments = 20
	var pot := MeshInstance3D.new()
	pot.mesh = c
	pot.material_override = clay
	pot.position = Vector3(0, 0.3, 0)
	r.add_child(pot)
	var inside := clay.duplicate() as StandardMaterial3D
	inside.cull_mode = BaseMaterial3D.CULL_FRONT
	inside.albedo_color = Color("7a3e26")
	var inner := MeshInstance3D.new()
	inner.mesh = c
	inner.material_override = inside
	inner.position = pot.position
	r.add_child(inner)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.4
	lip.outer_radius = 0.48
	lip.ring_segments = 20
	part(r, lip, clay, Vector3(0, 0.6, 0), Vector3.ZERO, 0.01)
	part(r, cyl(0.31, 0.31, 0.04, 16), mat("soil", Color("4a3626")), Vector3(0, 0.1, 0), Vector3.ZERO, 0.0)
	return r


## An old stone well: a ring of flat field stones, a little wooden roof on two posts, a pail on a rope.
static func stone_well(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Well", at, rng.randf_range(0, 360))
	var moss := Color("6e7a4a")
	for course in range(5):
		var n := 14
		for k in range(n):
			var a := TAU * (k + (0.5 if course % 2 else 0.0)) / n
			var p := Vector3(cos(a) * 0.82, 0.08 + course * 0.15, sin(a) * 0.82)
			_wall_stone(r, p, Vector3(0.2, 0.075, 0.12), -rad_to_deg(a) + 90.0, rng, moss, course == 4)
	part(r, cyl(0.7, 0.7, 0.02, 20), mat("wellwater", Color("1e2a2c"), 0.1), Vector3(0, 0.25, 0), Vector3.ZERO, 0.0)
	var wood := mat("wellwood", Color("6a5038"))
	for side: float in [-1.0, 1.0]:
		part(r, box(Vector3(0.12, 1.9, 0.12)), wood, Vector3(side * 0.95, 0.95, 0), Vector3.ZERO, 0.008)
	var roof := PrismMesh.new()
	roof.size = Vector3(2.5, 0.6, 1.5)
	part(r, roof, mat("wellroof", Color("5a4636")), Vector3(0, 2.15, 0), Vector3.ZERO, 0.012)
	part(r, cyl(0.06, 0.06, 1.9, 8), wood, Vector3(0, 1.55, 0), Vector3(0, 0, 90), 0.006)   # the winch
	part(r, cyl(0.01, 0.01, 0.6, 4), mat("rope", Color("c8b088")), Vector3(0, 1.22, 0), Vector3.ZERO, 0.0)
	return r


## A burrow under the roots: a soft mound of earth, a round dark doorway with a few pebbles and a twig arch around
## it, a tiny mushroom by the door. Cute, not a hole.
static func burrow(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Burrow", at, yaw)
	var earth := mat("burrowearth", Color("6e5236"))
	part(r, blob(Vector3(0.95, 0.38, 0.8), {"exponent": 2.2, "flat_bottom": 0.2}), earth, Vector3(-0.15, 0.05, 0), Vector3.ZERO, 0.012)
	part(r, cyl(0.34, 0.34, 0.06, 18), mat("burrowdark", Color("1e140c")), Vector3(0.55, 0.2, 0), Vector3(0, 0, 70), 0.0)
	for k in range(7):
		var a := lerpf(-1.3, 1.3, k / 6.0)
		part(r, blob(Vector3(0.08, 0.06, 0.07), "pebble"), mat("pebble%d" % (k % 3), Color("8a857a").lerp(Color("b0a898"), (k % 3) / 2.0)),
			Vector3(0.6, 0.22 + sin(a + 1.57) * 0.3, cos(a + 1.57) * 0.38), Vector3.ZERO, 0.006)
	part(r, cyl(0.02, 0.025, 0.9, 5), mat("twig", Color("5e4a36")), Vector3(0.64, 0.5, 0), Vector3(90, 0, 0), 0.006)
	part(r, cyl(0.025, 0.035, 0.12, 6), mat("stalk", Color("efe6d0")), Vector3(0.75, 0.06, 0.48), Vector3.ZERO, 0.0)
	part(r, blob(Vector3(0.09, 0.05, 0.09), "dome"), mat("cap", Color("c8603a")), Vector3(0.75, 0.13, 0.48), Vector3.ZERO, 0.006)
	return r
