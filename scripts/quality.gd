extends Node

## Browser/mobile safety net. Quality changes only renderer settings; game state and motion are untouched.
## The first downgrade takes two seconds of sustained slow frames, and recovery is deliberately slower so a
## phone does not oscillate while a shader compiles or a woods card is opening.

const BAD_FRAME_MS := 22.0
const GOOD_FRAME_MS := 15.0
const SAMPLE_SECONDS := 0.5
const BAD_SECONDS := 2.0
const GOOD_SECONDS := 5.0

var tier := 0
var enabled := true
var _sample := []
var _sample_time := 0.0
var _bad := 0.0
var _good := 0.0
var _root: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not enabled:
		return
	if _root == null or not is_instance_valid(_root) or _root != get_tree().current_scene:
		_root = get_tree().current_scene
		_sample.clear()
		_sample_time = 0.0
		_bad = 0.0
		_good = 0.0
		if _root != null:
			set_tier("base")
	if _root == null:
		return
	_sample.append(delta * 1000.0)
	_sample_time += delta
	if _sample_time < SAMPLE_SECONDS:
		return
	_sample.sort()
	var median := float(_sample[_sample.size() / 2])
	_sample.clear()
	_sample_time = 0.0
	if median > BAD_FRAME_MS:
		_bad += SAMPLE_SECONDS
		_good = 0.0
	elif median < GOOD_FRAME_MS:
		_good += SAMPLE_SECONDS
		_bad = 0.0
	else:
		_bad = 0.0
		_good = 0.0
	if _bad >= BAD_SECONDS and tier < 3:
		_bad = 0.0
		set_tier(["scale75", "scale60", "notilt"][tier])
	elif _good >= GOOD_SECONDS and tier > 0:
		_good = 0.0
		set_tier(["base", "scale75", "scale60"][tier - 1])

func set_tier(name: String) -> void:
	if _root == null:
		_root = get_tree().current_scene
	if _root == null:
		return
	var view := _root.get_viewport()
	match name:
		"base":
			tier = 0
			view.scaling_3d_scale = 1.0
			_set_shadows(true)
			_set_tilt(1.0)
		"scale75":
			tier = 1
			view.scaling_3d_scale = 0.75
			_set_shadows(true)
			_set_tilt(1.0)
		"scale60":
			tier = 2
			view.scaling_3d_scale = 0.6
			_set_shadows(true)
			_set_tilt(1.0)
		"notilt":
			tier = 3
			view.scaling_3d_scale = 0.6
			_set_shadows(false)
			_set_tilt(0.0)

func _set_shadows(on: bool) -> void:
	for node in _all(_root):
		if node is DirectionalLight3D:
			var light := node as DirectionalLight3D
			if not light.has_meta("quality_shadow"):
				light.set_meta("quality_shadow", light.shadow_enabled)
			light.shadow_enabled = bool(light.get_meta("quality_shadow", false)) and on

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
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("quality_mix", v), from, amount, Motion._d(0.45))

func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out
