extends "res://scripts/garden/garden/garden_world.gd"

## Garden 5/6 - the pets in the yard: spawning, modes, carrying, walking, steering round things, emotes.
##
## Hedgepets in the yard. Each pet is a HedgePetNode (scripts/pet/hedge_pet_node.gd); this layer moves them. A pet
## has a mode (wander, visit, follow, carried, curled up) set through set_pet_mode(); _walk() is the per-frame step:
## pick a target, steer round solid things (colliders, _steer) and other pets (_separate). Contact shadows are cheap
## blobs instead of real shadows (the phone budget).
##
## Part of the garden layer chain (the full order is at the top of scripts/garden/garden.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var roster: Array = []                            # every CharacterArtProfile; pets holds the ones built so far
var _nodes := {}                                  # pet name -> HedgePetNode
var _pending_pet_modes := {}                      # a sliced visitor stays wholly hidden until its baked parts are ready
var _wander := {}                                 # pet -> {target, wait, mode}
var walk_stats := {"arrived": 0, "close_enough": 0, "gave_up": 0, "most_in_a_row": 0}   # tools/checks/stuck_check.gd
var is_built := false

var hideouts: Node
var perches: Node                                 # small birds hop up onto things (perches.gd)
# ------------------------------------------------------------------ pets
func _spawn_pets() -> void:
	roster = CharacterArtProfile.roster()


var _shadow_mat: StandardMaterial3D


## A soft dark pool on the grass under a pet: it sits on the lawn instead of hovering over it.
func _contact_shadow(node: Node3D, p: CharacterArtProfile) -> void:
	if _shadow_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.5))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.albedo_texture = tex
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var r: Vector3 = p.regions["BODY"]["radii"]
	var plane := PlaneMesh.new()
	plane.size = Vector2(r.x * 2.6 + 0.6, r.z * 2.6 + 0.4)
	var s := MeshInstance3D.new()
	s.mesh = plane
	s.material_override = _shadow_mat
	s.position = Vector3(0.2, 0.02, 0)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.name = "ContactShadow"
	node.add_child(s)


## A pet's node, built the first time it comes by (a garden of thirty pets only pays for the ones in it).
func node_for(p: CharacterArtProfile) -> HedgePetNode:
	if _nodes.has(p.pet_name):
		return _nodes[p.pet_name]
	var node := HedgePetNode.new()
	node.name = "Pet_" + p.pet_name
	add_child(node)
	# compact cache profile: a visitor that isn't baked grows from its recipe in slices, hidden till whole (starting
	# residents are built at once, during the load, as ever)
	node.sliced = is_built and not p.starts_resident
	var build_started := HitchLog.begin("pet_build:" + p.pet_name)
	node.setup(p)
	HitchLog.end("pet_build:" + p.pet_name, build_started)
	node.scale = Vector3.ONE * PET_SCALE
	node.rotation.y = _rng.randf_range(-PI, PI)
	node.set_detail("MEDIUM", true)
	node.visible = false
	node.position = GATES[gate_for(p)]["out"]
	_contact_shadow(node, p)
	pets.append(node)
	_nodes[p.pet_name] = node
	_wander[node] = {"target": node.position, "wait": _rng.randf_range(0.5, 3.0), "mode": "away", "gate": gate_for(p)}
	if node.building:
		node.materialized.connect(func() -> void:
			if _pending_pet_modes.has(node):
				var wanted: Array = _pending_pet_modes[node]
				_pending_pet_modes.erase(node)
				set_pet_mode(node, wanted[0], wanted[1]))
	return node


## How a pet is in the garden: "away" (out of sight), "peek" (at the fence gap, looking in), "roam" (wandering),
## "leave" (walking back out through the gap).
func set_pet_mode(node: HedgePetNode, mode: String, at_once := false) -> void:
	if node.building:
		_pending_pet_modes[node] = [mode, at_once]
		node.visible = false
		return
	var w: Dictionary = _wander[node]
	if w["mode"] == "carried":
		return                                           # in the bucket: only uncarry() lets it out
	if w.get("perch") != null:
		perches.release(node, w)                         # off its perch (or not going to it after all)
	var was: String = w["mode"]
	w["mode"] = mode
	var g: Dictionary = GATES[w.get("gate", "fence")]
	var side := Vector3(g["peek"] - g["out"]).normalized().cross(Vector3.UP)
	match mode:
		"away":
			if node.visible and not at_once:             # out through the gap: shrink away, then park outside
				Motion.vanish(node, false).tween_callback(func() -> void: node.position = g["out"])
			else:
				node.visible = false
				node.position = g["out"]
		"peek":
			if was == "away":
				HitchLog.tag("first_draw:" + node.profile.pet_name)
			var bs: Dictionary = hideouts.spot_of("burrow") if hideouts != null else {}
			if w.get("gate", "") == "burrow" and was == "away" and not bs.is_empty() and bs["occupant"] == null:
				hideouts.place_hidden(node, bs, 9999.0)          # a face in the burrow doorway, looking out
				w["mode"] = "hidden"
				w["peeking"] = true
				return
			if was == "away":
				node.position = g["out"].lerp(g["peek"], 0.55) + side * _rng.randf_range(-1.0, 1.0)
				Motion.appear(node, Vector3.ONE * PET_SCALE, Motion.SLOW)
			w["target"] = _fit(g["peek"] + side * _rng.randf_range(-1.2, 1.2), node, w)
		"roam":
			if w.get("peeking", false) and w.get("hideout") != null:
				w["peeking"] = false
				hideouts.exit(node)                          # climbs out of the burrow into the garden
				return
			if was == "away":
				Motion.appear(node, Vector3.ONE * PET_SCALE, Motion.SLOW)
				node.position = _fit(g["peek"].lerp(g["inside"], 0.5), node, w)
				if at_once:                              # already living here when the garden opens
					for k in range(20):
						var spot := Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-2, 3))
						if not _blocked(spot, 0.8):
							node.position = Vector3(spot.x, 0, spot.y)
							break
			w["target"] = _fit(g["inside"] + side * _rng.randf_range(-1.0, 1.0), node, w)
			w["wait"] = 0.5
		"leave":
			w["target"] = g["out"].lerp(g["peek"], 0.2)
			w["best_d"] = INF


## Into the bucket (🪣): out of the garden's hands until uncarry().
func carry(node: HedgePetNode) -> void:
	var w: Dictionary = _wander[node]
	if w.get("perch") != null:
		perches.release(node, w)
	w["mode"] = "carried"
	w["following"] = false
	node.set_sleeping(false)
	node.visible = false


## Out of the bucket at a spot on the lawn: it hops out and carries on as a visitor or resident would.
func uncarry(node: HedgePetNode, at: Vector3, animate := true) -> void:
	var w: Dictionary = _wander[node]
	w["mode"] = "roam"
	node.position = Vector3(at.x, 0, at.z)
	node.scale = Vector3.ONE * PET_SCALE
	w["target"] = node.position
	w["wait"] = 1.5
	node.visible = true
	if animate:
		Motion.appear(node, Vector3.ONE * PET_SCALE)
		node.tap()


func pet_mode(node: HedgePetNode) -> String:
	return _wander[node]["mode"]


var _hover := Vector2.INF                         # the pointer over the garden (mouse only; touch has no hover)
func _clamp_target(t: Vector3) -> Vector3:
	return Vector3(clampf(t.x, -15.0, 15.0), 0.0, clampf(t.z, -14.0, 12.0))


## Wander: stand a while, look around, pick a free spot, walk there with a little step, turning to face the way.
func _walk(node: HedgePetNode, delta: float) -> void:
	var w: Dictionary = _wander[node]
	if w["mode"] == "away" or w["mode"] == "carried":
		return
	if w["mode"] in ["hiding", "hidden", "emerging"]:
		hideouts.tend(node, w, delta)                    # climbing in / tucked away / climbing out
		return
	if perches.up_there(w):
		perches.tend(node, w, delta)                     # hopping up / sitting on top of something / hopping down
		return
	var to: Vector3 = w["target"] - node.position
	to.y = 0.0
	if to.length() < 0.15:
		if w["mode"] == "roam" and float(w.get("best_d", INF)) != INF:
			walk_stats["arrived"] += 1                  # reached the spot it was going for
			w["give_ups"] = 0
		w["best_d"] = INF
		node.walking = move_toward(node.walking, 0.0, delta * 3.0)
		if w["mode"] == "peek":
			node.rotation.y = lerp_angle(node.rotation.y, _heading(node.position, CENTER), clampf(delta * 3.0, 0.0, 1.0))   # looking in
			return
		if w["mode"] == "leave":
			var b: Dictionary = hideouts.spot_of("burrow")
			if w.get("gate", "") == "burrow" and not b.is_empty() and b["occupant"] == null:
				hideouts.enter(node, b, true)            # home: back down the burrow
				return
			set_pet_mode(node, "away")
			return
		if w["mode"] == "to_hide":
			hideouts.enter(node, w["hideout"])
			return
		if w["mode"] == "to_perch":
			perches.hop_up(node, w)
			return
		w["wait"] = float(w["wait"]) - delta
		if node.sleeping:
			# asleep wherever it settled: a slow Zzz now and then; it wakes by itself (or when you tap it)
			w["zzz"] = float(w.get("zzz", 0.0)) - delta
			if float(w["zzz"]) <= 0.0:
				w["zzz"] = _rng.randf_range(3.5, 6.0)
				emote(node, "💤")
			if float(w["wait"]) <= 0.0:
				node.set_sleeping(false)
				w["wait"] = _rng.randf_range(1.5, 3.0)
			return
		# standing: turn three-quarters toward the viewer, so you see faces, not backs (or toward a napping friend)
		var face: float = w.get("face", 0.0)
		var look_at: Vector3 = w["friend"].position if w.get("friend") != null and is_instance_valid(w["friend"]) else camera.position
		node.rotation.y = lerp_angle(node.rotation.y, _heading(node.position, look_at) + face, clampf(delta * 2.0, 0.0, 1.0))
		if w.get("fav", "") != "":
			emote(node, str(w["fav"]))                   # got to a favourite thing: enjoy it
			w["fav"] = ""
		if w.get("friend") != null:
			if is_instance_valid(w["friend"]):
				emote(node, "💕")
			w["friend"] = null
			node.set_sleeping(true)                      # curled up beside its friend
			w["wait"] = _rng.randf_range(25.0, 45.0)
			return
		var free: bool = w["mode"] == "roam" and not w.get("following", false)    # a follower stays with you
		if float(w["wait"]) <= 0.0 and free and _rng.randf() < 0.18:
			node.set_sleeping(true)                      # a nap, right here, however inconvenient
			w["wait"] = _rng.randf_range(20.0, 40.0)
			w["face"] = _rng.randf_range(-1.2, 1.2)
			return
		if float(w["wait"]) <= 0.0 and free and _rng.randf() < 0.15 and _curl_up(node, w):
			return
		if float(w["wait"]) <= 0.0 and free and _rng.randf() < 0.12 and hideouts.go_hide(node, w):
			return
		if float(w["wait"]) <= 0.0 and free and perches.go_perch(node, w):
			return
		if float(w["wait"]) <= 0.0:
			var fav: Dictionary = game.favourite(node) if game != null and _rng.randf() < 0.55 else {}
			if not fav.is_empty():
				var at: Vector3 = fav["at"]
				# beside it, where this pet actually fits (its own size, not a fixed margin)
				var off := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * (float(fav["radius"]) * 0.8 + pet_radius(node) + 0.3)
				var spot := free_spot(Vector2(at.x + off.x, at.z + off.z), pet_radius(node))
				if BOUNDS.has_point(spot) and not _path_blocked(Vector2(node.position.x, node.position.z), spot, pet_radius(node)):
					w["target"] = Vector3(spot.x, 0, spot.y)
					w["best_d"] = INF
					w["fav"] = fav["emote"]
					w["wait"] = _rng.randf_range(5.0, 10.0)
					w["face"] = _rng.randf_range(-0.9, 0.9)
					return
			_pick_target(node, w)
			w["wait"] = _rng.randf_range(2.0, 6.0)
			w["face"] = [-0.8, 0.8].pick_random() + _rng.randf_range(-0.3, 0.3)
		return
	var speed := 1.1 * (0.6 if node.profile.species == "tortoise" else 1.0)
	# steering is smoothed so avoidance can't flip sides every frame (no spinning in place)
	var want := _steer(node, to.normalized())
	var dir: Vector3 = (w.get("dir", want) as Vector3).lerp(want, clampf(delta * 5.0, 0.0, 1.0))
	dir = dir.normalized() if dir.length() > 0.01 else want
	w["dir"] = dir
	var heading := atan2(-dir.z, dir.x)
	node.rotation.y = lerp_angle(node.rotation.y, heading, clampf(delta * 4.0, 0.0, 1.0))
	# keep shuffling forward while turning, slower the more it has to turn
	var align := clampf(1.0 - absf(angle_difference(node.rotation.y, heading)) / 1.4, 0.15, 1.0)
	node.position += dir * minf(speed * align * delta, to.length())
	node.walking = move_toward(node.walking, 0.3 + 0.7 * align, delta * 3.0)
	# progress, not movement: if it hasn't got 0.25 m closer in 1.5 s it is blocked (by a pet on the spot, junk parked
	# in the way, a corner). Near the goal that counts as arriving; far from it, pick somewhere else.
	var d := to.length()
	if d < float(w.get("best_d", INF)) - 0.25:
		w["best_d"] = d
		w["stall"] = 0.0
	else:
		w["stall"] = float(w.get("stall", 0.0)) + delta
	if float(w["stall"]) > 1.5:
		w["stall"] = 0.0
		w["best_d"] = INF
		if d < pet_radius(node) + 1.2 or w["mode"] != "roam":
			w["target"] = node.position                 # close enough: stop here (peek / leave also end here)
			walk_stats["close_enough"] += 1
			w["give_ups"] = 0
		else:
			_pick_target(node, w)
			walk_stats["gave_up"] += 1
			w["give_ups"] = int(w.get("give_ups", 0)) + 1
			walk_stats["most_in_a_row"] = maxi(walk_stats["most_in_a_row"], w["give_ups"])


# ------------------------------------------------------------------ collisions
## Pets are round: this one's footprint radius in the garden.
func pet_radius(node: HedgePetNode) -> float:
	var r: Vector3 = node.profile.regions["BODY"]["radii"]
	return maxf(r.x, r.z) * node.scale.x * 0.85


## Everything solid on the lawn as circles [centre, radius]: trunks and walls, junk and things you built (not sticks
## or leaf piles - pets walk over those), and the other pets.
func colliders(skip: Variant = null, with_pets := true, with_things := true) -> Array:
	var out: Array = []
	for o in obstacles:
		out.append([o[0], float(o[1])])
	for t in (things if with_things else []):
		if t["kind"] in ["stick", "leaf_pile"] or (skip is Dictionary and t == skip):
			continue
		out.append([t["at"], float(t["radius"]) * 0.8])
	for n in pets:
		if with_pets and n.visible and n != skip and not perches.up_there(_wander[n]):
			out.append([Vector2(n.position.x, n.position.z), pet_radius(n)])
	return out


## colliders(node) for the pets' walk, every frame, as packed centres and radii: the trunks, walls and things are
## gathered once a frame (they were gathered again for each pet, twice), the other pets after them - the same circles
## in the same order, so the same pushes.
var _solid_frame := -1
var _solid_at := PackedVector2Array()
var _solid_r := PackedFloat64Array()


func _walk_colliders(node: HedgePetNode) -> Array:
	var f := Engine.get_process_frames()
	if f != _solid_frame:
		_solid_frame = f
		_solid_at.clear()
		_solid_r.clear()
		for c in colliders(null, false):
			_solid_at.append(c[0])
			_solid_r.append(float(c[1]))
	var at := _solid_at.duplicate()
	var r := _solid_r.duplicate()
	for n in pets:
		if n.visible and n != node and not perches.up_there(_wander[n]):
			at.append(Vector2(n.position.x, n.position.z))
			r.append(pet_radius(n))
	return [at, r]


## Walk around whatever is ahead instead of into it: each nearby solid in front pushes the heading sideways.
func _steer(node: HedgePetNode, want: Vector3) -> Vector3:
	var p := Vector2(node.position.x, node.position.z)
	var w2 := Vector2(want.x, want.z)
	var avoid := Vector2.ZERO
	var pr := pet_radius(node)
	var cs := _walk_colliders(node)
	var at: PackedVector2Array = cs[0]
	var rs: PackedFloat64Array = cs[1]
	for i in at.size():
		var off: Vector2 = p - at[i]
		var reach: float = rs[i] + pr + 1.4
		if absf(off.x) > reach or absf(off.y) > reach:
			continue                                   # (far off: the gap below is over 1.4 anyway)
		var gap := off.length() - rs[i] - pr
		if gap > 1.4 or off.length() < 0.001:
			continue
		if w2.dot(-off.normalized()) <= 0.0:
			continue                                   # behind or beside: no need
		var side := Vector2(-off.y, off.x).normalized()
		if side.dot(w2) < 0.0:
			side = -side                               # go round on the side we're already heading
		avoid += (off.normalized() * 0.5 + side) * (1.4 - gap) / 1.4
	var d := (w2 + avoid * 1.6).normalized()
	return Vector3(d.x, 0, d.y)


## Nothing overlaps: a pet inside a solid (walked in, or had a wheelbarrow-full of junk hauled into it) is pushed
## out, gently, every frame.
func _separate(node: HedgePetNode, delta: float) -> void:
	var p := Vector2(node.position.x, node.position.z)
	var pr := pet_radius(node)
	var push := Vector2.ZERO
	var cs := _walk_colliders(node)
	var at: PackedVector2Array = cs[0]
	var rs: PackedFloat64Array = cs[1]
	for i in at.size():
		var off: Vector2 = p - at[i]
		var reach: float = rs[i] + pr
		if absf(off.x) >= reach or absf(off.y) >= reach:
			continue                                   # (not touching: depth below would be <= 0)
		var depth: float = rs[i] + pr - off.length()
		if depth > 0.0:
			push += (off.normalized() if off.length() > 0.001 else Vector2.RIGHT) * depth
	if push != Vector2.ZERO:
		var step := push * clampf(delta * 12.0, 0.0, 1.0)
		node.position += Vector3(step.x, 0, step.y)


## A little thought above a pet's head (an emoji), rising and fading.
func emote(node: Node3D, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = node.position + Vector3(0, 1.7 * node.scale.y * 2.0, 0)
	add_child(l)
	l.scale = Vector3.ONE * 0.01
	Motion.appear(l, Vector3.ONE, Motion.FAST)
	Motion.float_away(l, 0.7, 1.6, 0.6)


## Go and curl up beside another pet that's napping (then nap too). False if nobody is.
func _curl_up(node: HedgePetNode, w: Dictionary) -> bool:
	var sleepers: Array = pets.filter(func(n) -> bool: return n != node and n.visible and n.sleeping and _wander[n]["mode"] == "roam")
	if sleepers.is_empty():
		return false
	var friend: HedgePetNode = sleepers.pick_random()
	var pr := pet_radius(node)
	var side := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	var spot := friend.position + side * (pet_radius(friend) + pr + 0.05)
	var p2 := Vector2(spot.x, spot.z)
	if _blocked(p2, pr) or not BOUNDS.has_point(p2):
		return false
	w["target"] = spot
	w["friend"] = friend
	w["best_d"] = INF
	w["wait"] = 0.1
	return true


## A random free spot it can walk straight to (falls back to staying put).
func _pick_target(node: HedgePetNode, w: Dictionary) -> void:
	var pr := pet_radius(node)
	var from := Vector2(node.position.x, node.position.z)
	for attempt in range(16):
		var p := Vector2(_rng.randf_range(BOUNDS.position.x, BOUNDS.end.x), _rng.randf_range(BOUNDS.position.y, BOUNDS.end.y))
		if not _blocked(p, pr + 0.4) and not _path_blocked(from, p, pr):
			w["target"] = Vector3(p.x, 0, p.y)
			w["best_d"] = INF
			return
	w["target"] = node.position


## The nearest point to `p` where a pet of radius `pr` fits: pushed out of every solid it lands in (a few passes,
## since getting out of one can put it in another). Pets don't count: they move.
## A gate spot moved to where this pet fits (and its progress tracking reset for the new goal).
func _fit(v: Vector3, node: HedgePetNode, w: Dictionary) -> Vector3:
	var p := free_spot(Vector2(v.x, v.z), pet_radius(node))
	w["best_d"] = INF
	w["stall"] = 0.0
	return Vector3(p.x, 0, p.y)


func free_spot(p: Vector2, pr: float) -> Vector2:
	for pass_i in range(4):
		var moved := false
		for c in colliders(null, false):
			var off: Vector2 = p - c[0]
			var need := float(c[1]) + pr + 0.15
			if off.length() < need:
				p = (c[0] as Vector2) + (off.normalized() if off.length() > 0.001 else Vector2.RIGHT) * need
				moved = true
		if not moved:
			break
	return p


## The pet nearest the pointer looks up at you, with a curious tilt; the rest go back to what they were doing.
func _notice_pointer() -> void:
	var near: HedgePetNode = null
	if _hover != Vector2.INF:
		var best := 150.0
		for node in pets:
			if not node.visible or node.sleeping:
				continue
			var d := camera.unproject_position(node.global_position + Vector3(0, 0.7, 0)).distance_to(_hover)
			if d < best:
				best = d
				near = node
	for node in pets:
		var was: bool = node.noticed
		node.noticed = node == near
		if node.noticed:
			node.look_point = camera.global_position
		elif was:
			node.look_point = Vector3.INF


## The yaw that points a pet (it faces +x) from `from` toward `to`.
func _heading(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.z - from.z), to.x - from.x)


func _path_blocked(a: Vector2, b: Vector2, pr := 0.7) -> bool:
	var steps := maxi(4, int(a.distance_to(b) / 0.5))
	for k in range(1, steps + 1):
		if _blocked(a.lerp(b, float(k) / steps), pr):
			return true
	return false
