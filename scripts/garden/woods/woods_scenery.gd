extends "res://scripts/garden/woods/woods_trails.gd"

## Woods 3/6 - the scenery: trees and crowns, willows, the forest floor, undergrowth, clearings, the pine flats.
##
## The bulk of what you see. Trees are batched per patch as MultiMeshes (one draw per patch, not per tree);
## crowns are shared templates (_crown_template) so 110 leafy crowns cost a handful of meshes. _keep_open() is the
## rule that nothing grows on a trail or in an arrival view. The forest floor, undergrowth and pine flats are all
## scattered from seeded RNGs: the order of calls here decides where every plant lands, so do not reorder them.
##
## Part of the woods layer chain (see scripts/garden/woods.gd for the full order). Code here was moved verbatim from
## the old single file; only its place changed.

## Calico aster in the sunny spots along the trails (garden.aster_clump: copies of three stems), just off the tread.
## Its own numbers, so nothing else in the woods moves.
func _asters() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 5150
	var next := 8.0
	for e in _paths:
		if e.get("stub", false):
			continue
		var pts: PackedVector3Array = e["pts"]
		var run := 0.0
		for i in range(1, pts.size()):
			run += pts[i - 1].distance_to(pts[i])
			if run < next:
				continue
			next = run + r.randf_range(10.0, 18.0)
			var d := Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).normalized()
			var side := 1.0 if r.randf() < 0.5 else -1.0
			var p := Vector2(pts[i].x, pts[i].z) + d.orthogonal() * side * r.randf_range(2.0, 2.6)
			if _near_trail(p, 1.5):                      # (soft and leafy: brushing past one is fine, like the ferns)
				continue
			garden.aster_clump(self, Vector3(p.x, height(p.x, p.y) - 0.05, p.y), r.randi())
		next -= run


## The trees (woods_trees.gd): oak, maple, birch and white pine, real trunks and limbs under leafy crowns; with
## leaves near the trails, dark crown masses further off. Never within 2.8 m of a trail.
func _trees(rng: RandomNumberGenerator) -> void:
	var maker = preload("res://scripts/garden/woods_trees.gd").new(self)
	for k in range(1300):
		await Slicer.tick(self)
		var p := Vector2(rng.randf_range(-58, 58), rng.randf_range(-108, 16))
		if _keep_open(p, rng):
			continue
		if _near_trail(p, 2.8):                          # by a trail: stepped back off it, not lost (the woods stay thick)
			var t := _nearest_trail(p)
			if t == Vector2.INF or t.distance_to(p) < 0.01:
				continue
			p = t + (p - t).normalized() * rng.randf_range(3.2, 4.5)
			if _near_trail(p, 2.8) or _keep_open(p, rng):
				continue
		var roll := rng.randf()
		var kind := "pine" if roll < 0.35 else ("oak" if roll < 0.6 else ("maple" if roll < 0.85 else "birch"))
		var to_pines: Vector2 = p - (NODES["pines"]["at"] as Vector2)
		if p.distance_to(NODES["pines"]["at"]) < PINES_R + 6.0 or (to_pines.dot(PINES_VIEW) > 0.0 and absf(to_pines.dot(PINES_VIEW.orthogonal())) < 10.0 + to_pines.dot(PINES_VIEW) * 0.4):
			kind = "pine"                                # the flats and their view are a white pine stand
		var blaze := Vector3.ZERO                            # a painted trail blaze on trunks right by the path
		if _near_trail(p, 4.2) and rng.randf() < 0.3:
			var t := _nearest_trail(p)
			if t != Vector2.INF:                                 # (not by the way home: no blazes on that)
				blaze = Vector3(t.x - p.x, 0, t.y - p.y).normalized()
		maker.tree(kind, Vector3(p.x, height(p.x, p.y), p.y), rng, _near_trail(p, maker.LEAFY_REACH), blaze)
	await maker.finish()
	set_meta("trees_rejected", maker.rejected)


## Leafy crowns: a few made once with the hedgepets' foliage (fixed seeds, so they bake), shared by every tree near a
## trail. [leaf sheet, palette].
const CROWNS := [["hedgeoak", "autumn"], ["hedgemaple", "crimson"], ["hedgeoak", "green"], ["hedgemaple", "autumn"],
	["hedgeivy", "green"], ["hedgeboxwood", "spring"]]
var _crowns: Array = []


func _crown_template(i: int, sheet := "", palette := "", radii := Vector3(2.4, 1.9, 2.4)) -> Node3D:
	if sheet == "":
		while _crowns.size() <= i:
			_crowns.append(null)
		if _crowns[i] != null:
			return _crowns[i]
		sheet = CROWNS[i][0]
		palette = CROWNS[i][1]
	var pal := SpeciesBuilder.palette_of(palette)
	var inner := Color(SpeciesBuilder.PALETTES[palette][6])
	var t: Node3D = garden._bush(Vector3.ZERO, radii, sheet, pal, inner, 0.7, 0.9, "dome", 0.0, Color(1.0, 0.98, 0.92), 9100 + i)
	t.reparent(self, false)
	t.visible = false
	if i < _crowns.size():
		_crowns[i] = t
	return t


## Weeping willows on the creek banks and round the pond: a leaning trunk, a soft crown of willow leaves, and long
## strands hanging almost to the ground, swaying.
var _willows_sway: Array = []


func _willows(rng: RandomNumberGenerator) -> void:
	var spots: Array = []
	for along: float in [-52.0, -30.0, -9.0, 14.0, 33.0, 55.0]:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		spots.append(_creek_point(along + rng.randf_range(-3, 3)) + CREEK_DIR.orthogonal() * side * rng.randf_range(3.6, 4.6))
	for k in range(2):
		spots.append(POND_AT + Vector2.from_angle(k * PI + 0.6) * (POND_R + 2.6))
	var crown_t := _crown_template(99, "hedgewillow", "spring", Vector3(2.2, 1.5, 2.2))
	var strand := CylinderMesh.new()
	strand.top_radius = 0.03
	strand.bottom_radius = 0.012
	strand.height = 1.0
	strand.radial_segments = 4
	strand.rings = 1
	for p: Vector2 in spots:
		var y := height(p.x, p.y)
		var tall := rng.randf_range(5.5, 7.0)
		if _near_trail(p, 4.4) or not eye_clear(Vector3(p.x, y + 2.0, p.y), 3.2):   # the curtain hangs ~2.6 m out
			continue
		var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		GardenProps.part(self, GardenProps.cyl(0.22, 0.38, tall, 9), GardenProps.mat("willowbark", Color("5a4c3a")), Vector3(p.x, y + tall * 0.5 - 0.2, p.y), Vector3(rad_to_deg(lean.z), 0, rad_to_deg(-lean.x)), 0.012)
		var top := Vector3(p.x, y + tall, p.y) + lean * tall
		var crown: Node3D = crown_t.duplicate()
		crown.visible = true
		crown.position = top
		add_child(crown)
		var hang := Node3D.new()                           # the curtain of strands, swaying as one
		hang.position = top
		add_child(hang)
		var items: Array = []
		for k in range(70):
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.2, 2.6)
			var len := rng.randf_range(2.0, tall - 1.2)
			var at := Vector3(cos(a) * r, -rng.randf_range(0.2, 0.9) - len * 0.5, sin(a) * r)
			items.append([Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))).scaled(Vector3(1.6, len, 1.6)), at), Color("9ab452").lerp(Color("6a8a3a"), rng.randf())])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = strand
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hang.add_child(mi)
		hang.set_meta("phase", rng.randf() * TAU)
		_willows_sway.append(hang)


## What lies about under the trees, off the trails: fallen logs with moss on them, old stumps, mossy boulders, and
## clusters of mushrooms.
func _forest_floor(rng: RandomNumberGenerator) -> void:
	var logs: Array = []
	var mossy: Array = []
	var stumps: Array = []
	var stones: Array = []
	var stems: Array = []
	var caps: Array = []
	var tries := 0
	var placed := 0
	while placed < 170 and tries < 3000:
		await Slicer.tick(self)
		tries += 1
		var p := Vector2(rng.randf_range(-56, 56), rng.randf_range(-106, 14))
		if _near_trail(p, 1.8) or not _near_trail(p, 14.0) or _keep_open(p, rng):
			continue
		placed += 1
		var y := height(p.x, p.y)
		var kind := rng.randf()
		if kind < 0.22:
			var len := rng.randf_range(2.0, 4.5)
			if _near_trail(p, 1.6 + len * 0.5):          # a log is long: all of it off the trail
				continue
			var r := rng.randf_range(0.18, 0.32)
			var yaw := rng.randf() * TAU
			var b := Basis.from_euler(Vector3(0, yaw, PI * 0.5))
			logs.append([Transform3D(b * Basis.from_scale(Vector3(r, len, r)), Vector3(p.x, y + r * 0.7, p.y)), Color("4a3a2c").lerp(Color("5a4a38"), rng.randf())])   # lying down (not stood on end)
			mossy.append([Transform3D(Basis.from_euler(Vector3(0, yaw + PI * 0.5, 0)) * Basis.from_scale(Vector3(r * 1.1, r * 0.45, len * 0.35)), Vector3(p.x, y + r * 1.5, p.y)), Color("4e6e30").lerp(Color("6a7a34"), rng.randf())])
		elif kind < 0.4:
			var r := rng.randf_range(0.25, 0.45)
			var h := rng.randf_range(0.25, 0.6)
			stumps.append([Transform3D(Basis().scaled(Vector3(r, h, r)), Vector3(p.x, y + h * 0.5 - 0.05, p.y)), Color("5a4634")])
			mossy.append([Transform3D(Basis().scaled(Vector3(r * 0.95, r * 0.25, r * 0.95)), Vector3(p.x, y + h, p.y)), Color("5a7a34")])
		elif kind < 0.65:
			var sz := rng.randf_range(0.4, 1.1)
			stones.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(sz, sz * 0.6, sz * 0.8)), Vector3(p.x, y - sz * 0.12, p.y)), Color("7e7a70").darkened(rng.randf() * 0.25)])
			mossy.append([Transform3D(Basis().scaled(Vector3(sz * 0.85, sz * 0.22, sz * 0.7)), Vector3(p.x, y + sz * 0.62, p.y)), Color("4e6e30")])
		else:
			var cap := Color("a8583a") if rng.randf() < 0.6 else (Color("d8c8a0") if rng.randf() < 0.6 else Color("c8402e"))
			for k in range(rng.randi_range(3, 7)):
				var q := p + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
				var qy := height(q.x, q.y)
				var h := rng.randf_range(0.05, 0.14)
				stems.append([Transform3D(Basis().scaled(Vector3(0.018, h, 0.018)), Vector3(q.x, qy + h * 0.5, q.y)), Color("e8dcc4")])
				var w := rng.randf_range(0.04, 0.08)
				caps.append([Transform3D(Basis().scaled(Vector3(w, w * 0.45, w)), Vector3(q.x, qy + h, q.y)), cap.darkened(rng.randf() * 0.15)])
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	_multimesh(cyl, logs)
	_multimesh(cyl, stumps)
	_multimesh(ball, mossy)
	_rock_multimesh(RockFactory.make({"role": "cobble", "size": Vector3.ONE, "seed": 733}), stones)
	_multimesh(cyl, stems)
	_multimesh(ball, caps)


## Where no tree grows: in the creek, in the ridge's view (a few deep below, their tops under you), round the old oak.
func _keep_open(p: Vector2, rng: RandomNumberGenerator) -> bool:
	if absf(_creek_lat(p)) < 3.4 and absf((p - CREEK_AT).dot(CREEK_DIR)) < 80.0:
		return true
	var rv := p - (NODES["ridge"]["at"] as Vector2)
	var s := rv.dot(VIEW_DIR)
	if s > 1.0 and absf(rv.dot(VIEW_DIR.orthogonal())) < 9.0 + s * 1.0:
		return s < 28.0 or rng.randf() < 0.75
	# A second, narrow window faces back over the footbridge toward home. It is below the lookout,
	# so the miniature lawn and white house can be picked out without turning the ravine into a lawn.
	var home_view := (HOME_DIR * 18.0 - NODES["ridge"]["at"]).normalized()
	var hs := rv.dot(home_view)
	if hs > 1.0 and hs < 28.0 and absf(rv.dot(home_view.orthogonal())) < 3.5 + hs * 0.16:
		return true
	if p.distance_to(POND_AT) < POND_R + 2.0 or p.distance_to(CELLAR_AT) < 6.5:
		return true
	var ov := p - (NODES["oak"]["at"] as Vector2)               # the oak's lookout: nothing right in front of it
	var os := ov.dot(OAK_VIEW)
	if os > 2.0 and os < 40.0 and absf(ov.dot(OAK_VIEW.orthogonal())) < 5.0 + os * 0.85:
		return true                                         # (the whole slope below: trees there would reach into the view)
	var pv := p - (NODES["pines"]["at"] as Vector2)             # the pine flats' long view: the same, all white pine
	var ps := pv.dot(PINES_VIEW)
	if ps > 5.0 and absf(pv.dot(PINES_VIEW.orthogonal())) < 3.0 + ps * 0.32:
		return rng.randf() < 0.72
	var fv := p - (NODES["fork"]["at"] as Vector2)              # the fork's long view: thinned trunks, layer on layer
	var fs := fv.dot(FORK_VIEW)
	if fs > 5.0 and absf(fv.dot(FORK_VIEW.orthogonal())) < 3.0 + fs * 0.32:
		return rng.randf() < 0.72
	return p.distance_to(_oak_at()) < 13.0


func _oak_at() -> Vector2:
	return (NODES["oak"]["at"] as Vector2) + Vector2(7.5, -3.5)     # beside the view north, framing it; clear of both trails


## Ferns and long grass along the trails and round the clearings: the garden's own tufts, darker and bigger.
func _undergrowth(rng: RandomNumberGenerator) -> void:
	var grass: GeometryInstance3D = garden.get_node_or_null("Grass")
	if grass == null:
		return
	var buf := PackedFloat32Array()
	var n := 0
	for e in _paths:
		await Slicer.tick(self)
		var pts: PackedVector3Array = e["pts"]
		for i in pts.size():
			for k in range(5):
				var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(1.0, 3.5)
				var p := Vector2(pts[i].x, pts[i].z) + off
				if _near_trail(p, 1.35):                     # beside the path, not on it (you'd walk through it)
					continue
				var s := rng.randf_range(0.6, 1.1)
				var b := Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)).scaled(Vector3(s * 1.3, s * rng.randf_range(0.9, 1.3), s * 1.3))
				var o := Vector3(p.x, height(p.x, p.y) - 0.05, p.y)
				var c := Color("6a8a4a").lerp(Color("8a8a50"), rng.randf() * 0.5)
				buf.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, c.r, c.g, c.b, 1.0, float(rng.randi_range(0, 7)), rng.randf() * TAU, 0.0, 0.0])
				n += 1
	var hollow: Vector2 = NODES["hollow"]["at"]
	for k in range(260):                                  # fern hollow: ferns everywhere but the path
		var p := hollow + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(3.0, 13.0)
		if _near_trail(p, 1.35):
			continue
		var s := rng.randf_range(0.9, 1.6)
		var b := Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)).scaled(Vector3(s * 1.5, s * rng.randf_range(1.0, 1.4), s * 1.5))
		var o := Vector3(p.x, height(p.x, p.y) - 0.05, p.y)
		var c := Color("4e7a3a").lerp(Color("6a8a44"), rng.randf())
		buf.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, c.r, c.g, c.b, 1.0, float(rng.randi_range(0, 7)), rng.randf() * TAU, 0.0, 0.0])
		n += 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = (grass as MultiMeshInstance3D).multimesh.mesh
	mm.instance_count = n
	mm.buffer = buf
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = grass.material_override
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## The pine flats: level ground under white pines, every bit of it orange needles - drifts of them, a few cones,
## the odd fallen branch, all lying flat on the ground (on the trail too: it's soft underfoot). Own random numbers.
func _pine_flats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var c: Vector2 = NODES["pines"]["at"]
	var cones: Array = []
	var sticks: Array = []
	for k in range(260):                                  # a few cones, the odd fallen branch, lying on the needles
		var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * PINES_R
		var y := height(p.x, p.y)
		var t := _nearest_trail(p)
		if t != Vector2.INF and t.distance_to(p) < 1.0:
			y = maxf(y, _trail_y(t) - 0.3) + 0.06
		cones.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, PI * 0.5)).scaled(Vector3(0.05, 0.09, 0.05)), Vector3(p.x, y + 0.05, p.y)), Color("6a4a2c")])
		if k % 13 == 0 and (t == Vector2.INF or t.distance_to(p) > 2.0):
			var len := rng.randf_range(0.8, 1.8)
			sticks.append([Transform3D(Basis.from_euler(Vector3(PI * 0.5, rng.randf() * TAU, 0)).scaled(Vector3(0.035, len, 0.035)), Vector3(p.x, y + 0.04, p.y)), Color("5a4430")])
	_needle_bed(c, rng)
	var cone := SphereMesh.new()
	cone.radius = 1.0
	cone.height = 2.0
	cone.radial_segments = 6
	cone.rings = 3
	var stick := CylinderMesh.new()
	stick.top_radius = 0.7
	stick.bottom_radius = 1.0
	stick.height = 1.0
	stick.radial_segments = 5
	stick.rings = 1
	_multimesh(cone, cones)
	_multimesh(stick, sticks)


## The needle bed: one tiling picture of fallen pine needles (thin crossing strokes in rust, orange and tan, drawn once
## here), laid on a disc that follows the ground (and the trail's dirt) over the flats. One draw call.
func _needle_bed(c: Vector2, rng: RandomNumberGenerator) -> void:
	const N := 256
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var colours := [Color("b4602c"), Color("c8803c"), Color("9a4c22"), Color("d6964c"), Color("7e4424"), Color("c06a30")]
	for k in range(1100):
		var p := Vector2(rng.randf() * N, rng.randf() * N)
		var a := rng.randf() * TAU
		var d := Vector2(cos(a), sin(a))
		var len := rng.randf_range(14.0, 30.0)
		var col: Color = colours[rng.randi() % colours.size()]
		for i in range(int(len)):
			var q := p + d * i
			var x := posmod(int(q.x), N)
			var y := posmod(int(q.y), N)
			img.set_pixel(x, y, col)
			if k % 3 == 0:                                    # some needles a touch thicker
				img.set_pixel(posmod(x + 1, N), y, col.darkened(0.15))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.7, 0.7, 0.7)                     # one picture per ~1.4 m
	m.roughness = 1.0
	m.metallic_specular = 0.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := PINES_R
	var step := 0.8
	var n := int(r * 2.0 / step)
	var grid: Array = []
	for j in range(n + 1):
		var row: Array = []
		for i in range(n + 1):
			var q := c + Vector2(-r + i * step, -r + j * step)
			var y := height(q.x, q.y)
			var t := _nearest_trail(q)
			if t != Vector2.INF and t.distance_to(q) < 1.0:
				y = maxf(y, _trail_y(t) - 0.3) + 0.06
			row.append(Vector3(q.x, y + 0.03, q.y))
		grid.append(row)
	for j in range(n):
		for i in range(n):
			var mid: Vector3 = grid[j][i]
			if Vector2(mid.x, mid.z).distance_to(c) > r:
				continue
			for v in [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j][i], grid[j + 1][i + 1], grid[j + 1][i]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var node := MeshInstance3D.new()
	node.name = "NeedleBed"
	node.mesh = st.commit()
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _brambles(at: Vector3, rng: RandomNumberGenerator) -> void:
	var bramble := GardenProps.mat("bramble", Color("2a3320"))
	for k in range(9):
		var p := at + Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))
		GardenProps.part(self, GardenProps.blob(Vector3(0.9, 0.7, 0.9) * snappedf(rng.randf_range(0.7, 1.3), 0.1), "pebble"), bramble, Vector3(p.x, height(p.x, p.z) + 0.3, p.z), Vector3(0, rng.randf_range(0, 360), 0), 0.012)
