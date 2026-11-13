class_name RockFactory
extends RefCounted

## Very-low-poly rocks. The mesh never grows new detail during a variation: a handful of points is
## fractured in place, nudged once, then hulled. Grain and cracks belong in rock.gdshader.

const ROLES := ["wall_stone", "cap_stone", "stepping_stone", "boulder", "cobble", "scree", "ledge", "outcrop"]
const DATA_PATH := "res://data/rocks.json"
static var _cache := {}
static var _archetypes := {}
static var _rock_shader: Shader

static func archetypes() -> Dictionary:
	if _archetypes.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_archetypes = parsed
	return _archetypes

static func archetype(role: String) -> Dictionary:
	var key := "weathered_boulder" if role == "boulder" else role
	var data: Dictionary = archetypes().get(key, archetypes().get("weathered_boulder", {})).duplicate(true)
	return data

static func make(spec: Dictionary) -> ArrayMesh:
	var role := str(spec.get("role", "boulder"))
	var data := archetype(role)
	data["role"] = role
	for k in spec:
		if k != "role" and k != "at" and k != "yaw": data[k] = spec[k]
	var size: Vector3 = spec.get("size", Vector3.ONE)
	var seed := int(spec.get("seed", 1))
	var qsize := (size / 0.03).round() * 0.03
	qsize = qsize.max(Vector3(0.03, 0.03, 0.03))
	var key := BakeCache.key(["rock_factory_v2", role, qsize, seed, data])
	if _cache.has(key): return _cache[key]
	var baked = BakeCache.fetch(key)
	if baked != null:
		_cache[key] = baked
		return baked

	var max_triangles := int(data.get("max_triangles", 48))
	var points: Array = _build_points(data, qsize, seed, max_triangles)
	var mesh := _hull_mesh(points, Color.WHITE)
	var triangles := _triangle_count(mesh)
	# The cap is a contract, not a guideline. Reduce the point set if an unusual archetype edit breaks it.
	while triangles > max_triangles and points.size() > 8:
		points = points.slice(0, points.size() - 1)
		mesh = _hull_mesh(points, Color.WHITE)
		triangles = _triangle_count(mesh)
	if triangles > max_triangles:
		push_error("RockFactory: %s produced %d triangles; cap is %d" % [role, triangles, max_triangles])
	_cache[key] = mesh
	BakeCache.store(key, mesh)
	return mesh


static func material(tint: Color) -> ShaderMaterial:
	if _rock_shader == null: _rock_shader = load("res://shaders/rock.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _rock_shader
	m.set_shader_parameter("tint", tint)
	return m


static func triangle_count(role: String, seed := 1) -> int:
	var d := archetype(role)
	var aspect := _v3(d.get("aspect", [1.0, 1.0, 1.0]))
	return _triangle_count(make({"role": role, "size": aspect, "seed": seed}))


static func wall(from: Vector3, to: Vector3, height: float, seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var length := from.distance_to(to)
	var dir := (to - from).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var x := 0.0
	var course := 0
	while x < length - 0.05:
		var h := minf(height * (0.38 + course * 0.09), height * 0.78)
		var slot := minf(rng.randf_range(0.65, 1.15), length - x)
		out.append({"role": "wall_stone", "size": Vector3(slot * 0.9, h * 0.9, rng.randf_range(0.28, 0.44)), "at": from + dir * (x + slot * 0.5) + Vector3(0, h * 0.5, 0), "yaw": rad_to_deg(atan2(-dir.z, dir.x)), "seed": rng.randi(), "course": course})
		x += slot * 0.94
		if x > length * (0.7 + course * 0.04):
			course += 1
			if course >= 4: break
	x = 0.0
	while x < length - 0.05:
		var slot := minf(rng.randf_range(0.75, 1.2), length - x)
		out.append({"role": "cap_stone", "size": Vector3(slot * 0.92, height * 0.18, rng.randf_range(0.42, 0.58)), "at": from + dir * (x + slot * 0.5) + Vector3(0, height * 0.86, 0), "yaw": rad_to_deg(atan2(-dir.z, dir.x)), "seed": rng.randi()})
		x += slot * 0.95
	return out


static func crossing(path_points: PackedVector3Array, width: float, seed := 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(path_points.size()):
		out.append({"role": "stepping_stone", "size": Vector3(width * 0.72, width * 0.22, width * 0.56), "at": path_points[i], "seed": seed + i * 37})
	return out


static func scatter(area: AABB, density: float, role := "boulder", seed := 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(clampi(int(area.size.x * area.size.z * density), 0, 500)):
		var s := rng.randf_range(0.35, 1.0)
		out.append({"role": role, "size": Vector3(s, s * rng.randf_range(0.5, 0.78), s * rng.randf_range(0.7, 1.0)), "at": area.position + Vector3(rng.randf_range(0, area.size.x), 0, rng.randf_range(0, area.size.z)), "seed": rng.randi(), "sink": 0.16})
	return out


static func _build_points(data: Dictionary, size: Vector3, seed: int, max_triangles: int) -> Array:
	var count := clampi(int(data.get("hull_points", 12)), 10, 14)
	if max_triangles <= 16: count = 10
	var aspect := _v3(data.get("aspect", [1.0, 1.0, 1.0]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var points: Array[Vector3] = []
	points.append(Vector3(0, aspect.y, 0))
	points.append(Vector3(0, -aspect.y, 0))
	var ring := count - 2
	for i in range(ring):
		var a := TAU * float(i) / ring + rng.randf_range(-0.06, 0.06)
		var y := rng.randf_range(-0.18, 0.18) * aspect.y
		points.append(Vector3(cos(a) * aspect.x, y, sin(a) * aspect.z))
	# 1. Structural fracture planes: project beyond-plane vertices, never add geometry.
	var planes := clampi(int(data.get("fracture_planes", 4)), 3, 6)
	var role := str(data.get("role", ""))
	for p in range(planes):
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1)).normalized()
		if role in ["wall_stone", "cap_stone"]: n.y = rng.randf_range(-0.12, 0.12)
		elif role == "stepping_stone": n = Vector3(rng.randf_range(-0.3, 0.3), 1, rng.randf_range(-0.3, 0.3)).normalized()
		elif role in ["ledge", "outcrop"]: n.y = rng.randf_range(-0.16, 0.28)
		var d := rng.randf_range(0.55, 0.86) * minf(aspect.x, minf(aspect.y, aspect.z))
		for i in points.size():
			var over := points[i].dot(n) - d
			if over > 0.0: points[i] -= n * over
	# 2. One broad coherent nudge, capped by the archetype's displacement budget.
	var displacement := minf(minf(float(data.get("deformation", 0.05)), float(data.get("max_displacement", 0.08))), 0.08)
	for i in points.size():
		var p := points[i]
		var broad := Vector3(sin(p.x * 1.7 + seed), cos(p.z * 1.3 + seed * 0.7), sin((p.x + p.z) * 1.1 + seed * 0.31))
		var nudge := broad * (displacement * 0.45)
		points[i] = (p + nudge).clamp(-aspect * 1.08, aspect * 1.08)
	# 3. Weathering: at most three sharp crown points are pulled inward, no new triangles.
	var weathering := clampf(float(data.get("weathering", 0.2)), 0.0, 0.35)
	for i in range(mini(3, points.size())):
		var index := (seed + i * 5) % points.size()
		points[index] = points[index].lerp(Vector3.ZERO, weathering * 0.08)
	return points.map(func(p: Vector3) -> Vector3: return Vector3(p.x * size.x * 0.5, p.y * size.y * 0.5, p.z * size.z * 0.5))


static func _hull_mesh(points: Array, tint: Color) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var eps := 0.00001
	for a in range(points.size()):
		for b in range(a + 1, points.size()):
			for c in range(b + 1, points.size()):
				var normal: Vector3 = (points[b] - points[a]).cross(points[c] - points[a])
				if normal.length_squared() < eps: continue
				# Reject slivers before they can become a visible facet. The point budget remains unchanged.
				var extent: float = points[a].distance_to(points[b]) + points[b].distance_to(points[c]) + points[c].distance_to(points[a])
				if normal.length() < extent * extent * 0.012: continue
				var side := 0
				var valid := true
				for j in points.size():
					if j == a or j == b or j == c: continue
					var s := signf(normal.dot(points[j] - points[a]))
					if absf(s) < 0.001: continue
					if side == 0: side = int(s)
					elif int(s) != side:
						valid = false
						break
				if not valid or side == 0: continue
				var n: Vector3 = normal.normalized() * (-1.0 if side > 0 else 1.0)
				var base := vertices.size()
				vertices.append(points[a]); vertices.append(points[c] if side > 0 else points[b]); vertices.append(points[b] if side > 0 else points[c])
				normals.append(n); normals.append(n); normals.append(n)
				colors.append(tint); colors.append(tint); colors.append(tint)
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _triangle_count(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0: return 0
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3


static func _v3(value: Variant) -> Vector3:
	if value is Vector3: return value
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
