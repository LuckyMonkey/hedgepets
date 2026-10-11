extends RefCounted

## The woods' trees, made like the hedgepets: real trunks and limbs, crowns of leafy clusters from the same glyph
## foliage (garden._bush, fixed seeds so they bake). Four New England kinds:
##   oak    a stout trunk forking into limbs, a broad crown (oak leaves; autumn or still green)
##   maple  the same build, crimson and orange
##   birch  a slim white trunk, small gold clusters stacked up it
##   pine   a white pine: a tall straight trunk, flat tiers of needles, the top thinning
## Crowns start 3-4 m up, so walking you see trunks, limbs and leaves, not bare poles. Trees near the trails get leaf
## glyphs; further off, only the clusters' dark masses (they read as tree shapes in the haze). Everything is merged
## per 24 m patch - one trunk mesh, a mass mesh and a leaf multimesh per kind of leaf - so the whole wood is a few
## dozen draws however many trees, and every patch is stored in the bake (BakeCache).

const PATCH := 24.0
const LEAFY_REACH := 16.0                      # trees nearer a trail than this get leaves
const DENSITY := 0.38                          # of the full cluster's leaves (bigger leaves cover the gaps)
const LEAF_SIZE := 1.15
const KINDS := {
	"oak": {"sheet": "hedgeoak", "palettes": ["autumn", "green"], "bark": Color("4a3c30"), "build": "broad"},
	"maple": {"sheet": "hedgemaple", "palettes": ["crimson", "autumn"], "bark": Color("54463a"), "build": "broad"},
	"birch": {"sheet": "hedgegoldchild", "palettes": ["gold"], "bark": Color("e6e0d4"), "build": "slim"},
	"pine": {"sheet": "hedgepine", "palettes": ["pine"], "bark": Color("4e3c2e"), "build": "pine"},
}

var woods: Node3D
var garden: Node3D
var _clusters := {}                            # [kind, palette, seed] -> {mass: Mesh, leaves: MultiMesh, inner: Color}
var _patches := {}                             # Vector2i -> {trunk: SurfaceTool, mass: {inner -> SurfaceTool}, leaves: {sheet -> Array}}
var leafy := 0


func _init(w: Node3D) -> void:
	woods = w
	garden = w.garden


## One leafy cluster: a little bush of this kind's leaves, made once per kind, palette and seed.
func _cluster(kind: String, palette: String, seed: int) -> Dictionary:
	var key := "%s/%s/%d" % [kind, palette, seed]
	if _clusters.has(key):
		return _clusters[key]
	var k: Dictionary = KINDS[kind]
	var radii := Vector3(1.6, 1.25, 1.6) if kind != "pine" else Vector3(1.7, 0.7, 1.7)
	var inner := Color(SpeciesBuilder.PALETTES[palette][6]).darkened(0.15)
	var h: Node3D = garden._bush(Vector3.ZERO, radii, k["sheet"], SpeciesBuilder.palette_of(palette), inner, LEAF_SIZE, DENSITY, "dome", 0.0, Color(1.0, 0.98, 0.92), 7300 + seed)
	var c := {"mass": (h.get_child(0) as MeshInstance3D).mesh, "leaves": (h.get_child(1) as MultiMeshInstance3D).multimesh, "inner": inner, "sheet": k["sheet"]}
	h.queue_free()
	_clusters[key] = c
	return c


func _patch(p: Vector2) -> Dictionary:
	var key := Vector2i(floori(p.x / PATCH), floori(p.y / PATCH))
	if not _patches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_patches[key] = {"trunk": st, "mass": {}, "leaves": {}, "cached": BakeCache.fetch(BakeCache.key(["woodstrees3", key])) != null}
	return _patches[key]


## A tapered limb from a to b, its radius ra at a and rb at b, coloured c: added to the patch's trunk mesh.
func _limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, c: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	var n := 7
	for i in range(n):
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var shade := c.darkened(0.12 * (0.5 + 0.5 * sin(a0 * 2.0)))
		for v: Vector3 in [a + d0 * ra, b + d0 * rb, b + d1 * rb, a + d0 * ra, b + d1 * rb, a + d1 * ra]:
			st.set_color(shade)
			st.add_vertex(v)


## A cluster in the patch, at `at` (world, woods-local) with this scale: its dark mass always; its leaves if leafy.
func _add_cluster(pt: Dictionary, c: Dictionary, at: Vector3, s: Vector3, yaw: float, with_leaves: bool) -> void:
	var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(s), at)
	var inner_key: String = (c["inner"] as Color).to_html(false)
	if not pt["mass"].has(inner_key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		pt["mass"][inner_key] = [st, c["inner"]]
	(pt["mass"][inner_key][0] as SurfaceTool).append_from(c["mass"], 0, xf * Transform3D(Basis().scaled(Vector3.ONE * (0.96 if with_leaves else 1.08)), Vector3.ZERO))
	if not with_leaves:
		return
	var mm: MultiMesh = c["leaves"]
	var sheet: String = c["sheet"]
	if not pt["leaves"].has(sheet):
		pt["leaves"][sheet] = [mm.mesh, []]
	var items: Array = pt["leaves"][sheet][1]
	for i in mm.instance_count:
		items.append([xf * mm.get_instance_transform(i), mm.get_instance_color(i), mm.get_instance_custom_data(i)])


## A tree of this kind at p (woods-local, on the ground).
func tree(kind: String, p: Vector3, rng: RandomNumberGenerator, leafy_ok: bool) -> void:
	var k: Dictionary = KINDS[kind]
	var pal: String = k["palettes"][rng.randi_range(0, k["palettes"].size() - 1)]
	var pt := _patch(Vector2(p.x, p.z))
	var st: SurfaceTool = pt["trunk"]
	var bark: Color = (k["bark"] as Color).darkened(rng.randf() * 0.12)
	var s := rng.randf_range(0.85, 1.25)
	var yaw := rng.randf() * TAU
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var leaves := leafy_ok
	if leaves:
		leafy += 1
	_limbs_plan = []
	_clusters_plan = []
	match k["build"]:
		"broad":
			var fork := p + (Vector3.UP * 3.2 + lean * 2.0) * s
			_plan_limb(p - Vector3(0, 0.3, 0), fork, 0.36 * s, 0.24 * s, bark)
			var top := fork + (Vector3.UP * 3.5 + lean) * s
			_plan_limb(fork, top, 0.24 * s, 0.1 * s, bark)
			for b in range(rng.randi_range(3, 4)):
				var a := yaw + b * TAU / 4.0 + rng.randf_range(-0.4, 0.4)
				var out := Vector3(cos(a), 0, sin(a))
				var from := fork + Vector3.UP * rng.randf_range(0.0, 1.4) * s
				var tip := from + (out * rng.randf_range(2.0, 2.8) + Vector3.UP * rng.randf_range(1.2, 2.2)) * s
				_plan_limb(from, tip, 0.15 * s, 0.06 * s, bark)
				_plan_cluster(_cluster(kind, pal, rng.randi_range(0, 2)), tip + Vector3.UP * 0.3 * s, Vector3.ONE * rng.randf_range(0.9, 1.25) * s, rng.randf() * TAU, leaves)
			_plan_cluster(_cluster(kind, pal, rng.randi_range(0, 2)), top + Vector3.UP * 0.4 * s, Vector3.ONE * rng.randf_range(1.1, 1.4) * s, rng.randf() * TAU, leaves)
			_plan_cluster(_cluster(kind, pal, rng.randi_range(0, 2)), fork + Vector3.UP * 2.2 * s, Vector3.ONE * 1.2 * s, rng.randf() * TAU, leaves)
		"slim":
			var top := p + (Vector3.UP * 9.0 + lean * 4.0) * s
			_plan_limb(p - Vector3(0, 0.3, 0), top, 0.17 * s, 0.06 * s, bark)
			for b in range(4):
				var y := lerpf(0.42, 0.95, b / 3.0)
				var at := p.lerp(top, y)
				var a := yaw + b * 2.3
				var off := Vector3(cos(a), 0, sin(a)) * 0.7 * s
				_plan_limb(at - off * 0.2, at + off, 0.05 * s, 0.03 * s, bark)
				_plan_cluster(_cluster(kind, pal, b % 3), at + off, Vector3.ONE * rng.randf_range(0.6, 0.8) * s, rng.randf() * TAU, leaves)
		"pine":
			var tall := rng.randf_range(12.0, 16.0)
			var top := p + (Vector3.UP * tall + lean * 3.0) * s
			_plan_limb(p - Vector3(0, 0.3, 0), top, 0.3 * s, 0.05 * s, bark)
			var tiers := 6
			for t in range(tiers):
				var f := lerpf(0.3, 0.98, float(t) / (tiers - 1))
				var at := p.lerp(top, f)
				var w := lerpf(1.25, 0.45, f)
				var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)) * s
				_plan_cluster(_cluster(kind, pal, t % 3), at + off, Vector3(w, w * 0.9, w) * s, rng.randf() * TAU, leaves)
	# never in your way: nothing of it near the camera's path along any trail (its eye height, all the way)
	for l: Array in _limbs_plan:
		for f: float in [0.0, 0.5, 1.0]:
			if not woods.eye_clear((l[0] as Vector3).lerp(l[1], f), lerpf(l[2], l[3], f) + 0.6):
				_count_rejected(leaves)
				return
	for c: Array in _clusters_plan:
		if not woods.eye_clear(c[1], 1.6 * (c[2] as Vector3).x + 0.4):
			_count_rejected(leaves)
			return
	if pt["cached"]:                                  # this patch is in the bake: planned (same numbers drawn), not built
		return
	for l: Array in _limbs_plan:
		_limb(st, l[0], l[1], l[2], l[3], l[4])
	for c: Array in _clusters_plan:
		_add_cluster(pt, c[0], c[1], c[2], c[3], c[4])


var _limbs_plan: Array = []
var _clusters_plan: Array = []
var rejected := 0


func _plan_limb(a: Vector3, b: Vector3, ra: float, rb: float, c: Color) -> void:
	_limbs_plan.append([a, b, ra, rb, c])


func _plan_cluster(c: Dictionary, at: Vector3, sc: Vector3, yaw: float, with_leaves: bool) -> void:
	_clusters_plan.append([c, at, sc, yaw, with_leaves])


func _count_rejected(was_leafy: bool) -> void:
	rejected += 1
	if was_leafy:
		leafy -= 1


## Turn every patch into its meshes (from the bake when it has them) and put them in the woods.
func finish() -> void:
	var leaf_mats := {}
	for key: Vector2i in _patches:
		var pt: Dictionary = _patches[key]
		var ck := BakeCache.key(["woodstrees3", key])
		var cached = BakeCache.fetch(ck)
		var made: Array
		if cached != null:
			made = cached
		else:
			made = []
			var st: SurfaceTool = pt["trunk"]
			st.generate_normals()
			made.append(["trunk", st.commit(), null])
			for ik in pt["mass"]:
				var ms: SurfaceTool = pt["mass"][ik][0]
				made.append(["mass", ms.commit(), pt["mass"][ik][1]])
			for sheet in pt["leaves"]:
				var items: Array = pt["leaves"][sheet][1]
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.use_custom_data = true
				mm.mesh = pt["leaves"][sheet][0]
				mm.instance_count = items.size()
				for i in items.size():
					mm.set_instance_transform(i, items[i][0])
					mm.set_instance_color(i, items[i][1])
					mm.set_instance_custom_data(i, items[i][2])
				made.append(["leaves", mm, sheet])
			BakeCache.store(ck, made)
		for m: Array in made:
			match m[0]:
				"trunk":
					var node := MeshInstance3D.new()
					node.mesh = m[1]
					var bm := StandardMaterial3D.new()
					bm.vertex_color_use_as_albedo = true
					bm.roughness = 1.0
					node.material_override = bm
					woods.add_child(node)
				"mass":
					var node := MeshInstance3D.new()
					node.mesh = m[1]
					node.material_override = GardenProps.mat("treemass%s" % (m[2] as Color).to_html(false), m[2])
					woods.add_child(node)
				"leaves":
					var node := MultiMeshInstance3D.new()
					node.multimesh = m[1]
					if not leaf_mats.has(m[2]):
						leaf_mats[m[2]] = garden._leaf_material(m[2])
					node.material_override = leaf_mats[m[2]]
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					woods.add_child(node)
