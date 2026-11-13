extends SceneTree

## Woods frame trace: a quiet stand, slow and fast camera turns, and two walks through
## the normal trail choices. It records wall-clock frame spans, frames over 33 ms, and
## the HitchLog tags attached to those frames.
##
## Headless:
##   HEDGEPETS_FRESH=1 ~/.local/bin/godot --headless --audio-driver Dummy --path . --script tools/woods_trace.gd
## Windowed software GL is the same command under the private X server from the woods brief.

var garden: Node
var woods: Node
var rows: Array = [] # [phase, ms, tags]


func _init() -> void:
	call_deferred("_run")


func _frame(phase: String) -> void:
	var started := Time.get_ticks_usec()
	await process_frame
	var ms := float(Time.get_ticks_usec() - started) / 1000.0
	rows.append([phase, ms, HitchLog.last_tags()])


func _frames(phase: String, count: int) -> void:
	for i in count:
		await _frame(phase)


func _turn(phase: String, amount: float, count := 90) -> void:
	woods._goal_yaw += amount
	await _frames(phase, count)


func _walk(phase: String, to: String) -> void:
	var way: Dictionary = woods._way_to(to)
	if way.is_empty():
		print("TRACE missing way %s from %s" % [to, woods._at])
		return
	woods.walk(way)
	var limit := 420
	while not woods._walking.is_empty() and limit > 0:
		await _frame(phase)
		limit -= 1
	if limit == 0:
		print("TRACE walk timeout %s -> %s" % [woods._at, to])


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_NO_PREBUILD", "1")
	OS.low_processor_usage_mode_sleep_usec = 0
	Motion.speed = 0.0
	garden = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	woods = garden.woods
	woods.build_now()
	await woods.enter()
	HitchLog.clear()
	# Give the first post-entry frame and the renderer's warm-up work a place in the
	# trace, but start the reported samples after it.
	await _frames("warmup", 30)
	rows.clear()

	for cycle in range(2):
		await _frames("stand_%d" % (cycle + 1), 90)
		await _turn("turn_slow_%d" % (cycle + 1), 0.35)
		await _turn("turn_fast_%d" % (cycle + 1), 1.4, 45)
		if cycle == 0:
			await _walk("walk_to_fork", "fork")
		else:
			await _walk("walk_to_nursery", "nursery")

	var times: Array[float] = []
	var over33 := 0
	var tag_counts := {}
	for row: Array in rows:
		times.append(float(row[1]))
		if float(row[1]) > 33.0:
			over33 += 1
			for tag: String in row[2]:
				tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
	times.sort()
	var n := times.size()
	print("TRACE woods frames %d p50 %.1f p95 %.1f max %.1f over33 %d" % [n, times[n / 2], times[int(n * 0.95)], times[-1], over33])
	var keys: Array = tag_counts.keys()
	keys.sort()
	for tag in keys:
		print("TRACE woods over33 tag %s count %d" % [tag, tag_counts[tag]])
	for row: Array in rows:
		if float(row[1]) > 33.0:
			print("TRACE woods slow %.1f ms %s %s" % [row[1], row[0], ",".join(row[2])])
	quit(0)
