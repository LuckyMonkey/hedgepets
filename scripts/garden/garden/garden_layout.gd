extends Node3D

## Garden 1/6 - the layout: bounds, gates, the fence, the creek line, and quick questions about the yard.
##
## The fixed shape of the yard and quick questions about it. BOUNDS is the playable lawn; GATES are the ways out
## (the footbridge to the woods, the street, the burrow); the fence is split into FENCE_SECTIONS so a broken one can be
## mended (mend_fence). on_bridge() / _in_creek() / _in_puddle() / count() are asked by the pets, the tools and the
## game, so they sit at the bottom of the chain where everyone can reach them.
##
## Part of the garden layer chain (the full order is at the top of scripts/garden/garden.gd). Code here was moved verbatim
## from the old single file; only its place changed.

const BOUNDS := Rect2(-12.0, -8.5, 24.0, 17.0)    # x, z where pets may walk
const PET_SCALE := 0.62
const PAPER := Color(0.968627, 0.945098, 0.890196)

var camera: Camera3D
var sun: DirectionalLight3D
var pets: Array[HedgePetNode] = []
var obstacles: Array = []                         # fixed: [Vector2 centre (x, z), radius] (trees)
var things: Array = []                            # the garden's props: {id, kind, node, at (Vector2), radius, junk, value}
## Orbit: the camera circles the middle of the garden. Drag sideways to spin (with a glide after a fling), drag up and
## down to tilt a little, wheel / pinch to zoom. Springs on all three (Motion.spring).
const CENTER := Vector3(0.0, 0.0, -0.8)
var game: Node                                    # scripts/garden/garden_game.gd
const GAP := Vector3(2.5, 0.0, -11.0)             # the collapsed bit of fence (the burying-ground side)
## Ways in. Each pet comes by the one that fits it (gate_for): the creek's footbridge, the gap in the woods wall, the
## garden gate from the houses, or the broken fence by the burying ground. out = where it waits unseen, peek = where
## it stands looking in, inside = its first steps in the garden.
const GATES := {
	"fence": {"out": Vector3(2.5, 0, -17.0), "peek": Vector3(2.5, 0, -11.7), "inside": Vector3(2.5, 0, -8.5)},
	"woods": {"out": Vector3(17.0, 0, -2.0), "peek": Vector3(10.2, 0, -2.0), "inside": Vector3(6.5, 0, -2.0)},
	"creek": {"out": Vector3(-23.0, 0, 1.5), "peek": Vector3(-14.2, 0, 1.5), "inside": Vector3(-10.0, 0, 1.5)},
	"houses": {"out": Vector3(2.6, 0, 13.0), "peek": Vector3(-1.0, 0, 10.6), "inside": Vector3(-1.0, 0, 7.0)},   # out: into his yard, beside the stairs
	# the burrow behind the bottom-corner tree: burrowing pets peek out of it and climb out (hideouts.gd)
	"burrow": {"out": Vector3(-12.3, -1.0, 4.9), "peek": Vector3(-11.6, 0, 4.9), "inside": Vector3(-9.0, 0, 3.8)},
}
const BURROW_AT := Vector3(-12.3, 0, 4.9)
const GREG_Z := 20.9                              # the white house with the blue door (its back to the garden)
## The back fence, in runs you can mend one at a time; the collapsed bit (FENCE_GAP) becomes a gate when mended.
const FENCE_SECTIONS := [Vector2(-16.0, -7.2), Vector2(-7.2, 1.6), Vector2(1.6, 6.0), Vector2(6.0, 10.4), Vector2(10.4, 16.0)]   # on the 2.2 m post grid
const FENCE_GAP := Vector2(0.5, 4.5)
var fence_sections: Array = []


## Rebuild one section of the back fence, mended (animated unless at_once: loading a save).
func mend_fence(i: int, at_once := false) -> void:
	var sec: Dictionary = fence_sections[i]
	if sec["mended"]:
		return
	sec["mended"] = true
	var old: Node3D = sec["node"]
	var r := RandomNumberGenerator.new()
	var fresh := GardenProps.bake_static(GardenProps.broken_fence(self, sec["from"], sec["to"], -11.0, r, FENCE_GAP, true))
	sec["node"] = fresh
	if at_once:
		old.queue_free()
		return
	fresh.scale = Vector3(1, 0.02, 1)
	var t := Motion.channel(old, "mend")
	t.tween_property(old, "scale", Vector3(1, 0.02, 1), Motion._d(Motion.BASE)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(old.queue_free)
	var t2 := Motion.channel(fresh, "mend")
	t2.tween_interval(Motion._d(Motion.BASE * 0.6))
	t2.tween_property(fresh, "scale", Vector3.ONE, Motion._d(Motion.SLOW)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
const GATE_WORDS := {
	"burrow": ["mole", "chipmunk", "woodchuck", "mouse"],
	"creek": ["otter", "mink", "peeper", "bullfrog", "turtle", "mallard", "duck", "loon", "seal", "puffin", "eft", "beaver", "mole"],
	"woods": ["fox", "coyote", "fisher", "bobcat", "fawn", "moose", "bear", "porcupine", "turkey", "owl", "woodpecker", "chipmunk", "hedgehog"],
	"houses": ["raccoon", "opossum", "skunk", "mouse", "bunny", "robin", "cardinal", "jay", "chickadee", "dove", "bluebird", "squirrel"],
}


func gate_for(p: CharacterArtProfile) -> String:
	for gate in GATE_WORDS:
		for word: String in GATE_WORDS[gate]:
			if p.species.contains(word):
				return gate
	return "fence"
var woods: Node                                   # scripts/garden/woods.gd: the trails over the footbridge


## The creek's course (x for a given z), down the west side.
## The real creek ends at the fence line; neighborhood.gd carries it on past next door in the skybox.
const CREEK_END := 12.0


func _creek_x(z: float) -> float:
	return -17.0 + 1.5 * sin(z * 0.15)


## On the footbridge over the creek (the way to the woods).
func on_bridge(p: Vector2) -> bool:
	var bz: float = GATES["creek"]["peek"].z
	return absf(p.y - bz) < 1.4 and absf(p.x - _creek_x(bz)) < 2.6


func _in_creek(p: Vector2) -> bool:
	return absf(p.x - _creek_x(p.y)) < 1.7


## Where the trail into the woods runs (its z at x), bending a little as it leaves the bridge.
func _trail_z(x: float, bz: float) -> float:
	var x0 := _creek_x(bz) - 2.4
	return bz + sin((x0 - x) * 0.16) * 1.4


func count(kind: String) -> int:
	var n := 0
	for t in things:
		if t["kind"] == kind:
			n += 1
	return n


## The sprinkler's puddle (garden_props.gd: offset 0.9, 0.4 from the sprinkler, 2.6 x 1.8, turned 20°).
func _in_puddle(p: Vector2) -> bool:
	for t in things:
		if t["kind"] == "sprinkler":
			var node: Node3D = t["node"]
			var puddle := node.get_node_or_null("Puddle") as Node3D
			if puddle != null:
				var local := puddle.global_transform.affine_inverse() * Vector3(p.x, 0, p.y)
				if Vector2(local.x / 1.15, local.z / 0.8).length() < 1.0:
					return true
	return false


static func _hash01(x: float, z: float) -> float:
	return fposmod(sin(x * 127.1 + z * 311.7) * 43758.5453, 1.0)
