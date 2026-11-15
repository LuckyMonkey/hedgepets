extends "res://scripts/garden/game/game_ui.gd"

## Game 7/7 - the tools: what a tap does with each tool, the shovel, regrafting, arranging things.
##
## tap() is the big switch: what a tap on the lawn, a plant, a thing or a pet does with the tool in hand (hand,
## shovel, seeds, water, basket). With the basket out you can drag a build to move it (arrange_*).
##
## Part of the garden game layer chain (the full order is at the top of scripts/garden/garden_game.gd). Code here was moved verbatim
## from the old single file; only its place changed.

## A tap on the garden. Returns true when the game used it (the garden then does nothing else).
func tap(at: Vector2, pet: HedgePetNode) -> bool:
	if at.y > garden.get_viewport().get_visible_rect().size.y * 0.86 or at.y < 120:
		return true                                      # the toolbar and the top bar
	var g: Vector3 = garden.ground_point(at)
	if g == Vector3.INF:
		return false
	var p2 := Vector2(g.x, g.z)
	if _collect_gift(p2):
		return true
	if pet == null and garden.on_bridge(p2):           # over the footbridge: into the woods
		garden.woods.enter()
		return true
	match tool:
		"hand":
			if carried != "" and pet == null and _thing_at(p2) == null:
				if not garden.BOUNDS.has_point(p2) or garden._blocked(p2, 0.6):
					toast("Somewhere clear on the lawn.")
				else:
					put_down(Vector3(p2.x, 0, p2.y))
				return true
			if pet != null:
				pet.tap()
				pet.look_point = garden.camera.global_position
				toast(_pet_line(pet))
				return true
			var t = _thing_at(p2)
			var mend = grab._mendable_at(p2)
			if t != null and t["kind"] == "fire_pit":
				t["node"].tapped(self)
			elif t == null and mend != null and mend["kind"] == "fence":
				toast("A broken run of fence. Hold ✋ on it and it'll mend; the collapsed bit becomes a gate.")
			elif t != null and t["kind"] == "wheelbarrow":
				toast("The wheelbarrow (%d/%d loads of dirt). Haul it with ✋ over a dirt pile to load it, over holes to fill them." % [int(t.get("load", 0)), DIRT_MAX])
			elif t != null and t["kind"] == "barrel":
				grab.barrel_tapped()
			elif t != null and t["kind"] == "bucket" and carried == "" and garden.hideouts.occupied(t):
				pick_up_bucket(t)
			elif t != null and garden.hideouts.coax(t):
				toast("Someone's coming out...")
			elif t != null and t["kind"] == "burrow":       # nobody in the doorway: go down and look in on the sleepers
				garden.den.enter()
			elif t != null:
				toast(_thing_line(t))
			elif _plant_at(p2) != null:
				toast(_plant_line(_plant_at(p2)))
			if t != null and t["kind"] == "burrow":
				return true                                  # (went down into the den)
			garden.frame_point(Vector3(p2.x, 0, p2.y))       # the camera comes over to work there
			return true
		"shovel":
			return _shovel(p2)
		"_old_shovel":
			var t = _thing_at(p2)
			if t != null:
				if grab.grabbable(t) and not t.get("placed", false):
					toast("Too heavy to shovel. Grab it with ✋, yank it loose, haul it to the trash barrel 🗑️.")
					return true
				if not t["junk"]:
					toast("That stays.")
					return true
				_clear(t)
				return true
			if _blocked_for_bed(p2):
				toast("Not here - too close to something.")
				return true
			_dig(p2)
			return true
		"seeds":
			var bed = _bed_at(p2)
			if bed == null:
				toast("Dig a seedbed first (🪏).")
				return true
			if bed["plant"] != null:
				toast("Something's already growing there.")
				return true
			for i in keep_seeds.size():
				if keep_seeds[i]["species"] == seed_choice:
					var given: Dictionary = keep_seeds.pop_at(i)
					_plant(seed_choice, bed, 0, 0.6, 0.0, str(given["genes"]), "nursery")
					toast("%s You sow one of the nursery's seeds. Water it (💧)." % SEEDS[seed_choice]["icon"])
					return true
			var price: int = SEEDS[seed_choice]["price"]
			if coins < price:
				toast("Not enough coins for %s seeds (🪙 %d)." % [seed_choice, price])
				return true
			coins -= price
			_plant(seed_choice, bed, 0)
			_refresh()
			return true
		"shears":
			if pet == null:
				toast("Tap a pet to regraft it in %s %s (🪙 %d)." % [SEEDS[seed_choice]["icon"], seed_choice, SEEDS[seed_choice]["price"]])
				return true
			regraft(pet)
			return true
		"build":
			if OFFERINGS.has(build_choice):
				var offering: Dictionary = OFFERINGS[build_choice]
				var basket: Dictionary = woods_finds["basket"]
				var find_kind: String = offering["find"]
				if int(basket.get(find_kind, 0)) <= 0:
					toast("Find a %s in the woods first. It will wait in your basket." % find_kind)
					return true
				if not garden.BOUNDS.has_point(p2) or garden._blocked(p2, float(offering["radius"]) + 0.2) or _bed_at(p2) != null:
					toast("Not here - too close to something.")
					return true
				basket[find_kind] -= 1
				_place(build_choice, p2, randf_range(-40, 40))
				toast("%s Set out the %s." % [offering["icon"], offering["name"]])
				_refresh()
				return true
			var item: Dictionary = BUILDS[build_choice]
			if coins < int(item["price"]):
				toast("A %s costs 🪙 %d." % [item["name"], item["price"]])
				return true
			if not garden.BOUNDS.has_point(p2) or garden._blocked(p2, float(item["radius"]) + 0.2) or _bed_at(p2) != null:
				toast("Not here - too close to something.")
				return true
			coins -= int(item["price"])
			_place(build_choice, p2, randf_range(-40, 40))
			toast("%s Put down a %s." % [item["icon"], item["name"]])
			_refresh()
			return true
		"water":
			if pet != null:
				pet.shake_off()
				_splash(pet.position + Vector3(0, 0.6, 0))
				toast(["%s shook it all off.", "%s gave a big shake. Droplets everywhere.", "%s didn't mind the water at all."].pick_random() % pet.profile.pet_name)
				return true
			var pl = _plant_at(p2)
			if pl == null:
				toast("Water a plant (tap right on it).")
				return true
			pl["water"] = 1.0
			toast("💧 Watered the %s." % pl["species"])
			_splash(Vector3(pl["at"].x, 0.2, pl["at"].y))
			return true
	return false


## The 🪏: scoop dirt, fill holes, dig up what you sowed, dig new holes (joining rows), clear junk.
func _shovel(p2: Vector2) -> bool:
	var pile = dirt_at(p2)
	var bed = _bed_at(p2, 0.38)
	var t = _thing_at(p2)
	if barrow.has("node") and p2.distance_to(barrow["at"]) < 0.7:
		if shovelful:
			if int(barrow.get("load", 0)) >= DIRT_MAX:
				toast("The wheelbarrow's full.")
			else:
				shovelful = false
				grab.barrow_load(barrow, 1)
				toast("Into the wheelbarrow with it.")
		elif int(barrow.get("load", 0)) > 0:
			shovelful = true
			grab.barrow_load(barrow, -1)
			toast("🪏 A shovelful from the wheelbarrow. Tap a hole to fill it.")
		else:
			toast("An empty wheelbarrow. Haul it (✋) over a dirt pile to fill it, then over holes to fill them.")
		_refresh()
		return true
	if shovelful:
		if bed != null and bed["plant"] == null:
			shovelful = false
			fill_hole(bed)
			toast("🪏 Filled it in.")
		elif pile != null:
			if pile["loads"] < DIRT_MAX:
				pile["loads"] += 1
				_dirt_look(pile)
			shovelful = false
			toast("Back on the pile.")
		elif bed != null:
			toast("Something's growing there. Fill an empty hole, or put the dirt down on the lawn.")
		elif not garden._blocked(p2, 0.1) and garden.BOUNDS.has_point(p2):
			shovelful = false
			add_dirt(p2, Vector2.ZERO)
			toast("Put the dirt down.")
		else:
			toast("Not here.")
		_refresh()
		return true
	if pile != null:
		shovelful = true
		take_dirt(pile)
		toast("🪏 A shovelful of dirt. Tap a hole to fill it in.")
		_refresh()
		return true
	if bed != null:
		if bed["plant"] != null:
			var pl: Dictionary = bed["plant"]
			var name: String = SpeciesBuilder.PLANT_NAMES.get(pl["species"], pl["species"])
			unplant(pl)
			toast(("🪏 Dug the %s back up. The seed's back in 🌱." if int(pl["stage"]) <= 1 else "🪏 Dug up the %s. It goes on the compost.") % name)
			_refresh()
			return true
		var src = null                                     # fill it from the nearest dirt
		for d in dirt_piles:
			if d["at"].distance_to(bed["at"]) < 4.0 and (src == null or d["at"].distance_to(bed["at"]) < src["at"].distance_to(bed["at"])):
				src = d
		if src != null:
			take_dirt(src)
			fill_hole(bed)
			toast("🪏 Filled it in from the pile.")
		else:
			toast("No dirt nearby to fill it. Bring some in the wheelbarrow.")
		return true
	if t != null:
		if grab.grabbable(t) and not t.get("placed", false):
			toast("Too heavy to shovel. Grab it with ✋, yank it loose, haul it to the trash barrel 🗑️.")
			return true
		if not t["junk"]:
			toast("That stays.")
			return true
		_clear(t)
		return true
	var spot := _dig_spot(p2)
	if _blocked_for_bed(spot):
		spot = p2
	if _blocked_for_bed(spot):
		toast("Not here - too close to something.")
		return true
	for d in dirt_piles:                                  # a pile in the way of the row: shove it aside
		if (d["at"] as Vector2).distance_to(spot) < 0.75:
			var away: Vector2 = (d["at"] - spot).normalized() if (d["at"] as Vector2).distance_to(spot) > 0.01 else Vector2.UP
			d["at"] = spot + away * 0.95
			Motion.channel(d["node"], "move").tween_property(d["node"], "position", Vector3(d["at"].x, 0, d["at"].y), Motion._d(Motion.BASE)).set_trans(Tween.TRANS_SINE)
	var nb := _dig(spot)
	Telemetry.event("dig", {"row": nb.get("linked", false)})
	var cam: Vector3 = garden.camera.global_position
	var side := (Vector2(cam.x, cam.z) - spot).normalized() * 1.0   # toward you: below the row on screen, out of its way
	if nb.get("linked", false):
		var dir := Vector2.from_angle(-deg_to_rad(nb["node"].rotation_degrees.y))
		var perp := dir.orthogonal()
		side = (perp if perp.dot(side) >= 0.0 else -perp) * 1.0
	add_dirt(spot, side)
	_burst_dirt(spot)
	return true


## ✂️ on a pet: regrow it in the chosen seed's plant (its price). The contraband, regrafted, settles down.
func regraft(pet: HedgePetNode) -> void:
	var price: int = SEEDS[seed_choice]["price"]
	if SpeciesBuilder.plant_of(pet.profile) == seed_choice:
		toast("%s is already %s." % [pet.profile.pet_name, seed_choice])
	elif coins < price:
		toast("Regrafting in %s costs 🪙 %d." % [seed_choice, price])
	else:
		coins -= price
		pet_plant[pet.profile.pet_name] = seed_choice
		pet.set_plant(seed_choice)
		if is_contraband(pet.profile.pet_name):     # regrafted: it settles down
			contraband["stage"] = 4
			Telemetry.event("contraband", {"stage": 4, "pet": pet.profile.pet_name})
		Telemetry.event("regraft", {"pet": pet.profile.pet_name, "plant": seed_choice})
		toast("✂️ %s is growing in %s now." % [pet.profile.pet_name, seed_choice])
		_refresh()


# ------------------------------------------------------------------ arranging (🧺)
var _arr: Dictionary = {}             # {t, from}: the thing being moved
## A press with 🧺 out. True if it landed on something you built: then a drag moves it and a tap turns it (and the
## press doesn't also put a new thing down).
func arrange_begin(screen: Vector2) -> bool:
	_arr = {}
	if tool != "build":
		return false
	var g: Vector3 = garden.ground_point(screen)
	if g == Vector3.INF:
		return false
	var t = _thing_at(Vector2(g.x, g.z))
	if t == null or not t.get("placed", false):
		return false
	if garden.hideouts.occupied(t):
		toast("Someone's hiding in there. Let them be.")
		return true
	_arr = {"t": t, "from": (t["node"] as Node3D).position}
	return true


func arrange_move(screen: Vector2) -> void:
	if _arr.is_empty():
		return
	var g: Vector3 = garden.ground_point(screen)
	if g != Vector3.INF:
		(_arr["t"]["node"] as Node3D).position = Vector3(g.x, 0.12, g.z)       # lifted a little while it's carried


func arrange_end(_screen: Vector2, dragged: bool) -> void:
	if _arr.is_empty():
		return
	var t: Dictionary = _arr["t"]
	var n: Node3D = t["node"]
	var from: Vector3 = _arr["from"]
	_arr = {}
	if not dragged:                                      # a tap: turn it an eighth
		n.position = from
		Motion.channel(n, "turn").tween_property(n, "rotation_degrees:y", n.rotation_degrees.y + 45.0, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	var p2 := Vector2(n.position.x, n.position.z)
	var was: Vector2 = t["at"]
	t["at"] = Vector2(1e6, 1e6)                          # not in its own way
	var fits: bool = garden.BOUNDS.has_point(p2) and not garden._blocked(p2, float(t["radius"]) + 0.1) and _bed_at(p2) == null
	if fits:
		t["at"] = p2
		Motion.drop(n, 0.0, Motion.FAST)
	else:
		t["at"] = was
		toast("Not there - too close to something.")
		Motion.channel(n, "move").tween_property(n, "position", from, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
