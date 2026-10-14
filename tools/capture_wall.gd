extends SceneTree

## A stone wall alone on a lawn, from the side and three-quarters: fast iteration on GardenProps.stone_wall.
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path . --audio-driver Dummy --rendering-driver opengl3 \
##     --resolution 960x540 --script tools/capture_wall.gd       (writes /tmp/hedgepets-views/wall_*.png)
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/hedgepets-views"
	DirAccess.make_dir_recursive_absolute(out)
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7b37a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.75)
	env.ambient_light_energy = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.87, 0.68)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-33.0, -38.0, 0.0)
	w.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	ground.material_override = GardenProps.mat("lawn_test", Color("7f9a46"))
	w.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	GardenProps.bake_static(GardenProps.stone_wall(w, Vector3(-3.5, 0, 0), Vector3(3.5, 0, 0.6), rng))
	var cam := Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	for v: Array in [["side", Vector3(0, 0.9, 3.2), Vector3(0, 0.4, 0.3)], ["quarter", Vector3(3.2, 1.3, 2.6), Vector3(1.0, 0.4, 0.3)],
			["end", Vector3(6.0, 1.2, 1.2), Vector3(2.5, 0.45, 0.4)], ["top", Vector3(0.5, 4.5, 3.0), Vector3(0.5, 0.4, 0.3)]]:
		cam.position = v[1]
		cam.look_at(v[2])
		for i in range(4):
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("wall_%s.png" % v[0]))
	print("wall captured -> " + out)
	quit(0)
