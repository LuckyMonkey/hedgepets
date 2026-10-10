extends Node3D

## The man on the porch of the house that overlooks the garden. When you're not looking, he comes out onto the deck
## and takes pictures of the hedgepets with his phone (now and then a little flash at the edge of your view). The moment
## the camera finds him he's caught: either the phone goes into his pocket very fast and he becomes extremely interested
## in the sky (and if you keep looking, he goes in after all), or he hurries straight back inside. A while later, when
## you're looking elsewhere, he's back. He has no name in the game, and he never explains himself.
## docs/private/LORE.md.

enum { INSIDE, OUT, WATCHING, CAUGHT, GOING_IN }

const WALK := 1.1
const HURRY := 2.6
const DECK := 1.35

var garden: Node3D
var _house: Vector3
var _state := INSIDE
var _wait := 25.0                     # seconds until he next comes out (inside) / of looking at the sky (caught)
var _goal := Vector3.ZERO
var _speed := WALK
var _t := 0.0
var _flash_in := 6.0
var _body: Node3D
var _head: Node3D
var _arm: Node3D
var _phone: Node3D
var _legs: Array = []
var _flash: OmniLight3D
var _raise := 0.0                     # 0 = phone down, 1 = held up taking pictures (eased)
var _seen_for := 0.0
var _walk_phase := 0.0
var _caught_times := 0


func setup(g: Node3D, house_at: Vector3) -> void:
	garden = g
	_house = house_at
	name = "PorchWatcher"
	_build()
	position = _door()
	visible = false
	scale = Vector3.ONE * 0.01


func _door() -> Vector3:
	return _house + Vector3(0.0, DECK, -3.53 - 0.35)


func _rail_spot() -> Vector3:
	return _house + Vector3(randf_range(-2.1, 1.6), DECK, -3.53 - 2.6 + 0.45)


func _build() -> void:
	var skin := GardenProps.mat("watcherskin", Color("d8b49a"))
	var coat := GardenProps.mat("watchercoat", Color("4e5a3c"))
	var jeans := GardenProps.mat("watcherjeans", Color("3a4458"))
	var shoe := GardenProps.mat("watchershoe", Color("2a2622"))
	var hair := GardenProps.mat("watcherhair", Color("4a3a2c"))
	var cap := GardenProps.mat("watchercap", Color("7a3a2e"))
	_body = Node3D.new()
	add_child(_body)
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.1, 0.9, 0)
		_body.add_child(leg)
		GardenProps.part(leg, GardenProps.cyl(0.07, 0.065, 0.86, 8), jeans, Vector3(0, -0.43, 0), Vector3.ZERO, 0.008)
		GardenProps.part(leg, GardenProps.blob(Vector3(0.07, 0.05, 0.13), {"exponent": 2.2, "flat_bottom": 0.6}), shoe, Vector3(0, -0.86, 0.04), Vector3.ZERO, 0.006)
		_legs.append(leg)
	GardenProps.part(_body, GardenProps.blob(Vector3(0.23, 0.36, 0.16), {"exponent": 2.6}), coat, Vector3(0, 1.22, 0), Vector3.ZERO, 0.012)
	GardenProps.part(_body, GardenProps.blob(Vector3(0.14, 0.08, 0.12), {"exponent": 2.2}), coat, Vector3(0, 1.56, -0.06), Vector3.ZERO, 0.008)   # the hood, down
	var left := Node3D.new()
	left.position = Vector3(-0.25, 1.5, 0)
	left.rotation_degrees.z = -6.0
	_body.add_child(left)
	GardenProps.part(left, GardenProps.cyl(0.055, 0.06, 0.6, 8), coat, Vector3(0, -0.3, 0), Vector3.ZERO, 0.008)
	GardenProps.part(left, GardenProps.blob(Vector3(0.045, 0.055, 0.04), "pebble"), skin, Vector3(0, -0.62, 0), Vector3.ZERO, 0.004)
	_arm = Node3D.new()
	_arm.position = Vector3(0.25, 1.5, 0)
	_body.add_child(_arm)
	GardenProps.part(_arm, GardenProps.cyl(0.055, 0.06, 0.6, 8), coat, Vector3(0, -0.3, 0), Vector3.ZERO, 0.008)
	GardenProps.part(_arm, GardenProps.blob(Vector3(0.045, 0.055, 0.04), "pebble"), skin, Vector3(0, -0.62, 0), Vector3.ZERO, 0.004)
	_phone = Node3D.new()
	_phone.position = Vector3(0, -0.66, 0.03)
	_arm.add_child(_phone)
	GardenProps.part(_phone, GardenProps.box(Vector3(0.075, 0.15, 0.012)), GardenProps.mat("phone", Color("1e1e22"), 0.3), Vector3.ZERO, Vector3(90, 0, 0), 0.0)
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color("9ac8ff")
	screen.emission_enabled = true
	screen.emission = Color("6aa0e0")
	GardenProps.part(_phone, GardenProps.box(Vector3(0.065, 0.13, 0.002)), screen, Vector3(0, 0.008, 0), Vector3(90, 0, 0), 0.0)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("f4f6ff")
	_flash.light_energy = 0.0
	_flash.omni_range = 4.0
	_phone.add_child(_flash)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.62, 0)
	_body.add_child(_head)
	GardenProps.part(_head, GardenProps.blob(Vector3(0.11, 0.13, 0.115), {"exponent": 2.0}), skin, Vector3(0, 0.11, 0), Vector3.ZERO, 0.008)
	GardenProps.part(_head, GardenProps.blob(Vector3(0.118, 0.07, 0.122), {"exponent": 2.0}), hair, Vector3(0, 0.17, -0.015), Vector3.ZERO, 0.006)
	GardenProps.part(_head, GardenProps.blob(Vector3(0.125, 0.06, 0.125), {"exponent": 2.4, "flat_bottom": 0.8}), cap, Vector3(0, 0.21, 0), Vector3.ZERO, 0.006)
	GardenProps.part(_head, GardenProps.box(Vector3(0.16, 0.015, 0.11)), cap, Vector3(0, 0.2, 0.13), Vector3(-8, 0, 0), 0.004)
	for side: float in [-1.0, 1.0]:
		GardenProps.part(_head, GardenProps.cyl(0.025, 0.025, 0.006, 10), GardenProps.mat("watcherspecs", Color("222222"), 0.3), Vector3(side * 0.045, 0.12, 0.112), Vector3(90, 0, 0), 0.0)


## Whether the camera has him: on screen, well inside the edges, and near enough to make him out.
func seen() -> bool:
	if not visible or garden.camera == null or not garden.camera.current:
		return false
	var head := _head.global_position + Vector3(0, 0.1, 0)
	var cam: Camera3D = garden.camera
	if cam.is_position_behind(head) or cam.global_position.distance_to(head) > 34.0:
		return false
	var r := garden.get_viewport().get_visible_rect().size
	var s := cam.unproject_position(head)
	return s.x > r.x * 0.12 and s.x < r.x * 0.88 and s.y > r.y * 0.1 and s.y < r.y * 0.85


func _door_seen() -> bool:
	var cam: Camera3D = garden.camera
	if cam == null or cam.is_position_behind(_door()):
		return false
	var r := garden.get_viewport().get_visible_rect().size
	var s := cam.unproject_position(_door() + Vector3(0, 1.0, 0))
	return s.x > 0 and s.x < r.x and s.y > 0 and s.y < r.y and cam.global_position.distance_to(_door()) < 34.0


## The pet he's photographing: the nearest one out in the garden.
func _subject() -> Vector3:
	var best := Vector3(0, 0.4, 0)
	var bd := INF
	for node: HedgePetNode in garden.pets:
		if node.visible and node.global_position.distance_to(global_position) < bd:
			bd = node.global_position.distance_to(global_position)
			best = node.global_position + Vector3(0, 0.3, 0)
	return best


func _go_in(hurry: bool) -> void:
	_state = GOING_IN
	_goal = _door()
	_speed = HURRY if hurry else WALK


func _process(delta: float) -> void:
	_t += delta
	var looking := seen()
	_seen_for = _seen_for + delta if looking else 0.0
	match _state:
		INSIDE:
			_wait -= delta
			if _wait <= 0.0 and not _door_seen():
				_state = OUT
				position = _door()
				_goal = _rail_spot()
				_speed = WALK
				visible = true
				Motion.appear(self, Vector3.ONE, Motion.BASE)
			elif _wait <= 0.0:
				_wait = 3.0
		OUT:
			if looking:
				_caught()
			elif _walk_to(delta):
				_state = WATCHING
				_flash_in = randf_range(2.0, 5.0)
		WATCHING:
			if looking:
				_caught()
			else:
				var at := _subject()
				var flat := Vector3(at.x - global_position.x, 0, at.z - global_position.z)
				rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), clampf(delta * 2.0, 0.0, 1.0))
				_flash_in -= delta
				if _flash_in <= 0.0:
					_flash_in = randf_range(3.0, 8.0)
					var tw := Motion.channel(_flash, "flash")
					tw.tween_property(_flash, "light_energy", 6.0, 0.04)
					tw.tween_property(_flash, "light_energy", 0.0, 0.18)
		CAUGHT:
			_wait -= delta
			if _seen_for > 2.5 or _wait <= 0.0:          # still being looked at (or the sky's run out): inside after all
				_go_in(_seen_for > 2.5)
		GOING_IN:
			if _walk_to(delta):
				_state = INSIDE
				_wait = randf_range(45.0, 150.0)
				Motion.vanish(self, false, Motion.BASE)
	var up := 1.0 if _state == WATCHING else 0.0
	_raise = Motion.approach(_raise, up, 9.0 if up < _raise else 3.0, delta)   # the phone goes away fast
	_arm.rotation_degrees.x = lerpf(4.0, -105.0, _raise)
	_phone.visible = _raise > 0.15
	var sky := 1.0 if _state == CAUGHT else 0.0
	_head.rotation_degrees.x = lerpf(4.0 * _raise, -32.0, sky) + sin(_t * 0.8) * 1.5
	_head.rotation_degrees.y = sin(_t * 0.6) * 20.0 * sky


func _caught() -> void:
	_caught_times += 1
	if randf() < 0.5:
		_state = CAUGHT                                  # phone away, nothing to see here, lovely sky
		_wait = randf_range(4.0, 7.0)
	else:
		_go_in(true)


## Walk toward _goal; true once there.
func _walk_to(delta: float) -> bool:
	var to := _goal - position
	to.y = 0.0
	if to.length() < 0.06:
		for leg: Node3D in _legs:
			leg.rotation_degrees.x = Motion.approach(leg.rotation_degrees.x, 0.0, 10.0, delta)
		return true
	var step := minf(to.length(), _speed * delta)
	position += to.normalized() * step
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(delta * 10.0, 0.0, 1.0))
	_walk_phase += step * 6.0
	for i in _legs.size():
		(_legs[i] as Node3D).rotation_degrees.x = sin(_walk_phase + i * PI) * 24.0
	return false
