extends "res://scripts/garden/game/game_state.gd"

## Game 2/7 - soil and plants: digging, dirt, seedbeds, planting, growing, watering, self-sowing, placing builds.
##
## The soil cycle: the shovel digs a seedbed (a hole next to a hole makes a row), the dirt goes on a pile you can scoop
## back. Seeds go in a bed; a plant goes mound -> sprout -> bush -> flowering while it is watered, and water dries out
## (DRY_GROWTH). Plants self-sow nearby. Builds (the basket tool) are placed here too: things on the same lawn.
##
## Part of the garden game layer chain (the full order is at the top of scripts/garden/garden_game.gd). Code here was moved verbatim
## from the old single file; only its place changed.

## Things to put in the garden (🧺): bought with coins, placed with a tap, cleared with the shovel for half back.
## With 🧺 out, drag something you built to move it, tap it to turn it (arrange_*).
const BUILDS := {
	"feeder": {"icon": "🐦", "price": 8, "name": "bird feeder", "radius": 0.5},
	"bath": {"icon": "⛲", "price": 10, "name": "bird bath", "radius": 0.6},
	"log_pile": {"icon": "🪵", "price": 6, "name": "log pile", "radius": 0.8},
	"nest_box": {"icon": "🏠", "price": 7, "name": "birdhouse", "radius": 0.4},
	"pumpkin": {"icon": "🎃", "price": 3, "name": "pumpkin", "radius": 0.5},
	"apples": {"icon": "🍎", "price": 5, "name": "crate of apples", "radius": 0.7},
	"bucket": {"icon": "🪣", "price": 4, "name": "steel bucket", "radius": 0.35},       # hideouts: a pet may hop in
	"planter": {"icon": "🏺", "price": 4, "name": "clay pot", "radius": 0.48},
	"chair": {"icon": "🪑", "price": 5, "name": "lawn chair", "radius": 0.5},
	"hay": {"icon": "🌾", "price": 4, "name": "hay bale", "radius": 0.6},
	"scarecrow": {"icon": "🧑‍🌾", "price": 9, "name": "scarecrow", "radius": 0.45},
	"lantern": {"icon": "🏮", "price": 6, "name": "garden lantern", "radius": 0.3},
	"stones": {"icon": "🪨", "price": 3, "name": "stepping stones", "radius": 0.3},
	"fire_pit": {"icon": "🔥", "price": 6, "name": "fire pit", "radius": 0.65},     # tap it with ✋ to light it
}
const STAGE_SECONDS := 18.0        # watered growth time per stage
const WATER_SECONDS := 40.0        # how long one watering lasts
var coins := 15
var seedbeds: Array = []           # {at: Vector2, node, plant (or null)}
var placed: Array = []              # {kind, x, z, yaw}: what you built (saved)
var nursery := {"visits": 0, "said": [], "once": [], "gave": false, "crossed": false, "returned": false}   # nursery.gd (saved)
var keep_seeds: Array = []          # seeds the nursery gave you, {species, genes}: sown before bought ones of that kind
const SOW_REACH := 5.0              # from a flowering plant this near
## Digging. A hole beside another joins it into a row; the dirt goes on a pile beside it (dirt_piles, saved), which
## the 🪏 can scoop from to fill a hole again, and the wheelbarrow (garden_grab.gd) can carry about.
const ROW_STEP := 0.8               # a hole dug this near another joins its row, this far along
const DIRT_MAX := 4                 # loads on one pile
var dirt_piles: Array = []          # {at: Vector2, loads, node}
var grab: Node                       # scripts/garden/garden_grab.gd: yank, haul, sell, fix
## Now and then a resident grows a single flower somewhere unexpected (at most three each). Just because.
func surprise_flower(quiet := false) -> void:
	var options: Array = garden.pets.filter(func(n) -> bool: return n.visible and pet_state.get(n.profile.pet_name, "") == "resident" and n.extra_flowers.size() < 3)
	if options.is_empty():
		return
	var node: HedgePetNode = options.pick_random()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	node.sprout_flower(rng)
	pet_flowers[node.profile.pet_name] = node.extra_flowers.map(func(f) -> Array: return [f[0], f[1].x, f[1].y, f[1].z])
	if not quiet:
		toast("🌼 %s has grown a little flower." % node.profile.pet_name)


## Everything planted grows: slowly on its own (rain, dew), three times as fast while watered. Wet soil looks dark.
const DRY_GROWTH := 0.35


func _grow(delta: float) -> void:
	for pl in plants:
		var wet: bool = pl["water"] > 0.0
		if wet:
			pl["water"] = maxf(0.0, pl["water"] - delta / WATER_SECONDS)
		_wet_look(pl["bed"], pl["water"] > 0.0)
		if pl["stage"] < 3:
			pl["progress"] += delta / STAGE_SECONDS * (1.0 if wet else DRY_GROWTH)
			if pl["progress"] >= 1.0:
				pl["progress"] = 0.0
				pl["stage"] += 1
				_build_plant(pl)
				Telemetry.event("grew", {"species": pl["species"], "stage": pl["stage"]})
				var name: String = SpeciesBuilder.PLANT_NAMES.get(pl["species"], pl["species"])
				toast(["🌱 Your %s is up.", "🌿 Your %s is a proper little bush now.", "🌸 Your %s is flowering."][int(pl["stage"]) - 1] % name)


## A bed's soil darkens when watered and pales as it dries (eased, never a jump).
func _wet_look(bed: Dictionary, wet: bool) -> void:
	if bed.get("wet", false) == wet or bed["node"] == null:
		return
	bed["wet"] = wet
	var m: StandardMaterial3D = bed["mat"]
	Motion.channel(bed["node"], "wet").tween_property(m, "albedo_color", Color("3e2c1e") if wet else Color("6a5038"), Motion._d(Motion.SLOW * 2.0))


func _place(kind: String, p2: Vector2, yaw: float, animate := true) -> void:
	var at := Vector3(p2.x, 0, p2.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p2.x * 1000 + p2.y * 7)
	var node: Node3D
	match kind:
		"feeder": node = GardenProps.bird_feeder(garden, at, yaw)
		"bath": node = GardenProps.bird_bath(garden, at, yaw)
		"log_pile": node = GardenProps.log_pile(garden, at, yaw)
		"nest_box": node = GardenProps.nest_box(garden, at, yaw)
		"pumpkin": node = GardenProps.pumpkin(garden, at, rng.randf_range(0.55, 0.8), rng)
		"apples": node = GardenProps.apple_crate(garden, at, yaw, rng)
		"bucket": node = GardenProps.paint_bucket(garden, at, yaw)
		"planter": node = GardenProps.pot_upright(garden, at)
		"chair": node = GardenProps.chair_upright(garden, at, yaw)
		"hay": node = GardenProps.hay_bale(garden, at, yaw, rng)
		"scarecrow": node = GardenProps.scarecrow(garden, at, yaw)
		"lantern": node = GardenProps.lantern(garden, at, yaw)
		"stones": node = GardenProps.stepping_stones(garden, at, yaw, rng)
		"fire_pit": node = preload("res://scripts/garden/fire_pit.gd").build(garden, at, yaw)
		_:
			if OFFERINGS.has(kind):
				node = GardenProps.offering_dish(garden, at, yaw, str(OFFERINGS[kind]["find"]))
			else:
				return
	node.rotation_degrees.y = yaw                        # every kind the same way round (it's saved, and arranged)
	var spec: Dictionary = BUILDS.get(kind, OFFERINGS.get(kind, {}))
	garden._thing(kind, node, p2, float(spec["radius"]), int(spec.get("price", 0)) / 2)
	garden.things[-1]["placed"] = true
	garden.things[-1]["id"] = "placed_%d_%d" % [Time.get_ticks_usec(), randi()]
	if garden.hideouts != null and garden.hideouts.SPOTS.has(kind):
		garden.hideouts.add_spot(garden.things[-1])
	placed.append({"kind": kind, "x": p2.x, "z": p2.y, "yaw": yaw, "node": node})
	if animate:
		Telemetry.event("build", {"kind": kind})
		Motion.appear(node, Vector3.ONE)


func _thing_at(p: Vector2) -> Variant:               # (a thing Dictionary, or null)
	var best = null
	var best_d := 1e9
	for t in garden.things:
		var d: float = p.distance_to(t["at"])
		if d < maxf(float(t["radius"]), 0.7) and d < best_d:
			best = t
			best_d = d
	return best


## The hole nearest p, within reach (the 🪏 wants you right on it; sowing is more forgiving).
func _bed_at(p: Vector2, reach := 0.9) -> Variant:   # (a seedbed Dictionary, or null)
	var best = null
	for b in seedbeds:
		if p.distance_to(b["at"]) < reach and (best == null or p.distance_to(b["at"]) < p.distance_to(best["at"])):
			best = b
	return best


func _plant_at(p: Vector2) -> Variant:              # (a plant Dictionary, or null)
	for pl in plants:
		if p.distance_to(pl["at"]) < 1.0:
			return pl
	return null


func _blocked_for_bed(p: Vector2) -> bool:
	if not garden.BOUNDS.has_point(p) or garden._blocked(p, 0.12):
		return true
	for b in seedbeds:
		if p.distance_to(b["at"]) < ROW_STEP * 0.7:
			return true
	return false


## Where a new hole goes: right where you tapped, or - beside another hole - one step along from it, joining its row
## (any direction: rows, curves, a square plot).
func _dig_spot(p: Vector2) -> Vector2:
	var near = null
	var best := ROW_STEP * 1.6
	for b in seedbeds:
		var d: float = p.distance_to(b["at"])
		if d < best:
			best = d
			near = b
	if near == null:
		return p
	var dir: Vector2 = (p - near["at"]).normalized() if p.distance_to(near["at"]) > 0.01 else Vector2.RIGHT
	return near["at"] + dir * ROW_STEP


func dirt_at(p: Vector2) -> Variant:                 # (a dirt pile Dictionary, or null)
	for d in dirt_piles:
		if p.distance_to(d["at"]) < 0.22 + 0.07 * d["loads"]:
			return d
	return null


## A load of dirt onto the pile beside `beside` (or a new pile, a step off to the side of the row).
func add_dirt(near: Vector2, side: Vector2 = Vector2.ZERO, loads := 1) -> void:
	for d in dirt_piles:
		if near.distance_to(d["at"]) < 1.7 and d["loads"] < DIRT_MAX:
			d["loads"] += loads
			_dirt_look(d)
			return
	var at := near + side                                 # (no side: right there)
	for k in range(8):                                    # somewhere clear of the beds
		if not seedbeds.any(func(b) -> bool: return at.distance_to(b["at"]) < 0.7) and garden.BOUNDS.has_point(at):
			break
		at = near + Vector2.from_angle(k * TAU / 8.0) * 1.0
	var d := {"at": at, "loads": loads, "node": null}
	dirt_piles.append(d)
	_dirt_look(d)


func take_dirt(d: Dictionary) -> void:
	d["loads"] -= 1
	if d["loads"] <= 0:
		dirt_piles.erase(d)
		Motion.vanish(d["node"], true)
	else:
		_dirt_look(d)


func _dirt_look(d: Dictionary) -> void:
	var s: float = 0.6 + 0.2 * d["loads"]
	if d["node"] == null:
		var node := GardenProps.part(garden, GardenProps.blob(Vector3(0.36, 0.22, 0.32), {"exponent": 2.0, "flat_bottom": 0.5}), GardenProps.mat("dirtpile", Color("5c4230")), Vector3(d["at"].x, 0.0, d["at"].y), Vector3(0, randf() * 360.0, 0), 0.006)
		node.name = "DirtPile"
		d["node"] = node
		Motion.appear(node, Vector3.ONE * s)
	else:
		Motion.channel(d["node"], "scale").tween_property(d["node"], "scale", Vector3.ONE * s, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fill a hole back in (it goes; what was sown in it comes back as a seed).
func fill_hole(bed: Dictionary) -> void:
	Telemetry.event("fill")
	if bed["plant"] != null:
		unplant(bed["plant"])
	seedbeds.erase(bed)
	_burst_dirt(bed["at"])
	Motion.vanish(bed["node"], true)


## Dig up what's growing in a bed: a seed or sprout comes back as a seed (same as it was); a bigger plant goes on the
## compost. The hole stays.
func unplant(pl: Dictionary) -> void:
	Telemetry.event("unplant", {"species": pl["species"], "stage": pl["stage"]})
	plants.erase(pl)
	pl["bed"]["plant"] = null
	if pl["node"] != null:
		Motion.vanish(pl["node"], true)
	if int(pl["stage"]) <= 1:
		keep_seeds.append({"species": pl["species"], "genes": pl["genes"]})


func _burst_dirt(at: Vector2) -> void:
	if grab != null:
		grab._burst(Vector3(at.x, 0.05, at.y), Color("6a5038"), 10, 1.0)


func _clear(t: Dictionary) -> void:
	if garden.hideouts.occupied(t):
		toast("Someone's hiding in there.")
		return
	garden.hideouts.remove_spot(t)
	garden.things.erase(t)
	placed = placed.filter(func(b) -> bool: return b["node"] != t["node"])
	cleared += 1
	Telemetry.event("clear", {"kind": t["kind"]})
	coins += int(t["value"])
	Motion.vanish(t["node"], true, Motion.BASE)
	toast("🪏 Cleared the %s. 🪙 +%d" % [_thing_name(t["kind"]), t["value"]])
	_refresh()


func _dig(p: Vector2) -> Dictionary:
	var bed := {"at": p, "node": null, "plant": null}
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("6a5038")
	m.roughness = 1.0
	m.metallic_specular = 0.0
	GardenProps.near_fade(m)
	bed["mat"] = m
	var yaw := randf() * 360.0
	var link = null                                       # the hole it joins, if any
	for b in seedbeds:
		if p.distance_to(b["at"]) < ROW_STEP * 1.05:
			link = b
			break
	if link != null:
		var dir: Vector2 = p - link["at"]
		yaw = rad_to_deg(atan2(-dir.y, dir.x))
		link["node"].rotation_degrees.y = yaw if not link.get("linked", false) else link["node"].rotation_degrees.y
		link["linked"] = true
		bed["linked"] = true
	var node := GardenProps.part(garden, GardenProps.blob(Vector3(0.52, 0.06, 0.4), "pebble"), m, Vector3(p.x, 0.0, p.y), Vector3(0, yaw, 0), 0.0)
	node.name = "Seedbed"
	if link != null:                                       # the soil between them: one long hole
		var mid := (link["at"] as Vector2 - p) * 0.5
		GardenProps.part(node, GardenProps.blob(Vector3(0.42, 0.055, 0.34), "pebble"), m, Vector3(mid.x, 0.0, mid.y).rotated(Vector3.UP, -deg_to_rad(yaw)), Vector3.ZERO, 0.0)
	Motion.appear(node, Vector3.ONE)
	bed["node"] = node
	seedbeds.append(bed)
	return bed


func _plant(species: String, bed: Dictionary, stage: int, water := 0.6, progress := 0.0, genes := Heredity.STOCK, origin := "seed") -> Dictionary:
	var pl := {"species": species, "at": bed["at"], "stage": stage, "water": water, "progress": progress, "node": null, "bed": bed,
		"genes": Heredity.valid(genes), "origin": origin}
	bed["plant"] = pl
	plants.append(pl)
	_build_plant(pl)
	if stage == 0 and _loaded:
		Telemetry.event("sow", {"species": species, "origin": origin})
	if stage == 0 and origin == "seed":
		toast("%s Planted %s. Water it (💧)." % [SEEDS[species]["icon"], species])
	return pl


const STAGE_SIZE := [0.3, 0.32, 0.55, 0.62]


## A plant's look for its stage. The new stage grows out of the old one (no pop): the old shrinks away underneath
## while the new scales up from the old one's size.
func _build_plant(pl: Dictionary) -> void:
	var old: Node3D = pl["node"]
	var from_scale := 0.01
	if old != null:
		var old_stage: int = maxi(0, int(pl["stage"]) - 1)
		var squat := Heredity.SHORT if Heredity.short(pl["genes"]) else 1.0
		var was: float = STAGE_SIZE[old_stage] * (squat if old_stage >= 2 else 1.0)
		var now: float = STAGE_SIZE[pl["stage"]] * (squat if int(pl["stage"]) >= 2 else 1.0)
		from_scale = was / now
		Motion.vanish(old, true, Motion.BASE)
	var at := Vector3(pl["at"].x, 0.0, pl["at"].y)
	var stage: int = pl["stage"]
	var holder := Node3D.new()
	holder.name = "Plant_" + pl["species"]
	garden.add_child(holder)
	if stage == 0:
		GardenProps.part(holder, GardenProps.blob(Vector3(0.25, 0.12, 0.25), "dome"), GardenProps.mat("mound", Color("5c432e")), at, Vector3.ZERO, 0.0)
	else:
		var size: float = [0.0, 0.32, 0.55, 0.62][stage]
		if stage >= 2 and Heredity.short(pl["genes"]):
			size *= Heredity.SHORT
		var look: Array = SpeciesBuilder.PLANTS[pl["species"]]
		var palette := SpeciesBuilder.palette_of(look[0])
		var bush: Node3D = garden._bush(at + Vector3(0, size * 0.75, 0), Vector3(size, size * 0.85, size), SEEDS[pl["species"]]["sheet"], palette, Color(SpeciesBuilder.PALETTES[look[0]][6]), 0.22 + size * 0.2, 1.6, "dome", 1.0 if stage == 3 else 0.0, Heredity.bloom(pl["species"], pl["genes"]))
		bush.reparent(holder)
	pl["node"] = holder
	holder.scale = Vector3.ONE * from_scale
	var t := Motion.channel(holder, "scale")
	t.tween_property(holder, "scale", Vector3.ONE, Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _splash(at: Vector3) -> void:
	var drop := Label3D.new()
	drop.text = "💧"
	drop.font_size = 64
	drop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	drop.position = at + Vector3(0, 0.8, 0)
	garden.add_child(drop)
	Motion.float_away(drop, 0.8, 0.8, 0.2)


## Now and then an empty seedbed near something flowering gets a seedling of its own. It takes after the flowering
## plant and after another of the same kind (the bees' doing), or the plant itself (Heredity.cross).
func _self_sow() -> void:
	var empty := seedbeds.filter(func(b) -> bool: return b["plant"] == null)
	if empty.is_empty() or randf() > 0.4:
		return
	var bed: Dictionary = empty.pick_random()
	var near := plants.filter(func(pl) -> bool: return pl["stage"] >= 3 and (pl["at"] as Vector2).distance_to(bed["at"]) < SOW_REACH)
	if near.is_empty():
		return
	var mother: Dictionary = near.pick_random()
	var kin := plants.filter(func(pl) -> bool: return pl["stage"] >= 3 and pl["species"] == mother["species"])
	var father: Dictionary = kin.pick_random()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var genes := Heredity.cross(mother["genes"], father["genes"], rng)
	_plant(mother["species"], bed, 0, 0.3, 0.0, genes, "volunteer")
	toast("🌱 Something's come up on its own in an empty bed.")
	if mother["genes"] != father["genes"]:
		nursery["crossed"] = true
	var m: String = mother["genes"]
	var f: String = father["genes"]
	if (Heredity.pale(genes) and not Heredity.pale(m) and not Heredity.pale(f)) or (Heredity.short(genes) and not Heredity.short(m) and not Heredity.short(f)):
		nursery["returned"] = true                       # it skipped the parents and came back


var _loaded := false               # saving before the old save was read would overwrite it
