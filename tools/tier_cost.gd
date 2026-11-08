extends SceneTree
## Garden then woods in the real window, as the game runs (current_scene set, so Quality applies its tier).
func _init():
	call_deferred("_run")
func _sample(label: String, g: Node) -> void:
	var vp := root.get_viewport_rid()
	for i in range(30):
		await process_frame
	var us: Array = []
	var d := 0
	var p := 0
	var last := Time.get_ticks_usec()
	for i in range(150):
		await process_frame
		var now := Time.get_ticks_usec()
		us.append(now - last)
		last = now
		d += RenderingServer.viewport_get_render_info(vp, 0, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME) + RenderingServer.viewport_get_render_info(vp, 1, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		p += RenderingServer.viewport_get_render_info(vp, 0, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) + RenderingServer.viewport_get_render_info(vp, 1, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	us.sort()
	var q = root.get_node_or_null("Quality")
	print("TIER %s %s: p50 %.1f ms, p90 %.1f ms, draws %d, prims %d" % [q.tier_name() if q else "?", label, us[75] / 1000.0, us[135] / 1000.0, d / 150, p / 150])
func _run():
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_HOUR", "16.5")
	seed(20261014)
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	current_scene = g
	if not g.is_built:
		await g.built
	g.set_process_unhandled_input(false)
	var q = root.get_node_or_null("Quality")
	if q:
		q.apply_current()
		q.enabled = false
	await _sample("garden", g)
	g.woods.build_now()
	g.woods.enter()
	for i in range(20):
		await process_frame
	g.woods.set_process_unhandled_input(false)
	if q:
		q.apply_current()
	await _sample("woods", g)
	quit()
