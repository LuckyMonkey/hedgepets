extends Node

## Game 1/7 - the state: what the player has (coins, plants, builds, pets met, followers), tuning constants, and telling the player things (toast, descriptions).
##
## Everything the save holds is declared here, so one file answers "what does the player have?". The constants
## (SEEDS, BUILDS, OFFERINGS and the timings) are the game's tuning. toast() is the one way to tell the player
## something; the description helpers word what a tap on a plant, thing or pet says. _refresh() (redraw the HUD) is
## declared here so every layer can call it; game_ui.gd fills it in.
##
## Part of the garden game layer chain (the full order is at the top of scripts/garden/garden_game.gd). Code here was moved verbatim
## from the old single file; only its place changed.


## Declared here so every layer can call it; the real body is in game_ui.gd.
func _refresh() -> void:
	pass

const GardenDescriptions = preload("res://scripts/garden/garden_descriptions.gd")

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
	"aster": {"icon": "💮", "price": 5, "sheet": "hedgeaster"},      # calico aster: the bees' late flowers
}
## Foraged things can be set out in a small shared dish. The item is consumed from the woods basket;
## the dish itself is a normal placed thing, so it counts for appeal and is saved with the garden.
const OFFERINGS := {
	"offering_cone": {"icon": "🌲", "find": "cone", "name": "pine cone dish", "radius": 0.42},
	"offering_acorn": {"icon": "🌰", "find": "acorn", "name": "acorn dish", "radius": 0.42},
	"offering_feather": {"icon": "🪶", "find": "feather", "name": "feather dish", "radius": 0.42},
	"offering_apple": {"icon": "🍎", "find": "apple", "name": "apple dish", "radius": 0.48},
}
var garden: Node3D
var cleared := 0
var plants: Array = []             # {species, at, stage, water, progress, node, bed}
var pet_plant := {}                # pet name -> the plant it was regrafted in with ✂️ (SpeciesBuilder.PLANTS)
var pet_state := {}                # pet name -> "away" | "noticed" | "visiting" | "resident"
var _toast: Label
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
	for offering: String in OFFERINGS:
		c[offering] = garden.count(offering)
		c[OFFERINGS[offering]["find"]] = garden.count(offering)
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


var pet_flowers := {}               # pet name -> [[region, x, y, z], ...]: single flowers it has sprouted (saved)


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


## The sunlit clearing: the middle of the lawn free of junk (sun-lovers want open grass to sit in).
func _clearing() -> bool:
	for t in garden.things:
		if t["junk"] and Vector2(t["at"]).distance_to(Vector2(0.0, -0.5)) < 4.0 and t["kind"] != "stick":
			return false
	return true


# ------------------------------------------------------------------ friends (🐾): following, and the bucket
func node_by_name(name: String) -> HedgePetNode:
	for p: CharacterArtProfile in garden.roster:
		if p.pet_name == name:
			return _node(p)
	return null


## Stable entrypoints: callers and checks may still use these names.
func _plant_line(pl: Dictionary) -> String:
	return GardenDescriptions.plant_line(pl)


func _thing_name(kind: String) -> String:
	return GardenDescriptions.thing_name(kind)


func _thing_line(t: Dictionary) -> String:
	return GardenDescriptions.thing_line(t)


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
