extends SceneTree

## Headless quality guard: estimate the woods primitives submitted for each tier from visible scene geometry.
## MultiMeshes use their tier-controlled visible instance count; camera range and a conservative screen frustum
## reject patches the renderer would cull. This does not replace the real-window cost probe, but it catches a tier
## that accidentally leaves the same woods geometry active.

func _init() -> void:
	call_deferred("_run")


var _triangles := {}


func _mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var id := mesh.get_instance_id()
	if not _triangles.has(id):
		_triangles[id] = mesh.get_faces().size() / 3
	return int(_triangles[id])


func _multimesh_centre(node: MultiMeshInstance3D) -> Vector3:
	if node.has_meta("woods_local_centre"):
		return node.get_meta("woods_local_centre")
	if node.has_meta("tier_check_centre"):
		return node.get_meta("tier_check_centre")
	var centre := Vector3.ZERO
	var samples := 0
	var step := maxi(1, ceili(node.multimesh.instance_count / 64.0))
	for i in range(0, node.multimesh.instance_count, step):
		centre += node.multimesh.get_instance_transform(i).origin
		samples += 1
	centre /= maxf(samples, 1)
	node.set_meta("tier_check_centre", centre)
	return centre


func _in_view(node: GeometryInstance3D, cam: Camera3D) -> bool:
	if not node.is_visible_in_tree() or node.get_viewport() != cam.get_viewport():
		return false
	var box := node.get_aabb()
	var leaf := str(node.get_meta("woods_lod_kind", "")) == "leaves"
	# The dummy renderer does not expose a useful MultiMesh AABB. Woods generation records the authored
	# patch centre before upload; the transform sample is only a fallback for renderer-backed runs.
	var centre := node.global_transform * _multimesh_centre(node) if leaf else node.global_transform * box.get_center()
	var distance := centre.distance_to(cam.global_position)
	if node.visibility_range_end > 0.0 and distance > node.visibility_range_end:
		return false
	# Visibility range, streamed parent visibility, and visible_instance_count are deterministic headlessly.
	# Leave leaf-card frustum culling to the real-window benchmark because Dummy exposes no usable bounds.
	if leaf:
		return true
	if cam.is_position_behind(centre):
		return false
	var screen := cam.unproject_position(centre)
	var size := cam.get_viewport().get_visible_rect().size
	var margin := size * 0.4                         # patch centres just off-screen can still cover the edge
	return screen.x >= -margin.x and screen.y >= -margin.y and screen.x <= size.x + margin.x and screen.y <= size.y + margin.y


func _count(root_node: Node, cam: Camera3D) -> Dictionary:
	var triangles := 0
	var draws := 0
	var leaves := 0
	var leaf_nodes := 0
	var visible_leaf_nodes := 0
	for node in root_node.find_children("*", "", true, false):
		if not node is GeometryInstance3D:
			continue
		var leaf := str(node.get_meta("woods_lod_kind", "")) == "leaves"
		if leaf:
			leaf_nodes += 1
		if not _in_view(node, cam):
			continue
		if leaf:
			visible_leaf_nodes += 1
		var mesh: Mesh
		var instances := 1
		if node is MultiMeshInstance3D:
			var mm := (node as MultiMeshInstance3D).multimesh
			if mm == null:
				continue
			mesh = mm.mesh
			instances = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			if leaf:
				leaves += instances
		elif node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		else:
			continue
		triangles += _mesh_triangles(mesh) * instances
		draws += mesh.get_surface_count()
	return {"triangles": triangles, "draws": draws, "leaf_instances": leaves, "leaf_nodes": leaf_nodes, "visible_leaf_nodes": visible_leaf_nodes}


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_HOUR", "16.5")
	Motion.speed = 0.0
	var harness := Node.new()
	harness.name = "TierHarness"
	root.add_child(harness)
	current_scene = harness
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	harness.add_child(garden)
	if not garden.is_built:
		await garden.built
	garden.woods.build_now()
	await garden.woods.enter()
	var quality := root.get_node("Quality")
	quality.enabled = false
	var counts := {}
	for tier in ["low", "medium", "high"]:
		quality.set_tier(tier)
		quality.apply_current()
		await process_frame
		counts[tier] = _count(garden.woods, garden.woods.cam)
		print("TIER_PRIMITIVES %s %s" % [tier, JSON.stringify(counts[tier])])
	var low := int(counts["low"]["triangles"])
	var medium := int(counts["medium"]["triangles"])
	var low_leaves := int(counts["low"]["leaf_instances"])
	var medium_leaves := int(counts["medium"]["leaf_instances"])
	var ok := low <= 400000 and low_leaves < int(medium_leaves * 0.3)
	print("PASS tier_primitives" if ok else "FAIL tier_primitives: low %d, medium %d, leaf instances %d / %d" % [low, medium, low_leaves, medium_leaves])
	quit(0 if ok else 1)
