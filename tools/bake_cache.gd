extends SceneTree

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


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	BakeCache.reset()
	BakeCache.recording = true
	var t0 := Time.get_ticks_msec()
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	g.woods.build_now()                                  # the woods too: their leafy trees and things bake as well
	var live_ms := Time.get_ticks_msec() - t0
	# every pet in its own plant: the first one (Gerald) is built at startup, the rest whenever they arrive
	var t1 := Time.get_ticks_msec()
	for p: CharacterArtProfile in CharacterArtProfile.roster():
		var n := HedgePetNode.new()
		root.add_child(n)
		n.setup(p)
		n.queue_free()
	print("built all %d pets live in %d ms" % [CharacterArtProfile.roster().size(), Time.get_ticks_msec() - t1])
	var recorded: BakedData = BakeCache._data
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
	# a cached startup
	BakeCache.recording = false
	BakeCache.reset()
	t0 = Time.get_ticks_msec()
	var g2: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g2)
	print("cached startup: %d ms (cache hits %d, misses %d)" % [Time.get_ticks_msec() - t0, BakeCache.hits, BakeCache.misses])
	var size := FileAccess.get_file_as_bytes(BakeCache.PATH).size()
	print("cache file: %.1f MB" % (size / 1048576.0))
	quit(0 if bad == 0 and err == OK else 1)
