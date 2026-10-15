extends SceneTree

## Reopens the bake in its own process and checks the foliage is really in it (tools/foliage_validate.gd), and that
## the leaf counts match what the bake recorded from its sources (build/cache_manifest.json "foliage").
## Self-test first: a populated MultiMesh baked headless must be caught (it saves empty - the missing-leaves bug).
##   godot --headless --audio-driver Dummy --path . --script tools/foliage_bake_check.gd
## Exit 1 on any problem.
const V := preload("res://tools/foliage_validate.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fails := 0
	# 1. the self-test: the regression this guards against must fail the validator
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 50
	for i in range(50):
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(i, 0, 0)))
	var probe := BakedData.new()
	probe.items = {"probe": [ArrayMesh.new(), mm]}
	var tmp := "user://foliage_probe.res"
	ResourceSaver.save(probe, tmp, ResourceSaver.FLAG_COMPRESS)
	var probe_back := ResourceLoader.load(tmp, "", ResourceLoader.CACHE_MODE_IGNORE) as BakedData
	var caught: Array = V.check(probe_back)["problems"]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	print("%s self-test: a populated MultiMesh in a bake is rejected (%d problem(s))" % ["PASS" if caught.size() > 0 else "FAIL", caught.size()])
	if caught.is_empty():
		fails += 1
	# 2. the real bake, reopened here
	var data := ResourceLoader.load(BakeCache.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BakedData
	if data == null:
		print("FAIL cannot load %s" % BakeCache.PATH)
		quit(1)
		return
	var r := V.check(data)
	for p in (r["problems"] as Array).slice(0, 20):
		print("FAIL ", p)
	fails += (r["problems"] as Array).size()
	print("bake: %d leaf sets, %d leaves, %d meshes; by kind %s" % [r["leaf_sets"], r["leaves"], r["meshes"], r["by_kind"]])
	# 3. against what the bake recorded from its sources
	var man_path := "res://build/cache_manifest.json"
	if FileAccess.file_exists(man_path):
		var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(man_path))
		var want: Dictionary = man.get("foliage", {})
		if want.is_empty():
			print("FAIL the manifest has no foliage counts (rebake with tools/bake_cache.gd)")
			fails += 1
		else:
			var ok: bool = int(want["leaves"]) == r["leaves"] and int(want["leaf_sets"]) == r["leaf_sets"]
			print("%s leaf counts match the bake's sources (%d sets, %d leaves)" % ["PASS" if ok else "FAIL", int(want["leaf_sets"]), int(want["leaves"])])
			if not ok:
				fails += 1
	else:
		print("FAIL no build/cache_manifest.json (rebake with tools/bake_cache.gd)")
		fails += 1
	print("foliage_bake_check: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	quit(0 if fails == 0 else 1)
