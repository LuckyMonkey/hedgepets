extends "res://scripts/pet/node/pet_face.gd"

## Pet 3/4 - the foliage: leaves as multimeshes over the body, vines and tendrils, flowers, level of detail.
##
## Leaves cover the body as MultiMeshes (one draw per leaf style), placed by the foliage system and mirrored left to
## right (_with_mirror) so the pet is symmetric. Vines and tendrils are tubes along curves. set_detail() / _apply_lod()
## thin the leaves with distance and quality tier: the same shape, fewer leaves.
##
## Part of the pet layer chain (the full order is at the top of scripts/pet/hedge_pet_node.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var leaves_mat: ShaderMaterial
var shell_mat: ShaderMaterial                    # the silhouette ink (the leaves' next pass)
var foliage_nodes: Array[MultiMeshInstance3D] = []
var cluster_debug: Array = []                    # [{position, parent, normal, color}] for the debug view
var detail := "CLOSE"
## Single flowers that have sprouted somewhere unexpected: [region name, direction]. Kept across regrafts.
var extra_flowers: Array = []
var building := false
## A single flower sprouts somewhere on the pet (on top, mostly): grows in, stays, survives regrafts.
func sprout_flower(rng: RandomNumberGenerator) -> void:
	var names: Array = []
	for n in profile.regions:
		if profile.regions[n].get("foliage", false):
			names.append(n)
	if names.is_empty():
		return
	var region: String = names[rng.randi() % names.size()]
	var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.0), rng.randf_range(-1, 1)).normalized()
	extra_flowers.append([region, dir])
	var node := _flower_node(region, dir)
	if node != null:
		Motion.appear(node, Vector3.ONE, Motion.SLOW * 2.0)


func _flower_node(region_name: String, dir: Vector3) -> Node3D:
	if not profile.regions.has(region_name) or leaves_mat == null:
		return null
	var r: Dictionary = profile.regions[region_name]
	var on_head: bool = region_name == "HEAD" or r.get("parent", "") == "HEAD"
	var c: Vector3 = Vector3.ZERO if region_name == "HEAD" else r["center"]
	var p := HedgeAnatomy.shape_point(r, c, dir)
	var n := HedgeAnatomy.shape_normal(r, c, p)
	var size := profile.leaf_size * 0.95
	var t := (Vector3.UP - n * Vector3.UP.dot(n))
	t = t.normalized() if t.length() > 0.05 else n.cross(Vector3.FORWARD).normalized()
	var right := t.cross(n).normalized()
	var up := (t * cos(0.6) + n * sin(0.6)).normalized()
	var item := [Transform3D(Basis(right * size, up * size, right.cross(up).normalized() * size), p + n * 0.03), profile.flower_color, Color(13.0, randf() * TAU, 0.8, 0.0)]
	var holder := Node3D.new()
	holder.name = "ExtraFlower"
	(head if on_head else pet).add_child(holder)
	_add_multimesh(holder, [item], "EXTRA_FLOWER")
	return holder


# ------------------------------------------------------------------ foliage


func rebuild_foliage() -> void:
	for node in foliage_nodes:
		node.queue_free()
	foliage_nodes.clear()
	cluster_debug.clear()
	if leaves_mat == null:
		leaves_mat = ShaderMaterial.new()
		leaves_mat.shader = load("res://shaders/leaf.gdshader")
		leaves_mat.set_shader_parameter("leaf_sheet", Assets.mipmapped("res://assets/sprites/%s.png" % profile.leaf_sheet))
		leaves_mat.set_shader_parameter("leaf_normals", Assets.mipmapped("res://assets/sprites/%s_n.png" % profile.leaf_sheet))
		shell_mat = ShaderMaterial.new()
		shell_mat.shader = load("res://shaders/leaf_ink_shell.gdshader")
		shell_mat.set_shader_parameter("leaf_sheet", leaves_mat.get_shader_parameter("leaf_sheet"))
		leaves_mat.next_pass = shell_mat
	_leaf_param("ink_color", Color(profile.ink_color.r, profile.ink_color.g, profile.ink_color.b))
	shell_mat.set_shader_parameter("strength", profile.silhouette_ink / 0.85)
	shell_mat.set_shader_parameter("body_radius", (profile.regions["BODY"]["radii"] as Vector3).length() / sqrt(3.0))
	shell_mat.set_shader_parameter("head_radius", (profile.regions["HEAD"]["radii"] as Vector3).length() / sqrt(3.0))
	leaves_mat.set_shader_parameter("silhouette_ink", profile.silhouette_ink)
	leaves_mat.set_shader_parameter("interior_ink", profile.interior_ink)
	var key_dir := Basis.from_euler(profile.key_angle * PI / 180.0) * Vector3.FORWARD
	var head_c: Vector3 = profile.regions["HEAD"]["center"]
	for region_name in profile.regions:
		var r: Dictionary = profile.regions[region_name]
		if not r.get("foliage", false):
			continue
		await _slice()
		HitchLog.tag("pet_part:%s/foliage_%s" % [profile.pet_name, region_name])
		var built := FoliageBuilder.build(profile, region_name, head_c, key_dir)
		await _slice()
		var parent: Node3D = head if (region_name == "HEAD" or r.get("parent", "") == "HEAD") else pet
		var items: Array = built["items"]
		if r.get("mirror", false):
			items = _with_mirror(items, r)
		elif r.has("rotation"):
			items = _rotated(items, r, 1.0)
		await _add_multimesh(parent, items, region_name)
		for c in built["clusters"]:
			cluster_debug.append({"position": c["position"], "parent": parent, "normal": c["normal"], "color": c["color"]})
	await _slice()
	await _add_multimesh(pet, _tendrils(), "TENDRILS")
	for f in extra_flowers:
		_flower_node(f[0], f[1])
	set_detail(detail, true)


## Leaves grown on a rotated region follow its rotation (about the region's centre).
func _rotated(items: Array, r: Dictionary, side: float) -> Array:
	var rot: Vector3 = r.get("rotation", Vector3.ZERO)
	var c: Vector3 = r["center"]
	var b := Basis.from_euler(Vector3(deg_to_rad(rot.x * side), deg_to_rad(rot.y * side), deg_to_rad(rot.z)))
	var out: Array = []
	for it in items:
		var t: Transform3D = it[0]
		var local := t.origin - c
		out.append([Transform3D(b * t.basis, c + b * local), it[1], it[2]])
	return out


## A mirrored region (ears): the leaves on the other side are the same leaves, reflected across z.
func _with_mirror(items: Array, r: Dictionary) -> Array:
	var c: Vector3 = r["center"]
	var near := _rotated(items, r, 1.0)
	var far_items: Array = []
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	for it in items:
		var t: Transform3D = it[0]
		var o := t.origin
		far_items.append([Transform3D(flip * t.basis, Vector3(o.x, o.y, -o.z)), it[1], it[2]])
	var mirrored := r.duplicate()
	mirrored["center"] = c * Vector3(1, 1, -1)
	return near + _rotated(far_items, mirrored, -1.0)


func _add_multimesh(parent: Node3D, items: Array, label: String) -> void:
	if items.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	await _slice()
	mm.instance_count = items.size()
	await _slice()
	for i in range(items.size()):
		if i % 128 == 0:
			await _slice()
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
		mm.set_instance_custom_data(i, items[i][2])
	var node := MultiMeshInstance3D.new()
	node.name = "Foliage_" + label
	node.multimesh = mm
	node.material_override = leaves_mat
	parent.add_child(node)
	foliage_nodes.append(node)


## Level 4: a few short tendrils trailing from the lower body; short so the silhouette stays the animal.
## Vines: stems that run over the body (between the leaves, so they weave in and out), with fresh leaves along them
## and a curling tendril where each one escapes the silhouette (the goal image's growth curves).
var _vine_nodes: Array[Node3D] = []


func _tendrils() -> Array:
	for n in _vine_nodes:
		n.queue_free()
	_vine_nodes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(profile.seed) + "vines")
	var body: Dictionary = profile.regions["BODY"]
	var c: Vector3 = body["center"]
	var items: Array = []
	var stem := StandardMaterial3D.new()
	stem.albedo_color = profile.palette["warm_yellow_green"].darkened(0.25)
	stem.roughness = 1.0
	for v in range(profile.tendrils):
		# start on the upper body, walk around it along a tilted great circle
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.0), rng.randf_range(-1, 1)).normalized()
		var axis := d.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1))).normalized()
		var steps := rng.randi_range(9, 15)
		var pts: Array[Vector3] = []
		for k in range(steps):
			d = d.rotated(axis, 0.16 + 0.04 * sin(k * 1.3))
			if d.y < -0.25:
				break
			var p := HedgeAnatomy.shape_point(body, c, d)
			var n := HedgeAnatomy.shape_normal(body, c, p)
			pts.append(p + n * (0.13 + 0.05 * sin(k * 2.1 + v)))
		if pts.size() < 4:
			continue
		# the end lifts off and curls out into the air
		var last: Vector3 = pts[-1]
		var out := (last - c).normalized()
		var reach := clampf((body["radii"] as Vector3).x / 1.3, 0.35, 1.0)        # tendrils sized to the pet
		for k in range(3):
			last += (out * 0.1 + Vector3(0, 0.05 - k * 0.06, 0) + out.cross(Vector3.UP).normalized() * 0.04 * k) * reach
			pts.append(last)
		for k in range(1, pts.size() - 1):
			if k % 2 != 0:
				continue
			var t: Vector3 = (pts[k + 1] - pts[k - 1]).normalized()
			var n: Vector3 = (pts[k] - c).normalized()
			var side := t.cross(n).normalized() * (1.0 if k % 4 == 0 else -1.0)
			var up := (side * 0.8 + t * 0.4 + n * 0.3).normalized()
			var right := up.cross(n).normalized()
			var size := profile.leaf_size * rng.randf_range(0.5, 0.75)
			items.append([Transform3D(Basis(right * size, up * size, right.cross(up).normalized() * size), pts[k]),
				profile.palette["warm_yellow_green"].lerp(profile.palette["matcha"], rng.randf()), Color(float(rng.randi_range(0, 7)), rng.randf_range(0, TAU), 1.0, 0.3)])
		var tip: Vector3 = pts[-1]
		var tdir: Vector3 = (pts[-1] - pts[-2]).normalized()
		var tright := tdir.cross(Vector3.UP).normalized()
		var tsize := profile.leaf_size * 0.9
		items.append([Transform3D(Basis(tright * tsize, tdir * tsize, tright.cross(tdir).normalized() * tsize), tip), profile.palette["muted_ivy"], Color(11.0, rng.randf_range(0, TAU), 1.0, 0.5)])
		_vine_nodes.append(_tube(pts, 0.022, stem))
	return items


## A thin stem along points (with an ink outline), on the pet.
func _tube(pts: Array[Vector3], radius: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := 6
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var dir := (b - a).normalized()
		var x := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var y := dir.cross(x).normalized()
		var ra := radius * (1.0 - 0.5 * float(i) / pts.size())
		var rb := radius * (1.0 - 0.5 * float(i + 1) / pts.size())
		for k in range(ring):
			var a0 := TAU * k / ring
			var a1 := TAU * (k + 1) / ring
			var n0 := x * cos(a0) + y * sin(a0)
			var n1 := x * cos(a1) + y * sin(a1)
			for vtx: Array in [[a + n0 * ra, n0], [b + n0 * rb, n0], [b + n1 * rb, n1], [a + n0 * ra, n0], [b + n1 * rb, n1], [a + n1 * ra, n1]]:
				st.set_normal(vtx[1])
				st.add_vertex(vtx[0])
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = m
	node.material_overlay = _hull(0.008)
	node.name = "Vine"
	pet.add_child(node)
	return node


## Set a uniform on the leaves and their ink shell together.
func _leaf_param(name: String, value: Variant) -> void:
	leaves_mat.set_shader_parameter(name, value)
	if shell_mat != null:
		shell_mat.set_shader_parameter(name, value)


## Detail levels (mobile first): fewer, bigger leaves keep the masses whole; interior ink fades.
## Smooth: the leaves of the new level grow in / shrink away (scripts/anim/motion.gd). instant = true for captures.
func set_detail(level: String, instant := false) -> void:
	detail = level
	if building:                                         # (applied when it's whole: _setup_body ends with set_detail)
		return
	var l: Dictionary = profile.lod[level]
	var goal := Vector3(float(l["leaves"]), float(l["scale"]), float(l["ink"]))
	if instant or Motion.speed <= 0.0 or leaves_mat == null:
		_lod = goal
		_apply_lod()
		return
	var t := Motion.channel(self, "lod")
	t.tween_method(func(v: Vector3) -> void:
		_lod = v
		_apply_lod(), _lod, goal, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## How grown-in the foliage is: 0 bare (just the green mass), 1 full. Motion.grow_leaves / shed_leaves animate it.
var leaf_growth := 1.0:
	set(v):
		leaf_growth = v
		if leaves_mat != null:
			_apply_lod()
var _lod := Vector3(1.0, 1.0, 1.0)         # kept rank, leaf scale, interior ink of the current detail level


func _apply_lod() -> void:
	_leaf_param("lod_keep", lerpf(-0.3, _lod.x, leaf_growth))
	_leaf_param("lod_scale", _lod.y)
	leaves_mat.set_shader_parameter("detail_ink", _lod.z)


## Foliage presets for the acceptance captures.
func set_foliage(preset: String) -> void:
	match preset:
		"LOW":
			profile.growth = 0.35
			profile.flowering = 0.0
		"MEDIUM":
			profile.growth = 0.65
			profile.flowering = 0.15
		"FULL":
			profile.growth = 1.0
			profile.flowering = 0.35
		"FLOWERING":
			profile.growth = 1.0
			profile.flowering = 1.0
	rebuild_foliage()
