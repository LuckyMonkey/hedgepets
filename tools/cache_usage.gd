extends SceneTree

## Which baked entries does the game ever read? Runs every path that asks the cache - the garden's build, the woods'
## build, all 47 pets materialised - with tracking on, then lists the entries never read (by label/generator, from
## build/cache_manifest.json written by tools/bake_cache.gd). Headless:
##   godot --headless --audio-driver Dummy --path . --script tools/cache_usage.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	BakeCache.reset()
	BakeCache.track = true
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	g.woods.build_now()
	for p: CharacterArtProfile in CharacterArtProfile.roster():
		var n := HedgePetNode.new()
		root.add_child(n)
		n.setup(p)
		n.queue_free()
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/cache_manifest.json"))
	var unused := {}
	var used_bytes := 0
	var unused_bytes := 0
	for e: Dictionary in m["entries"]:
		if BakeCache.touched.has(e["key"]):
			used_bytes += int(e["zstd"])
			continue
		unused_bytes += int(e["zstd"])
		var k := "%s %s" % [str(e["label"]).get_slice(":", 0), e["generator"]]
		if not unused.has(k):
			unused[k] = [0, 0]
		unused[k][0] += 1
		unused[k][1] += int(e["zstd"])
	print("USAGE read %d of %d entries; read %.1f MB zstd, never read %.1f MB zstd" % [BakeCache.touched.size(), m["entries"].size(), used_bytes / 1048576.0, unused_bytes / 1048576.0])
	for k in unused:
		print("USAGE never read: %-46s %5d entries %6.1f MB" % [k, unused[k][0], unused[k][1] / 1048576.0])
	quit(0)
