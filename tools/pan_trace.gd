extends SceneTree

## Scripted garden-camera hitch trace. Six residents walk while the same helpers used by input drive a slow orbit,
## a fast orbit, and repeated reversals. First-time visitors are built only during the first slow pass; the second
## pass separates build/upload/compile hitches from steady rendering.
##
## Headless CPU: godot --headless --audio-driver Dummy --path . --script tools/pan_trace.gd
## GPU Compatibility: godot --audio-driver Dummy --path . --rendering-method gl_compatibility --disable-vsync \
##                    --resolution 540x960 --script tools/pan_trace.gd

var garden: Node
var results := {}
var arrivals: Array[CharacterArtProfile] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.low_processor_usage_mode_sleep_usec = 0
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_NO_PREBUILD", "1")
	OS.set_environment("HEDGEPETS_HOUR", "16.5")
	seed(20261112)
	HitchLog.clear()
	garden = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	if not garden.is_built:
		await garden.built
	garden.set_process_unhandled_input(false)
	var quality := root.get_node_or_null("Quality")
	if quality != null:
		quality.enabled = false
	_set_six_residents()
	for p: CharacterArtProfile in garden.roster:
		if not garden._nodes.has(p.pet_name):
			arrivals.append(p)
		if arrivals.size() >= 5:
			break
	for k in range(90):
		await process_frame
	results["idle_first"] = await _phase("idle_first", 300, _idle)
	results["idle_second"] = await _phase("idle_second", 300, _idle)
	results["slow_first"] = await _phase("slow_first", 420, _slow_turn, true)
	results["slow_second"] = await _phase("slow_second", 420, _slow_turn)
	results["fast_first"] = await _phase("fast_first", 120, _fast_turn)
	results["fast_second"] = await _phase("fast_second", 120, _fast_turn)
	results["back_first"] = await _phase("back_first", 300, _back_turn)
	results["back_second"] = await _phase("back_second", 300, _back_turn)
	var out := {"renderer": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(),
		"size": var_to_str(root.get_visible_rect().size), "phases": results, "live_hitches": HitchLog.hitches(),
		"miniature_redraws": garden.neighborhood.redraws}
	print("PAN " + JSON.stringify(out))
	var path := OS.get_environment("PAN_OUT")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(out, "\t") + "\n")
			f.close()
	quit()


func _set_six_residents() -> void:
	var n := 0
	for p: CharacterArtProfile in garden.roster:
		if n >= 6:
			break
		garden.game.pet_state[p.pet_name] = "resident"
		garden.game._apply_mode(garden.game._node(p), true)
		n += 1


func _phase(label: String, frames: int, drive: Callable, build_visitors := false) -> Dictionary:
	var samples: Array[float] = []
	var slow: Array = []
	var tags := {}
	var last := Time.get_ticks_usec()
	for i in range(frames):
		drive.call(i, frames)
		if build_visitors and i >= 45 and (i - 45) % 75 == 0:
			var ai := int((i - 45) / 75)
			if ai < arrivals.size():
				var p: CharacterArtProfile = arrivals[ai]
				garden.game.pet_state[p.pet_name] = "noticed"
				garden.game._apply_mode(garden.game._node(p))
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		var frame_tags := HitchLog.last_tags()
		samples.append(ms)
		if ms > 50.0:
			slow.append({"frame": i, "ms": snappedf(ms, 0.1), "tags": frame_tags})
		for what: String in frame_tags:
			var key := what.get_slice(":", 0)
			tags[key] = int(tags.get(key, 0)) + 1
	var ordered := samples.duplicate()
	ordered.sort()
	var over33 := samples.filter(func(v: float) -> bool: return v > 33.0).size()
	var over50 := samples.filter(func(v: float) -> bool: return v > 50.0).size()
	var row := {"frames": frames, "p50_ms": snappedf(ordered[frames / 2], 0.01),
		"p95_ms": snappedf(ordered[int(frames * 0.95)], 0.01), "max_ms": snappedf(ordered[-1], 0.01),
		"over33": over33, "over50": over50, "slow": slow, "tags": tags}
	print("PAN %-12s p50 %6.2f  p95 %6.2f  max %7.2f  >33 %d  >50 %d" % [label, row["p50_ms"], row["p95_ms"], row["max_ms"], over33, over50])
	for hitch: Dictionary in slow:
		print("PAN hitch %s frame %d %7.1f ms %s" % [label, hitch["frame"], hitch["ms"], hitch["tags"]])
	return row


func _slow_turn(_i: int, frames: int) -> void:
	garden._turn_by(Vector2(-TAU / (garden.TURN_PER_PX * frames), 0.0))


func _idle(_i: int, _frames: int) -> void:
	pass


func _fast_turn(_i: int, frames: int) -> void:
	garden._turn_by(Vector2(-TAU / (garden.TURN_PER_PX * frames), 0.0))


func _back_turn(i: int, frames: int) -> void:
	var direction := 1.0 if int(i / 50) % 2 == 0 else -1.0
	garden._turn_by(Vector2(direction * 1.35, 0.0))
