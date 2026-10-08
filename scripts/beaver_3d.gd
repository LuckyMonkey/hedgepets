extends Node3D

## Gerald in 3D: a beaver made of ivy, seen from above and to the side like hedgepetsGoal.jpg.
##
## Everything is built here, procedurally: the leafy masses (body, head), thousands of ivy leaves as one MultiMesh
## (each leaf is a sprite from assets/sprites, lit with its normal map, moved by the wind in shaders/leaf.gdshader),
## the woven-twig tail, root feet, berry eyes, seed nose and teeth, a warm sun with real shadows, and the camera.
## Life: he blinks, his head turns a little toward your pointer, gusts roll through his leaves; tap him and he hops,
## his leaves shiver and a heart floats up.

const BODY_C := Vector3(0.0, 1.05, 0.0)
const BODY_R := Vector3(1.55, 1.0, 1.12)
const HEAD_C := Vector3(1.62, 1.38, 0.0)
const HEAD_R := Vector3(0.82, 0.72, 0.74)
const FACE_DIR := Vector3(1.0, -0.08, 0.0)          # the way he faces (+X)
const PAPER := Color(0.968627, 0.945098, 0.890196)
const PALETTE := [Color("3b6534"), Color("5d8a37"), Color("8ea64c"), Color("20472a"), Color("4a7a36"), Color("2f5a2c"), Color("6f963e")]

var pet: Node3D
var head: Node3D
var leaves_mat: ShaderMaterial
var eyes: Array[MeshInstance3D] = []
var heart: Label3D
var time := 0.0
var joy := 0.0
var hop := 0.0
var _hop_v := 0.0
var _next_blink := 2.0
var _blink := 0.0
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1977
	_build_world()
	pet = Node3D.new()
	add_child(pet)
	head = Node3D.new()
	head.position = HEAD_C
	pet.add_child(head)
	_build_masses()
	_build_tail()
	_build_feet()
	_build_leaves()
	_build_face()
	_build_ui()


# ------------------------------------------------------------------ world: camera, sun, ground
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = PAPER
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.80, 0.70)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED   # the paper background must not shine off everything
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.80)
	sun.light_energy = 0.36
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 30.0
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)   # from the upper left, behind the viewer's shoulder
	add_child(sun)
	var fill := DirectionalLight3D.new()   # a soft cool fill from the other side, no shadows
	fill.light_color = Color(0.75, 0.85, 1.0)
	fill.light_energy = 0.08
	fill.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	add_child(fill)
	var camera := Camera3D.new()
	# from the front-right and above, like the goal image; framed by width because the window is portrait
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 40.0
	var target := Vector3(0.1, 0.9, 0.0)
	camera.position = target + Vector3(0.42, 0.55, 0.72).normalized() * 7.4
	add_child(camera)
	camera.look_at(target, Vector3.UP)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(PAPER.r * 0.82, PAPER.g * 0.84, PAPER.b * 1.0)   # tuned so the lit ground comes out as the paper
	ground_mat.roughness = 1.0
	ground_mat.metallic_specular = 0.0
	ground.material_override = ground_mat
	add_child(ground)


# ------------------------------------------------------------------ the creature
func _ellipsoid(parent: Node3D, center: Vector3, radii: Vector3, color: Color, roughness := 0.9) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = center
	node.scale = radii
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	node.material_override = mat
	parent.add_child(node)
	return node


func _build_masses() -> void:
	# deep leafy shade inside the hedge: whatever shows between the leaves is more plant
	_ellipsoid(pet, BODY_C, BODY_R * 0.97, Color("1e3214"))
	_ellipsoid(head, Vector3.ZERO, HEAD_R * 0.96, Color("223817"))
	# moss over the muzzle
	_ellipsoid(head, FACE_DIR * HEAD_R.x * 0.62 + Vector3(0, -0.12, 0), Vector3(0.42, 0.34, 0.42), Color("56702c"))


func _build_tail() -> void:
	# a paddle of woven twigs, behind and low, tilted up a little
	var tail := _ellipsoid(pet, Vector3(-2.05, 0.32, 0.12), Vector3(0.95, 0.10, 0.62), Color.WHITE, 1.0)
	tail.rotation_degrees = Vector3(0, 8, 9)
	var weave := Image.create(256, 256, false, Image.FORMAT_RGB8)
	weave.fill(Color("2a1f12"))
	for i in range(-16, 32):
		for dir: int in [1, -1]:
			for k in range(256):
				var x := i * 16 + (k * dir if dir > 0 else 255 - k)
				var y := k
				for w in range(-3, 4):
					var px := x + w
					if px >= 0 and px < 256:
						var c := Color("5a4329") if absi(w) < 3 else Color("7e6342")
						weave.set_pixel(px, y, c)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(weave)
	mat.uv1_scale = Vector3(3, 3, 1)
	mat.roughness = 0.95
	tail.material_override = mat


func _build_feet() -> void:
	# root clumps: a mossy knot and roots splaying into the ground
	var root_mat := StandardMaterial3D.new()
	root_mat.albedo_color = Color("4a3622")
	root_mat.roughness = 1.0
	for spot: Vector3 in [Vector3(1.0, 0.0, 0.62), Vector3(1.0, 0.0, -0.62), Vector3(-0.85, 0.0, 0.7), Vector3(-0.85, 0.0, -0.7)]:
		_ellipsoid(pet, spot + Vector3(0, 0.14, 0), Vector3(0.22, 0.14, 0.2), Color("3f5a24"))
		for r in range(5):
			var a := TAU * float(r) / 5.0 + 0.4
			var root := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.045
			cyl.bottom_radius = 0.015
			cyl.height = 0.42
			root.mesh = cyl
			root.material_override = root_mat
			root.position = spot + Vector3(cos(a) * 0.2, 0.08, sin(a) * 0.2)
			root.rotation = Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2)
			pet.add_child(root)


## A few vines hanging off his sides and back, leaves all along them, swinging in the same wind.
func _build_vines() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	var items: Array = []
	for v in range(9):
		var a := _rng.randf_range(-PI, PI)
		var d := Vector3(cos(a) * 0.9, _rng.randf_range(-0.15, 0.35), sin(a)).normalized()
		var p := BODY_C + d * BODY_R
		var out := Vector3(d.x, 0.0, d.z).normalized()
		var steps := _rng.randi_range(4, 7)
		for k in range(steps):
			var prev := p
			p += out * 0.16 + Vector3(0, -0.13 - 0.02 * k, 0)
			if p.y < 0.12:
				break
			_stem(prev, p)
			var size := _rng.randf_range(0.26, 0.36) * (1.0 - 0.06 * k)
			var leaf_up := (out * 0.4 + Vector3.DOWN).normalized().rotated(out, _rng.randf_range(-0.8, 0.8))
			var right := leaf_up.cross(out).normalized()
			var normal := right.cross(leaf_up).normalized()
			items.append([Transform3D(Basis(right * size, leaf_up * size, normal * size), p), PALETTE[_rng.randi_range(0, PALETTE.size() - 1)], Color(float(_rng.randi_range(0, 7)), _rng.randf_range(0.0, TAU), 1.0, 0.0)])
	mm.instance_count = items.size()
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
		mm.set_instance_custom_data(i, items[i][2])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = leaves_mat
	pet.add_child(node)


func _stem(a: Vector3, b: Vector3) -> void:
	var seg := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 6
	seg.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("426633")
	mat.roughness = 0.9
	seg.material_override = mat
	pet.add_child(seg)
	seg.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	seg.basis = Basis(Quaternion(Vector3.UP, dir))


## Ivy all over the body and head: thousands of leaves, each a quad on the surface, facing out and a little up.
func _build_leaves() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/hedgeivy.png"))
	var normals := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/hedgeivy_n.png"))
	image.generate_mipmaps()
	normals.generate_mipmaps()
	leaves_mat = ShaderMaterial.new()
	leaves_mat.shader = load("res://shaders/leaf.gdshader")
	leaves_mat.set_shader_parameter("leaf_sheet", ImageTexture.create_from_image(image))
	leaves_mat.set_shader_parameter("leaf_normals", ImageTexture.create_from_image(normals))
	_scatter(pet, BODY_C, BODY_R, 1900, false)
	_scatter(head, Vector3.ZERO, HEAD_R, 900, true)
	_build_vines()


func _scatter(parent: Node3D, center: Vector3, radii: Vector3, count: int, is_head: bool) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.center_offset = Vector3(0, 0.5, 0)   # the stalk at the bottom edge sits on the surface
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var customs: Array[Color] = []
	for i in range(count):
		var d := Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn()).normalized()
		if d.y < -0.55:
			continue                                  # nothing grows underneath
		var p := center + d * radii
		var normal := (d / radii).normalized()       # the ellipsoid's true normal
		var size := _rng.randf_range(0.34, 0.52)
		if is_head:
			# leaves keep off just the berry eyes, the seed nose and the teeth; the rest of the face is small mossy leaves
			var clear := false
			for feature: Vector3 in [Vector3(0.62, 0.38, 0.55).normalized(), Vector3(0.62, 0.38, -0.55).normalized(), Vector3(1.0, -0.05, 0.0), Vector3(0.95, -0.45, 0.0).normalized()]:
				if d.angle_to(feature) < 0.30:
					clear = true
			if clear:
				continue
			var face := d.dot(FACE_DIR.normalized())
			if face > 0.2:
				size *= lerpf(1.0, 0.38, clampf((face - 0.2) / 0.6, 0.0, 1.0))
			size *= 0.85
		# the leaf lies against the surface, pointing outward and up (ivy climbs), tilted out a little
		var up_hint := (Vector3.UP - normal * normal.dot(Vector3.UP))
		if up_hint.length() < 0.1:
			up_hint = Vector3(1, 0, 0) - normal * normal.x
		var leaf_up := up_hint.normalized().rotated(normal, _rng.randf_range(-0.9, 0.9))
		var facing := (normal * 0.55 + leaf_up * 0.0).normalized()
		var leaf_right := leaf_up.cross(facing).normalized()
		var leaf_normal := leaf_right.cross(leaf_up).normalized()
		leaf_up = (leaf_up + normal * _rng.randf_range(0.15, 0.6)).normalized()   # lifting off the surface
		leaf_normal = leaf_right.cross(leaf_up).normalized()
		var basis := Basis(leaf_right * size, leaf_up * size, leaf_normal * size)
		transforms.append(Transform3D(basis, p - normal * 0.04))
		var shade: Color = PALETTE[_rng.randi_range(0, PALETTE.size() - 1)]
		shade = shade.lightened(_rng.randf_range(-0.05, 0.12))
		colors.append(shade)
		var cell := float(_rng.randi_range(0, 7))
		if _rng.randf() < 0.025:
			cell = 13.0                               # a white flower now and then
			colors[colors.size() - 1] = Color(1, 1, 1)
		var rim := clampf(1.0 - absf(d.dot(Vector3(0.42, 0.55, 0.72).normalized())), 0.2, 1.0)
		customs.append(Color(cell, _rng.randf_range(0.0, TAU), lerpf(0.4, 1.0, rim), 0.0))
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, customs[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = leaves_mat
	parent.add_child(node)


func _build_face() -> void:
	# berry eyes: glossy, dark with a purple sheen
	var berry := StandardMaterial3D.new()
	berry.albedo_color = Color("1c1222")
	berry.roughness = 0.08
	berry.metallic_specular = 1.0
	for side: float in [1.0, -1.0]:
		var dir := Vector3(0.62, 0.38, 0.55 * side).normalized()
		var eye := _ellipsoid(head, dir * HEAD_R * 0.98, Vector3(0.13, 0.15, 0.13), Color.BLACK, 0.08)
		eye.material_override = berry
		eyes.append(eye)
	# a seed for a nose, at the front of the muzzle
	var seed_mat := StandardMaterial3D.new()
	seed_mat.albedo_color = Color("3b2617")
	seed_mat.roughness = 0.35
	var nose := _ellipsoid(head, Vector3(HEAD_R.x * 1.12, -0.04, 0.0), Vector3(0.13, 0.10, 0.17), Color.BLACK)
	nose.material_override = seed_mat
	# two pale seeds for teeth
	for side: float in [1.0, -1.0]:
		_ellipsoid(head, Vector3(HEAD_R.x * 1.02, -0.36, 0.065 * side), Vector3(0.05, 0.13, 0.055), Color("efe6c4"), 0.5)
	# leaf ears: two big ivy leaves standing up from the top of the head
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = 2
	for i in range(2):
		var side := 1.0 if i == 0 else -1.0
		var basis := Basis.from_euler(Vector3(-0.30 * side, 0.55 * side, 0.0)).scaled(Vector3(0.62, 0.62, 0.62))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(-0.12, HEAD_R.y * 0.80, 0.40 * side)))
		mm.set_instance_color(i, Color("6f963e"))
		mm.set_instance_custom_data(i, Color(2.0, float(i) * 2.0, 0.9, 0.0))
	var ears := MultiMeshInstance3D.new()
	ears.multimesh = mm
	ears.material_override = leaves_mat
	head.add_child(ears)
	heart = Label3D.new()
	heart.text = "♥"
	heart.font_size = 160
	heart.modulate = Color(0.93, 0.42, 0.45, 0.0)
	heart.outline_modulate = Color(0, 0, 0, 0)
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.position = Vector3(0.3, 1.2, 0.0)
	head.add_child(heart)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var name_tag := Label.new()
	name_tag.text = "Gerald"
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
	# blink: squash the berries for a moment every few seconds
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 1.0
		_next_blink = _rng.randf_range(2.4, 5.5)
	_blink = maxf(0.0, _blink - delta * 8.0)
	for eye in eyes:
		eye.scale.y = 0.15 * (1.0 - 0.85 * sin(_blink * PI))
	# the head turns a little toward the pointer, and glances around when nobody is pointing
	_look = _look.lerp(_look_target, clampf(delta * 3.0, 0.0, 1.0))
	head.rotation = Vector3(0.0, -_look.x * 0.22, -_look.y * 0.12 + sin(time * 0.9) * 0.02)
	# hop
	if hop > 0.0 or _hop_v != 0.0:
		_hop_v -= 9.0 * delta
		hop += _hop_v * delta
		if hop <= 0.0:
			hop = 0.0
			_hop_v = 0.0
	pet.position.y = hop + sin(time * 1.5) * 0.004
	leaves_mat.set_shader_parameter("gust", joy * 1.4)
	heart.modulate.a = clampf(joy * 1.4, 0.0, 1.0)
	heart.position.y = 1.2 + (1.0 - joy) * 0.5


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var size := get_viewport().get_visible_rect().size
		_look_target = Vector2((event.position.x / size.x - 0.5) * 2.0, (event.position.y / size.y - 0.45) * 2.0).limit_length(1.0)
	elif event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		var camera := get_viewport().get_camera_3d()
		var on_screen := camera.unproject_position(pet.global_position + BODY_C)
		if event.position.distance_to(on_screen) < get_viewport().get_visible_rect().size.x * 0.45:
			joy = 1.0
			if hop <= 0.0:
				_hop_v = 2.6
				hop = 0.001
