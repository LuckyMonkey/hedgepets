extends Node2D

## Makes the HedgePet alive. Sits on the "Pet" node, which stands at the pet's feet;
## its children (the base wash, the leaves and the face) draw in canvas pixels and
## are offset back by the feet position, so everything here moves from the feet.
##
## Cheap on purpose: the leafy body is never redrawn for animation; it only gets
## this node's transform (breathing, sway, hop, wiggle). Only the face layer redraws
## each frame, from life_state().

const Creature = preload("res://scripts/creature_definition.gd")

var time := 0.0
var blink := 0.0            # 0 open .. 1 shut
var look := Vector2.ZERO    # where the eyes point, -1..1
var joy := 0.0              # 1 right after a tap, fades
var hop := 0.0              # height of the current hop, px
var _hop_velocity := 0.0
var _squash := 0.0
var _next_blink := 2.0
var _blinks_left := 0
var _look_target := Vector2.ZERO
var _pointer_idle := 99.0
var _next_glance := 1.5
var _next_wiggle := 9.0
var _wiggle := 0.0
var _base_position := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_base_position = position
	_next_blink = _rng.randf_range(1.5, 3.5)


func life_state() -> Dictionary:
	return {"blink": blink, "look": look, "sprout": time * 2.1, "joy": joy, "time": time}


func _process(delta: float) -> void:
	time += delta
	# blinking: every few seconds, sometimes twice in a row
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blinks_left = 2 if _rng.randf() < 0.25 else 1
		_next_blink = _rng.randf_range(2.4, 5.5)
	if _blinks_left > 0:
		blink = minf(1.0, blink + delta * 14.0)
		if blink >= 1.0:
			_blinks_left -= 1
	else:
		blink = maxf(0.0, blink - delta * 9.0)
	if _blinks_left > 0 and blink >= 1.0:
		blink = 0.99
	# eyes: follow the pointer; when nobody is pointing, glance around on their own
	_pointer_idle += delta
	if _pointer_idle > 3.0:
		_next_glance -= delta
		if _next_glance <= 0.0:
			_look_target = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.8)) if _rng.randf() < 0.7 else Vector2.ZERO
			_next_glance = _rng.randf_range(1.2, 3.5)
	look = look.lerp(_look_target, clampf(delta * 6.0, 0.0, 1.0))
	# a little shimmy every so often, for no reason at all
	_next_wiggle -= delta
	if _next_wiggle <= 0.0:
		_wiggle = 1.0
		_next_wiggle = _rng.randf_range(8.0, 16.0)
	_wiggle = maxf(0.0, _wiggle - delta * 1.4)
	# a tap: hop, land with a squish
	if hop > 0.0 or _hop_velocity != 0.0:
		_hop_velocity -= 2600.0 * delta
		hop += _hop_velocity * delta
		if hop <= 0.0:
			hop = 0.0
			if _hop_velocity < -200.0:
				_squash = 1.0
			_hop_velocity = 0.0
	_squash = maxf(0.0, _squash - delta * 4.0)
	joy = maxf(0.0, joy - delta * 0.55)
	# breathing, sway, squash and wiggle are all just this node's transform
	var breath := sin(time * 1.7)
	var squash := _squash * sin(_squash * PI) * 0.10
	scale = Vector2(1.0 + breath * 0.006 + squash, 1.0 - breath * 0.012 - squash + (0.04 if _hop_velocity > 0.0 else 0.0))
	skew = sin(time * 0.65) * 0.018 + sin(time * 13.0) * 0.03 * _wiggle
	rotation = sin(time * 11.0) * 0.025 * _wiggle
	position = _base_position + Vector2(0.0, -hop)


func _input(event: InputEvent) -> void:
	var at := Vector2.INF
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		at = event.position
	elif event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		at = event.position
		_maybe_tap(_canvas_point(at))
	if at != Vector2.INF:
		_pointer_idle = 0.0
		var point := _canvas_point(at)
		_look_target = ((point - Creature.HEAD_CENTER) / Vector2(520.0, 620.0)).limit_length(1.0)
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		var panel := get_parent().get_node_or_null("DebugPanel")
		if panel != null:
			panel.visible = not panel.visible   # the renderer lab, out of the way unless you want it


func _canvas_point(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _maybe_tap(point: Vector2) -> void:
	var on_head := ((point - Creature.HEAD_CENTER) / Creature.HEAD_RADII).length() <= 1.05
	var on_body := ((point - Creature.BODY_CENTER) / Creature.BODY_RADII).length() <= 1.05
	if not (on_head or on_body):
		return
	joy = 1.0
	if hop <= 0.0:
		_hop_velocity = 820.0
		hop = 0.01
