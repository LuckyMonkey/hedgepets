extends SceneTree

## What the woods cost, by kind of thing: at a few places, frame time / draw calls / primitives with everything shown,
## then with each category hidden in turn (the difference is that category's cost). GPU, a real window:
##   godot --path . --audio-driver Dummy --resolution 540x960 --disable-vsync --script tools/woods_cost.gd
func _init() -> void:
	call_deferred("_run")


func _cat(n: Node, w: Node) -> String:
	if n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			return "other"
		if mm.mesh is QuadMesh or mm.mesh is PlaneMesh:
			return "leaf cards"
		return "small things (multimesh)"
	if n is MeshInstance3D:
		var m := (n as MeshInstance3D).mesh
		if m == null:
			return "other"
		var box := m.get_aabb()
		if box.size.x > 60.0:
			return "ground/ribbons"
		if box.size.y > 6.0:
			return "tree patches"
		if n.get_parent() != w:
			return "props"
		return "props"
	return ""


func _measure(frames: int) -> Array:
	for i in range(20):
		await process_frame
	var t0 := Time.get_ticks_usec()
	var dc := 0.0
	var pr := 0.0
	for i in range(frames):
		await process_frame
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return [snappedf((Time.get_ticks_usec() - t0) / 1000.0 / frames, 0.01), int(dc / frames), int(pr / frames)]


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	g.set_process_unhandled_input(false)
	var w: Node3D = g.woods
	w.build_now()
	w.enter()
	for i in range(90):
		await process_frame
	w.set_process_unhandled_input(false)
	var cats := {}
	var stack: Array = [w]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var k := _cat(n, w)
		if k != "":
			if not cats.has(k):
				cats[k] = []
			cats[k].append(n)
	for k in cats:
		var tris := 0
		for n in cats[k]:
			if n is MeshInstance3D:
				tris += (n as MeshInstance3D).mesh.get_faces().size() / 3
			elif n is MultiMeshInstance3D:
				var mm := (n as MultiMeshInstance3D).multimesh
				tris += mm.instance_count * (mm.mesh.get_faces().size() / 3)
		print("COST %-26s nodes %5d  triangles %8d" % [k, cats[k].size(), tris])
	for place in ["trailhead", "fork", "ridge", "pines"]:
		w._at = place
		w._settle(Vector3.INF)
		var all: Array = await _measure(120)
		print("COST %-10s all: %.2f ms  %d draws  %d prims" % [place, all[0], all[1], all[2]])
		for k in cats:
			for n in cats[k]:
				n.visible = false
			var r: Array = await _measure(120)
			for n in cats[k]:
				n.visible = true
			print("COST %-10s   without %-26s %.2f ms (-%d draws, -%d prims)" % [place, k, r[0], all[1] - r[1], all[2] - r[2]])
		w.land.show_land(false)
		var sky: Array = await _measure(120)
		w.land.show_land(true)
		print("COST %-10s   without the 1:16 sky render      %.2f ms" % [place, sky[0]])
	quit(0)
