class_name GardenProps
extends "res://scripts/garden/props/props_surroundings.gd"

## The garden's things, built from simple shapes in the same storybook style as the pets: matte, soft colours, a
## thin ink outline. Not a perfect eden - a real back garden: a tipped lawn chair, a rusty grill, a broken fence,
## a leaking sprinkler, sticks and branches, a tire, a tipped pot, leaf piles. Every builder takes a parent and a
## seeded RandomNumberGenerator and returns the prop's root node.

##
## GardenProps is the top of a layer chain of prop catalogues (scripts/garden/props/):
##   props_kit -> props_yard -> props_builds -> props_surroundings -> garden_props.gd (here: hideouts)
## Call everything as GardenProps.<name>(): every layer's static functions are reachable through this class.

# ------------------------------------------------------------------ hideouts (pets climb in: hideouts.gd)
## A steel paint bucket: a slightly tapered pail, a rolled rim, a wire bail handle, an old drip of paint down one side.
static func paint_bucket(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Bucket", at, yaw)
	var steel := mat("pail", Color("a9aeb0"), 0.45)
	var pail := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.26
	c.height = 0.52
	c.cap_top = false                                   # open: you can see in (and climb in)
	c.radial_segments = 20
	pail.mesh = c
	pail.material_override = steel
	pail.position = Vector3(0, 0.26, 0)
	r.add_child(pail)
	var inside := steel.duplicate() as StandardMaterial3D
	inside.cull_mode = BaseMaterial3D.CULL_FRONT
	inside.albedo_color = Color("6e7274")
	var inner := MeshInstance3D.new()
	inner.mesh = c
	inner.material_override = inside
	inner.position = pail.position
	r.add_child(inner)
	part(r, cyl(0.26, 0.26, 0.02, 20), mat("pailfloor", Color("5a5e60")), Vector3(0, 0.02, 0), Vector3.ZERO, 0.0)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.29
	rim.outer_radius = 0.32
	rim.ring_segments = 20
	part(r, rim, steel, Vector3(0, 0.52, 0), Vector3.ZERO, 0.0)
	var bail := TorusMesh.new()
	bail.inner_radius = 0.3
	bail.outer_radius = 0.315
	part(r, bail, mat("wire", Color("4a4e50")), Vector3(0, 0.52, 0), Vector3(90, 0, 0), 0.0).scale = Vector3(1, 1, 1.2)
	part(r, box(Vector3(0.06, 0.22, 0.01)), mat("paintdrip", Color("3a6a8a")), Vector3(0.2, 0.42, 0.2), Vector3(0, 45, 0), 0.0)
	return r


## A big terracotta pot, standing upright, empty except for a little old soil.
static func pot_upright(parent: Node3D, at: Vector3) -> Node3D:
	var r := root(parent, "Planter", at, 0.0)
	var clay := mat("terracotta2", Color("b0623e"))
	var c := CylinderMesh.new()
	c.top_radius = 0.42
	c.bottom_radius = 0.3
	c.height = 0.6
	c.cap_top = false
	c.radial_segments = 20
	var pot := MeshInstance3D.new()
	pot.mesh = c
	pot.material_override = clay
	pot.position = Vector3(0, 0.3, 0)
	r.add_child(pot)
	var inside := clay.duplicate() as StandardMaterial3D
	inside.cull_mode = BaseMaterial3D.CULL_FRONT
	inside.albedo_color = Color("7a3e26")
	var inner := MeshInstance3D.new()
	inner.mesh = c
	inner.material_override = inside
	inner.position = pot.position
	r.add_child(inner)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.4
	lip.outer_radius = 0.48
	lip.ring_segments = 20
	part(r, lip, clay, Vector3(0, 0.6, 0), Vector3.ZERO, 0.01)
	part(r, cyl(0.31, 0.31, 0.04, 16), mat("soil", Color("4a3626")), Vector3(0, 0.1, 0), Vector3.ZERO, 0.0)
	return r


## An old stone well: a ring of flat field stones, a little wooden roof on two posts, a pail on a rope.
static func stone_well(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Well", at, rng.randf_range(0, 360))
	var moss := Color("6e7a4a")
	for course in range(5):
		var n := 14
		for k in range(n):
			var a := TAU * (k + (0.5 if course % 2 else 0.0)) / n
			var p := Vector3(cos(a) * 0.82, 0.08 + course * 0.15, sin(a) * 0.82)
			_wall_stone(r, p, Vector3(0.2, 0.075, 0.12), -rad_to_deg(a) + 90.0, rng, moss, course == 4)
	part(r, cyl(0.7, 0.7, 0.02, 20), mat("wellwater", Color("1e2a2c"), 0.1), Vector3(0, 0.25, 0), Vector3.ZERO, 0.0)
	var wood := mat("wellwood", Color("6a5038"))
	for side: float in [-1.0, 1.0]:
		part(r, box(Vector3(0.12, 1.9, 0.12)), wood, Vector3(side * 0.95, 0.95, 0), Vector3.ZERO, 0.008)
	var roof := PrismMesh.new()
	roof.size = Vector3(2.5, 0.6, 1.5)
	part(r, roof, mat("wellroof", Color("5a4636")), Vector3(0, 2.15, 0), Vector3.ZERO, 0.012)
	part(r, cyl(0.06, 0.06, 1.9, 8), wood, Vector3(0, 1.55, 0), Vector3(0, 0, 90), 0.006)   # the winch
	part(r, cyl(0.01, 0.01, 0.6, 4), mat("rope", Color("c8b088")), Vector3(0, 1.22, 0), Vector3.ZERO, 0.0)
	return r


## A burrow under the roots: a soft mound of earth, a round dark doorway with a few pebbles and a twig arch around
## it, a tiny mushroom by the door. Cute, not a hole.
static func burrow(parent: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := root(parent, "Burrow", at, yaw)
	var earth := mat("burrowearth", Color("6e5236"))
	part(r, blob(Vector3(0.95, 0.38, 0.8), {"exponent": 2.2, "flat_bottom": 0.2}), earth, Vector3(-0.15, 0.05, 0), Vector3.ZERO, 0.012)
	part(r, cyl(0.34, 0.34, 0.06, 18), mat("burrowdark", Color("1e140c")), Vector3(0.55, 0.2, 0), Vector3(0, 0, 70), 0.0)
	for k in range(7):
		var a := lerpf(-1.3, 1.3, k / 6.0)
		part(r, blob(Vector3(0.08, 0.06, 0.07), "pebble"), mat("pebble%d" % (k % 3), Color("8a857a").lerp(Color("b0a898"), (k % 3) / 2.0)),
			Vector3(0.6, 0.22 + sin(a + 1.57) * 0.3, cos(a + 1.57) * 0.38), Vector3.ZERO, 0.006)
	part(r, cyl(0.02, 0.025, 0.9, 5), mat("twig", Color("5e4a36")), Vector3(0.64, 0.5, 0), Vector3(90, 0, 0), 0.006)
	part(r, cyl(0.025, 0.035, 0.12, 6), mat("stalk", Color("efe6d0")), Vector3(0.75, 0.06, 0.48), Vector3.ZERO, 0.0)
	part(r, blob(Vector3(0.09, 0.05, 0.09), "dome"), mat("cap", Color("c8603a")), Vector3(0.75, 0.13, 0.48), Vector3.ZERO, 0.006)
	return r
