extends SceneTree

## Desktop lower bound for save work (JSON + FileAccess; Web adds IndexedDB in WebSave.put). Uses a private temp save.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("HEDGEPETS_SAVE", "user://perf_save_trace.json")
	OS.set_environment("HEDGEPETS_NO_PREBUILD", "1")
	var garden := (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	if not garden.is_built:
		await garden.built
	garden.set_process_unhandled_input(false)
	var samples: Array[float] = []
	for i in range(12):
		var started := Time.get_ticks_usec()
		garden.game.save()
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
		await process_frame
	var ordered := samples.duplicate()
	ordered.sort()
	var started := Time.get_ticks_usec()
	garden.game.save(true)
	var forced := (Time.get_ticks_usec() - started) / 1000.0
	print("SAVE frames %d p50 %.2f p95 %.2f max %.2f ms forced %.2f ms bytes %d" % [samples.size(), ordered[ordered.size() / 2],
		ordered[int(ordered.size() * 0.95)], ordered[-1], forced, FileAccess.get_file_as_bytes("user://perf_save_trace.json").size()])
	quit()
