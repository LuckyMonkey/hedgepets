extends SceneTree

## What the walk passes through: sweeps the camera's eye (1.5 m up, near plane 0.08 m) and the walker's body along
## every trail in the woods, and lists every piece of geometry that comes within reach - solid meshes (triangles)
## and leaf / grass instances (their boxes). Headless; no rendering needed.
##   godot --headless --audio-driver Dummy --path . --script tools/woods_clip_check.gd
## Exit 1 if anything solid is inside the eye's radius or across the walker's body.
const EYE_R := 0.32                 # the camera: near plane + a margin (closer than this, you see inside it)
const BODY_R := 0.3                 # the walker, knee to chest
const STEP := 0.25

var samples := {}                   # Vector2i cell -> Array of [point, radius, kind]
var hits := {}                      # key -> {what, at, kind, d}


func _init() -> void:
	call_deferred("_run")


func _add(p: Vector3, r: float, kind: String) -> void:
	var c := Vector2i(floori(p.x), floori(p.z))
	if not samples.has(c):
		samples[c] = []
	samples[c].append([p, r, kind])


func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)


func _near(lo: Vector3, hi: Vector3) -> Array:
	var out: Array = []
	for x in range(floori(lo.x - 1.0), floori(hi.x + 1.0) + 1):
		for z in range(floori(lo.z - 1.0), floori(hi.z + 1.0) + 1):
			var s = samples.get(Vector2i(x, z))
			if s != null:
				out.append_array(s)
	return out


func _hit(what: String, at: Vector3, kind: String, d: float, r := 0.0) -> void:
	if r - d < 0.035:
		what += " #graze"                                 # within 3 cm of the edge: brushing past, not through
	var key := "%s@%d,%d" % [what, roundi(at.x), roundi(at.z)]
	if not hits.has(key) or hits[key]["d"] > d:
		hits[key] = {"what": what, "at": at, "kind": kind, "d": d}


## A readable name: the nearest named ancestor, the material's colour, and the size of the thing.
func _describe(mi: MeshInstance3D, woods: Node, box: AABB) -> String:
	var q: Node = mi
	var named := ""
	while q != null and q != woods:
		if not str(q.name).begins_with("@"):
			named = str(q.name)
			break
		q = q.get_parent()
	var m = mi.material_override
	var col := ""
	if m is StandardMaterial3D:
		col = (m as StandardMaterial3D).albedo_color.to_html(false)
	elif m is ShaderMaterial:
		col = (m as ShaderMaterial).shader.resource_path.get_file()
	return "%s %s size %.1fx%.1fx%.1f %s" % [named, col, box.size.x, box.size.y, box.size.z, mi.mesh.get_class()]


func _skip(n: Node, woods: Node) -> bool:
	if n is Node3D and not (n as Node3D).is_visible_in_tree():
		return true                                       # templates, the pail when not carried
	if n is GeometryInstance3D and (n as GeometryInstance3D).material_override is ShaderMaterial \
			and ((n as GeometryInstance3D).material_override as ShaderMaterial).shader.resource_path.ends_with("light_shaft.gdshader"):
		return true                                       # sunbeams: light, not things (they fade out up close)
	var q := n
	while q != null and q != woods:
		if q.name in ["Sunbeam", "HomeView", "Brook", "DistantLand"] or q is SubViewport:
			return true
		q = q.get_parent()
	return false


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	BakeCache.reset()
	BakeCache._usable = 0                                 # built live: what the code makes now, not an old bake
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	var w: Node3D = g.woods
	w.build_now()
	w.visible = true                                     # (hidden until you walk in)
	var inv := w.global_transform.affine_inverse()
	# the walk: every trail, both ways the same line; the way home; standing at each place (turning)
	var lines: Array = []
	for e in w._paths:
		if not e.get("stub", false):
			lines.append(e["pts"])
	var home := PackedVector3Array()
	var t := 0.0
	while t <= 17.0:
		var p2: Vector2 = w.HOME_DIR * t
		var y: float = w.height(p2.x, p2.y)
		if absf((p2 - w.BROOK_AT).dot(w.HOME_DIR)) < 2.6:   # over the creek you walk on the footbridge's deck
			y = maxf(y, w._base(Vector2.ZERO) + 0.2)
		home.append(Vector3(p2.x, y, p2.y))
		t += 0.5
	lines.append(home)
	for pts: PackedVector3Array in lines:
		for i in range(1, pts.size()):
			var a: Vector3 = pts[i - 1]
			var b: Vector3 = pts[i]
			var n := maxi(1, ceili(a.distance_to(b) / STEP))
			for k in range(n):
				var p: Vector3 = a.lerp(b, float(k) / n)
				_add(p + Vector3(0, w.EYE, 0), EYE_R, "eye")
				_add(p + Vector3(0, 0.7, 0), BODY_R, "body")
				_add(p + Vector3(0, 1.1, 0), BODY_R, "body")
	for id in w.NODES:
		_add(w.node_pos(id) + Vector3(0, w.EYE, 0), EYE_R + 0.15, "eye")
	var tris := 0
	var stack: Array = [w]
	var ground_done := false
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not n is GeometryInstance3D or _skip(n, w) or not (n as Node3D).is_visible_in_tree() and n.get_parent() != w:
			pass
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and not _skip(n, w):
			var mi := n as MeshInstance3D
			var xf: Transform3D = inv * mi.global_transform
			var box: AABB = xf * mi.mesh.get_aabb()
			if box.size.x > 100.0 or box.size.y < 0.25:
				continue                                         # the ground, trail ribbons, flat litter: underfoot
			if _near(box.position, box.end).is_empty():
				continue
			var f: PackedVector3Array = mi.mesh.get_faces()
			tris += f.size() / 3
			for i in range(0, f.size(), 3):
				var a: Vector3 = xf * f[i]
				var b: Vector3 = xf * f[i + 1]
				var c: Vector3 = xf * f[i + 2]
				var lo := a.min(b).min(c)
				var hi := a.max(b).max(c)
				if hi.y < 0.0 and false:
					continue
				for s: Array in _near(lo, hi):
					var p: Vector3 = s[0]
					if p.y + s[1] < lo.y or p.y - s[1] > hi.y:
						continue
					var q := _closest_on_tri(p, a, b, c)
					var d := q.distance_to(p)
					if d < float(s[1]):
						_hit(_describe(mi, w, box), q, s[2], d, float(s[1]))
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null and not _skip(n, w):
			var mmi := n as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm.mesh == null:
				continue
			var xf: Transform3D = inv * mmi.global_transform
			var mb := mm.mesh.get_aabb()
			for i in range(mm.instance_count):
				var ix: Transform3D = xf * mm.get_instance_transform(i)
				var box: AABB = ix * mb
				if box.size.y < 0.25 and box.end.y < 0.0:
					continue
				var cpos := box.get_center()
				for s: Array in _near(box.position, box.end):
					var p: Vector3 = s[0]
					var q := p.clamp(box.position, box.end)
					var d := q.distance_to(p)
					if d < float(s[1]) * 0.6:                      # a card's box is bigger than the card: be generous
						_hit("%s %s #leafy" % [mm.mesh.get_class(), str(mmi.material_override.resource_path if mmi.material_override else "")], cpos, s[2], d)
	# the ground itself: nowhere along the walk may the land rise into the camera
	var buried := 0
	for cellk in samples:
		for s: Array in samples[cellk]:
			if s[2] != "eye":
				continue
			var p: Vector3 = s[0]
			for o: Vector2 in [Vector2.ZERO, Vector2(0.35, 0), Vector2(-0.35, 0), Vector2(0, 0.35), Vector2(0, -0.35)]:
				if w.height(p.x + o.x, p.z + o.y) > p.y - 0.45:
					buried += 1
					if buried <= 12:
						print("TERRAIN eye at (%.1f, %.1f, %.1f): ground %.2f m below the eye" % [p.x, p.y, p.z, p.y - w.height(p.x + o.x, p.z + o.y)])
					break
	print("woods_clip_check: %d eye samples with the ground within 0.45 m" % buried)
	var solid := buried
	var keys: Array = hits.keys()
	keys.sort_custom(func(a, b) -> bool: return hits[a]["d"] < hits[b]["d"])
	for k in keys:
		var h: Dictionary = hits[k]
		var leafy := str(h["what"]).ends_with("#leafy")
		var graze := str(h["what"]).ends_with("#graze")
		if not leafy and not graze:
			solid += 1
		print("%s %-5s %.2f m  at (%.1f, %.1f, %.1f)  %s" % ["LEAF " if leafy else ("GRAZE" if graze else "SOLID"), h["kind"], h["d"], h["at"].x, h["at"].y, h["at"].z, h["what"]])
	print("woods_clip_check: %d triangles near the walk, %d solid hits, %d leafy hits" % [tris, solid, hits.size() - solid])
	quit(1 if solid > 0 else 0)
