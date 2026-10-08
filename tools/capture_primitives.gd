extends SceneTree

## The primitive library (HedgeAnatomy.PRESETS) side by side, softly lit, outlined: /tmp/hedgepets-views/primitives.png
const RADII := {"paddle": Vector3(0.6, 0.09, 0.45), "teardrop": Vector3(0.55, 0.42, 0.42)}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Motion.speed = 0.0                   # captures and checks: every transition instant, results deterministic
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.968627, 0.945098, 0.890196)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.86, 0.78)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.75
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 50
	world.add_child(cam)
	cam.position = Vector3(0, 1.2, 8.0)
	cam.look_at(Vector3(0, 0.0, 0), Vector3.UP)
	var names: Array = HedgeAnatomy.PRESETS.keys()
	for i in range(names.size()):
		var name: String = names[i]
		var region := {"radii": RADII.get(name, Vector3(0.5, 0.42, 0.42)), "shape": name}
		var node := MeshInstance3D.new()
		node.mesh = HedgeAnatomy.build_mesh(region)
		var col := i % 3
		var row := i / 3
		node.position = Vector3((col - 1) * 1.55, (1 - row) * 1.75, 0.0)
		node.rotation_degrees = Vector3(15, -35, 0)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("6e8c42") if i % 2 == 0 else Color("a8704f")
		m.roughness = 1.0
		node.material_override = m
		var hull := ShaderMaterial.new()
		hull.shader = load("res://shaders/ink_hull.gdshader")
		hull.set_shader_parameter("width", 0.02)
		node.material_overlay = hull
		world.add_child(node)
		var label := Label3D.new()
		label.text = name
		label.font_size = 48
		label.modulate = Color(0.25, 0.2, 0.15)
		label.outline_size = 0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = node.position + Vector3(0, -0.62, 0.0)
		world.add_child(label)
	for i in range(8):
		await process_frame
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/primitives.png")
	print("saved primitives")
	quit()
