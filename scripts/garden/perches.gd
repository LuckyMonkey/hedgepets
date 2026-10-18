extends Node

## Perches: the small birds don't only hop about in the grass. Now and then one picks something in the garden - the
## trash barrel's lid, the ironing board, the wheelbarrow, the grill, the woodpile - hops over to it and, with a quick
## flutter (a shiver through its leaves, no wings spread), hops up and sits on top a while, looking about. Then it
## hops down beside it and carries on. One bird per perch; if you haul the thing away, the bird hops off.
## The perch is the top of the thing itself (its highest surface, read from its mesh), so new props just work.

const MIN_H := 0.3              # anything lower isn't worth the hop
const MAX_H := 2.2              # nothing higher than a quick flutter reaches
const REACH := 9.0              # how far away a perch can tempt a bird
const CHANCE := 0.35            # when a bird is deciding where to go next, how often it picks a perch
const SKIP := ["stick", "leaf_pile", "branch", "sprinkler", "burrow", "barrel_fill"]

var garden: Node3D
var _taken := {}                # thing id -> the bird on it
var _birds := {}                # species -> true: the small birds (plan "bird", size <= 0.75 in species.json)
var _rng := RandomNumberGenerator.new()   # its own, so birds deciding never changes what the other pets do


func setup(g: Node3D) -> void:
	garden = g
	_rng.seed = 2210
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://pets/species.json"))
	for s in (d if d is Array else []):
		if s.get("plan", "") == "bird" and float(s.get("size", 1.0)) <= 0.75:
			_birds[s["species"]] = true


func can_perch(node: HedgePetNode) -> bool:
	return _birds.has(node.profile.species)


## The top of a thing, in the garden: the middle of its highest surface (its vertices within 3 cm of the top).
func top_of(t: Dictionary) -> Vector3:
	var root: Node3D = t["node"]
	if not is_instance_valid(root) or not root.is_visible_in_tree():
		return Vector3.INF
	var pts := PackedVector3Array()
	var best := -INF
	for n in [root] + root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf := mi.global_transform
		for s in range(mi.mesh.get_surface_count()):
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := xf * v
				if p.y > best - 0.03:
					pts.append(p)
					best = maxf(best, p.y)
	var sum := Vector3.ZERO
	var n := 0
	for p in pts:
		if p.y > best - 0.03:
			sum += p
			n += 1
	return sum / n if n > 0 else Vector3.INF


## Deciding where to go next: maybe a perch. Reserves it and sends the bird walking to just beside it.
func go_perch(node: HedgePetNode, w: Dictionary) -> bool:
	if not can_perch(node) or _rng.randf() > CHANCE:
		return false
	var options: Array = []
	for t in garden.things:
		if t["kind"] in SKIP or _taken.has(t["id"]) or t == _held():
			continue
		var at: Vector2 = t["at"]
		if at.distance_to(Vector2(node.position.x, node.position.z)) > REACH:
			continue
		var top := top_of(t)
		if top == Vector3.INF or top.y < MIN_H or top.y > MAX_H:
			continue
		options.append([t, top])
	if options.is_empty():
		return false
	var pick: Array = options[_rng.randi() % options.size()]
	var t: Dictionary = pick[0]
	var top: Vector3 = pick[1]
	# stand on the ground just outside it, on the side the bird is coming from
	var away := Vector2(node.position.x - top.x, node.position.z - top.z)
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var spot: Vector2 = garden.free_spot(t["at"] + away * (float(t["radius"]) * 0.8 + garden.pet_radius(node) + 0.15), garden.pet_radius(node))
	_taken[t["id"]] = node
	w["mode"] = "to_perch"
	w["perch"] = t
	w["target"] = Vector3(spot.x, 0, spot.y)
	w["best_d"] = INF
	return true


## Beside it: a quick flutter and a hop up onto the top.
func hop_up(node: HedgePetNode, w: Dictionary) -> void:
	var t: Dictionary = w["perch"]
	var top := top_of(t)
	if top == Vector3.INF or Vector2(top.x - node.position.x, top.z - node.position.z).length() > float(t["radius"]) + 1.5 or _held() == t:
		release(node, w)                                 # gone, moved, or too far to reach from here
		return
	w["mode"] = "perching"
	w["perch_at"] = (t["node"] as Node3D).global_position
	node.walking = 0.0
	node.rotation.y = garden._heading(node.position, top)
	_hop(node, top, func() -> void:
		w["mode"] = "perched"
		w["wait"] = _rng.randf_range(6.0, 16.0)
		w["face"] = _rng.randf_range(-0.9, 0.9))


func _hop(node: HedgePetNode, to: Vector3, done: Callable) -> void:
	var from := node.position
	var arc := 0.25 + absf(to.y - from.y) * 0.35
	node._shake = 0.45                                   # the flutter: a quick shiver through its leaves
	var t := Motion.channel(node, "perch")
	t.tween_method(func(k: float) -> void:
		node.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * arc, 0), 0.0, 1.0, Motion._d(0.45)).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		node.position = to
		done.call())


## Every frame while it's up there: look about (toward you, mostly); hop down when it's had enough, when you take
## it along, or when its perch moves.
func tend(node: HedgePetNode, w: Dictionary, delta: float) -> void:
	if w["mode"] != "perched":
		return                                           # mid-hop
	var t: Dictionary = w["perch"]
	var moved: bool = not is_instance_valid(t["node"]) or (t["node"] as Node3D).global_position.distance_to(w["perch_at"]) > 0.05 \
		or _held() == t
	if moved:
		_land(node, w, true)
		return
	node.rotation.y = lerp_angle(node.rotation.y, garden._heading(node.position, garden.camera.position) + float(w.get("face", 0.0)), clampf(delta * 2.0, 0.0, 1.0))
	w["wait"] = float(w["wait"]) - delta
	if float(w["wait"]) <= 0.0 or w.get("following", false):
		_land(node, w)


## Down again, beside the perch (startled: straight down, no pause).
func _land(node: HedgePetNode, w: Dictionary, startled := false) -> void:
	var t: Dictionary = w["perch"]
	var c := Vector2(node.position.x, node.position.z)
	var out := Vector2.from_angle(_rng.randf() * TAU)
	var spot: Vector2 = garden.free_spot(c + out * (float(t["radius"]) * 0.8 + garden.pet_radius(node) + 0.2), garden.pet_radius(node))
	w["mode"] = "perching"
	node.rotation.y = garden._heading(node.position, Vector3(spot.x, 0, spot.y))
	if startled:
		node.tap()
	_hop(node, Vector3(spot.x, 0, spot.y), func() -> void:
		release(node, w)
		w["wait"] = _rng.randf_range(1.0, 3.0))


## Off the perch for good (landed, or something else took over: leaving, the bucket): back to roaming on the ground.
func release(node: HedgePetNode, w: Dictionary) -> void:
	var t = w.get("perch")
	if t != null and _taken.get(t["id"]) == node:
		_taken.erase(t["id"])
	w["perch"] = null
	if w["mode"] in ["to_perch", "perching", "perched"]:
		w["mode"] = "roam"
		w["target"] = node.position * Vector3(1, 0, 1)
		w["best_d"] = INF
	if node.position.y != 0.0 and w["mode"] != "perched":
		Motion.channel(node, "perch").kill()
		node.position.y = 0.0


## The thing under your ✋ right now (a bird won't land on it, and hops off it).
func _held() -> Variant:
	return garden.game.grab.held if garden.game != null else null


func up_there(w: Dictionary) -> bool:
	return w["mode"] in ["perching", "perched"]
