extends SceneTree

## How detailed each kind of garden thing is: triangles drawn (MultiMesh instances counted) and triangles per square
## metre of its bounding box's footprint-ish area (size.x*size.y + size.y*size.z + size.x*size.z), so a pebble and a
## pine can be compared. Grouped by the nearest named ancestor under the garden. Headless is fine:
##   godot --headless --path . --audio-driver Dummy --script tools/detail_census.gd
func _init() -> void:
	call_deferred("_run")


func _tris(m: Mesh) -> int:
	if m == null:
		return 0
	var t := 0
	for s in range(m.get_surface_count()):
		var a := m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += ((idx as PackedInt32Array).size() if idx != null and not (idx as PackedInt32Array).is_empty() else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func _label(g: Node, scene: Node) -> String:
	var n := g.get_parent()
	while n != scene and n.get_parent() != scene and (n.name.begins_with("@") or n.name in ["Head", "Pet", "HEAD", "BODY"]):
		n = n.get_parent()
	return str(n.name).rstrip("0123456789_-").trim_suffix("@") if not str(n.name).begins_with("@") else "(unnamed under %s)" % n.get_parent().name


func _run() -> void:
	Motion.speed = 0.0
	var scene: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(120):
		await process_frame
	var mesh_tris := {}
	var groups := {}
	for g: GeometryInstance3D in scene.find_children("*", "GeometryInstance3D", true, false):
		if not g.is_visible_in_tree() or g.get_viewport() != root:
			continue
		var tris := 0
		var area := 0.0
		if g is MeshInstance3D:
			var m: Mesh = (g as MeshInstance3D).mesh
			if not mesh_tris.has(m):
				mesh_tris[m] = _tris(m)
			tris = mesh_tris[m]
			var s: Vector3 = g.get_aabb().size * g.global_basis.get_scale()
			area = s.x * s.y + s.y * s.z + s.x * s.z
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
			var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
			if not mesh_tris.has(mm.mesh):
				mesh_tris[mm.mesh] = _tris(mm.mesh)
			tris = mesh_tris[mm.mesh] * mm.instance_count
			var s: Vector3 = mm.mesh.get_aabb().size if mm.mesh else Vector3.ZERO
			area = (s.x * s.y + s.y * s.z + s.x * s.z) * mm.instance_count
		else:
			continue
		var k := _label(g, scene)
		if tris >= 3000 and area < 0.1:
			print("ODD ", g.get_path(), " ", (g as MeshInstance3D).mesh.get_class() if g is MeshInstance3D else "", " tris ", tris, " aabb ", g.get_aabb().size)
		if k.begins_with("(unnamed") or k == "Garden":
			var mat: Material = g.material_override
			var what := ""
			if mat is ShaderMaterial:
				what = (mat as ShaderMaterial).shader.resource_path.get_file()
				var tex = (mat as ShaderMaterial).get_shader_parameter("leaf_sheet")
				if tex != null:
					what = "leaves"
			elif mat is StandardMaterial3D:
				what = "solid " + ("%s" % (mat as StandardMaterial3D).albedo_color.to_html(false))
			k = "%s: %s %s" % [k, g.get_class().replace("Instance3D", ""), what]
		if not groups.has(k):
			groups[k] = [0, 0, 0.0]
		groups[k][0] += 1
		groups[k][1] += tris
		groups[k][2] += area
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	var total := 0
	for k in keys:
		total += groups[k][1]
	for k in keys.slice(0, 45):
		var g: Array = groups[k]
		print("DETAIL %-34s draws %4d  tris %8d  tris/m2 %8.0f" % [k, g[0], g[1], g[1] / maxf(g[2], 0.01)])
	print("DETAIL total tris ", total)
	quit()
