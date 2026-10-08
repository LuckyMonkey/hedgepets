class_name CharacterArtProfile
extends Resource

## Everything that makes a HedgePet look like itself, as data: proportions, anatomical regions, facial anchors,
## protected zones, foliage per region, palette, lighting, expression and detail levels. The renderer
## (scripts/hedge_pet_3d.gd + scripts/art/*) reads this; it holds no art numbers of its own.
##
## Gerald's values live in res://pets/gerald.tres (made by CharacterArtProfile.gerald()). A future HedgePet is the
## same architecture with a different profile. The design pillar: a child can draw it with ovals, two eyes, a nose,
## two teeth, four little feet and repeated leaf marks. Parameters are documented in docs/ART_DIRECTION.md.

@export var pet_name := "Gerald"
@export var species := "beaver"
@export var adopted := "October 6, 2026"
@export var seed := 1977
@export var leaf_sheet := "hedgeivy"        # assets/sprites/<leaf_sheet>.png (+ _n.png): the plant it is made of

## Face features beyond the eyes: "teeth" (bool), "mouth" ("beaver" | "smile" | "bunny"), "cheeks" (bool),
## "nose" (radii of the nose seed).
@export var features := {"teeth": true, "mouth": "beaver", "cheeks": true, "nose": Vector3(0.11, 0.085, 0.14)}

## Garden wishes (scripts/garden/garden_game.gd): what makes this pet NOTICE the garden (peek through the fence),
## VISIT (come in and wander) and MOVE IN (stay). Conditions are garden counts: "puddle", "sticks", "branches",
## "rocks", "leaf_pile", "lawn_chair", "cleared" (junk cleared so far), "<plant>_planted", "<plant>_grown",
## "<plant>_flowering" (plants: ivy, clover, fern, jasmine). "hints" are the journal's words for each step.
@export var wants := {"notice": {}, "visit": {}, "resident": {}}
@export var hints := {"notice": "", "visit": "", "resident": ""}
@export var starts_resident := false

## Framing: what the camera looks at, and from how far, in the default three-quarter view.
@export var frame_target := Vector3(0.15, 0.85, 0.0)
@export var frame_distance := 7.4

## Regions. Each: center (in the parent's space), radii (ellipsoid), parent ("" = the creature), foliage (bool),
## density (clusters per unit area, relative), leaf_scale (relative to profile.leaf_size), max_displacement (how far
## leaves may stand off the surface, in world units: the 80/20 silhouette control), growth_up (how strongly leaves
## climb upward vs. lie along the surface), material ("foliage" | "moss" | "terracotta" | "tail" | "ear" | "blossom"
## | "sage"), and optionally: shape (a preset name or numbers, see hedge_anatomy.gd), rotation (degrees), mirror (a
## copy on the other side, z flipped), flowers (the region is made of blossom), outline (ink width), color.
@export var regions := {}

## Facial anchors on the head, in head-local space: "dir" is a direction from the head centre, the anchor sits on the
## head (or muzzle) surface along it. "on" says which region's surface ("HEAD" or "MUZZLE").
@export var anchors := {}

## Protected zones around anchors: foliage density and leaf size fall off smoothly toward them (never a hole).
## Each: anchor name -> {"radius": angular radius on the head (radians), "strength": 0..1}
@export var protected_zones := {}

## Feet (ceramic / terracotta garden-ornament nubs): creature-space positions.
@export var feet: Array[Vector3] = []

## Foliage hierarchy.
@export var leaf_size := 0.40               # base leaf length in world units (BODY uses 1.0x)
@export var leaves_per_cluster := 20
@export var cluster_spread := 0.52          # angular spread of a cluster (radians)
@export var cluster_min_gap := 0.36         # cluster centres keep apart: the negative space between clumps
@export var coverage := 0.86                # fraction of each cluster's leaves kept (gaps show the inner green mass)
@export var face_clearing := 1.0            # multiplier on every protected zone
@export var silhouette_scale := 1.0         # multiplier on every region's max_displacement
@export var flowering := 0.35               # 0 no flowers .. 1 blooming (flowers never near the face)
@export var growth := 1.0                   # 0.3 young/sparse .. 1 full
@export var tendrils := 4                   # vines trailing from the body

## Palette: botanical families. Leaves take their cluster's family, with gentle variation inside it; orientation
## (upward = lit) and age shift it within the family. No arbitrary RGB.
@export var palette := {
	"deep_forest": Color("2f4a2a"),
	"muted_ivy": Color("4a6b36"),
	"matcha": Color("6e8c42"),
	"warm_yellow_green": Color("889a44"),
	"soft_sage": Color("72886a"),
	"pale_highlight": Color("b9c58a"),
}
@export var inner_mass := Color("34502a")   # the green under the leaves (visible in the gaps, on purpose)
@export var color_variation := 0.06         # variation within a cluster
@export var paper := Color(0.968627, 0.945098, 0.890196)

## Ink: strong at the silhouette, thin and low-contrast inside the foliage.
@export var ink_color := Color("26301d")
@export var silhouette_ink := 0.85
@export var interior_ink := 0.30
@export var outline_strength := 1.0         # inverted-hull outline on tail, feet, ears, muzzle

## Lighting preset: soft illustration.
@export var key_energy := 0.72
@export var key_angle := Vector3(-58.0, -32.0, 0.0)
@export var key_color := Color(1.0, 0.95, 0.86)
@export var fill_energy := 0.30             # from the viewer's side: the face never falls into shadow
@export var ambient_energy := 0.50
@export var ambient_color := Color(0.86, 0.86, 0.78)
@export var shadow_softness := 4.0          # shadow blur
@export var shadow_strength := 0.32         # how dark cast shadows get on the paper

## Expression.
@export var eye_size := 0.155
@export var blink_interval := Vector2(2.4, 5.5)
@export var look_strength := 0.22
@export var hop_height := 0.38

## Detail levels (mobile first): fraction of leaves drawn, leaf scale-up to keep masses whole, interior ink kept.
@export var lod := {
	"CLOSE": {"leaves": 1.0, "scale": 1.0, "ink": 1.0, "flowers": true},
	"MEDIUM": {"leaves": 0.55, "scale": 1.25, "ink": 0.5, "flowers": true},
	"FAR": {"leaves": 0.25, "scale": 1.7, "ink": 0.0, "flowers": false},
}


static func gerald() -> CharacterArtProfile:
	var p := CharacterArtProfile.new()
	# Primitives (scripts/art/hedge_anatomy.gd): BODY a pear-bean that sits flat; HEAD big and round (baby
	# proportions); MUZZLE a soft cushion; TAIL a rounded-rectangle paddle; EARS small cups; FEET flat-bottomed domes.
	p.regions = {
		"BODY": {"center": Vector3(0.0, 0.95, 0.0), "radii": Vector3(1.34, 0.95, 1.04), "parent": "", "foliage": true,
			"density": 1.3, "leaf_scale": 1.0, "max_displacement": 0.26, "growth_up": 0.45, "material": "foliage",
			"shape": {"exponent": 2.15, "taper": -0.14, "flat_bottom": 0.88}},
		"HEAD": {"center": Vector3(1.30, 1.40, 0.0), "radii": Vector3(0.84, 0.78, 0.80), "parent": "", "foliage": true,
			"density": 2.3, "leaf_scale": 0.62, "max_displacement": 0.11, "growth_up": 0.3, "material": "foliage",
			"shape": {"exponent": 2.1, "taper": -0.05}},
		"MUZZLE": {"center": Vector3(0.70, -0.22, 0.0), "radii": Vector3(0.34, 0.27, 0.37), "parent": "HEAD", "foliage": false,
			"density": 0.0, "leaf_scale": 0.25, "max_displacement": 0.0, "growth_up": 0.0, "material": "moss",
			"shape": {"exponent": 2.4, "taper": -0.15}, "outline": 0.016},
		"TAIL": {"center": Vector3(-1.62, 0.16, 0.08), "radii": Vector3(0.74, 0.075, 0.56), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.4, "max_displacement": 0.0, "growth_up": 0.0, "material": "tail",
			"shape": {"exponent": 4.0}, "rotation": Vector3(0, 6, 7), "outline": 0.025},   # a rounded-rectangle paddle
		"EARS": {"center": Vector3(-0.12, 0.66, 0.46), "radii": Vector3(0.12, 0.17, 0.07), "parent": "HEAD", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "ear",
			"shape": {"exponent": 2.3}, "rotation": Vector3(-24, -20, 0), "mirror": true, "outline": 0.018},
		"FEET": {"center": Vector3.ZERO, "radii": Vector3(0.23, 0.16, 0.2), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "terracotta",
			"shape": {"exponent": 2.6, "flat_bottom": 0.12}, "outline": 0.016},
	}
	p.anchors = {
		"EYE_LEFT": {"dir": Vector3(0.76, 0.36, 0.46), "on": "HEAD"},
		"EYE_RIGHT": {"dir": Vector3(0.76, 0.36, -0.46), "on": "HEAD"},
		"NOSE": {"dir": Vector3(1.0, 0.25, 0.0), "on": "MUZZLE"},
		"MOUTH": {"dir": Vector3(0.82, -0.50, 0.0), "on": "MUZZLE"},
		"TEETH": {"dir": Vector3(0.92, -0.62, 0.0), "on": "MUZZLE"},
		"CHEEK_LEFT": {"dir": Vector3(0.62, -0.18, 0.72), "on": "HEAD"},
		"CHEEK_RIGHT": {"dir": Vector3(0.62, -0.18, -0.72), "on": "HEAD"},
	}
	p.protected_zones = {
		"EYE_LEFT": {"radius": 0.42, "strength": 1.0},
		"EYE_RIGHT": {"radius": 0.42, "strength": 1.0},
		"NOSE": {"radius": 0.55, "strength": 1.0},
		"MOUTH": {"radius": 0.5, "strength": 1.0},
		"TEETH": {"radius": 0.5, "strength": 1.0},
		"CHEEK_LEFT": {"radius": 0.34, "strength": 0.6},
		"CHEEK_RIGHT": {"radius": 0.34, "strength": 0.6},
	}
	p.frame_target = Vector3(0.15, 0.85, 0.0)
	p.frame_distance = 7.4
	p.starts_resident = true
	p.wants = {"notice": {"puddle": 1}, "visit": {"sticks": 3}, "resident": {"ivy_grown": 1, "puddle": 1}}
	p.hints = {"notice": "Gerald likes the sound of water.", "visit": "He collects sticks. Leave a few lying about.",
		"resident": "He'd stay for good with some ivy to chew and his puddle."}
	p.feet = [Vector3(0.82, 0.0, 0.56), Vector3(0.82, 0.0, -0.56), Vector3(-0.66, 0.0, 0.62), Vector3(-0.66, 0.0, -0.62)]
	return p


## Clover: a sitting topiary bunny made of clover. Pear body (wider at the bottom), egg head, tall leafy ears that
## narrow to their tips, a cotton tail of blossom, little teeth.
static func clover() -> CharacterArtProfile:
	var p := CharacterArtProfile.new()
	p.pet_name = "Clover"
	p.species = "bunny"
	p.adopted = "October 8, 2026"
	p.seed = 4113
	p.leaf_sheet = "hedgeclover"
	p.leaf_size = 0.30
	p.flowering = 0.5
	p.palette = {"deep_forest": Color("355a2c"), "muted_ivy": Color("4f7a38"), "matcha": Color("74a046"),
		"warm_yellow_green": Color("8fae4c"), "soft_sage": Color("7c9a6c"), "pale_highlight": Color("b8cf86"),
		"blossom": Color(1.0, 0.97, 0.95)}
	p.inner_mass = Color("3c6230")
	p.regions = {
		"BODY": {"center": Vector3(0.0, 0.86, 0.0), "radii": Vector3(0.88, 0.84, 0.82), "parent": "", "foliage": true,
			"density": 1.5, "leaf_scale": 1.0, "max_displacement": 0.18, "growth_up": 0.35, "material": "foliage",
			"shape": {"exponent": 2.05, "taper": -0.32, "taper_axis": "y", "flat_bottom": 0.86}},
		"HEAD": {"center": Vector3(0.46, 1.92, 0.0), "radii": Vector3(0.62, 0.56, 0.6), "parent": "", "foliage": true,
			"density": 2.4, "leaf_scale": 0.6, "max_displacement": 0.08, "growth_up": 0.3, "material": "foliage", "shape": "egg"},
		"MUZZLE": {"center": Vector3(0.50, -0.15, 0.0), "radii": Vector3(0.2, 0.16, 0.25), "parent": "HEAD", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "moss", "shape": "cushion",
			"outline": 0.012},
		"EARS": {"center": Vector3(-0.14, 0.74, 0.22), "radii": Vector3(0.16, 0.46, 0.10), "parent": "HEAD", "foliage": true,
			"density": 4.0, "leaf_scale": 0.62, "max_displacement": 0.05, "growth_up": 0.9, "material": "foliage",
			"shape": {"exponent": 2.1, "taper": -0.25, "taper_axis": "y"}, "rotation": Vector3(-12, 0, 6), "mirror": true},
		"TAIL": {"center": Vector3(-0.86, 0.48, 0.0), "radii": Vector3(0.26, 0.26, 0.26), "parent": "", "foliage": true,
			"density": 3.0, "leaf_scale": 0.7, "max_displacement": 0.05, "growth_up": 0.0, "material": "blossom", "flowers": true},
		"FEET": {"center": Vector3.ZERO, "radii": Vector3(0.24, 0.13, 0.17), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "terracotta",
			"shape": "dome", "outline": 0.014},
	}
	p.anchors = {
		"EYE_LEFT": {"dir": Vector3(0.78, 0.30, 0.46), "on": "HEAD"},
		"EYE_RIGHT": {"dir": Vector3(0.78, 0.30, -0.46), "on": "HEAD"},
		"NOSE": {"dir": Vector3(1.0, 0.35, 0.0), "on": "MUZZLE"},
		"MOUTH": {"dir": Vector3(0.85, -0.45, 0.0), "on": "MUZZLE"},
		"TEETH": {"dir": Vector3(0.9, -0.7, 0.0), "on": "MUZZLE"},
		"CHEEK_LEFT": {"dir": Vector3(0.6, -0.2, 0.72), "on": "HEAD"},
		"CHEEK_RIGHT": {"dir": Vector3(0.6, -0.2, -0.72), "on": "HEAD"},
	}
	p.protected_zones = {"EYE_LEFT": {"radius": 0.42, "strength": 1.0}, "EYE_RIGHT": {"radius": 0.42, "strength": 1.0},
		"NOSE": {"radius": 0.5, "strength": 1.0}, "MOUTH": {"radius": 0.45, "strength": 1.0}, "TEETH": {"radius": 0.45, "strength": 1.0},
		"CHEEK_LEFT": {"radius": 0.3, "strength": 0.6}, "CHEEK_RIGHT": {"radius": 0.3, "strength": 0.6}}
	p.feet = [Vector3(0.52, 0.0, 0.34), Vector3(0.52, 0.0, -0.34), Vector3(0.05, 0.0, 0.6), Vector3(0.05, 0.0, -0.6)]
	p.features = {"teeth": true, "mouth": "bunny", "cheeks": true, "nose": Vector3(0.07, 0.055, 0.09)}
	p.eye_size = 0.13
	p.tendrils = 0
	p.frame_target = Vector3(0.1, 1.25, 0.0)
	p.frame_distance = 7.0
	p.wants = {"notice": {"cleared": 4}, "visit": {"clover_planted": 1}, "resident": {"clover_grown": 2}}
	p.hints = {"notice": "A tidier lawn would catch a bunny's eye.", "visit": "Something sweet and three-leaved would bring her in.",
		"resident": "Two good clover patches and she'd never leave."}
	return p


## Juniper: a hedgehog of fern. A low bean body with fronds that sweep up and back (spiky, but bounded), a bare
## mossy face that narrows to a pointed snout, tiny ears, four little feet. No teeth.
static func juniper() -> CharacterArtProfile:
	var p := CharacterArtProfile.new()
	p.pet_name = "Juniper"
	p.species = "hedgehog"
	p.adopted = "October 8, 2026"
	p.seed = 7071
	p.leaf_sheet = "hedgefern"
	p.leaf_size = 0.36
	p.leaves_per_cluster = 22
	p.flowering = 0.15
	p.palette = {"deep_forest": Color("24402a"), "muted_ivy": Color("3d6236"), "matcha": Color("5f8a40"),
		"warm_yellow_green": Color("7f9a44"), "soft_sage": Color("6a8466"), "pale_highlight": Color("a9bd7e")}
	p.inner_mass = Color("2c4826")
	p.regions = {
		"BODY": {"center": Vector3(0.0, 0.62, 0.0), "radii": Vector3(1.0, 0.62, 0.8), "parent": "", "foliage": true,
			"density": 1.6, "leaf_scale": 0.9, "max_displacement": 0.32, "growth_up": 1.2, "material": "foliage",
			"shape": {"exponent": 2.1, "taper": -0.1, "flat_bottom": 0.82}},
		"HEAD": {"center": Vector3(0.88, 0.58, 0.0), "radii": Vector3(0.48, 0.4, 0.42), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "sage",
			"shape": {"exponent": 2.0, "taper": -0.5}, "outline": 0.014, "color": Color("c4b48c")},
		"EARS": {"center": Vector3(-0.12, 0.34, 0.25), "radii": Vector3(0.07, 0.09, 0.05), "parent": "HEAD", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "sage", "mirror": true,
			"outline": 0.01},
		"FEET": {"center": Vector3.ZERO, "radii": Vector3(0.14, 0.09, 0.12), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "terracotta",
			"shape": "dome", "outline": 0.01},
	}
	p.anchors = {
		"EYE_LEFT": {"dir": Vector3(0.62, 0.34, 0.6), "on": "HEAD"},
		"EYE_RIGHT": {"dir": Vector3(0.62, 0.34, -0.6), "on": "HEAD"},
		"NOSE": {"dir": Vector3(1.0, 0.02, 0.0), "on": "HEAD"},
		"MOUTH": {"dir": Vector3(0.75, -0.55, 0.0), "on": "HEAD"},
		"CHEEK_LEFT": {"dir": Vector3(0.45, -0.2, 0.85), "on": "HEAD"},
		"CHEEK_RIGHT": {"dir": Vector3(0.45, -0.2, -0.85), "on": "HEAD"},
	}
	p.protected_zones = {}
	p.feet = [Vector3(0.62, 0.0, 0.34), Vector3(0.62, 0.0, -0.34), Vector3(-0.5, 0.0, 0.42), Vector3(-0.5, 0.0, -0.42)]
	p.features = {"teeth": false, "mouth": "smile", "cheeks": true, "nose": Vector3(0.075, 0.065, 0.075)}
	p.eye_size = 0.085
	p.tendrils = 0
	p.frame_target = Vector3(0.2, 0.55, 0.0)
	p.frame_distance = 5.6
	p.wants = {"notice": {"leaf_pile": 1}, "visit": {"fern_planted": 1}, "resident": {"lawn_chair": 1, "fern_grown": 1}}
	p.hints = {"notice": "Hedgehogs can't resist a pile of old leaves.", "visit": "A fern would make him feel at home.",
		"resident": "He's been eyeing that tipped-over chair as a bedroom. Don't tidy it away."}
	return p


## Bramble: a tortoise whose shell is a flowering jasmine bush. A low dome shell, a mossy head and legs, a short
## tail. Slow, round, content.
static func bramble() -> CharacterArtProfile:
	var p := CharacterArtProfile.new()
	p.pet_name = "Bramble"
	p.species = "tortoise"
	p.adopted = "October 8, 2026"
	p.seed = 9001
	p.leaf_sheet = "hedgejasmine"
	p.leaf_size = 0.34
	p.flowering = 0.8
	p.palette = {"deep_forest": Color("2f4d2e"), "muted_ivy": Color("4b7140"), "matcha": Color("6c9550"),
		"warm_yellow_green": Color("8aa35a"), "soft_sage": Color("7a9476"), "pale_highlight": Color("b4c793")}
	p.inner_mass = Color("33502c")
	p.regions = {
		"BODY": {"center": Vector3(0.0, 0.42, 0.0), "radii": Vector3(1.08, 0.72, 0.96), "parent": "", "foliage": true,
			"density": 1.5, "leaf_scale": 1.0, "max_displacement": 0.16, "growth_up": 0.5, "material": "foliage",
			"shape": {"exponent": 2.35, "flat_bottom": 0.42}},
		"HEAD": {"center": Vector3(1.22, 0.58, 0.0), "radii": Vector3(0.40, 0.34, 0.36), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "sage", "shape": "egg",
			"outline": 0.014, "color": Color("7c8c5c")},
		"TAIL": {"center": Vector3(-1.08, 0.24, 0.0), "radii": Vector3(0.2, 0.08, 0.1), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "sage",
			"shape": {"exponent": 2.0, "taper": 0.7, "color": Color("7c8c5c")}, "outline": 0.01, "color": Color("7c8c5c")},
		"FEET": {"center": Vector3.ZERO, "radii": Vector3(0.24, 0.2, 0.22), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "sage",
			"shape": "dome", "outline": 0.014, "color": Color("7c8c5c")},
	}
	p.anchors = {
		"EYE_LEFT": {"dir": Vector3(0.62, 0.40, 0.56), "on": "HEAD"},
		"EYE_RIGHT": {"dir": Vector3(0.62, 0.40, -0.56), "on": "HEAD"},
		"NOSE": {"dir": Vector3(1.0, 0.15, 0.0), "on": "HEAD"},
		"MOUTH": {"dir": Vector3(0.88, -0.35, 0.0), "on": "HEAD"},
		"CHEEK_LEFT": {"dir": Vector3(0.5, -0.15, 0.82), "on": "HEAD"},
		"CHEEK_RIGHT": {"dir": Vector3(0.5, -0.15, -0.82), "on": "HEAD"},
	}
	p.protected_zones = {}
	p.feet = [Vector3(0.66, 0.0, 0.62), Vector3(0.66, 0.0, -0.62), Vector3(-0.62, 0.0, 0.6), Vector3(-0.62, 0.0, -0.6)]
	p.features = {"teeth": false, "mouth": "smile", "cheeks": true, "nose": Vector3(0.035, 0.03, 0.035)}
	p.eye_size = 0.08
	p.tendrils = 3
	p.frame_target = Vector3(0.15, 0.45, 0.0)
	p.frame_distance = 6.0
	p.wants = {"notice": {"rocks": 2}, "visit": {"jasmine_planted": 1}, "resident": {"jasmine_flowering": 1, "puddle": 1}}
	p.hints = {"notice": "Warm stones to sun on.", "visit": "The smell of jasmine, even a little one.",
		"resident": "Flowering jasmine and a drink of water. He's in no hurry."}
	return p

