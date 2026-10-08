extends SceneTree

## How long the garden takes to build, part by part (a phone is several times slower than this machine).
##   godot --headless --path . --script tools/boot_time.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var t0 := Time.get_ticks_msec()
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	print("garden built in %d ms" % (Time.get_ticks_msec() - t0))
	var parts: Dictionary = g.boot_ms
	var keys: Array = parts.keys()
	keys.sort_custom(func(a, b) -> bool: return parts[a] > parts[b])
	for k in keys:
		print("  %-18s %6d ms" % [k, parts[k]])
	quit()
