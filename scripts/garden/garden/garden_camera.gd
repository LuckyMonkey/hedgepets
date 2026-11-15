extends "res://scripts/garden/garden/garden_pets.gd"

## Garden 6/6 - the camera and input: orbit, pan, zoom, pinch, taps, framing a point.
##
## The camera never jumps: input moves a goal (yaw, elevation, distance, target) and the camera eases toward it
## (Motion.approach / Motion.spring in garden.gd's _process). Drag to orbit, two fingers to pan and pinch, wheel to
## zoom. frame_point() is how the game asks the camera to look at something (a new arrival, a tapped pet).
##
## Part of the garden layer chain (the full order is at the top of scripts/garden/garden.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var _target := Vector3(0.0, 0.0, -0.8)
var _distance := 12.5
## The camera eases toward these (Motion.approach): input moves the goal, never the camera itself; a drag that ends
## moving keeps gliding a little.
var _goal_target := Vector3(0.0, 0.0, -0.8)
var _yaw := 0.0
var _goal_yaw := 0.0
var _elev := deg_to_rad(49.5)
var _goal_elev := deg_to_rad(49.5)
var _goal_distance := 12.5
var _press_at := Vector2.INF
var _dragged := false
func _place_camera() -> void:
	# up close the camera comes down toward eye level, so a close-up shows faces, not tops of heads
	var close := clampf((12.5 - _distance) / (12.5 - ZOOM_MIN), 0.0, 1.0)
	var el := _elev - close * close * 0.45
	var dir := Vector3(sin(_yaw) * cos(el), sin(el), cos(_yaw) * cos(el))
	camera.position = _target + dir * _distance
	camera.look_at(_target, Vector3.UP)


# ------------------------------------------------------------------ input: pan, zoom, tap a pet
## Controls. Touch: one finger on the top half of the screen turns around the garden and tilts a little; on the bottom
## half it pans, the ground following your hand (an invisible line; nobody needs to be told). Two fingers: pan and
## pinch to zoom. Mouse: left drag turns, right drag pans. Wheel / pinch: zoom, from close-up to the whole garden.
## Keys: WASD or arrows pan, Q / E turn, R / F zoom.
const TURN_PER_PX := 0.0025
const ZOOM_MIN := 4.5
const ZOOM_MAX := 24.0
var _touches := {}                 # touch index -> position
var _holder := ""                  # what this press works: "arrange" (moving something you built), "grab" (junk), ""
var _pan_drag := false             # this finger started on the bottom half: it pans
var _pinch := 0.0


func _unhandled_input(event: InputEvent) -> void:
	# On touch screens Godot also sends each touch as a mouse event (the HUD's buttons rely on that). The garden takes
	# the touch itself and ignores the copy, or a one-finger turn would count twice.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	# a touch that lands on the HUD belongs to the HUD (its button got the mouse copy), not to the garden under it
	if event is InputEventScreenTouch and event.pressed and game != null and game.ui_blocks(event.position):
		return
	if event is InputEventMagnifyGesture:
		_zoom_by(1.0 / event.factor)
		return
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoom_by(0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.12)
		return
	# two fingers: pan with their midpoint, pinch to zoom; a single finger never turns while two are down
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch = _touch_spread()
		if _touches.size() >= 2:
			_press_at = Vector2.INF              # a second finger cancels the tap / turn
			return
	if event is InputEventScreenDrag and _touches.size() >= 2:
		var before := _touch_mid()
		_touches[event.index] = event.position
		_pan_by((_touch_mid() - before))
		var spread := _touch_spread()
		if _pinch > 1.0 and spread > 1.0:
			_zoom_by(_pinch / spread)
		_pinch = spread
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
	if event is InputEventMouseMotion:
		_hover = event.position
	# right mouse button: pan
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_pan_by(event.relative)
		return
	if _touches.size() >= 2:
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if pressed:
		_press_at = event.position
		_dragged = false
		_pan_drag = event is InputEventScreenTouch and event.position.y > get_viewport().get_visible_rect().size.y * 0.5
		_holder = ""
		if game != null and game.arrange_begin(event.position):     # something you built, with 🧺: move or turn it
			_holder = "arrange"
		elif game != null and game.grab.begin(event.position):      # on a piece of junk: work it, don't turn
			_holder = "grab"
		elif game != null and game.tool == "water":                  # the watering can pours where you hold it
			_holder = "pour"
			game.pour_begin(event.position)
	elif released and _press_at != Vector2.INF:
		if _holder == "arrange":
			game.arrange_end(event.position, _dragged)
		elif _holder == "grab":
			if not game.grab.end(event.position):
				_tap(event.position)
		elif _holder == "pour":
			if not game.pour_end(_dragged):
				_tap(event.position)
		elif not _dragged:
			_tap(event.position)
		_press_at = Vector2.INF
		_holder = ""
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _press_at != Vector2.INF:
		if event.position.distance_to(_press_at) > 10.0:
			_dragged = true
		if _holder == "arrange":
			game.arrange_move(event.position)
			return
		if _holder == "grab":
			game.grab.move(event.position)
			return
		if _holder == "pour":
			game.pour_move(event.position)
			return
		if _dragged and _pan_drag:
			_pan_by(event.relative)
		elif _dragged:
			_turn_by(event.relative)


func _touch_mid() -> Vector2:
	var m := Vector2.ZERO
	for k in _touches:
		m += _touches[k]
	return m / maxf(1.0, _touches.size())


func _touch_spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


## Move the view by a screen drag: the ground follows the hand (drag right, the garden moves right).
func _pan_by(screen: Vector2) -> void:
	var k := _goal_distance * 0.0016
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var toward_camera := Vector3(sin(_yaw), 0, cos(_yaw))
	_goal_target = _clamp_target(_goal_target - right * screen.x * k - toward_camera * screen.y * k)


func _turn_by(screen: Vector2) -> void:
	_goal_yaw -= screen.x * TURN_PER_PX
	_goal_elev = clampf(_goal_elev + screen.y * 0.002, deg_to_rad(28), deg_to_rad(72))


## A tap on the lawn (or a thing on it) with ✋ brings the camera over to work there: the view eases to the spot,
## nudged towards what's around it so the things you can work on are in frame, and comes in to a comfortable working
## distance if it was further out. Only goals: the camera's springs do the easing, and any drag takes over at once.
const WORK_DISTANCE := 8.0
const WORK_ELEV := 52.0

func frame_point(p: Vector3) -> void:
	var near := Vector2.ZERO
	var n := 0
	for t: Dictionary in things:
		var at: Vector2 = t["at"]
		if at.distance_to(Vector2(p.x, p.z)) < 3.5:
			near += at
			n += 1
	var aim := Vector2(p.x, p.z)
	if n > 0:
		aim = aim.lerp(near / n, 0.35)
	_goal_target = _clamp_target(Vector3(aim.x, 0.0, aim.y))
	if _goal_distance > WORK_DISTANCE:
		_goal_distance = WORK_DISTANCE
	_goal_elev = lerpf(_goal_elev, deg_to_rad(WORK_ELEV), 0.5)


func _zoom_by(factor: float) -> void:
	_goal_distance = clampf(_goal_distance * factor, ZOOM_MIN, ZOOM_MAX)


func _keys(delta: float) -> void:
	var pan := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A): pan.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): pan.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): pan.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): pan.y += 1.0
	if pan != Vector2.ZERO:
		_pan_by(-pan.limit_length(1.0) * 520.0 * delta)
	if Input.is_physical_key_pressed(KEY_Q): _goal_yaw += 0.9 * delta
	if Input.is_physical_key_pressed(KEY_E): _goal_yaw -= 0.9 * delta
	if Input.is_physical_key_pressed(KEY_R): _zoom_by(1.0 - 1.2 * delta)
	if Input.is_physical_key_pressed(KEY_F): _zoom_by(1.0 + 1.2 * delta)


func _tap(at: Vector2) -> void:
	var best: HedgePetNode = null
	var best_d := 90.0
	for node in pets:
		if not node.visible:
			continue
		var d := camera.unproject_position(node.global_position + Vector3(0, 0.6, 0)).distance_to(at)
		if d < best_d:
			best_d = d
			best = node
	if game != null and game.tap(at, best if best_d < 90.0 else null):
		return
	if best != null:
		best.tap()
		best.look_point = camera.global_position


## Where a screen point lands on the lawn (y = 0).
func ground_point(at: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(at)
	var dir := camera.project_ray_normal(at)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := -origin.y / dir.y
	return origin + dir * t if t > 0.0 else Vector3.INF
