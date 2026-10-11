extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _walk(n: Node, out: Array) -> void:
	for c in n.get_children():
		out.append(c)
		_walk(c, out)
func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	await process_frame
	var w: Node3D = garden.woods
	w.build_now()
	var all: Array = []
	_walk(w, all)
	var n := 0
	for c in all:
		if not c is GeometryInstance3D or c is MultiMeshInstance3D or c is Label3D or (c as Node3D).position == Vector3.ZERO:
			continue
		var gi := c as GeometryInstance3D
		var box: AABB = gi.global_transform * gi.get_aabb()
		var mid := box.get_center() - w.global_position
		var r: float = Vector2(box.size.x, box.size.z).length() * 0.5
		if box.size.y < 0.5 or r > 6.0:
			continue
		if gi.material_override is ShaderMaterial:
			continue                                     # sunbeams (they fade up close)
		# a box, not a ball: test points through its height
		var bad := false
		for f in [0.1, 0.5, 0.9]:
			var p := Vector3(mid.x, box.position.y - w.global_position.y + box.size.y * f, mid.z)
			if not w.eye_clear(p, r * 0.8):
				bad = true
		if bad:
			n += 1
			if n <= 25:
				var par: Node = c.get_parent()
				print("IN THE WAY %s/%s (%s) size %s at %s" % [par.name, c.name, (gi.material_override.resource_name if gi.material_override else ""), box.size, mid])
	print("IN THE WAY total ", n)
	quit(0)
