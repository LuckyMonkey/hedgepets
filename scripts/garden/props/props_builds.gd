extends "res://scripts/garden/props/props_yard.gd"

## Props 3/4 - things you can put in the garden: feeder, bath, log pile, nest box, pumpkin, crate, hay, scarecrow, lantern, stones.
##
## Each one is a BUILDS entry in game_state.gd: bought with coins, placed with a tap, and each draws certain visitors.
##
## Part of the props layer chain (the full order is at the top of scripts/garden/garden_props.gd). Code here was moved verbatim
## from the old single file; only its place changed.

# ------------------------------------------------------------------ things you can put in the garden (🧺)
## A wooden post with a little roofed feeder and a seed tray.
static func bird_feeder(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Feeder", at, yaw)
	var wood := mat("feederwood", Color("8a6a48"))
	part(r, cyl(0.05, 0.06, 1.5, 8), wood, Vector3(0, 0.75, 0), Vector3.ZERO, 0.008)
	part(r, box(Vector3(0.5, 0.05, 0.5)), wood, Vector3(0, 1.52, 0), Vector3.ZERO, 0.008)
	part(r, box(Vector3(0.36, 0.3, 0.36)), mat("feederglass", Color("c8d4cc")), Vector3(0, 1.7, 0), Vector3.ZERO, 0.006)
	var roof := PrismMesh.new()
	roof.size = Vector3(0.62, 0.22, 0.56)
	part(r, roof, mat("feederroof", Color("6a3a2a")), Vector3(0, 1.97, 0), Vector3.ZERO, 0.01)
	part(r, blob(Vector3(0.2, 0.04, 0.2), "dome"), mat("seed", Color("c8a060")), Vector3(0, 1.56, 0), Vector3.ZERO, 0.0)
	return r


## A concrete bird bath: pedestal and a shallow bowl of water.
static func bird_bath(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Bath", at, yaw)
	var stone := mat("bathstone", Color("b4ae9e"))
	part(r, cyl(0.12, 0.2, 0.7, 12), stone, Vector3(0, 0.35, 0), Vector3.ZERO, 0.01)
	part(r, cyl(0.5, 0.3, 0.16, 18), stone, Vector3(0, 0.76, 0), Vector3.ZERO, 0.012)
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	water.set_shader_parameter("drip", Vector2(0.5, 0.5))
	var disc := PlaneMesh.new()
	disc.size = Vector2(1.05, 1.05)
	var w := MeshInstance3D.new()
	w.mesh = disc
	w.material_override = water
	w.position = Vector3(0, 0.845, 0)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(w)
	return r


## Split logs stacked in a little pyramid.
static func log_pile(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "LogPile", at, yaw)
	var bark := mat("logbark", Color("6a5038"))
	var rows := [[-0.36, 0.0, 0.36], [-0.18, 0.18], [0.0]]
	for y in range(rows.size()):
		for x: float in rows[y]:
			part(r, cyl(0.17, 0.17, 1.1, 10), bark, Vector3(x, 0.17 + y * 0.3, 0), Vector3(90, 0, 0), 0.012)
	return r


## A nest box on a post, with a round door.
static func nest_box(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "NestBox", at, yaw)
	var wood := mat("boxwood_plank", Color("9a7a52"))
	part(r, cyl(0.05, 0.06, 1.3, 8), mat("feederwood", Color("8a6a48")), Vector3(0, 0.65, 0), Vector3.ZERO, 0.008)
	part(r, box(Vector3(0.34, 0.42, 0.32)), wood, Vector3(0, 1.45, 0), Vector3.ZERO, 0.01)
	var roof := PrismMesh.new()
	roof.size = Vector3(0.48, 0.18, 0.44)
	part(r, roof, mat("feederroof", Color("6a3a2a")), Vector3(0, 1.75, 0), Vector3.ZERO, 0.01)
	part(r, cyl(0.06, 0.06, 0.02, 12), mat("hole", Color("2a2018")), Vector3(0.17, 1.5, 0), Vector3(0, 0, 90), 0.0)
	return r


## A ribbed pumpkin with a curly stem.
static func pumpkin(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Pumpkin", at, rng.randf_range(0, 360))
	var orange := mat("pumpkin%d" % rng.randi_range(0, 2), Color("d8782a").lerp(Color("e89a3a"), rng.randf()))
	for k in range(8):
		var a := TAU * k / 8.0
		part(r, blob(Vector3(size * 0.42, size * 0.5, size * 0.3), {"exponent": 2.0}), orange, Vector3(cos(a), 0.0, sin(a)) * size * 0.32 + Vector3(0, size * 0.48, 0), Vector3(0, -rad_to_deg(a), 0), 0.01 if k % 2 == 0 else 0.0)
	part(r, cyl(0.03, 0.05, size * 0.3, 6), mat("stem", Color("5a6a2a")), Vector3(0, size * 1.02, 0), Vector3(0, 0, 14), 0.008)
	return r


## A wooden crate of windfall apples, a few spilled.
static func apple_crate(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Apples", at, yaw)
	var slat := mat("crate", Color("b08a5a"))
	for side: float in [-1.0, 1.0]:
		part(r, box(Vector3(0.9, 0.36, 0.05)), slat, Vector3(0, 0.18, side * 0.3), Vector3.ZERO, 0.008)
		part(r, box(Vector3(0.05, 0.36, 0.6)), slat, Vector3(side * 0.43, 0.18, 0), Vector3.ZERO, 0.008)
	var red := mat("apple", Color("b8322a"))
	var green := mat("apple2", Color("8aa03a"))
	for k in range(9):
		part(r, blob(Vector3(0.12, 0.11, 0.12), {"exponent": 2.0}), red if k % 4 else green, Vector3(rng.randf_range(-0.3, 0.3), 0.32 + rng.randf_range(0, 0.05), rng.randf_range(-0.2, 0.2)), Vector3.ZERO, 0.006)
	for k in range(3):
		part(r, blob(Vector3(0.12, 0.11, 0.12), {"exponent": 2.0}), red, Vector3(0.7 + k * 0.2, 0.1, rng.randf_range(-0.4, 0.5)), Vector3.ZERO, 0.006)
	return r


## A hay bale: a straw block with two twine bands and a few loose wisps.
static func hay_bale(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "HayBale", at, yaw)
	var straw := mat("straw", Color("d6b862"))
	part(r, blob(Vector3(0.52, 0.26, 0.32), {"exponent": 5.0}), straw, Vector3(0, 0.26, 0), Vector3.ZERO, 0.012)
	var twine := mat("twine", Color("8a6a3a"))
	for x: float in [-0.22, 0.22]:
		part(r, blob(Vector3(0.025, 0.275, 0.335), {"exponent": 5.0}), twine, Vector3(x, 0.26, 0), Vector3.ZERO, 0.0)
	var wisp := mat("strawwisp", Color("e2c876"))
	for k in range(7):
		part(r, cyl(0.006, 0.01, rng.randf_range(0.15, 0.3), 4), wisp, Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.05, 0.5), rng.randf_range(-0.3, 0.3)) * Vector3(1, 1, 1), Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-70, 70)), 0.0)
	return r


## A friendly scarecrow: a post and crossbar, a patched red shirt, a burlap head with button eyes and a stitched
## smile, a floppy straw hat, straw poking out of the cuffs. Keeps nobody away.
static func scarecrow(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Scarecrow", at, yaw)
	var wood := mat("feederwood", Color("8a6a48"))
	part(r, cyl(0.045, 0.055, 1.9, 8), wood, Vector3(0, 0.95, 0), Vector3.ZERO, 0.008)
	part(r, box(Vector3(1.2, 0.06, 0.06)), wood, Vector3(0, 1.42, 0), Vector3.ZERO, 0.008)
	var shirt := mat("scareshirt", Color("b4483a"))
	part(r, blob(Vector3(0.27, 0.32, 0.15), {"exponent": 3.0}), shirt, Vector3(0, 1.22, 0), Vector3.ZERO, 0.012)
	part(r, blob(Vector3(0.5, 0.09, 0.1), {"exponent": 3.0}), shirt, Vector3(0, 1.4, 0), Vector3.ZERO, 0.01)
	part(r, box(Vector3(0.14, 0.14, 0.02)), mat("patch", Color("d8b46a")), Vector3(0.1, 1.16, 0.15), Vector3(0, 0, 12), 0.0)
	var straw := mat("strawwisp", Color("e2c876"))
	for side: float in [-1.0, 1.0]:
		part(r, cyl(0.02, 0.07, 0.14, 6), straw, Vector3(side * 0.58, 1.4, 0), Vector3(0, 0, side * 90), 0.0)
	var head := part(r, blob(Vector3(0.19, 0.21, 0.18), {"exponent": 2.0}), mat("burlap", Color("cdb48a")), Vector3(0, 1.74, 0), Vector3.ZERO, 0.01)
	var dark := mat("button", Color("2a2420"))
	for side: float in [-1.0, 1.0]:
		part(head, cyl(0.03, 0.03, 0.02, 10), dark, Vector3(side * 0.07, 0.03, 0.17), Vector3(90, 0, 0), 0.0)
	for k in range(5):
		var x := (k - 2) * 0.035
		part(head, box(Vector3(0.022, 0.006, 0.01)), dark, Vector3(x, -0.07 + absf(x) * 0.6, 0.175), Vector3(0, 0, x * 260), 0.0)
	var hat := mat("hat", Color("b89a52"))
	part(r, cyl(0.34, 0.34, 0.025, 18), hat, Vector3(0, 1.9, 0), Vector3(6, 0, -4), 0.01)
	part(r, cyl(0.14, 0.17, 0.17, 14), hat, Vector3(0, 1.99, 0), Vector3(6, 0, -4), 0.01)
	return r


## A lantern on a shepherd's hook, glowing warm (it shows best at dusk).
static func lantern(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Lantern", at, yaw)
	var iron := mat("iron", Color("2e2c2a"), 0.6)
	part(r, cyl(0.02, 0.025, 1.5, 6), iron, Vector3(0, 0.75, 0), Vector3.ZERO, 0.006)
	part(r, box(Vector3(0.3, 0.025, 0.025)), iron, Vector3(0.14, 1.5, 0), Vector3.ZERO, 0.006)
	part(r, cyl(0.006, 0.006, 0.1, 4), iron, Vector3(0.28, 1.45, 0), Vector3.ZERO, 0.0)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd88a")
	glow.emission_enabled = true
	glow.emission = Color("ffc060")
	glow.emission_energy_multiplier = 1.4
	part(r, box(Vector3(0.14, 0.18, 0.14)), glow, Vector3(0.28, 1.31, 0), Vector3.ZERO, 0.0)
	part(r, cyl(0.02, 0.11, 0.07, 4), iron, Vector3(0.28, 1.43, 0), Vector3(0, 45, 0), 0.006)
	part(r, box(Vector3(0.16, 0.02, 0.16)), iron, Vector3(0.28, 1.21, 0), Vector3.ZERO, 0.006)
	return r


## Three flat stepping stones in a little curve, sunk into the lawn.
static func stepping_stones(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Stones", at, yaw)
	for k in range(3):
		var g := Color("8a8a82").lerp(Color("a49a88"), rng.randf())
		part(r, blob(Vector3(0.3, 0.035, 0.24) * rng.randf_range(0.85, 1.1), "pebble"), mat("stepstone%d" % k, g), Vector3((k - 1) * 0.62, 0.01, (k - 1) * (k - 1) * 0.18), Vector3(0, rng.randf_range(0, 180), 0), 0.006)
	return r
