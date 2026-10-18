extends Node

## Hands-on yard work. With ✋, press on a piece of junk and drag:
##
##   YANK   most things are stuck (bedded in the lawn, sunk in mud, rusted in place). Pulling builds STRAIN: the thing
##          leans toward your hand and starts to shake, a ring fills at your finger. A slow, steady pull frees
##          anything in the end (heavier = longer); quick jerks are an optional shortcut, never required. At full
##          strain it tears free: a burst of dirt, a hop, a bare patch where it was.
##   HAUL   a free thing follows your hand on a heavy spring: light things lift and swing, heavy ones scrape along
##          the ground, slow, tilted, kicking up dust. Let go and it thuds down where you leave it.
##   BIN    drop junk in the trash barrel by the garden gate. It only holds 100 lb (a big rock won't go in at all).
##          The rubbish truck comes by on its own every so often (and while you're away) and empties it, paying a
##          little scrap. No fee, no countdown, nothing to call: the yard just gets cleared gradually.
##   MEND   hold on a broken thing (the sprinkler, a run of the back fence) and it gets fixed over a few seconds:
##          a ring fills, no pulling, no hurry. The sprinkler stands up and works (sprays in slow sweeps now and
##          then, watering plants within reach); the fence stands straight again (the gap becomes a gate).
##   RAKE   press on a drift of fallen leaves (nothing else there) and drag: the leaves sweep along under your hand
##          and heap up where you gather them (scripts/garden/fallen_leaves.gd). Just for the pleasure of it.
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
	"chair": {"lb": 12, "stuck": 0.0}, "wheelbarrow": {"lb": 30, "stuck": 0.0}, "fire_pit": {"lb": 140, "stuck": 0.0},
}
const AREA := Rect2(-13.0, -10.4, 26.0, 19.8)        # where things can be hauled to
const BARREL_CAP := 100.0
const TRUCK_EVERY := Vector2(150.0, 300.0)   # seconds after something goes in; real time, so also while away

var garden: Node3D
var game: Node
var barrel: Dictionary = {}
var contents: Array = []            # {kind, lb, value} in the barrel
var next_pickup := 0.0              # unix time the truck comes by (0 = nothing in the barrel)
var _tag: Label3D
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
var _mending = null                 # {kind, ...} being mended under your hand
var _mend := 0.0
const MEND_SECONDS := 3.0
var _raking := false
var _rake_at := Vector3.INF
var _raked := 0
var _spray: CPUParticles3D
var _spray_t := 0.0


func setup(g: Node3D, gm: Node, ui: CanvasLayer) -> void:
	garden = g
	game = gm
	for t in garden.things:
		_init_thing(t)
	var at := Vector3(3.2, 0, 7.6)
	garden._thing("barrel", GardenProps.trash_barrel(garden, at, 200.0), Vector2(at.x, at.z), 0.6, 0, false)
	barrel = garden.things[-1]
	_tag = Label3D.new()
	_tag.font_size = 44
	_tag.pixel_size = 0.004
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.outline_size = 10
	_tag.position = at + Vector3(0, 1.75, 0)
	garden.add_child(_tag)
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
	var f = _mendable_at(Vector2(g.x, g.z))
	if f != null:
		_mending = f
		_mend = 0.0
		_pointer = screen
		return true
	var t = _thing_near(Vector2(g.x, g.z))
	if t == null:
		if garden.fallen != null and garden.fallen.rakeable(g):
			_raking = true
			_rake_at = g
			_raked = 0
			return true
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
	if _raking:
		var g: Vector3 = garden.ground_point(screen)
		if g != Vector3.INF:
			_raked += garden.fallen.rake(_rake_at, g)
			_rake_at = g
		return
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
	if _raking:
		_raking = false
		return _raked > 0                                 # pressed and let go on the leaves: still a tap
	if _mending != null:
		var used := _mend > 0.08
		_mending = null
		ring.hide_ring()
		return used                                       # a quick tap still means "look at it"
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
	if t["junk"] and _at_barrel(t):
		Telemetry.event("bin", {"kind": t["kind"]})
		_bin(t)
		return true
	if t["kind"] in ["stick", "branch"] and _onto_brush_pile(t):
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
	_tend_tag(delta)
	_tend_sprinkler(delta)
	if _mending != null:
		_mend += delta / MEND_SECONDS
		ring.show_ring(_pointer, clampf(_mend, 0.0, 1.0), "🔧 " + str(_mending["label"]), false)
		if _mend >= 1.0:
			_finish_mend(_mending)
			_mending = null
			ring.hide_ring()
		return
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
	# effort: a steady pull always gets there (heavier = longer); a jerk adds more; easing off lets it settle back
	var effort := (tension * 0.6 + yank * 1.8) * 2.6 / sqrt(lb * 0.5 + 4.0) / maxf(float(t["stuck"]), 0.2)
	var rate := effort if tension > 0.15 or yank > 0.0 else -0.3
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
	Telemetry.event("yank", {"kind": t["kind"]})
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
	# solid: it stops against trunks, walls and other things (pets get shoved aside by garden._separate)
	var pr := float(t["radius"]) * 0.8
	# a light thing is carried (lifted over low junk); a heavy one is dragged and bumps into everything
	for c in garden.colliders(t, false, lb >= 20.0):
		var off := Vector2(pos.x, pos.z) - (c[0] as Vector2)
		var depth := float(c[1]) + pr - off.length()
		if depth > 0.0 and off.length() > 0.001:
			var n := off.normalized()
			pos.x += n.x * depth
			pos.z += n.y * depth
			var v2 := Vector2(_vel.x, _vel.z)
			v2 -= n * minf(0.0, v2.dot(n))             # lose the speed going into it
			_vel = Vector3(v2.x, 0, v2.y)
	if t["kind"] == "wheelbarrow":                       # rolling over a dirt pile shovels it in
		var here := Vector2(pos.x, pos.z)
		for d in game.dirt_piles.duplicate():
			if int(t.get("load", 0)) < game.DIRT_MAX and here.distance_to(d["at"]) < 0.7:
				game.take_dirt(d)
				barrow_load(t, 1)
				game.toast("Dirt into the wheelbarrow (%d/%d)." % [int(t["load"]), game.DIRT_MAX])
	var light := lb < 20.0
	pos.y = lerpf(node.position.y, (0.45 + 0.05 * sin(_t * 5.0)) if light else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	node.position = pos
	t["at"] = Vector2(pos.x, pos.z) + t["offset"]       # where pets see it, as it moves
	var sp := _vel.length()
	var axis := _vel.normalized().cross(Vector3.DOWN).normalized() if sp > 0.01 else Vector3.RIGHT
	var tilt := clampf(sp * (0.12 if light else 0.05), 0.0, 0.5) * (1.0 if light else -1.0)
	node.basis = node.basis.slerp(Basis(axis, tilt) * _base, clampf(delta * 6.0, 0.0, 1.0))
	if not light:
		_dust_at(node, sp > 0.4)
	var words := "%s  ~%d lb" % [_label(t), int(lb)]
	if t["junk"] and _at_barrel(t):
		words = ("🗑️ let go to bin it  (%d/%d lb)" % [int(fill_lb() + lb), int(BARREL_CAP)]) if fill_lb() + lb <= BARREL_CAP else ("🗑️ won't fit: room for %d lb" % int(BARREL_CAP - fill_lb()))
	ring.show_ring(_pointer, -1.0, words, false)


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
	if t["kind"] == "wheelbarrow" and int(t.get("load", 0)) > 0:   # let go over holes: it fills them
		var filled := 0
		for bed in game.seedbeds.duplicate():
			if int(t["load"]) > 0 and bed["plant"] == null and (bed["at"] as Vector2).distance_to(t["at"]) < 1.3:
				game.fill_hole(bed)
				barrow_load(t, -1)
				filled += 1
		if filled > 0:
			game.toast("Tipped the wheelbarrow: %d hole%s filled." % [filled, "" if filled == 1 else "s"])


## The wheelbarrow's load of dirt (0..DIRT_MAX), and the heap you can see in its tray.
func barrow_load(t: Dictionary, change: int) -> void:
	t["load"] = clampi(int(t.get("load", 0)) + change, 0, game.DIRT_MAX)
	var node: Node3D = t["node"]
	var heap: Node3D = node.get_node_or_null("Load")
	if heap == null:
		heap = GardenProps.part(node, GardenProps.blob(Vector3(0.55, 0.16, 0.36), {"exponent": 2.0}), GardenProps.mat("dirtpile", Color("5c4230")), Vector3(-0.05, 0.78, 0), Vector3.ZERO, 0.004)
		heap.name = "Load"
		heap.scale = Vector3.ONE * 0.01
	var s := 0.01 if int(t["load"]) == 0 else 0.55 + 0.15 * int(t["load"])
	Motion.channel(heap, "scale").tween_property(heap, "scale", Vector3(1, s, 1) * maxf(s, 0.01) if s > 0.02 else Vector3.ONE * 0.01, Motion._d(Motion.BASE))


## Sticks and branches dropped on the brush pile join it: the pile grows (and shy woodland visitors like it more).
func _onto_brush_pile(t: Dictionary) -> bool:
	var piles: Array = garden.things.filter(func(x) -> bool: return x["kind"] == "brush_pile")
	if piles.is_empty():
		return false
	var pile: Dictionary = piles[0]
	var node: Node3D = t["node"]
	var pn: Node3D = pile["node"]
	if Vector2(node.position.x - pn.position.x, node.position.z - pn.position.z).length() > float(pile["radius"]) + 0.8:
		return false
	var tw := Motion.channel(node, "lean")
	tw.tween_property(node, "position", pn.position + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3)), Motion._d(Motion.BASE)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.6, Motion._d(Motion.BASE))
	tw.tween_callback(node.queue_free)
	garden.things.erase(t)
	game.cleared += 1
	pile["size"] = int(pile.get("size", 0)) + 1
	var grow := 1.0 + 0.06 * minf(float(pile["size"]), 8.0)
	Motion.channel(pn, "scale").tween_property(pn, "scale", Vector3.ONE * grow, Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	game.toast("🍂 Onto the brush pile. Something small might like it in there.")
	game._refresh()
	return true


func _at_barrel(t: Dictionary) -> bool:
	var node: Node3D = t["node"]
	var b: Node3D = barrel["node"]
	return Vector2(node.position.x - b.position.x, node.position.z - b.position.z).length() < float(t["radius"]) * 0.8 + 1.1


func fill_lb() -> float:
	var n := 0.0
	for c in contents:
		n += float(c["lb"])
	return n


## Into the barrel, if it fits; out of the yard (cleared) but not paid for until the pickup.
func _bin(t: Dictionary) -> void:
	var node: Node3D = t["node"]
	var lb := float(t["lb"])
	if fill_lb() + lb > BARREL_CAP:
		game.toast("🗑️ It won't fit. The barrel has room for %d lb; that's ~%d lb." % [int(BARREL_CAP - fill_lb()), int(lb)])
		_drop(t)
		return
	var b: Node3D = barrel["node"]
	var tw := Motion.channel(node, "lean")
	tw.tween_property(node, "position", b.position + Vector3(0, 1.3, 0), Motion._d(Motion.FAST * 1.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.45, Motion._d(Motion.FAST * 1.5))
	tw.tween_property(node, "position", b.position + Vector3(0, 0.7, 0), Motion._d(Motion.FAST)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.05, Motion._d(Motion.FAST))
	tw.tween_callback(node.queue_free)
	garden.things.erase(t)
	game.placed = game.placed.filter(func(p) -> bool: return p["node"] != node)
	contents.append({"kind": t["kind"], "lb": lb, "value": _value(t)})
	if next_pickup <= 0.0:
		next_pickup = Time.get_unix_time_from_system() + randf_range(TRUCK_EVERY.x, TRUCK_EVERY.y)
	game.cleared += 1
	Motion.swap(b, Vector3.ONE, func() -> void: pass)
	_show_fill()
	game.toast("🗑️ Binned the %s. %d/%d lb." % [_label(t), int(fill_lb()), int(BARREL_CAP)])
	game._refresh()


## Tapping the barrel just tells you how full it is.
func barrel_tapped() -> void:
	if contents.is_empty():
		game.toast("🗑️ The barrel's empty. Haul junk here; it holds %d lb." % int(BARREL_CAP))
	else:
		game.toast("🗑️ %d of %d lb. The truck comes by every so often." % [int(fill_lb()), int(BARREL_CAP)])


func _scrap() -> int:
	var v := 0
	for c in contents:
		v += int(c["value"])
	return v


func _pickup(quiet := false) -> void:
	var scrap := _scrap()
	game.coins += scrap
	contents.clear()
	next_pickup = 0.0
	var b: Node3D = barrel["node"]
	var lid: Node3D = b.get_node("Lid")
	var tw := Motion.channel(lid, "lid")
	tw.tween_property(lid, "rotation_degrees:z", 75.0, Motion._d(Motion.FAST)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(Motion._d(0.4))
	tw.tween_callback(_show_fill)
	Motion.swap(b, Vector3.ONE, func() -> void: pass)
	if not quiet:
		game.toast("🚛 The rubbish truck came by and emptied the barrel. Scrap 🪙 +%d" % scrap)
		var sounds := garden.get_node_or_null("Soundscape")
		if sounds != null:
			sounds.play_once("garbage_truck", Vector3(4.0, 1.0, 30.0), -12.0)   # out front: rumble, hiss, beep
	game._refresh()


## The lid rides up and the rubbish shows as the barrel fills.
func _show_fill() -> void:
	var b: Node3D = barrel["node"]
	var f := clampf(fill_lb() / BARREL_CAP, 0.0, 1.0)
	var fill: Node3D = b.get_node("Fill")
	var lid: Node3D = b.get_node("Lid")
	Motion.channel(fill, "fill").tween_property(fill, "scale", Vector3(1, maxf(0.01, f * 1.4), 1), Motion._d(Motion.BASE)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Motion.channel(lid, "lid").tween_property(lid, "rotation_degrees:z", f * 38.0, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


var _tag_t := 0.0


func _tend_tag(delta: float) -> void:
	_tag_t -= delta
	if _tag_t > 0.0 or _tag == null:
		return
	_tag_t = 0.5
	if not contents.is_empty() and next_pickup > 0.0 and Time.get_unix_time_from_system() >= next_pickup:
		_pickup()                                       # the truck came by
	_tag.text = "🗑️ %d/%d lb" % [int(fill_lb()), int(BARREL_CAP)]
	_tag.modulate = Color(1, 0.86, 0.7) if fill_lb() >= BARREL_CAP * 0.9 else Color.WHITE


func _value(t: Dictionary) -> int:
	return int(t["value"]) + (12 if t["kind"] == "grill" and not t["rusty"] else 0)


# ------------------------------------------------------------------ mending
## A broken thing under this point that can be mended: the sprinkler, or a run of the back fence.
func _mendable_at(p: Vector2):
	for t in garden.things:
		if t["kind"] == "sprinkler" and not t.get("fixed", false) and p.distance_to(t["at"]) < 0.9:
			return {"kind": "sprinkler", "thing": t, "label": "fixing the sprinkler"}
	for i in range(garden.fence_sections.size()):
		var sec: Dictionary = garden.fence_sections[i]
		if not sec["mended"] and absf(p.y - (-11.0)) < 0.8 and p.x >= float(sec["from"]) and p.x < float(sec["to"]):
			return {"kind": "fence", "index": i, "label": "mending the fence"}
	return null


func _finish_mend(f: Dictionary) -> void:
	Telemetry.event("mend", {"kind": f["kind"]})
	if f["kind"] == "fence":
		garden.mend_fence(f["index"])
		game.toast("🔨 That bit of fence is standing straight again.")
	else:
		fix_sprinkler(f["thing"])
		game.toast("💦 The sprinkler works again. It'll water whatever's near it, now and then.")
	game._refresh()


## The sprinkler stands up and starts working (at_once: loading a save).
func fix_sprinkler(t: Dictionary, at_once := false) -> void:
	t["fixed"] = true
	var node: Node3D = t["node"]
	var body: Node3D = node.get_child(0)
	if at_once:
		body.rotation_degrees = Vector3.ZERO
		body.position = Vector3(0, 0.08, 0)
	else:
		var tw := Motion.channel(body, "fix")
		tw.tween_property(body, "rotation_degrees", Vector3.ZERO, Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(body, "position", Vector3(0, 0.08, 0), Motion._d(Motion.SLOW))
	_spray = CPUParticles3D.new()
	_spray.amount = 70
	_spray.lifetime = 1.1
	_spray.direction = Vector3(1, 1.4, 0)
	_spray.spread = 6.0
	_spray.initial_velocity_min = 3.2
	_spray.initial_velocity_max = 3.8
	_spray.gravity = Vector3(0, -7.5, 0)
	_spray.scale_amount_min = 0.025
	_spray.scale_amount_max = 0.045
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.88, 0.98, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	var drop := SphereMesh.new()
	drop.radius = 1.0
	drop.height = 2.0
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = m
	_spray.mesh = drop
	_spray.position = Vector3(0, 0.3, 0)
	_spray.emitting = false
	node.add_child(_spray)
	_spray_t = 4.0


## The sprinkler's routine: on for twenty seconds every minute, sweeping back and forth, watering what it reaches.
func _tend_sprinkler(delta: float) -> void:
	if _spray == null or not is_instance_valid(_spray):
		return
	_spray_t -= delta
	var cycle := fposmod(_spray_t, 60.0)
	var on := cycle < 20.0
	_spray.emitting = on
	if on:
		var a := sin(_t * 0.7) * 1.2
		_spray.direction = Vector3(cos(a), 1.4, sin(a))
		if fposmod(_t, 1.0) < delta:
			var at: Vector3 = _spray.global_position
			for pl in game.plants:
				if Vector2(at.x, at.z).distance_to(pl["at"]) < 3.6:
					pl["water"] = 1.0


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
