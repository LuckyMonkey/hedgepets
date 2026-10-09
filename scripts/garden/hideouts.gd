extends Node

## Hiding places: a paint bucket, a big pot, the old well, the burrow. A pet walks to one, climbs up onto the rim in a
## little arc, slides down inside (the walls hide it as it goes, a puff of its own leaves); at the same moment the
## opening fills with its texture (its leaves over its moss) and a simple face peeks out: two dark eyes with light
## dots that blink and look around. Coming out is the same, backwards. No pop-in anywhere (Motion).
## The burrow is also a way in (garden.GATES["burrow"]): burrowing pets arrive by peeking out of it and climbing out.

## kind -> where the opening is (node-local), its radius, how deep it goes, and which way in ("down" / "in")
const SPOTS := {
	"bucket": {"open": Vector3(0, 0.53, 0), "r": 0.28, "depth": 0.45, "way": "down"},
	"planter": {"open": Vector3(0, 0.6, 0), "r": 0.4, "depth": 0.5, "way": "down"},
	"well": {"open": Vector3(0, 0.82, 0), "r": 0.68, "depth": 1.0, "way": "down"},
	"burrow": {"open": Vector3(0.62, 0.2, 0), "r": 0.3, "depth": 0.7, "way": "in"},
}

var garden: Node3D
var spots: Array = []            # {thing, kind, occupant, fill}


func setup(g: Node3D) -> void:
	garden = g
	for t in garden.things:
		if SPOTS.has(t["kind"]):
			add_spot(t)


func add_spot(t: Dictionary) -> void:
	spots.append({"thing": t, "kind": t["kind"], "occupant": null, "fill": null})


## A placed hideout cleared away (garden_game._clear): only ever when nobody's in it.
func remove_spot(t: Dictionary) -> void:
	spots = spots.filter(func(s) -> bool: return s["thing"] != t)


func occupied(t: Dictionary) -> bool:
	for s in spots:
		if s["thing"] == t and s["occupant"] != null:
			return true
	return false


func spot_of(kind: String) -> Dictionary:
	for s in spots:
		if s["kind"] == kind:
			return s
	return {}


func opening(s: Dictionary) -> Vector3:
	return (s["thing"]["node"] as Node3D).to_global(SPOTS[s["kind"]]["open"])


func _out_dir(s: Dictionary) -> Vector3:
	var node: Node3D = s["thing"]["node"]
	return (node.global_basis * Vector3.RIGHT).normalized() if SPOTS[s["kind"]]["way"] == "in" else Vector3.UP


## Where a pet stands before it climbs in: on the ground just outside, facing the opening.
func approach_point(s: Dictionary, node: HedgePetNode) -> Vector3:
	var o := opening(s)
	var pr: float = garden.pet_radius(node)
	var from := Vector3(node.position.x - o.x, 0, node.position.z - o.z)
	if SPOTS[s["kind"]]["way"] == "in":
		from = _out_dir(s) * Vector3(1, 0, 1)
	from = from.normalized() if from.length() > 0.01 else Vector3.BACK
	var reach := float(s["thing"]["radius"]) * 0.8 + pr + 0.05
	return Vector3(o.x, 0, o.z) + from * reach


## Go and hide somewhere nearby that's free. False if there's nowhere.
func go_hide(node: HedgePetNode, w: Dictionary) -> bool:
	var free: Array = spots.filter(func(s) -> bool: return s["occupant"] == null and opening(s).distance_to(node.position) < 12.0)
	if free.is_empty():
		return false
	var s: Dictionary = free.pick_random()
	s["occupant"] = node                                     # reserved on the way
	w["mode"] = "to_hide"
	w["hideout"] = s
	w["target"] = approach_point(s, node)
	w["best_d"] = INF
	return true


## Climb in. then_away: it's leaving the garden this way (the burrow): after a moment the face goes too.
func enter(node: HedgePetNode, s: Dictionary, then_away := false) -> void:
	var w: Dictionary = garden._wander[node]
	w["mode"] = "hiding"
	w["hideout"] = s
	s["occupant"] = node
	var spec: Dictionary = SPOTS[s["kind"]]
	var o := opening(s)
	var rest := node.scale
	node.rotation.y = garden._heading(node.position, o)
	node.walking = 0.0
	var t := Motion.channel(node, "hide")
	if spec["way"] == "down":
		# hop up onto the rim, then slide down inside
		var lift := o + Vector3(0, 0.12, 0)
		var start := node.position
		t.tween_method(func(k: float) -> void:
			node.position = start.lerp(lift, k) + Vector3(0, sin(k * PI) * 0.4, 0), 0.0, 1.0, Motion._d(0.6)).set_trans(Tween.TRANS_SINE)
		t.tween_callback(func() -> void:
			node._leaf_burst()
			_fill(s, node, true))
		t.tween_property(node, "position", o - Vector3(0, float(spec["depth"]), 0), Motion._d(0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(node, "scale", rest * 0.55, Motion._d(0.7)).set_trans(Tween.TRANS_SINE)
	else:
		# crouch and slide in through the doorway
		var into := o - _out_dir(s) * float(spec["depth"]) - Vector3(0, 0.25, 0)
		t.tween_property(node, "position", o - Vector3(0, 0.05, 0), Motion._d(0.4)).set_trans(Tween.TRANS_SINE)
		t.tween_callback(func() -> void: _fill(s, node, true))
		t.tween_property(node, "position", into, Motion._d(0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(node, "scale", rest * 0.5, Motion._d(0.7)).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		node.visible = false
		node.scale = rest
		w["mode"] = "hidden"
		w["hidden_t"] = 2.5 if then_away else randf_range(15.0, 40.0)
		w["then_away"] = then_away)


## Already inside (a burrowing pet arriving): the face appears in the doorway, the pet stays out of sight.
func place_hidden(node: HedgePetNode, s: Dictionary, seconds: float) -> void:
	var w: Dictionary = garden._wander[node]
	s["occupant"] = node
	w["hideout"] = s
	w["mode"] = "hidden"
	w["hidden_t"] = seconds
	w["then_away"] = false
	node.visible = false
	node.position = opening(s) - Vector3(0, 0.3, 0)
	_fill(s, node, true)


## Climb out and step onto the grass, then carry on (mode afterwards: roam).
func exit(node: HedgePetNode) -> void:
	var w: Dictionary = garden._wander[node]
	var s: Dictionary = w["hideout"]
	var spec: Dictionary = SPOTS[s["kind"]]
	w["mode"] = "emerging"
	var o := opening(s)
	var rest := node.scale
	var land := approach_point(s, node)
	if spec["way"] == "down":
		land = Vector3(o.x, 0, o.z) + (garden.CENTER - Vector3(o.x, 0, o.z)).normalized() * (float(s["thing"]["radius"]) * 0.8 + garden.pet_radius(node) + 0.1)
	_fill(s, node, false)
	node.scale = rest * 0.55
	node.position = o - (Vector3(0, float(spec["depth"]), 0) if spec["way"] == "down" else _out_dir(s) * float(spec["depth"]) + Vector3(0, 0.25, 0))
	node.visible = true
	node.rotation.y = garden._heading(o, land)
	var t := Motion.channel(node, "hide")
	t.tween_property(node, "position", o + Vector3(0, 0.08, 0), Motion._d(0.55)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "scale", rest, Motion._d(0.55)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var from := o + Vector3(0, 0.08, 0)
	t.tween_method(func(k: float) -> void:
		node.position = from.lerp(land, k) + Vector3(0, sin(k * PI) * 0.45, 0), 0.0, 1.0, Motion._d(0.55)).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		node.position = land
		s["occupant"] = null
		w["hideout"] = null
		w["mode"] = "roam"
		w["target"] = land
		w["wait"] = randf_range(1.0, 3.0)
		node.tap())


## Each frame for a hidden pet: wait, then come out (or, leaving, let the face go and be away).
func tend(node: HedgePetNode, w: Dictionary, delta: float) -> void:
	if w["mode"] != "hidden":
		return
	w["hidden_t"] = float(w["hidden_t"]) - delta
	if w["hidden_t"] > 0.0:
		return
	if w.get("then_away", false):
		var s: Dictionary = w["hideout"]
		_fill(s, node, false)
		s["occupant"] = null
		w["hideout"] = null
		w["then_away"] = false
		garden.set_pet_mode(node, "away", true)
	else:
		exit(node)


## A tap on a hideout with someone inside coaxes them out.
func coax(t: Dictionary) -> bool:
	for s in spots:
		if s["thing"] == t and s["occupant"] != null:
			var w: Dictionary = garden._wander[s["occupant"]]
			if w["mode"] == "hidden":
				w["hidden_t"] = 0.0
				w["then_away"] = false
				return true
	return false


# ------------------------------------------------------------------ the fill: the opening full of the pet
func _fill(s: Dictionary, node: HedgePetNode, show: bool) -> void:
	if not show:
		var old: Node3D = s["fill"]
		s["fill"] = null
		if old != null and is_instance_valid(old):
			var spec: Dictionary = SPOTS[s["kind"]]
			var t := Motion.channel(old, "fill")
			t.tween_property(old, "scale", Vector3(0.2, 0.2, 0.2), Motion._d(0.45)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			t.tween_callback(old.queue_free)
		return
	var spec: Dictionary = SPOTS[s["kind"]]
	var r: float = spec["r"] * 0.92
	var holder := Node3D.new()
	holder.name = "HideoutFill"
	garden.add_child(holder)
	var o := opening(s)
	var normal := _out_dir(s)
	holder.global_position = o
	var x := normal.cross(Vector3.FORWARD if absf(normal.z) < 0.9 else Vector3.RIGHT).normalized()
	holder.global_basis = Basis(x, normal, x.cross(normal).normalized())   # local +y = out of the opening
	# its moss, then its own leaves over it
	var bed := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.05
	bed.mesh = disc
	var m := StandardMaterial3D.new()
	m.albedo_color = node.profile.inner_mass.lightened(0.3)
	m.roughness = 1.0
	bed.material_override = m
	holder.add_child(bed)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node.profile.pet_name)
	var items: Array = []
	var families: Array = node.profile.palette.values()
	for k in range(int(10 + r * 20)):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 0.85
		var size := node.profile.leaf_size * 0.75 * clampf(r / 0.4, 0.6, 1.4)
		var rot := rng.randf() * TAU
		var right := Vector3(cos(rot), 0, sin(rot))
		var up := Vector3(-sin(rot), 0.35, cos(rot)).normalized()
		items.append([Transform3D(Basis(right * size, up * size, right.cross(up).normalized() * size), Vector3(cos(a) * d, 0.03, sin(a) * d)),
			families[rng.randi() % families.size()], Color(float(rng.randi_range(0, 7)), rng.randf() * TAU, 0.6, 0.0)])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0, 0.5, 0)
	mm.mesh = quad
	mm.instance_count = items.size()
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
		mm.set_instance_custom_data(i, items[i][2])
	var leaves := MultiMeshInstance3D.new()
	leaves.multimesh = mm
	leaves.material_override = node.leaves_mat
	holder.add_child(leaves)
	# a simple face: two dark eyes with a light dot, at the front edge, looking out
	var face := Node3D.new()
	face.name = "Face"
	var front: Vector3 = (garden.camera.global_position - o) * Vector3(1, 0, 1)
	front = holder.global_basis.inverse() * front.normalized()
	front.y = 0.0
	front = front.normalized() if front.length() > 0.01 else Vector3.FORWARD
	face.position = front * r * 0.45 + Vector3(0, 0.06, 0)
	face.basis = Basis.looking_at(-front, Vector3.UP)
	holder.add_child(face)
	var es := clampf(r * 0.2, 0.05, 0.11)
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = Color("1a120c")
	eye_m.roughness = 0.6
	var dot_m := StandardMaterial3D.new()
	dot_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_m.albedo_color = Color("f8f4ea")
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = es
		sph.height = es * 2.3
		eye.mesh = sph
		eye.material_override = eye_m
		eye.position = Vector3(side * es * 1.4, es * 0.6, 0)
		eye.name = "Eye"
		face.add_child(eye)
		var dot := MeshInstance3D.new()
		var ds := SphereMesh.new()
		ds.radius = es * 0.28
		ds.height = es * 0.56
		dot.mesh = ds
		dot.material_override = dot_m
		dot.position = Vector3(-es * 0.3, es * 0.4, -es * 0.85)
		eye.add_child(dot)
	s["fill"] = holder
	# rises up from inside as the pet goes down
	holder.global_position = o - normal * float(spec["depth"]) * 0.6
	holder.scale = Vector3.ONE * 0.4
	var t := Motion.channel(holder, "fill")
	t.tween_property(holder, "global_position", o, Motion._d(0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(holder, "scale", Vector3.ONE, Motion._d(0.7)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var _t := 0.0


## The faces in the openings blink and glance around now and then.
func _process(delta: float) -> void:
	_t += delta
	for s in spots:
		var f: Node3D = s["fill"]
		if f == null or not is_instance_valid(f):
			continue
		var face := f.get_node_or_null("Face") as Node3D
		if face == null:
			continue
		var phase := fmod(_t + float(hash(s["kind"]) % 7), 4.3)
		var blink := 1.0 - 0.9 * clampf(1.0 - absf(phase - 4.15) / 0.12, 0.0, 1.0)
		for eye in face.get_children():
			(eye as Node3D).scale.y = blink
		face.rotation.y = sin(_t * 0.7 + float(hash(s["kind"]) % 5)) * 0.35
