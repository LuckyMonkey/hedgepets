extends SceneTree

## Which part of the distant land is that? Stands at one woods place (default the pond) and captures the view once
## with everything, then once with each named piece of the miniature land hidden, so a stray shape in the woods' sky
## can be traced to the code that made it. Writes /tmp/hedgepets-views/land_<place>_<piece>.png.
##   DISPLAY=:77 CAPTURE_PLACE=pond godot --path . --audio-driver Dummy --script tools/capture/capture_land_layers.gd

func _init() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/%s.png" % name)


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	var woods: Node = garden.woods
	woods.build_now()
	woods.enter()
	await create_timer(1.5).timeout
	woods.set_process_unhandled_input(false)
	var place := OS.get_environment("CAPTURE_PLACE")
	if place == "":
		place = "pond"
	var look: Vector3 = Vector3(woods.POND_AT.x, 0, woods.POND_AT.y) - woods.node_pos("pond") if place == "pond" else Vector3(woods.VIEW_DIR.x, 0, woods.VIEW_DIR.y)
	woods._at = place
	woods._yaw = woods._heading_of(look.normalized())
	woods._goal_yaw = woods._yaw
	woods._pitch = deg_to_rad(-6.0)
	woods._settle(Vector3.INF)
	await create_timer(1.2).timeout
	_shot("land_%s_all" % place)
	var pieces: Array = []
	for n in woods.land.view.find_children("*", "GeometryInstance3D", true, false):
		pieces.append(n)
	print("land pieces: ", pieces.map(func(n: Node) -> String: return str(n.name)))
	for n: GeometryInstance3D in pieces:
		if not n.visible:
			continue
		n.visible = false
		woods.land._request_redraw()
		await create_timer(0.4).timeout
		_shot("land_%s_without_%s" % [place, n.name])
		n.visible = true
	quit(0)
