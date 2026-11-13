extends SceneTree
## Claude 2026-11-13: renders a 6x3 grid of every rock role, lifted onto the ground, lit by one sun -> $SHOT_OUT/grid5.png.
## Needs an X server (docs/OWNER_QUICKSTART.md): DISPLAY=:77 SHOT_OUT=~/work/shots godot --path . --rendering-driver opengl3 --script tools/rock_shots.gd
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("a7b37a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.8, 0.82, 0.78); env.environment.ambient_light_energy = 0.35
	w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, -40, 0); sun.light_energy = 1.0; w.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("7d8a45"); ground.material_override = gm; w.add_child(ground)
	var roles := [["wall_stone", Vector3(0.9, 0.45, 0.5)], ["cap_stone", Vector3(1.0, 0.25, 0.6)], ["stepping_stone", Vector3(0.8, 0.2, 0.7)], ["boulder", Vector3(1.6, 1.1, 1.3)], ["cobble", Vector3(0.3, 0.2, 0.26)], ["ledge", Vector3(1.8, 0.6, 0.9)]]
	for i in roles.size():
		for k in range(3):
			var mi := MeshInstance3D.new()
			mi.mesh = RockFactory.make({"role": roles[i][0], "size": roles[i][1], "seed": 11 + k * 7})
			mi.material_override = RockFactory.material(Color("9a968a"))
			var ab: AABB = mi.mesh.get_aabb()
			mi.position = Vector3(-2.0 + k * 2.0, -ab.position.y, -i * 1.9)
			mi.rotation.y = 0.5 * k
			w.add_child(mi)
	var cam := Camera3D.new(); w.add_child(cam); cam.fov = 55
	cam.position = Vector3(0, 2.6, 3.2); cam.look_at(Vector3(0, 0.2, -4.0), Vector3.UP)
	for k in range(15): await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT") + "/grid5.png")
	quit(0)
