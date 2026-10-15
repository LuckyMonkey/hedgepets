extends RefCounted

## What a bake must contain, checked on the data itself (tools/bake_cache.gd before and after saving, and
## tools/foliage_bake_check.gd in a separate process). A successful bake is not a complete bake:
##   - no MultiMesh with instances: a headless bake saves MultiMesh instance data empty (the leaves vanish), and a
##     MultiMesh loaded from a resource reads back zeros to scripts even on a GPU, so it can't be verified either.
##     Foliage is stored as packed leaves (garden.gd pack_leaves) instead.
##   - every packed leaf set: a count > 0, exactly 20 floats (or, half precision, 40 bytes) per leaf, and every leaf decodes to a finite,
##     non-degenerate transform (an all-zero leaf is an invisible leaf).
##   - the grass buffer: 20 floats per tuft, none degenerate.
##   - every mesh: at least one surface with vertices.

const Garden := preload("res://scripts/garden/garden.gd")


## {"problems": [String], "leaf_sets": int, "leaves": int, "by_kind": {kind: [sets, leaves]}, "meshes": int}
static func check(data: BakedData) -> Dictionary:
	var out := {"problems": [], "leaf_sets": 0, "leaves": 0, "by_kind": {}, "meshes": 0}
	for k in data.items:
		_walk(data.items[k], str(k), out)
	return out


static func _walk(v: Variant, k: String, out: Dictionary) -> void:
	if v is MultiMesh:
		if (v as MultiMesh).instance_count > 0:
			out["problems"].append("%s: a MultiMesh with %d instances: a headless bake saves its instance data empty (store packed leaves)" % [k, v.instance_count])
		return
	if v is Mesh:
		out["meshes"] += 1
		var verts := 0
		for s in range((v as Mesh).get_surface_count()):
			verts += ((v as Mesh).surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if verts == 0:
			out["problems"].append("%s: a mesh with no vertices" % k)
		return
	if v is Array:
		var a: Array = v
		if a.size() == 4 and a[0] is PackedFloat32Array and a[1] is int and a[2] is PackedVector3Array:
			_leaves(a[0], a[1], k, "bush", out)                     # garden._bush, full: leaves + the mass's verts/normals
			if (a[2] as PackedVector3Array).is_empty() or (a[2] as PackedVector3Array).size() != (a[3] as PackedVector3Array).size():
				out["problems"].append("%s: a bush mass with %d vertices and %d normals" % [k, a[2].size(), a[3].size()])
			return
		if a.size() == 2 and a[0] is PackedByteArray and a[1] is int:
			_leaves(a[0], a[1], k, "bush", out)                     # garden._bush, half
			return
		if a.size() == 5 and str(a[0]) == "leaves" and (a[1] is PackedByteArray or a[1] is PackedFloat32Array):
			_leaves(a[1], a[3], k, "woods_patch", out)              # woods_trees patch
			return
		if a.size() == 3 and a[0] is int and a[1] is PackedFloat32Array:
			_floats(a[1], a[0], k, "grass", out)                    # garden grass: [count, buffer, rng state]
			return
		for x in a:
			_walk(x, k, out)
		return
	if v is Dictionary:
		for x in (v as Dictionary).values():
			_walk(x, k, out)


static func _leaves(bytes: Variant, count: int, k: String, kind: String, out: Dictionary) -> void:
	if count <= 0:
		out["problems"].append("%s: an empty %s leaf set" % [k, kind])
		return
	if bytes is PackedFloat32Array:
		_floats(bytes, count, k, kind, out)
		return
	if bytes.size() != count * 40:
		out["problems"].append("%s: %s leaf set of %d leaves has %d bytes (want %d)" % [k, kind, count, bytes.size(), count * 40])
		return
	_floats(Garden.unpack_leaves(bytes, count), count, k, kind, out)


static func _floats(f: PackedFloat32Array, count: int, k: String, kind: String, out: Dictionary) -> void:
	if count <= 0 or f.size() != count * 20:
		out["problems"].append("%s: %s buffer of %d floats for %d instances" % [k, kind, f.size(), count])
		return
	var bad := 0
	for i in range(count):
		var o := i * 20
		var det := f[o] * (f[o + 5] * f[o + 10] - f[o + 6] * f[o + 9]) - f[o + 1] * (f[o + 4] * f[o + 10] - f[o + 6] * f[o + 8]) \
			+ f[o + 2] * (f[o + 4] * f[o + 9] - f[o + 5] * f[o + 8])
		if not is_finite(det) or absf(det) < 1e-9 or not is_finite(f[o + 3] + f[o + 7] + f[o + 11]):
			bad += 1
	if bad > 0:
		out["problems"].append("%s: %d of %d %s instances are degenerate or non-finite" % [k, bad, count, kind])
	out["leaf_sets"] += 1
	out["leaves"] += count
	if not out["by_kind"].has(kind):
		out["by_kind"][kind] = [0, 0]
	out["by_kind"][kind][0] += 1
	out["by_kind"][kind][1] += count
