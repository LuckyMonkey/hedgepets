class_name HedgeAnatomy
extends RefCounted

## Region geometry for a HedgePet: every region is an ellipsoid in its parent's space (the creature, or the HEAD),
## so features stay attached as the shape changes. Facial anchors live in head-local space; protection falls off
## smoothly around them (a soft clearing, never a hole).


## The point on an ellipsoid (centre c, radii r) along direction d from its centre.
static func surface_point(c: Vector3, r: Vector3, d: Vector3) -> Vector3:
	var n := d.normalized()
	var k := 1.0 / (n / r).length()
	return c + n * k


## The outward normal of the ellipsoid at a point on (or near) it.
static func surface_normal(c: Vector3, r: Vector3, p: Vector3) -> Vector3:
	return ((p - c) / (r * r)).normalized()


static func region(profile: CharacterArtProfile, name: String) -> Dictionary:
	return profile.regions.get(name, {})


## An anchor's position in head-local space (on the head or the muzzle surface).
static func anchor_point(profile: CharacterArtProfile, name: String) -> Vector3:
	var a: Dictionary = profile.anchors[name]
	var head: Dictionary = region(profile, "HEAD")
	if a.get("on", "HEAD") == "MUZZLE":
		var m: Dictionary = region(profile, "MUZZLE")
		return surface_point(m["center"], m["radii"], a["dir"])
	return surface_point(Vector3.ZERO, head["radii"], a["dir"])


## The outward normal at an anchor, in head-local space.
static func anchor_normal(profile: CharacterArtProfile, name: String) -> Vector3:
	var a: Dictionary = profile.anchors[name]
	if a.get("on", "HEAD") == "MUZZLE":
		var m: Dictionary = region(profile, "MUZZLE")
		return surface_normal(m["center"], m["radii"], anchor_point(profile, name))
	return surface_normal(Vector3.ZERO, region(profile, "HEAD")["radii"], anchor_point(profile, name))


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
