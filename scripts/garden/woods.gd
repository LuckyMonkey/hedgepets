extends "res://scripts/garden/woods/woods_build.gd"

## The woods, over the footbridge: a dark, hilly hiking trail. You stand at a clearing and turn to look around (drag,
## anywhere); the trails out of it are marked with their names, and the one you're facing lights up. Tap and you
## walk it - up and down the hills, a little bob in your step - to the next clearing. The pets following you (🐾 in
## the garden) trail along behind and gather round when you stop; a pet you're carrying (🪣) rides in its bucket and
## sits beside you, and "Let out" turns it into one more follower.
##
## Daytime under the trees: deep blue-green shade, a blue haze between the trunks, and the morning sun coming through
## in places - sunbeams slanting down (the garden's light-shaft shader), motes drifting in them, the canopy's shadows
## dappling the trails.
##
## Clearings (NODES) and the trails between them (EDGES): the trailhead by the creek, the mossy fork (the hub, mossy
## boulders), the fern hollow down low (ferns), the ridge up high (an overlook: the land falls away to a misty valley,
## far hills: distant_land.gd), the creek crossing (a real creek in its channel, stepping stones where the
## trails cross it), the old oak (one huge tree alone in its glade), and the nursery (nursery.gd). Dark, but kind:
## lanterns at every clearing, sunbeams, motes in the light. Never spooky.
##
## Finds (FINDS, SPOTS): litter to pick up, dumped junk to work loose, and what the woods drop - pine cones, acorns,
## mushrooms and feathers for the basket (the nursery buys them), and wild seeds to sow. Tap them from the clearing.
## Litter stays picked up; what the woods drop grows back after a while. Saved in game.woods_finds.

##
## This file is the top of a layer chain; each layer adds one concern and extends the one before:
##   woods_ground -> woods_trails -> woods_scenery -> woods_landmarks -> woods_finds -> woods_build -> woods.gd (here)
## all in scripts/garden/woods/. Here: setting up a visit, arriving and leaving, walking a trail, looking around, input.

const WALK_SPEED := 5.0
var _press := Vector2.INF
var _moved := false
var _t := 0.0
var followers: Array = []             # HedgePetNode, in walking order
var _carried: HedgePetNode = null
var _let_out: Button
var _released: Array = []             # pets let out of the bucket here: they come home beside you
var _told := false
func title_text() -> String:
	return ""


func loading_note() -> String:
	return "Into the woods. The first walk in takes a little while."


func muffle() -> Vector2:
	return Vector2(2400.0, -8.0)                         # the garden's birds, far off behind the trees


func setup(g: Node3D) -> void:
	name = "Woods"
	position = ORIGIN
	super.setup(g)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.08
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	_let_out = Button.new()
	_let_out.flat = true
	_let_out.add_theme_font_size_override("font_size", 36)
	_let_out.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_let_out.position = Vector2(60, 1680)
	_let_out.custom_minimum_size = Vector2(420, 90)
	_let_out.visible = false
	_let_out.pressed.connect(let_out)
	_ui.add_child(_let_out)
	_basket_label = Label.new()
	_basket_label.add_theme_font_size_override("font_size", 40)
	_basket_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_basket_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 0.6))
	_basket_label.add_theme_constant_override("outline_size", 8)
	_basket_label.position = Vector2(60, 150)
	_basket_label.modulate.a = 0.0
	_ui.add_child(_basket_label)
	_binocular_caption = Label.new()
	_binocular_caption.add_theme_font_size_override("font_size", 34)
	_binocular_caption.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_binocular_caption.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 0.8))
	_binocular_caption.add_theme_constant_override("outline_size", 8)
	_binocular_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_binocular_caption.position = Vector2(60, 1420)
	_binocular_caption.size = Vector2(960, 100)
	_binocular_caption.visible = false
	_ui.add_child(_binocular_caption)


# ------------------------------------------------------------------ a visit
func _arrive() -> void:
	followers.clear()
	_released.clear()
	for name: String in garden.game.following:
		var node: HedgePetNode = garden.game.node_by_name(name)
		if node == null or not garden.pet_mode(node) in ["roam", "peek", "away", "leave"]:
			continue
		borrow(node)
		node.set_sleeping(false)
		followers.append(node)
	_carried = null
	if garden.game.carried != "":
		_carried = garden.game.node_by_name(garden.game.carried)
		if _carried != null:
			borrow(_carried)
	_at = "trailhead"
	_walking = {}
	_wild_begin()
	_refresh_finds()
	Telemetry.event("woods", {"followers": followers.size(), "carried": _carried != null})
	land.show_land(true)
	show_basket()
	_yaw = _heading_of(_way_to("fork")["dir"])
	_goal_yaw = _yaw
	_settle(Vector3.INF)
	_place_camera(_arrival_camera_point())
	if not _told:
		_told = true
		garden.game.toast("Turn to face a trail, then tap to walk it.")


func _depart() -> void:
	_walking = {}
	land.show_land(false)
	_wild.clear()                                        # (give_back puts them back where they were: away)
	nursery.depart()
	for node: HedgePetNode in followers + ([_carried] if _carried != null else []):
		Motion.channel(node, "woods").kill()             # nothing still easing anyone into place out here
	_pail.visible = false
	for node: HedgePetNode in _released:               # let out here: they come home with you, beside you
		garden.game.home_from_woods(node)


func _way_to(to: String) -> Dictionary:
	for way: Dictionary in _labels[_at]:
		if way["to"] == to:
			return way
	return {}


func _settle(came_from: Vector3) -> void:
	var c := node_pos(_at)
	for i in followers.size():
		var node: HedgePetNode = followers[i]
		var a: float = _yaw + [0.6, -0.6, 1.0, -1.0, 1.4][i % 5]
		var p := c + Vector3(-sin(a), 0, -cos(a)) * (3.6 + 0.5 * (i / 2))
		p.y = height(p.x, p.z)
		var tw := Motion.channel(node, "woods")
		tw.tween_property(node, "position", to_global(p), Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_SINE)
		node.look_point = to_global(c + Vector3(0, EYE, 0))
	if _carried != null:
		var a := _yaw - 0.35
		var p := c + Vector3(-sin(a), 0, -cos(a)) * 2.4
		p.y = height(p.x, p.z)
		_pail.position = p
		_pail.visible = true
		_carried.scale = Vector3.ONE * garden.PET_SCALE * 0.55
		_carried.position = to_global(p + Vector3(0, 0.18, 0))
		_carried.rotation.y = garden._heading(p, c)
		_carried.look_point = to_global(c + Vector3(0, EYE, 0))
		_carried.visible = true
	_let_out.visible = _carried != null
	if _carried != null:
		_let_out.text = "🪣  Let %s out" % _carried.profile.pet_name
	_title.text = NODES[_at]["name"] if NODES.has(_at) else ""


## The bucket tipped: the pet hops out and walks with you from now on (and comes home with you).
func let_out() -> void:
	if _carried == null:
		return
	var node := _carried
	_carried = null
	_pail.visible = false
	node.scale = Vector3.ONE * garden.PET_SCALE
	node.position = to_global(_pail.position)
	node.tap()
	keep(node)
	_released.append(node)
	followers.append(node)
	garden.game.carried = ""
	if not garden.game.following.has(node.profile.pet_name):
		garden.game.following.append(node.profile.pet_name)
	garden.game.toast("%s hops out and shakes off. It'll walk with you now." % node.profile.pet_name)
	_settle(Vector3.INF)


# ------------------------------------------------------------------ walking a trail
func walk(way: Dictionary) -> void:
	if way.get("stub", false):
		garden.game.toast("The way to the nursery is still overgrown. Another day.")
		return
	if way["to"] == "garden":
		leave()
		return
	if _at == "nursery":
		nursery.depart()
	var e: Dictionary = _paths[int(way["edge"])]
	var pts: PackedVector3Array = e["pts"] if e["a"] == _at else _reversed(e["pts"])
	var length := 0.0
	for i in range(1, pts.size()):
		length += pts[i].distance_to(pts[i - 1])
	_walking = {"pts": pts, "s": 0.0, "len": length, "to": way["to"]}
	_pail.visible = false
	if _carried != null:
		_carried.visible = false                         # in the bucket, in your hand
	_let_out.visible = false
	_title.text = ""


func _sample(pts: PackedVector3Array, s: float) -> Vector3:
	if s <= 0.0:
		return pts[0]
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if acc + seg >= s:
			return pts[i - 1].lerp(pts[i], (s - acc) / maxf(seg, 0.0001))
		acc += seg
	return pts[pts.size() - 1]


func _step_walk(delta: float) -> void:
	var w := _walking
	var len: float = w["len"]
	var s: float = w["s"]
	var ease := clampf(minf(s, len - s) / 2.5, 0.35, 1.0)   # gentle start and stop
	s = minf(len, s + WALK_SPEED * ease * delta)
	w["s"] = s
	var pts: PackedVector3Array = w["pts"]
	var here := _sample(pts, s)
	var ahead := _sample(pts, minf(len, s + 3.0))
	var d := ahead - here
	if Vector2(d.x, d.z).length() > 0.3:
		_goal_yaw = atan2(-d.x, -d.z)
	var slope := atan2(d.y, maxf(0.5, Vector2(d.x, d.z).length()))
	_pitch = lerpf(_pitch, clampf(slope * 0.8 - 0.08, -0.35, 0.3), clampf(delta * 2.0, 0.0, 1.0))   # eyes on the trail: up a climb you look up it, not into it
	var bob := sin(s * 2.6) * 0.045
	_place_camera(here + Vector3(0, EYE + bob, 0))
	for i in followers.size():                          # trailing along behind, each a little further back
		var node: HedgePetNode = followers[i]
		Motion.channel(node, "woods").kill()
		var fs := s - 2.4 - i * 1.7
		var p := _sample(pts, fs)
		var q := _sample(pts, fs + 0.8)
		node.position = to_global(p)
		if fs > 0.0 and q.distance_to(p) > 0.05:
			node.rotation.y = lerp_angle(node.rotation.y, garden._heading(p, q), clampf(delta * 6.0, 0.0, 1.0))
		node.walking = 1.0 if fs > 0.0 and s < len else move_toward(node.walking, 0.0, delta * 3.0)
		node.look_point = Vector3.INF
	if s >= len:
		_at = w["to"]
		_walking = {}
		for node: HedgePetNode in followers:
			node.walking = 0.0
		_settle(pts[pts.size() - 1])
		Telemetry.event("trail", {"to": _at})
		if _at == "nursery":
			_goal_yaw = _heading_of(nursery.basis.z)    # turn to face her bench as you come in
			nursery.arrive()


# ------------------------------------------------------------------ looking around
func _place_camera(at: Vector3) -> void:
	cam.position = at
	cam.rotation = Vector3(_pitch, _yaw, 0)


func _arrival_camera_point() -> Vector3:
	var p := node_pos(_at) + Vector3(0, EYE, 0)
	if _at == "oak":
		p += Vector3(OAK_VIEW.x, 0, OAK_VIEW.y) * 2.8
	elif _at == "ridge":
		p -= Vector3(VIEW_DIR.x, 0, VIEW_DIR.y) * 1.5
	return p


func facing() -> Dictionary:
	if not _walking.is_empty():
		return {}
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var best: Dictionary = {}
	var best_dot := cos(deg_to_rad(28.0))
	for way: Dictionary in _labels[_at]:
		var dt: float = fwd.dot(way["dir"])
		if dt > best_dot:
			best_dot = dt
			best = way
	return best


func _process(delta: float) -> void:
	_stream_update()
	_t += delta
	if _binocular_mode or _binocular_returning:
		_update_binocular_camera(delta)
	elif not _walking.is_empty():
		_step_walk(delta)
	else:
		_pitch = lerpf(_pitch, clampf(_pitch, deg_to_rad(-25), deg_to_rad(12)), clampf(delta * 4.0, 0.0, 1.0))
	_yaw = lerp_angle(_yaw, _goal_yaw, clampf(delta * (5.0 if _walking.is_empty() else 3.0), 0.0, 1.0))
	if _binocular_mode or _binocular_returning:
		pass                                             # the mounted viewer owns the camera while in its quiet gaze
	elif _walking.is_empty():
		_place_camera(_arrival_camera_point())
	else:
		cam.rotation = Vector3(_pitch, _yaw, 0)
	var faced := facing()
	for way: Dictionary in _labels[_at]:                 # the sign you're facing reads bright
		var l: Label3D = way["label"]
		var want := Color(1.0, 0.95, 0.8) if way == faced else Color(0.78, 0.7, 0.54)
		l.modulate = Motion.approach(l.modulate, want, 4.0, delta)
		(l.get_meta("back") as Label3D).modulate = l.modulate
	for id in _labels:                                   # the chevrons: on the trail you're facing, here
		for way: Dictionary in _labels[id]:
			if way.has("marks"):
				var m: StandardMaterial3D = way["marks"]["mat"]
				var a := (0.7 + 0.25 * sin(_t * 4.0)) if (id == _at and way == faced) else 0.0
				m.albedo_color.a = Motion.approach(m.albedo_color.a, a, 6.0, delta)
	_wild_tick(delta)
	_tend_trinkets(delta)
	for t in _trinkets:                                 # a gentle bob, like the garden's gifts
		(t["node"] as Label3D).position.y = float(t["base"]) + 0.06 * sin(_t * 2.2 + float(t["phase"]))
		(t["node"] as Label3D).visible = t["at"] == _at
	land.follow(cam, cam.position, delta)
	for h: Node3D in _willows_sway:                      # the willows' strands, swaying
		var ph: float = h.get_meta("phase")
		h.rotation = Vector3(sin(_t * 0.6 + ph) * 0.035, 0, cos(_t * 0.45 + ph * 1.3) * 0.035)
	for f: Dictionary in _finds:                         # glints twinkle, around where you stand (not specks from every place)
		var g: Label3D = f["node"].get_node_or_null("Glint")
		if g != null:
			g.visible = f["at"] == _at
			g.modulate.a = 0.55 + 0.45 * sin(_t * 2.1 + f["node"].position.x * 3.0)
	for f: Node3D in _fireflies:
		var ph: float = f.get_meta("phase")
		f.position = f.get_meta("home") + Vector3(sin(_t * 0.5 + ph), sin(_t * 0.8 + ph * 2.0) * 0.4, cos(_t * 0.4 + ph)) * 0.6
		f.visible = sin(_t * 1.3 + ph * 3.0) > -0.3


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if _binocular_mode and event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_binocular_fov = clampf(_binocular_fov + (-3.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 3.0), 8.0, 40.0)
		return
	if _binocular_mode and event is InputEventMagnifyGesture:
		_binocular_fov = clampf(_binocular_fov / maxf(event.factor, 0.1), 8.0, 40.0)
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if pressed:
		_press = event.position
		_moved = false
	elif released and _press != Vector2.INF:
		if not _moved:
			_tap(event.position)
		_press = Vector2.INF
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _press != Vector2.INF:
		if event.position.distance_to(_press) > 10.0:
			_moved = true
		if _moved and _binocular_mode:
			_binocular_yaw = clampf(_binocular_yaw - event.relative.x * 0.0032, _heading_of(Vector3(VIEW_DIR.x, 0, VIEW_DIR.y)) - 0.65, _heading_of(Vector3(VIEW_DIR.x, 0, VIEW_DIR.y)) + 0.65)
			_binocular_pitch = clampf(_binocular_pitch - event.relative.y * 0.002, deg_to_rad(-28), deg_to_rad(8))
		elif _moved and _walking.is_empty():               # any drag looks around
			_goal_yaw -= event.relative.x * 0.0045
			_pitch = clampf(_pitch - event.relative.y * 0.002, deg_to_rad(-25), deg_to_rad(12))
	if event is InputEventKey and event.pressed and _walking.is_empty():
		if event.physical_keycode in [KEY_A, KEY_LEFT, KEY_Q]:
			_goal_yaw += 0.4
		elif event.physical_keycode in [KEY_D, KEY_RIGHT, KEY_E]:
			_goal_yaw -= 0.4
		elif event.physical_keycode in [KEY_W, KEY_UP, KEY_SPACE, KEY_ENTER] and not facing().is_empty():
			walk(facing())


func _tap(at: Vector2) -> void:
	if _binocular_mode:
		_leave_binoculars()
		return
	if not _walking.is_empty():
		return
	if _binoculars != null and not cam.is_position_behind(_binoculars.global_position) and cam.unproject_position(_binoculars.global_position + Vector3(0, 1.1, 0)).distance_to(at) < 150.0:
		_enter_binoculars()
		return
	var pets := followers.duplicate()
	if _carried != null:
		pets.append(_carried)
	for node: HedgePetNode in pets:
		if node.visible and cam.unproject_position(node.global_position + Vector3(0, 0.4, 0)).distance_to(at) < 110.0 and not cam.is_position_behind(node.global_position):
			node.tap()
			garden.game.toast(["%s sniffs the night air.", "%s's leaves rustle. It likes it out here.", "%s looks up at the trees, then at you.", "%s is right behind you."].pick_random() % node.profile.pet_name)
			return
	if _at == "nursery" and nursery.tap(at, cam):
		return
	if _wild_tapped(at):
		return
	if _at == "hollow" and not cam.is_position_behind(campfire.global_position) and cam.unproject_position(campfire.global_position + Vector3(0, 0.3, 0)).distance_to(at) < 130.0:
		campfire.tapped(garden.game)
		return
	if _take_trinket(at):
		return
	var f := _find_at(at)
	if not f.is_empty():
		take(f)
		return
	var way := _way_tapped(at)
	if way.is_empty():
		garden.game.toast("Tap a trail (or its sign) to walk it. Drag to look around.")
	else:
		if way != facing():
			_goal_yaw = _heading_of(way["dir"])            # turn to it first, as you set off
		walk(way)


## Which trail a tap means: the one whose start (its first few metres, or its sign) is nearest the tap on screen; if
## the tap isn't near any, the one you're facing.
func _way_tapped(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 230.0
	for way: Dictionary in _labels[_at]:
		var c := node_pos(_at)
		var marks: Array = [c + way["dir"] * 4.0, c + way["dir"] * 7.0]
		if way.has("label"):
			marks.append((way["label"] as Label3D).global_position - global_position)
		for q: Vector3 in marks:
			var g := to_global(Vector3(q.x, height(q.x, q.z) + 0.3, q.z) if q.y < c.y + 1.0 else q)
			if cam.is_position_behind(g):
				continue
			var d := cam.unproject_position(g).distance_to(at)
			if d < best_d:
				best_d = d
				best = way
	return best if not best.is_empty() else facing()
