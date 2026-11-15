extends RefCounted

## Props 1/4 - the kit every prop is made from: shared materials, primitives (box, cylinder, blob, hull), the near fade, the root node, merging.
##
## A prop is a small tree of MeshInstance3Ds built from a few primitives with an ink outline (hull) and flat, slightly
## toy-like materials. Materials are cached by name (_mats) so a hundred rocks share one material and batch. near_fade()
## dissolves things that come between the camera and the view instead of letting them pop. merge_static() folds many
## finished props into a few meshes per cell, for things that never move.
##
## Part of the props layer chain (the full order is at the top of scripts/garden/garden_props.gd). Code here was moved verbatim
## from the old single file; only its place changed.

const INK := Color("2b2a20")
static var _mats := {}


static func mat(name: String, color: Color, roughness := 1.0) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic_specular = 0.0
	near_fade(m)
	_mats[name] = m
	return m


static func rust_mat() -> StandardMaterial3D:
	if _mats.has("rust"):
		return _mats["rust"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in range(64):
		for x in range(64):
			var n := sin(x * 0.31 + y * 0.17) * 0.5 + sin(x * 0.07 - y * 0.29) * 0.5 + rng.randf_range(-0.25, 0.25)
			var base := Color("3b3633")                        # old black enamel
			var rust := Color("9a5232").lerp(Color("c97a3e"), rng.randf())
			img.set_pixel(x, y, base.lerp(rust, smoothstep(-0.2, 0.5, n)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 1.0
	m.metallic_specular = 0.1
	near_fade(m)
	_mats["rust"] = m
	return m


## Everything in the garden dissolves right in front of the camera (near_fade.gdshaderinc; StandardMaterial's own
## pixel-dither distance fade), so the camera never sits inside a trunk or a crown.
const NEAR_FADE := Vector2(1.0, 3.2)


static func near_fade(m: BaseMaterial3D) -> BaseMaterial3D:
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = NEAR_FADE.x
	m.distance_fade_max_distance = NEAR_FADE.y
	return m


static func hull(width: float) -> ShaderMaterial:
	var key := "hull%.3f" % width
	if _mats.has(key):
		return _mats[key]
	var h := ShaderMaterial.new()
	h.shader = load("res://shaders/ink_hull.gdshader")
	h.set_shader_parameter("ink", INK)
	h.set_shader_parameter("width", width)
	h.set_shader_parameter("near_fade", NEAR_FADE)
	_mats[key] = h
	return h


static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg := Vector3.ZERO, outline := 0.012) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if mesh is TorusMesh and (mesh as TorusMesh).rings == 64:
		_torus_detail(mesh)
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation_degrees = rot_deg
	if outline > 0.0:
		node.material_overlay = hull(outline)
	parent.add_child(node)
	return node


## A torus left at Godot's default is 64 x 32 = 4096 triangles, a whole pet's head for a bucket's rim. Sized instead:
## around by its radius, the tube by its thickness (a rim 20 x 6, the tire 28 x 10).
static func _torus_detail(t: TorusMesh) -> void:
	t.rings = clampi(int(round(t.outer_radius * 40.0)) + 8, 12, 32)
	t.ring_segments = clampi(int(round((t.outer_radius - t.inner_radius) * 60.0)) + 5, 5, 12)


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(r_top: float, r_bottom: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 0                                          # straight or tapered sides: rings between the caps add nothing
	return c


static func blob(radii: Vector3, shape: Variant = {}, rings := -1, segments := -1) -> ArrayMesh:
	if rings < 0:                                        # by size (HedgeAnatomy.detail): ~0.35 m and up keep 12 x 24
		var d := HedgeAnatomy.detail(radii, 0.35, 24, 8)
		rings = d.x
		segments = d.y
	var k := BakeCache.key(["blob", radii, shape, rings, segments])
	var cached = BakeCache.fetch(k)
	if cached != null:
		return cached
	BakeCache.begin_composite()                          # (the blob's entry is what's kept, not the mesh build inside it)
	var m := HedgeAnatomy.build_mesh({"radii": radii, "shape": shape}, rings, segments)
	BakeCache.end_composite()
	BakeCache.store(k, m)
	return m


static func root(parent: Node3D, name: String, at: Vector3, yaw_deg: float) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = at
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	return n


## Merge every mesh under `r` (static scenery: walls, stones, fences) into one mesh per material, keeping each
## part's outline. Hundreds of draw calls become a handful; nothing looks different.
static func bake_static(r: Node3D) -> Node3D:
	var groups := {}                 # material -> [SurfaceTool, overlay]
	var parts: Array = []
	var stack: Array = [r]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and n != r:
			parts.append(n)
	var inv := r.global_transform.affine_inverse()
	for mi: MeshInstance3D in parts:
		var key: Material = mi.material_override
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = [st, mi.material_overlay]
		var xf: Transform3D = inv * mi.global_transform
		for surf in range(mi.mesh.get_surface_count()):
			(groups[key][0] as SurfaceTool).append_from(mi.mesh, surf, xf)
	for mi: MeshInstance3D in parts:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for key in groups:
		var st: SurfaceTool = groups[key][0]
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = key
		merged.material_overlay = groups[key][1]
		r.add_child(merged)
	return r


## Merge many static things into a few meshes: every MeshInstance3D under `roots` (with its material and ink overlay),
## grouped by `cell`-metre patch and material, becomes one mesh per group under `parent`/MergedProps. Same look, a
## fraction of the draw calls. Only for things that never move again. Returns the number of meshes made.
static func merge_static(parent: Node3D, roots: Array, cell := 24.0) -> int:
	var inv := parent.global_transform.affine_inverse()
	var groups := {}
	var parts: Array = []
	for r: Node in roots:
		if r is MeshInstance3D:
			parts.append(r)
		parts.append_array(r.find_children("*", "MeshInstance3D", true, false))
	for mi: MeshInstance3D in parts:
		await Slicer.tick(parent)
		if mi.mesh == null:
			continue
		var xf: Transform3D = inv * mi.global_transform
		var c := Vector2i(floori(xf.origin.x / cell), floori(xf.origin.z / cell))
		var key := "%d_%d_%d_%d_%d" % [c.x, c.y, mi.material_override.get_instance_id() if mi.material_override else 0,
			mi.material_overlay.get_instance_id() if mi.material_overlay else 0, mi.cast_shadow]
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = [st, mi.material_override, mi.material_overlay, mi.cast_shadow]
		for surf in range(mi.mesh.get_surface_count()):
			(groups[key][0] as SurfaceTool).append_from(mi.mesh, surf, xf)
	for r: Node in roots:
		r.get_parent().remove_child(r)
		r.queue_free()
	var holder := Node3D.new()
	holder.name = "MergedProps"
	parent.add_child(holder)
	for key in groups:
		await Slicer.tick(parent)
		var g: Array = groups[key]
		var merged := MeshInstance3D.new()
		merged.mesh = (g[0] as SurfaceTool).commit()
		merged.material_override = g[1]
		merged.material_overlay = g[2]
		merged.cast_shadow = g[3]
		holder.add_child(merged)
	return groups.size()
