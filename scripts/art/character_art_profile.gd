class_name CharacterArtProfile
extends Resource

## Everything that makes a HedgePet look like itself, as data: proportions, anatomical regions, facial anchors,
## protected zones, foliage per region, palette, lighting, expression and detail levels. The renderer
## (scripts/beaver_3d.gd + scripts/art/*) reads this; it holds no art numbers of its own.
##
## Gerald's values live in res://pets/gerald.tres (made by CharacterArtProfile.gerald()). A future HedgePet is the
## same architecture with a different profile. The design pillar: a child can draw it with ovals, two eyes, a nose,
## two teeth, four little feet and repeated leaf marks. Parameters are documented in docs/ART_DIRECTION.md.

@export var pet_name := "Gerald"
@export var seed := 1977

## Regions. Each: center (in the parent's space), radii (ellipsoid), parent ("" = the creature), foliage (bool),
## density (clusters per unit area, relative), leaf_scale (relative to profile.leaf_size), max_displacement (how far
## leaves may stand off the surface, in world units: the 80/20 silhouette control), growth_up (how strongly leaves
## climb upward vs. lie along the surface), material ("foliage" | "moss" | "terracotta" | "tail" | "ear").
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
			"shape": {"exponent": 2.4, "taper": -0.15}},
		"TAIL": {"center": Vector3(-1.62, 0.16, 0.08), "radii": Vector3(0.74, 0.075, 0.56), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.4, "max_displacement": 0.0, "growth_up": 0.0, "material": "tail",
			"shape": {"exponent": 4.0}},                                  # a rounded-rectangle paddle
		"EARS": {"center": Vector3(-0.12, 0.66, 0.46), "radii": Vector3(0.12, 0.17, 0.07), "parent": "HEAD", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "ear",
			"shape": {"exponent": 2.3}},
		"FEET": {"center": Vector3.ZERO, "radii": Vector3(0.23, 0.16, 0.2), "parent": "", "foliage": false,
			"density": 0.0, "leaf_scale": 0.0, "max_displacement": 0.0, "growth_up": 0.0, "material": "terracotta",
			"shape": {"exponent": 2.6, "flat_bottom": 0.12}},
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
	p.feet = [Vector3(0.82, 0.0, 0.56), Vector3(0.82, 0.0, -0.56), Vector3(-0.66, 0.0, 0.62), Vector3(-0.66, 0.0, -0.62)]
	return p
