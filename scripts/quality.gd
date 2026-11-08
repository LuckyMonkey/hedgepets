extends Node

## Invisible renderer detail selector. The tier is chosen before the garden is ready from the adapter/CPU,
## refined by a short startup benchmark, remembered for two weeks, and then corrected slowly from frame medians.
## Quality changes are renderer-only; the world, motion and save state never depend on them.

signal tier_changed(name: String)

const LOW := 0
const MEDIUM := 1
const HIGH := 2
const SETTINGS := "user://settings.cfg"
const SAMPLE_SECONDS := 0.5
const BENCH_FRAMES := 60
const REMEMBER_SECONDS := 14.0 * 24.0 * 3600.0

var tier := MEDIUM
var enabled := true
var benchmark_ms := 0.0
var _root: Node
var _sample: Array[float] = []
var _sample_time := 0.0
var _bad := 0.0
var _good := 0.0
var _benchmark: Array[float] = []
var _benchmarking := false
var _override := ""
var _hardware_tier := MEDIUM
var _gpu := ""
var _applied := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gpu = RenderingServer.get_video_adapter_name()
	_hardware_tier = _hardware_start_tier()
	_override = _detail_override()
	var remembered := _remembered_tier()
	if _override != "":
		tier = _tier_number(_override)
	elif remembered >= 0:
		tier = remembered
	else:
		tier = _hardware_tier
	_benchmarking = _override == "" and remembered < 0 and OS.get_environment("HEDGEPETS_FRESH") == ""

func _process(delta: float) -> void:
	if not enabled:
		return
	if _root == null or not is_instance_valid(_root) or _root != get_tree().current_scene:
		_root = get_tree().current_scene
		_sample.clear()
		_sample_time = 0.0
		_bad = 0.0
		_good = 0.0
		_applied = false
		if _root != null:
			_apply_tier()
	if _root == null:
		return
	if not _applied and bool(_root.get("is_built")):
		_apply_tier()
		_applied = true
	if _benchmarking:
		_benchmark.append(delta * 1000.0)
		if _benchmark.size() >= BENCH_FRAMES:
			_benchmark.sort()
			benchmark_ms = float(_benchmark[_benchmark.size() / 2])
			_benchmarking = false
			_select_from_benchmark()
		return
	_sample.append(delta * 1000.0)
	_sample_time += delta
	if _sample_time < SAMPLE_SECONDS:
		return
	_sample.sort()
	var median := float(_sample[_sample.size() / 2])
	_sample.clear()
	_sample_time = 0.0
	if median > _bad_limit():
		_bad += SAMPLE_SECONDS
		_good = 0.0
	elif median < _good_limit():
		_good += SAMPLE_SECONDS
		_bad = 0.0
	else:
		_bad = 0.0
		_good = 0.0
	if _bad >= 5.0 and tier > LOW:
		_bad = 0.0
		set_tier(tier - 1)
	elif _good >= 10.0 and tier < HIGH:
		_good = 0.0
		set_tier(tier + 1)

func tier_name() -> String:
	return ["low", "medium", "high"][clampi(tier, LOW, HIGH)]

func benchmark_value() -> float:
	return benchmark_ms

func set_tier(value: Variant) -> void:
	var next := _tier_number(str(value)) if value is String else clampi(int(value), LOW, HIGH)
	if next == tier and _root != null:
		_apply_tier()
		return
	tier = next
	_apply_tier()
	tier_changed.emit(tier_name())


func apply_current() -> void:
	if _root == null or not is_instance_valid(_root):
		_root = get_tree().current_scene
	_apply_tier()
	if _root != null and _root.find_child("Grass", true, false) != null and _root.find_child("TiltShift", true, false) != null:
		_applied = true

func _apply_tier() -> void:
	if _root == null:
		return
	var view := _root.get_viewport()
	match tier:
		HIGH:
			view.scaling_3d_scale = 1.0
			_set_shadows(true)
			_set_tilt(1.0)
			_set_grass(1.0)
		MEDIUM:
			view.scaling_3d_scale = 1.0
			_set_shadows(false)
			_set_tilt(1.0)
			_set_grass(0.72)
		LOW:
			view.scaling_3d_scale = 0.75
			_set_shadows(false)
			_set_tilt(0.82)
			_set_grass(0.45)
	for node in _all(_root):
		if node.has_method("quality_tier_changed"):
			node.quality_tier_changed(tier_name())

func _set_grass(amount: float) -> void:
	var grass := _root.find_child("Grass", true, false)
	if grass == null or grass.multimesh == null:
		return
	grass.multimesh.visible_instance_count = int(grass.multimesh.instance_count * amount)

func _set_shadows(on: bool) -> void:
	for node in _all(_root):
		if node is DirectionalLight3D:
			var light := node as DirectionalLight3D
			light.shadow_enabled = on

func _set_tilt(amount: float) -> void:
	var layer := _root.find_child("TiltShift", true, false)
	if layer == null or layer.get_child_count() == 0:
		return
	var rect := layer.get_child(0) as ColorRect
	if rect == null or not rect.material is ShaderMaterial:
		return
	var mat := rect.material as ShaderMaterial
	var from := float(mat.get_shader_parameter("quality_mix")) if mat.get_shader_parameter("quality_mix") != null else 1.0
	var tween := Motion.channel(_root, "quality_tilt")
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("quality_mix", v), from, amount, Motion._d(0.6))

func _select_from_benchmark() -> void:
	var chosen := HIGH if benchmark_ms <= 12.0 else MEDIUM if benchmark_ms <= 24.0 else LOW
	if _hardware_tier == LOW:
		chosen = mini(chosen, MEDIUM)
	set_tier(chosen)
	_save_tier()
	Telemetry.event("quality", {"tier": tier_name(), "benchmark_ms": snappedf(benchmark_ms, 0.1), "gpu": _gpu})

func _hardware_start_tier() -> int:
	var cpu := OS.get_processor_count()
	var gpu := _gpu.to_lower()
	if cpu <= 4 or _is_weak_gpu(gpu):
		return LOW
	if _is_high_gpu(gpu):
		return HIGH
	return MEDIUM

func _is_weak_gpu(gpu: String) -> bool:
	for token in ["hd graphics 4", "hd graphics 5", "uhd graphics 5", "mali-g5", "mali-g6", "mali-g7", "adreno 5"]:
		if gpu.contains(token):
			return true
	return false

func _is_high_gpu(gpu: String) -> bool:
	for token in ["nvidia", "geforce", "radeon rx", "apple m", "apple gpu", "adreno 6", "adreno 7"]:
		if gpu.contains(token):
			return true
	return false

func _detail_override() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--detail="):
			var v := arg.trim_prefix("--detail=").to_lower()
			if v in ["low", "medium", "high"]:
				return v
	if OS.has_feature("web"):
		var v := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('detail') || ''")).to_lower()
		if v in ["low", "medium", "high"]:
			return v
	return ""

func _remembered_tier() -> int:
	var c := ConfigFile.new()
	if c.load(SETTINGS) != OK:
		return -1
	var gpu := str(c.get_value("quality", "gpu", ""))
	var stamp := float(c.get_value("quality", "time", 0.0))
	if gpu != _gpu or Time.get_unix_time_from_system() - stamp > REMEMBER_SECONDS:
		return -1
	benchmark_ms = float(c.get_value("quality", "benchmark_ms", 0.0))
	return _tier_number(str(c.get_value("quality", "tier", "medium")))

func _save_tier() -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("quality", "gpu", _gpu)
	c.set_value("quality", "tier", tier_name())
	c.set_value("quality", "benchmark_ms", benchmark_ms)
	c.set_value("quality", "time", Time.get_unix_time_from_system())
	c.save(SETTINGS)

func _tier_number(value: String) -> int:
	match value.to_lower():
		"low": return LOW
		"high": return HIGH
	return MEDIUM

func _bad_limit() -> float:
	return 50.0 if tier == HIGH else 33.0

func _good_limit() -> float:
	return 12.0 if tier == HIGH else 15.0

func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out
