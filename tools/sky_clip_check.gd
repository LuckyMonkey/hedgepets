extends SceneTree

## The woods' sky is a 1:16 miniature filmed by a camera at the woods camera's position / 16 (miniature_sky.gd). If
## that camera ends up under the miniature's ground, or closer to any of its geometry than its near plane, the sky goes
## dark or a cut edge sweeps across it. This walks every trail (eye height, every STEP metres) and every place, and
## checks the sky camera's clearance above the miniature terrain and its distance to every miniature triangle near it.
##   godot --headless --audio-driver Dummy --path . --script tools/sky_clip_check.gd
## Exit 1 if any sample is too close (CLEAR, in sky units: the sky camera's near plane with a margin).
const STEP := 0.5
const CLEAR := 0.075                    # sky units (1.2 m at full size); the sky camera's near plane is 0.05

var tris := {}                          # Vector2i cell (0.25 sky units) -> PackedVector3Array of triangle corners


func _init() -> void:
	call_deferred("_run")


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x * 4.0), floori(p.z * 4.0))


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


## The highest miniature surface straight below/above p (sky units), or -INF.
func _ground_at(p: Vector3) -> float:
	var best := -INF
	var f: PackedVector3Array = tris.get(_cell(p), PackedVector3Array())
	for i in range(0, f.size(), 3):
		var a := f[i]
		var b := f[i + 1]
		var c := f[i + 2]
		var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(den) < 1e-12:
			continue
		var u := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.z - c.z)) / den
		var v := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.z - c.z)) / den
		if u < -1e-6 or v < -1e-6 or u + v > 1.0 + 1e-6:
			continue
		best = maxf(best, u * a.y + v * b.y + (1.0 - u - v) * c.y)
	return best


func _nearest(p: Vector3) -> float:
	var best := INF
	var c0 := _cell(p)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var f: PackedVector3Array = tris.get(c0 + Vector2i(dx, dz), PackedVector3Array())
			for i in range(0, f.size(), 3):
				best = minf(best, _closest_on_tri(p, f[i], f[i + 1], f[i + 2]).distance_to(p))
	return best


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	if not g.is_built:
		await g.built
	var w: Node3D = g.woods
	w.build_now()
	var world: Node3D = w.land.view.get_node("World")
	# every miniature triangle within reach of the woods (sky units, the land's own space), binned by cell
	var n := 0
	for mi: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf: Transform3D = world.global_transform.affine_inverse() * mi.global_transform
		var f := mi.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var a: Vector3 = xf * f[i]
			var b: Vector3 = xf * f[i + 1]
			var c: Vector3 = xf * f[i + 2]
			var lo := a.min(b).min(c)
			var hi := a.max(b).max(c)
			if hi.x < -6.0 or lo.x > 6.0 or hi.z < -9.0 or lo.z > 3.5:
				continue                                # nowhere near where the sky camera can be
			for cx in range(floori(lo.x * 4.0), floori(hi.x * 4.0) + 1):
				for cz in range(floori(lo.z * 4.0), floori(hi.z * 4.0) + 1):
					var k := Vector2i(cx, cz)
					if not tris.has(k):
						tris[k] = PackedVector3Array()
					tris[k].append_array([a, b, c])
			n += 1
	# the eye along every trail and the way home, and standing at every place
	var eyes: Array = []
	for e in w._paths:
		if e.get("stub", false):
			continue
		var pts: PackedVector3Array = e["pts"]
		for i in range(1, pts.size()):
			var steps := maxi(1, ceili(pts[i - 1].distance_to(pts[i]) / STEP))
			for k in range(steps):
				eyes.append([pts[i - 1].lerp(pts[i], float(k) / steps) + Vector3(0, w.EYE, 0), "%s-%s" % [e["a"], e["b"]]])
	for id in w.NODES:
		eyes.append([w.node_pos(id) + Vector3(0, w.EYE, 0), id])
	var bad := 0
	var worst := {}
	for s: Array in eyes:
		var q: Vector3 = (s[0] as Vector3) / MiniatureSky.SCALE
		var ground := _ground_at(q)
		var above := q.y - ground
		var near := _nearest(q)
		if above < CLEAR or near < CLEAR:
			bad += 1
			var key: String = s[1]
			if not worst.has(key) or minf(above, near) < worst[key][0]:
				worst[key] = [minf(above, near), s[0], above, near]
	for k in worst:
		var v: Array = worst[k]
		print("SKY %-16s at (%.1f, %.1f, %.1f): %.2f m above the miniature ground, %.2f m from its nearest triangle (full-size metres)" % [k, v[1].x, v[1].y, v[1].z, v[2] * MiniatureSky.SCALE, v[3] * MiniatureSky.SCALE])
	print("sky_clip_check: %d miniature triangles near the woods, %d eye samples, %d too close" % [n, eyes.size(), bad])
	quit(1 if bad > 0 else 0)
