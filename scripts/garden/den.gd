extends Elsewhere

## The burrow den: a round room under the garden, through the burrow behind the tree. Roots overhead, moss beds in
## a ring, a jar of fireflies for a lamp, daylight down the tunnel. The pets who've moved in nap here; tap one and
## it stirs. Nothing to do but look in on them (watching is play). Going and coming back: elsewhere.gd.

const DEPTH := -60.0
const ROOM := 7.5                    # dome radius (pets are big: room for five to curl up with space between)
const BEDS := 5
const BED_RING := 3.1
const ROOF := 0.62                   # the dome is squashed to this much of its radius

var _sleepers: Array = []            # {node, zz}
var _beds: Array[Vector3] = []
var _yaw := 0.6
var _elev := deg_to_rad(34.0)
var _dist := 5.0
var _goal_yaw := 0.6
var _press := Vector2.INF
var _moved := false
var _t := 0.0
var _fireflies: Array = []


func title_text() -> String:
	return "The burrow"


func muffle() -> Vector2:
	return Vector2(700.0, -6.0)                          # the garden overhead, through the earth


func setup(g: Node3D) -> void:
	name = "Den"
	position = Vector3(0, DEPTH, 0)
	super.setup(g)


func _arrive() -> void:
	Telemetry.event("den")
	_tuck_in()
	if _sleepers.is_empty():
		garden.game.toast("Nobody sleeps down here yet. Pets who move in nap here.")
	else:
		garden.game.toast("Shh. %s %s asleep." % [_names(), "is" if _sleepers.size() == 1 else "are"])


func _depart() -> void:
	for s in _sleepers:
		(s["zz"] as Node).queue_free()
	_sleepers.clear()


## The residents who are about (not hiding in something just now) come down and curl up on the beds.
func _tuck_in() -> void:
	_sleepers.clear()
	for p: CharacterArtProfile in garden.roster:
		if _sleepers.size() >= BEDS:
			break
		if garden.game.pet_state.get(p.pet_name, "") != "resident":
			continue
		var node: HedgePetNode = garden.node_for(p)
		if not garden.pet_mode(node) in ["away", "roam", "peek", "leave"]:
			continue
		var bed: Vector3 = _beds[_sleepers.size()]
		borrow(node)
		var s := {"node": node}
		node.position = to_global(bed) + Vector3(0, 0.08, 0)
		node.rotation = Vector3(0, atan2(-bed.x, -bed.z) + PI * 0.5 + randf_range(-0.4, 0.4), 0)   # curled toward the lamp
		node.set_sleeping(true)
		s["zz"] = _zz(node)
		_sleepers.append(s)


func _names() -> String:
	var names: Array = _sleepers.map(func(s) -> String: return (s["node"] as HedgePetNode).profile.pet_name)
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]


func _zz(node: HedgePetNode) -> Label3D:
	var l := Label3D.new()
	l.text = "z"
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = Color(0.98, 0.94, 0.84, 0.0)
	l.outline_size = 0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = node.global_position + Vector3(0, 0.9, 0)
	l.set_meta("base", l.global_position)
	l.set_meta("phase", randf() * TAU)
	return l


# ------------------------------------------------------------------ the room
func _build() -> void:
	var earth := GardenProps.mat("denearth", Color("5a4030"))
	var dome := MeshInstance3D.new()                     # a hemisphere seen from inside
	dome.mesh = _inside_out(ROOM)
	dome.material_override = earth
	dome.scale = Vector3(1, ROOF, 1)
	add_child(dome)
	GardenProps.part(self, GardenProps.cyl(ROOM - 0.05, ROOM - 0.05, 0.1, 32), GardenProps.mat("denfloor", Color("6e5038")), Vector3(0, -0.05, 0), Vector3.ZERO, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1031
	# stones in the walls, roots through the ceiling
	var stone := GardenProps.mat("denstone", Color("7a7068"))
	for k in range(40):
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.05, 0.75)
		if absf(angle_difference(a, -PI * 0.5)) < 0.35 and up < 0.4:
			continue                                     # not across the tunnel mouth
		var d := Vector3(cos(a) * cos(up * 1.4), sin(up * 1.4) * ROOF, sin(a) * cos(up * 1.4)) * (ROOM - 0.05)
		GardenProps.part(self, GardenProps.blob(Vector3(0.36, 0.22, 0.3) * rng.randf_range(0.6, 1.3), "pebble"), stone, d, Vector3(rng.randf_range(0, 40), rng.randf_range(0, 360), 0), 0.0)
	var root_mat := GardenProps.mat("denroot", Color("7a5a3a"))
	for k in range(14):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.6, 5.0)
		var top := ROOM * ROOF * sqrt(maxf(0.0, 1.0 - pow(r / ROOM, 2.0)))
		var len := rng.randf_range(0.8, 2.0)
		GardenProps.part(self, GardenProps.cyl(0.025, 0.08, len, 6), root_mat, Vector3(cos(a) * r, top - len * 0.45, sin(a) * r), Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), 0.006)
	# the moss beds, each with a scatter of dry leaves
	var moss := GardenProps.mat("denmoss", Color("5e7a3a"))
	var leaf := GardenProps.mat("denleaf", Color("b8743a"))
	for k in range(BEDS):
		var a := TAU * k / BEDS + 0.3
		var at := Vector3(cos(a), 0, sin(a)) * BED_RING
		_beds.append(at)
		GardenProps.part(self, GardenProps.blob(Vector3(1.0, 0.12, 0.8), "pebble"), moss, at + Vector3(0, 0.02, 0), Vector3(0, rad_to_deg(-a), 0), 0.008)
		for j in range(7):
			GardenProps.part(self, GardenProps.blob(Vector3(0.12, 0.014, 0.07), {"exponent": 2.0}), leaf, at + Vector3(rng.randf_range(-1.1, 1.1), 0.03, rng.randf_range(-0.9, 0.9)), Vector3(0, rng.randf_range(0, 360), 0), 0.0)
	# the firefly jar in the middle: the lamp
	var lamp_at := Node3D.new()                        # the jar, and the fireflies in it, at twice life size: it's the room's lamp
	lamp_at.scale = Vector3.ONE * 2.0
	add_child(lamp_at)
	var jar := GardenProps.mat("denjar", Color(0.85, 0.92, 0.88, 0.35))
	jar.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	GardenProps.part(lamp_at, GardenProps.cyl(0.16, 0.16, 0.36, 16), jar, Vector3(0, 0.18, 0), Vector3.ZERO, 0.006)
	GardenProps.part(lamp_at, GardenProps.cyl(0.13, 0.13, 0.05, 16), GardenProps.mat("denlid", Color("8a7a5a")), Vector3(0, 0.385, 0), Vector3.ZERO, 0.006)
	var fly := StandardMaterial3D.new()
	fly.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fly.albedo_color = Color("fff2a0")
	for k in range(7):
		var f := GardenProps.part(lamp_at, GardenProps.blob(Vector3(0.018, 0.018, 0.018), {"exponent": 2.0}), fly, Vector3(rng.randf_range(-0.09, 0.09), rng.randf_range(0.08, 0.3), rng.randf_range(-0.09, 0.09)), Vector3.ZERO, 0.0)
		f.set_meta("home", f.position)
		f.set_meta("phase", rng.randf() * TAU)
		_fireflies.append(f)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffbe72")
	lamp.light_energy = 2.6
	lamp.omni_range = 9.0
	lamp.omni_attenuation = 1.2
	lamp.position = Vector3(0, 1.0, 0)
	add_child(lamp)
	# daylight down the tunnel, behind the camera's usual side
	var day := StandardMaterial3D.new()
	day.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	day.albedo_color = Color("e8ecc8")
	var hole := GardenProps.part(self, GardenProps.cyl(0.8, 0.8, 0.02, 24), day, Vector3(0, 0.8, -ROOM + 0.25), Vector3(90, 0, 0), 0.0)
	hole.scale = Vector3(1, 1, 0.8)
	var spill := OmniLight3D.new()
	spill.light_color = Color("c8d4e0")
	spill.light_energy = 0.6
	spill.omni_range = 6.0
	spill.position = Vector3(0, 1.2, -ROOM + 1.0)
	add_child(spill)
	var env := dark_env(Color("1e1610"), Color("8a6a4a"), 0.35)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.environment = env
	add_child(cam)
	_placecamera()


## A hemisphere with its faces and normals turned inward (lit from inside).
func _inside_out(radius: float) -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.is_hemisphere = true
	s.radial_segments = 32
	s.rings = 12
	var arrays := s.get_mesh_arrays()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in normals.size():
		normals[i] = -normals[i]
	arrays[Mesh.ARRAY_NORMAL] = normals
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		idx[i] = idx[i + 1]
		idx[i + 1] = a
	arrays[Mesh.ARRAY_INDEX] = idx
	arrays[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# ------------------------------------------------------------------ looking around
func _placecamera() -> void:
	var c := Vector3(0, 0.35, 0)
	var off := Vector3(sin(_yaw) * cos(_elev), sin(_elev), cos(_yaw) * cos(_elev)) * _dist
	cam.position = c + off
	cam.look_at(to_global(c), Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	_yaw = lerp_angle(_yaw, _goal_yaw, clampf(delta * 8.0, 0.0, 1.0))
	_placecamera()
	for f: Node3D in _fireflies:
		var ph: float = f.get_meta("phase")
		f.position = f.get_meta("home") + Vector3(sin(_t * 0.9 + ph), sin(_t * 1.3 + ph * 2.0) * 0.6, cos(_t * 0.7 + ph)) * 0.05
		f.visible = sin(_t * 1.7 + ph * 3.0) > -0.6
	for s in _sleepers:                                  # z ... z ... drifting up, each in its own breath
		var l: Label3D = s["zz"]
		var k := fmod(_t * 0.35 + float(l.get_meta("phase")) / TAU, 1.0)
		l.global_position = (l.get_meta("base") as Vector3) + Vector3(sin(k * 6.0) * 0.08, k * 0.6, 0)
		l.modulate.a = sin(k * PI) * 0.8
		l.font_size = int(lerpf(40.0, 80.0, k))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_dist = clampf(_dist * (0.92 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.08), 3.6, 5.3)
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
		if _moved:                                       # any drag looks around the room
			_goal_yaw -= event.relative.x * 0.004
			_elev = clampf(_elev + event.relative.y * 0.002, deg_to_rad(20), deg_to_rad(38))


func _tap(at: Vector2) -> void:
	for s in _sleepers:
		var node: HedgePetNode = s["node"]
		if cam.unproject_position(node.global_position + Vector3(0, 0.4, 0)).distance_to(at) < 110.0:
			node.tap()
			garden.game.toast(["%s stirs, sighs, and settles again.", "%s's ear twitches. Still asleep.", "%s curls up a little tighter.", "%s is dreaming about something nice."].pick_random() % node.profile.pet_name)
			return
