extends SceneTree

## How many distinct shaders the garden draws with: every ShaderMaterial's shader, and every StandardMaterial3D's
## feature set (which is what decides its generated shader). On the web each one is compiled on first draw, so this is
## the number that decides how long the first frames take.
##   godot --headless --path . --script tools/material_census.gd
func _init() -> void:
	call_deferred("_run")


func _key(m: Material) -> String:
	if m is ShaderMaterial:
		return "shader:" + ((m as ShaderMaterial).shader.resource_path if (m as ShaderMaterial).shader != null else "none") + ":" + str((m as ShaderMaterial).shader.get_instance_id() if (m as ShaderMaterial).shader else 0)
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		var tex := []
		for t in range(BaseMaterial3D.TEXTURE_MAX):
			if b.get_texture(t) != null:
				tex.append(t)
		var feats := []
		for f in range(BaseMaterial3D.FEATURE_MAX):
			if b.get_feature(f):
				feats.append(f)
		var flags := []
		for f in range(BaseMaterial3D.FLAG_MAX):
			if b.get_flag(f):
				flags.append(f)
		return "std:t%d s%d c%d d%d b%d tex%s f%s fl%s nx%s" % [b.transparency, b.shading_mode, b.cull_mode, b.depth_draw_mode, b.billboard_mode, tex, feats, flags, str(b.next_pass != null)]
	return m.get_class()


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	await process_frame
	var keys := {}
	var stack: Array = [garden]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mats: Array = []
		if n is GeometryInstance3D:
			var g := n as GeometryInstance3D
			if g.material_override:
				mats.append(g.material_override)
			if g.material_overlay:
				mats.append(g.material_overlay)
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				var mi := n as MeshInstance3D
				for s in mi.mesh.get_surface_count():
					var sm := mi.get_surface_override_material(s)
					if sm == null:
						sm = mi.mesh.surface_get_material(s)
					if sm:
						mats.append(sm)
			if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh and (n as MultiMeshInstance3D).multimesh.mesh:
				var mm := (n as MultiMeshInstance3D).multimesh.mesh
				for s in mm.get_surface_count():
					if mm.surface_get_material(s):
						mats.append(mm.surface_get_material(s))
		elif n is CanvasItem and (n as CanvasItem).material:
			mats.append((n as CanvasItem).material)
		for m: Material in mats:
			while m != null:
				var k := _key(m)
				keys[k] = int(keys.get(k, 0)) + 1
				m = m.next_pass
	var ks := keys.keys()
	ks.sort_custom(func(a, b) -> bool: return keys[a] > keys[b])
	print("distinct shaders: %d" % ks.size())
	for k in ks:
		print("%5d  %s" % [keys[k], k])
	quit(0)
