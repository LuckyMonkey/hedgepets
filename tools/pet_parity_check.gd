extends SceneTree

## Recipe parity: every pet built from its recipe (live: profile + seed through the generators) must be the same pet
## as the baked one - mesh by mesh (vertex, normal, colour, UV, index streams), MultiMesh by MultiMesh (instance
## count and buffer), material by material. Needs a renderer for MultiMesh buffers and a full-roster bake:
##   HEDGEPETS_PETS_BAKED=all godot --headless --path . --script tools/bake_cache.gd
##   xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . --script tools/pet_parity_check.gd
func _init() -> void:
	call_deferred("_run")


func _fingerprint(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "", true, false):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh:
			var m: ArrayMesh = (c as MeshInstance3D).mesh
			var h := ""
			for s in m.get_surface_count():
				h += var_to_bytes(m.surface_get_arrays(s)).hex_encode().sha256_text()
			out.append(["mesh", _name(c), h.sha256_text(), var_to_bytes((c as MeshInstance3D).transform)])
		elif c is MultiMeshInstance3D and (c as MultiMeshInstance3D).multimesh != null:
			var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
			out.append(["mm", _name(c), mm.instance_count, var_to_bytes(mm.buffer).hex_encode().sha256_text(), var_to_bytes((c as MultiMeshInstance3D).transform)])
	return out


## A node's own name, or "" for an auto-generated one (@Class@id: differs between any two builds).
func _name(n: Node) -> String:
	var s := str(n.name)
	return "" if s.begins_with("@") else s


func _build(p: CharacterArtProfile) -> Array:
	var n := HedgePetNode.new()
	root.add_child(n)
	n.setup(p)
	var f := _fingerprint(n)
	n.free()
	return f


func _run() -> void:
	var roster := CharacterArtProfile.roster()
	BakeCache.reset()
	var baked: Array = []
	for p in roster:
		baked.append(_build(p))
	var hits := BakeCache.hits
	BakeCache.reset()
	BakeCache._usable = 0                                # no bake: every pet from its recipe
	BakeCache._memory.clear()
	var bad := 0
	for i in roster.size():
		var live := _build(roster[i])
		if live != baked[i]:
			bad += 1
			print("DIFFERS %s (%d parts baked, %d live)" % [roster[i].pet_name, baked[i].size(), live.size()])
	print("pet_parity_check: %d pets, %d identical, %d differ (baked build used %d cache hits; live used %d)" % [roster.size(), roster.size() - bad, bad, hits, BakeCache.hits])
	quit(0 if bad == 0 and hits > 0 else 1)
