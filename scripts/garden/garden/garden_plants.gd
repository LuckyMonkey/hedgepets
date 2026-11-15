extends "res://scripts/garden/garden/garden_sky.gd"

## Garden 3/6 - plants and trees: leaf materials, bushes, the tree wall, crowns, limbs, asters, fallen leaves.
##
## Every leafy thing in the garden is drawn like the pets: leaf sprites on a shared material (_leaf_material),
## arranged by the foliage system (scripts/art/foliage_builder.gd). _bush() is the one entry point; its result is kept
## in the startup cache (pack_leaves / unpack_leaves) so a phone does not rebuild thousands of leaves at load. Trees are
## merged into a few crown and limb meshes per cell (_merge_crowns, _merge_limbs) to keep draw calls low. Seeded: the
## order of calls decides where every leaf lands.
##
## Part of the garden layer chain (the full order is at the top of scripts/garden/garden.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var _rng := RandomNumberGenerator.new()
var _leaf_mats := {}
signal built                                      # the garden is up and playable (after a staged build)
func _leaf_material(sheet: String) -> ShaderMaterial:
	if _leaf_mats.has(sheet):
		return _leaf_mats[sheet]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/leaf.gdshader")
	m.set_shader_parameter("leaf_sheet", Assets.mipmapped("res://assets/sprites/%s.png" % sheet))
	m.set_shader_parameter("leaf_normals", Assets.mipmapped("res://assets/sprites/%s_n.png" % sheet))
	m.set_shader_parameter("interior_ink", 0.2)
	m.set_shader_parameter("silhouette_ink", 0.5)
	m.set_shader_parameter("near_fade", GardenProps.NEAR_FADE)
	_leaf_mats[sheet] = m
	return m


## A leafy mass (hedge, tree crown, leaf pile) grown with the pets' foliage system.
func _bush(center: Vector3, radii: Vector3, sheet: String, palette: Dictionary, inner: Color, leaf_size: float, density: float, shape: Variant = {}, flowering := 0.0, bloom := Color(1.0, 0.98, 0.92), fixed_seed := -1) -> Node3D:
	var seed := _rng.randi() if fixed_seed < 0 else fixed_seed     # (a fixed seed: the same leaves every time, bakeable)
	var holder := Node3D.new()
	add_child(holder)
	# The bake keeps the leaves as packed numbers (not a MultiMesh: a headless bake saves those empty) and the mass as
	# its vertices and normals (HedgeAnatomy.grid_mesh puts back the same mesh). "full" (the default): exactly what the
	# generators made. "half" (hedgepets/foliage_precision, an experiment): half-float leaves about the centre and one
	# unit mass per shape scaled to the radii - about 4 mm off, smaller.
	var full := foliage_precision() == "full"
	var parts: Array = ["bush", center, radii, sheet, palette, inner, leaf_size, density, shape, flowering, seed, "f32" if full else "h16"]
	if bloom != Color(1.0, 0.98, 0.92):
		parts.append(bloom)
	var region := {"center": center, "radii": radii, "parent": "", "foliage": true, "density": density, "leaf_scale": 1.0,
		"max_displacement": 0.2, "growth_up": 0.4, "material": "foliage", "shape": shape}
	var k := BakeCache.key(parts)
	var cached = BakeCache.fetch(k)
	var hit: bool = cached != null
	BakeCache.begin_composite()                          # (the parts of a bush are never kept on their own)
	if not hit:
		var p := CharacterArtProfile.new()
		p.seed = seed
		p.leaf_size = leaf_size
		p.growth = 1.0
		p.flowering = flowering
		p.flower_color = bloom
		p.leaves_per_cluster = 16
		p.palette = palette
		p.anchors = {}
		p.protected_zones = {}
		p.regions = {"BODY": region, "HEAD": {"center": Vector3(0, -100, 0), "radii": Vector3(0.1, 0.1, 0.1), "parent": "", "foliage": false}}
		var core: ArrayMesh = HedgeAnatomy.build_mesh(region, 16, 28) if full else null
		var built := FoliageBuilder.build(p, "BODY", Vector3(0, -100, 0), Vector3(0.5, -0.8, 0.3).normalized())
		var items: Array = built["items"]
		if full:
			var arr := core.surface_get_arrays(0)
			cached = [pack_leaves(items, Vector3.ZERO, true), items.size(), arr[Mesh.ARRAY_VERTEX], arr[Mesh.ARRAY_NORMAL]]
		else:
			cached = [pack_leaves(items, center, false), items.size()]
	var mass_mesh: Mesh
	if full:
		mass_mesh = HedgeAnatomy.grid_mesh(cached[2], cached[3], 16, 28)
	else:
		mass_mesh = HedgeAnatomy.build_mesh({"center": Vector3.ZERO, "radii": Vector3.ONE, "shape": shape}, 16, 28)
	BakeCache.end_composite()
	if not hit:
		BakeCache.store(k, cached)
	var buf := unpack_leaves(cached[0], cached[1])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _leaf_quad()
	mm.instance_count = cached[1]
	if cached[1] > 0:
		mm.buffer = buf
	var mass := MeshInstance3D.new()
	mass.mesh = mass_mesh
	mass.position = center
	mass.scale = Vector3.ONE * 0.96 if full else radii * 0.96
	mass.material_override = GardenProps.mat("inner%s" % inner.to_html(), inner)
	holder.add_child(mass)
	var leaves := MultiMeshInstance3D.new()
	leaves.multimesh = mm
	# Alpha-tested leaf cards are the dominant shadow-map cost on WebGL/mobile. The lawn shader's
	# fixed dapple and the tree masses retain the same broad, soft shade impression.
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not full:
		leaves.position = center
	leaves.material_override = _leaf_material(sheet)
	holder.add_child(leaves)
	holder.set_meta("mass_scale", Vector3.ONE if full else radii)   # (woods_trees copies the mass into its patches)
	last_leaves = buf                                    # (for woods_trees: the renderer can't give it back headless)
	return holder


static var _quad: QuadMesh
## The leaf buffer of the last _bush built (not kept on the bush: that would hold a second copy of every leaf).
var last_leaves := PackedFloat32Array()


static func _leaf_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.center_offset = Vector3(0, 0.5, 0)
	return _quad


## "full" (default) or "half": how foliage is kept in the bake (env HEDGEPETS_FOLIAGE_PRECISION, or the project
## setting hedgepets/foliage_precision). Rebake after changing it: the cache keys include it.
static func foliage_precision() -> String:
	var v := OS.get_environment("HEDGEPETS_FOLIAGE_PRECISION")
	if v == "":
		v = str(ProjectSettings.get_setting("hedgepets/foliage_precision", "full"))
	return "half" if v == "half" else "full"


## Leaves [Transform3D, Color, Color custom] as a MultiMesh buffer (20 floats each), origins made relative to `origin`.
## full: the floats themselves (PackedFloat32Array). half: half floats (PackedByteArray), an RGBAH image 5 pixels wide,
## one row per leaf, so Godot converts it natively both ways.
static func pack_leaves(items: Array, origin: Vector3, full: bool) -> Variant:
	var f := PackedFloat32Array()
	f.resize(items.size() * 20)
	for i in range(items.size()):
		var xf: Transform3D = items[i][0]
		var c: Color = items[i][1]
		var d: Color = items[i][2]
		var b := xf.basis
		var o := xf.origin - origin
		var j := i * 20
		f[j] = b.x.x; f[j + 1] = b.y.x; f[j + 2] = b.z.x; f[j + 3] = o.x
		f[j + 4] = b.x.y; f[j + 5] = b.y.y; f[j + 6] = b.z.y; f[j + 7] = o.y
		f[j + 8] = b.x.z; f[j + 9] = b.y.z; f[j + 10] = b.z.z; f[j + 11] = o.z
		f[j + 12] = c.r; f[j + 13] = c.g; f[j + 14] = c.b; f[j + 15] = c.a
		f[j + 16] = d.r; f[j + 17] = d.g; f[j + 18] = d.b; f[j + 19] = d.a
	if full:
		return f
	if items.is_empty():
		return PackedByteArray()
	var img := Image.create_from_data(5, items.size(), false, Image.FORMAT_RGBAF, f.to_byte_array())
	img.convert(Image.FORMAT_RGBAH)
	return img.get_data()


static func unpack_leaves(data: Variant, count: int) -> PackedFloat32Array:
	if data is PackedFloat32Array:
		return data
	if count == 0:
		return PackedFloat32Array()
	var img := Image.create_from_data(5, count, false, Image.FORMAT_RGBAH, data)
	img.convert(Image.FORMAT_RGBAF)
	return img.get_data().to_float32_array()


## Calico aster, growing wild: loose clumps of slender stems 0.5-1.2 m tall under clouds of tiny white daisies (their
## eyes yellow to rose-purple: hedgeaster.png). Three stems are grown once (fixed seeds: baked) and every clump is
## copies of them, turned, leaned and sized: a clump costs no bake and no generation. Each leaf sways on its own.
var _aster_stems: Array = []
func aster_clump(parent: Node3D, at: Vector3, seed: int) -> Node3D:
	if _aster_stems.is_empty():
		var pal := SpeciesBuilder.palette_of("aster")
		var inner := Color(SpeciesBuilder.PALETTES["aster"][6])
		for k in range(3):
			var h: float = [0.6, 0.9, 1.2][k]
			var b := _bush(Vector3(0, h * 0.6, 0), Vector3(0.26, h * 0.4, 0.26), "hedgeaster", pal, inner, 0.3, 1.2, "egg", 1.0, Color("fffaf4"), 7300 + k)
			b.get_child(0).visible = false               # no dark core: an aster is airy, slender stems under the leaves
			var sr := RandomNumberGenerator.new()
			sr.seed = 7310 + k
			# the bloom: far more flowers than a bush gets - a cloud of sprays over the top (each card several daisies)
			var buf := last_leaves.duplicate()
			var n_leaves := buf.size() / 20
			var n_flowers := 26 + k * 10
			for j in range(n_flowers):
				var d := Vector3(sr.randf_range(-1, 1), sr.randf_range(0.15, 1.0), sr.randf_range(-1, 1)).normalized()
				var on := Vector3(0, h * 0.6, 0) + d * Vector3(0.26, h * 0.4, 0.26) * 1.05
				var size := sr.randf_range(0.22, 0.3)
				var tan := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized().rotated(d, sr.randf() * TAU)
				var xf := Transform3D(Basis(tan * size, d.cross(tan).normalized() * size, d * size), on - d.cross(tan).normalized() * size * 0.5)
				var w := Color(1.0, 0.99, 0.96).lerp(Color(1.0, 0.95, 0.97), sr.randf())
				buf.append_array([xf.basis.x.x, xf.basis.y.x, xf.basis.z.x, xf.origin.x, xf.basis.x.y, xf.basis.y.y, xf.basis.z.y, xf.origin.y,
					xf.basis.x.z, xf.basis.y.z, xf.basis.z.z, xf.origin.z, w.r, w.g, w.b, 1.0, 13.0, sr.randf() * TAU, 0.7, 0.3])
			var mm: MultiMesh = (b.get_child(1) as MultiMeshInstance3D).multimesh
			mm.instance_count = n_leaves + n_flowers
			mm.buffer = buf
			var stems := SurfaceTool.new()
			stems.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in range(4):
				var lean := Vector3(sr.randf_range(-12, 12), 0, sr.randf_range(-12, 12))
				var foot := Vector3(sr.randf_range(-0.06, 0.06), h * 0.42, sr.randf_range(-0.06, 0.06))
				stems.append_from(GardenProps.cyl(0.006, 0.011, h * 0.85, 4), 0, Transform3D(Basis.from_euler(lean * PI / 180.0), foot))
			_aster_stems.append({"buf": buf, "stems": stems.commit(), "leaves": (b.get_child(1) as MultiMeshInstance3D).material_override})
			remove_child(b)                              # (only its numbers are kept: clumps are built from them)
			b.queue_free()
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var clump := Node3D.new()
	clump.name = "WildAster"
	clump.position = at
	parent.add_child(clump, true)
	# 3-5 stems, each a copy of one of the three: their leaves joined into one MultiMesh and their stalks into one
	# mesh, so a clump is two draws (it was ~20: every copy had its own leaves and four stalks)
	var buf := PackedFloat32Array()
	var stalks := SurfaceTool.new()
	stalks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_mat: Material = null
	for i in range(r.randi_range(3, 5)):
		var proto: Dictionary = _aster_stems[r.randi() % 3]
		var pos := Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
		var rot := Vector3(r.randf_range(-0.14, 0.14), r.randf() * TAU, r.randf_range(-0.14, 0.14))
		var xf := Transform3D(Basis.from_euler(rot).scaled(Vector3.ONE * r.randf_range(0.75, 1.0)), pos)
		buf.append_array(_moved_leaves(proto["buf"], xf))
		stalks.append_from(proto["stems"], 0, xf)
		leaf_mat = proto["leaves"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _leaf_quad()
	mm.instance_count = buf.size() / 20
	mm.buffer = buf
	var leaves := MultiMeshInstance3D.new()
	leaves.multimesh = mm
	leaves.material_override = leaf_mat
	clump.add_child(leaves)
	var stalk := MeshInstance3D.new()
	stalk.mesh = stalks.commit()
	stalk.material_override = GardenProps.mat("asterstem", Color("4a3a30"))
	clump.add_child(stalk)
	return clump


## A leaf buffer (MultiMesh layout, 20 floats a leaf) with every leaf moved by xf.
static func _moved_leaves(src: PackedFloat32Array, xf: Transform3D) -> PackedFloat32Array:
	var out := src.duplicate()
	for o in range(0, src.size(), 20):
		var t := xf * Transform3D(Basis(Vector3(src[o], src[o + 4], src[o + 8]), Vector3(src[o + 1], src[o + 5], src[o + 9]),
			Vector3(src[o + 2], src[o + 6], src[o + 10])), Vector3(src[o + 3], src[o + 7], src[o + 11]))
		var b := t.basis
		out[o] = b.x.x; out[o + 1] = b.y.x; out[o + 2] = b.z.x; out[o + 3] = t.origin.x
		out[o + 4] = b.x.y; out[o + 5] = b.y.y; out[o + 6] = b.z.y; out[o + 7] = t.origin.y
		out[o + 8] = b.x.z; out[o + 9] = b.y.z; out[o + 10] = b.z.z; out[o + 11] = t.origin.z
	return out


## Fallen leaves lying on the ground everywhere, thickest under the trees (one MultiMesh of flat leaf cards).
var fallen: MultiMeshInstance3D                  # the leaves on the ground (scripts/garden/fallen_leaves.gd)


func _leaf_litter() -> void:
	var image := Assets.image("res://assets/sprites/hedgemaple.png")
	var tex := ImageTexture.create_from_image(image.get_region(Rect2i(0, 0, 160 * 8, 160)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = Vector3(1.0 / 8.0, 1.0, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.metallic_specular = 0.0
	var quad := PlaneMesh.new()
	quad.size = Vector2(1, 1)
	var sources: Array = _crowns.duplicate()
	sources.append(Vector3(-12.0, 0, -20.0))
	var items: Array = []
	var colors := [Color("c9923c"), Color("b8702e"), Color("9a3428"), Color("c0482e"), Color("d8a848"), Color("8a6a3a")]
	for i in range(4200):
		var under := i % 3 != 0
		var p: Vector3
		if under:
			var c: Vector3 = sources.pick_random()
			var rr := sqrt(_rng.randf()) * 5.5
			var a := _rng.randf() * TAU
			p = Vector3(c.x + cos(a) * rr, 0, c.z + sin(a) * rr)
		else:
			p = Vector3(_rng.randf_range(-18, 18), 0, _rng.randf_range(-24, 10))
		if _in_puddle(Vector2(p.x, p.z)) or _in_creek(Vector2(p.x, p.z)):
			continue
		var s := _rng.randf_range(0.22, 0.4)
		var b := Basis.from_euler(Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf() * TAU, _rng.randf_range(-0.25, 0.25))).scaled(Vector3(s, s, s))
		items.append([Transform3D(b, p + Vector3(0, 0.015 + _rng.randf() * 0.02, 0)), (colors.pick_random() as Color).darkened(_rng.randf() * 0.15)])
	fallen = preload("res://scripts/garden/fallen_leaves.gd").new()   # they stay, more land, ✋ rakes them
	fallen.setup(self, m, quad, items, sources)
	add_child(fallen)


## A limb from a to b (a tapered cylinder with an ink hull).
func _limb(a: Vector3, b: Vector3, r0: float, r1: float, m: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = GardenProps.cyl(r1, r0, a.distance_to(b), clampi(int(round(r0 * 24.0)) + 4, 6, 14))   # sides by thickness
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	node.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	node.material_override = m
	node.material_overlay = GardenProps.hull(0.02)
	if _limbs_loose:                                     # (trees going into the skybox: neighborhood.adopt takes them whole)
		add_child(node)
		return node
	var c := Vector2i(floori((a.x + b.x) * 0.5 / LIMB_CELL), floori((a.z + b.z) * 0.5 / LIMB_CELL))
	if not _limb_patches.has(c):
		var patch := Node3D.new()
		patch.name = "Limbs_%d_%d" % [c.x, c.y]
		add_child(patch)
		_limb_patches[c] = patch
	_limb_patches[c].add_child(node)
	return node


## Limbs never move: once the trees are up, each patch becomes one mesh per bark (~440 cylinders -> ~20 meshes; each
## limb was a draw, its ink hull a second, and both again in every shadow split). Patches keep frustum culling.
const LIMB_CELL := 24.0
var _limb_patches := {}
var _limbs_loose := false


func _merge_limbs() -> void:
	for patch: Node3D in _limb_patches.values():
		GardenProps.bake_static(patch)
	_limb_patches.clear()
	_merge_crowns()


## Tree crowns never move either: per patch, the dark masses become one mesh per colour and the leaves one MultiMesh
## per sheet (the leaf buffers joined: in "full" precision every leaf is already in garden space). Same leaves, same
## shader; ~300 crowns -> a few dozen draws.
const CROWN_CELL := 10.0                          # smaller than the limbs': crowns are most of the primitives, so they cull finer
var _crown_patches := {}                          # cell -> [[holder, leaf buffer], ...]


func _crown(holder: Node3D, at: Vector3) -> void:
	if _limbs_loose or foliage_precision() != "full":
		return
	var c := Vector2i(floori(at.x / CROWN_CELL), floori(at.z / CROWN_CELL))
	if not _crown_patches.has(c):
		_crown_patches[c] = []
	_crown_patches[c].append([holder, last_leaves])


## A crown's dark core at half resolution (16 x 28 grid -> 8 x 14: every other point of the same surface). It sits
## inside the leaves; only glimpses of it show, so the quarter of the triangles looks the same.
func _coarse(m: Mesh) -> Mesh:
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	if v.size() != 17 * 29:
		return m
	var cv := PackedVector3Array()
	var cn := PackedVector3Array()
	for i in range(0, 17, 2):
		for j in range(0, 29, 2):
			cv.append(v[i * 29 + j])
			cn.append(n[i * 29 + j])
	return HedgeAnatomy.grid_mesh(cv, cn, 8, 14)


func _merge_crowns() -> void:
	for c: Vector2i in _crown_patches:
		var masses := {}                              # material -> SurfaceTool
		var leaves := {}                              # material -> PackedFloat32Array
		for item: Array in _crown_patches[c]:
			var holder: Node3D = item[0]
			var mass: MeshInstance3D = holder.get_child(0)
			var key: Material = mass.material_override
			if not masses.has(key):
				masses[key] = SurfaceTool.new()
				(masses[key] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
			(masses[key] as SurfaceTool).append_from(_coarse(mass.mesh), 0, holder.transform * mass.transform)
			var lm: Material = (holder.get_child(1) as MultiMeshInstance3D).material_override
			if not leaves.has(lm):
				leaves[lm] = PackedFloat32Array()
			leaves[lm].append_array(item[1])
			remove_child(holder)
			holder.queue_free()
		var patch := Node3D.new()
		patch.name = "Crowns_%d_%d" % [c.x, c.y]
		add_child(patch)
		for key: Material in masses:
			var mi := MeshInstance3D.new()
			mi.mesh = (masses[key] as SurfaceTool).commit()
			mi.material_override = key
			patch.add_child(mi)
		for lm: Material in leaves:
			var buf: PackedFloat32Array = leaves[lm]
			if buf.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = _leaf_quad()
			mm.instance_count = buf.size() / 20
			mm.buffer = buf
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.material_override = lm
			patch.add_child(node)
	_crown_patches.clear()


## A big broadleaf tree: a leaning trunk, a few branches forking up and out, a leaf clump at each branch end.
func _tree(at: Vector3, height: float, palette: Dictionary, sheet := "hedgeoak", far := false) -> void:
	var bark := GardenProps.mat("bark", Color("5c4634"))
	var lean := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	var top := at + Vector3(0, height * 0.62, 0) + lean
	_limb(at, top, 0.55, 0.3, bark).name = "Trunk"
	_limb(at + Vector3(0, 0.2, 0), at + Vector3(0.9, 0.0, 0.3), 0.3, 0.12, bark)       # a root
	_limb(at + Vector3(0, 0.2, 0), at + Vector3(-0.6, 0.0, -0.7), 0.28, 0.1, bark)
	var n := 3 if far else 5                                 # far trees (out of focus): fewer, bigger leaf masses
	var leaf := 1.3 if far else 0.8
	var dens := 0.32 if far else 0.5
	var grow := height / 12.0 if far else 1.0
	for i in range(n):
		var a := TAU * float(i) / float(n) + _rng.randf_range(-0.4, 0.4)
		var from := at.lerp(top, _rng.randf_range(0.55, 0.95))
		var reach := _rng.randf_range(2.2, 3.6)
		var to := from + Vector3(cos(a) * reach, _rng.randf_range(1.6, 3.2), sin(a) * reach)
		_limb(from, to, 0.24, 0.08, bark)
		var twig := to + Vector3(cos(a + 0.8) * 0.9, 0.7, sin(a + 0.8) * 0.9)
		_limb(to, twig, 0.08, 0.03, bark)
		var r := _rng.randf_range(1.6, 2.3) * grow
		_crown(_bush(to + Vector3(0, 0.6, 0), Vector3(r, r * 0.72, r), sheet, palette, Color(palette["deep_forest"]).darkened(0.2), leaf, dens, "egg"), at)
	_crown(_bush(top + Vector3(0, 2.6, 0) * grow, Vector3(2.6, 2.0, 2.6) * grow, sheet, palette, Color(palette["deep_forest"]).darkened(0.2), leaf * 1.06, dens, "egg"), at)
	if not far:
		_crowns.append(top + Vector3(0, 1.5, 0))
	obstacles.append([Vector2(at.x, at.z), 1.0])


## A pine: a straight thin trunk and tiers of needles, wide at the bottom, narrowing to a point.
func _pine(at: Vector3, height: float, far := false) -> void:
	var pine := {"deep_forest": Color("1c3529"), "muted_ivy": Color("28493a"), "matcha": Color("3b6046"),
		"warm_yellow_green": Color("557349"), "soft_sage": Color("4f6b5e"), "pale_highlight": Color("7f9a7c")}
	_limb(at, at + Vector3(0, height, 0), 0.4, 0.08, GardenProps.mat("pinebark", Color("4e3a2c"))).name = "Trunk"
	var tiers := 5
	for i in range(tiers):
		var t := float(i) / float(tiers - 1)
		var y := lerpf(height * 0.28, height * 0.9, t)
		var r := lerpf(3.0, 0.9, t) * height / 12.0 * _rng.randf_range(0.82, 1.12)
		var off := Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.35, 0.35))
		_crown(_bush(at + Vector3(0, y, 0) + off, Vector3(r, r * _rng.randf_range(0.48, 0.62), r * _rng.randf_range(0.85, 1.0)), "hedgepine", pine, Color("1d3326"), 1.25 if far else 0.8, 0.35 if far else 0.55,
			{"exponent": 2.0, "taper": -0.75, "taper_axis": "y", "flat_bottom": 0.5}), at)
	obstacles.append([Vector2(at.x, at.z), 0.7])


var _crowns: Array = []                           # broadleaf crowns: where falling leaves come from


func _baked_shadow(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
