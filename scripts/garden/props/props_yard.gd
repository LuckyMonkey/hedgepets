extends "res://scripts/garden/props/props_kit.gd"

## Props 2/4 - the yard's own things: the chair, the grill, the fence and its gate, the sprinkler, sticks, rocks, the stone wall.
##
## What the garden starts with: junk to clear and broken things to mend. Each function builds a Node3D under the given
## parent at the given place. Rocks come from scripts/art/rock_factory.gd (plane-cut low-poly rocks).
##
## Part of the props layer chain (the full order is at the top of scripts/garden/garden_props.gd). Code here was moved verbatim
## from the old single file; only its place changed.

## A small shared dish for a found thing. One mesh recipe serves every offering kind; the coloured item is only
## a tiny accent, keeping the garden cheap on low-tier phones.
static func offering_dish(parent: Node3D, at: Vector3, yaw: float, kind: String) -> Node3D:
	var r := root(parent, "OfferingDish_" + kind, at, yaw)
	var clay := mat("offering_clay", Color("b46a44"))
	var dark := mat("offering_dark", Color("4b3528"))
	part(r, cyl(0.28, 0.34, 0.08, 12), clay, Vector3(0, 0.05, 0), Vector3.ZERO, 0.006)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.25
	rim.outer_radius = 0.34
	rim.rings = 16
	rim.ring_segments = 6
	part(r, rim, clay, Vector3(0, 0.1, 0), Vector3.ZERO, 0.004)
	var accent: Color = {"cone": Color("7a5232"), "acorn": Color("a87a3a"), "feather": Color("4a7ac0"), "apple": Color("b8402e")}.get(kind, Color("8a6a4a"))
	part(r, blob(Vector3(0.09, 0.07, 0.09), "pebble"), mat("offering_" + kind, accent), Vector3(0, 0.15, 0), Vector3.ZERO, 0.004)
	if kind == "feather":
		part(r, box(Vector3(0.025, 0.012, 0.2)), dark, Vector3(0, 0.18, 0), Vector3(0, 0, 18), 0.0)
	return r


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
const PICKET_Z := -0.17                              # rails at -0.1 (0.06 thick): pickets clear of them, nailed behind

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
				# behind the rails (not through them), every other one a little further back: a leaning picket crosses
				# its neighbour, and in one plane the two faces fought (the "clipping" the owner saw)
				var picket := part(r, box(Vector3(0.22, h, 0.05)), paint if rng.randf() < 0.7 else old, Vector3(px, h * 0.5, PICKET_Z - (k % 2) * 0.014), Vector3(0, 0, lean), 0.008)
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
			var picket := part(r, box(Vector3(0.22, 1.45, 0.05)), paint, Vector3(x + 0.25 + k * 0.36, 0.725, PICKET_Z), Vector3.ZERO, 0.008)
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
	part(r, RockFactory.make({"role": "boulder", "size": Vector3(size, size * 0.62, size * 0.8), "seed": shape}), RockFactory.material(grey), Vector3(0, -size * 0.12, 0), Vector3.ZERO, 0.01)
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
	var stone := part(r, blob(q, {"exponent": 2.7, "flat_bottom": 0.75}, 6, 10), mat("wall%d" % int(grey.r * 100 + grey.g * 10), grey),
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
	var role := "cap_stone" if cap else "wall_stone"
	var stone := part(r, RockFactory.make({"role": role, "size": q * 2.0, "seed": rng.randi()}), RockFactory.material(m.albedo_color), at - Vector3(0, q.y, 0),
		Vector3(rng.randf_range(-7, 7), yaw + rng.randf_range(-12, 12), rng.randf_range(-9, 9)), 0.008)
	stone.name = "Stone"


static var _sized := {}


## One of the unit stones stretched to `radii`: its vertex arrays scaled (normals by the inverse), made at runtime in
## a moment and shared by every stone of that size and shape. Nothing is stored in the bake.
static func fieldstone_sized(radii: Vector3, variant: int) -> ArrayMesh:
	var key := [radii, variant % 3]
	if _sized.has(key):
		return _sized[key]
	var m := RockFactory.make({"role": "boulder", "size": radii * 2.0, "seed": variant, "roughness": 0.2, "facets": 7, "flatten": 0.92})
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


## A garden gate standing open on its hinge.
static func open_gate(parent: Node3D, hinge: Vector3, width: float, swing_deg: float) -> Node3D:
	var r := root(parent, "Gate", hinge, swing_deg)
	var paint := mat("fence", Color("e3ddcb"))
	part(r, box(Vector3(width, 0.08, 0.06)), paint, Vector3(width * 0.5, 0.3, 0), Vector3.ZERO, 0.006)
	part(r, box(Vector3(width, 0.08, 0.06)), paint, Vector3(width * 0.5, 0.85, 0), Vector3.ZERO, 0.006)
	for k in range(6):
		part(r, box(Vector3(0.09, 1.15, 0.05)), paint, Vector3(0.1 + k * (width - 0.2) / 5.0, 0.6, 0.02), Vector3.ZERO, 0.006)
	return r
