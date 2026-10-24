extends SceneTree

## Where the frame goes and where it hangs. Headless (CPU: scripts, scene, physics; no GPU):
##   godot --headless --audio-driver Dummy --path . --script tools/hitch_trace.gd
## TRACE_MODE=ablate (default) - a garden with PETS residents (6): the steady frame, then the same with each
##   processing script switched off in turn (the difference is that script's cost per frame).
## TRACE_MODE=enter - the real walk into the woods, every frame over 12 ms (CARD=1: built behind its card on the way
##   in; PREBUILD=1: first 40 s in the garden while the woods prebuild, if hedgepets/woods_prebuild is on).
## TRACE_MODE=woods - each step of arriving in the woods, timed.  TRACE_MODE=pet - one pet's build, piece by piece.
## TRACE_MODE=parts - garden._process piece by piece.
## Headless Godot sleeps ~6.9 ms a frame (no window to draw): this turns that off, so the numbers are the real work.
## Edited garden.gd or woods.gd? Rebake (tools/bake_cache.gd) first, or every pet and tree builds live and it lies.
var frames := int(OS.get_environment("TRACE_FRAMES")) if OS.get_environment("TRACE_FRAMES") != "" else 240
var garden: Node


func _init() -> void:
	call_deferred("_run")


func _ms(n: int) -> float:
	var t := Time.get_ticks_usec()
	for i in range(n):
		await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / n


func _garden(residents: int) -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_NO_PREBUILD", "1")
	garden = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await process_frame
	var n := 0
	for p: CharacterArtProfile in garden.roster:
		if n >= residents:
			break
		garden.game.pet_state[p.pet_name] = "resident"
		garden.game._apply_mode(garden.game._node(p), true)
		n += 1


func _run() -> void:
	OS.low_processor_usage_mode_sleep_usec = 0           # headless sleeps ~6.9 ms a frame otherwise (no window to draw)
	var mode := OS.get_environment("TRACE_MODE")
	if mode == "enter":
		await _enter()
	elif mode == "pet":
		await _pet()
	elif mode == "parts":
		await _parts()
	elif mode == "woods":
		await _woods()
	else:
		await _ablate()
	quit()


func _ablate() -> void:
	await _garden(int(OS.get_environment("PETS")) if OS.get_environment("PETS") != "" else 6)
	await _ms(120)
	var groups := {}                                     # script path (or class) -> nodes processing
	for n: Node in garden.find_children("*", "", true, false) + [garden]:
		if n.is_processing() or n.is_physics_processing():
			var s: Script = n.get_script()
			var key: String = s.resource_path.get_file() if s != null and s.resource_path != "" else n.get_class()
			if not groups.has(key):
				groups[key] = []
			groups[key].append(n)
	var base := await _ms(frames)
	print("TRACE base %.2f ms/frame, %d nodes, %d processing groups, process %.2f ms, physics %.2f ms" % [base,
		garden.find_children("*", "", true, false).size(), groups.size(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	var rows: Array = []
	for key: String in groups:
		for n: Node in groups[key]:
			n.set_process(false)
			n.set_physics_process(false)
		var off := await _ms(frames)
		for n: Node in groups[key]:
			n.set_process(true)
			n.set_physics_process(true)
		rows.append([base - off, key, groups[key].size()])
	rows.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for r in rows:
		print("TRACE %-28s x%-4d saves %6.2f ms/frame" % [r[1], r[2], r[0]])
	garden.set_process(false)
	garden.game.set_process(false)
	print("TRACE all garden+game process off: %.2f ms/frame (engine floor)" % await _ms(frames))


# ------------------------------------------------------------------ play
var _tag := ""                                          # what's going on now (printed with each slow frame)
var _log: Array = []                                    # [ms, tag, t]


func _rec(n: int, tag := "") -> void:
	if tag != "":
		_tag = tag
	var last := Time.get_ticks_usec()
	for i in range(n):
		await process_frame
		var now := Time.get_ticks_usec()
		var why := _tag
		var w: Node = garden.woods if garden != null else null
		if w != null and w._prebuilding:
			why += " | prebuild " + str(w._pre_step)
		_log.append([(now - last) / 1000.0, why, now])
		last = now


func _summary() -> void:
	var ms: Array = []
	for e in _log:
		ms.append(e[0])
	ms.sort()
	var n := ms.size()
	print("TRACE frames %d  p50 %.1f  p95 %.1f  p99 %.1f  max %.1f ms" % [n, ms[n / 2], ms[int(n * 0.95)], ms[int(n * 0.99)], ms[n - 1]])
	var worst := _log.duplicate()
	worst.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for e in worst.slice(0, 25):
		print("TRACE slow %7.1f ms  %s" % [e[0], e[1]])
	var by := {}                                         # time over 20 ms, summed per tag
	for e in _log:
		if e[0] > 20.0:
			by[e[1]] = by.get(e[1], 0.0) + e[0]
	for k in by:
		print("TRACE over20 %8.0f ms in  %s" % [by[k], k])


# ------------------------------------------------------------------ woods: each step of walking in, timed
func _t(what: String, c: Callable) -> void:
	var t := Time.get_ticks_usec()
	await c.call()
	print("TRACE woods %-22s %7.1f ms" % [what, (Time.get_ticks_usec() - t) / 1000.0])


func _woods() -> void:
	await _garden(int(OS.get_environment("PETS")) if OS.get_environment("PETS") != "" else 3)
	await _ms(60)
	var w: Node = garden.woods
	await _t("build_now", func() -> void: await w.build_now())
	await _ms(30)
	await _t("save", func() -> void: garden.game.save())
	await _t("before_away", func() -> void: await w.before_away())
	await _t("pause_garden", func() -> void: w.pause_garden(true))
	w.inside = true
	w.visible = true
	w.cam.make_current()
	w._ui.visible = true
	w.set_process(true)
	await _t("_wild_begin", func() -> void: w._wild_begin())
	w._wild.clear()
	await _t("_refresh_finds", func() -> void: w._refresh_finds())
	await _t("land.show_land", func() -> void: w.land.show_land(true))
	await _t("show_basket", func() -> void: w.show_basket())
	await _t("_settle", func() -> void: w._settle(Vector3.INF))
	w.land.show_land(false)
	await _t("_arrive", func() -> void: w._arrive())
	_log.clear()
	await _rec(240, "woods first frames")
	var i := 0
	for e in _log.slice(0, 40):
		print("TRACE woods frame %2d %6.1f ms" % [i, e[0]])
		i += 1
	_summary()


# ------------------------------------------------------------------ parts: garden._process piece by piece
func _each(what: String, c: Callable, n := 300) -> void:
	var t := Time.get_ticks_usec()
	for i in range(n):
		c.call()
	print("TRACE part %-26s %7.3f ms/frame" % [what, (Time.get_ticks_usec() - t) / 1000.0 / n])


func _parts() -> void:
	await _garden(int(OS.get_environment("PETS")) if OS.get_environment("PETS") != "" else 6)
	await _ms(120)
	var g: Node = garden
	print("TRACE obstacles %d things %d pets %d" % [g.obstacles.size(), g.things.size(), g.pets.size()])
	g.set_process(false)
	var d := 1.0 / 60.0
	_each("walk (all pets)", func() -> void:
		g._solid_frame = -1
		for node in g.pets:
			g._walk(node, d))
	_each("separate (all pets)", func() -> void:
		g._solid_frame = -1
		for node in g.pets:
			if node.visible:
				g._separate(node, d))
	_each("colliders(null,false)", func() -> void: g.colliders(null, false))
	_each("_walk_colliders x6 (cached)", func() -> void:
		for node in g.pets:
			g._walk_colliders(node))
	_each("pet_radius x6", func() -> void:
		for node in g.pets:
			g.pet_radius(node))
	_each("up_there x6", func() -> void:
		for node in g.pets:
			g.perches.up_there(g._wander[node]))
	_each("notice_pointer", func() -> void: g._notice_pointer())
	_each("tend_sun", func() -> void: g._tend_sun(d))
	_each("place_camera", func() -> void: g._place_camera())
	_each("neighborhood.follow", func() -> void: g.neighborhood.follow(g.camera, g.camera.position, d))
	_each("whole _process", func() -> void:
		g._solid_frame = -1
		g._process(d))


# ------------------------------------------------------------------ enter: the real walk into the woods, per frame
func _enter() -> void:
	await _garden(3)
	await _ms(60)
	var w: Node = garden.woods
	if OS.get_environment("PREBUILD") != "":
		w.prebuild()
		_log.clear()
		await _rec(60 * 40, "garden, woods prebuilding")
		_summary()
	elif OS.get_environment("CARD") == "":
		await w.build_now()                              # CARD=1: built on the way in, behind its card
	await _ms(30)
	_log.clear()
	w.enter()
	var t0 := Time.get_ticks_msec()
	await _rec(4000 if OS.get_environment("CARD") == "" else 9000, "entering")
	print("TRACE enter wall %d ms, inside %s" % [Time.get_ticks_msec() - t0, w.inside])
	var i := 0
	for e in _log:
		if e[0] > 12.0:
			print("TRACE enter frame %3d %6.1f ms inside=%s" % [i, e[0], w.inside])
		i += 1
	_summary()


# ------------------------------------------------------------------ pet: one pet's build, piece by piece
func _pet() -> void:
	await _garden(0)
	await _ms(30)
	var names := OS.get_environment("PET_NAMES").split(",") if OS.get_environment("PET_NAMES") != "" else PackedStringArray(["Monarch", "Tuppence", "Gerald"])
	for p: CharacterArtProfile in garden.roster:
		if not p.pet_name in names:
			continue
		var node := HedgePetNode.new()
		garden.add_child(node)
		var t := Time.get_ticks_usec()
		node.setup(p)
		var whole := (Time.get_ticks_usec() - t) / 1000.0
		var h0 := BakeCache.hits
		var again := HedgePetNode.new()
		garden.add_child(again)
		t = Time.get_ticks_usec()
		again.setup(p)
		print("TRACE pet %-10s second build %.1f ms (cache hits %d)" % [p.pet_name, (Time.get_ticks_usec() - t) / 1000.0, BakeCache.hits - h0])
		again.queue_free()
		var head_c: Vector3 = p.regions["HEAD"]["center"]
		var key_dir := Basis.from_euler(p.key_angle * PI / 180.0) * Vector3.FORWARD
		var line := ""
		var leaves := 0
		for rn in p.regions:
			if not p.regions[rn].get("foliage", false):
				continue
			t = Time.get_ticks_usec()
			var built := FoliageBuilder.build(p, rn, head_c, key_dir)
			var b_ms := (Time.get_ticks_usec() - t) / 1000.0
			t = Time.get_ticks_usec()
			node._add_multimesh(node.pet, built["items"], "probe")
			leaves += built["items"].size()
			line += " %s %.1f+%.1f(%d)" % [rn, b_ms, (Time.get_ticks_usec() - t) / 1000.0, built["items"].size()]
		t = Time.get_ticks_usec()
		node._tendrils()
		var tend := (Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		node._build_face()
		print("TRACE pet %-10s whole %6.1f ms | %d leaves | tendrils %.1f face %.1f | build+fill per region:%s" % [p.pet_name, whole, leaves, tend, (Time.get_ticks_usec() - t) / 1000.0, line])
		t = Time.get_ticks_usec()
		node._build_regions()
		print("TRACE pet %-10s regions %.1f ms" % [p.pet_name, (Time.get_ticks_usec() - t) / 1000.0])
		node.queue_free()
