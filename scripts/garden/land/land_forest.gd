extends "res://scripts/garden/land/land_terrain.gd"

## Distant land 2/3 - the forest: the near forest, the endless corridors, the dense forest and canopy bands.
##
## Forest to the horizon in bands. The nearer crowns are drawn with the woods' own leaf cards (_leafy_crowns,
## TreeFactory), so the forest past the woods is the same forest; past LEAFY_REACH they are lumps in the haze, which
## reads fine that far off. All of it is MultiMesh: a few draws for a whole horizon. Fixed seeds: the same forest
## every time.
##
## Part of the distant land layer chain (the full order is at the top of scripts/garden/distant_land.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var _forest_noise: FastNoiseLite
## Pines and broadleaf crowns over the hills: one multimesh, thinning to nothing where it's too far to tell.
func _forest(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1718
	var cones: Array = []
	var balls: Array = []
	var tries := 0
	while cones.size() + balls.size() < 5200 and tries < 30000:
		await Slicer.tick(self)
		tries += 1
		var a := rng.randf() * TAU
		var r := pow(rng.randf(), 0.7) * 300.0 + 12.0
		var x := cos(a) * r
		var z := sin(a) * r - 2.6
		var y := height(x, z)
		if y > 26.0 or Vector2(x, z).distance_to(LAKE) < 72.0 and Vector2(x, z).distance_to(LAKE) > LAKE_R - 6.0 and rng.randf() < 0.85:
			continue                                   # not on bare rock; few among the fields
		if Vector2(x, z).distance_to(LAKE) < LAKE_R:
			continue
		var s := rng.randf_range(0.5, 1.0) * (1.0 + r / 300.0)
		var col := Color("1e3624").lerp(Color("2e4a2c"), rng.randf())
		if rng.randf() < 0.5:
			cones.append([Transform3D(Basis().scaled(Vector3(s * 0.35, s * 1.1, s * 0.35)), Vector3(x, y + s * 0.5, z)), haze(col, r * SCALE)])
		else:
			var au := rng.randf() < 0.35
			balls.append([Transform3D(Basis().scaled(Vector3(s * 0.5, s * 0.42, s * 0.5)), Vector3(x, y + s * 0.3, z)), haze(Color("9a5a24").lerp(Color("b87a30"), rng.randf()) if au else col.lightened(0.08), r * SCALE)])
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 6
	ball.rings = 3
	for pair: Array in [[cone, cones], [ball, balls]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = pair[0]
		mm.instance_count = pair[1].size()
		for i in pair[1].size():
			mm.set_instance_transform(i, pair[1][i][0])
			mm.set_instance_color(i, pair[1][i][1])
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = m
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(node)
	await _dense_forest(world)
	await _near_forest(world)
	await _endless_woods(world)


func _endless_woods(world: Node3D) -> void:
	await _endless_band(world, FORK_SKY, FORK_DIR, 314159, false)
	await _endless_band(world, PINES_SKY, PINES_DIR, 271, true)


func _endless_band(world: Node3D, origin: Vector2, dir: Vector2, seed: int, all_pine: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var trunks: Array = []
	var crowns: Array = []
	var firs: Array = []
	var leafy: Array = []
	var s := 3.4
	while s < 380.0:
		await Slicer.tick(self)
		var step := 0.42 + s * 0.022
		var half := 6.0 + s * 0.42
		var lat := -half
		while lat < half:
			var p := origin + dir * (s + rng.randf_range(-0.5, 0.5) * step) + dir.orthogonal() * (lat + rng.randf_range(-0.5, 0.5) * step)
			lat += step
			var mx := p.x * SCALE
			var mz := p.y * SCALE
			if mx > -60.0 and mx < 62.0 and mz > -110.0 and mz < 26.0:
				continue                                  # the woods' own trees
			if rng.randf() < 0.12:
				continue
			var y := height(p.x, p.y)
			var metres := (p - origin).length() * SCALE
			var tall := rng.randf_range(2.4, 3.3)             # old growth: tall trunks, the canopy far overhead
			var girth := (0.06 + step * 0.06) * rng.randf_range(0.8, 1.3)   # far trunks a touch thicker: they still read
			trunks.append([Transform3D(Basis().scaled(Vector3(girth, tall, girth)), Vector3(p.x, y + tall * 0.5 - 0.05, p.y)), haze(Color("3e3026").lerp(Color("54443a"), rng.randf()), metres)])
			if all_pine or rng.randf() < 0.3:             # a hemlock or a pine among the hardwoods (all white pine past the flats)
				var w := rng.randf_range(0.4, 0.6) + step * 0.2
				firs.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(w, tall * 0.7, w)), Vector3(p.x, y + tall * 0.68, p.y)), haze(Color("1e3a2a").lerp(Color("2a4a32"), rng.randf()), metres)])
			else:                                         # the canopy: crowns overlapping into one ceiling
				var w := rng.randf_range(0.8, 1.2) + step * 0.5
				var c := Color("3a5a30").lerp(Color("a0602c"), clampf(rng.randf() * 1.4 - 0.4, 0.0, 1.0)).lerp(Color("2c4a2a"), 0.35)
				var crown := [Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(w, w * 0.45, w)), Vector3(p.x, y + tall * 0.95, p.y)), haze(c, metres)]
				if s < LEAFY_REACH:                       # near enough to make out: the woods' leaf cards (see _leafy_crowns)
					leafy.append(crown)
				else:
					crowns.append(crown)
		s += step
	_forest_multimesh(world, _forest_trunk_mesh(), trunks, "EndlessTrunks")
	_forest_multimesh(world, _forest_cluster_mesh(0), crowns, "EndlessCanopy")
	print("distant land endless woods: %d leaf cards" % _leafy_crowns(world, leafy, "EndlessCrowns"))
	_forest_multimesh(world, _forest_pine_mesh(true if all_pine else false), firs, "EndlessFirs")


## How far out (in land units from where a band starts) crowns are drawn with leaf cards rather than a lump.
const LEAFY_REACH := 60.0


## Crowns as the woods' own leaf cards (TreeFactory.far_crown: a few big crown leaves each), so the land's nearer forest
## is the same forest as the woods. A lumpy flat-coloured mesh this near read as a slab hanging in the woods' sky.
## items: [Transform3D (the crown's size and place), Color (its hazed tint)]. Returns the number of leaf cards.
func _leafy_crowns(world: Node3D, items: Array, label: String, kind := "oak") -> int:
	var leaves := {}
	var n := 0
	for it: Array in items:
		var xf: Transform3D = it[0]
		if not toy_clear(Vector2(xf.origin.x, xf.origin.z)):
			continue
		var tint: Color = it[1]
		var palette: String = "gold" if kind == "birch" else ("green" if tint.g > tint.r else ("crimson" if kind == "maple" else "autumn"))
		var radii: Vector3 = TreeFactory.KINDS[kind]["radii"]
		var fit := xf * Transform3D(Basis().scaled(Vector3.ONE / radii.x), Vector3.ZERO)   # the cluster's metres to this crown
		var sheet: String = TreeFactory.KINDS[kind]["sheet"]
		if not leaves.has(sheet):
			leaves[sheet] = []
		(leaves[sheet] as Array).append_array(TreeFactory.far_crown(kind, palette, n % TreeFactory.VARIANTS, fit, tint))
		n += 1
	var cards := 0
	for node in TreeFactory.leaf_nodes(leaves):
		node.name = "%s_%s" % [label, node.name]
		(node as MultiMeshInstance3D).multimesh.custom_aabb = AABB(Vector3(-470.0, -20.0, -470.0), Vector3(940.0, 100.0, 940.0))
		cards += (node as MultiMeshInstance3D).multimesh.instance_count
		world.add_child(node)
	return cards


## Right past the edge of the woods: the forest goes on, tree by tree - trunks you look between, crowns overlapping,
## stands of pine, drifts of autumn maple, birch on the hill, now and then a dead snag, a few clearings. Clustered by
## noise (never a grid), densest by the woods, thinning into the canopy layer beyond.
func _near_forest(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 160461
	var stand := FastNoiseLite.new()                  # what grows where: pine stands, maple drifts, birch on the high ground
	stand.seed = 160462
	stand.frequency = 0.06
	var gaps := FastNoiseLite.new()
	gaps.seed = 160463
	gaps.frequency = 0.09
	var crowns := [[], [], [], []]                    # broadleaf A, broadleaf B, birch, pine
	var trunks: Array = []
	var snags: Array = []
	var autumn := [Color("a8462a"), Color("c0602c"), Color("cf8a34"), Color("8a3a24"), Color("b07a2e")]
	var green := [Color("2e5232"), Color("3a6038"), Color("4a6a3c")]
	var pines := [Color("1c3e2c"), Color("244a32"), Color("2c5438")]
	var step := 1.25
	var reach := 44.0
	var n := int(reach / step)
	for ix in range(-n, n + 1):
		await Slicer.tick(self)
		for iz in range(-n, n + 1):
			var p := Vector2(ix * step + rng.randf_range(-0.5, 0.5) * step, iz * step - 2.6 + rng.randf_range(-0.5, 0.5) * step)
			var mx := p.x * SCALE
			var mz := p.y * SCALE
			if mx > -60.0 and mx < 62.0 and mz > -110.0 and mz < 26.0:
				continue                              # the woods themselves (their own trees)
			var r := p.length()
			if r > reach:
				continue
			var g := gaps.get_noise_2d(p.x, p.y)
			if g < -0.42 or rng.randf() > lerpf(0.92, 0.55, smoothstep(10.0, reach, r)) * smoothstep(-0.42, -0.2, g):
				continue                              # a clearing, or just a gap
			var y := height(p.x, p.y)
			if y > 24.0:
				continue
			var kind := stand.get_noise_2d(p.x, p.y)
			var tall := rng.randf_range(1.0, 1.7)
			var metres := r * SCALE
			var bark := haze(Color("4a3a2c").darkened(rng.randf() * 0.2), metres)
			if rng.randf() < 0.025:                   # a dead snag: grey, bare, tall
				snags.append([Transform3D(Basis().scaled(Vector3(0.05, tall * 1.1, 0.05)), Vector3(p.x, y + tall * 0.5, p.y)), haze(Color("8a8478"), metres)])
				continue
			if r < 16.0:                              # trunks only near: further off it's all canopy
				trunks.append([Transform3D(Basis().scaled(Vector3(0.045, tall * 0.62, 0.045)), Vector3(p.x, y + tall * 0.3, p.y)), bark])
			var yaw := rng.randf() * TAU
			var full := lerpf(1.0, 1.5, smoothstep(10.0, reach, r))   # crowns widen with distance till they touch
			if kind > 0.18:                           # a pine stand
				var w := rng.randf_range(0.38, 0.56) * full
				crowns[3].append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(w, tall * 0.95, w)), Vector3(p.x, y + tall * 0.62, p.y)), haze(pines[rng.randi_range(0, 2)], metres)])
			elif kind < -0.3 and y > 0.5:             # birch on the higher ground
				var w := rng.randf_range(0.32, 0.46) * full
				crowns[2].append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(w, w * 1.6, w)), Vector3(p.x, y + tall * 0.78, p.y)), haze(Color("c8a43a").lerp(Color("a89a4a"), rng.randf()), metres)])
			else:                                     # maple and oak: autumn drifts, some still green
				var w := rng.randf_range(0.5, 0.8) * full
				var c: Color = autumn[rng.randi_range(0, 4)] if absf(stand.get_noise_2d(p.x * 2.0 + 50.0, p.y * 2.0)) > 0.12 else green[rng.randi_range(0, 2)]
				crowns[rng.randi_range(0, 1)].append([Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.1, 0.1), yaw, 0)).scaled(Vector3(w, w * 0.7, w)), Vector3(p.x, y + tall * 0.72, p.y)), haze(c, metres)])
	# broadleaf and birch crowns: the woods' own leaf cards, so the forest past the woods is the same forest
	var cards := _leafy_crowns(world, crowns[0], "NearCrownsA", "oak") + _leafy_crowns(world, crowns[1], "NearCrownsB", "maple") \
		+ _leafy_crowns(world, crowns[2], "NearCrownsBirch", "birch")
	_forest_multimesh(world, _forest_pine_mesh(false), crowns[3], "NearPine")
	_forest_multimesh(world, _forest_trunk_mesh(), trunks, "NearTrunks")
	_forest_multimesh(world, _forest_trunk_mesh(), snags, "NearSnags")
	print("distant land near forest: %d trees, %d snags, %d leaf cards" % [trunks.size(), snags.size(), cards])


## The old cone-and-ball layer is deliberately kept as a far-horizon texture. This second layer is the woodland:
## jittered cells, noise-shaped clearings and several silhouette families make the miniature read as a living forest
## instead of a field of repeated decorations. It is static, has no collision or animation, and is six instanced draws.
func _dense_forest(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 272001
	var broad_a: Array = []
	var broad_b: Array = []
	var birch: Array = []
	var pine: Array = []
	var cedar: Array = []
	var trunks: Array = []
	var understory: Array = []
	var deadwood: Array = []
	var broad_palette := [Color("2a5036"), Color("386640"), Color("47744a"), Color("5d7c4f"), Color("806b39"), Color("9a7138")]
	var pine_palette := [Color("1f4935"), Color("2b5b41"), Color("386b48"), Color("487752")]
	var birch_palette := [Color("52704a"), Color("6d8250"), Color("87905a"), Color("9a7e49")]
	var trunk_palette := [Color("4a3a2b"), Color("57432f"), Color("624e38"), Color("6a573d")]
	var cell := 7.2
	var cells := 64
	for ix in range(-cells, cells + 1):
		await Slicer.tick(self)
		for iz in range(-cells, cells + 1):
			var p := Vector2((float(ix) + rng.randf_range(-0.46, 0.46)) * cell, (float(iz) + rng.randf_range(-0.46, 0.46)) * cell - 2.6)
			var radius := p.length()
			if radius < 6.5 or radius > 455.0:
				continue
			var y := height(p.x, p.y)
			if y > 28.0:
				continue
			var lake_distance := p.distance_to(LAKE)
			if lake_distance < LAKE_R + 3.0:
				continue
			var density := lerpf(0.82, 0.38, smoothstep(25.0, 430.0, radius))
			var cluster := (_forest_noise.get_noise_2d(p.x, p.y) + 1.0) * 0.5
			var clearing := smoothstep(0.08, 0.56, cluster)
			density *= lerpf(0.38, 1.0, clearing)
			# Keep the ridge's named valley open, but let the forest close in again at its far rim.
			var rv := p - Vector2(22.0, -44.0)
			var valley_forward := rv.dot(Vector2(0.89, -0.456))
			var valley_side := absf(rv.dot(Vector2(0.456, 0.89)))
			var valley_window := smoothstep(18.0, 42.0, valley_side) * smoothstep(18.0, 185.0, valley_forward)
			density *= lerpf(1.0, 0.22, valley_window)
			# The two woodland compositions look into the north bowl: fuller here, with no artificial ring boundary.
			var north_bias := maxf(0.0, Vector2(0.0, -1.0).dot(p.normalized()))
			density *= 1.0 + north_bias * 0.16
			if rng.randf() > density:
				continue
			var local_p := p + Vector2(rng.randf_range(-2.4, 2.4), rng.randf_range(-2.4, 2.4))
			var local_y := height(local_p.x, local_p.y)
			var kind_roll := rng.randf()
			var tree_height := rng.randf_range(1.15, 1.85) * lerpf(1.0, 0.8, smoothstep(180.0, 440.0, radius))
			var yaw := rng.randf() * TAU
			var bark: Color = trunk_palette[rng.randi_range(0, trunk_palette.size() - 1)]
			# The trunk is useful in the near and middle layers; far forest is carried by its canopy silhouette.
			if radius < 22.0:                          # (further off, a trunk under a crown just reads as a lollipop)
				var trunk_r := rng.randf_range(0.07, 0.13) * (1.15 if kind_roll < 0.56 else 0.8)
				trunks.append([Transform3D(Basis().scaled(Vector3(trunk_r, tree_height, trunk_r)), Vector3(local_p.x, local_y + tree_height * 0.5, local_p.y)), bark])
			if kind_roll < 0.48:
				var crown := broad_a if rng.randf() < 0.58 else broad_b
				var crown_w := rng.randf_range(0.72, 1.18) * lerpf(1.0, 0.82, smoothstep(150.0, 420.0, radius))
				var crown_h := rng.randf_range(0.62, 1.02)
				var crown_colour: Color = broad_palette[rng.randi_range(0, broad_palette.size() - 1)]
				crown.append([Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), yaw, rng.randf_range(-0.06, 0.06))).scaled(Vector3(crown_w, crown_h, crown_w * rng.randf_range(0.86, 1.08))), Vector3(local_p.x, local_y + tree_height * 0.82, local_p.y)), _forest_tint(crown_colour, radius)])
			elif kind_roll < 0.67:
				var crown_w := rng.randf_range(0.5, 0.85) * lerpf(1.0, 0.8, smoothstep(150.0, 420.0, radius))
				var crown_colour: Color = birch_palette[rng.randi_range(0, birch_palette.size() - 1)]
				birch.append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(crown_w, rng.randf_range(0.82, 1.24), crown_w * 0.82)), Vector3(local_p.x, local_y + tree_height * 0.82, local_p.y)), _forest_tint(crown_colour, radius)])
			elif kind_roll < 0.88:
				var width := rng.randf_range(0.5, 0.86)
				pine.append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(width, tree_height * rng.randf_range(1.05, 1.3), width)), Vector3(local_p.x, local_y + tree_height * 0.66, local_p.y)), _forest_tint(pine_palette[rng.randi_range(0, pine_palette.size() - 1)], radius)])
			else:
				var width := rng.randf_range(0.42, 0.7)
				cedar.append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(width, tree_height * rng.randf_range(0.9, 1.2), width)), Vector3(local_p.x, local_y + tree_height * 0.62, local_p.y)), _forest_tint(pine_palette[rng.randi_range(0, pine_palette.size() - 1)].darkened(0.08), radius)])
			if radius < 135.0 and rng.randf() < 0.62:
				var shrub_p := local_p + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
				var shrub_colour: Color = broad_palette[rng.randi_range(0, 3)].darkened(0.16)
				understory.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(rng.randf_range(0.22, 0.46), rng.randf_range(0.18, 0.34), rng.randf_range(0.22, 0.46))), Vector3(shrub_p.x, height(shrub_p.x, shrub_p.y) + 0.18, shrub_p.y)), shrub_colour])
			if radius < 180.0 and rng.randf() < 0.035:
				var log_p := local_p + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
				deadwood.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(rng.randf_range(0.65, 1.8), rng.randf_range(0.07, 0.13), rng.randf_range(0.07, 0.13))), Vector3(log_p.x, height(log_p.x, log_p.y) + 0.07, log_p.y)), Color("342e27")])
	_forest_multimesh(world, _forest_cluster_mesh(0), broad_a, "BroadleafCanopyA")
	_forest_multimesh(world, _forest_cluster_mesh(1), broad_b, "BroadleafCanopyB")
	_forest_multimesh(world, _forest_cluster_mesh(2), birch, "BirchCanopy")
	_forest_multimesh(world, _forest_pine_mesh(false), pine, "WhitePineCanopy")
	_forest_multimesh(world, _forest_pine_mesh(true), cedar, "CedarCanopy")
	_forest_multimesh(world, _forest_trunk_mesh(), trunks, "DistantTrunks")
	_forest_multimesh(world, _forest_cluster_mesh(3), understory, "DistantUnderstory")
	_forest_multimesh(world, _forest_deadwood_mesh(), deadwood, "DistantDeadwood")
	await _forest_canopy_shelves(world)


## A few large canopy groups establish the depth bands the individual trees cannot express at thumbnail scale. They
## overlap the tree field, follow the miniature terrain, and leave the ridge's open valley as a deliberate negative
## space. The result is a forest edge that dissolves into woodland rather than a circular wall around the level.
func _forest_canopy_shelves(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 272002
	var shelf_a: Array = []
	var shelf_b: Array = []
	var vista_a: Array = []
	var vista_b: Array = []
	# (no shelves nearer than 62 units: the near forest's own trees cover that distance, and a shelf that close reads
	# as a flat slab hanging in the woods' sky - the pond and the ridge showed it)
	var bands := [[62.0, 30], [112.0, 38], [190.0, 46]]
	for band_i: int in bands.size():
		await Slicer.tick(self)
		var band: Array = bands[band_i]
		var radius: float = band[0]
		var count: int = band[1]
		for i in count:
			var angle := (float(i) / float(count)) * TAU + rng.randf_range(-0.11, 0.11)
			var p := Vector2(cos(angle), sin(angle)) * (radius + rng.randf_range(-radius * 0.16, radius * 0.16))
			if p.distance_to(LAKE) < LAKE_R + 7.0:
				continue
			var rv := p - Vector2(22.0, -44.0)
			var forward := rv.dot(Vector2(0.89, -0.456))
			var side := absf(rv.dot(Vector2(0.456, 0.89)))
			if forward > 15.0 and side < 21.0 + forward * 0.24 and rng.randf() < 0.82:
				continue
			var y := height(p.x, p.y)
			if y > 28.0:
				continue
			var far := float(band_i + 2) / 4.0              # as when the list began with two nearer bands: same sizes
			var width := lerpf(1.25, 5.6, far) * rng.randf_range(0.78, 1.24)
			var crown_height := lerpf(0.82, 1.85, far) * rng.randf_range(0.78, 1.18)
			var crown_y := y + lerpf(0.72, 1.28, far) + rng.randf_range(-0.16, 0.22)
			var tint := Color("2f5940").lerp(Color("64806a"), rng.randf() * 0.75)
			if rng.randf() < 0.34:
				tint = tint.lerp(Color("72522b"), rng.randf_range(0.12, 0.34))
			var item := [Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), rng.randf() * TAU, rng.randf_range(-0.04, 0.04))).scaled(Vector3(width, crown_height, width * rng.randf_range(0.78, 1.18))), Vector3(p.x, crown_y, p.y)), _forest_tint(tint, radius)]
			(shelf_a if (i + band_i) % 2 == 0 else shelf_b).append(item)
	# Two overlapping north-facing lanes are intentional landmarks: the oak's rolling canopy sea and the fork's
	# view through trunks. They are high enough to meet the horizon, but sparse enough to preserve glimpses of haze.
	var lanes := [-1.43, -1.18, -0.92]
	var depths := [50.0, 92.0, 158.0]                  # (not nearer: see the bands above)
	for lane_i in lanes.size():
		for depth_i in depths.size():
			var radius: float = depths[depth_i]
			var count := 6 + (depth_i + 2) * 3
			for i in count:
				var angle: float = lanes[lane_i] + lerpf(-0.24, 0.24, float(i) / maxf(1.0, count - 1.0)) + rng.randf_range(-0.055, 0.055)
				var p := Vector2(cos(angle), sin(angle)) * (radius + rng.randf_range(-radius * 0.12, radius * 0.12))
				var y := height(p.x, p.y)
				if y > 28.0:
					continue
				var far := float(depth_i + 2) / 4.0
				var width := lerpf(1.2, 4.8, far) * rng.randf_range(0.82, 1.2)
				var crown_height := lerpf(0.92, 1.68, far) * rng.randf_range(0.8, 1.16)
				var crown_y := y + lerpf(0.9, 1.48, far) + rng.randf_range(-0.12, 0.2)
				var tint := Color("1d3b2b").lerp(Color("496044"), rng.randf() * 0.7)
				var item := [Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.04, 0.04))).scaled(Vector3(width, crown_height, width * rng.randf_range(0.8, 1.14))), Vector3(p.x, crown_y, p.y)), _forest_tint(tint, radius)]
				(vista_a if (i + depth_i + lane_i) % 2 == 0 else vista_b).append(item)
	_forest_multimesh(world, _forest_cluster_mesh(0), shelf_a, "CanopyShelfA")
	_forest_multimesh(world, _forest_cluster_mesh(1), shelf_b, "CanopyShelfB")
	_forest_multimesh(world, _forest_cluster_mesh(0), vista_a, "OldOakForestVista")
	_forest_multimesh(world, _forest_cluster_mesh(1), vista_b, "DeepForestVista")


func _forest_tint(colour: Color, radius: float) -> Color:
	return haze(colour, radius * SCALE)


func _forest_cluster_mesh(variant: int) -> Mesh:
	var source := SphereMesh.new()                   # a few pixels across: as few triangles as still read round
	source.radius = 1.0
	source.height = 2.0
	source.radial_segments = 5
	source.rings = 2
	var parts: Array
	match variant:
		0:
			parts = [[Vector3(0, 0, 0), Vector3(0.9, 0.62, 0.9)], [Vector3(-0.78, -0.02, 0.08), Vector3(0.68, 0.5, 0.72)], [Vector3(0.72, 0.08, -0.1), Vector3(0.72, 0.54, 0.66)]]
		1:
			parts = [[Vector3(0, 0.08, 0), Vector3(0.72, 0.82, 0.74)], [Vector3(-0.55, -0.12, 0.12), Vector3(0.58, 0.44, 0.58)], [Vector3(0.5, 0.0, -0.16), Vector3(0.46, 0.56, 0.5)], [Vector3(0.05, 0.42, 0.05), Vector3(0.42, 0.38, 0.42)]]
		2:
			parts = [[Vector3(0, 0.26, 0), Vector3(0.5, 0.48, 0.5)], [Vector3(-0.28, -0.08, 0.04), Vector3(0.42, 0.36, 0.38)], [Vector3(0.31, -0.08, -0.08), Vector3(0.4, 0.34, 0.36)]]
		_:
			parts = [[Vector3(0, 0, 0), Vector3(1.0, 0.46, 0.86)], [Vector3(-0.38, 0.02, 0.16), Vector3(0.56, 0.32, 0.5)], [Vector3(0.43, -0.02, -0.12), Vector3(0.52, 0.3, 0.48)]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		st.append_from(source, 0, Transform3D(Basis().scaled(part[1]), part[0]))
	st.generate_normals()
	return st.commit()


func _forest_pine_mesh(narrow: bool) -> Mesh:
	var source := CylinderMesh.new()
	source.top_radius = 0.0
	source.bottom_radius = 1.0
	source.height = 1.0
	source.radial_segments = 6
	source.rings = 0                                  # (the default 4 rings and caps were triangles nobody sees)
	source.cap_top = false
	source.cap_bottom = false
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := 4 if narrow else 5
	for i in range(tiers):
		var f := float(i) / float(tiers - 1)
		var width := lerpf(0.92, 0.25, f) if narrow else lerpf(1.05, 0.3, f)
		var y := lerpf(-0.34, 0.38, f)
		st.append_from(source, 0, Transform3D(Basis().scaled(Vector3(width, 0.42 if narrow else 0.38, width)), Vector3(0, y, 0)))
	st.generate_normals()
	return st.commit()


func _forest_trunk_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.38
	mesh.bottom_radius = 0.55
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 0
	mesh.cap_top = false
	mesh.cap_bottom = false
	return mesh


func _forest_deadwood_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	return mesh


func _forest_multimesh(world: Node3D, mesh: Mesh, items: Array, label: String) -> void:
	items = items.filter(func(it: Array) -> bool:
		var o: Vector3 = (it[0] as Transform3D).origin
		return toy_clear(Vector2(o.x, o.z)))
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	mm.custom_aabb = AABB(Vector3(-470.0, -20.0, -470.0), Vector3(940.0, 100.0, 940.0))
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)
