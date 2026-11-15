extends "res://scripts/garden/woods/woods_landmarks.gd"

## Woods 5/6 - finds and visitors: things to pick up, the basket, wild hedgepets, trinkets they leave.
##
## What the player can take. Finds (FINDS, SPOTS) are litter, junk and what the woods drop; litter stays picked
## up, the rest regrows after REGROW seconds of real time. Saved in game.woods_finds. Wild hedgepets wander near
## the clearings and keep SHY metres away; one may leave a trinket where you stood. They are seeded per visit
## (_wrng), separate from the build RNG, so their wandering never changes the scenery.
##
## Part of the woods layer chain (see scripts/garden/woods.gd for the full order). Code here was moved verbatim from
## the old single file; only its place changed.

## Things to find, and what each is. what: litter (a coin, gone for good), junk (a few tugs, more coins, gone for good),
## forage (into the basket for the nursery; grows back), seeds (wild seeds to sow; grow back).
const FINDS := {
	"can": {"what": "litter", "coins": 1, "say": "A rusty can. Into the sack with it."},
	"bottle": {"what": "litter", "coins": 1, "say": "An old bottle, half full of leaves."},
	"wrapper": {"what": "litter", "coins": 1, "say": "A sweet wrapper. Somebody's been through here."},
	"tire": {"what": "junk", "coins": 6, "tugs": 3, "say": "Somebody rolled a tire into the creek. Not any more."},
	"tarp": {"what": "junk", "coins": 4, "tugs": 3, "say": "An old blue tarp, bundled up and hauled off."},
	"drum": {"what": "junk", "coins": 6, "tugs": 3, "say": "A rusted oil drum. That's been here a while. Not now."},
	"line": {"what": "junk", "coins": 3, "tugs": 2, "say": "A snarl of fishing line, cut out of the reeds. The birds will thank you."},
	"cone": {"what": "forage", "say": "A good pine cone. Into the basket."},
	"acorn": {"what": "forage", "say": "Acorns, a handful. Into the basket."},
	"mushroom": {"what": "forage", "say": "A mushroom, picked carefully. Into the basket."},
	"feather": {"what": "forage", "say": "A blue jay's feather. Into the basket."},
	"apple": {"what": "forage", "say": "An apple off the old tree. Small and sour and perfect. Into the basket."},
	"seeds": {"what": "seeds"},
}
const SPOTS := {
	"trailhead": ["can", "wrapper", "tarp", "cone", "seeds"],
	"fork": ["bottle", "can", "mushroom", "acorn", "seeds"],
	"hollow": ["wrapper", "bottle", "mushroom", "feather", "seeds"],
	"ridge": ["can", "drum", "cone", "feather", "seeds"],
	"creek": ["bottle", "tire", "line", "acorn", "seeds"],
	"oak": ["wrapper", "acorn", "mushroom", "feather", "seeds"],
	"pond": ["bottle", "can", "feather", "cone", "seeds"],
	"cellar": ["can", "bottle", "apple", "acorn", "seeds"],
	"pines": ["cone", "cone", "mushroom", "feather", "seeds"],
}
const WILD_SEEDS := {"trailhead": "clover", "fork": "moss", "hollow": "fern", "ridge": "pine", "creek": "willow", "oak": "oak",
	"pond": "willow", "cellar": "rose", "pines": "pine"}
const REGROW := 20.0 * 60.0                      # seconds of real time before what the woods drop is back
const LITTER_BACK := 45.0 * 60.0                 # hikers pass through: litter and junk turn up again, slowly
const TRINKET_EVERY := 120.0                     # a wild hedgepet leaves a little something by where you stand

var _yaw := 0.0
var _walking: Dictionary = {}         # {pts, s, len, to}
var _finds: Array = []                # {id, kind, at (node id), node: Node3D, tugs}
var _basket_label: Label
var basket: Dictionary:
	get:
		return garden.game.woods_finds["basket"]


# ------------------------------------------------------------------ finds
func _place_finds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909                                        # the same spots every time
	for id in SPOTS:
		var c := node_pos(id)
		var kinds: Array = SPOTS[id]
		for i in kinds.size():
			var kind: String = kinds[i]
			var at := _clear_spot(c, rng.randf_range(2.4, 5.2), rng)
			if kind in ["tire", "line"] and id == "creek":     # in the water / the reeds
				var q := Vector2(c.x, c.z)
				var b := _creek_point((q - CREEK_AT).dot(CREEK_DIR) + (2.5 if kind == "tire" else -3.0)) + CREEK_DIR.orthogonal() * (0.4 if kind == "tire" else 1.9) * signf(_creek_lat(q))
				at = Vector3(b.x, height(b.x, b.y) + (0.55 if kind == "tire" else 0.6), b.y)
			var holder := GardenProps.root(self, "Find_" + kind, at, rng.randf() * 360.0)
			_placement("%s:find_%s_%d" % [id, kind, i], holder, 0.6)
			_find_look(holder, kind, rng)
			_finds.append({"id": "%s:%d" % [id, i], "kind": kind, "at": id, "node": holder, "tugs": int(FINDS[kind].get("tugs", 1))})


func _find_look(h: Node3D, kind: String, rng: RandomNumberGenerator) -> void:
	match kind:
		"can":
			GardenProps.part(h, GardenProps.cyl(0.04, 0.04, 0.12, 8), GardenProps.rust_mat(), Vector3(0, 0.04, 0), Vector3(0, 0, 90), 0.004)
		"bottle":
			GardenProps.part(h, GardenProps.cyl(0.04, 0.045, 0.24, 8), GardenProps.mat("bottleglass", Color("4a7a52"), 0.2), Vector3(0, 0.045, 0), Vector3(0, 0, 90), 0.004)
		"wrapper":
			GardenProps.part(h, GardenProps.blob(Vector3(0.08, 0.015, 0.05), "pebble"), GardenProps.mat("wrapper", Color("d44a3a"), 0.4), Vector3(0, 0.02, 0), Vector3.ZERO, 0.003)
		"tire":
			GardenProps.old_tire(h, Vector3(0, -0.2, 0), 0.0).rotation_degrees.x = 25.0
		"tarp":
			GardenProps.part(h, GardenProps.blob(Vector3(0.8, 0.22, 0.6), "pebble"), GardenProps.mat("tarp", Color("536878"), 0.95), Vector3(0, 0.12, 0), Vector3.ZERO, 0.01)
		"drum":
			GardenProps.part(h, GardenProps.cyl(0.3, 0.3, 0.85, 14), GardenProps.rust_mat(), Vector3(0, 0.28, 0), Vector3(0, 0, 90), 0.01)
		"line":
			GardenProps.part(h, GardenProps.blob(Vector3(0.28, 0.16, 0.24), {"exponent": 1.6}), GardenProps.mat("fishline", Color("a8b2b4"), 0.3), Vector3(0, 0.1, 0), Vector3.ZERO, 0.0)
		"cone":
			GardenProps.part(h, GardenProps.blob(Vector3(0.05, 0.075, 0.05), {"exponent": 2.0, "taper": 0.4}), GardenProps.mat("pinecone", Color("7a5232")), Vector3(0, 0.04, 0), Vector3(80, 0, 0), 0.004)
		"acorn":
			for k in range(3):
				var o := Vector3(rng.randf_range(-0.06, 0.06), 0.02, rng.randf_range(-0.06, 0.06))
				GardenProps.part(h, GardenProps.blob(Vector3(0.022, 0.03, 0.022), "pebble"), GardenProps.mat("acorn", Color("a87a3a")), o, Vector3(80, k * 50, 0), 0.0)
		"apple":
			GardenProps.part(h, GardenProps.blob(Vector3(0.05, 0.048, 0.05), "pebble"), GardenProps.mat("redapple", Color("b8402e")), Vector3(0, 0.045, 0), Vector3.ZERO, 0.004)
		"mushroom":
			GardenProps.part(h, GardenProps.cyl(0.02, 0.028, 0.1, 8), GardenProps.mat("mushstem", Color("e6dcc4")), Vector3(0, 0.05, 0), Vector3.ZERO, 0.003)
			GardenProps.part(h, GardenProps.blob(Vector3(0.07, 0.04, 0.07), "dome"), GardenProps.mat("mushcap", Color("a8583a")), Vector3(0, 0.1, 0), Vector3.ZERO, 0.004)
		"feather":
			GardenProps.part(h, GardenProps.blob(Vector3(0.025, 0.006, 0.11), {"exponent": 2.0}), GardenProps.mat("jayfeather", Color("4a7ac0"), 0.5), Vector3(0, 0.01, 0), Vector3.ZERO, 0.0)
		"seeds":
			for k in range(3):
				var o := Vector3((k - 1) * 0.05, 0, rng.randf_range(-0.03, 0.03))
				GardenProps.part(h, GardenProps.cyl(0.004, 0.006, 0.34, 4), GardenProps.mat("seedstem", Color("8a8a5a")), o + Vector3(0, 0.17, 0), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)), 0.0)
				GardenProps.part(h, GardenProps.blob(Vector3(0.035, 0.05, 0.035), "pebble"), GardenProps.mat("seedhead", Color("cfc29a")), o + Vector3(0, 0.36, 0), Vector3.ZERO, 0.0)
	if FINDS[kind]["what"] != "junk":                    # a glint, so small things can be found (a can is 12 cm; the woods are dark)
		var g := Label3D.new()
		g.text = "✨"
		g.font_size = 64
		g.fixed_size = true                               # the same size on screen near or far
		g.pixel_size = 0.08 / 64.0
		g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		g.position = Vector3(0, 0.3, 0)
		g.name = "Glint"
		h.add_child(g)


## What has grown back since you were last here, and what's still gone.
func _refresh_finds() -> void:
	var taken: Dictionary = garden.game.woods_finds["taken"]
	var now := Time.get_unix_time_from_system()
	for f: Dictionary in _finds:
		var gone := taken.has(f["id"])
		var back := REGROW if FINDS[f["kind"]]["what"] in ["forage", "seeds"] else LITTER_BACK
		if gone and now - float(taken[f["id"]]) > back:
			taken.erase(f["id"])
			gone = false
		var node: Node3D = f["node"]
		if not gone and not node.visible:
			node.scale = Vector3.ONE
			node.visible = true
		elif gone:
			node.visible = false


func show_basket() -> void:
	var n := 0
	for k in basket:
		n += int(basket[k])
	if n > 0:
		_basket_label.text = "🧺 %d" % n
	Motion.fade(_basket_label, 1.0 if n > 0 else 0.0)


func _find_at(screen: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for f: Dictionary in _finds:
		var node: Node3D = f["node"]
		if not node.visible or f["at"] != _at:
			continue
		var p := node.global_position + Vector3(0, 0.1, 0)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(screen)
		var reach := 150.0 if FINDS[f["kind"]]["what"] == "junk" else 100.0
		if d < reach and d < best_d:
			best_d = d
			best = f
	return best


func take(f: Dictionary) -> void:
	var game: Node = garden.game
	var info: Dictionary = FINDS[f["kind"]]
	var node: Node3D = f["node"]
	if info["what"] == "junk" and f["tugs"] > 1:          # it takes a few goes
		f["tugs"] -= 1
		var t := Motion.channel(node, "tug")
		t.tween_property(node, "rotation_degrees:z", 7.0, Motion._d(Motion.FAST * 0.6))
		t.tween_property(node, "rotation_degrees:z", -5.0, Motion._d(Motion.FAST * 0.6))
		t.tween_property(node, "rotation_degrees:z", 0.0, Motion._d(Motion.FAST))
		game.toast(["Stuck fast. Pull again.", "It's coming. Once more."][mini(1, 3 - int(f["tugs"]))] if f["tugs"] > 1 else "Nearly...")
		return
	game.woods_finds["taken"][f["id"]] = Time.get_unix_time_from_system()
	Telemetry.event("find", {"kind": f["kind"], "at": f["at"]})
	Motion.vanish(node, false)
	match info["what"]:
		"litter", "junk":
			game.coins += int(info["coins"])
			game.toast("%s 🪙 +%d" % [info["say"], info["coins"]])
		"forage":
			basket[f["kind"]] = int(basket.get(f["kind"], 0)) + 1
			game.collection[f["kind"]] = int(game.collection.get(f["kind"], 0)) + 1
			game.toast(info["say"] + " The nursery might want it.")
			show_basket()
		"seeds":
			var species: String = WILD_SEEDS.get(f["at"], "clover")
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			for k in range(2):
				game.keep_seeds.append({"species": species, "genes": _wild_genes(rng)})
			game.toast("🌱 Wild %s, gone to seed. Two to sow - they're in 🌱, under %s." % [SpeciesBuilder.PLANT_NAMES.get(species, species), species])
	game._refresh()


## Wild seeds aren't the shop's: now and then one carries something its parents didn't show.
static func _wild_genes(rng: RandomNumberGenerator) -> String:
	var out := ""
	for pair: Array in [["C", "c"], ["T", "t"]]:
		var a: String = pair[1] if rng.randf() < 0.3 else pair[0]
		var b: String = pair[1] if rng.randf() < 0.3 else pair[0]
		out += a + b if a <= b else b + a
	return out


# ------------------------------------------------------------------ wild hedgepets
## Hedgepets that don't live in your garden, out in the woods: a few at a time, off the trail ahead of you, nosing
## about and watching you. Come within a few metres and they scurry off; fall far behind and they slip away, and
## others turn up further on. You can't catch them - tap one and you learn who it was.
const WILD_COUNT := 6
const SHY := 8.0                       # closer than this, they're off
var _wild: Array = []                  # {node, pos (local), goal, speed, wait, gone}
var _wrng := RandomNumberGenerator.new()


func _wild_begin() -> void:
	_wild.clear()
	var game: Node = garden.game
	var pool: Array = garden.roster.filter(func(p) -> bool: return game.pet_state.get(p.pet_name, "") == "away" and p.pet_name != game.carried and not game.following.has(p.pet_name))
	pool.shuffle()
	for p: CharacterArtProfile in pool.slice(0, WILD_COUNT):
		var node: HedgePetNode = garden.node_for(p)
		if is_borrowed(node):
			continue
		borrow(node)
		node.visible = false
		node.set_sleeping(false)
		_wild.append({"node": node, "pos": Vector3.INF, "goal": Vector3.INF, "speed": 0.0, "wait": _wrng.randf_range(0.0, 2.0), "gone": true})


## Somewhere ahead of you, off the trail, on dry ground.
func _wild_spot() -> Vector3:
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var right := fwd.cross(Vector3.UP)
	for k in range(20):
		var ahead := _wrng.randf_range(10.0, 16.0)          # ahead and on screen: you see them, then see them go
		var q := cam.position + fwd * ahead + right * _wrng.randf_range(-0.35, 0.35) * ahead
		var p2 := Vector2(q.x, q.z)
		if p2.x < -56 or p2.x > 58 or p2.y < -106 or p2.y > 14 or _near_trail(p2, 1.4) or water_at(p2.x, p2.y) > -INF:
			continue
		return Vector3(q.x, height(q.x, q.z), q.z)
	return Vector3.INF


func _wild_tick(delta: float) -> void:
	for w: Dictionary in _wild:
		var node: HedgePetNode = w["node"]
		if node.building:
			continue                                      # whole or not at all; materialisation finishes in shared slices
		if w["gone"]:
			w["wait"] -= delta
			if w["wait"] <= 0.0:
				var at := _wild_spot()
				if at != Vector3.INF:
					w["gone"] = false
					w["pos"] = at
					w["goal"] = at
					node.position = to_global(at)
					node.rotation.y = _wrng.randf() * TAU
					Motion.appear(node, Vector3.ONE * garden.PET_SCALE)
			continue
		var pos: Vector3 = w["pos"]
		var off := Vector3(pos.x - cam.position.x, 0, pos.z - cam.position.z)
		var d := off.length()
		if d > 30.0:                                     # left behind: slip away, turn up somewhere ahead later
			w["gone"] = true
			w["wait"] = _wrng.randf_range(2.0, 6.0)
			Motion.vanish(node, false)
			continue
		if d < SHY and w["speed"] < 3.0:                 # too close: off it goes, away from you
			var away := off.normalized().rotated(Vector3.UP, _wrng.randf_range(-0.7, 0.7))
			var g := pos + away * _wrng.randf_range(6.0, 10.0)
			if _near_trail(Vector2(g.x, g.z), 1.2):          # off through the trees, not up the path
				g = pos + away.rotated(Vector3.UP, PI * 0.5 * signf(_wrng.randf() - 0.5)) * 7.0
			w["goal"] = Vector3(g.x, height(g.x, g.z), g.z)
			w["speed"] = 3.8
		var to: Vector3 = w["goal"] - pos
		to.y = 0.0
		if to.length() > 0.1:
			var step := minf(to.length(), float(w["speed"]) * delta)
			pos += to.normalized() * step
			pos.y = height(pos.x, pos.z)
			node.rotation.y = lerp_angle(node.rotation.y, atan2(to.x, to.z), clampf(delta * 10.0, 0.0, 1.0))
			node.walking = 1.0
			node.look_point = Vector3.INF
		else:
			node.walking = move_toward(node.walking, 0.0, delta * 3.0)
			w["speed"] = 0.0
			w["wait"] -= delta
			node.look_point = cam.global_position         # a wary look at you
			if w["wait"] <= 0.0:                           # nose about a little
				w["wait"] = _wrng.randf_range(1.5, 4.0)
				var g := pos + Vector3(_wrng.randf_range(-1.5, 1.5), 0, _wrng.randf_range(-1.5, 1.5))
				if not _near_trail(Vector2(g.x, g.z), 1.2) and water_at(g.x, g.z) == -INF:
					w["goal"] = Vector3(g.x, height(g.x, g.z), g.z)
					w["speed"] = 0.9
		w["pos"] = pos
		node.position = to_global(pos)


func _wild_tapped(at: Vector2) -> bool:
	for w: Dictionary in _wild:
		var node: HedgePetNode = w["node"]
		if w["gone"] or not node.visible or cam.is_position_behind(node.global_position):
			continue
		if cam.unproject_position(node.global_position + Vector3(0, 0.3, 0)).distance_to(at) < 110.0:
			Telemetry.event("wild_tap", {"pet": node.profile.pet_name})
			garden.game.toast("A wild %s, keeping its distance. It doesn't live in your garden - yet." % SpeciesBuilder.variant_name(node.profile))
			return true
	return false


# ------------------------------------------------------------------ trinkets
## Everyone gathers round where you're standing: followers in a loose arc ahead (so you see them), the bucket beside.
## What the wild hedgepets leave about (like the garden's gifts): an acorn, a feather, a little shell... by where you
## stand, one every couple of minutes, up to two per place. Tap one for its coins. Nothing goes away if you don't.
var _trinkets: Array = []               # {node: Label3D, at: place id, value}
var _trinket_clock := TRINKET_EVERY * 0.5


func _tend_trinkets(delta: float) -> void:
	_trinket_clock -= delta
	if _trinket_clock > 0.0 or not _walking.is_empty():
		return
	_trinket_clock = TRINKET_EVERY
	if _trinkets.filter(func(t) -> bool: return t["at"] == _at).size() >= 2:
		return
	var g: Array = garden.game.GIFTS.pick_random()
	var c := node_pos(_at)
	var p := _off_trail(c + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(2.2, 3.6), 0.6)
	var l: Label3D = garden.game.pickup_label(g[0], 0.11)
	l.position = p + Vector3(0, 0.3, 0)
	add_child(l)
	Motion.appear(l, Vector3.ONE, Motion.FAST)
	_trinkets.append({"node": l, "at": _at, "value": int(g[1]), "base": p.y + 0.3, "phase": randf() * TAU})


func _take_trinket(screen: Vector2) -> bool:
	for t in _trinkets:
		var l: Label3D = t["node"]
		if t["at"] != _at or cam.is_position_behind(l.global_position):
			continue
		if cam.unproject_position(l.global_position).distance_to(screen) < 110.0:
			_trinkets.erase(t)
			garden.game.coins += int(t["value"])
			garden.game.toast("%s 🪙 +%d" % [l.text, t["value"]])
			garden.game._refresh()
			Motion.float_away(l, 1.2, 0.6, 0.1)
			return true
	return false
