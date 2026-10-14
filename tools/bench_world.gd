extends SceneTree

## One benchmark run of the world (run each in its own process; tools/bench_world.sh repeats them).
##   BENCH_MODE=procedural  every cached mesh built live (A: the procedural runtime, BakeCache bypassed)
##   BENCH_MODE=cached      the game as shipped (B: BakeCache, assets/baked/garden.res)
##   BENCH_FRAMES=300       frames timed per place (garden, then woods) when there's a real renderer
## Prints one line: BENCH {json}. Same seed, same hour, same camera, the player's save untouched.
func _init() -> void:
	call_deferred("_run")


func _pcts(us: Array) -> Dictionary:
	if us.is_empty():
		return {}
	var s := us.duplicate()
	s.sort()
	var n := s.size()
	var total := 0.0
	for v in s:
		total += v
	var mean := total / n
	var var_sum := 0.0
	for v in s:
		var_sum += (v - mean) * (v - mean)
	var worst := s.slice(int(n * 0.99))                  # the slowest 1% of frames
	var worst_mean := 0.0
	for v in worst:
		worst_mean += v
	worst_mean /= maxf(worst.size(), 1)
	return {"frames": n, "mean_ms": snappedf(mean / 1000.0, 0.001), "p50_ms": snappedf(s[n / 2] / 1000.0, 0.001),
		"p95_ms": snappedf(s[int(n * 0.95)] / 1000.0, 0.001), "p99_ms": snappedf(s[int(n * 0.99)] / 1000.0, 0.001),
		"max_ms": snappedf(s[-1] / 1000.0, 0.001), "stdev_ms": snappedf(sqrt(var_sum / n) / 1000.0, 0.001),
		"avg_fps": snappedf(1e6 / mean, 0.1), "low1_fps": snappedf(1e6 / worst_mean, 0.1)}


func _time_frames(n: int) -> Dictionary:
	for i in range(30):                                  # settle (shaders compiled, first uploads done)
		await process_frame
	var us: Array = []
	var draws := 0.0
	var prims := 0.0
	var last := Time.get_ticks_usec()
	for i in range(n):
		await process_frame
		var now := Time.get_ticks_usec()
		us.append(float(now - last))
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var r := _pcts(us)
	r["draw_calls"] = int(draws / n)
	r["primitives"] = int(prims / n)
	r["cpu_process_ms"] = snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.001)
	return r


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c


func _run() -> void:
	var mode := OS.get_environment("BENCH_MODE") if OS.get_environment("BENCH_MODE") != "" else "cached"
	var frames := int(OS.get_environment("BENCH_FRAMES")) if OS.get_environment("BENCH_FRAMES") != "" else 300
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_HOUR", "16.5")
	seed(20261014)
	BakeCache.reset()
	if mode == "procedural":
		BakeCache._usable = 0                            # no baked data: every mesh built by the generators, as before the cache
	var headless := DisplayServer.get_name() == "headless"
	var out := {"mode": mode, "renderer": RenderingServer.get_video_adapter_name(), "headless": headless,
		"size": var_to_str(root.get_visible_rect().size)}
	var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var t0 := Time.get_ticks_usec()
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	if not g.is_built:
		await g.built
	out["garden_build_ms"] = snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	out["garden_steps_ms"] = g.boot_ms
	out["cache_hits"] = BakeCache.hits
	out["cache_misses"] = BakeCache.misses
	g.set_process_unhandled_input(false)
	await process_frame
	out["garden_nodes"] = _count(g)
	out["garden_mem_mb"] = snappedf((Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1048576.0, 0.1)
	if not headless:
		out["garden_frames"] = await _time_frames(frames)
	var t1 := Time.get_ticks_usec()
	g.woods.build_now()
	out["woods_build_ms"] = snappedf((Time.get_ticks_usec() - t1) / 1000.0, 0.1)
	g.woods.enter()
	for i in range(10):
		await process_frame
	g.woods.set_process_unhandled_input(false)
	out["total_nodes"] = _count(g)
	out["total_mem_mb"] = snappedf((Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1048576.0, 0.1)
	out["peak_mem_mb"] = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0, 0.1)
	if not headless:
		out["woods_frames"] = await _time_frames(frames)
		out["video_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	out["cache_misses_after_woods"] = BakeCache.misses
	print("BENCH " + JSON.stringify(out))
	quit(0)
