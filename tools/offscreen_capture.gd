extends SceneTree
## Offscreen capture: garden (and woods) rendered in a 720x1280 SubViewport; OUT=dir.
func _init():
	call_deferred("_run")
func _run():
	Motion.speed = 0.0
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_HOUR", "16.5")
	seed(20261014)
	var out := OS.get_environment("OUT")
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override = Vector2i(1080, 1920)
	view.size_2d_override_stretch = true
	root.add_child(view)
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	view.add_child(g)
	if not g.is_built:
		await g.built
	g.set_process_unhandled_input(false)
	var q = root.get_node_or_null("Quality")
	if q != null and "enabled" in q:
		q.enabled = false
	for i in range(60):
		await process_frame
	view.get_texture().get_image().save_png(out + "/garden.png")
	g.woods.build_now()
	g.woods.enter()
	for i in range(60):
		await process_frame
	view.get_texture().get_image().save_png(out + "/woods.png")
	print("captured")
	quit(0)
