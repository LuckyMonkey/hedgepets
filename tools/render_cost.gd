extends SceneTree

## What each render lever costs: GPU and CPU ms per frame, draw calls and primitives, garden then woods, for the
## levers the web quality tiers use (3D render scale, tilt-shift, shadows, grass/litter density).
##   DISPLAY=:0 godot --audio-driver Dummy --path . --script tools/render_cost.gd --disable-vsync --resolution 270x480
## The game renders into a SubViewport of PX (default 720x1280, a phone canvas) that updates every frame, so the
## numbers hold even when the desktop hides or covers the window (a hidden window stops drawing).
## Prints one line per (place, setup): COST {json}. Same seed, same hour, same camera, the player's save untouched.
const FRAMES := 120

var vp: RID
var view: SubViewport


func _init() -> void:
	call_deferred("_run")


func _info(kind: int) -> int:
	return RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, kind) \
		+ RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, kind)


func _subviews(n: Node, out: Array) -> Array:
	for k in n.get_children():
		if k is SubViewport:
			out.append(k.get_viewport_rid())
		_subviews(k, out)
	return out


func _measure(place: String, setup: String) -> void:
	# Wall-clock frames (vsync off). GPU timer queries are not used: on Mesa (Haswell) they stop the drawing after a while.
	for i in range(20):
		await process_frame
	var us: Array = []
	var draws := 0
	var prims := 0
	var last := Time.get_ticks_usec()
	for i in range(FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		us.append(float(now - last))
		last = now
		draws += _info(RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		prims += _info(RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	us.sort()
	print("COST " + JSON.stringify({"place": place, "setup": setup, "p50_ms": snappedf(us[FRAMES / 2] / 1000.0, 0.1),
		"p90_ms": snappedf(us[FRAMES * 9 / 10] / 1000.0, 0.1), "draws": draws / FRAMES, "prims": prims / FRAMES,
		"script_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01)}))


func _setups(g: Node, place: String) -> void:
	var setups: Array = OS.get_environment("SETUPS").split(",") if OS.get_environment("SETUPS") != "" \
		else ["base", "scale75", "scale60", "notilt", "noshadow", "lowgrass", "low"]
	for round in range(int(OS.get_environment("ROUNDS")) if OS.get_environment("ROUNDS") != "" else 1):
		for s in setups:
			_apply(g, "base")
			_apply(g, s)
			await _measure(place, s)
	_apply(g, "base")


func _apply(g: Node, s: String) -> void:
	match s:
		"base":
			view.scaling_3d_scale = 1.0
			g.get_node("TiltShift").visible = true
			for l in _lights(view, []):
				l.shadow_enabled = l.get_meta("shadow", l.shadow_enabled)
				l.set_meta("shadow", l.shadow_enabled)
			var gr: MultiMeshInstance3D = g.get_node("Grass")
			gr.multimesh.visible_instance_count = -1
			for m in _skies(view, []):
				m.res = m.get_meta("res", m.res)
				m.set_meta("res", m.res)
				m._fit()
		"scale75":
			view.scaling_3d_scale = 0.75
		"scale60":
			view.scaling_3d_scale = 0.6
		"notilt":
			g.get_node("TiltShift").visible = false
		"noshadow":
			for l in _lights(view, []):
				l.shadow_enabled = false
		"grass50":
			var gr: MultiMeshInstance3D = g.get_node("Grass")
			gr.multimesh.visible_instance_count = gr.multimesh.instance_count / 2
		"sky35":
			for m in _skies(view, []):
				m.res = 0.35
				m._fit()
		"low":
			view.scaling_3d_scale = 0.6
			g.get_node("TiltShift").visible = false
			for l in _lights(view, []):
				l.shadow_enabled = false


func _lights(n: Node, out: Array) -> Array:
	for k in n.get_children():
		if k is DirectionalLight3D and k.get_viewport() == view:
			out.append(k)
		_lights(k, out)
	return out


func _skies(n: Node, out: Array) -> Array:
	for k in n.get_children():
		if k is MiniatureSky:
			out.append(k)
		_skies(k, out)
	return out


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_HOUR", "16.5")
	seed(20261014)
	var px: PackedStringArray = (OS.get_environment("PX") if OS.get_environment("PX") != "" else "720x1280").split("x")
	view = SubViewport.new()
	view.size = Vector2i(int(px[0]), int(px[1]))
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override = Vector2i(1080, 1920)
	view.size_2d_override_stretch = true
	root.add_child(view)
	vp = view.get_viewport_rid()
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	view.add_child(g)
	var q = root.get_node_or_null("Quality")
	if q != null:
		q.enabled = false
	if not g.is_built:
		await g.built
	g.set_process_unhandled_input(false)
	print("COST " + JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(),
		"px": var_to_str(view.size), "visible": var_to_str(view.get_visible_rect().size)}))
	await _setups(g, "garden")
	if OS.get_environment("NO_WOODS") == "":
		g.woods.build_now()
		g.woods.enter()
		for i in range(10):
			await process_frame
		g.woods.set_process_unhandled_input(false)
		await _setups(g, "woods")
	quit(0)
