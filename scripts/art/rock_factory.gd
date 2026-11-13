class_name RockFactory
extends RefCounted

## Cheap, deterministic low-poly stone geometry. A rock starts as a box and is cut by planes: this
## produces the broad fractured faces of fieldstone instead of a stretched animal primitive.
## Specs are dictionaries so the bake tool, the lab, and callers can share the same small API.

const ROLES := ["wall_stone", "cap_stone", "stepping_stone", "boulder", "cobble", "scree", "ledge", "outcrop"]
static var _cache := {}

static func make(spec: Dictionary) -> ArrayMesh:
	var role := str(spec.get("role", "boulder"))
	var size: Vector3 = spec.get("size", Vector3.ONE)
	var seed := int(spec.get("seed", 1))
	var roughness := clampf(float(spec.get("roughness", 0.18)), 0.0, 0.5)
	var facets := clampi(int(spec.get("facets", 7)), 2, 18)
	var flatten := clampf(float(spec.get("flatten", 1.0)), 0.25, 1.0)
	var sink := clampf(float(spec.get("sink", 0.0)), 0.0, 0.45)
	var qsize := (size / 0.03).round() * 0.03
	qsize = qsize.max(Vector3(0.03, 0.03, 0.03))
	var key := BakeCache.key(["rock_factory", role, qsize, seed, snappedf(roughness, 0.01), facets, snappedf(flatten, 0.01), snappedf(sink, 0.01)])
	if _cache.has(key):
		return _cache[key]
	var baked = BakeCache.fetch(key)
	if baked != null:
		_cache[key] = baked
		return baked

	var half := qsize * 0.5
	var polys: Array = _box_faces(half)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var count := facets
	if role == "wall_stone":
		count += 2
	elif role == "cap_stone" or role == "stepping_stone":
		count += 1
	elif role == "ledge" or role == "outcrop":
		count += 3
	for i in range(count):
		var n := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.7, 0.7), rng.randf_range(-1.0, 1.0)).normalized()
		if role == "wall_stone" or role == "cap_stone":
			n.y = rng.randf_range(-0.18, 0.18)
			n = n.normalized()
		elif role == "stepping_stone":
			n.y = rng.randf_range(0.72, 1.0)
			n = n.normalized()
		elif role == "ledge" or role == "outcrop":
			n.y = rng.randf_range(-0.2, 0.35)
			n = n.normalized()
		var reach := rng.randf_range(0.68, 0.98)
		# A cut is never allowed to make a point: broad cuts read as fractured stone.
		polys = _cut(polys, n, reach * (1.0 - roughness * 0.35) * minf(half.x, minf(half.y, half.z)) * 1.35)
		if polys.is_empty():
			polys = _box_faces(half)
	# Role shaping happens before the cuts, preserving level beds and sunk stones.
	for poly in polys:
		for p in poly:
			p.y *= flatten
			if sink > 0.0 and p.y < 0.0:
				p.y *= 1.0 - sink
	var mesh := _mesh_from_faces(polys, flatten, sink)
	_cache[key] = mesh
	BakeCache.store(key, mesh)
	return mesh


static func wall(from: Vector3, to: Vector3, height: float, seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var length := from.distance_to(to)
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var x := 0.0
	var course := 0
	while x < length - 0.05:
		var h := minf(height * (0.38 + course * 0.09), height * 0.78)
		var slot := minf(rng.randf_range(0.65, 1.15), length - x)
		var depth := rng.randf_range(0.28, 0.44)
		var center := from + dir * (x + slot * 0.5) + Vector3(0, h * 0.5, 0)
		out.append({"role": "wall_stone", "size": Vector3(slot * 0.9, h * 0.9, depth), "at": center, "yaw": rad_to_deg(atan2(-dir.z, dir.x)), "seed": rng.randi(), "course": course})
		x += slot * 0.94
		if x > length * (0.7 + course * 0.04):
			course += 1
			if course >= 4:
				break
	# A separate cap course makes the top read as a hand-laid wall, not a single slab.
	x = 0.0
	while x < length - 0.05:
		var slot := minf(rng.randf_range(0.75, 1.2), length - x)
		out.append({"role": "cap_stone", "size": Vector3(slot * 0.92, height * 0.18, rng.randf_range(0.42, 0.58)), "at": from + dir * (x + slot * 0.5) + Vector3(0, height * 0.86, 0), "yaw": rad_to_deg(atan2(-dir.z, dir.x)), "seed": rng.randi()})
		x += slot * 0.95
	return out


static func crossing(path_points: PackedVector3Array, width: float, seed := 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(path_points.size()):
		var p := path_points[i]
		out.append({"role": "stepping_stone", "size": Vector3(width * 0.72, width * 0.22, width * 0.56), "at": p, "seed": seed + i * 37})
	return out


static func scatter(area: AABB, density: float, role := "boulder", seed := 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := clampi(int(area.size.x * area.size.z * density), 0, 500)
	for i in range(n):
		var s := rng.randf_range(0.35, 1.0)
		out.append({"role": role, "size": Vector3(s, s * rng.randf_range(0.5, 0.78), s * rng.randf_range(0.7, 1.0)), "at": area.position + Vector3(rng.randf_range(0, area.size.x), 0, rng.randf_range(0, area.size.z)), "seed": rng.randi(), "sink": 0.16})
	return out


static func _box_faces(h: Vector3) -> Array:
	return [[Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)], [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)], [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)], [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)], [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)], [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]]


static func _cut(polys: Array, n: Vector3, d: float) -> Array:
	var result: Array = []
	var cap: Array[Vector3] = []
	for poly in polys:
		var clipped: Array[Vector3] = []
		for i in range(poly.size()):
			var a: Vector3 = poly[i]
			var b: Vector3 = poly[(i + 1) % poly.size()]
			var da := a.dot(n) - d
			var db := b.dot(n) - d
			if da <= 0.0:
				clipped.append(a)
			if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
				var t := da / (da - db)
				var q := a.lerp(b, t)
				clipped.append(q)
				cap.append(q)
		if clipped.size() >= 3:
			result.append(clipped)
	if cap.size() >= 3:
		var center := Vector3.ZERO
		for p in cap: center += p
		center /= cap.size()
		var u := n.cross(Vector3.UP)
		if u.length_squared() < 0.01: u = n.cross(Vector3.RIGHT)
		u = u.normalized()
		var v := n.cross(u).normalized()
		cap.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2((a - center).dot(v), (a - center).dot(u)) < atan2((b - center).dot(v), (b - center).dot(u)))
		result.append(cap)
	return result


static func _mesh_from_faces(polys: Array, flatten := 1.0, sink := 0.0) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for poly in polys:
		for i in range(1, poly.size() - 1):
			var base := vertices.size()
			var a: Vector3 = poly[0]
			var b: Vector3 = poly[i]
			var c: Vector3 = poly[i + 1]
			for p in [a, b, c]:
				var shaped: Vector3 = p
				shaped.y *= flatten
				if sink > 0.0 and shaped.y < 0.0: shaped.y *= 1.0 - sink
				vertices.append(shaped)
			var normal := (b - a).cross(c - a).normalized()
			normals.append(normal); normals.append(normal); normals.append(normal)
			indices.append(base); indices.append(base + 1); indices.append(base + 2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
