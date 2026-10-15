extends SceneTree

const FoliageValidate := preload("res://tools/foliage_validate.gd")

## Rebuild res://assets/baked/garden.res: build the garden once while recording every foliage mass / leaf set and
## every stone mesh, save it, read it back and check every entry round-trips exactly, then time a cached startup.
## Run after changing the foliage / anatomy code or the garden's scenery, and before every export.
##   godot --headless --path . --script tools/bake_cache.gd
func _init() -> void:
	call_deferred("_run")


func _arrays_equal(a: Variant, b: Variant) -> bool:
	if a is MultiMesh:
		return a.instance_count == b.instance_count and a.buffer == b.buffer
	if a is Mesh:
		if a.get_surface_count() != b.get_surface_count():
			return false
		for s in range(a.get_surface_count()):
			var x: Array = a.surface_get_arrays(s)
			var y: Array = b.surface_get_arrays(s)
			if x[Mesh.ARRAY_VERTEX] != y[Mesh.ARRAY_VERTEX] or x[Mesh.ARRAY_INDEX] != y[Mesh.ARRAY_INDEX]:
				return false
		return true
	if a is Array:
		for i in range(a.size()):
			if not _arrays_equal(a[i], b[i]):
				return false
		return true
	return a == b


## build/cache_manifest.json: every entry's label, generator, type and size (raw, and zstd as the .res stores it),
## and totals by label - what the cache is made of, measured.
func _manifest(data: BakedData, file_bytes: int, foliage: Dictionary) -> void:
	var entries: Array = []
	var by := {}
	for k in data.items:
		var v = data.items[k]
		var raw := var_to_bytes_with_objects(v)
		var z := raw.compress(FileAccess.COMPRESSION_ZSTD).size()
		var lab: Array = BakeCache.labels.get(k, ["?", "?"])
		var cls: String = v.get_class() if v is Object else type_string(typeof(v))
		entries.append({"key": k, "label": lab[0], "generator": lab[1], "type": cls, "raw": raw.size(), "zstd": z})
		var group: String = "pet" if str(lab[0]).begins_with("pet:") else str(lab[0])
		if not by.has(group):
			by[group] = {"entries": 0, "raw": 0, "zstd": 0}
		by[group]["entries"] += 1
		by[group]["raw"] += raw.size()
		by[group]["zstd"] += z
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open("res://build/cache_manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"file_bytes": file_bytes, "by_label": by, "foliage": foliage, "entries": entries}, " "))
	f.close()
	for g in by:
		print("manifest: %-8s %5d entries  raw %6.1f MB  zstd %6.1f MB" % [g, by[g]["entries"], by[g]["raw"] / 1048576.0, by[g]["zstd"] / 1048576.0])


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	BakeCache.reset()
	BakeCache.recording = true
	var t0 := Time.get_ticks_msec()
	BakeCache.label = "garden"
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	BakeCache.label = "woods"
	g.woods.build_now()                                  # the woods too: their trees (code-driven, from this cache) and things
	var live_ms := Time.get_ticks_msec() - t0
	# every pet in its own plant: the first one (Gerald) is built at startup, the rest whenever they arrive
	var t1 := Time.get_ticks_msec()
	var starters_only := HedgePetNode.pets_baked() == "starters"   # compact profile: visitors grow from their recipes
	for p: CharacterArtProfile in CharacterArtProfile.roster():
		if starters_only and not p.starts_resident:
			continue
		BakeCache.label = "pet:" + p.pet_name
		var n := HedgePetNode.new()
		root.add_child(n)
		n.setup(p)
		n.queue_free()
	print("built all %d pets live in %d ms" % [CharacterArtProfile.roster().size(), Time.get_ticks_msec() - t1])
	var recorded: BakedData = BakeCache._data
	var src := FoliageValidate.check(recorded)          # the leaves as the generators made them
	var err := BakeCache.save()
	print("recorded %d entries in a live build of %d ms; saved %s: %s" % [recorded.items.size(), live_ms, BakeCache.PATH, error_string(err)])
	g.queue_free()
	await process_frame
	# read it back from disk and compare every entry
	var back := ResourceLoader.load(BakeCache.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BakedData
	var bad := 0
	for k in recorded.items:
		if not back.items.has(k) or not _arrays_equal(recorded.items[k], back.items[k]):
			bad += 1
	print("round trip: %d / %d entries identical" % [recorded.items.size() - bad, recorded.items.size()])
	# a successful bake isn't a complete one: the foliage must really be in the file
	var got := FoliageValidate.check(back)
	for p in (src["problems"] + got["problems"]).slice(0, 20):
		print("FOLIAGE PROBLEM: ", p)
	var foliage_ok: bool = (src["problems"] as Array).is_empty() and (got["problems"] as Array).is_empty() \
		and src["leaves"] == got["leaves"] and src["leaf_sets"] == got["leaf_sets"] and got["leaves"] > 0
	print("foliage: %s - %d leaf sets, %d leaves made; %d sets, %d leaves read back %s" % ["OK" if foliage_ok else "FAILED",
		src["leaf_sets"], src["leaves"], got["leaf_sets"], got["leaves"], got["by_kind"]])
	# a cached startup
	BakeCache.recording = false
	BakeCache.reset()
	t0 = Time.get_ticks_msec()
	var g2: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g2)
	print("cached startup: %d ms (cache hits %d, misses %d)" % [Time.get_ticks_msec() - t0, BakeCache.hits, BakeCache.misses])
	var size := FileAccess.get_file_as_bytes(BakeCache.PATH).size()
	print("cache file: %.1f MB" % (size / 1048576.0))
	_manifest(recorded, size, {"leaf_sets": src["leaf_sets"], "leaves": src["leaves"], "by_kind": src["by_kind"]})
	quit(0 if bad == 0 and err == OK and foliage_ok else 1)
