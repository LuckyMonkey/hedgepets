class_name SpeciesBuilder
extends RefCounted

## HedgePets from a few lines of data (res://pets/species.json), on the same renderer as the hand-made profiles in
## character_art_profile.gd. A species is a body PLAN plus a PLANT, a PALETTE and PARTS:
##
##   plan     quadruped | sitter | bird | round | long | snail
##   plant    the leaf sheet (ivy clover fern jasmine oak pine sage maple boxwood willow rose lavender)
##   palette  a name from PALETTES (the leaves); skin / skin2 / dark / beak: the ceramic parts (hex)
##   size     overall scale (1 = Gerald-ish); leg (leg length, 0 = little nubs); neck; head (head scale); eyes
##   body     [x, y, z] body stretch
##   ears     round pointy long floppy big mouse tufts nubs biground none
##   snout    short long flat beak bill trunk bignose star none
##   tail     bushy thin cotton paddle curly short fan ringed tuft taper none   (+ "tip": true for a pale tip)
##   extras   mane wings horns antlers antennae eyepatch mask belly stripes hands blaze cap bib crest wattle ring
##            facedisc
##   bloom    hex for the cell-13 bloom; flowering 0..1
##   wants / hints   garden wishes (see garden_game.gd) and the journal's words for them
##
## Built in creature space: x forward, y up, z to the side. Head parts are in head units (h = head radius).

const PALETTES := {
	"green": ["2f4a2a", "4a6b36", "6e8c42", "889a44", "72886a", "b9c58a", "34502a"],
	"spring": ["2e5a2a", "4a8a3a", "6eae4a", "9cc25a", "7a9e6a", "c8e08e", "345a2c"],
	"hemp": ["2a5420", "468a2e", "68ae3c", "92c84e", "70a05a", "c6e486", "2a4c20"],
	"autumn": ["6b3d1f", "9a5426", "b8702e", "c9923c", "8a6a3a", "e0b25a", "5a3418"],
	"crimson": ["6a2420", "9a3428", "c0482e", "d07038", "8a4a3a", "e89a5a", "5a2018"],
	"silver": ["46574a", "66786a", "869684", "9aa58e", "a7b3a6", "cfd6c8", "4a5a4c"],
	"pine": ["1f3b30", "2e5240", "456b4c", "5f7d4e", "5e7a6c", "93ab8c", "223a2c"],
	"golden": ["6a5a24", "8f7a2e", "b29a3e", "c8b452", "9a9060", "e6d68a", "5a4a20"],
	"blossom": ["7a3a4a", "a85a6a", "d07e8a", "e8a0a0", "b88a90", "f4c8c8", "6a3040"],
	"lavender": ["4a4466", "6a6288", "8a82a8", "a8a0c0", "8c8ca0", "d0c8e0", "3e3a58"],
	"snow": ["a8b0a0", "c2c8b8", "d8dccf", "e6e6d8", "c8ccc0", "f6f6ee", "9aa092"],
	"dark": ["2a3a32", "3a4e44", "4e6656", "66806a", "58706a", "90a894", "24302a"],
	"bark": ["4e3e2a", "6e5a3e", "8e7650", "a8925e", "827a62", "c8b88a", "3e3222"],
	"blue": ["24365a", "34507a", "4a6c98", "6a88b0", "6a7a90", "a8c0dc", "1e2c48"],
	"moss": ["2e4a1e", "4a6e26", "6e9430", "8eac3a", "6a8a4a", "c4d870", "2e4418"],
	"holly": ["14301e", "1e4228", "2a5a34", "3e7040", "3a5a44", "7aa070", "142a1a"],
	"bostonivy": ["5a2a20", "8a3a28", "a8502e", "6e7a3a", "7a5a3a", "d08a50", "4a2418"],
	"creeper": ["5a1820", "8a2430", "b03838", "c85a3a", "7a3a3a", "e0806a", "4a1418"],
	"frost": ["2e4a2a", "4a6a3a", "6a8a4a", "8aa05a", "7a907a", "dcd8b0", "34502a"],
	"gold": ["4a5a22", "6e7e2a", "94a434", "c2c044", "8a9a52", "e8dc78", "3e4a1c"],
	"glossy": ["17331d", "1f4426", "2e5e32", "467a3a", "3e6448", "88ac74", "152a18"],
}
## Every plant a pet can be made of (a leaf sheet baked from a font or drawn by tools/make_leaf_styles.py), with the
## look it brings: its palette, the colour of its bloom (cell 13) and how much it blooms.
const PLANTS := {
	"ivy": ["green", "fffaf0", 0.35], "clover": ["spring", "fffaf0", 0.3], "fern": ["green", "fffaf0", 0.15],
	"jasmine": ["green", "fffaf0", 0.7], "oak": ["autumn", "a8743a", 0.5], "pine": ["pine", "8a5a34", 0.25],
	"sage": ["silver", "c8b4e6", 0.3], "maple": ["crimson", "b0502a", 0.3], "boxwood": ["green", "f6f0e0", 0.2],
	"willow": ["spring", "e6e0b0", 0.3], "rose": ["green", "e86a7a", 0.6], "lavender": ["lavender", "9a7ad0", 0.7],
	"moss": ["moss", "c86a3a", 0.5], "holly": ["holly", "d42a2a", 0.6],
	"bostonivy": ["bostonivy", "2a3050", 0.3], "creeper": ["creeper", "2a2a48", 0.35], "variegated": ["frost", "f4f0d8", 0.3],
	"needlepoint": ["green", "c8d070", 0.3], "heartivy": ["spring", "c8d070", 0.3], "persianivy": ["glossy", "c8d070", 0.25],
	"goldchild": ["gold", "d8d070", 0.3], "fig": ["spring", "b8c860", 0.2],
	"cannabis": ["hemp", "e8ecc8", 0.3],                  # never sold; see garden_game "contraband"
}

## How many leaves a plant needs to cover a body: broad ivy covers with few, willow and lavender need twice as many.
const LEAF_FULLNESS := {"ivy": 1.0, "bostonivy": 1.0, "creeper": 1.2, "variegated": 1.0, "oak": 1.2, "maple": 1.4,
	"pine": 1.8, "holly": 1.0, "boxwood": 1.3, "moss": 1.4, "jasmine": 1.2, "rose": 1.1, "lavender": 2.0, "clover": 1.2,
	"fern": 1.4, "willow": 2.0, "sage": 1.3, "needlepoint": 1.5, "heartivy": 1.0, "persianivy": 0.8, "goldchild": 1.0, "fig": 1.4, "cannabis": 1.7}


static func fullness(plant: String) -> int:
	return int(round(12.0 * float(LEAF_FULLNESS.get(plant, 1.2))))


## Variants: every pet can also come in the plants related to its own (its plant's groups), and each variant has a
## name: the plant's word + the animal ("Creeper Fox", "Mossback Turtle", "Frostleaf Beaver"). Which one turns up
## depends on what you grow (garden_game.gd).
const GROUPS := [
	["ivy", "bostonivy", "creeper", "variegated"],
	["ivy", "needlepoint", "heartivy", "goldchild"],
	["persianivy", "heartivy", "fig", "needlepoint"],
	["oak", "maple", "creeper", "bostonivy"],
	["pine", "holly", "boxwood", "moss"],
	["jasmine", "rose", "lavender", "clover"],
	["fern", "willow", "sage", "moss"],
	["clover", "fern", "boxwood", "variegated"],
]
const PREFIX := {"ivy": "Ivy", "bostonivy": "Boston", "creeper": "Creeper", "variegated": "Frostleaf", "oak": "Oakleaf",
	"maple": "Maple", "pine": "Pine", "holly": "Holly", "boxwood": "Box", "moss": "Mossback", "jasmine": "Jasmine",
	"rose": "Briar", "lavender": "Lavender", "clover": "Clover", "fern": "Fern", "willow": "Willow", "sage": "Sage",
	"needlepoint": "Needlepoint", "heartivy": "Heartleaf", "persianivy": "Persian", "goldchild": "Goldchild", "fig": "Fig", "cannabis": "Hempleaf"}
const PLANT_NAMES := {"ivy": "English ivy", "bostonivy": "Boston ivy", "creeper": "Virginia creeper",
	"variegated": "variegated ivy", "boxwood": "boxwood", "moss": "moss", "holly": "holly", "cannabis": "cannabis"}


## The plant a pet is made of by nature (its profile's own), not a regraft.
static func native_plant(p: CharacterArtProfile) -> String:
	return p.get_meta("native_plant", plant_of(p))


static func variants_of(p: CharacterArtProfile) -> Array:
	var native := native_plant(p)
	var out: Array = [native]
	for g: Array in GROUPS:
		if g.has(native):
			for plant in g:
				if not out.has(plant) and out.size() < 4:
					out.append(plant)
	return out


static func animal_noun(p: CharacterArtProfile) -> String:
	var words := p.species.split(" ")
	return words[words.size() - 1].capitalize()


static func variant_name(p: CharacterArtProfile, plant := "") -> String:
	var pl := plant if plant != "" else plant_of(p)
	return "%s %s" % [PREFIX.get(pl, pl.capitalize()), animal_noun(p)]


static func palette_of(name: String) -> Dictionary:
	var pal: Array = PALETTES[name]
	var out := {}
	for i in range(FAMILIES.size()):
		out[FAMILIES[i]] = _c(pal[i])
	return out


## The same pet grown in another plant: a copy of its profile with that plant's leaves, palette and bloom.
static func restyle(p: CharacterArtProfile, plant: String) -> CharacterArtProfile:
	var q: CharacterArtProfile = p.duplicate(true)
	q.set_meta("native_plant", native_plant(p))
	var look: Array = PLANTS[plant]
	q.leaf_sheet = "hedge" + plant
	q.palette = palette_of(look[0])
	q.inner_mass = _c(PALETTES[look[0]][6])
	q.flower_color = _c(look[1])
	q.flowering = float(look[2])
	q.leaves_per_cluster = fullness(plant)
	return q


static func plant_of(p: CharacterArtProfile) -> String:
	return p.leaf_sheet.trim_prefix("hedge")
const FAMILIES := ["deep_forest", "muted_ivy", "matcha", "warm_yellow_green", "soft_sage", "pale_highlight"]


static func load_all(path := "res://pets/species.json") -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Array = []
	for spec in data:
		out.append(build(spec))
	return out


static func _c(hex) -> Color:
	return Color(str(hex))


static func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## A ceramic (not leafy) part.
static func _part(center: Vector3, radii: Vector3, color: Color, opts := {}) -> Dictionary:
	var r := {"center": center, "radii": radii, "parent": "", "foliage": false, "density": 0.0, "leaf_scale": 0.0,
		"max_displacement": 0.0, "growth_up": 0.0, "material": "sage", "color": color, "outline": 0.012}
	r.merge(opts, true)
	return r


## A leafy part.
static func _leafy(center: Vector3, radii: Vector3, opts := {}) -> Dictionary:
	var r := {"center": center, "radii": radii, "parent": "", "foliage": true, "density": 1.5, "leaf_scale": 0.85,
		"max_displacement": 0.2, "growth_up": 0.5, "material": "foliage"}
	r.merge(opts, true)
	return r


static func build(spec: Dictionary) -> CharacterArtProfile:
	var p := CharacterArtProfile.new()
	p.pet_name = spec["name"]
	p.species = spec["species"]
	p.adopted = spec.get("adopted", "October 8, 2026")
	p.seed = absi(hash(p.pet_name)) % 100000
	p.leaf_sheet = "hedge" + str(spec.get("plant", "ivy"))
	var pal: Array = PALETTES[spec.get("palette", "green")]
	var palette := {}
	for i in range(FAMILIES.size()):
		palette[FAMILIES[i]] = _c(pal[i])
	p.palette = palette
	p.inner_mass = _c(pal[6])
	p.flower_color = _c(spec.get("bloom", "fffaf0"))
	p.flowering = float(spec.get("flowering", 0.25))
	p.tendrils = 0
	p.leaves_per_cluster = 18
	var s: float = spec.get("size", 1.0)
	p.leaf_size = 0.34 * clampf(s, 0.55, 1.5) * float(spec.get("leaf", 1.0))
	var skin := _c(spec.get("skin", "9aa47e"))
	var skin2 := _c(spec.get("skin2", "e6ddc6"))
	var dark := _c(spec.get("dark", "3a3028"))
	var beak := _c(spec.get("beak", "e0962e"))
	var leg: float = float(spec.get("leg", 0.0)) * s
	var neck: float = float(spec.get("neck", 0.0)) * s
	var stretch: Vector3 = _v(spec.get("body", [1, 1, 1]))
	var extras: Array = spec.get("extras", [])
	var R := {}
	var feet: Array[Vector3] = []
	var h := 0.5 * s
	var hc := Vector3.ZERO
	var tb := Vector3.ZERO                       # where the tail attaches
	var top := 0.0
	var plan: String = spec.get("plan", "quadruped")
	match plan:
		"quadruped":
			var br := Vector3(1.0, 0.6, 0.66) * s * stretch
			var by := br.y * 0.92 + leg
			R["BODY"] = _leafy(Vector3(0, by, 0), br, {"shape": {"exponent": 2.2, "flat_bottom": 0.85}})
			h = 0.5 * s * float(spec.get("head", 1.0))
			hc = Vector3(br.x * 0.95, by + br.y * 0.5 + neck, 0)
			var fx := br.x * 0.62
			var fz := br.z * 0.55
			feet = [Vector3(fx, 0, fz), Vector3(fx, 0, -fz), Vector3(-fx, 0, fz), Vector3(-fx, 0, -fz)]
			_feet(R, s, leg, dark if spec.has("dark") else skin, float(spec.get("leg_width", 1.0)))
			tb = Vector3(-br.x * 0.98, by + br.y * 0.15, 0)
		"sitter":
			var br := Vector3(0.55, 0.65, 0.52) * s * stretch
			R["BODY"] = _leafy(Vector3(0, br.y * 0.95, 0), br, {"shape": {"exponent": 2.0, "taper": -0.3, "taper_axis": "y", "flat_bottom": 0.9}, "leaf_scale": 0.8, "max_displacement": 0.16})
			h = 0.48 * s * float(spec.get("head", 1.0))
			hc = Vector3(0.12 * s, br.y * 1.85 + h * 0.55 + neck, 0)
			feet = [Vector3(0.36 * s, 0, 0.2 * s), Vector3(0.36 * s, 0, -0.2 * s), Vector3(-0.05 * s, 0, 0.34 * s), Vector3(-0.05 * s, 0, -0.34 * s)]
			_feet(R, s * 0.85, 0.0, dark if spec.has("dark") else skin, 1.0)
			tb = Vector3(-br.x * 0.95, br.y * 0.5, 0)
		"bird":
			var br := Vector3(0.62, 0.52, 0.5) * s * stretch
			var by := br.y * (0.9 if leg == 0.0 else 1.0) + leg
			R["BODY"] = _leafy(Vector3(0, by, 0), br, {"shape": {"exponent": 2.0, "taper": 0.2, "flat_bottom": 0.9 if leg == 0.0 else 1.0}, "leaf_scale": 0.75, "max_displacement": 0.14})
			h = 0.42 * s * float(spec.get("head", 1.0))
			hc = Vector3(br.x * 0.62, by + br.y * 0.95 + neck, 0)
			R["WINGS"] = _leafy(Vector3(-0.05 * s, by + 0.06 * s, br.z * 0.88), Vector3(0.48, 0.3, 0.07) * s,
				{"mirror": true, "rotation": Vector3(0, 0, -12), "density": 1.8, "max_displacement": 0.07, "leaf_scale": 0.6})
			if leg > 0.0:
				feet = [Vector3(0.05 * s, 0, 0.16 * s), Vector3(0.05 * s, 0, -0.16 * s)]
				R["FEET"] = _part(Vector3.ZERO, Vector3(0.045 * s, leg * 0.5 + 0.05 * s, 0.045 * s), beak, {"outline": 0.008})
			else:
				feet = [Vector3(0.22 * s, 0, 0.16 * s), Vector3(0.22 * s, 0, -0.16 * s)]
				R["FEET"] = _part(Vector3.ZERO, Vector3(0.14, 0.05, 0.1) * s, beak, {"shape": "dome", "outline": 0.008})
			tb = Vector3(-br.x * 0.95, by + br.y * 0.1, 0)
		"round":
			var br := Vector3(0.7, 0.58, 0.62) * s * stretch
			R["BODY"] = _leafy(Vector3(0, br.y, 0), br, {"shape": {"exponent": 2.1, "flat_bottom": 0.8}})
			h = 0.4 * s * float(spec.get("head", 1.0))
			hc = Vector3(br.x * 0.85, br.y * 0.85 + neck, 0)
			feet = [Vector3(0.45 * s, 0, 0.3 * s), Vector3(0.45 * s, 0, -0.3 * s), Vector3(-0.4 * s, 0, 0.34 * s), Vector3(-0.4 * s, 0, -0.34 * s)]
			_feet(R, s * 0.9, 0.0, dark if spec.has("dark") else skin, 1.0)
			tb = Vector3(-br.x, br.y * 0.7, 0)
		"long":
			var n: int = spec.get("segments", 6)
			var taper: bool = spec.get("taper", true)
			var x := 0.0
			for i in range(n):
				var k := float(i) / float(n - 1)
				var rs := 0.34 * s * ((1.0 - 0.55 * k) if taper else 1.0)
				var c := Vector3(x, rs * 0.95, sin(float(i) * 0.95) * 0.32 * s)
				var name := "BODY" if i == 0 else "SEG_%d" % i
				R[name] = _leafy(c, Vector3(rs * 1.05, rs, rs), {"density": 1.8, "max_displacement": 0.1, "leaf_scale": 0.7})
				if not taper:
					feet.append(c * Vector3(1, 0, 1) + Vector3(0, 0, rs * 0.7))
					feet.append(c * Vector3(1, 0, 1) - Vector3(0, 0, rs * 0.7))
				x -= rs * 1.45
			if not taper:
				R["FEET"] = _part(Vector3.ZERO, Vector3(0.07, 0.06, 0.07) * s, dark, {"shape": "dome", "outline": 0.008})
			h = 0.38 * s * float(spec.get("head", 1.0))
			hc = Vector3(0.38 * s, h * 1.05 + neck, 0.0)
			tb = Vector3(x, 0.1 * s, 0)
		"snail":
			R["BODY"] = _leafy(Vector3(-0.15 * s, 0.68 * s, 0), Vector3(0.55, 0.55, 0.42) * s, {"density": 2.0, "max_displacement": 0.12, "leaf_scale": 0.7})
			R["SLUG"] = _part(Vector3(0.12 * s, 0.15 * s, 0), Vector3(0.9, 0.16, 0.3) * s, skin, {"shape": {"exponent": 2.2, "flat_bottom": 0.4}, "outline": 0.012})
			h = 0.3 * s * float(spec.get("head", 1.0))
			hc = Vector3(0.88 * s, 0.4 * s + neck, 0)
			tb = Vector3(-0.8 * s, 0.1 * s, 0)
	# ---- head
	if spec.get("head_leafy", false):
		R["HEAD"] = _leafy(hc, Vector3(h, h * 0.94, h * 0.96), {"density": 2.3, "leaf_scale": 0.6, "max_displacement": 0.1, "growth_up": 0.3})
		p.protected_zones = {"EYE_LEFT": {"radius": 0.45, "strength": 1.0}, "EYE_RIGHT": {"radius": 0.45, "strength": 1.0},
			"NOSE": {"radius": 0.5, "strength": 1.0}, "MOUTH": {"radius": 0.45, "strength": 1.0}}
	else:
		R["HEAD"] = _part(hc, Vector3(h, h * 0.92, h * 0.95), skin, {"shape": {"exponent": 2.0, "taper": float(spec.get("head_taper", -0.15))}, "outline": 0.014})
		p.protected_zones = {}
	var e: Array = spec.get("eye_dir", [0.62, 0.3, 0.62])
	p.anchors = {"EYE_LEFT": {"dir": Vector3(e[0], e[1], e[2]), "on": "HEAD"}, "EYE_RIGHT": {"dir": Vector3(e[0], e[1], -e[2]), "on": "HEAD"},
		"CHEEK_LEFT": {"dir": Vector3(0.45, -0.22, 0.86), "on": "HEAD"}, "CHEEK_RIGHT": {"dir": Vector3(0.45, -0.22, -0.86), "on": "HEAD"}}
	var nose := Vector3(0.14, 0.1, 0.16) * h
	var mouth := "smile"
	match str(spec.get("snout", "short")):
		"short":
			R["MUZZLE"] = _part(Vector3(0.72, -0.28, 0) * h, Vector3(0.38, 0.3, 0.42) * h, skin2, {"parent": "HEAD", "shape": "cushion"})
			_nose_mouth(p, "MUZZLE", Vector3(1, 0.3, 0), Vector3(0.8, -0.5, 0))
		"long":
			R["MUZZLE"] = _part(Vector3(0.85, -0.22, 0) * h, Vector3(0.6, 0.28, 0.34) * h, skin2, {"parent": "HEAD", "shape": {"exponent": 2.2, "taper": 0.35}})
			_nose_mouth(p, "MUZZLE", Vector3(1, 0.2, 0), Vector3(0.75, -0.55, 0))
			nose = Vector3(0.12, 0.09, 0.13) * h
		"flat":
			R["MUZZLE"] = _part(Vector3(0.9, -0.12, 0) * h, Vector3(0.2, 0.28, 0.34) * h, skin2, {"parent": "HEAD", "shape": {"exponent": 2.6}})
			_nose_mouth(p, "MUZZLE", Vector3(1, 0.1, 0), Vector3(0.4, -0.95, 0))
			nose = Vector3(0.05, 0.12, 0.17) * h
		"beak":
			R["BEAK"] = _part(Vector3(0.95, -0.12, 0) * h, Vector3(0.4, 0.16, 0.24) * h, beak, {"parent": "HEAD", "shape": {"exponent": 2.0, "taper": 0.85}})
		"bill":
			R["BEAK"] = _part(Vector3(0.98, -0.14, 0) * h, Vector3(0.5, 0.1, 0.32) * h, beak, {"parent": "HEAD", "shape": {"exponent": 2.6, "taper": 0.2}})
		"trunk":
			R["TRUNK"] = _part(Vector3(0.82, -0.62, 0) * h, Vector3(0.24, 0.7, 0.24) * h, skin, {"parent": "HEAD", "shape": {"exponent": 2.0, "taper": 0.45, "taper_axis": "y"}, "rotation": Vector3(0, 0, 20)})
			p.anchors["NOSE"] = {"dir": Vector3(1, -0.1, 0), "on": "HEAD"}
			p.anchors["MOUTH"] = {"dir": Vector3(0.7, -0.7, 0), "on": "HEAD"}
			nose = Vector3(0.0, 0.0, 0.0)
		"star":
			R["MUZZLE"] = _part(Vector3(0.88, -0.05, 0) * h, Vector3(0.3, 0.36, 0.36) * h, Color("e8908c"), {"parent": "HEAD", "shape": "cushion"})
			_nose_mouth(p, "MUZZLE", Vector3(1, 0.1, 0), Vector3(0.3, -0.95, 0))
			nose = Vector3(0.04, 0.05, 0.06) * h
		"bignose":
			_nose_mouth(p, "HEAD", Vector3(1, 0.0, 0), Vector3(0.8, -0.55, 0))
			nose = Vector3(0.2, 0.26, 0.22) * h
		_:
			_nose_mouth(p, "HEAD", Vector3(1, 0.1, 0), Vector3(0.85, -0.45, 0))
			nose = Vector3(0.05, 0.04, 0.06) * h
	# ---- ears and things on the head (head units)
	var ear_color := _c(spec.get("ear_color", spec.get("skin", "9aa47e")))
	var ears := {
		"round": [Vector3(-0.08, 0.78, 0.52), Vector3(0.1, 0.28, 0.26), Vector3(-20, 0, 0), {}],
		"biground": [Vector3(-0.05, 0.55, 0.78), Vector3(0.1, 0.42, 0.38), Vector3(-10, 0, 0), {}],
		"pointy": [Vector3(-0.08, 0.88, 0.44), Vector3(0.1, 0.34, 0.2), Vector3(-12, 0, 0), {"exponent": 2.0, "taper": -0.85, "taper_axis": "y"}],
		"long": [Vector3(-0.2, 1.25, 0.3), Vector3(0.1, 0.62, 0.18), Vector3(-8, 0, 0), {"exponent": 2.0, "taper": -0.45, "taper_axis": "y"}],
		"floppy": [Vector3(0.0, 0.05, 0.92), Vector3(0.1, 0.5, 0.26), Vector3(18, 0, 0), {"exponent": 2.0, "taper": -0.3, "taper_axis": "y"}],
		"big": [Vector3(-0.15, 0.25, 0.95), Vector3(0.06, 0.66, 0.58), Vector3(12, 0, 0), {}],
		"mouse": [Vector3(-0.05, 0.75, 0.55), Vector3(0.06, 0.42, 0.42), Vector3(-25, 0, 0), {}],
		"tufts": [Vector3(0.0, 0.85, 0.45), Vector3(0.07, 0.26, 0.1), Vector3(-25, 0, 0), {"exponent": 2.0, "taper": -0.9, "taper_axis": "y"}],
		"nubs": [Vector3(-0.05, 0.62, 0.72), Vector3(0.08, 0.15, 0.2), Vector3(-45, 0, 0), {}],
	}
	var ear_kind: String = spec.get("ears", "round")
	if ears.has(ear_kind):
		var ed: Array = ears[ear_kind]
		R["EARS"] = _part(ed[0] * h, ed[1] * h, ear_color, {"parent": "HEAD", "mirror": true, "rotation": ed[2], "shape": ed[3]})
	if "horns" in extras:
		R["HORNS"] = _part(Vector3(-0.05, 0.9, 0.36) * h, Vector3(0.09, 0.3, 0.09) * h, _c(spec.get("horn", "efe3c4")),
			{"parent": "HEAD", "mirror": true, "rotation": Vector3(-22, 0, 0), "shape": {"exponent": 2.0, "taper": -0.9, "taper_axis": "y"}})
	if "antlers" in extras:
		R["ANTLERS"] = _part(Vector3(-0.1, 0.95, 0.5) * h, Vector3(0.06, 0.45, 0.06) * h, _c(spec.get("horn", "8a6e4a")),
			{"parent": "HEAD", "mirror": true, "rotation": Vector3(-30, 0, 0), "shape": {"exponent": 2.0, "taper": -0.7, "taper_axis": "y"}})
		R["ANTLER_TINES"] = _part(Vector3(0.12, 1.2, 0.72) * h, Vector3(0.05, 0.28, 0.05) * h, _c(spec.get("horn", "8a6e4a")),
			{"parent": "HEAD", "mirror": true, "rotation": Vector3(-10, 0, -30), "shape": {"exponent": 2.0, "taper": -0.7, "taper_axis": "y"}})
	if "antennae" in extras:
		R["ANTENNAE"] = _part(Vector3(0.1, 1.05, 0.3) * h, Vector3(0.05, 0.4, 0.05) * h, dark, {"parent": "HEAD", "mirror": true, "rotation": Vector3(-20, 0, 0)})
	if "mane" in extras:
		R["MANE"] = _leafy(Vector3(-0.35, -0.05, 0) * h, Vector3(0.55, 1.3, 1.3) * h, {"parent": "HEAD", "density": 2.2, "leaf_scale": 0.8, "max_displacement": 0.22})
	if "eyepatch" in extras:
		var d := Vector3(e[0], e[1], e[2]).normalized() * 0.84
		R["EYE_PATCH"] = _part(d * h, Vector3(0.24, 0.3, 0.22) * h, dark, {"parent": "HEAD", "mirror": true, "outline": 0.0})
	if "mask" in extras:
		R["MASK"] = _part(Vector3(0.0, 0.18, 0.0) * h, Vector3(0.88, 0.4, 1.0) * h, dark, {"parent": "HEAD", "outline": 0.0})
	if "stripes" in extras:
		R["STRIPES"] = _part(Vector3(0.05, 0.38, 0.4) * h, Vector3(0.85, 0.22, 0.2) * h, dark, {"parent": "HEAD", "mirror": true, "outline": 0.0})
	var white := Color("f6f4ec")
	if "blaze" in extras:
		R["BLAZE"] = _part(Vector3(0.1, 0.62, 0) * h, Vector3(0.82, 0.32, 0.17) * h, white, {"parent": "HEAD", "outline": 0.0})
	if "cap" in extras:
		R["CAP"] = _part(Vector3(-0.05, 0.5, 0) * h, Vector3(0.97, 0.6, 0.99) * h, dark, {"parent": "HEAD", "outline": 0.0})
	if "bib" in extras:
		R["BIB"] = _part(Vector3(0.5, -0.62, 0) * h, Vector3(0.42, 0.32, 0.52) * h, dark, {"parent": "HEAD", "outline": 0.0})
	if "crest" in extras:
		R["CREST"] = _part(Vector3(-0.3, 0.95, 0) * h, Vector3(0.3, 0.42, 0.1) * h, _c(spec.get("crest_color", spec.get("skin", "9aa47e"))),
			{"parent": "HEAD", "rotation": Vector3(0, 0, 32), "shape": {"exponent": 2.0, "taper": -0.8, "taper_axis": "y"}})
	if "wattle" in extras:
		R["WATTLE"] = _part(Vector3(0.82, -0.6, 0) * h, Vector3(0.11, 0.32, 0.11) * h, Color("c83a2a"), {"parent": "HEAD"})
	if "ring" in extras:
		R["RING"] = _part(Vector3(-0.05, -0.85, 0) * h, Vector3(0.72, 0.16, 0.72) * h, skin2, {"parent": "HEAD", "outline": 0.0})
	if "facedisc" in extras:
		R["FACE_DISC"] = _part(Vector3(e[0], e[1], e[2]).normalized() * 0.72 * h, Vector3(0.28, 0.42, 0.4) * h, skin2,
			{"parent": "HEAD", "mirror": true, "outline": 0.008})
	# ---- body extras
	var bc: Vector3 = R["BODY"]["center"]
	var bradii: Vector3 = R["BODY"]["radii"]
	if "belly" in extras:
		R["BELLY"] = _part(bc + Vector3(bradii.x * 0.5, -bradii.y * 0.05, 0), Vector3(bradii.x * 0.62, bradii.y * 0.8, bradii.z * 0.7), skin2, {"outline": 0.0})
	if "wings" in extras:
		R["WINGS"] = _leafy(bc + Vector3(-0.1 * s, bradii.y * 0.85, bradii.z * 0.7), Vector3(0.45, 0.05, 0.42) * s,
			{"mirror": true, "rotation": Vector3(-35, 0, 0), "density": 1.6, "max_displacement": 0.06, "leaf_scale": 0.6})
	if "hands" in extras:
		R["HANDS"] = _part(bc + Vector3(bradii.x * 0.78, bradii.y * 0.45, bradii.z * 0.3), Vector3(0.08, 0.1, 0.07) * s,
			dark if spec.has("dark") else skin, {"mirror": true, "outline": 0.01})
	# ---- tail
	match str(spec.get("tail", "short")):
		"bushy":
			R["TAIL"] = _leafy(tb + Vector3(-0.25, 0.55, 0) * s, Vector3(0.34, 0.72, 0.34) * s, {"shape": {"exponent": 2.0, "taper": 0.2, "taper_axis": "y"}, "rotation": Vector3(0, 0, 25), "density": 2.0, "max_displacement": 0.25})
			if spec.get("tip", false):
				R["TAIL_TIP"] = _leafy(tb + Vector3(-0.55, 1.15, 0) * s, Vector3(0.2, 0.2, 0.2) * s, {"flowers": true, "density": 2.5})
		"thin":
			R["TAIL"] = _part(tb + Vector3(-0.42, 0.12, 0) * s, Vector3(0.45, 0.045, 0.045) * s, _c(spec.get("tail_color", spec.get("skin2", "e6ddc6"))), {"rotation": Vector3(0, 0, -20), "outline": 0.008})
		"cotton":
			R["TAIL"] = _leafy(tb + Vector3(-0.06, 0, 0) * s, Vector3(0.2, 0.2, 0.2) * s, {"flowers": true, "density": 2.5})
		"paddle":
			R["TAIL"] = _part(tb + Vector3(-0.45, -0.12, 0) * s, Vector3(0.5, 0.06, 0.3) * s, skin, {"shape": {"exponent": 4.0}, "material": "tail", "outline": 0.02})
		"curly":
			R["TAIL"] = _part(tb + Vector3(-0.1, 0.08, 0) * s, Vector3(0.1, 0.1, 0.06) * s, skin2, {"outline": 0.008})
		"short":
			R["TAIL"] = _part(tb + Vector3(-0.12, 0.06, 0) * s, Vector3(0.18, 0.1, 0.1) * s, _c(spec.get("tail_color", spec.get("skin", "9aa47e"))), {"shape": "teardrop", "rotation": Vector3(0, 0, 25)})
		"fan":
			var f: float = spec.get("fan", 1.0)
			R["TAIL"] = _leafy(tb + Vector3(-0.28, 0.2 + 0.3 * (f - 1.0), 0) * s, Vector3(0.3 * f, 0.3 * f, 0.07) * s, {"rotation": Vector3(0, 0, 30 - 25 * (f - 1.0)), "density": 2.0, "max_displacement": 0.08, "leaf_scale": 0.6})
		"taper":
			R["TAIL"] = _part(tb + Vector3(-0.45, 0.05, 0) * s, Vector3(0.55, 0.12, 0.12) * s, skin, {"shape": {"exponent": 2.0, "taper": 0.8}, "rotation": Vector3(0, 0, 8)})
		"tuft":
			R["TAIL"] = _part(tb + Vector3(-0.4, -0.05, 0) * s, Vector3(0.42, 0.035, 0.035) * s, skin, {"rotation": Vector3(0, 0, 35), "outline": 0.008})
			R["TAIL_TIP"] = _leafy(tb + Vector3(-0.72, -0.3, 0) * s, Vector3(0.12, 0.14, 0.12) * s, {"density": 2.5, "max_displacement": 0.06, "leaf_scale": 0.5})
		"ringed":
			for i in range(4):
				var k := float(i)
				R["TAIL_%d" % i] = _part(tb + Vector3(-0.18 - 0.26 * k, 0.05 + 0.12 * k, 0) * s, Vector3(0.18, 0.17, 0.17) * s * (1.0 - 0.07 * k), skin2 if i % 2 == 0 else dark)
	# ---- face
	p.features = {"teeth": spec.get("teeth", false), "mouth": spec.get("mouth", mouth), "cheeks": spec.get("cheeks", true), "nose": nose}
	if spec.get("teeth", false) and p.anchors.has("MOUTH"):
		p.anchors["TEETH"] = {"dir": Vector3(0.9, -0.62, 0), "on": p.anchors["MOUTH"]["on"]}
	p.eye_size = 0.2 * h * float(spec.get("eyes", 1.0))
	p.hop_height = 0.38 * s
	p.regions = R
	p.feet = feet
	top = hc.y + h * (2.0 if ear_kind == "long" else 1.2)
	var length := maxf(2.2 * s, absf(tb.x) + hc.x + h)
	p.frame_target = Vector3(0.2 * s, top * 0.48, 0)
	p.frame_distance = maxf(top, length) * 1.75 + 0.9
	p.wants = spec.get("wants", {"notice": {}, "visit": {}, "resident": {}})
	var hints: Array = spec.get("hints", ["", "", ""])
	p.hints = {"notice": hints[0], "visit": hints[1], "resident": hints[2]}
	return plantify(p)


## The cute, all-plant pass (the goal image's rules, applied to any pet):
##   - a hedgepet is ALL PLANT except its feet and tail: head, face, snout and ears are leaves (the face younger and
##     lighter); snouts and markings (masks, stripes, caps, bibs, collars, bellies, crests) are clear moss patches
##   - features stay features: eyes, nose, teeth, beak; so do paws, tails, horns, antlers, antennae (wood and stems)
##   - cute proportions: a bigger head, bigger eyes, a shorter snout
##   - the leaf look: fewer, bigger leaves you can tell apart with shadow between, fine ink, a few vines
const KEEP := ["BODY", "FEET", "HANDS", "HORNS", "ANTLERS", "ANTLER_TINES", "ANTENNAE", "BEAK", "SLUG", "TRUNK", "WINGS"]
const MARKINGS := ["MASK", "EYE_PATCH", "BLAZE", "CAP", "BIB", "RING", "STRIPES", "FACE_DISC", "BELLY", "CREST", "WATTLE", "BELL"]


static func plantify(p: CharacterArtProfile) -> CharacterArtProfile:
	var R: Dictionary = p.regions
	var head: Dictionary = R["HEAD"]
	var grow := 1.08
	# a bigger head (its parts move out with it)
	head["radii"] = (head["radii"] as Vector3) * grow
	for name in R:
		if name != "HEAD" and R[name].get("parent", "") == "HEAD":
			R[name]["center"] = (R[name]["center"] as Vector3) * grow
			if name in ["MUZZLE"]:
				var r: Vector3 = R[name]["radii"]
				R[name]["radii"] = Vector3(r.x * 0.85, r.y, r.z)   # a shorter snout
	for name in R:
		var r: Dictionary = R[name]
		if name in KEEP or name.begins_with("TAIL") or name.begins_with("SEG_"):
			continue
		var leafy := {"foliage": true, "material": "foliage", "growth_up": 0.2, "coverage": 1.0}
		if name == "HEAD":
			leafy.merge({"density": 3.2, "leaf_scale": 0.55, "max_displacement": 0.12, "growth_up": 0.3, "tint": "pale_highlight",
				"tint_amount": 0.42, "coverage": 0.97, "leaves_per_cluster": 18}, true)   # a lighter face: it reads as a head
		elif name == "MUZZLE" or name == "FACE" or name in MARKINGS:
			# a clear patch: short grass / moss fibres, no leaves (the face reads; markings read). Snouts take the
			# pet's own moss colour (HedgePetNode.patch_tint); markings keep their colour, softened toward the plant.
			r["surface"] = "moss"
			r["foliage"] = false
			r.erase("outline")
			if name in MARKINGS and r.has("color"):
				r["tint_color"] = (r["color"] as Color).lerp(p.palette["matcha"], 0.15)
			r.erase("color")
			continue
		elif name == "EARS":
			leafy.merge({"density": 7.0, "leaf_scale": 0.42, "max_displacement": 0.05, "leaves_per_cluster": 14}, true)
		else:
			continue
		r.merge(leafy, true)
		r.erase("outline")
		if not name in MARKINGS:
			r.erase("color")             # under the leaves is the plant's own dark mass, not a painted skin
	# the face shows through: eyes, nose, mouth and teeth keep a small clearing
	var zones := {}
	for a in ["EYE_LEFT", "EYE_RIGHT"]:
		if p.anchors.has(a):
			zones[a] = {"radius": 0.36, "strength": 1.0}
	for a: Array in [["NOSE", 0.2], ["MOUTH", 0.16], ["TEETH", 0.18]]:
		if p.anchors.has(a[0]):
			zones[a[0]] = {"radius": a[1], "strength": 1.0}
	p.protected_zones = zones
	p.eye_size *= 1.15
	p.leaf_size *= 1.3
	p.leaves_per_cluster = fullness(plant_of(p))
	p.coverage = 0.8
	p.interior_ink = 0.6
	p.silhouette_ink = 1.0
	p.ink_color = Color("1c2213")
	p.inner_mass = p.inner_mass.darkened(0.18)          # the gaps between leaves read as shadow, not as skin
	# vines only on pets big enough to carry them (on a chickadee they'd be spider legs)
	var body_r: Vector3 = R["BODY"]["radii"]
	p.tendrils = 3 if body_r.x >= 0.9 else (1 if body_r.x >= 0.6 else 0)
	return p


## Tuning: per-pet adjustments picked with the swatch tool (res://dev/swatches.tscn), saved in res://pets/tuning.json
## as {pet name: {feature: value}}. Numeric features are multipliers on the pet as built; "plant" is a plant name;
## "hue" shifts the palette's hue.
const TUNING_PATH := "res://pets/tuning.json"
const FEATURES := ["head", "eyes", "ears", "snout length", "snout width", "body length", "body height", "legs",
	"leaf size", "fullness", "hue", "plant"]


static func load_tuning() -> Dictionary:
	if not FileAccess.file_exists(TUNING_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
	return d if d is Dictionary else {}


static func tune(base: CharacterArtProfile, t: Dictionary) -> CharacterArtProfile:
	if t.is_empty():
		return base
	var p: CharacterArtProfile = base.duplicate(true)
	p.set_meta("native_plant", native_plant(base))
	var R: Dictionary = p.regions
	for f in t:
		var v = t[f]
		match f:
			"head":
				R["HEAD"]["radii"] = (R["HEAD"]["radii"] as Vector3) * float(v)
				for n in R:
					if R[n].get("parent", "") == "HEAD":
						R[n]["center"] = (R[n]["center"] as Vector3) * float(v)
						R[n]["radii"] = (R[n]["radii"] as Vector3) * float(v)
			"eyes":
				p.eye_size *= float(v)
			"ears":
				if R.has("EARS"):
					R["EARS"]["radii"] = (R["EARS"]["radii"] as Vector3) * float(v)
			"snout length":
				if R.has("MUZZLE"):
					var r: Vector3 = R["MUZZLE"]["radii"]
					R["MUZZLE"]["center"] = (R["MUZZLE"]["center"] as Vector3) + Vector3(r.x * (float(v) - 1.0), 0, 0)
					R["MUZZLE"]["radii"] = Vector3(r.x * float(v), r.y, r.z)
			"snout width":
				if R.has("MUZZLE"):
					var r: Vector3 = R["MUZZLE"]["radii"]
					R["MUZZLE"]["radii"] = Vector3(r.x, r.y * float(v), r.z * float(v))
			"body length":
				R["BODY"]["radii"] = (R["BODY"]["radii"] as Vector3) * Vector3(float(v), 1, 1)
			"body height":
				var r: Vector3 = R["BODY"]["radii"]
				R["BODY"]["center"] = (R["BODY"]["center"] as Vector3) + Vector3(0, r.y * (float(v) - 1.0), 0)
				R["BODY"]["radii"] = Vector3(r.x, r.y * float(v), r.z)
			"legs":
				if R.has("FEET"):
					var r: Vector3 = R["FEET"]["radii"]
					R["FEET"]["radii"] = Vector3(r.x, r.y * float(v), r.z)
			"leaf size":
				p.leaf_size *= float(v)
			"fullness":
				p.leaves_per_cluster = maxi(4, int(round(p.leaves_per_cluster * float(v))))
			"hue":
				var pal := {}
				for k in p.palette:
					var c: Color = p.palette[k]
					pal[k] = Color.from_hsv(fposmod(c.h + float(v), 1.0), c.s, c.v)
				p.palette = pal
			"plant":
				var q := restyle(p, str(v))
				q.regions = p.regions
				p = q
	return p


static func _nose_mouth(p: CharacterArtProfile, on: String, nose: Vector3, mouth: Vector3) -> void:
	p.anchors["NOSE"] = {"dir": nose, "on": on}
	p.anchors["MOUTH"] = {"dir": mouth, "on": on}


static func _feet(R: Dictionary, s: float, leg: float, color: Color, width: float) -> void:
	if leg > 0.05:
		R["FEET"] = _part(Vector3.ZERO, Vector3(0.13 * s * width, leg * 0.5 + 0.08 * s, 0.13 * s * width), color, {"shape": {"exponent": 2.2}, "outline": 0.012})
	else:
		R["FEET"] = _part(Vector3.ZERO, Vector3(0.17, 0.11, 0.15) * s, color, {"shape": "dome", "outline": 0.012})
