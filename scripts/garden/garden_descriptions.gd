extends RefCounted

## Descriptions only. No game state, scene nodes, input, or save dependencies.
## Pure helpers extracted from GardenGame; keep output byte-for-byte compatible.

## What a plant looks like, said plainly: tall or short, in flower or not, and the colour when it's unexpected.
static func plant_line(pl: Dictionary) -> String:
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
static func thing_name(kind: String) -> String:
	return {"lawn_chair": "lawn chair", "grill": "rusty grill", "sprinkler": "broken sprinkler", "tire": "old tire",
		"pot": "flowerpot", "wheelbarrow": "wheelbarrow", "bucket": "paint bucket", "planter": "big pot", "well": "old well",
		"burrow": "burrow", "woodpile": "woodpile", "brush_pile": "brush pile", "chair": "lawn chair", "barrel": "trash barrel", "branch": "branch", "stick": "stick", "rock": "rock", "leaf_pile": "leaf pile"}.get(kind, kind)


static func thing_line(t: Dictionary) -> String:
	return {"lawn_chair": "A tipped-over lawn chair. Cosy underneath, if you're small.",
		"grill": "A rusty grill. Nobody's cooked on it in years.",
		"sprinkler": "The sprinkler's broken - it just leaks. There's a nice puddle, though. Hold ✋ on it to fix it." if not t.get("fixed", false) else "💦 The sprinkler. Every minute it sweeps about and waters the plants it reaches.",
		"tire": "An old tire. Why is there always an old tire?",
		"pot": "A tipped flowerpot. The soil's all over the place.",
		"branch": "A fallen branch.", "stick": "A stick. Somebody might want this.",
		"rock": "A sun-warmed rock.", "leaf_pile": "A pile of old leaves, raked and forgotten."}.get(t["kind"], "Something in the grass.")
