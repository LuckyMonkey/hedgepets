extends "res://scripts/garden/game/game_visitors.gd"

## Game 4/7 - friends: pets that follow you, the bucket, pouring water to lead them, coming home from the woods.
##
## Pets that walk with you. Pouring water (hold and drag) lays a trail; pets nearby trot after it, and the ones that
## reach it follow you a while, into the woods too. A pet that reaches an empty bucket climbs in and can be carried.
## home_from_woods() puts everyone back when you return.
##
## Part of the garden game layer chain (the full order is at the top of scripts/garden/garden_game.gd). Code here was moved verbatim
## from the old single file; only its place changed.

const MAX_FOLLOWERS := 3
var following: Array = []           # pet names that follow you (saved)
var carried := ""                   # the pet in the bucket, or "" (saved)
## ✋ on a bucket with someone in it: you pick it up and carry it, pet and all.
func pick_up_bucket(t: Dictionary) -> void:
	var s: Dictionary = {}
	for sp in garden.hideouts.spots:
		if sp["thing"] == t:
			s = sp
	var node: HedgePetNode = s["occupant"]
	garden.hideouts._fill(s, node, false)
	s["occupant"] = null
	carried = node.profile.pet_name
	following.erase(carried)
	garden.carry(node)
	Telemetry.event("bucket_carry", {"pet": carried})
	_carried_bucket = t
	garden.things.erase(t)
	garden.hideouts.remove_spot(t)
	Motion.channel(t["node"], "lift").tween_property(t["node"], "position:y", 0.6, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_SINE)
	Motion.vanish(t["node"], false)
	toast("🪣 You pick up the bucket with %s in it. Over the footbridge, if you like - or ✋ tap the lawn to set it down." % carried)
	_refresh()


var _carried_bucket = null           # the bucket thing you're carrying (off the lawn while you are)


func put_down(at: Vector3) -> void:
	var node := node_by_name(carried)
	carried = ""
	if _carried_bucket != null:                           # the bucket goes down where you are, and out they hop
		var t: Dictionary = _carried_bucket
		_carried_bucket = null
		var bn: Node3D = t["node"]
		bn.position = at
		bn.visible = true
		bn.scale = Vector3.ONE
		Motion.appear(bn, Vector3.ONE)
		t["at"] = Vector2(at.x, at.z) + t.get("offset", Vector2.ZERO)
		t["moved"] = true
		garden.things.append(t)
		garden.hideouts.add_spot(t)
		at += (garden.camera.global_position - at).normalized() * Vector3(1, 0, 1) * 0.8
	if node != null:
		garden.uncarry(node, at)
		toast("%s hops out of the bucket." % node.profile.pet_name)
	_refresh()


# ------------------------------------------------------------------ pouring (💧): hedgepets love water
const TRAIL_LIFE := 25.0             # seconds a wet patch lasts
const LURE_REACH := 7.0              # how far off a hedgepet notices water being poured
const FOLLOW_SECONDS := 150.0        # how long one that reached the water walks with you
var _pour := Vector2.INF             # where you're pouring (screen), or INF
var _pour_time := 0.0
var _drip := 0.0
var trail: Array = []                # {at: Vector2, age, node}
var _following_for := {}             # pet name -> seconds left walking with you


func pour_begin(screen: Vector2) -> void:
	_pour = screen
	_pour_time = 0.0


func pour_move(screen: Vector2) -> void:
	_pour = screen


## Let go. False if it was really a tap (the garden treats it as one: water that plant, splash that pet).
func pour_end(dragged: bool) -> bool:
	_pour = Vector2.INF
	if dragged or _pour_time > 0.35:
		Telemetry.event("pour", {"s": snappedf(_pour_time, 0.1)})
	return dragged or _pour_time > 0.35


func _pouring(delta: float) -> void:
	for d in trail.duplicate():                           # the wet patches dry
		d["age"] += delta
		if d["age"] > TRAIL_LIFE:
			trail.erase(d)
			Motion.vanish(d["node"], true, Motion.SLOW)
	for name in _following_for.keys():
		_following_for[name] -= delta
		if _following_for[name] <= 0.0:
			_following_for.erase(name)
			following.erase(name)
	if _pour == Vector2.INF:
		return
	_pour_time += delta
	if _pour_time < 0.2:
		return
	var g: Vector3 = garden.ground_point(_pour)
	if g == Vector3.INF:
		return
	var p := Vector2(g.x, g.z)
	_drip -= delta
	var last: Vector2 = trail[-1]["at"] if not trail.is_empty() else Vector2.INF
	if _drip <= 0.0 or (last != Vector2.INF and last.distance_to(p) > 0.45):
		_drip = 0.35
		var wet := GardenProps.part(garden, GardenProps.blob(Vector3(0.32, 0.012, 0.28), "pebble"), GardenProps.mat("wetgrass", Color("26341e"), 0.3), Vector3(p.x, 0.012, p.y), Vector3(0, randf() * 360.0, 0), 0.0)
		wet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Motion.appear(wet, Vector3.ONE)
		trail.append({"at": p, "age": 0.0, "node": wet})
		if randf() < 0.4:
			_splash(Vector3(p.x, 0.0, p.y))
		for pl in plants:
			if (pl["at"] as Vector2).distance_to(p) < 0.8:
				pl["water"] = 1.0
	_lure(p)


## Every hedgepet near the water comes after it; the first to reach it walks with you; a trail that ends at an empty
## bucket: the first to reach it climbs in.
func _lure(p: Vector2) -> void:
	var bucket: Dictionary = {}
	for sp in garden.hideouts.spots:
		if sp["kind"] == "bucket" and sp["occupant"] == null and Vector2(garden.hideouts.opening(sp).x, garden.hideouts.opening(sp).z).distance_to(p) < 0.9:
			bucket = sp
	for node: HedgePetNode in garden.pets:
		var name := node.profile.pet_name
		if not node.visible or garden.pet_mode(node) != "roam" or not pet_state.get(name, "") in ["visiting", "resident"]:
			continue
		var here := Vector2(node.position.x, node.position.z)
		var d := here.distance_to(p)
		if d > LURE_REACH:
			continue
		var w: Dictionary = garden._wander[node]
		if node.sleeping:
			node.set_sleeping(false)
		if not bucket.is_empty() and d < 1.4:
			bucket["occupant"] = node
			garden.hideouts.enter(node, bucket)
			bucket["lured"] = true
			following.erase(name)
			_pour = Vector2.INF
			Telemetry.event("bucket_in", {"pet": name})
			toast("💧 %s followed the water right into the bucket! Pick it up with ✋ to carry it." % name)
			return
		var to := p + (here - p).normalized() * 0.7
		var t: Vector3 = garden._fit(Vector3(to.x, 0, to.y), node, w)
		w["target"] = t
		w["wait"] = 0.2
		if d < 1.3 and not following.has(name) and following.size() < MAX_FOLLOWERS:
			following.append(name)
			w["following"] = true
			node.tap()
			Telemetry.event("follow", {"pet": name})
			toast("💧 %s loves the water. It'll walk with you a while." % name)
		if following.has(name):
			_following_for[name] = FOLLOW_SECONDS


## Back from the woods with a pet you let out there: it arrives beside where you're looking.
func home_from_woods(node: HedgePetNode) -> void:
	var g: Vector3 = garden._target
	var spot: Vector2 = garden.free_spot(Vector2(g.x + randf_range(-1.5, 1.5), g.z + randf_range(-1.5, 1.5)), garden.pet_radius(node))
	garden.uncarry(node, Vector3(spot.x, 0, spot.y), false)
	garden._wander[node]["following"] = true


## Loading a save: the bucket's occupant goes back in it; followers remember.
func _restore_friends() -> void:
	if carried != "":
		var node := node_by_name(carried)
		if node == null:
			carried = ""
		else:
			garden.carry(node)
	for name: String in following.duplicate():
		var node := node_by_name(name)
		if node == null:
			following.erase(name)
		else:
			garden._wander[node]["following"] = true
			_following_for[name] = FOLLOW_SECONDS


## Followers keep near whatever you're looking at: when you look away, they come over (walking, never blinking).
func _lead_followers() -> void:
	var g: Vector3 = garden._target
	var i := 0
	for name: String in following:
		var node := node_by_name(name)
		if node == null or not node.visible or garden.pet_mode(node) != "roam":
			continue
		var w: Dictionary = garden._wander[node]
		w["following"] = true
		var near := g + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.8
		i += 1
		if Vector2(node.position.x, node.position.z).distance_to(Vector2(near.x, near.z)) > 2.4:
			if node.sleeping:
				node.set_sleeping(false)
			var t: Vector3 = garden._fit(near, node, w)
			if garden.BOUNDS.has_point(Vector2(t.x, t.z)):
				w["target"] = t
				w["wait"] = 0.4
