extends Node

## The garden loop. Tidy, grow, attract, keep.
##   Tools  ✋ hand (pet them, look at things) · 🪏 shovel (clear junk for scrap coins; dig a seedbed on bare lawn)
##          🌱 seeds (plant ivy, clover, fern or jasmine in a seedbed) · 💧 water (watered plants grow)
##   Plants mound -> sprout -> bush -> flowering, while watered (water dries out).
##   Pets   each species NOTICES the garden (peeks through the gap in the fence), VISITS (comes in, wanders) and
##          MOVES IN (stays; brings a few coins now and then) when its wishes are met (CharacterArtProfile.wants).
##          Junk is not all bad: some visitors want sticks, a leaf pile, a puddle, the tipped chair.
##   Journal what you know about each pet: the hint for its next step, revealed as it gets closer.
##   Water  💧 hold and drag to pour. Hedgepets love water: the ones nearby trot after it, and the ones that reach it
##          walk with you a while (into the woods over the footbridge too). Pour a trail into an empty bucket and the
##          first to reach it climbs in; pick the bucket up with ✋ and carry it (tap the lawn with ✋ to set it down).
##   Saved to user://garden.json every few seconds and whenever you leave (on the web also to localStorage: WebSave).

var save_path := "user://garden.json"
const SEEDS := {
	"ivy": {"icon": "🌿", "price": 3, "sheet": "hedgeivy"},
	"clover": {"icon": "🍀", "price": 3, "sheet": "hedgeclover"},
	"fern": {"icon": "🌾", "price": 4, "sheet": "hedgefern"},
	"jasmine": {"icon": "🌼", "price": 6, "sheet": "hedgejasmine"},
	"sage": {"icon": "🪴", "price": 4, "sheet": "hedgesage"},
	"oak": {"icon": "🌰", "price": 6, "sheet": "hedgeoak"},
	"pine": {"icon": "🌲", "price": 8, "sheet": "hedgepine"},
	"maple": {"icon": "🍁", "price": 7, "sheet": "hedgemaple"},
	"boxwood": {"icon": "🌳", "price": 5, "sheet": "hedgeboxwood"},
	"willow": {"icon": "🎋", "price": 6, "sheet": "hedgewillow"},
	"rose": {"icon": "🌹", "price": 6, "sheet": "hedgerose"},
	"lavender": {"icon": "🪻", "price": 5, "sheet": "hedgelavender"},
	"moss": {"icon": "🍃", "price": 3, "sheet": "hedgemoss"},
	"holly": {"icon": "🎄", "price": 7, "sheet": "hedgeholly"},
	"bostonivy": {"icon": "🧱", "price": 5, "sheet": "hedgebostonivy"},
	"creeper": {"icon": "🍇", "price": 5, "sheet": "hedgecreeper"},
	"variegated": {"icon": "🤍", "price": 6, "sheet": "hedgevariegated"},
	"needlepoint": {"icon": "✳️", "price": 5, "sheet": "hedgeneedlepoint"},
	"heartivy": {"icon": "💚", "price": 4, "sheet": "hedgeheartivy"},
	"persianivy": {"icon": "🟢", "price": 6, "sheet": "hedgepersianivy"},
	"goldchild": {"icon": "💛", "price": 6, "sheet": "hedgegoldchild"},
	"fig": {"icon": "🌀", "price": 4, "sheet": "hedgefig"},
}
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
const MAX_FOLLOWERS := 3
const STAGE_SECONDS := 18.0        # watered growth time per stage
const WATER_SECONDS := 40.0        # how long one watering lasts
const INCOME_SECONDS := 30.0

var garden: Node3D
var coins := 15
var cleared := 0
var tool := "hand"
var seed_choice := "ivy"
var seedbeds: Array = []           # {at: Vector2, node, plant (or null)}
var plants: Array = []             # {species, at, stage, water, progress, node, bed}
var build_choice := "feeder"
var placed: Array = []              # {kind, x, z, yaw}: what you built (saved)
var following: Array = []           # pet names that follow you (saved)
var carried := ""                   # the pet in the bucket, or "" (saved)
var nursery := {"visits": 0, "said": [], "once": [], "gave": false, "crossed": false, "returned": false}   # nursery.gd (saved)
var woods_finds := {"taken": {}, "basket": {}}   # woods.gd: what you've picked up there (when) and what's in the basket
var keep_seeds: Array = []          # seeds the nursery gave you, {species, genes}: sown before bought ones of that kind
const SOW_SECONDS := 45.0           # how often an empty bed may get a self-sown seedling
const SOW_REACH := 5.0              # from a flowering plant this near
var _sow := SOW_SECONDS
## The contraband (the owner's design notes): very rarely a resident made of something leafy and herby starts to
## change - "Hmm. Clover's leaves look different." - then, a while later, smells really strong; then the journal
## quietly identifies the volunteer growth, and it's made of cannabis. From then on it wants full sun, preferably
## right by the street gate in front of the house with the porch. Nothing bad happens; there's no meter. Lure it back
## with water, or regraft it with ✂️ and it settles down. Saved; telemetry "contraband".
var contraband := {}                 # {name, stage (1 leaves, 2 smell, 3 cannabis, 4 settled), next_at}
const CONTRABAND_CHANCE := 0.012     # per minute of play, while there's a likely resident
const CONTRABAND_STEP := 600.0       # real seconds between the signs
const CONTRABAND_PLANTS := ["clover", "fern", "sage", "moss", "variegated", "ivy"]
var _contra_check := 60.0
var _contra_told := false
var _beat := 20.0
var _beats := 0
## Digging. A hole beside another joins it into a row; the dirt goes on a pile beside it (dirt_piles, saved), which
## the 🪏 can scoop from to fill a hole again, and the wheelbarrow (garden_grab.gd) can carry about.
const ROW_STEP := 0.8               # a hole dug this near another joins its row, this far along
const DIRT_MAX := 4                 # loads on one pile
var dirt_piles: Array = []          # {at: Vector2, loads, node}
var shovelful := false              # the 🪏 is carrying a load of dirt
var barrow: Dictionary = {}         # the wheelbarrow's thing (garden.things), its load in barrow["load"]
## How many hedgepets the garden has room for at once (residents and guests together): a remarkable garden, six.
const MAX_PETS := 6
const MOVE_ON_SECONDS := 600.0      # a resident whose wishes go unmet this long moves on (it may come back)
var _bucket_badge: Label
var _lead := 0.0
var discovered := {}                # pet name -> [plants it has visited in]: the variant collection
var pet_plant := {}                # pet name -> the plant it was regrafted in with ✂️ (SpeciesBuilder.PLANTS)
var pet_state := {}                # pet name -> "away" | "noticed" | "visiting" | "resident"
var _since := {}                   # pet name -> seconds its current step's wishes have been unmet
var _income := INCOME_SECONDS
var _check := 0.0
var _save := 5.0
var _ui: CanvasLayer
var _coin_label: Label
var _toast: Label
var _tool_buttons := {}
var _seed_row: GridContainer
var _build_row: GridContainer
const BUILD_AT := Vector2(36, 1560)
var _builds_shown := false
var _journal: PanelContainer
var _journal_text: RichTextLabel


var grab: Node                       # scripts/garden/garden_grab.gd: yank, haul, sell, fix


func setup(g: Node3D) -> void:
	garden = g
	if OS.get_environment("HEDGEPETS_SAVE") != "":
		save_path = OS.get_environment("HEDGEPETS_SAVE")      # checks use their own save file
	_build_ui()
	grab = preload("res://scripts/garden/garden_grab.gd").new()
	grab.name = "Grab"
	add_child(grab)
	grab.setup(garden, self, _ui)
	var wb := GardenProps.wheelbarrow(garden, Vector3(3.2, 0, 7.4), -30.0)   # added last: earlier things keep their ids
	garden._thing("wheelbarrow", wb, Vector2(3.2, 7.4), 0.6, 0, false)
	barrow = garden.things[-1]
	barrow["load"] = 0
	grab.grabbable(barrow)                                # its weight and grip, ready to haul
	for p: CharacterArtProfile in garden.roster:
		pet_state[p.pet_name] = "resident" if p.starts_resident else "away"
	WorldOverrides.current().apply(garden)                # the world editor's authored changes, before the player's save
	_load()
	for p: CharacterArtProfile in garden.roster:
		if pet_state[p.pet_name] != "away":
			_apply_mode(_node(p), true)
	_restore_friends()
	_refresh()
	_refresh.call_deferred()
	Telemetry.start()
	var here := pet_state.values().filter(func(s) -> bool: return s != "away").size()
	Telemetry.event("session", {"touch": DisplayServer.is_touchscreen_available(), "w": garden.get_viewport().get_visible_rect().size.x,
		"back_after_h": snappedf(_away_for / 3600.0, 0.1), "coins": coins, "here": here, "plants": plants.size()})                              # again once the toolbar is laid out (the chip finds its tool)
	if _away_for > 6.0 * 3600.0:
		_welcome_back()
	else:
		toast("Tidy the garden, plant things, and see who comes by.")


# ------------------------------------------------------------------ what the garden has
func garden_counts() -> Dictionary:
	var c := {"puddle": garden.count("sprinkler"), "sticks": garden.count("stick"), "branches": garden.count("branch"),
		"rocks": garden.count("rock"), "leaf_pile": garden.count("leaf_pile"), "lawn_chair": garden.count("lawn_chair"),
		"grill": garden.count("grill"), "tire": garden.count("tire"), "pot": garden.count("pot"),
		"feeder": garden.count("feeder"), "bath": garden.count("bath"), "log_pile": garden.count("log_pile"),
		"nest_box": garden.count("nest_box"), "pumpkin": garden.count("pumpkin"), "apples": garden.count("apples"),
		"woodpile": garden.count("woodpile"), "brush_pile": garden.count("brush_pile"), "chair": garden.count("chair"),
		"clearing": 1 if _clearing() else 0,
		"cleared": cleared}
	for p: CharacterArtProfile in garden.roster:
		if pet_state.get(p.pet_name, "") == "resident":
			c["has_" + p.species] = int(c.get("has_" + p.species, 0)) + 1
	for sp in SEEDS:
		c[sp + "_planted"] = 0
		c[sp + "_grown"] = 0
		c[sp + "_flowering"] = 0
	for pl in plants:
		c[pl["species"] + "_planted"] += 1
		if pl["stage"] >= 2:
			c[pl["species"] + "_grown"] += 1
		if pl["stage"] >= 3:
			c[pl["species"] + "_flowering"] += 1
	return c


func _met(wants: Dictionary, counts: Dictionary) -> bool:
	for k in wants:
		if int(counts.get(k, 0)) < int(wants[k]):
			return false
	return true


# ------------------------------------------------------------------ the loop
func _process(delta: float) -> void:
	_grow(delta)
	_pouring(delta)
	_tend_gifts(delta)
	_sow -= delta
	if _sow <= 0.0:
		_sow = SOW_SECONDS
		_self_sow()
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_visitors()
	_lead -= delta
	if _lead <= 0.0:
		_lead = 0.7
		_lead_followers()
	_income -= delta
	if _income <= 0.0:
		_income = INCOME_SECONDS
		var counts := garden_counts()
		for p: CharacterArtProfile in garden.roster:
			if pet_state[p.pet_name] == "resident" and _met(p.wants["resident"], counts) and gifts.size() < 12:
				var node: HedgePetNode = _node(p)
				if node.visible:
					_drop_gift(node)
	_contra_check -= delta
	if _contra_check <= 0.0:
		_contra_check = 60.0
		_tend_contraband()
	_beat -= delta
	if _beat <= 0.0:                                     # what the garden's like, now and then; and send what's queued
		_beat = 20.0
		_beats += 1
		if _beats % 3 == 0:
			Telemetry.event("beat", {"coins": coins, "tool": tool, "plants": plants.size(), "room": capacity(),
				"here": pet_state.values().filter(func(s) -> bool: return s != "away").size()})
		Telemetry.flush()
	_save -= delta
	if _save <= 0.0:
		_save = 8.0
		save()



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
				if guests < capacity() and _notice_wait <= 0.0 and _met(p.wants["notice"], counts) and grows_for(p):
					guests += 1
					_notice_wait = notice_gap()
					next = "noticed"
					_choose_variant(p)
			"noticed":
				if _met(p.wants["visit"], counts):
					next = "visiting"
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


var pet_flowers := {}               # pet name -> [[region, x, y, z], ...]: single flowers it has sprouted (saved)


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


## The pet's node in the garden, grown in whatever plant you last regrafted it in.
func _node(p: CharacterArtProfile) -> HedgePetNode:
	var fresh: bool = not garden._nodes.has(p.pet_name)
	var node: HedgePetNode = garden.node_for(p)
	if fresh and pet_flowers.has(p.pet_name):
		for f in pet_flowers[p.pet_name]:
			node.extra_flowers.append([str(f[0]), Vector3(float(f[1]), float(f[2]), float(f[3]))])
			node._flower_node(str(f[0]), Vector3(float(f[1]), float(f[2]), float(f[3])))
	var want: String = pet_plant.get(p.pet_name, "")
	if want != "" and SpeciesBuilder.plant_of(node.profile) != want:
		node.set_plant(want, node.visible)
	return node


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


## The sunlit clearing: the middle of the lawn free of junk (sun-lovers want open grass to sit in).
func _clearing() -> bool:
	for t in garden.things:
		if t["junk"] and Vector2(t["at"]).distance_to(Vector2(0.0, -0.5)) < 4.0 and t["kind"] != "stick":
			return false
	return true


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


var _away_for := 0.0                # seconds since the last visit (0 on a first visit)


func _restore_gift(icon: String, at: Vector3, value: int) -> void:
	var l := Label3D.new()
	l.text = icon
	l.font_size = 64
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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
	var l := Label3D.new()
	l.text = g[0]
	l.font_size = 64
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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


# ------------------------------------------------------------------ tools
## Is there a visible, clickable piece of the HUD at this screen point? (touch input: see garden._unhandled_input)
func ui_blocks(at: Vector2) -> bool:
	var stack: Array = _ui.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			var c := n as Control
			if not c.is_visible_in_tree() or c.modulate.a < 0.05:
				continue
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(at):
				return true
		stack.append_array(n.get_children())
	return false


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
	node.rotation_degrees.y = yaw                        # every kind the same way round (it's saved, and arranged)
	garden._thing(kind, node, p2, float(BUILDS[kind]["radius"]), int(BUILDS[kind]["price"]) / 2)
	garden.things[-1]["placed"] = true
	garden.things[-1]["id"] = "placed_%d_%d" % [Time.get_ticks_usec(), randi()]
	if garden.hideouts != null and garden.hideouts.SPOTS.has(kind):
		garden.hideouts.add_spot(garden.things[-1])
	placed.append({"kind": kind, "x": p2.x, "z": p2.y, "yaw": yaw, "node": node})
	if animate:
		Telemetry.event("build", {"kind": kind})
		Motion.appear(node, Vector3.ONE)


# ------------------------------------------------------------------ friends (🐾): following, and the bucket
func node_by_name(name: String) -> HedgePetNode:
	for p: CharacterArtProfile in garden.roster:
		if p.pet_name == name:
			return _node(p)
	return null


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


# ------------------------------------------------------------------ arranging (🧺)
var _arr: Dictionary = {}             # {t, from}: the thing being moved
var _told_arrange := false


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


func _thing_at(p: Vector2):
	var best = null
	var best_d := 1e9
	for t in garden.things:
		var d: float = p.distance_to(t["at"])
		if d < maxf(float(t["radius"]), 0.7) and d < best_d:
			best = t
			best_d = d
	return best


## The hole nearest p, within reach (the 🪏 wants you right on it; sowing is more forgiving).
func _bed_at(p: Vector2, reach := 0.9):
	var best = null
	for b in seedbeds:
		if p.distance_to(b["at"]) < reach and (best == null or p.distance_to(b["at"]) < p.distance_to(best["at"])):
			best = b
	return best


func _plant_at(p: Vector2):
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


func dirt_at(p: Vector2):
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


## What a plant looks like, said plainly: tall or short, in flower or not, and the colour when it's unexpected.
func _plant_line(pl: Dictionary) -> String:
	var name: String = SpeciesBuilder.PLANT_NAMES.get(pl["species"], pl["species"])
	var stage: int = pl["stage"]
	var g: String = pl["genes"]
	var line := ""
	match stage:
		0:
			line = "Something's just come up here on its own." if pl["origin"] == "volunteer" else "A seedbed, freshly sown with %s." % name
			return line
		1:
			line = "A %s sprout." % name
		2:
			line = "A %s %s." % ["short" if Heredity.short(g) else "tall", name]
		_:
			line = "A %s %s, in flower" % ["short" if Heredity.short(g) else "tall", name]
			line += " - white ones." if Heredity.pale(g) and Heredity.shows_colour(pl["species"]) else "."
	if pl["origin"] == "volunteer":
		line += " It came up on its own."
	elif pl["origin"] == "nursery":
		line += " From the nursery's seed."
	return line


# ------------------------------------------------------------------ words
func _thing_name(kind: String) -> String:
	return {"lawn_chair": "lawn chair", "grill": "rusty grill", "sprinkler": "broken sprinkler", "tire": "old tire",
		"pot": "flowerpot", "wheelbarrow": "wheelbarrow", "bucket": "paint bucket", "planter": "big pot", "well": "old well",
		"burrow": "burrow", "woodpile": "woodpile", "brush_pile": "brush pile", "chair": "lawn chair", "barrel": "trash barrel", "branch": "branch", "stick": "stick", "rock": "rock", "leaf_pile": "leaf pile"}.get(kind, kind)


func _thing_line(t: Dictionary) -> String:
	return {"lawn_chair": "A tipped-over lawn chair. Cosy underneath, if you're small.",
		"grill": "A rusty grill. Nobody's cooked on it in years.",
		"sprinkler": "The sprinkler's broken - it just leaks. There's a nice puddle, though. Hold ✋ on it to fix it." if not t.get("fixed", false) else "💦 The sprinkler. Every minute it sweeps about and waters the plants it reaches.",
		"tire": "An old tire. Why is there always an old tire?",
		"pot": "A tipped flowerpot. The soil's all over the place.",
		"branch": "A fallen branch.", "stick": "A stick. Somebody might want this.",
		"rock": "A sun-warmed rock.", "leaf_pile": "A pile of old leaves, raked and forgotten."}.get(t["kind"], "Something in the grass.")


func _pet_line(pet: HedgePetNode) -> String:
	var p: CharacterArtProfile = pet.profile
	var who := "%s the %s" % [p.pet_name, SpeciesBuilder.variant_name(p)]
	match pet_state[p.pet_name]:
		"resident":
			return "%s lives here. %s" % [who, "Happy as anything." if _met(p.wants["resident"], garden_counts()) else "Something's missing: " + p.hints["resident"]]
		"visiting":
			return "%s is visiting. %s" % [who, p.hints["resident"]]
		_:
			return "%s is peeking in. %s" % [who, p.hints["visit"]]


# ------------------------------------------------------------------ ui
const TOAST_AT := Vector2(90, 140)
const SEEDS_AT := Vector2(44, 1460)
const JOURNAL_AT := Vector2(90, 260)
var _shown_coins := -1
var _seeds_shown := false
var _journal_open := false


## A message: slides in, stays a few seconds, fades. A new one replaces it smoothly.
func toast(text: String) -> void:
	Telemetry.event("say", {"t": text.left(100)})
	if _toast.visible and _toast.modulate.a > 0.05 and _toast.text != "":   # one is showing: let it go first
		var t := Motion.channel(_toast, "fade")
		t.tween_property(_toast, "modulate:a", 0.0, Motion._d(Motion.FAST * 0.8))
		t.tween_callback(func() -> void: _show_toast(text))
	else:
		_show_toast(text)


func _show_toast(text: String) -> void:
	_toast.text = text
	Motion.slide_in(_toast, TOAST_AT, Vector2(0, -18))
	var t := Motion.channel(_toast, "hold")
	t.tween_interval(Motion._d(3.4))
	t.tween_property(_toast, "modulate:a", 0.0, Motion._d(Motion.SLOW))


## Bring the HUD to the current state, every change eased (scripts/anim/motion.gd).
func _refresh() -> void:
	if _shown_coins < 0:
		_shown_coins = coins
		_coin_label.text = "🪙 %d" % coins
	elif coins != _shown_coins:
		Motion.count(_coin_label, _shown_coins, coins, func(v: int) -> void:
			_shown_coins = v
			_coin_label.text = "🪙 %d" % v)
		Motion.pulse(_coin_label, 1.25 if coins > _shown_coins else 0.9)
	for t in _tool_buttons:
		var b: Button = _tool_buttons[t]
		Motion.channel(b, "fade").tween_property(b, "modulate:a", 1.0 if t == tool else 0.5, Motion._d(Motion.FAST))
		Motion.scale_to(b, 1.15 if t == tool else 0.92)
	_show_tool()
	var want_seeds := tool == "seeds" or tool == "shears"
	if want_seeds != _seeds_shown:
		_seeds_shown = want_seeds
		if want_seeds:
			Motion.slide_in(_seed_row, SEEDS_AT, Vector2(0, 26))
		else:
			Motion.fade(_seed_row, 0.0, Motion.FAST)
	var want_builds := tool == "build"
	if want_builds != _builds_shown:
		_builds_shown = want_builds
		if want_builds:
			Motion.slide_in(_build_row, BUILD_AT, Vector2(0, 26))
		else:
			Motion.fade(_build_row, 0.0, Motion.FAST)
	_bucket_badge.visible = carried != ""
	_bucket_badge.text = "🪣 You're carrying %s in the bucket. ✋ tap the lawn to set it down." % carried
	for b in _build_row.get_children():
		Motion.channel(b, "fade").tween_property(b, "modulate:a", 1.0 if b.name == build_choice else 0.55, Motion._d(Motion.FAST))
		Motion.scale_to(b, 1.08 if b.name == build_choice else 1.0)
	for b in _seed_row.get_children():
		Motion.channel(b, "fade").tween_property(b, "modulate:a", 1.0 if b.name == seed_choice else 0.55, Motion._d(Motion.FAST))
		Motion.scale_to(b, 1.08 if b.name == seed_choice else 1.0)
	if _journal_open:
		_fill_journal()


const TOOL_WORDS := {
	"hand": "✋ Hand - tap to look and pet · hold on junk to yank and haul it · hold on broken things to mend them",
	"shovel": "🪏 Shovel - dig (beside a hole: a row) · scoop dirt · fill a hole · dig up what you sowed",
	"seeds": "🌱 Seeds - pick a plant, then tap a hole to sow it",
	"shears": "✂️ Shears - pick a plant, then tap a pet to regraft it",
	"build": "🧺 Build - pick a thing, tap the lawn · drag one to move it · tap it to turn it",
	"water": "💧 Watering can - hold and drag to pour · hedgepets love water and follow it",
}
var _puck: Panel
var _caption: Label
var _shown_tool := ""


## The chip glides behind the tool in your hand; the caption says what it does.
func _show_tool() -> void:
	var b: Button = _tool_buttons.get(tool)
	if b == null or _puck == null:
		return
	var goal := b.global_position + b.size * 0.5 - _puck.size * 0.5
	if _shown_tool == "":
		_puck.position = goal
	else:
		Motion.channel(_puck, "move").tween_property(_puck, "position", goal, Motion._d(Motion.BASE)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _shown_tool != tool:
		_shown_tool = tool
		_caption.text = TOOL_WORDS.get(tool, "")
		Motion.slide_in(_caption, Vector2(40, 1672), Vector2(0, 14))


func _fill_journal() -> void:
	var lines := "[b]Journal[/b]\n\n"
	var counts := garden_counts()
	var unseen: Array = []
	for p: CharacterArtProfile in garden.roster:
		var state: String = pet_state[p.pet_name]
		if state == "away":
			unseen.append(p)
			continue
		var label: String = {"away": "not seen yet", "noticed": "peeking in", "visiting": "visiting", "resident": "lives here"}[state]
		var step: String = {"away": "notice", "noticed": "visit", "visiting": "resident", "resident": "resident"}[state]
		var hint: String = p.hints[step] if state != "away" or cleared > 0 else "???"
		if state == "away" and not _met(p.wants["notice"], counts):
			hint = p.hints["notice"]
		var seen: Array = discovered.get(p.pet_name, [])
		var vs: Array = seen.map(func(v) -> String: return SpeciesBuilder.variant_name(p, v))
		var seen_as := ("\n[color=#7a6a50]seen as %s[/color]" % ", ".join(vs)) if vs.size() > 1 else ""
		if is_contraband(p.pet_name):
			hint = "It wants sun. Lots of sun. Preferably where nobody can see it."
		lines += "[b]%s[/b] the %s - %s\n%s%s\n\n" % [p.pet_name, SpeciesBuilder.variant_name(p, pet_plant.get(p.pet_name, "")), label, hint, seen_as]
	# rumours: a few of the ones you haven't met, the nearest to noticing first
	lines += "[b]Around the neighbourhood[/b]\n\n"
	unseen.sort_custom(func(a, b) -> bool: return _missing(a.wants["notice"], counts) < _missing(b.wants["notice"], counts))
	for p: CharacterArtProfile in unseen.slice(0, 4):
		var vs: Array = SpeciesBuilder.variants_of(p).map(func(v) -> String: return SpeciesBuilder.PLANT_NAMES.get(v, v))
		lines += "🐾 %s [color=#7a6a50]Seen near gardens growing %s.[/color]\n\n" % [p.hints["notice"], " or ".join(vs.slice(0, 2)) if vs.size() <= 2 else ", ".join(vs.slice(0, vs.size() - 1)) + " or " + vs[vs.size() - 1]]
	lines += "[color=#7a6a50]Room here for %d at once.[/color]\n" % capacity()
	lines += "\n[url=howto]❓ How to play[/url]     [url=feedback]💬 Tell us what you think[/url]\n"
	_journal_text.text = lines


func _missing(wants: Dictionary, counts: Dictionary) -> int:
	var n := 0
	for k in wants:
		n += maxi(0, int(wants[k]) - int(counts.get(k, 0)))
	return n


func _button(text: String, tip: String, size := 64) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.flat = true
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(120, 110)
	return b


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	_ui.name = "GameUI"
	garden.add_child(_ui)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.9, 0.85)
	style.set_corner_radius_all(28)
	style.set_content_margin_all(12)
	# top: coins and the journal
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 44)
	_coin_label.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
	_coin_label.position = Vector2(40, 30)
	_ui.add_child(_coin_label)
	var jb := _button("📖", "Journal: who might come, and what they like", 52)
	jb.position = Vector2(930, 10)
	jb.pressed.connect(func() -> void:
		_journal_open = not _journal_open
		if _journal_open:
			Telemetry.event("journal")
			_fill_journal()
			Motion.slide_in(_journal, JOURNAL_AT, Vector2(0, 40))
		else:
			Motion.fade(_journal, 0.0, Motion.FAST)
		_refresh())
	_ui.add_child(jb)
	var db := _button("🕳️", "The burrow: where the pets who live here nap", 52)
	db.position = Vector2(800, 10)
	db.pressed.connect(func() -> void: garden.den.enter())
	_ui.add_child(db)
	# a message line
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_color", Color(0.25, 0.2, 0.14))
	_toast.add_theme_stylebox_override("normal", style)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(90, 140)
	_toast.size = Vector2(900, 0)
	_ui.add_child(_toast)
	# bottom: tools
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.position = Vector2(60, 1770)
	bar.size = Vector2(960, 120)
	bar.add_theme_constant_override("separation", 14)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(50, 1760)
	panel.size = Vector2(980, 130)
	_ui.add_child(panel)
	panel.add_child(bar)
	for t: Array in [["hand", "✋", "Hand: tap to pet and look; press and drag junk to yank it loose and haul it"], ["shovel", "🪏", "Shovel: dig a seedbed, scoop up a leaf pile or something you built"],
			["seeds", "🌱", "Seeds: plant in a seedbed"], ["shears", "✂️", "Shears: regraft a pet in the chosen plant"], ["build", "🧺", "Build: put a feeder, bath, scarecrow... in the garden; drag one you built to move it, tap it to turn it"], ["water", "💧", "Watering can: hold and drag to pour"]]:
		var b := _button(t[1], t[2])
		var key: String = t[0]
		b.pressed.connect(func() -> void:
			tool = key
			Telemetry.event("tool", {"tool": key})
			if key == "build" and not _told_arrange:
				_told_arrange = true
				toast("Tap the lawn to put one down. Drag one you built to move it; tap it to turn it.")
			_refresh())
		bar.add_child(b)
		_tool_buttons[key] = b
	# which tool is in your hand: a bright rounded chip behind it that glides to the chosen one, and its name and
	# what it does just above the bar
	_puck = Panel.new()
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.36, 0.52, 0.3, 0.95)
	chip.set_corner_radius_all(30)
	chip.border_color = Color(0.98, 0.94, 0.8)
	chip.set_border_width_all(4)
	_puck.add_theme_stylebox_override("panel", chip)
	_puck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_puck.size = Vector2(128, 118)
	_ui.add_child(_puck)
	_ui.move_child(_puck, panel.get_index() + 1)
	_ui.move_child(panel, _puck.get_index())
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	_caption.add_theme_color_override("font_outline_color", Color(0.12, 0.1, 0.07, 0.75))
	_caption.add_theme_constant_override("outline_size", 9)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.position = Vector2(40, 1672)
	_caption.size = Vector2(1000, 80)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_caption)
	_seed_row = GridContainer.new()
	_seed_row.columns = 8
	_seed_row.position = SEEDS_AT
	_seed_row.add_theme_constant_override("h_separation", 8)
	_seed_row.add_theme_constant_override("v_separation", 6)
	for sp in SEEDS:
		var b := _button("%s%d" % [SEEDS[sp]["icon"], SEEDS[sp]["price"]], "%s seeds" % sp, 32)
		b.name = sp
		b.custom_minimum_size = Vector2(116, 90)
		b.pressed.connect(func() -> void:
			seed_choice = sp
			var kept := keep_seeds.filter(func(k) -> bool: return k["species"] == sp).size()
			toast("%s %s seeds (🪙 %d)%s. Tap a hole to sow." % [SEEDS[sp]["icon"], SpeciesBuilder.PLANT_NAMES.get(sp, sp), SEEDS[sp]["price"], (" - you have %d of your own, free" % kept) if kept > 0 else ""])
			_refresh())
		_seed_row.add_child(b)
	_seed_row.visible = false
	_ui.add_child(_seed_row)
	_build_row = GridContainer.new()
	_build_row.columns = 7
	_build_row.position = BUILD_AT
	_build_row.add_theme_constant_override("h_separation", 8)
	_build_row.add_theme_constant_override("v_separation", 6)
	for kind in BUILDS:
		var item: Dictionary = BUILDS[kind]
		var b := _button("%s%d" % [item["icon"], item["price"]], "%s (🪙 %d)" % [item["name"], item["price"]], 34)
		b.name = kind
		b.custom_minimum_size = Vector2(136, 90)
		b.pressed.connect(func() -> void:
			build_choice = kind
			toast("%s A %s (🪙 %d). Tap the lawn to put it down." % [item["icon"], item["name"], item["price"]])
			_refresh())
		_build_row.add_child(b)
	_build_row.visible = false
	_ui.add_child(_build_row)
	_bucket_badge = Label.new()
	_bucket_badge.add_theme_font_size_override("font_size", 32)
	_bucket_badge.add_theme_color_override("font_color", Color(0.3, 0.24, 0.16))
	_bucket_badge.position = Vector2(40, 90)
	_bucket_badge.visible = false
	_ui.add_child(_bucket_badge)
	_journal = PanelContainer.new()
	_journal.add_theme_stylebox_override("panel", style)
	_journal.position = Vector2(90, 260)
	_journal.size = Vector2(900, 1100)
	_journal.visible = false
	_journal_text = RichTextLabel.new()
	_journal_text.bbcode_enabled = true
	_journal_text.add_theme_font_size_override("normal_font_size", 30)
	_journal_text.add_theme_font_size_override("bold_font_size", 34)
	_journal_text.add_theme_color_override("default_color", Color(0.25, 0.2, 0.14))
	_journal_text.custom_minimum_size = Vector2(860, 1060)
	_journal_text.meta_clicked.connect(func(meta) -> void:
		if str(meta) in ["feedback", "howto"]:          # the survey / the guide, on their own pages (a new tab on the web)
			Telemetry.event("open_" + str(meta))
			OS.shell_open("https://go.fridge.run/hedgepets/" + str(meta)))
	_journal.add_child(_journal_text)
	_ui.add_child(_journal)


func set_ui_visible(on: bool) -> void:
	_ui.visible = on


# ------------------------------------------------------------------ save
func save() -> void:
	if OS.get_environment("HEDGEPETS_FRESH") != "":
		return                                           # captures and checks never touch the player's garden
	var data := {"coins": coins, "cleared": cleared, "gone": [], "beds": [], "pets": pet_state, "plants": pet_plant,
		"moved": _moved_state(),
		"mended": {"fence": range(garden.fence_sections.size()).filter(func(i) -> bool: return garden.fence_sections[i]["mended"]),
			"sprinkler": garden.things.any(func(t) -> bool: return t["kind"] == "sprinkler" and t.get("fixed", false))},
		"gifts": gifts.map(func(g) -> Dictionary: return {"x": g["at"].x, "z": g["at"].z, "icon": g["node"].text, "value": g["value"]}),
		"flowers": pet_flowers,
		"last_visit": Time.get_unix_time_from_system(),
		"barrel": {"contents": grab.contents, "next_pickup": grab.next_pickup},
		"following": following, "carried": carried, "nursery": nursery, "keep_seeds": keep_seeds, "woods_finds": woods_finds, "contraband": contraband,
		"dirt": dirt_piles.map(func(d) -> Array: return [d["at"].x, d["at"].y, d["loads"]]), "shovelful": shovelful,
		"barrow": {"x": barrow["node"].position.x, "z": barrow["node"].position.z, "load": int(barrow.get("load", 0))} if barrow.has("node") else {},
		"discovered": discovered, "placed": placed.map(func(b) -> Dictionary: return {"kind": b["kind"], "x": b["node"].position.x, "z": b["node"].position.z, "yaw": b["node"].rotation_degrees.y})}
	var present := {}
	for t in garden.things:
		present[t["id"]] = true
	for id in _all_ids:
		if not present.has(id):
			data["gone"].append(id)
	for b in seedbeds:
		var pl = b["plant"]
		data["beds"].append({"x": b["at"].x, "z": b["at"].y, "plant": null if pl == null else {"species": pl["species"], "stage": pl["stage"], "water": pl["water"], "progress": pl["progress"],
			"genes": pl["genes"], "origin": pl["origin"]}})
	var text := JSON.stringify(data)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	WebSave.put(save_path, text)                          # the browser's copy, written at once (web only)


## Leaving (tab hidden, app sent to the background, window closed): save right then, not up to 8 s later.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if garden != null and is_instance_valid(garden) and _loaded:
			save()
			Telemetry.event("hidden")
			Telemetry.flush()


var _all_ids: Array = []
var _loaded := false               # saving before the old save was read would overwrite it


## Things you've worked on (moved, yanked loose, righted, scrubbed): saved by id.
func _moved_state() -> Dictionary:
	var out := {}
	for t in garden.things:
		if t.has("lb") and (t.get("moved", false) or float(t.get("stuck", 1.0)) <= 0.0 or float(t.get("scrub", 0.0)) > 0.0 or not t.get("tipped", true)) and not t.get("placed", false):
			out[t["id"]] = {"x": t["node"].position.x, "z": t["node"].position.z, "stuck": t["stuck"], "tipped": t.get("tipped", false), "scrub": t.get("scrub", 0.0)}
	return out


func _load() -> void:
	for t in garden.things:
		_all_ids.append(t["id"])
	_loaded = true
	var text := WebSave.newest(save_path)
	if text == "" or OS.get_environment("HEDGEPETS_FRESH") != "":
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = int(data.get("coins", coins))
	cleared = int(data.get("cleared", 0))
	var gone: Array = data.get("gone", [])
	for t in garden.things.duplicate():
		if gone.has(t["id"]):
			garden.things.erase(t)
			t["node"].queue_free()
	for b in data.get("beds", []):
		var bed := _dig(Vector2(float(b["x"]), float(b["z"])))
		var pl = b.get("plant")
		if pl != null:
			_plant(str(pl["species"]), bed, int(pl["stage"]), float(pl["water"]), float(pl["progress"]), str(pl.get("genes", Heredity.STOCK)), str(pl.get("origin", "seed")))
	pet_flowers = data.get("flowers", {})
	for g in data.get("gifts", []):
		_restore_gift(str(g["icon"]), Vector3(float(g["x"]), 0, float(g["z"])), int(g["value"]))
	_away_for = Time.get_unix_time_from_system() - float(data.get("last_visit", Time.get_unix_time_from_system()))
	var mended: Dictionary = data.get("mended", {})
	for i in mended.get("fence", []):
		garden.mend_fence(int(i), true)
	if mended.get("sprinkler", false):
		for t in garden.things:
			if t["kind"] == "sprinkler":
				grab.fix_sprinkler(t, true)
	var bin: Dictionary = data.get("barrel", {})
	grab.contents = bin.get("contents", [])
	grab.next_pickup = float(bin.get("next_pickup", 0.0))
	if not grab.contents.is_empty() and grab.next_pickup > 0.0 and Time.get_unix_time_from_system() >= grab.next_pickup:
		grab._pickup(true)                              # the truck came while you were away
	grab._show_fill()
	var moved: Dictionary = data.get("moved", {})
	for t in garden.things:
		if moved.has(t["id"]):
			grab.grabbable(t)
			var m: Dictionary = moved[t["id"]]
			var node: Node3D = t["node"]
			node.position = Vector3(float(m["x"]), 0, float(m["z"]))
			t["at"] = Vector2(node.position.x, node.position.z) + t.get("offset", Vector2.ZERO)
			t["stuck"] = float(m.get("stuck", 0.0))
			t["moved"] = true
			if not m.get("tipped", true) and t.get("tipped", false):
				grab.set_chair_upright(t)
			if m.has("scrub"):
				t["scrub"] = float(m["scrub"])
				t["rusty"] = t["scrub"] < 1.0
				grab.set_rust(t, clampf(t["scrub"], 0.0, 1.0))
	pet_plant = data.get("plants", {})
	discovered = data.get("discovered", {})
	for b in data.get("placed", []):
		_place(str(b["kind"]), Vector2(float(b["x"]), float(b["z"])), float(b["yaw"]), false)
	following = (data.get("following", []) as Array).filter(func(n) -> bool: return n is String)
	carried = str(data.get("carried", ""))
	var ns = data.get("nursery", {})
	if ns is Dictionary:
		for k in ns:
			nursery[k] = ns[k]
	var wf = data.get("woods_finds", {})
	if wf is Dictionary:
		woods_finds["taken"] = wf.get("taken", {}) if wf.get("taken", {}) is Dictionary else {}
		woods_finds["basket"] = wf.get("basket", {}) if wf.get("basket", {}) is Dictionary else {}
	for d in data.get("dirt", []):
		if d is Array and d.size() == 3:
			var pile := {"at": Vector2(float(d[0]), float(d[1])), "loads": int(d[2]), "node": null}
			dirt_piles.append(pile)
			_dirt_look(pile)
	shovelful = bool(data.get("shovelful", false))
	if data.get("contraband", {}) is Dictionary:
		contraband = data.get("contraband", {})
	var bw = data.get("barrow", {})
	if bw is Dictionary and bw.has("x") and barrow.has("node"):
		barrow["node"].position = Vector3(float(bw["x"]), 0, float(bw["z"]))
		barrow["at"] = Vector2(float(bw["x"]), float(bw["z"]))
		grab.barrow_load(barrow, int(bw.get("load", 0)))
	keep_seeds = (data.get("keep_seeds", []) as Array).filter(func(k) -> bool: return k is Dictionary and SEEDS.has(str(k.get("species", ""))))
	var saved: Dictionary = data.get("pets", {})
	for name in saved:
		if pet_state.has(name):
			pet_state[name] = saved[name]

