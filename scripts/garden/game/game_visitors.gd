extends "res://scripts/garden/game/game_plants.gd"

## Game 3/7 - visitors: who the garden attracts and why, capacity, favourites, gifts, the contraband.
##
## Why a hedgepet comes. appeal() scores how inviting the garden is; each species notices the garden, visits, then
## moves in when its wishes are met (CharacterArtProfile.wants, grows_for). capacity() is 2 to 6 by design: they are
## not Pokemon, and every garden ends up different. Residents leave gifts; the contraband is a rare, harmless change
## in a herby resident (see the comment on it in game_state.gd).
##
## Part of the garden game layer chain (the full order is at the top of scripts/garden/garden_game.gd). Code here was moved verbatim
## from the old single file; only its place changed.

const GIFT_COLLECTION := {"🌰": "acorn", "🪶": "feather", "🍄": "mushroom", "🐚": "shell", "💎": "stone", "🌼": "flower", "🫐": "berry"}
var collection := {}             # found kind -> number; unlike the basket, this is a keepsake record
## The contraband (the owner's design notes): very rarely a resident made of something leafy and herby starts to
## change - "Hmm. Clover's leaves look different." - then, a while later, smells really strong; then the journal
## quietly identifies the volunteer growth, and it's made of cannabis. From then on it wants full sun, preferably
## right by the street gate in front of the house with the porch. Nothing bad happens; there's no meter. Lure it back
## with water, or regraft it with ✂️ and it settles down. Saved; telemetry "contraband".
var contraband := {}                 # {name, stage (1 leaves, 2 smell, 3 cannabis, 4 settled), next_at}
const CONTRABAND_CHANCE := 0.012     # per minute of play, while there's a likely resident
const CONTRABAND_STEP := 600.0       # real seconds between the signs
const CONTRABAND_PLANTS := ["clover", "fern", "sage", "moss", "variegated", "ivy"]
## How many hedgepets the garden has room for at once (residents and guests together): a remarkable garden, six.
const MAX_PETS := 6
const MOVE_ON_SECONDS := 600.0      # a resident whose wishes go unmet this long moves on (it may come back)
var discovered := {}                # pet name -> [plants it has visited in]: the variant collection
var _since := {}                   # pet name -> seconds its current step's wishes have been unmet
var story: GardenStory              # scripts/garden/garden_story.gd: Your garden, cause and effect, introductions


## Appeal: how inviting the garden is. Every kind of plant grown, every kind of thing built and every resident adds
## to it; more appeal = more guests at once and new faces sooner.
func appeal() -> int:
	var a := 0
	var kinds := {}
	for pl in plants:
		if pl["stage"] >= 2:
			kinds[pl["species"]] = true
	a += kinds.size()
	var built := {}
	for b in placed:
		built[b["kind"]] = true
	a += built.size()
	for k in pet_state:
		if pet_state[k] == "resident":
			a += 1
	return a


func max_guests() -> int:
	return capacity()


## How many hedgepets the garden has room for at once, residents included: 2, up to MAX_PETS for a remarkable
## garden (many kinds of plants grown, many kinds of things built).
func capacity() -> int:
	var kinds := {}
	for pl in plants:
		if pl["stage"] >= 2:
			kinds[pl["species"]] = true
	var built := {}
	for b in placed:
		built[b["kind"]] = true
	return clampi(2 + (kinds.size() + built.size()) / 3, 2, MAX_PETS)


## Whether you grow any plant this pet is made of (or one related): what draws each hedgepet in the first place.
func grows_for(p: CharacterArtProfile) -> bool:
	var vs: Array = SpeciesBuilder.variants_of(p)
	return plants.any(func(pl) -> bool: return vs.has(pl["species"]))


func notice_gap() -> float:
	return maxf(5.0, 14.0 - appeal() * 0.6)
var _notice_wait := 4.0


func _visitors() -> void:
	var counts := garden_counts()
	story.watch(counts)
	_notice_wait -= 1.0
	var guests := 0                                       # everyone here: residents too (room for capacity())
	for k in pet_state:
		if pet_state[k] in ["noticed", "visiting", "resident"]:
			guests += 1
	var order: Array = garden.roster.duplicate()
	order.shuffle()
	for p: CharacterArtProfile in order:
		var name := p.pet_name
		var state: String = pet_state[name]
		var next := state
		match state:
			"away":
				if guests < capacity() and _notice_wait <= 0.0 and _met(p.wants["notice"], counts) and grows_for(p) and FruitUnlocks.unlocked(p):
					guests += 1
					_notice_wait = notice_gap()
					next = "noticed"
					_choose_variant(p)
			"noticed":
				if _met(p.wants["visit"], counts):
					next = "visiting"
					if story.introduced.has(name):
						toast("%s came in to have a look around." % name)
				elif not _met(p.wants["notice"], counts):
					_since[name] = float(_since.get(name, 0.0)) + 1.0
					if float(_since[name]) > 90.0:          # lingers at the fence a good while first
						next = "away"
			"resident":
				if not p.starts_resident and not _met(p.wants["resident"], counts):
					_since[name] = float(_since.get(name, 0.0)) + 1.0
					if float(_since[name]) > MOVE_ON_SECONDS:  # a long while: no hurry, no punishment, just change
						next = "away"
						toast("%s has moved on, somewhere that suits it better. It might come back one day." % name)
				else:
					_since[name] = 0.0
			"visiting":
				if _met(p.wants["resident"], counts):
					next = "resident"
					coins += 10
					toast("🏡 %s moved in! (🪙 +10)" % name)
				elif not _met(p.wants["visit"], counts):
					_since[name] = float(_since.get(name, 0.0)) + 1.0
					if float(_since[name]) > 240.0:         # stays a long while; no rush to make it happy
						next = "noticed" if _met(p.wants["notice"], counts) else "away"
						toast("%s wandered home for now. Maybe another day." % name)
		if next != state:
			Telemetry.event(next if next != "away" else "left", {"pet": name, "from": state, "here": guests, "room": capacity()})
			_since[name] = 0.0
			pet_state[name] = next
			_apply_mode(_node(p))
			if next == "visiting":
				story.arrived(p)                          # the first time: the camera eases to it, a card introduces it
			_refresh()


## Which variant turns up depends on what you grow: if any of this pet's variant plants are grown here, it often
## comes made of one of them. A new variant goes in the collection.
func _choose_variant(p: CharacterArtProfile) -> void:
	var grown := {}
	for pl in plants:
		if pl["stage"] >= 2:
			grown[pl["species"]] = true
	var options: Array = SpeciesBuilder.variants_of(p).filter(func(v) -> bool: return grown.has(v))
	var plant := SpeciesBuilder.native_plant(p)
	if not options.is_empty() and randf() < 0.75:
		plant = options.pick_random()
	pet_plant[p.pet_name] = plant
	var seen: Array = discovered.get(p.pet_name, [])
	if not seen.has(plant):
		seen.append(plant)
		discovered[p.pet_name] = seen
		toast("✨ Someone new at the fence: a %s!" % SpeciesBuilder.variant_name(p, plant))
	else:
		toast("A %s is peeking through the gap in the fence…" % SpeciesBuilder.variant_name(p, plant))


func _apply_mode(node: HedgePetNode, at_once := false) -> void:
	var state: String = pet_state[node.profile.pet_name]
	var mode: String = {"away": "away", "noticed": "peek", "visiting": "roam", "resident": "roam"}[state]
	if garden.pet_mode(node) in ["roam", "peek"] and mode == "away" and not at_once:   # walk off, never blink out
		mode = "leave"
	if garden.pet_mode(node) != mode:
		garden.set_pet_mode(node, mode, at_once)


func _tend_contraband(force := "") -> void:
	var now := Time.get_unix_time_from_system()
	if contraband.is_empty():
		var likely: Array = garden.roster.filter(func(p) -> bool: return pet_state.get(p.pet_name, "") == "resident" and not p.starts_resident \
			and CONTRABAND_PLANTS.has(pet_plant.get(p.pet_name, SpeciesBuilder.plant_of(p))))
		if force != "":
			likely = garden.roster.filter(func(p) -> bool: return p.pet_name == force)
		if likely.is_empty() or (force == "" and OS.get_environment("HEDGEPETS_CONTRABAND") == "" and randf() > CONTRABAND_CHANCE):
			return
		var who: CharacterArtProfile = likely[0]
		for p: CharacterArtProfile in likely:                 # Clover first, if she's here
			if p.pet_name == "Clover":
				who = p
		contraband = {"name": who.pet_name, "stage": 1, "next_at": now + CONTRABAND_STEP}
		Telemetry.event("contraband", {"stage": 1, "pet": who.pet_name})
		toast("Hmm. %s's leaves look different." % who.pet_name)
		return
	var name: String = contraband["name"]
	var stage: int = contraband["stage"]
	if stage >= 3 or (now < float(contraband["next_at"]) and force == ""):
		return
	contraband["stage"] = stage + 1
	contraband["next_at"] = now + CONTRABAND_STEP
	Telemetry.event("contraband", {"stage": stage + 1, "pet": name})
	if stage == 1:
		toast("%s smells... really strong today." % name)
	else:
		pet_plant[name] = "cannabis"
		var node := node_by_name(name)
		if node != null:
			node.set_plant("cannabis")
		var seen: Array = discovered.get(name, [])
		if not seen.has("cannabis"):
			seen.append("cannabis")
			discovered[name] = seen
		toast("📖 Your journal has quietly identified the volunteer growth on %s: Cannabis sativa. Oh no." % name)


## Whether this pet is the contraband (made of cannabis, not settled).
func is_contraband(name: String) -> bool:
	return contraband.get("name", "") == name and int(contraband.get("stage", 0)) == 3


# ------------------------------------------------------------------ favourites and gifts
const WANT_THINGS := {"puddle": ["sprinkler", "💧"], "sticks": ["stick", "🪵"], "branches": ["branch", "🪵"], "rocks": ["rock", "☀️"],
	"leaf_pile": ["leaf_pile", "🍂"], "lawn_chair": ["lawn_chair", "💤"], "brush_pile": ["brush_pile", "🍂"], "woodpile": ["woodpile", "🪵"], "chair": ["chair", "💤"], "grill": ["grill", "👃"], "tire": ["tire", "💤"], "pot": ["pot", "💤"]}
const GIFTS := [["🌰", 2], ["🪶", 3], ["🍄", 2], ["🐚", 4], ["💎", 6], ["🌼", 2], ["🫐", 3]]
var gifts: Array = []               # {at: Vector3, node: Label3D, value, age}


## Somewhere this pet likes to go: one of the things or plants in its wishes. {at, radius, emote} or {}.
func favourite(node: HedgePetNode) -> Dictionary:
	var p: CharacterArtProfile = node.profile
	var options: Array = []
	if is_contraband(p.pet_name):                        # it wants sun: right out front, by the street gate
		var g: Vector3 = garden.GATES["houses"]["inside"]
		for k in range(10):
			options.append({"at": g + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.2, 0.2)), "radius": 0.6, "emote": "☀️"})
	for step in ["notice", "visit", "resident"]:
		for key: String in p.wants[step]:
			if OFFERING_WANT_TO_KIND.has(key):
				for t in garden.things:
					if t["kind"] == OFFERING_WANT_TO_KIND[key]:
						options.append({"at": Vector3(t["at"].x, 0, t["at"].y), "radius": t["radius"], "emote": OFFERING_WANT_EMOTE[key]})
				continue
			if WANT_THINGS.has(key):
				var kind: String = WANT_THINGS[key][0]
				for t in garden.things:
					if t["kind"] == kind:
						options.append({"at": Vector3(t["at"].x, 0, t["at"].y), "radius": t["radius"], "emote": WANT_THINGS[key][1]})
			else:
				var sp := key.get_slice("_", 0)
				for pl in plants:
					if pl["species"] == sp and pl["stage"] >= 1:
						options.append({"at": Vector3(pl["at"].x, 0, pl["at"].y), "radius": 0.6, "emote": "💚" if pl["stage"] < 3 else "🌸"})
	for t in garden.things:                               # a lit fire: everyone likes sitting by it
		if t["kind"] == "fire_pit" and t["node"].lit():
			for k in range(3):
				options.append({"at": Vector3(t["at"].x, 0, t["at"].y), "radius": 1.1, "emote": "🔥"})
	return options.pick_random() if not options.is_empty() else {}


const OFFERING_WANT_TO_KIND := {"cone": "offering_cone", "acorn": "offering_acorn", "feather": "offering_feather", "apple": "offering_apple"}
const OFFERING_WANT_EMOTE := {"cone": "🌲", "acorn": "🌰", "feather": "🪶", "apple": "🍎"}


## One favourite collectable per pet, derived from its authored wants. It is deliberately not a second data table.
func favourite_collectable(p: CharacterArtProfile) -> String:
	for step in ["resident", "visit", "notice"]:
		for key: String in p.wants[step]:
			if OFFERING_WANT_TO_KIND.has(key):
				return key
	return ""


var _away_for := 0.0                # seconds since the last visit (0 on a first visit)


## Something to tap for coins (a gift here, a trinket in the woods): the same size on screen however far the camera
## is (at the garden's distance a 30 cm emoji was a speck among the leaf litter), a pale halo so it reads on grass and
## in the dark woods, drawn over the grass and leaves. `size`: its height in metres at 1 m from the camera.
static func pickup_label(icon: String, size := 0.07) -> Label3D:
	var l := Label3D.new()
	l.text = icon
	l.font_size = 64
	l.outline_size = 14
	l.outline_modulate = Color(1.0, 0.97, 0.84, 0.85)
	l.fixed_size = true
	l.pixel_size = size / 64.0
	l.no_depth_test = true
	l.render_priority = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l


func _restore_gift(icon: String, at: Vector3, value: int) -> void:
	var l := pickup_label(icon)
	l.position = at + Vector3(0, 0.25, 0)
	garden.add_child(l)
	gifts.append({"at": at, "node": l, "value": value, "age": 1.0})


## Back after a while: the garden carried on without you. A resident or two may have flowered; nothing went wrong.
func _welcome_back() -> void:
	if _away_for < 6.0 * 3600.0:
		return
	var blooms := mini(3, 1 + int(_away_for / 86400.0))
	for i in range(blooms):
		surprise_flower(true)
	toast("🌿 Welcome back. The garden's been growing.")


## A happy resident leaves something behind: tap it to collect.
func _drop_gift(node: HedgePetNode) -> void:
	var g: Array = GIFTS.pick_random()
	var gift_kind: String = str(GIFT_COLLECTION.get(g[0], ""))
	if gift_kind != "":
		collection[gift_kind] = int(collection.get(gift_kind, 0)) + 1
	var l := pickup_label(g[0])
	var at := node.position + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(0.3, 0.7))
	l.position = at + Vector3(0, 1.1, 0)
	garden.add_child(l)
	Motion.appear(l, Vector3.ONE, Motion.FAST)
	Motion.drop(l, 0.25)
	gifts.append({"at": at, "node": l, "value": g[1], "age": 0.0})
	garden.emote(node, "🎁")


func _tend_gifts(delta: float) -> void:
	for g in gifts.duplicate():
		g["age"] += delta
		var l: Label3D = g["node"]
		if g["age"] > Motion._d(Motion.SLOW) + 0.05:   # landed: a gentle bob, eased in
			l.position.y = 0.25 + 0.07 * sin((g["age"] - 0.65) * 3.0) * clampf(g["age"] - 0.65, 0.0, 1.0)
		# gifts stay where they fell until you pick them up (they're saved, too): nothing to miss


func _collect_gift(p2: Vector2) -> bool:
	for g in gifts:
		if Vector2(g["at"].x, g["at"].z).distance_to(p2) < 0.75:
			coins += int(g["value"])
			gifts.erase(g)
			var l: Label3D = g["node"]
			Motion.float_away(l, 1.2, 0.6, 0.1)
			toast("%s 🪙 +%d" % [l.text, g["value"]])
			_refresh()
			return true
	return false
