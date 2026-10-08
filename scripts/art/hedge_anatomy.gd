class_name HedgeAnatomy
extends RefCounted

## Region geometry for a HedgePet. Every region is a primitive in its parent's space (the creature, or the HEAD), so
## features stay attached as the shape changes. Facial anchors live in head-local space; protection falls off
## smoothly around them (a soft clearing, never a hole).
##
## Primitives. A region without "shape" is an ellipsoid. With "shape" it is a blob - a superellipsoid:
##   |x/a|^n + |y/(b*s)|^n + |z/(c*s)|^n = 1,  s = 1 + taper * x/a   (s scales the cross-section along x)
##   "exponent" n  2 = ellipsoid, 2.5-4 = a soft cushion / rounded slab, < 2 = pinched
##   "taper"       > 0 grows toward +x (front), < 0 toward the back (a pear, a teardrop, a snout)
##   "flat_bottom" cut at y = -flat_bottom * b (1 = no cut); the cut face is flat, so it can sit on the ground
## Points on the surface are found along a direction by bisection; normals from the field's gradient.


## Named primitives for building HedgePets: a region may say "shape": "bean" (or a dictionary of its own numbers).
const PRESETS := {
	"ellipsoid": {},
	"bean": {"exponent": 2.15, "taper": -0.14, "flat_bottom": 0.88},     # Gerald's body: fuller behind, sits flat
	"pear": {"exponent": 2.0, "taper": -0.35, "flat_bottom": 0.9},       # a sitting creature's body
	"egg": {"exponent": 2.0, "taper": 0.2},                              # a head with a narrower crown
	"cushion": {"exponent": 2.8},                                        # soft and boxy: muzzles, snouts, pillows
	"paddle": {"exponent": 4.0},                                         # a rounded-rectangle slab (with flat radii)
	"dome": {"exponent": 2.6, "flat_bottom": 0.12},                      # feet, mushroom caps, little stools
	"teardrop": {"exponent": 2.0, "taper": 0.75},                        # ears, buds, tails that point
	"pebble": {"exponent": 2.3, "taper": -0.1, "flat_bottom": 0.5},      # stones, toes, seeds
}


static func _shape(region: Dictionary) -> Dictionary:
	var sh = region.get("shape", {})
	return PRESETS.get(sh, {}) if sh is String else sh


static func field(region: Dictionary, q: Vector3) -> float:
	var r: Vector3 = region["radii"]
	var sh := _shape(region)
	var n: float = sh.get("exponent", 2.0)
	var s := clampf(1.0 + float(sh.get("taper", 0.0)) * q.x / r.x, 0.25, 2.5)
	return pow(absf(q.x / r.x), n) + pow(absf(q.y / (r.y * s)), n) + pow(absf(q.z / (r.z * s)), n)


## The point on a region's surface along direction d from its centre (region space; c is the centre to use).
static func shape_point(region: Dictionary, c: Vector3, d: Vector3) -> Vector3:
	var dir := d.normalized()
	var sh := _shape(region)
	var r: Vector3 = region["radii"]
	var q: Vector3
	if sh.is_empty():
		q = dir / (dir / r).length()
	else:
		var lo := 0.0
		var hi := maxf(r.x, maxf(r.y, r.z)) * 3.0
		for i in range(26):
			var mid := (lo + hi) * 0.5
			if field(region, dir * mid) < 1.0:
				lo = mid
			else:
				hi = mid
		q = dir * lo
	var flat: float = sh.get("flat_bottom", 1.0)
	if flat < 1.0 and q.y < -flat * r.y and dir.y < -0.0001:
		q = dir * ((-flat * r.y) / dir.y)                     # on the flat base
	return c + q


static func shape_normal(region: Dictionary, c: Vector3, p: Vector3) -> Vector3:
	var q := p - c
	var sh := _shape(region)
	var r: Vector3 = region["radii"]
	if sh.is_empty():
		return (q / (r * r)).normalized()
	var flat: float = sh.get("flat_bottom", 1.0)
	if flat < 1.0 and q.y <= -flat * r.y + 0.0005:
		return Vector3.DOWN
	var e := 0.002 * maxf(r.x, maxf(r.y, r.z))
	var g := Vector3(
		field(region, q + Vector3(e, 0, 0)) - field(region, q - Vector3(e, 0, 0)),
		field(region, q + Vector3(0, e, 0)) - field(region, q - Vector3(0, e, 0)),
		field(region, q + Vector3(0, 0, e)) - field(region, q - Vector3(0, 0, e)))
	return g.normalized() if g.length() > 0.000001 else q.normalized()


## A mesh of the region's primitive, centred on its own origin (place it at the region centre).
static func build_mesh(region: Dictionary, rings := 24, segments := 48) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in range(rings + 1):
		var v := float(i) / float(rings)
		var phi := v * PI
		for j in range(segments + 1):
			var u := float(j) / float(segments)
			var theta := u * TAU
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var p := shape_point(region, Vector3.ZERO, d)
			verts.append(p)
			normals.append(shape_normal(region, Vector3.ZERO, p))
			uvs.append(Vector2(u, v))
	for i in range(rings):
		for j in range(segments):
			var a := i * (segments + 1) + j
			var b := a + segments + 1
			indices.append_array([a, b, a + 1, b, b + 1, a + 1])   # clockwise = front faces outward (Godot)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Kept for callers that only have a centre and radii (plain ellipsoids).
static func surface_point(c: Vector3, r: Vector3, d: Vector3) -> Vector3:
	return shape_point({"radii": r}, c, d)


static func surface_normal(c: Vector3, r: Vector3, p: Vector3) -> Vector3:
	return shape_normal({"radii": r}, c, p)


static func region(profile: CharacterArtProfile, name: String) -> Dictionary:
	return profile.regions.get(name, {})


## An anchor's position in head-local space (on the head or the muzzle surface).
static func anchor_point(profile: CharacterArtProfile, name: String) -> Vector3:
	var a: Dictionary = profile.anchors[name]
	if a.get("on", "HEAD") == "MUZZLE":
		var m: Dictionary = region(profile, "MUZZLE")
		return shape_point(m, m["center"], a["dir"])
	return shape_point(region(profile, "HEAD"), Vector3.ZERO, a["dir"])


## The outward normal at an anchor, in head-local space.
static func anchor_normal(profile: CharacterArtProfile, name: String) -> Vector3:
	var a: Dictionary = profile.anchors[name]
	if a.get("on", "HEAD") == "MUZZLE":
		var m: Dictionary = region(profile, "MUZZLE")
		return shape_normal(m, m["center"], anchor_point(profile, name))
	return shape_normal(region(profile, "HEAD"), Vector3.ZERO, anchor_point(profile, name))


## How strongly a head-local point is protected (0 = grow freely, 1 = keep clear): the strongest zone wins, each a
## smooth gaussian of the angle (seen from the head centre) to its anchor. The muzzle is always clear.
static func protection(profile: CharacterArtProfile, head_local: Vector3) -> float:
	var m: Dictionary = region(profile, "MUZZLE")
	if not m.is_empty() and ((head_local - m["center"]) / (m["radii"] * 1.12)).length() < 1.0:
		return 1.0
	var best := 0.0
	var dir := head_local.normalized()
	for name in profile.protected_zones:
		var zone: Dictionary = profile.protected_zones[name]
		var angle := dir.angle_to(anchor_point(profile, name).normalized())
		var radius: float = float(zone["radius"]) * profile.face_clearing
		if radius <= 0.0:
			continue
		best = maxf(best, float(zone["strength"]) * exp(-pow(angle / radius, 2.0)))
	return clampf(best, 0.0, 1.0)
