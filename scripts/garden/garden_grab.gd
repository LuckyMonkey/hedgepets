extends Node

## Hands-on yard work. With ✋, press on a piece of junk and drag:
##
##   YANK   most things are stuck (bedded in the lawn, sunk in mud, rusted in place). Pulling builds STRAIN: the thing
##          leans toward your hand and starts to shake, a ring fills at your finger. Quick jerks (fast flicks) count
##          for much more than a steady pull, and heavy things barely move for a steady pull at all. At full strain
##          it tears free: a burst of dirt, a hop, a bare patch where it was.
##   HAUL   a free thing follows your hand on a heavy spring: light things lift and swing, heavy ones scrape along
##          the ground, slow, tilted, kicking up dust. Let go and it thuds down where you leave it.
##   SELL   drop junk in the wheelbarrow by the garden gate: hauled off for its scrap value, and it counts as cleared.
##   FIX    the tipped lawn chair rights itself when you yank it free. The rusty grill scrubs clean if you work it in
##          circles while you hold it; a clean grill sells for more.
##
## Weights are in pounds and everything is heavier than it looks (a grill is 90 lb, a bird bath 120).
## Press and let go without dragging = a tap (pet, look), as before.

const PHYS := {
	"stick": {"lb": 2, "stuck": 0.35}, "branch": {"lb": 15, "stuck": 0.8}, "rock": {"lb": 60, "stuck": 1.0},
	"lawn_chair": {"lb": 25, "stuck": 0.9, "tipped": true}, "grill": {"lb": 90, "stuck": 0.6, "rusty": true},
	"tire": {"lb": 25, "stuck": 0.75}, "pot": {"lb": 15, "stuck": 0.3}, "pumpkin": {"lb": 12, "stuck": 0.35},
	"feeder": {"lb": 30, "stuck": 0.0}, "bath": {"lb": 120, "stuck": 0.0}, "log_pile": {"lb": 80, "stuck": 0.0},
	"nest_box": {"lb": 25, "stuck": 0.0}, "apples": {"lb": 35, "stuck": 0.0},
}
const AREA := Rect2(-13.0, -10.4, 26.0, 19.8)        # where things can be hauled to
const BARROW_REACH := 1.7

var garden: Node3D
var game: Node
var barrow: Dictionary = {}
var held = null                     # the thing (garden.things entry) under your hand
var active := false                 # dragging (not just pressed)
var strain := 0.0
var _press := Vector2.ZERO
var _pointer := Vector2.ZERO
var _speed := 0.0                   # pointer speed, px/s (smoothed)
var _prev_pointer := Vector2.ZERO
var _vel := Vector3.ZERO
var _grip := Vector3.ZERO
var _base := Basis.IDENTITY
var _t := 0.0
var _scrub_angle := INF
var _dust: CPUParticles3D
var ring: Control


func setup(g: Node3D, gm: Node, ui: CanvasLayer) -> void:
	garden = g
	game = gm
	for t in garden.things:
		_init_thing(t)
	var at := Vector3(3.2, 0, 7.6)
	garden._thing("wheelbarrow", GardenProps.wheelbarrow(garden, at, 200.0), Vector2(at.x, at.z), 0.9, 0, false)
	barrow = garden.things[-1]
	ring = preload("res://scripts/garden/strain_ring.gd").new()
	ui.add_child(ring)


func _init_thing(t: Dictionary) -> void:
	if t.has("lb") or not PHYS.has(t["kind"]):
		return
	var ph: Dictionary = PHYS[t["kind"]]
	t["lb"] = ph["lb"]
	if t["kind"] == "rock":
		t["lb"] = int(20 + (float(t["radius"]) - 0.4) * 160.0)   # bigger rocks, heavier
	t["stuck"] = 0.0 if t.get("placed", false) else float(ph["stuck"])
	t["tipped"] = ph.get("tipped", false)
	t["rusty"] = ph.get("rusty", false)
	t["scrub"] = 0.0
	t["offset"] = t["at"] - Vector2(t["node"].position.x, t["node"].position.z)


func grabbable(t: Dictionary) -> bool:
	_init_thing(t)
	return t.has("lb")


# ------------------------------------------------------------------ input (from garden.gd)
## A press. True if it landed on something you could grab (the garden then doesn't turn the camera for this drag).
func begin(screen: Vector2) -> bool:
	if game.tool != "hand":
		return false
	var g: Vector3 = garden.ground_point(screen)
	if g == Vector3.INF:
		return false
	var t = _thing_near(Vector2(g.x, g.z))
	if t == null:
		return false
	held = t
	active = false
	strain = 0.0
	_press = screen
	_pointer = screen
	_speed = 0.0
	_prev_pointer = screen
	return true


func move(screen: Vector2) -> void:
	if held == null:
		return
	_pointer = screen
	if not active and screen.distance_to(_press) > 10.0:
		active = true
		var node: Node3D = held["node"]
		_base = node.basis
		_vel = Vector3.ZERO
		var g: Vector3 = garden.ground_point(screen)
		_grip = (node.position - g) if g != Vector3.INF else Vector3.ZERO
		_grip = _grip.limit_length(0.5) * Vector3(1, 0, 1)
		_scrub_angle = INF


## Let go. False if this was really a tap (never dragged): the garden treats it as one.
func end(screen: Vector2) -> bool:
	if held == null:
		return false
	var was_active := active
	var t: Dictionary = held
	held = null
	active = false
	ring.hide_ring()
	if not was_active:
		return false
	if _dust != null:
		_dust.emitting = false
	var node: Node3D = t["node"]
	if t["stuck"] > 0.0:                    # let go before it came free: it settles back
		var tw := Motion.channel(node, "lean")
		tw.tween_property(node, "basis", _base, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		return true
	if t["junk"] and node.position.distance_to(barrow["node"].position) < BARROW_REACH:
		_sell(t)
		return true
	_drop(t)
	return true


func _thing_near(p: Vector2):
	var best = null
	var best_d := 1e9
	for t in garden.things:
		if not grabbable(t):
			continue
		var d: float = p.distance_to(t["at"])
		if d < maxf(float(t["radius"]), 0.6) and d < best_d:
			best = t
			best_d = d
	return best


# ------------------------------------------------------------------ the work
func _process(delta: float) -> void:
	_t += delta
	if held == null or not active:
		return
	var t: Dictionary = held
	var node: Node3D = t["node"]
	var lb: float = t["lb"]
	var g: Vector3 = garden.ground_point(_pointer)
	if g == Vector3.INF:
		return
	# how fast the finger moves (px/s), per frame: a jerk is fast, a held finger is zero
	_speed = lerpf(_speed, _pointer.distance_to(_prev_pointer) / maxf(delta, 0.001), 0.5)
	_prev_pointer = _pointer
	if t["rusty"]:
		_scrub(t, delta)
	if t["stuck"] > 0.0:
		_yank(t, g, delta)
	else:
		_haul(t, g, delta)


## Stuck: strain builds with the pull and (much more) with fast jerks; heavier = slower; it relaxes if you ease off.
func _yank(t: Dictionary, g: Vector3, delta: float) -> void:
	var node: Node3D = t["node"]
	var lb: float = t["lb"]
	var pull := Vector3(g.x - node.position.x, 0, g.z - node.position.z)
	var tension := clampf(pull.length() / 2.0, 0.0, 1.0)
	var yank := clampf((_speed - 500.0) / 1400.0, 0.0, 1.0)
	# effort: a steady pull counts 1, a jerk up to 2.8; resistance grows with the square root of the weight
	var rate := (tension * 1.0 + yank * 1.8) * 2.6 / sqrt(lb * 0.5 + 4.0) / maxf(float(t["stuck"]), 0.2) - 0.3
	strain = clampf(strain + rate * delta, 0.0, 1.0)
	# it leans toward your hand and shakes as the strain builds (light things lean more)
	var dir := pull.normalized() if pull.length() > 0.01 else Vector3.RIGHT
	var axis := dir.cross(Vector3.DOWN).normalized()
	var give := clampf(16.0 / lb, 0.25, 1.0)
	var lean := (0.04 + 0.16 * tension) * give + 0.05 * strain * sin(_t * 46.0) * give
	node.basis = Basis(axis, -lean) * _base
	ring.show_ring(_pointer, strain, "%s  ~%d lb" % [_label(t), int(lb)], yank > 0.2)
	if strain >= 1.0:
		_break_free(t, dir)


func _break_free(t: Dictionary, dir: Vector3) -> void:
	var node: Node3D = t["node"]
	t["stuck"] = 0.0
	strain = 0.0
	_burst(node.position, Color("6a5038"), 26, 2.4)
	_scar(node.position, float(t["radius"]))
	node.basis = _base
	var hop := Motion.channel(node, "hop")
	hop.tween_property(node, "position:y", 0.35, Motion._d(Motion.FAST)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(node, "position:y", 0.0, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if t["tipped"]:
		_right_chair(t)
	game.toast(["Yanked it free!", "It came loose!", "Got it!", "Out it comes!"].pick_random() + "  %s ~%d lb" % [_label(t), int(t["lb"])])


## Free: follows your hand on a spring whose stiffness falls with weight; light things lift and swing, heavy ones drag.
func _haul(t: Dictionary, g: Vector3, delta: float) -> void:
	var node: Node3D = t["node"]
	var lb: float = t["lb"]
	var target := g + _grip
	target.x = clampf(target.x, AREA.position.x, AREA.end.x)
	target.z = clampf(target.z, AREA.position.y, AREA.end.y)
	var k := 70.0 / (lb * 0.5 + 2.0)
	var acc := (target - node.position) * k - _vel * 2.0 * sqrt(k)
	_vel += acc * delta
	_vel.y = 0.0
	_vel = _vel.limit_length(9.0 / sqrt(lb * 0.5 + 1.0))
	var pos := node.position + _vel * delta
	var light := lb < 20.0
	pos.y = lerpf(node.position.y, (0.45 + 0.05 * sin(_t * 5.0)) if light else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	node.position = pos
	var sp := _vel.length()
	var axis := _vel.normalized().cross(Vector3.DOWN).normalized() if sp > 0.01 else Vector3.RIGHT
	var tilt := clampf(sp * (0.12 if light else 0.05), 0.0, 0.5) * (1.0 if light else -1.0)
	node.basis = node.basis.slerp(Basis(axis, tilt) * _base, clampf(delta * 6.0, 0.0, 1.0))
	if not light:
		_dust_at(node, sp > 0.4)
	var near_barrow: bool = t["junk"] and node.position.distance_to(barrow["node"].position) < BARROW_REACH
	ring.show_ring(_pointer, -1.0, ("🛒 let go to haul it off  🪙 %d" % _value(t)) if near_barrow else "%s  ~%d lb" % [_label(t), int(lb)], false)


func _drop(t: Dictionary) -> void:
	var node: Node3D = t["node"]
	var tw := Motion.channel(node, "lean")
	tw.tween_property(node, "basis", _base, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if node.position.y > 0.02:
		Motion.drop(node, 0.0, Motion.BASE)
	if float(t["lb"]) >= 20.0:
		_burst(node.position, Color("8a7a5a"), 14, 1.2)          # a heavy thud
	t["at"] = Vector2(node.position.x, node.position.z) + t["offset"]
	t["moved"] = true


func _sell(t: Dictionary) -> void:
	var node: Node3D = t["node"]
	var into: Vector3 = barrow["node"].position + Vector3(0, 0.9, 0)
	var tw := Motion.channel(node, "lean")
	tw.tween_property(node, "position", into, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.2, Motion._d(Motion.BASE))
	tw.tween_callback(node.queue_free)
	garden.things.erase(t)
	game.placed = game.placed.filter(func(b) -> bool: return b["node"] != node)
	game.cleared += 1
	var v := _value(t)
	game.coins += v
	Motion.swap(barrow["node"], Vector3.ONE, func() -> void: pass)    # the barrow takes the weight
	game.toast("🛒 Hauled off the %s. 🪙 +%d" % [_label(t), v])
	game._refresh()


func _value(t: Dictionary) -> int:
	return int(t["value"]) + (12 if t["kind"] == "grill" and not t["rusty"] else 0)


# ------------------------------------------------------------------ fixing
func _right_chair(t: Dictionary) -> void:
	t["tipped"] = false
	var node: Node3D = t["node"]
	var chair: Node3D = node.get_child(0) if node.get_child_count() > 0 else null
	if chair == null:
		return
	var tw := Motion.channel(chair, "right")
	tw.tween_property(chair, "rotation_degrees", Vector3.ZERO, Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(chair, "position", Vector3.ZERO, Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	game.toast("🪑 Set the chair back on its feet.")


static func set_chair_upright(t: Dictionary) -> void:
	var node: Node3D = t["node"]
	if node.get_child_count() > 0:
		var chair: Node3D = node.get_child(0)
		chair.rotation_degrees = Vector3.ZERO
		chair.position = Vector3.ZERO
	t["tipped"] = false


## Working the grill in circles while you hold it scrubs the rust off (three full turns).
func _scrub(t: Dictionary, delta: float) -> void:
	var node: Node3D = t["node"]
	var c: Vector2 = garden.camera.unproject_position(node.position + Vector3(0, 0.9, 0))
	var d := _pointer - c
	if d.length() > 220.0 or d.length() < 12.0:
		_scrub_angle = INF
		return
	var a := d.angle()
	if _scrub_angle != INF:
		var step := absf(angle_difference(_scrub_angle, a))
		if step < 1.0:
			t["scrub"] = float(t["scrub"]) + step / (TAU * 3.0)
			set_rust(t, clampf(t["scrub"], 0.0, 1.0))
			if t["scrub"] >= 1.0 and t["rusty"]:
				t["rusty"] = false
				_burst(node.position + Vector3(0, 1.0, 0), Color("c86a3a"), 20, 1.6)
				game.toast("✨ Scrubbed the grill clean! It's worth more now.")
	_scrub_angle = a


## Rust (0 = as found) to clean dark enamel (1): each rusty part gets its own copy of the material, darkened.
static func set_rust(t: Dictionary, clean: float) -> void:
	var node: Node3D = t["node"]
	if not t.has("rust_mats"):
		var mats: Array = []
		var shared := GardenProps.rust_mat()
		var stack: Array = [node]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is MeshInstance3D and (n as MeshInstance3D).material_override == shared:
				var m := shared.duplicate() as StandardMaterial3D
				(n as MeshInstance3D).material_override = m
				mats.append(m)
		t["rust_mats"] = mats
	for m: StandardMaterial3D in t["rust_mats"]:
		m.albedo_color = Color.WHITE.lerp(Color(0.2, 0.2, 0.22), clean)
		m.roughness = lerpf(1.0, 0.45, clean)


# ------------------------------------------------------------------ dirt and dust
func _burst(at: Vector3, color: Color, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -7.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.color = color
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = m
	p.mesh = mesh
	p.position = at + Vector3(0, 0.1, 0)
	p.emitting = true
	garden.add_child(p)
	p.finished.connect(p.queue_free)


func _dust_at(node: Node3D, on: bool) -> void:
	if _dust == null or not is_instance_valid(_dust):
		_dust = CPUParticles3D.new()
		_dust.amount = 18
		_dust.lifetime = 0.8
		_dust.direction = Vector3.UP
		_dust.spread = 50.0
		_dust.initial_velocity_min = 0.2
		_dust.initial_velocity_max = 0.6
		_dust.gravity = Vector3(0, 0.3, 0)
		_dust.scale_amount_min = 0.1
		_dust.scale_amount_max = 0.25
		_dust.color = Color(0.62, 0.55, 0.42, 0.5)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 6
		mesh.rings = 3
		mesh.material = m
		_dust.mesh = mesh
		garden.add_child(_dust)
	_dust.position = node.position + Vector3(0, 0.05, 0)
	_dust.emitting = on


## Where something heavy lay a long time, the grass is gone: a patch of bare dirt that stays.
func _scar(at: Vector3, radius: float) -> void:
	var s := GardenProps.part(garden, GardenProps.blob(Vector3(radius * 0.7, 0.02, radius * 0.55), "pebble"), GardenProps.mat("scar", Color("6e5a40")), Vector3(at.x, 0.006, at.z), Vector3(0, randf() * 360.0, 0), 0.0)
	s.name = "Scar"
	Motion.appear(s, Vector3.ONE, Motion.BASE)


func _label(t: Dictionary) -> String:
	return game._thing_name(t["kind"])
