extends Node3D

## A HedgePet in 3D, assembled from its CharacterArtProfile (res://pets/gerald.tres): a bush that happens to look
## like a beaver. The silhouette establishes the animal (regions), the foliage the material (clusters of leaves),
## the face the personality (anchors). Each is built separately so none can destroy the others:
##   world      paper ground and background, soft illustration light
##   regions    the inner leafy masses (BODY, HEAD), MUZZLE, TAIL, EARS, FEET
##   foliage    scripts/art/foliage_builder.gd per region (head foliage is a child of the head and turns with it)
##   face       eyes, nose, mouth, teeth, cheeks at head-local anchors
##   life       blinks, looks toward you, a gust now and then; tap him: hop, shiver, a heart
##   detail     CLOSE / MEDIUM / FAR chosen from his size on screen (mobile first)
## Developer view: F1 (scripts/art/art_debug.gd). Acceptance captures: tools/capture_views.gd.

const PROFILE_PATH := "res://pets/gerald.tres"

@export var profile: CharacterArtProfile

var pet: Node3D
var head: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var leaves_mat: ShaderMaterial
var shell_mat: ShaderMaterial               # the silhouette ink (the leaves' next pass)
var foliage_nodes: Array[MultiMeshInstance3D] = []
var cluster_debug: Array = []                 # [{position (local to its region's parent), parent, normal, color}]
var eyes: Array[Node3D] = []
var heart: Label3D
var detail := "CLOSE"
var auto_detail := true
var time := 0.0
var joy := 0.0
var hop := 0.0
var _hop_v := 0.0
var _next_blink := 2.0
var _blink := 0.0
var _gust := 0.0
var _next_gust := 6.0
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _materials := {}


func _ready() -> void:
	if profile == null:
		profile = load(PROFILE_PATH) as CharacterArtProfile if ResourceLoader.exists(PROFILE_PATH) else CharacterArtProfile.gerald()
	_rng.seed = profile.seed
	_build_world()
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
	_build_ui()
	set_view("THREE_QUARTER")


# ------------------------------------------------------------------ world: paper, light, camera
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = profile.paper
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = profile.ambient_color
	env.ambient_light_energy = profile.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # an illustration: the paper stays the paper
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# soft illustration light: a broad warm key with soft, light shadows, and a fill from the viewer so the face
	# never falls into shadow
	sun = DirectionalLight3D.new()
	sun.light_color = profile.key_color
	sun.light_energy = profile.key_energy
	sun.shadow_enabled = true
	sun.shadow_blur = profile.shadow_softness
	sun.directional_shadow_max_distance = 25.0
	sun.rotation_degrees = profile.key_angle
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.light_color = Color(0.92, 0.95, 1.0)
	fill.light_energy = profile.fill_energy
	fill.rotation_degrees = Vector3(-18.0, 35.0, 0.0)    # from the front-right, where the viewer stands
	add_child(fill)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 40.0
	add_child(camera)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var paper_mat := ShaderMaterial.new()
	paper_mat.shader = load("res://shaders/paper_ground.gdshader")
	paper_mat.set_shader_parameter("paper", Color(profile.paper.r, profile.paper.g, profile.paper.b))
	paper_mat.set_shader_parameter("shadow_strength", profile.shadow_strength)
	ground.material_override = paper_mat
	ground.name = "Paper"
	add_child(ground)


## Camera presets for looking at him (and for the acceptance captures).
func set_view(view: String) -> void:
	var target := Vector3(0.15, 0.85, 0.0)
	var dir := Vector3(0.42, 0.55, 0.72)
	var distance := 7.4
	match view:
		"FRONT":
			dir = Vector3(1.0, 0.35, 0.0)
		"SIDE":
			dir = Vector3(0.0, 0.3, 1.0)
		"DISTANT":
			distance = 17.0
	camera.position = target + dir.normalized() * distance
	camera.look_at(target, Vector3.UP)


# ------------------------------------------------------------------ regions
func _mat(kind: String) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.0
	match kind:
		"inner":
			m.albedo_color = profile.inner_mass
		"moss":
			m.albedo_color = profile.palette["matcha"].darkened(0.08)
		"terracotta":
			m.albedo_color = Color("87634c")
		"ear":
			m.albedo_color = profile.palette["muted_ivy"]
		"ear_inner":
			m.albedo_color = profile.palette["muted_ivy"].darkened(0.18)   # a soft cup, not a dark spot
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
			m.albedo_color = Color(1.0, 0.70, 0.66, 0.62)   # peach, strong enough to stay pink over green
		"tail":
			m.albedo_texture = _engraved_texture()
			m.uv1_scale = Vector3(3.0, 2.0, 1.0)
	_materials[kind] = m
	return m


func _ellipsoid(parent: Node3D, center: Vector3, radii: Vector3, kind: String, outline := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 40
	mesh.rings = 20
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = center
	node.scale = radii
	node.material_override = _mat(kind)
	parent.add_child(node)
	if outline > 0.0 and profile.outline_strength > 0.0:
		var hull := ShaderMaterial.new()
		hull.shader = load("res://shaders/ink_hull.gdshader")
		hull.set_shader_parameter("ink", Color(profile.ink_color.r, profile.ink_color.g, profile.ink_color.b))
		hull.set_shader_parameter("width", outline * profile.outline_strength)
		node.material_overlay = hull
	return node


## A region's own primitive (scripts/art/hedge_anatomy.gd): bean, cushion, paddle, dome... at its centre.
func _primitive(parent: Node3D, region: Dictionary, center: Vector3, kind: String, outline := 0.0, scale := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = HedgeAnatomy.build_mesh(region)
	node.position = center
	node.scale = Vector3.ONE * scale
	node.material_override = _mat(kind)
	parent.add_child(node)
	if outline > 0.0 and profile.outline_strength > 0.0:
		var hull := ShaderMaterial.new()
		hull.shader = load("res://shaders/ink_hull.gdshader")
		hull.set_shader_parameter("ink", Color(profile.ink_color.r, profile.ink_color.g, profile.ink_color.b))
		hull.set_shader_parameter("width", outline * profile.outline_strength)
		node.material_overlay = hull
	return node


func _build_regions() -> void:
	var r: Dictionary = profile.regions
	# the inner leafy masses: the green that shows between clusters, on purpose
	_primitive(pet, r["BODY"], r["BODY"]["center"], "inner", 0.0, 0.97).name = "BODY"
	_primitive(head, r["HEAD"], Vector3.ZERO, "inner", 0.0, 0.97).name = "HEAD"
	_primitive(head, r["MUZZLE"], r["MUZZLE"]["center"], "moss", 0.016).name = "MUZZLE"
	# the tail: one rounded-rectangle paddle, engraved, low and behind; no leaves on it so it stays a beaver tail
	var tail := _primitive(pet, r["TAIL"], r["TAIL"]["center"], "tail", 0.025)
	tail.name = "TAIL"
	tail.rotation_degrees = Vector3(0, 6, 7)
	# ears: small rounded leaf-cups on top of the head
	for side: float in [1.0, -1.0]:
		var c: Vector3 = r["EARS"]["center"] * Vector3(1, 1, side)
		var ear := _primitive(head, r["EARS"], c, "ear", 0.018)
		ear.rotation_degrees = Vector3(-24.0 * side, -20.0 * side, 0)
		var inner := _primitive(ear, r["EARS"], Vector3(0.03, -0.01, 0.0), "ear_inner", 0.0, 0.62)
		inner.scale.z = 0.9
	# feet: flat-bottomed terracotta domes, short and compact, sitting on the ground
	var foot_r: Dictionary = r["FEET"]
	var lift: float = foot_r["radii"].y * float(foot_r["shape"].get("flat_bottom", 1.0))
	for f in profile.feet:
		_primitive(pet, foot_r, f + Vector3(0, lift, 0), "terracotta", 0.016).name = "FOOT"


## Engraved crosshatch for the paddle tail: warm wood with a restrained diamond pattern.
func _engraved_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color("7a5a3e"))
	for y in range(128):
		for x in range(128):
			var a := posmod(x + y, 32)
			var b := posmod(x - y, 32)
			if a < 2 or b < 2:
				img.set_pixel(x, y, Color("553d2a"))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ the face (head-local anchors)
func _anchor(name: String) -> Vector3:
	return HedgeAnatomy.anchor_point(profile, name)


func _build_face() -> void:
	# eyes: dark, round, a little oversized, like ceramic or ink; one restrained highlight; an ink rim
	for name in ["EYE_LEFT", "EYE_RIGHT"]:
		var holder := Node3D.new()
		holder.position = _anchor(name)
		var n := HedgeAnatomy.anchor_normal(profile, name)
		holder.basis = Basis(Quaternion(Vector3.FORWARD, -n))   # -Z of the holder faces out of the head
		head.add_child(holder)
		var s := profile.eye_size
		var eye := _ellipsoid(holder, Vector3(0, 0, -s * 0.35), Vector3(s, s * 1.08, s * 0.7), "eye", 0.06)
		eye.name = name
		_ellipsoid(eye, Vector3(-0.32, 0.36, -0.75), Vector3(0.24, 0.24, 0.12), "glint")
		eyes.append(holder)
	# nose: a soft dark seed on the front of the muzzle
	_ellipsoid(head, _anchor("NOSE"), Vector3(0.11, 0.085, 0.14), "nose", 0.05)
	# mouth: a few strokes - down from the nose, then a small curve each side
	var nose := _anchor("NOSE")
	var mouth := _anchor("MOUTH")
	_stroke([nose + Vector3(0, -0.07, 0), mouth])
	for side: float in [1.0, -1.0]:
		var pts: Array[Vector3] = []
		for k in range(6):
			var t := float(k) / 5.0
			pts.append(mouth + Vector3(-0.02 * sin(t * PI), 0.035 * sin(t * PI), side * t * 0.12))
		_stroke(pts)
	# teeth: two pale beaver teeth, identifiable from across the room
	for side: float in [1.0, -1.0]:
		var tooth := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.17, 0.085)
		tooth.mesh = box
		tooth.material_override = _mat("tooth")
		tooth.position = _anchor("TEETH") + Vector3(0.06, -0.05, side * 0.046)
		head.add_child(tooth)
		var hull := ShaderMaterial.new()
		hull.shader = load("res://shaders/ink_hull.gdshader")
		hull.set_shader_parameter("width", 0.008 * profile.outline_strength)
		tooth.material_overlay = hull
	# cheeks: a pale pigment wash
	for name in ["CHEEK_LEFT", "CHEEK_RIGHT"]:
		var cheek := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.12
		disc.bottom_radius = 0.12
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
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.014
		cyl.bottom_radius = 0.014
		cyl.height = a.distance_to(b) + 0.01
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
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/hedgeivy.png"))
		var normals := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/hedgeivy_n.png"))
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
	var key_dir := -sun.global_transform.basis.z
	var head_c: Vector3 = profile.regions["HEAD"]["center"]
	for region_name in profile.regions:
		if not profile.regions[region_name].get("foliage", false):
			continue
		var built := FoliageBuilder.build(profile, region_name, head_c, key_dir)
		var parent: Node3D = head if region_name == "HEAD" else pet
		_add_multimesh(parent, built["items"], region_name)
		for c in built["clusters"]:
			cluster_debug.append({"position": c["position"], "parent": parent, "normal": c["normal"], "color": c["color"]})
	_add_multimesh(pet, _tendrils(), "TENDRILS")
	set_detail(detail)


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


## Level 4: a few short tendrils trailing from the lower body; short so the silhouette stays a beaver.
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


## Detail levels (mobile first): fewer, bigger leaves keep the masses whole; interior ink fades; flowers go at FAR.
func set_detail(level: String) -> void:
	detail = level
	var l: Dictionary = profile.lod[level]
	_leaf_param("lod_keep", float(l["leaves"]))
	_leaf_param("lod_scale", float(l["scale"]))
	leaves_mat.set_shader_parameter("detail_ink", float(l["ink"]))


func _auto_detail() -> void:
	if not auto_detail or camera == null:
		return
	# how tall he is on screen, in pixels
	var top := camera.unproject_position(pet.global_position + Vector3(0, 2.1, 0))
	var bottom := camera.unproject_position(pet.global_position)
	var px := absf(bottom.y - top.y)
	var level := "CLOSE" if px > 360.0 else ("MEDIUM" if px > 170.0 else "FAR")
	if level != detail:
		set_detail(level)


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


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var name_tag := Label.new()
	name_tag.text = profile.pet_name
	name_tag.add_theme_font_size_override("font_size", 54)
	name_tag.add_theme_color_override("font_color", Color(0.36, 0.27, 0.19))
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.position = Vector2(140, 1500)
	name_tag.size = Vector2(800, 80)
	layer.add_child(name_tag)
	var note := Label.new()
	note.text = "adopted October 6, 2026  ·  tap him"
	note.add_theme_font_size_override("font_size", 26)
	note.add_theme_color_override("font_color", Color(0.45, 0.38, 0.30, 0.8))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.position = Vector2(140, 1575)
	note.size = Vector2(800, 40)
	layer.add_child(note)


# ------------------------------------------------------------------ life
func life_state() -> Dictionary:
	return {"joy": joy, "time": time}


func _process(delta: float) -> void:
	time += delta
	joy = maxf(0.0, joy - delta * 0.55)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 1.0
		_next_blink = _rng.randf_range(profile.blink_interval.x, profile.blink_interval.y)
	_blink = maxf(0.0, _blink - delta * 8.0)
	for eye in eyes:
		eye.scale.y = 1.0 - 0.88 * sin(_blink * PI)
	_look = _look.lerp(_look_target, clampf(delta * 3.0, 0.0, 1.0))
	head.rotation = Vector3(sin(time * 0.37) * 0.05, -_look.x * profile.look_strength, -_look.y * profile.look_strength * 0.5 + sin(time * 0.9) * 0.015)   # a gentle, curious tilt
	if hop > 0.0 or _hop_v != 0.0:
		_hop_v -= 9.0 * delta
		hop += _hop_v * delta
		if hop <= 0.0:
			hop = 0.0
			_hop_v = 0.0
	pet.position.y = hop + sin(time * 1.5) * 0.004
	# every so often a gust goes through his leaves
	_next_gust -= delta
	if _next_gust <= 0.0:
		_gust = 1.0
		_next_gust = _rng.randf_range(7.0, 14.0)
	_gust = maxf(0.0, _gust - delta * 0.8)
	_leaf_param("gust", joy * 1.2 + _gust * 0.5)
	shell_mat.set_shader_parameter("body_center", pet.to_global(profile.regions["BODY"]["center"]))
	shell_mat.set_shader_parameter("head_center", head.global_position)
	heart.modulate.a = clampf(joy * 1.4, 0.0, 1.0)
	heart.position.y = 1.1 + (1.0 - joy) * 0.5
	_auto_detail()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		var dbg := get_node_or_null("ArtDebug")
		if dbg == null:
			dbg = preload("res://scripts/art/art_debug.gd").new()
			dbg.name = "ArtDebug"
			add_child(dbg)
		else:
			dbg.queue_free()
		return
	if event is InputEventMouseMotion:
		var size := get_viewport().get_visible_rect().size
		_look_target = Vector2((event.position.x / size.x - 0.5) * 2.0, (event.position.y / size.y - 0.45) * 2.0).limit_length(1.0)
	elif event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		var on_screen := camera.unproject_position(pet.global_position + Vector3(0.3, 1.0, 0.0))
		if event.position.distance_to(on_screen) < get_viewport().get_visible_rect().size.x * 0.45:
			joy = 1.0
			if hop <= 0.0:
				_hop_v = sqrt(2.0 * 9.0 * profile.hop_height)
				hop = 0.001
