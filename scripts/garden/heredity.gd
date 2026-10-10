class_name Heredity
extends RefCounted

## Every plant you grow carries two small things from the plants it came from: whether its flowers have colour, and
## whether it grows tall. Each comes as a pair of letters, one from each parent plant. One capital is enough (a "C"
## gives coloured flowers, a "T" a tall plant), so a pale or a short plant has to get the small letter from both sides.
## Packets bought for the 🌱 tool are all STOCK. Self-sown seedlings (garden_game._self_sow) take one letter of each
## pair from each parent: the flowering plant beside the empty bed, and any flowering plant of the same kind (the bees
## carry it), which can be the same plant. The letters are never shown: you only ever see the plants.

const STOCK := "CCTT"
const PALE_BLOOM := Color("f6f2e8")
const SHORT := 0.66                       # a short plant's size, of a tall one's


static func valid(g: Variant) -> String:
	var s := str(g) if g != null else ""
	if s.length() != 4 or not s.to_upper() == "CCTT":
		return STOCK
	return s


## A seedling of two plants: one letter of each pair from each.
static func cross(a: String, b: String, rng: RandomNumberGenerator) -> String:
	var out := ""
	for locus: int in [0, 2]:
		var x := a[locus + rng.randi_range(0, 1)]
		var y := b[locus + rng.randi_range(0, 1)]
		out += x + y if x <= y else y + x         # capitals first: "Cc", never "cC"
	return out


static func pale(g: String) -> bool:
	return g.substr(0, 2) == "cc"


static func short(g: String) -> bool:
	return g.substr(2, 2) == "tt"


## The bloom a plant shows: its kind's own colour, or nearly white.
static func bloom(species: String, g: String) -> Color:
	var own := Color(SpeciesBuilder.PLANTS[species][1])
	return PALE_BLOOM if pale(g) else own


## Whether a pale bloom would look any different from this plant's own (white jasmine stays white).
static func shows_colour(species: String) -> bool:
	var own := Color(SpeciesBuilder.PLANTS[species][1])
	return own.s > 0.25
