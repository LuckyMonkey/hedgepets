extends "res://scripts/garden/woods/woods_scenery.gd"

## Woods 4/6 - the landmarks: the old oak, the creek, the ridge and its binoculars, sunbeams, the pond, the cellar hole.
##
## One function per named place: the old oak, the creek with its stepping stones, the ridge (the ravine with
## strata ledges and the mounted binoculars), the mossy fork, the pond, the cellar hole, the trailhead board.
## _clearings() walks the clearings and calls each landmark. The binoculars are here because they belong to the
## ridge: entering them swaps the camera for a zoomed one aimed at six details to find (BINOCULAR_DETAILS).
## Sunbeams, motes and stars are the light that makes the woods "dark, but kind".
##
## Part of the woods layer chain (see scripts/garden/woods.gd for the full order). Code here was moved verbatim from
## the old single file; only its place changed.

var _at := "trailhead"
var _goal_yaw := 0.0
var _pitch := deg_to_rad(-6.0)
var _fireflies: Array = []
var _binoculars: Node3D
var _binocular_mode := false
var _binocular_returning := false
var _binocular_target := Vector3.ZERO
var _binocular_yaw := 0.0
var _binocular_pitch := deg_to_rad(-10.0)
var _binocular_fov := 24.0
var _binocular_pos_state := {"v": Vector3.ZERO}
var _binocular_fov_state := {"v": 0.0}
var _binocular_caption: Label
var _binocular_dwell := 0.0
var _binocular_candidate := ""
const BINOCULAR_DETAILS := {
	"heron": {"name": "A heron in the creek", "at": Vector3(5.9, -1.0, -2.5)},
	"hawk": {"name": "A hawk circling above the ridge", "at": Vector3(12.8, 2.6, -8.0)},
	"fox": {"name": "A fox at the den", "at": Vector3(10.8, -0.2, -5.2)},
	"deer": {"name": "A deer at the treeline", "at": Vector3(9.1, 0.4, -6.8)},
	"church": {"name": "The church weathervane", "at": Vector3(7.6, 0.7, -1.1)},
	"garden": {"name": "Home, the garden by the white house", "at": Vector3(10.9, 0.6, 36.4)},
}
var campfire: Node3D                  # fire_pit.gd, in fern hollow
var land: MiniatureSky                 # distant_land.gd: the miniature land beyond the woods
## Each clearing: a lantern on its hook (warm light), a few rocks and logs; fireflies drifting; its own landmark.
func _clearings(rng: RandomNumberGenerator) -> void:
	var fly := StandardMaterial3D.new()
	fly.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fly.albedo_color = Color("fff2cc")                          # motes, drifting (daytime: not fireflies)
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	for id in NODES:
		await Slicer.tick(self)
		var c := node_pos(id)
		var a := rng.randf() * TAU
		if id == "nursery":                              # it has its own lamps and things (nursery.gd)
			continue
		var spot := _off_trail(c + _gap_dir(id) * 4.0, 2.4)   # in the widest gap between the trails (never on one)
		GardenProps.lantern(self, spot, rad_to_deg(a))
		var light := OmniLight3D.new()
		light.light_color = Color("ffbe72")
		light.light_energy = 0.45                                  # lit, but it's daytime: a little warmth in the shade
		light.omni_range = 6.0
		light.position = spot + Vector3(0, 1.4, 0)
		add_child(light)
		for k in range(3):                               # (same numbers drawn as ever; each kept clear by its own size)
			var raw := _clear_spot(c, rng.randf_range(4.0, 6.5), rng)
			var size := snappedf(rng.randf_range(0.5, 1.1), 0.1)
			var r := _off_trail(_out_of_view(id, c, raw), 1.3 + size)
			GardenProps.rock(self, r + Vector3(0, -0.1, 0), size, rng)
		var raw_log := _clear_spot(c, rng.randf_range(4.0, 6.0), rng)
		var log_len := rng.randf_range(2.4, 3.6)
		var log := _off_trail(_out_of_view(id, c, raw_log), 1.3 + log_len * 0.5)   # a log is long: all of it off the trail
		var log_yaw := rng.randf_range(0, 180)
		var log_ok := false
		for k in range(6):                               # and checked end to end: turned or moved out until it's clear
			var axis := Vector3(sin(deg_to_rad(log_yaw)), 0, cos(deg_to_rad(log_yaw))) * log_len * 0.5
			var clear := true
			for f: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				clear = clear and eye_clear(log + axis * f + Vector3(0, 0.3, 0), 0.75)
				clear = clear and _home_dist(Vector2(log.x + axis.x * f, log.z + axis.z * f)) > 1.0
			if clear:
				log_ok = true
				break
			log_yaw += 60.0
			if k >= 2:
				log = _off_trail(log + (log - c).normalized() * 0.8, 1.3 + log_len * 0.5)
		if log_ok:                                       # (nowhere clear to lie: this clearing does without)
			var log_node := GardenProps.part(self, GardenProps.cyl(0.28, 0.32, log_len, 9), GardenProps.mat("woodslog", Color("4a3a2a")), log + Vector3(0, 0.25, 0), Vector3(90, log_yaw, 0), 0.012)
			_placement("%s:log_0" % id, log_node, log_len * 0.5)
		for k in range(10):
			var f := MeshInstance3D.new()
			f.mesh = dot
			f.material_override = fly
			f.position = c + Vector3(rng.randf_range(-6, 6), rng.randf_range(0.5, 2.6), rng.randf_range(-6, 6))
			f.set_meta("home", f.position)
			f.set_meta("phase", rng.randf() * TAU)
			add_child(f)
			_fireflies.append(f)
	for f: Callable in [_old_oak, _creek, _ridge, _mossy_fork, func(_r) -> void: _trailhead_board(), _pond, _cellar_hole]:
		await Slicer.tick(self)
		f.call(rng)
	var camp := node_pos("hollow") + Vector3(2.6, 0, -1.8)     # a ring of stones in fern hollow: tap it to light it
	camp.y = height(camp.x, camp.z)
	campfire = preload("res://scripts/garden/fire_pit.gd").build(self, camp, 0.0)


# ------------------------------------------------------------------ the landmarks
## The old oak: one enormous tree alone in its glade - a flared trunk with roots over the ground, a hollow, great
## limbs going out sideways, a crown wider than the clearing. A lantern hangs from it.
func _old_oak(rng: RandomNumberGenerator) -> void:
	var at := _off_trail(Vector3(_oak_at().x, 0, _oak_at().y), 4.2) - Vector3(0, 0.2, 0)   # the trunk, roots and all, clear of every trail
	var p := Vector2(at.x, at.z)
	var bark := GardenProps.mat("oldoak", Color("4a3c30"))
	var r := GardenProps.root(self, "OldOak", at, rng.randf() * 360.0)
	_placement("oak:old_oak", r, 4.0)
	GardenProps.part(r, GardenProps.cyl(1.15, 1.9, 7.5, 16), bark, Vector3(0, 3.75, 0), Vector3(0, 0, 3), 0.025)
	GardenProps.part(r, GardenProps.blob(Vector3(2.5, 1.0, 2.5), {"exponent": 2.0, "flat_bottom": 0.6}), bark, Vector3(0, 0.4, 0), Vector3.ZERO, 0.02)
	for k in range(7):                                    # roots over the ground
		var a := k * TAU / 7.0 + rng.randf_range(-0.2, 0.2)
		var len := rng.randf_range(2.2, 3.4)
		GardenProps.part(r, GardenProps.blob(Vector3(len, 0.38, 0.5), {"exponent": 2.0, "taper": 0.5}), bark, Vector3(cos(a), 0.0, sin(a)) * (1.4 + len * 0.45) + Vector3(0, 0.15, 0), Vector3(0, -rad_to_deg(a), -6), 0.015)
	for k in range(14):                                   # deep furrowed bark
		var a := k * TAU / 14.0 + rng.randf_range(-0.1, 0.1)
		var ridge := GardenProps.part(r, GardenProps.blob(Vector3(0.22, 3.4, 0.22), {"exponent": 2.0}), GardenProps.mat("oakridge", Color("3e3228")), Vector3(cos(a) * 1.45, 3.4, sin(a) * 1.45), Vector3(0, 0, 0), 0.0)
		ridge.rotation = Vector3(sin(a) * 0.08, 0, -cos(a) * 0.08)
	GardenProps.part(r, GardenProps.blob(Vector3(0.42, 0.7, 0.3), {"exponent": 2.0}), GardenProps.mat("oakhollow", Color("120e0a")), Vector3(0, 1.7, 1.62), Vector3(-6, 0, 0), 0.0)
	var crowns: Array = []                                # the crown: the same leaf clusters as every tree, just more of them
	for k in range(6):                                    # the great limbs, each ending in its own mass of leaves
		var a := k * TAU / 6.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var limb := GardenProps.part(r, GardenProps.cyl(0.28, 0.7, 7.0, 10), bark, Vector3(0, 7.0, 0) + out * 2.6 + Vector3(0, 1.6, 0), Vector3.ZERO, 0.015)
		limb.look_at_from_position(limb.position, limb.position + out * 0.8 + Vector3(0, 0.6, 0), Vector3.UP)
		limb.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		var tip := Vector3(0, 11.0, 0) + out * rng.randf_range(6.0, 7.5)
		for j in range(3):
			var off := Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.6, 0.9), rng.randf_range(-1.6, 1.6))
			crowns.append(TreeFactory.crown("oak", tip + off, rng.randi(), rng.randf_range(1.3, 1.6)))
	for j in range(5):                                    # and the top, over the trunk
		var off := Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(0.0, 1.5), rng.randf_range(-3.0, 3.0))
		crowns.append(TreeFactory.crown("oak", Vector3(0, 13.5, 0) + off, rng.randi(), rng.randf_range(1.5, 1.8)))
	for n in TreeFactory.build_batch(crowns, Vector3(0, 11.0, 0)):
		n.name = "Crown_%s" % n.name
		r.add_child(n)


## The creek: water in its channel the whole way through the woods, rocks and cattails on the banks, and stepping
## stones where the trails cross it.
func _creek(rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := CREEK_DIR.orthogonal()
	var prev: Array = []
	for i in range(-72, 73):
		var c := _creek_point(float(i))
		var y := height(c.x, c.y) + 0.72
		var l := c + side * 1.95
		var r := c - side * 1.95
		var row := [Vector3(l.x, y, l.y), Vector3(r.x, y, r.y)]
		if not prev.is_empty():
			for v in [prev[0], row[0], row[1], prev[0], row[1], prev[1]]:
				st.add_vertex(v)
		prev = row
	st.generate_normals()
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.3, 0.36, 0.92)       # dark water with the moon on it
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic_specular = 1.0
	water.emission_enabled = true
	water.emission = Color("0c161c")
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = water
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	for i in range(-70, 71, 3):                           # the banks
		for sgn: float in [-1.0, 1.0]:
			if rng.randf() < 0.45:
				var b := _creek_point(i + rng.randf_range(-1, 1)) + side * sgn * rng.randf_range(2.1, 2.8)
				if not _near_trail(b, 1.4):
					var size := snappedf(rng.randf_range(0.35, 0.7), 0.1)
					if _near_trail(b, 1.7 + size):
						size = 0.25                                  # right by the trail: only a small one
					GardenProps.rock(self, Vector3(b.x, height(b.x, b.y) - 0.15, b.y), size, rng)
			elif rng.randf() < 0.3:
				var b := _creek_point(i + rng.randf_range(-1, 1)) + side * sgn * rng.randf_range(1.6, 2.2)
				if not _near_trail(b, 2.0):
					GardenProps.cattails(self, Vector3(b.x, height(b.x, b.y), b.y), rng)
	var stone := RockFactory.material(Color("7a7a72"))
	for e in _paths:                                      # stepping stones where a trail crosses
		var pts: PackedVector3Array = e["pts"]
		for i in range(pts.size()):
			var q := Vector2(pts[i].x, pts[i].z)
			var along := (q - CREEK_AT).dot(CREEK_DIR)
			if absf(_creek_lat(q)) < 2.1 and absf(along) < 72.0:
				var mid := _creek_point(along)
				var y := height(mid.x, mid.y) + 0.78
				GardenProps.part(self, RockFactory.make({"role": "stepping_stone", "size": Vector3(0.84, 0.28, 0.68), "seed": rng.randi(), "flatten": 0.96}), stone, Vector3(pts[i].x, y - 0.14, pts[i].z), Vector3(0, rng.randf_range(0, 180), 0), 0.006)


## The ridge: flat lichened rocks at the edge, a weathered bench looking out, a cairn.
func _ridge(rng: RandomNumberGenerator) -> void:
	var c: Vector2 = NODES["ridge"]["at"]
	var side := VIEW_DIR.orthogonal()
	var lichen := RockFactory.material(Color("8a8c80"))
	for k in range(7):
		var p := c + VIEW_DIR * rng.randf_range(4.0, 6.0) + side * (k - 3) * 1.6
		var rs := Vector3(1.0, 0.35, 0.8) * snappedf(rng.randf_range(0.8, 1.3), 0.1)
		var ledge_node := GardenProps.part(self, RockFactory.make({"role": "ledge", "size": rs * 2.0, "seed": rng.randi(), "roughness": 0.14, "facets": 8, "flatten": 0.9}), lichen, Vector3(p.x, height(p.x, p.y) - 0.1 - rs.y, p.y), Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 360), 0), 0.012)
		_placement("ridge:ledge_%d" % k, ledge_node, 1.2)
	var bench3 := _off_trail(Vector3(c.x, 0, c.y) + Vector3(VIEW_DIR.x, 0, VIEW_DIR.y) * 1.2 + Vector3(side.x, 0, side.y) * 2.4, 1.6)
	var bench := GardenProps.root(self, "RidgeBench", bench3, rad_to_deg(atan2(VIEW_DIR.x, VIEW_DIR.y)))
	_placement("ridge:bench", bench, 1.5)
	var grey := GardenProps.mat("greywood", Color("6e665a"))
	GardenProps.part(bench, GardenProps.box(Vector3(1.6, 0.06, 0.4)), grey, Vector3(0, 0.45, 0), Vector3.ZERO, 0.008)
	GardenProps.part(bench, GardenProps.box(Vector3(1.6, 0.3, 0.05)), grey, Vector3(0, 0.72, -0.2), Vector3(-10, 0, 0), 0.008)
	for sx: float in [-0.7, 0.7]:
		GardenProps.part(bench, GardenProps.box(Vector3(0.07, 0.45, 0.35)), grey, Vector3(sx, 0.22, 0), Vector3.ZERO, 0.006)
	var cairn := c - side * 3.0 + VIEW_DIR * 2.0
	var cy := height(cairn.x, cairn.y)
	for k in range(5):
		var w := 0.42 - k * 0.07
		GardenProps.part(self, GardenProps.blob(Vector3(w, 0.11, w * 0.85), "pebble"), lichen, Vector3(cairn.x, cy + 0.1 + k * 0.19, cairn.y), Vector3(0, rng.randf_range(0, 360), 0), 0.006)
	# The ridge is the ravine lookout: thin, broad strata follow the drop instead of reading as boulders.
	var ledge := GardenProps.mat("ravineledge", Color("625d51"))
	var down := VIEW_DIR
	var across := VIEW_DIR.orthogonal()
	for k in range(5):
		var q := Vector2(c.x, c.y) + down * (4.0 + k * 2.0) + across * (k - 2) * 2.1
		var h := height(q.x, q.y)
		GardenProps.part(self, GardenProps.box(Vector3(4.2, 0.18, 1.25)), ledge,
			Vector3(q.x, h + 0.04, q.y), Vector3(0, rad_to_deg(atan2(down.x, down.y)), 0), 0.01)
	_setup_ravine_viewer()


func _setup_ravine_viewer() -> void:
	if _binoculars != null:
		return
	var c: Vector2 = NODES["ridge"]["at"]
	var side := VIEW_DIR.orthogonal()
	var at := _off_trail(Vector3(c.x, height(c.x, c.y), c.y) + Vector3(side.x, 0, side.y) * 2.5 + Vector3(VIEW_DIR.x, 0, VIEW_DIR.y) * 1.8, 1.2)
	_binoculars = GardenProps.root(self, "RavineBinoculars", at, rad_to_deg(atan2(VIEW_DIR.x, VIEW_DIR.y)))
	_placement("ridge:binoculars", _binoculars, 1.0)
	var dark := GardenProps.mat("binocularmetal", Color("3c4a48"))
	var wood := GardenProps.mat("binocularpost", Color("5c4634"))
	GardenProps.part(_binoculars, GardenProps.box(Vector3(0.14, 1.25, 0.14)), wood, Vector3(0, 0.62, 0), Vector3.ZERO, 0.008)
	GardenProps.part(_binoculars, GardenProps.box(Vector3(0.8, 0.12, 0.18)), wood, Vector3(0, 1.2, 0), Vector3.ZERO, 0.008)
	for sx: float in [-0.18, 0.18]:
		GardenProps.part(_binoculars, GardenProps.cyl(0.09, 0.09, 0.48, 10), dark, Vector3(sx, 1.34, -0.12), Vector3(90, 0, 0), 0.006)
	GardenProps.part(_binoculars, GardenProps.box(Vector3(0.48, 0.08, 0.12)), dark, Vector3(0, 1.34, 0.13), Vector3.ZERO, 0.006)
	_binocular_target = at + Vector3(0, 1.1, 0) - Vector3(VIEW_DIR.x, 0, VIEW_DIR.y) * 0.7


func _binocular_saved() -> Dictionary:
	var b: Dictionary = garden.game.woods_finds.get("binoculars", {})
	return b if b is Dictionary else {}


func _enter_binoculars() -> void:
	if _binoculars == null or _binocular_mode:
		return
	_binocular_mode = true
	_binocular_returning = false
	_binocular_fov = 24.0
	_binocular_yaw = _heading_of(Vector3(VIEW_DIR.x, 0, VIEW_DIR.y))
	_binocular_pitch = deg_to_rad(-10.0)
	_binocular_pos_state["v"] = Vector3.ZERO
	_binocular_fov_state["v"] = 0.0
	_binocular_caption.text = "🔭 Drag to look · scroll to zoom · tap to step back"
	Motion.fade(_binocular_caption, 1.0, Motion.FAST)
	if land != null:
		land.res = 0.9
		land._fit()
	Telemetry.event("binoculars", {"place": "ridge"})


func _leave_binoculars() -> void:
	if not _binocular_mode:
		return
	_binocular_mode = false
	_binocular_returning = true
	Motion.fade(_binocular_caption, 0.0, Motion.FAST)
	_binocular_candidate = ""
	_binocular_dwell = 0.0
	_binocular_fov = 70.0
	_binocular_target = node_pos(_at) + Vector3(0, EYE, 0)
	_binocular_yaw = _goal_yaw
	_binocular_pitch = _pitch
	if land != null:
		land.quality_tier_changed(str(get_meta("quality_tier", "medium")))


func _binocular_detail() -> void:
	if land == null or not _binocular_mode:
		return
	var best := ""
	var best_d := 0.065
	for id: String in BINOCULAR_DETAILS:
		var d: Vector3 = BINOCULAR_DETAILS[id]["at"]
		var screen := cam.unproject_position(land.to_global(d * MiniatureSky.SCALE))
		var nd := screen.distance_to(get_viewport().get_visible_rect().size * 0.5) / minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y)
		if nd < best_d:
			best_d = nd
			best = id
	if best != _binocular_candidate:
		_binocular_candidate = best
		_binocular_dwell = 0.0
	elif best != "":
		_binocular_dwell += get_process_delta_time()
		if _binocular_dwell > 0.8:
			var found: Dictionary = _binocular_saved()
			if not found.has(best):
				found[best] = true
				garden.game.woods_finds["binoculars"] = found
				garden.game.save()
				Telemetry.event("binocular_find", {"detail": best})
			_binocular_caption.text = "🔭 " + str(BINOCULAR_DETAILS[best]["name"])


func _update_binocular_camera(delta: float) -> void:
	var target := _binocular_target
	cam.position = Motion.spring(cam.position, target, _binocular_pos_state, 0.42, delta)
	cam.fov = Motion.spring(cam.fov, _binocular_fov, _binocular_fov_state, 0.25, delta)
	cam.rotation = Vector3(Motion.approach(cam.rotation.x, _binocular_pitch, 8.0, delta), Motion.approach(cam.rotation.y, _binocular_yaw, 8.0, delta), 0)
	if _binocular_mode:
		_binocular_detail()
	elif cam.position.distance_to(target) < 0.03 and absf(cam.fov - 70.0) < 0.05:
		_binocular_returning = false


## Where the sun gets through: a slanting beam (two crossed cards, the garden's light-shaft shader, stronger). A couple near most clearings (off to the side, never in your face), more along
## the trails.
func _sunbeams(rng: RandomNumberGenerator, to_sun: Vector3) -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/light_shaft.gdshader")
	# sparingly: one by each place, a few along the trails; none at the two overlooks (you'd look down on them)
	var spots: Array = []
	var overlooks: Array = [NODES["oak"]["at"], NODES["ridge"]["at"]]
	for id in NODES:
		var c: Vector2 = NODES[id]["at"]
		var p: Vector2 = c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 8.0)
		if not id in ["nursery", "oak", "ridge"]:
			spots.append(p)
	for e in _paths:
		var pts: PackedVector3Array = e["pts"]
		for i in range(6, pts.size() - 6, 14):
			if rng.randf() < 0.35:
				var p := Vector2(pts[i].x, pts[i].z) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
				if overlooks.all(func(o: Vector2) -> bool: return o.distance_to(p) > 20.0):
					spots.append(p)
	var side := to_sun.cross(Vector3.FORWARD if absf(to_sun.z) < 0.9 else Vector3.RIGHT).normalized()
	for p: Vector2 in spots:
		var at := _off_trail(Vector3(p.x, 0, p.y), 2.5)          # never standing on a trail
		var beam := Node3D.new()
		beam.name = "Sunbeam"
		add_child(beam)
		beam.position = at
		beam.basis = Basis(side, to_sun, side.cross(to_sun).normalized())
		var mi := m.duplicate() as ShaderMaterial
		mi.set_shader_parameter("seed", rng.randf())
		mi.set_shader_parameter("strength", rng.randf_range(0.02, 0.032))
		mi.set_shader_parameter("colour", Color("ffe6b4"))
		var w := rng.randf_range(0.8, 2.0)
		for k in range(2):
			var card := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(w, 20.0)
			card.mesh = q
			card.material_override = mi
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			card.rotation.y = k * PI * 0.5
			card.position = Vector3(0, 10.0, 0)
			beam.add_child(card)
		for k in range(4):                                # motes, turning slowly in the light
			_fireflies.append(_mote(at + to_sun * rng.randf_range(0.8, 3.5) + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), rng))


func _mote(at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var f := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.018
	dot.height = 0.036
	dot.radial_segments = 4
	dot.rings = 2
	f.mesh = dot
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("fff2cc")
	f.material_override = m
	f.position = at
	f.set_meta("home", at)
	f.set_meta("phase", rng.randf() * TAU)
	add_child(f)
	return f


func _stars(rng: RandomNumberGenerator) -> void:
	var items: Array = []
	var c := node_pos("ridge")
	for k in range(260):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.12, 1.0), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(0.25, 0.7)
		items.append([Transform3D(Basis().scaled(Vector3.ONE * s), c + dir * 300.0), Color(1, 1, 0.94).lerp(Color("c8d4ff"), rng.randf())])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var dot := SphereMesh.new()
	dot.radius = 1.0
	dot.height = 2.0
	dot.radial_segments = 6
	dot.rings = 3
	mm.mesh = dot
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## The mossy fork: boulders gone green on top.
func _mossy_fork(rng: RandomNumberGenerator) -> void:
	var c := node_pos("fork")
	var moss := GardenProps.mat("forkmoss", Color("4e6e30"))
	for k in range(6):
		var raw := _clear_spot(c, rng.randf_range(3.8, 6.0), rng)
		var size := snappedf(rng.randf_range(0.7, 1.4), 0.1)        # (drawn here as ever; known first, so it's kept clear)
		var p := _off_trail(raw, 1.2 + size)
		var fv := Vector2(p.x - c.x, p.z - c.z)
		if fv.normalized().dot(FORK_VIEW) > 0.75:              # out of the long view north
			p = c + Vector3(-FORK_VIEW.orthogonal().x, 0, -FORK_VIEW.orthogonal().y) * fv.length() * signf(fv.dot(FORK_VIEW.orthogonal()) + 0.001)
			p = _off_trail(Vector3(p.x, 0, p.z), 1.2 + size)
		GardenProps.rock(self, p - Vector3(0, 0.2, 0), size, rng)
		GardenProps.part(self, GardenProps.blob(Vector3(size * 0.9, size * 0.28, size * 0.7), {"exponent": 2.2}), moss, p + Vector3(0, size * 0.42, 0), Vector3(0, rng.randf_range(0, 360), 0), 0.006)


## Beaver pond: still water in a bowl, the lodge (a dome of sticks and mud) out in it, a dam of sticks across the low
## end, lily pads, cattails round the edge, a few gnawed stumps.
func _pond(rng: RandomNumberGenerator) -> void:
	var y := pond_level()
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.3, 0.36, 0.92)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic_specular = 1.0
	water.emission_enabled = true
	water.emission = Color("0c161c")
	var disc := GardenProps.part(self, GardenProps.cyl(POND_R + 0.6, POND_R + 0.6, 0.04, 32), water, Vector3(POND_AT.x, y, POND_AT.y), Vector3.ZERO, 0.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sticks := GardenProps.mat("lodgesticks", Color("5a4a36"))
	var lodge := Vector3(POND_AT.x + 1.5, y, POND_AT.y - 1.0)
	GardenProps.part(self, GardenProps.blob(Vector3(1.7, 1.0, 1.5), {"exponent": 2.0, "flat_bottom": 0.6}), GardenProps.mat("lodgemud", Color("4a3c2e")), lodge, Vector3.ZERO, 0.014)
	for k in range(26):
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.1, 0.8)
		var at := lodge + Vector3(cos(a) * 1.5 * (1.0 - up * 0.6), up, sin(a) * 1.3 * (1.0 - up * 0.6))
		GardenProps.part(self, GardenProps.cyl(0.025, 0.035, rng.randf_range(0.9, 1.6), 5), sticks, at, Vector3(rng.randf_range(40, 80), rng.randf_range(0, 360), 0), 0.0)
	var low := POND_AT + Vector2(-POND_R, 1.5)                  # the dam across the low end
	for k in range(40):
		var along := rng.randf_range(-3.0, 3.0)
		var at := Vector3(low.x + rng.randf_range(-0.4, 0.4), y + rng.randf_range(-0.1, 0.4), low.y + along)
		GardenProps.part(self, GardenProps.cyl(0.03, 0.04, rng.randf_range(0.8, 1.5), 5), sticks, at, Vector3(rng.randf_range(60, 100), rng.randf_range(-30, 30), rng.randf_range(-20, 20)), 0.0)
	var pad := GardenProps.mat("lilypad", Color("4a6a34"))
	for k in range(14):
		var q := POND_AT + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.5, POND_R - 0.5)
		GardenProps.part(self, GardenProps.cyl(0.32, 0.32, 0.015, 10), pad, Vector3(q.x, y + 0.03, q.y), Vector3.ZERO, 0.0)
		if rng.randf() < 0.3:
			GardenProps.part(self, GardenProps.blob(Vector3(0.09, 0.06, 0.09), "pebble"), GardenProps.mat("lily", Color("f2ece4")), Vector3(q.x, y + 0.08, q.y), Vector3.ZERO, 0.0)
	for k in range(10):
		var q := POND_AT + Vector2.from_angle(rng.randf() * TAU) * (POND_R + rng.randf_range(0.2, 1.0))
		if not _near_trail(q, 2.0):
			GardenProps.cattails(self, Vector3(q.x, height(q.x, q.y), q.y), rng)
	for k in range(4):                                      # stumps, gnawed to a point
		var q := POND_AT + Vector2.from_angle(rng.randf() * TAU) * (POND_R + rng.randf_range(1.5, 3.0))
		var gy := height(q.x, q.y)
		GardenProps.part(self, GardenProps.cyl(0.0, 0.22, 0.55, 8), GardenProps.mat("gnawed", Color("c8a878")), Vector3(q.x, gy + 0.27, q.y), Vector3.ZERO, 0.008)


## The cellar hole: all that's left of a farmhouse - a square of dry-laid stone round a pit, a granite step, the
## chimney's base, an old lilac grown huge, and the apple tree that was in the dooryard.
func _cellar_hole(rng: RandomNumberGenerator) -> void:
	var c := Vector3(CELLAR_AT.x, height(CELLAR_AT.x, CELLAR_AT.y), CELLAR_AT.y)
	var stone := GardenProps.mat("cellarstone", Color("7e7a70"))
	for side in range(4):
		var a := side * PI * 0.5
		var along := Vector3(cos(a), 0, sin(a))
		var out := Vector3(-sin(a), 0, cos(a))
		for k in range(9):
			var at := c + out * 3.2 + along * (-3.2 + k * 0.8)
			at.y = height(at.x, at.z)
			for course in range(2):
				GardenProps.part(self, GardenProps.blob(Vector3(0.42, 0.18, 0.3) * snappedf(rng.randf_range(0.8, 1.2), 0.1), "pebble"), stone, at + Vector3(rng.randf_range(-0.1, 0.1), -0.2 - course * 0.32, 0), Vector3(0, rad_to_deg(a) + rng.randf_range(-10, 10), 0), 0.008)
	var step := c + Vector3(0, 0, 3.7)
	step.y = height(step.x, step.z)
	GardenProps.part(self, GardenProps.box(Vector3(1.3, 0.22, 0.5)), GardenProps.mat("granite", Color("9a968c")), step + Vector3(0, 0.05, 0), Vector3(0, 0, 2), 0.01)
	var chimney := c + Vector3(-1.6, 0, -1.4)
	chimney.y = height(chimney.x, chimney.z)
	GardenProps.part(self, GardenProps.box(Vector3(0.9, 1.3, 0.9)), stone, chimney + Vector3(0, 0.3, 0), Vector3(0, 8, 0), 0.012)
	var lilac := _off_trail(c + Vector3(-4.6, 0, -1.6), 3.2)
	GardenProps.part(self, GardenProps.blob(Vector3(1.6, 1.4, 1.5), {"exponent": 2.0}), GardenProps.mat("lilacleaf", Color("3a5030")), lilac + Vector3(0, 1.3, 0), Vector3.ZERO, 0.01)
	for k in range(9):
		var q := lilac + Vector3(rng.randf_range(-1.3, 1.3), rng.randf_range(1.5, 2.4), rng.randf_range(-1.2, 1.2))
		GardenProps.part(self, GardenProps.blob(Vector3(0.14, 0.22, 0.14), "pebble"), GardenProps.mat("lilacbloom", Color("a98ac8")), q, Vector3.ZERO, 0.0)
	var apple := _off_trail(c + Vector3(-2.4, 0, 5.0), 3.6)
	var bark := GardenProps.mat("applebark", Color("4a3c30"))
	GardenProps.part(self, GardenProps.cyl(0.18, 0.28, 2.4, 9), bark, apple + Vector3(0, 1.2, 0), Vector3(0, 0, 8), 0.01)
	GardenProps.part(self, GardenProps.blob(Vector3(2.2, 1.4, 2.0), {"exponent": 2.0}), GardenProps.mat("applecrown", Color("3a4c28")), apple + Vector3(0.3, 3.0, 0), Vector3.ZERO, 0.0)
	for k in range(14):
		var q := apple + Vector3(rng.randf_range(-1.8, 2.2), rng.randf_range(2.2, 3.6), rng.randf_range(-1.6, 1.6))
		GardenProps.part(self, GardenProps.blob(Vector3(0.07, 0.07, 0.07), "pebble"), GardenProps.mat("redapple", Color("b8402e")), q, Vector3.ZERO, 0.0)


## The trailhead: a little roofed board where a map would go.
func _trailhead_board() -> void:
	var c := node_pos("trailhead")
	# Keep the board behind the arrival camera's forward cone; it is found by turning back toward home.
	var at := _off_trail(c + Vector3(HOME_DIR.x, 0, HOME_DIR.y) * 4.5, 1.6)
	var r := GardenProps.root(self, "TrailBoard", at, -30.0)
	_placement("trailhead:sign_home", r, 1.0)
	var wood := GardenProps.mat("boardwood", Color("6a5038"))
	for sx: float in [-0.6, 0.6]:
		GardenProps.part(r, GardenProps.box(Vector3(0.1, 1.9, 0.1)), wood, Vector3(sx, 0.95, 0), Vector3.ZERO, 0.008)
	GardenProps.part(r, GardenProps.box(Vector3(1.3, 0.85, 0.05)), GardenProps.mat("boardface", Color("8a7458")), Vector3(0, 1.3, 0.02), Vector3.ZERO, 0.008)
	GardenProps.part(r, GardenProps.box(Vector3(1.5, 0.05, 0.45)), wood, Vector3(0, 1.92, 0), Vector3(-12, 0, 0), 0.008)
