extends SceneTree

## Where the frame goes, measured on the GPU: the main view's and every SubViewport's measured render time (CPU
## submit and GPU), draw calls and primitives, in the garden and at a few woods places. Same seed and hour each run,
## so two runs (before and after a change) compare. GPU, a real window, silent:
##   DISPLAY=:0 godot --audio-driver Dummy --resolution 540x960 --disable-vsync --path . --script tools/render_probe.gd
## PROBE_AB=1 also times each view with a skybox / the shadows switched off. Prints PROBE lines; PROBE_FRAMES (default 240) frames per view.
var frames := int(OS.get_environment("PROBE_FRAMES")) if OS.get_environment("PROBE_FRAMES") != "" else 240


func _init() -> void:
	call_deferred("_run")


func _vps() -> Array:
	var out: Array = [root]
	out.append_array(root.find_children("*", "SubViewport", true, false))
	for v: Viewport in out:
		RenderingServer.viewport_set_measure_render_time(v.get_viewport_rid(), true)
	return out


func _measure(label: String) -> void:
	var vps := _vps()
	for i in range(30):
		await process_frame
	var gpu := {}
	var cpu := {}
	var dc := 0.0
	var pr := 0.0
	var t0 := Time.get_ticks_usec()
	for i in range(frames):
		await process_frame
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		for v: Viewport in vps:
			var k := "main" if v == root else str(v.get_parent().name)
			gpu[k] = gpu.get(k, 0.0) + RenderingServer.viewport_get_measured_render_time_gpu(v.get_viewport_rid())
			cpu[k] = cpu.get(k, 0.0) + RenderingServer.viewport_get_measured_render_time_cpu(v.get_viewport_rid())
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	var parts := ""
	for k in gpu:
		parts += "  %s gpu %.2f cpu %.2f" % [k, gpu[k] / frames, cpu[k] / frames]
	print("PROBE %-12s frame %.2f ms  %d draws  %d prims%s" % [label, ms, int(dc / frames), int(pr / frames), parts])


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	g.set_process_unhandled_input(false)
	if not g.is_built:
		await g.built
	var variant := OS.get_environment("PROBE_SHADOW")    # "mode,distance" e.g. "2,40": an experiment on both suns
	if variant != "":
		g.sun.directional_shadow_mode = int(variant.get_slice(",", 0))
		g.sun.directional_shadow_max_distance = float(variant.get_slice(",", 1))
	if OS.get_environment("PROBE_LEAF_SHADOW") == "off":      # an experiment: leaf cards cast no shadow, their cores do
		for mm: MultiMeshInstance3D in g.find_children("*", "MultiMeshInstance3D", true, false):
			if mm.material_override is ShaderMaterial and mm.material_override.shader.resource_path.ends_with("leaf.gdshader"):
				mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(60):
		await process_frame
	await _measure("garden")
	if OS.get_environment("PROBE_SHOT") != "":
		root.get_texture().get_image().save_png(OS.get_environment("PROBE_SHOT") + "_garden.png")
	if OS.get_environment("PROBE_AB") != "":
		g.neighborhood.show_land(false)
		await _measure(" -skybox")
		g.neighborhood.show_land(true)
		g.sun.shadow_enabled = false
		await _measure(" -shadow")
		g.sun.shadow_enabled = true
	var w: Node3D = g.woods
	w.build_now()
	w.enter()
	for i in range(90):
		await process_frame
	w.set_process_unhandled_input(false)
	if variant != "":
		for l: DirectionalLight3D in w.find_children("*", "DirectionalLight3D", false, false):
			l.directional_shadow_mode = int(variant.get_slice(",", 0))
			l.directional_shadow_max_distance = minf(l.directional_shadow_max_distance, float(variant.get_slice(",", 1)))
	for place in ["trailhead", "fork", "ridge", "pines"]:
		w._at = place
		w._settle(Vector3.INF)
		await _measure(place)
		if OS.get_environment("PROBE_SHOT") != "" and place in ["trailhead", "pines"]:
			root.get_texture().get_image().save_png(OS.get_environment("PROBE_SHOT") + "_%s.png" % place)
		if OS.get_environment("PROBE_AB") != "" and place == "trailhead":
			var on: bool = g.neighborhood.view.render_target_update_mode == SubViewport.UPDATE_ALWAYS
			g.neighborhood.show_land(false)
			await _measure(" -garden sky")
			g.neighborhood.show_land(on)
			w.land.show_land(false)
			await _measure(" -land sky")
			w.land.show_land(true)
	quit(0)
