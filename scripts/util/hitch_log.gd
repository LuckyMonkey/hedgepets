class_name HitchLog
extends RefCounted

## Frame-time evidence shared by the live game and tools/pan_trace.gd. Expensive synchronous operations add a tag
## while they run; Quality closes the frame on its next _process call. Live play keeps only aggregated samples and
## the last few long frames. No player data is recorded.

const LIVE_HITCH_MS := 100.0
const REPORT_SECONDS := 30.0
const MAX_HITCHES := 24

static var _frame_tags := {}                         # tag -> measured span in ms (0 when it is only a marker)
static var _last_tags: Array[String] = []
static var _hitches: Array = []
static var _samples: Array[float] = []
static var _moving: Array[bool] = []
static var _report_time := 0.0
static var _camera_moving := false
static var _last_memory := -1.0


static func tag(what: String) -> void:
	if what != "":
		_frame_tags[what.left(48)] = maxf(float(_frame_tags.get(what.left(48), 0.0)), 0.0)


static func begin(what: String) -> int:
	tag(what)
	return Time.get_ticks_usec()


static func end(what: String, started_usec: int) -> float:
	var ms := (Time.get_ticks_usec() - started_usec) / 1000.0
	_frame_tags[what.left(48)] = maxf(float(_frame_tags.get(what.left(48), 0.0)), ms)
	return ms


static func camera_moving(on: bool) -> void:
	_camera_moving = _camera_moving or on


## Called near the beginning of a frame, so the tags and camera flag belong to the frame that just ended.
static func frame(delta: float, garden: Node) -> void:
	var ms := delta * 1000.0
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	if _last_memory >= 0.0 and memory - _last_memory > 4.0 * 1024.0 * 1024.0:
		_frame_tags["allocation"] = (memory - _last_memory) / (1024.0 * 1024.0)
	_last_memory = memory
	_last_tags = _format_tags(_frame_tags)
	_samples.append(ms)
	_moving.append(_camera_moving)
	if ms >= LIVE_HITCH_MS:
		_hitches.append({"ms": snappedf(ms, 0.1), "moving": _camera_moving, "tags": _last_tags.duplicate()})
		if _hitches.size() > MAX_HITCHES:
			_hitches.pop_front()
	_frame_tags.clear()
	_camera_moving = false
	_report_time += delta
	if _report_time >= REPORT_SECONDS:
		_report(garden)


static func last_tags() -> Array[String]:
	return _last_tags.duplicate()


static func hitches() -> Array:
	return _hitches.duplicate(true)


static func clear() -> void:
	_frame_tags.clear()
	_last_tags.clear()
	_hitches.clear()
	_samples.clear()
	_moving.clear()
	_report_time = 0.0
	_camera_moving = false
	_last_memory = -1.0


static func _format_tags(tags: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for what: String in tags:
		var span := float(tags[what])
		out.append("%s:%.1fms" % [what, span] if span >= 0.05 else what)
	out.sort()
	return out


static func _report(garden: Node) -> void:
	_report_time = 0.0
	if _samples.is_empty():
		return
	var ordered := _samples.duplicate()
	ordered.sort()
	var over50 := 0
	var moving_frames := 0
	var moving_over50 := 0
	var moving_max := 0.0
	for i in range(_samples.size()):
		var ms := _samples[i]
		if ms > 50.0:
			over50 += 1
		if _moving[i]:
			moving_frames += 1
			moving_max = maxf(moving_max, ms)
			if ms > 50.0:
				moving_over50 += 1
	var size := Vector2.ZERO if garden == null else garden.get_viewport().get_visible_rect().size
	# go keeps an event's data only under 600 bytes: the last three long frames, each one short line ("412 m pet_build:Gerald")
	var recent: Array[String] = []
	for h: Dictionary in _hitches.slice(maxi(0, _hitches.size() - 3)):
		var tags: Array = (h["tags"] as Array).slice(0, 4)
		recent.append(("%d%s %s" % [int(h["ms"]), " m" if h["moving"] else "", ",".join(tags)]).left(90))
	_hitches.clear()
	var quality := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Quality")
	var detail := str(quality.tier_name()) if quality != null else "unknown"
	Telemetry.event("frame_time", {"frames": ordered.size(), "p50": snappedf(ordered[ordered.size() / 2], 0.1),
		"p95": snappedf(ordered[int(ordered.size() * 0.95)], 0.1), "max": snappedf(ordered[-1], 0.1),
		"over50": over50, "moving": moving_frames, "moving_over50": moving_over50,
		"moving_max": snappedf(moving_max, 0.1), "detail": detail,
		"w": int(size.x), "h": int(size.y), "dpr": _device_pixel_ratio(), "hitches": recent})
	_samples.clear()
	_moving.clear()


static func _device_pixel_ratio() -> float:
	if not OS.has_feature("web"):
		return 1.0
	var dpr = JavaScriptBridge.eval("window.devicePixelRatio || 1")
	return snappedf(float(dpr) if dpr != null else 1.0, 0.1)
