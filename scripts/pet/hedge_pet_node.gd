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
## Little moods, each 0..1 and eased (never a jump): asleep (eyes shut, slow breaths, head down, Zzz), curious (a
## head tilt when you come near), shaking (after a watering: a shiver from nose to tail, droplets flying).
var asleep := 0.0
var sleeping := false
var curious := 0.0
var noticed := false
var _shake := 0.0
## Single flowers that have sprouted somewhere unexpected: [region name, direction]. Kept across regrafts.
var extra_flowers: Array = []
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
		if child.name != "ContactShadow" and not child is CPUParticles3D:   # the garden's shadow; a leaf burst in flight
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
## Animated (default): the old leaves fall away in a little burst, the pet squashes, and the new plant grows in.
func set_plant(plant: String, animate := true) -> void:
	if not animate or Motion.speed <= 0.0 or not is_inside_tree():
		_regrow(plant)
		return
	_leaf_burst()
	var rest := scale
	var t := Motion.shed_leaves(self)
	t.tween_callback(func() -> void:
		Motion.swap(self, rest, func() -> void:
			_regrow(plant)
			leaf_growth = 0.0
			Motion.grow_leaves(self)))


## Restart as `profile` (another pet: the viewer's ‹ ›) with the same transition as a regraft.
func become(p: CharacterArtProfile) -> void:
	if Motion.speed <= 0.0 or not is_inside_tree():
		setup(p)
		return
	var rest := scale
	var t := Motion.shed_leaves(self)
	t.tween_callback(func() -> void:
		Motion.swap(self, rest, func() -> void:
			var level := detail
			setup(p)
			set_detail(level, true)
			leaf_growth = 0.0
			Motion.grow_leaves(self)))


func _regrow(plant: String) -> void:
	var level := detail
	setup(SpeciesBuilder.restyle(profile, plant))
	set_detail(level, true)
	tap()


## A handful of the current leaves flying off (hides the moment one plant becomes another).
func _leaf_burst() -> void:
	if leaves_mat == null:
		return
	var sheet: Texture2D = leaves_mat.get_shader_parameter("leaf_sheet")
	var m := StandardMaterial3D.new()
	m.albedo_texture = sheet
	m.uv1_scale = Vector3(1.0 / 16.0, 0.5, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 28
	p.lifetime = 1.1
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = (profile.regions["BODY"]["radii"] as Vector3).x * 0.8
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -5.0, 0)
	p.angle_max = 360.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = profile.leaf_size * 0.6
	p.scale_amount_max = profile.leaf_size * 1.0
	p.color = profile.palette["matcha"]
	var quad := QuadMesh.new()
	quad.material = m
	p.mesh = quad
	p.position = profile.regions["BODY"]["center"]
	p.emitting = true
	add_child(p)
	p.finished.connect(p.queue_free)


## Fall asleep / wake up (eased in _process). Waking from a tap is a little startled hop.
func set_sleeping(on: bool) -> void:
	sleeping = on


## After a watering: shake it off.
func shake_off() -> void:
	sleeping = false
	_shake = 1.0
	joy = maxf(joy, 0.4)
	_droplets()


func _droplets() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 30
	p.lifetime = 0.9
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = (profile.regions["BODY"]["radii"] as Vector3).x * 0.9
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -8.0, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.06
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.88, 0.98, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	var drop := SphereMesh.new()
	drop.radius = 1.0
	drop.height = 2.0
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = m
	p.mesh = drop
	p.position = profile.regions["BODY"]["center"]
	p.emitting = true
	add_child(p)
	p.finished.connect(p.queue_free)


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


## A tap: a hop, a shiver through the leaves, a heart.
func tap() -> void:
	sleeping = false
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
		var image := Assets.image("res://assets/sprites/%s.png" % profile.leaf_sheet)
		var normals := Assets.image("res://assets/sprites/%s_n.png" % profile.leaf_sheet)
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
## Smooth: the leaves of the new level grow in / shrink away (scripts/anim/motion.gd). instant = true for captures.
func set_detail(level: String, instant := false) -> void:
	detail = level
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
	asleep = move_toward(asleep, 1.0 if sleeping else 0.0, delta * (0.5 if sleeping else 2.5))
	curious = move_toward(curious, 1.0 if noticed and not sleeping else 0.0, delta * 2.5)
	_shake = maxf(0.0, _shake - delta * 1.1)
	for eye in eyes:
		eye.scale.y = lerpf(1.0 - 0.88 * sin(_blink * PI), 0.1, asleep)
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
	if asleep > 0.0:
		_look_target = _look_target.lerp(Vector2.ZERO, asleep)
	_look = _look.lerp(_look_target, clampf(delta * 3.0, 0.0, 1.0))
	head.rotation = Vector3(sin(time * 0.37) * 0.05 + curious * 0.24 + sin(time * 30.0) * 0.08 * _shake,
		_look.x * profile.look_strength * 1.6, -_look.y * profile.look_strength * 0.5 + sin(time * 0.9) * 0.015 - asleep * 0.22)   # a gentle, curious tilt; head down asleep
	if hop > 0.0 or _hop_v != 0.0:
		_hop_v -= 9.0 * delta
		hop += _hop_v * delta
		if hop <= 0.0:
			hop = 0.0
			_hop_v = 0.0
	var step := absf(sin(time * 9.0)) * 0.06 * walking   # a little bounce in each step
	pet.position.y = hop + step + sin(time * 1.5) * 0.004
	pet.rotation.z = sin(time * 9.0) * 0.03 * walking
	pet.rotation.x = sin(time * 34.0) * 0.1 * _shake * _shake                  # shaking off the water
	pet.scale = Vector3(1.0, 1.0 + sin(time * 1.3) * 0.025 * asleep, 1.0)       # slow breaths in sleep
	_next_gust -= delta
	if _next_gust <= 0.0:
		_gust = 1.0
		_next_gust = _rng.randf_range(7.0, 14.0)
	_gust = maxf(0.0, _gust - delta * 0.8)
	_leaf_param("gust", joy * 1.2 + _gust * 0.5 * (1.0 - asleep * 0.7) + walking * 0.4 + _shake * 1.5)
	shell_mat.set_shader_parameter("body_center", pet.to_global(profile.regions["BODY"]["center"]))
	shell_mat.set_shader_parameter("head_center", head.global_position)
	heart.modulate.a = clampf(joy * 1.4, 0.0, 1.0)
	heart.position.y = 1.1 + (1.0 - joy) * 0.5
