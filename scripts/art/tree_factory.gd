class_name TreeFactory
extends RefCounted

## Every tree in the woods, made one way.
##
## A tree is a trunk with a few limbs (low-poly tapered tubes) and leafy clusters at the limb tips. A cluster is grown
## by the same foliage system as the hedgepets and the garden's bushes (FoliageBuilder): leaf cards from a glyph
## sheet, coloured from a palette. Near or far, a tree is the same tree: there is no second "far" style to switch to.
##
## Why one cluster density everywhere: earlier versions gave leaves only to trees by the trail and showed the rest as
## dark lumps, and turned leaves off past 36 m. That is what made the woods look like two different worlds glued
## together, and the swap popped as you walked. Now every tree has the same leaf cards (fewer, bigger leaves than a
## hedgepet: LEAF_SIZE, DENSITY), and the far ones simply fade into the haze.
##
## Budget (what to watch when tuning): leaf cards are 2 triangles each and are by far the biggest pool. The tree lab
## (tools/art/tree_lab.tscn) prints cards and triangles per tree; the woods print their totals when built.
##
## Determinism: each tree takes ONE number from the woods' build RNG and seeds its own RNG with it, so changing a tree's
## recipe never moves anything else in the woods. Clusters are a small fixed set per kind and palette (VARIANTS), made
## once, shared by every tree: the whole wood is a handful of cluster shapes.

const SPRIG := 8                             # leaves per sprig (a hedgepet's are 16)
## Detail by distance (the leaf shader): full detail to LOD_NEAR metres, only the crown leaves (grown bigger) by LOD_FAR.
const LOD_NEAR := 14.0
const LOD_FAR := 48.0
const VARIANTS := 3                          # cluster shapes per kind and palette
const LIMB_SIDES := 5                        # sides of a trunk or limb tube

## The four New England trees. sheet: leaf glyph sheet (assets/sprites/<sheet>.png); palettes: SpeciesBuilder palettes;
## radii: one cluster's size before the tree scales it; density, leaf: how many sprigs and how big their leaves;
## core: an inner shade mass, as a fraction of radii. All 0 now: a core shows as a slab wherever the leaves thin
## (near the camera, where leaves fade so they never fill your face, and far off), so the leaves carry the crown alone.
## The support stays for a tree that needs one.
const KINDS := {
	"oak": {"sheet": "hedgeoak", "palettes": ["autumn", "green"], "bark": Color("4a3c30"), "build": "broad",
		"radii": Vector3(1.7, 1.3, 1.7), "density": 0.17, "leaf": 1.4, "core": 0.0},
	"maple": {"sheet": "hedgemaple", "palettes": ["crimson", "autumn"], "bark": Color("54463a"), "build": "broad",
		"radii": Vector3(1.6, 1.3, 1.6), "density": 0.17, "leaf": 1.4, "core": 0.0},
	"birch": {"sheet": "hedgeboxwood", "palettes": ["gold"], "bark": Color("e6e0d4"), "build": "slim",
		"radii": Vector3(1.1, 1.0, 1.1), "density": 0.24, "leaf": 1.0, "core": 0.0},
	"pine": {"sheet": "hedgepine", "palettes": ["pine"], "bark": Color("4e3c2e"), "build": "pine",
		"radii": Vector3(1.7, 0.45, 1.7), "density": 0.32, "leaf": 1.7, "core": 0.0},
	# the willow's crown only: its trunk and hanging strands are built by the woods (woods_scenery._willows)
	"willow": {"sheet": "hedgewillow", "palettes": ["spring"], "bark": Color("5a4c3a"), "build": "crown",
		"radii": Vector3(2.2, 1.5, 2.2), "density": 0.26, "leaf": 1.1, "core": 0.0},
}

static var _clusters := {}                   # "kind/palette/variant" -> cluster dictionary (see cluster())
static var _leaf_mats := {}
static var _quad: QuadMesh


## A leafy cluster, made once and shared: {items: [[Transform3D, Color, Color]], sheet, core: Mesh, core_color}.
## items are leaf cards around the origin, in the format the leaf shader reads (colour + custom data per card).
static func cluster(kind: String, palette: String, variant: int) -> Dictionary:
	var key := "%s/%s/%d" % [kind, palette, variant]
	if _clusters.has(key):
		return _clusters[key]
	var k: Dictionary = KINDS[kind]
	var radii: Vector3 = k["radii"]
	var region := {"center": Vector3.ZERO, "radii": radii, "parent": "", "foliage": true, "density": k["density"], "leaf_scale": 1.0,
		"max_displacement": 0.2, "growth_up": 0.4, "material": "foliage", "shape": {"exponent": 2.0}, "leaves_per_cluster": SPRIG}
	var p := CharacterArtProfile.new()
	p.seed = 7300 + variant
	p.leaf_size = k["leaf"]
	p.growth = 1.0
	p.flowering = 0.0
	p.leaves_per_cluster = 16
	p.palette = SpeciesBuilder.palette_of(palette)
	p.anchors = {}
	p.protected_zones = {}
	p.regions = {"BODY": region, "HEAD": {"center": Vector3(0, -100, 0), "radii": Vector3(0.1, 0.1, 0.1), "parent": "", "foliage": false}}
	var built := FoliageBuilder.build(p, "BODY", Vector3(0, -100, 0), Vector3(0.5, -0.8, 0.3).normalized())
	# the core: a small, coarse ellipsoid (5 rings x 8 segments: 80 triangles, not the ~900 the old crowns used)
	# coloured between the palette's shade and its leaves, so a gap in the crown reads as leafy shade
	var core_region := {"center": Vector3.ZERO, "radii": radii * maxf(k["core"], 0.01), "shape": {"exponent": 2.0}}
	var shade := Color(SpeciesBuilder.PALETTES[palette][6])
	var leaf := Color(SpeciesBuilder.PALETTES[palette][2])
	var c := {"items": built["items"], "sheet": k["sheet"], "core": HedgeAnatomy.build_mesh(core_region, 5, 8) if k["core"] > 0.0 else null,
		"core_color": shade.darkened(0.25)}
	_clusters[key] = c
	return c


## How a tree of this kind looks at p, as a plan: {palette, bark, limbs: [[a, b, ra, rb]], clusters: [[variant, at, scale, yaw]]}.
## Pure: nothing is built, so the woods can test the plan against the trails first (and skip a tree in the way).
static func plan(kind: String, p: Vector3, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var k: Dictionary = KINDS[kind]
	var palettes: Array = k["palettes"]
	var out := {"kind": kind, "palette": palettes[rng.randi_range(0, palettes.size() - 1)],
		"bark": (k["bark"] as Color).darkened(rng.randf() * 0.12), "limbs": [], "clusters": []}
	var limbs: Array = out["limbs"]
	var clusters: Array = out["clusters"]
	var s := rng.randf_range(0.85, 1.2)
	var yaw := rng.randf() * TAU
	var lean := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
	match k["build"]:
		"broad":                                     # oak, maple: a stout trunk forking into 3-4 limbs, a rounded crown
			var fork := p + (Vector3.UP * 3.4 + lean * 2.0) * s
			limbs.append([p - Vector3(0, 0.3, 0), fork, 0.34 * s, 0.24 * s])
			var top := fork + (Vector3.UP * 3.2 + lean) * s
			limbs.append([fork, top, 0.22 * s, 0.1 * s])
			var n := rng.randi_range(3, 4)
			for b in range(n):
				var a := yaw + b * TAU / n + rng.randf_range(-0.35, 0.35)
				var out_dir := Vector3(cos(a), 0, sin(a))
				var from := fork + Vector3.UP * rng.randf_range(0.0, 1.2) * s
				var tip := from + (out_dir * rng.randf_range(1.8, 2.5) + Vector3.UP * rng.randf_range(1.3, 2.1)) * s
				limbs.append([from, tip, 0.14 * s, 0.06 * s])
				clusters.append([rng.randi_range(0, VARIANTS - 1), tip + Vector3.UP * 0.2 * s, Vector3.ONE * rng.randf_range(0.95, 1.15) * s, rng.randf() * TAU])
			clusters.append([rng.randi_range(0, VARIANTS - 1), top + Vector3.UP * 0.3 * s, Vector3.ONE * 1.2 * s, rng.randf() * TAU])
		"slim":                                      # birch: a slim white trunk, small clusters stacked up it
			var top := p + (Vector3.UP * 8.5 + lean * 4.0) * s
			limbs.append([p - Vector3(0, 0.3, 0), top, 0.16 * s, 0.06 * s])
			for b in range(4):
				var at := p.lerp(top, lerpf(0.45, 0.97, b / 3.0))
				var a := yaw + b * 2.3
				var off := Vector3(cos(a), 0, sin(a)) * 0.6 * s
				limbs.append([at - off * 0.2, at + off, 0.05 * s, 0.03 * s])
				clusters.append([b % VARIANTS, at + off, Vector3.ONE * lerpf(0.85, 0.6, b / 3.0) * s, rng.randf() * TAU])
		"pine":                                      # white pine: tall and straight, flat tiers of needles thinning up top
			var tall := rng.randf_range(12.0, 15.0)
			var top := p + (Vector3.UP * tall + lean * 3.0) * s
			limbs.append([p - Vector3(0, 0.3, 0), top, 0.28 * s, 0.05 * s])
			var tiers := 6
			for t in range(tiers):
				var f := lerpf(0.32, 0.97, float(t) / (tiers - 1))
				var at := p.lerp(top, f)
				var w := lerpf(1.35, 0.45, f)                        # a tier's spread, narrowing toward the top
				clusters.append([t % VARIANTS, at, Vector3(w, 1.0, w) * s, yaw + t * 1.3])
	return out


## The leaf material for a sheet (the hedgepets' leaf shader). Shared: one per sheet in the whole game.
static func leaf_material(sheet: String) -> ShaderMaterial:
	if _leaf_mats.has(sheet):
		return _leaf_mats[sheet]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/leaf.gdshader")
	m.set_shader_parameter("leaf_sheet", Assets.mipmapped("res://assets/sprites/%s.png" % sheet))
	m.set_shader_parameter("leaf_normals", Assets.mipmapped("res://assets/sprites/%s_n.png" % sheet))
	m.set_shader_parameter("interior_ink", 0.2)
	m.set_shader_parameter("silhouette_ink", 0.5)
	m.set_shader_parameter("near_fade", GardenProps.NEAR_FADE)
	m.set_shader_parameter("distance_lod_near", LOD_NEAR)
	m.set_shader_parameter("distance_lod_far", LOD_FAR)
	_leaf_mats[sheet] = m
	return m


## The quality tier ("low", "medium", "high"): how soon far trees thin to their crown leaves. Applies to every tree.
static func set_detail(tier: String) -> void:
	var near := LOD_NEAR * (0.55 if tier == "low" else 1.0 if tier == "medium" else 1.5)
	var far := LOD_FAR * (0.55 if tier == "low" else 1.0 if tier == "medium" else 1.5)
	for m: ShaderMaterial in _leaf_mats.values():
		m.set_shader_parameter("distance_lod_near", near)
		m.set_shader_parameter("distance_lod_far", far)


## The card every leaf is drawn on (its base at the stem).
static func leaf_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.center_offset = Vector3(0, 0.5, 0)
	return _quad


## A tapered tube from a to b (radius ra at a, rb at b), appended to st with colour c. LIMB_SIDES sides, no caps
## (the ends are hidden in the ground or the leaves).
static func add_limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, c: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	for i in range(LIMB_SIDES):
		var a0 := i * TAU / LIMB_SIDES
		var a1 := (i + 1) * TAU / LIMB_SIDES
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var shade := c.darkened(0.12 * (0.5 + 0.5 * sin(a0 * 2.0)))
		for v: Vector3 in [a + d0 * ra, b + d0 * rb, b + d1 * rb, a + d0 * ra, b + d1 * rb, a + d1 * ra]:
			st.set_color(shade)
			st.add_vertex(v)


## Just a crown (no trunk) of this kind at `at`: for trees whose trunk is built elsewhere (the willows).
static func crown(kind: String, at: Vector3, seed: int, scale := 1.0) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return {"kind": kind, "palette": k["palettes"][0], "bark": k["bark"], "limbs": [],
		"clusters": [[rng.randi_range(0, VARIANTS - 1), at, Vector3.ONE * scale, rng.randf() * TAU]]}


## A tree crown far away, as a few big leaf cards: the cluster's crown leaves only (rank <= max_rank), placed by
## `xf` and tinted toward `tint`. For the distant land, so the forest past the woods is drawn with the same leaves
## as the woods themselves (distant_land.gd _near_forest). Returns [Transform3D, Color, Color] items.
static func far_crown(kind: String, palette: String, variant: int, xf: Transform3D, tint: Color, max_rank := 0.3) -> Array:
	var out: Array = []
	for it: Array in cluster(kind, palette, variant)["items"]:
		var custom: Color = it[2]
		if custom.a > max_rank:
			continue
		out.append([xf * (it[0] as Transform3D), (it[1] as Color).lerp(tint, 0.6), custom])
	return out


## Leaf items grouped by sheet as MultiMeshInstance3D nodes (one per sheet), for callers that collect their own items.
static func leaf_nodes(by_sheet: Dictionary) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for sheet: String in by_sheet:
		var items: Array = by_sheet[sheet]
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = leaf_quad()
		mm.instance_count = items.size()
		for i in range(items.size()):
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
			mm.set_instance_custom_data(i, items[i][2])
		var node := MultiMeshInstance3D.new()
		node.name = "Leaves_%s" % sheet
		node.multimesh = mm
		node.material_override = leaf_material(sheet)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(node)
	return out


## Leaf cards and triangles for one planned tree: what it costs to draw.
static func cost(plan_: Dictionary) -> Dictionary:
	var cards := 0
	var core_tris := 0
	for c: Array in plan_["clusters"]:
		var cl := cluster(plan_["kind"], plan_["palette"], c[0])
		cards += (cl["items"] as Array).size()
		if cl["core"] != null:
			core_tris += (cl["core"] as Mesh).get_faces().size() / 3
	var limb_tris: int = (plan_["limbs"] as Array).size() * LIMB_SIDES * 2
	return {"cards": cards, "triangles": cards * 2 + core_tris + limb_tris}


## Turn planned trees into a few nodes for one batch (the woods make one batch per patch of ground): one trunk mesh,
## one core mesh, and one leaf MultiMesh per leaf sheet, all positioned around `origin` (the batch's centre, so the
## renderer culls each batch by where it really is). Draw calls per batch: 2 + the number of sheets.
static func build_batch(plans: Array, origin: Vector3) -> Array[Node3D]:
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cores := SurfaceTool.new()
	cores.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := {}                                     # sheet -> Array of [Transform3D, Color, Color]
	for pl: Dictionary in plans:
		for l: Array in pl["limbs"]:
			add_limb(trunk, (l[0] as Vector3) - origin, (l[1] as Vector3) - origin, l[2], l[3], pl["bark"])
		if pl.has("blaze"):                              # a painted trail mark on the trunk: [at, facing]
			_add_blaze(trunk, (pl["blaze"][0] as Vector3) - origin, pl["blaze"][1])
		for c: Array in pl["clusters"]:
			var cl := cluster(pl["kind"], pl["palette"], c[0])
			var xf := Transform3D(Basis.from_euler(Vector3(0, c[3], 0)).scaled(c[2]), (c[1] as Vector3) - origin)
			if cl["core"] != null:
				var col: Color = cl["core_color"]
				for v in (cl["core"] as Mesh).get_faces():
					cores.set_color(col)
					cores.add_vertex(xf * v)
			if not leaves.has(cl["sheet"]):
				leaves[cl["sheet"]] = []
			var into: Array = leaves[cl["sheet"]]
			for it: Array in cl["items"]:
				into.append([xf * (it[0] as Transform3D), it[1], it[2]])
	var out: Array[Node3D] = []
	var has_limbs := plans.any(func(pl: Dictionary) -> bool: return not (pl["limbs"] as Array).is_empty())
	var has_cores := plans.any(func(pl: Dictionary) -> bool: return KINDS[pl["kind"]]["core"] > 0.0)
	if has_limbs:
		trunk.generate_normals()
		var t := MeshInstance3D.new()
		t.name = "Trunks"
		t.mesh = trunk.commit()
		t.material_override = _vertex_colour_mat("bark")
		out.append(t)
	if has_cores:
		cores.generate_normals()
		var c := MeshInstance3D.new()
		c.name = "Cores"
		c.mesh = cores.commit()
		c.material_override = _vertex_colour_mat("core", true)   # unshaded: a lit core reads as a ball, a flat one as shade
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(c)
	out.append_array(leaf_nodes(leaves))
	for n in out:
		n.position = origin
	return out


## A trail blaze: a small pale-blue painted rectangle on a trunk, facing `out` (as on the old trails).
static func _add_blaze(st: SurfaceTool, at: Vector3, out: Vector3) -> void:
	var side := out.cross(Vector3.UP).normalized() * 0.07
	var up := Vector3(0, 0.13, 0)
	for v: Vector3 in [at - side - up, at + side - up, at + side + up, at - side - up, at + side + up, at - side + up]:
		st.set_color(Color("7ab0d8"))
		st.add_vertex(v + out * 0.01)


static var _vc_mats := {}
static func _vertex_colour_mat(key: String, unshaded := false) -> StandardMaterial3D:
	if not _vc_mats.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_vc_mats[key] = m
	return _vc_mats[key]
