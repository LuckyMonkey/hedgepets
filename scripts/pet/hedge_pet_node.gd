extends Node3D
class_name HedgePetNode

## One HedgePet, built from its CharacterArtProfile: regions (primitives), face (anchors), foliage (clusters of its
## plant), and its life (blinks, looks at things, a gust now and then, hops when tapped, a little step while it
## walks). Place it anywhere: the pet viewer (scripts/hedge_pet_3d.gd) holds one, the garden holds several.
## Its own space: the pet faces +X, stands on y = 0.

var profile: CharacterArtProfile
var pet: Node3D                                  # body root: hops and steps move this
var head: Node3D
var leaves_mat: ShaderMaterial
var shell_mat: ShaderMaterial                    # the silhouette ink (the leaves' next pass)
var foliage_nodes: Array[MultiMeshInstance3D] = []
var cluster_debug: Array = []                    # [{position, parent, normal, color}] for the debug view
var eyes: Array[Node3D] = []
var heart: Label3D
var detail := "CLOSE"
var time := 0.0
var joy := 0.0
var hop := 0.0
var walking := 0.0                               # 0 standing .. 1 walking: a little step bounce
var look_point := Vector3.INF                    # a world point to turn the head toward (INF: glance around)
var _hop_v := 0.0
var _next_blink := 2.0
var _blink := 0.0
var _gust := 0.0
var _next_gust := 6.0
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _next_glance := 2.0
var _rng := RandomNumberGenerator.new()
var _materials := {}


func setup(p: CharacterArtProfile) -> void:
	profile = p
	for child in get_children():
		if child.name != "ContactShadow":                # the garden's, not ours
			child.queue_free()
	foliage_nodes.clear()
	eyes.clear()
	_materials.clear()
	leaves_mat = null
	shell_mat = null
	_rng.seed = profile.seed
	_next_blink = _rng.randf_range(1.0, 3.0)
	pet = Node3D.new()
	pet.name = "Pet"
	add_child(pet)
	head = Node3D.new()
	head.name = "Head"
	head.position = profile.regions["HEAD"]["center"]
	pet.add_child(head)
	_build_regions()
	_build_face()
	rebuild_foliage()


## Regrow this pet in another plant (SpeciesBuilder.PLANTS): new leaves, palette and bloom; same shape and face.
func set_plant(plant: String) -> void:
	var level := detail
	setup(SpeciesBuilder.restyle(profile, plant))
	set_detail(level)
	tap()


## A tap: a hop, a shiver through the leaves, a heart.
func tap() -> void:
	joy = 1.0
	if hop <= 0.0:
		_hop_v = sqrt(2.0 * 9.0 * profile.hop_height)
		hop = 0.001


func _mat(kind: String, region := {}) -> Material:
	var key := kind + str(region.get("color", ""))
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.0
	match kind:
		"inner", "foliage":
			m.albedo_color = profile.inner_mass
		"moss":
			m.albedo_color = profile.palette["matcha"].darkened(0.08)
		"sage":
			m.albedo_color = Color("9aa47e")
		"blossom":
			m.albedo_color = Color("efe8dc")
		"terracotta":
			m.albedo_color = Color("87634c")
		"ear":
			m.albedo_color = profile.palette["muted_ivy"]
		"ear_inner":
			m.albedo_color = profile.palette["muted_ivy"].darkened(0.18)
		"eye":
			m.albedo_color = Color("1e1814")
			m.roughness = 0.55
			m.metallic_specular = 0.2
		"glint":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1, 1, 1, 0.9)
		"nose":
			m.albedo_color = Color("3a2a1e")
			m.roughness = 0.6
		"tooth":
			m.albedo_color = Color("f3ead0")
		"ink":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = profile.ink_color
		"cheek":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1.0, 0.70, 0.66, 0.62)
		"tail":
			m.albedo_texture = _engraved_texture()
			m.uv1_scale = Vector3(3.0, 2.0, 1.0)
	if region.has("color"):
		m.albedo_color = region["color"]
	_materials[key] = m
	return m


func _hull(width: float) -> ShaderMaterial:
	var hull := ShaderMaterial.new()
	hull.shader = load("res://shaders/ink_hull.gdshader")
	hull.set_shader_parameter("ink", Color(profile.ink_color.r, profile.ink_color.g, profile.ink_color.b))
	hull.set_shader_parameter("width", width * profile.outline_strength)
	return hull


## A region's own primitive (scripts/art/hedge_anatomy.gd): bean, cushion, paddle, dome... at a centre.
func _primitive(parent: Node3D, region: Dictionary, center: Vector3, kind: String, outline := 0.0, scale := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = HedgeAnatomy.build_mesh(region)
	node.position = center
	node.scale = Vector3.ONE * scale
	node.material_override = _mat(kind, region)
	parent.add_child(node)
	if outline > 0.0 and profile.outline_strength > 0.0:
		node.material_overlay = _hull(outline)
	return node


func _ellipsoid(parent: Node3D, center: Vector3, radii: Vector3, kind: String, outline := 0.0) -> MeshInstance3D:
	return _primitive(parent, {"radii": radii}, center, kind, outline)


func _build_regions() -> void:
	for name in profile.regions:
		var r: Dictionary = profile.regions[name]
		var parent: Node3D = head if (name == "HEAD" or r.get("parent", "") == "HEAD") else pet
		var center: Vector3 = Vector3.ZERO if name == "HEAD" else r["center"]
		var kind: String = "inner" if r.get("foliage", false) else str(r.get("material", "moss"))
		var outline: float = 0.0 if r.get("foliage", false) else float(r.get("outline", 0.0))
		if name == "FEET":
			var lift: float = r["radii"].y * float(HedgeAnatomy._shape(r).get("flat_bottom", 1.0))
			for f in profile.feet:
				_primitive(pet, r, f + Vector3(0, lift, 0), kind, outline).name = "FOOT"
			continue
		var sides := [1.0, -1.0] if r.get("mirror", false) else [1.0]
		for side: float in sides:
			var node := _primitive(parent, r, center * Vector3(1, 1, side), kind, outline, 0.97 if r.get("foliage", false) else 1.0)
			node.name = name
			var rot: Vector3 = r.get("rotation", Vector3.ZERO)
			node.rotation_degrees = Vector3(rot.x * side, rot.y * side, rot.z)
			if kind == "ear":   # a little cup inside
				var inner := _primitive(node, r, Vector3(0.03, -0.01, 0.0), "ear_inner", 0.0, 0.62)
				inner.scale.z = 0.9


## Engraved crosshatch for a paddle tail: warm wood with a restrained diamond pattern.
func _engraved_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color("7a5a3e"))
	for y in range(128):
		for x in range(128):
			if posmod(x + y, 32) < 2 or posmod(x - y, 32) < 2:
				img.set_pixel(x, y, Color("553d2a"))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ the face (head-local anchors)


func _anchor(name: String) -> Vector3:
	return HedgeAnatomy.anchor_point(profile, name)


func _build_face() -> void:
	var f: Dictionary = profile.features
	# eyes: dark, round, a little oversized, like ceramic or ink; one restrained highlight; an ink rim
	for name in ["EYE_LEFT", "EYE_RIGHT"]:
		if not profile.anchors.has(name):
			continue
		var holder := Node3D.new()
		holder.position = _anchor(name)
		holder.basis = Basis(Quaternion(Vector3.FORWARD, -HedgeAnatomy.anchor_normal(profile, name)))
		head.add_child(holder)
		var s := profile.eye_size
		var eye := _ellipsoid(holder, Vector3(0, 0, -s * 0.35), Vector3(s, s * 1.08, s * 0.7), "eye", 0.06 * s / 0.155)
		eye.name = name
		_ellipsoid(eye, Vector3(-0.32 * s, 0.36 * s, -0.75 * s * 0.7), Vector3(0.24, 0.24, 0.12) * s, "glint")
		eyes.append(holder)
	if profile.anchors.has("NOSE"):
		_ellipsoid(head, _anchor("NOSE"), f.get("nose", Vector3(0.1, 0.08, 0.12)), "nose", 0.012)
	if profile.anchors.has("MOUTH"):
		var nose := _anchor("NOSE")
		var mouth := _anchor("MOUTH")
		var w: float = f.get("nose", Vector3(0.1, 0.08, 0.12)).z
		match str(f.get("mouth", "smile")):
			"beaver", "bunny":   # down from the nose, then a small curve each side
				_stroke([nose + Vector3(0, -w * 0.5, 0), mouth])
				for side: float in [1.0, -1.0]:
					var pts: Array[Vector3] = []
					for k in range(6):
						var t := float(k) / 5.0
						pts.append(mouth + Vector3(-w * 0.15 * sin(t * PI), w * 0.25 * sin(t * PI), side * t * w * 0.9))
					_stroke(pts)
			_:                   # a simple smile
				var pts: Array[Vector3] = []
				for k in range(9):
					var t := float(k) / 8.0 * 2.0 - 1.0
					pts.append(mouth + Vector3(0.0, (1.0 - t * t) * -w * 0.25 + w * 0.2, t * w * 1.3))
				_stroke(pts)
	if f.get("teeth", false) and profile.anchors.has("TEETH"):
		var w2: float = f.get("nose", Vector3(0.1, 0.08, 0.12)).z
		for side: float in [1.0, -1.0]:
			var tooth := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.36, 1.2, 0.6) * w2 * 0.85
			tooth.mesh = box
			tooth.material_override = _mat("tooth")
			tooth.position = _anchor("TEETH") + Vector3(0.06, -0.05, side * w2 * 0.33) * (w2 / 0.14)
			head.add_child(tooth)
			tooth.material_overlay = _hull(0.008)
	if f.get("cheeks", false):
		for name in ["CHEEK_LEFT", "CHEEK_RIGHT"]:
			if not profile.anchors.has(name):
				continue
			var cheek := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = profile.eye_size * 0.8
			disc.bottom_radius = profile.eye_size * 0.8
			disc.height = 0.005
			cheek.mesh = disc
			cheek.material_override = _mat("cheek")
			cheek.position = _anchor(name)
			cheek.basis = Basis(Quaternion(Vector3.UP, HedgeAnatomy.anchor_normal(profile, name))).scaled(Vector3(1.0, 1.0, 0.7))
			head.add_child(cheek)
	heart = Label3D.new()
	heart.text = "♥"
	heart.font_size = 140
	heart.modulate = Color(0.93, 0.45, 0.48, 0.0)
	heart.outline_modulate = Color(0, 0, 0, 0)
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.position = Vector3(0.2, 1.1, 0.0)
	head.add_child(heart)


func _stroke(points: Array[Vector3]) -> void:
	var width := clampf(profile.eye_size * 0.09, 0.008, 0.016)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = width
		cyl.bottom_radius = width
		cyl.height = a.distance_to(b) + width
		cyl.radial_segments = 6
		seg.mesh = cyl
		seg.material_override = _mat("ink")
		seg.position = (a + b) * 0.5
		seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		head.add_child(seg)


# ------------------------------------------------------------------ foliage


func rebuild_foliage() -> void:
	for node in foliage_nodes:
		node.queue_free()
	foliage_nodes.clear()
	cluster_debug.clear()
	if leaves_mat == null:
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % profile.leaf_sheet))
		var normals := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s_n.png" % profile.leaf_sheet))
		image.generate_mipmaps()
		normals.generate_mipmaps()
		leaves_mat = ShaderMaterial.new()
		leaves_mat.shader = load("res://shaders/leaf.gdshader")
		leaves_mat.set_shader_parameter("leaf_sheet", ImageTexture.create_from_image(image))
		leaves_mat.set_shader_parameter("leaf_normals", ImageTexture.create_from_image(normals))
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
		var built := FoliageBuilder.build(profile, region_name, head_c, key_dir)
		var parent: Node3D = head if (region_name == "HEAD" or r.get("parent", "") == "HEAD") else pet
		var items: Array = built["items"]
		if r.get("mirror", false):
			items = _with_mirror(items, r)
		elif r.has("rotation"):
			items = _rotated(items, r, 1.0)
		_add_multimesh(parent, items, region_name)
		for c in built["clusters"]:
			cluster_debug.append({"position": c["position"], "parent": parent, "normal": c["normal"], "color": c["color"]})
	_add_multimesh(pet, _tendrils(), "TENDRILS")
	set_detail(detail)


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
	mm.instance_count = items.size()
	for i in range(items.size()):
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
func _tendrils() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(profile.seed) + "tendrils")
	var body: Dictionary = profile.regions["BODY"]
	var items: Array = []
	for v in range(profile.tendrils):
		var a := rng.randf_range(-2.6, 2.6)
		var d := Vector3(cos(a), rng.randf_range(-0.1, 0.2), sin(a)).normalized()
		var p := HedgeAnatomy.shape_point(body, body["center"], d)
		var out := Vector3(d.x, 0.0, d.z).normalized()
		for k in range(3):
			p += out * 0.10 + Vector3(0, -0.12, 0)
			if p.y < 0.2:
				break
			var size := profile.leaf_size * 0.7 * (1.0 - 0.12 * k)
			var up := (out * 0.3 + Vector3.DOWN).normalized()
			var right := up.cross(out).normalized()
			var normal := right.cross(up).normalized()
			items.append([Transform3D(Basis(right * size, up * size, normal * size), p), profile.palette["muted_ivy"], Color(float(rng.randi_range(0, 7)), rng.randf_range(0, TAU), 1.0, 0.4 + 0.2 * k)])
	return items


## Set a uniform on the leaves and their ink shell together.
func _leaf_param(name: String, value: Variant) -> void:
	leaves_mat.set_shader_parameter(name, value)
	if shell_mat != null:
		shell_mat.set_shader_parameter(name, value)


## Detail levels (mobile first): fewer, bigger leaves keep the masses whole; interior ink fades.
func set_detail(level: String) -> void:
	detail = level
	var l: Dictionary = profile.lod[level]
	_leaf_param("lod_keep", float(l["leaves"]))
	_leaf_param("lod_scale", float(l["scale"]))
	leaves_mat.set_shader_parameter("detail_ink", float(l["ink"]))


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


# ------------------------------------------------------------------ ui: name, note, pet switcher


func life_state() -> Dictionary:
	return {"joy": joy, "time": time}


func _process(delta: float) -> void:
	if profile == null:
		return
	time += delta
	joy = maxf(0.0, joy - delta * 0.55)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 1.0
		_next_blink = _rng.randf_range(profile.blink_interval.x, profile.blink_interval.y)
	_blink = maxf(0.0, _blink - delta * 8.0)
	for eye in eyes:
		eye.scale.y = 1.0 - 0.88 * sin(_blink * PI)
	# where to look: a point in the world, or glancing around now and then
	if look_point != Vector3.INF:
		var local := head.global_transform.affine_inverse() * look_point
		var flat := Vector2(local.x, local.z)
		_look_target = Vector2(clampf(atan2(-local.z, local.x) / 1.2, -1.0, 1.0), clampf(-local.y / maxf(flat.length(), 0.5), -1.0, 1.0))
	else:
		_next_glance -= delta
		if _next_glance <= 0.0:
			_look_target = Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.4, 0.4)) if _rng.randf() < 0.7 else Vector2.ZERO
			_next_glance = _rng.randf_range(1.5, 4.0)
	_look = _look.lerp(_look_target, clampf(delta * 3.0, 0.0, 1.0))
	head.rotation = Vector3(sin(time * 0.37) * 0.05, _look.x * profile.look_strength * 1.6, -_look.y * profile.look_strength * 0.5 + sin(time * 0.9) * 0.015)   # a gentle, curious tilt
	if hop > 0.0 or _hop_v != 0.0:
		_hop_v -= 9.0 * delta
		hop += _hop_v * delta
		if hop <= 0.0:
			hop = 0.0
			_hop_v = 0.0
	var step := absf(sin(time * 9.0)) * 0.06 * walking   # a little bounce in each step
	pet.position.y = hop + step + sin(time * 1.5) * 0.004
	pet.rotation.z = sin(time * 9.0) * 0.03 * walking
	_next_gust -= delta
	if _next_gust <= 0.0:
		_gust = 1.0
		_next_gust = _rng.randf_range(7.0, 14.0)
	_gust = maxf(0.0, _gust - delta * 0.8)
	_leaf_param("gust", joy * 1.2 + _gust * 0.5 + walking * 0.4)
	shell_mat.set_shader_parameter("body_center", pet.to_global(profile.regions["BODY"]["center"]))
	shell_mat.set_shader_parameter("head_center", head.global_position)
	heart.modulate.a = clampf(joy * 1.4, 0.0, 1.0)
	heart.position.y = 1.1 + (1.0 - joy) * 0.5
