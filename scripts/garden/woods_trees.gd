extends RefCounted

## Plants the woods' trees. What a tree looks like is TreeFactory's job (scripts/art/tree_factory.gd: oak, maple,
## birch, white pine, all from the foliage system); this file decides which trees may stand where and groups them
## into batches for drawing.
##
## Rules:
##   - Never in your way: every limb and every cluster is tested against the walk (woods.eye_clear: the camera's path
##     at eye height along every trail). A tree that would brush your face is not planted (counted in `rejected`).
##   - Batched by PATCH metres of ground: each patch is one trunk mesh, one core mesh and one leaf MultiMesh per leaf
##     sheet (TreeFactory.build_batch), so the whole wood is a few dozen draw calls however many trees.
##   - A trail blaze (a painted pale-blue mark) on some trunks right by a path, facing it.

const PATCH := 24.0

var woods: Node3D
var _patches := {}                             # Vector2i -> Array of tree plans (TreeFactory.plan)
var rejected := 0                              # trees left out for being in the way of the walk
var planted := 0


func _init(w: Node3D) -> void:
	woods = w


## Plant a tree of this kind at p (woods-local, on the ground), if it is clear of the walk. Takes exactly one number
## from rng, whatever the recipe, so tree recipes can change without moving anything else in the woods.
func tree(kind: String, p: Vector3, rng: RandomNumberGenerator, blaze := Vector3.ZERO) -> void:
	var pl := TreeFactory.plan(kind, p, rng.randi())
	if not _clear_of_walk(pl):
		rejected += 1
		return
	if blaze != Vector3.ZERO:
		var trunk: Array = pl["limbs"][0]
		var a: Vector3 = trunk[0]
		var b: Vector3 = trunk[1]
		var at := a.lerp(b, clampf(1.9 / maxf((b - a).y, 0.1), 0.0, 1.0))
		pl["blaze"] = [at + blaze * (lerpf(trunk[2], trunk[3], 0.3) + 0.01), blaze]
	var key := Vector2i(floori(p.x / PATCH), floori(p.z / PATCH))
	if not _patches.has(key):
		_patches[key] = []
	(_patches[key] as Array).append(pl)
	planted += 1


## Every limb (sampled along its length: a long one can cross the walk between its ends) and every cluster.
func _clear_of_walk(pl: Dictionary) -> bool:
	for l: Array in pl["limbs"]:
		var a: Vector3 = l[0]
		var b: Vector3 = l[1]
		var n := maxi(2, ceili(a.distance_to(b) / 0.6))
		for i in range(n + 1):
			var f := float(i) / n
			if not woods.eye_clear(a.lerp(b, f), lerpf(l[2], l[3], f) + 0.6):
				return false
	var radii: Vector3 = TreeFactory.KINDS[pl["kind"]]["radii"]
	for c: Array in pl["clusters"]:
		var s: Vector3 = c[2]
		if not woods.eye_clear(c[1], maxf(radii.x * s.x, radii.z * s.z) + 0.4):
			return false
	return true


## Build every patch and put it in the woods. Tags each node for the woods' quality tiers (woods_build.gd).
func finish() -> void:
	var cards := 0
	var tris := 0
	for key: Vector2i in _patches:
		await Slicer.tick(woods)                         # (a patch at a time: the woods build behind the garden)
		var plans: Array = _patches[key]
		var centre := Vector3.ZERO
		for pl: Dictionary in plans:
			centre += (pl["limbs"][0][0] as Vector3)
		centre /= plans.size()
		for node in TreeFactory.build_batch(plans, centre):
			var kind := "trunk" if node.name == "Trunks" else ("mass" if node.name == "Cores" else "leaves")
			node.name = "Patch_%d_%d_%s" % [key.x, key.y, node.name]
			node.set_meta("woods_lod_kind", kind)
			node.set_meta("woods_id", "tree:%d_%d:%s" % [key.x, key.y, kind])
			if node is MultiMeshInstance3D:
				var mm := (node as MultiMeshInstance3D).multimesh
				cards += mm.instance_count
				tris += mm.instance_count * 2
			elif node is MeshInstance3D:
				tris += (node as MeshInstance3D).mesh.get_faces().size() / 3
			woods.add_child(node)
	print("woods trees: %d planted, %d left out of the walk, %d patches, %d leaf cards, %d triangles" % [planted, rejected, _patches.size(), cards, tris])
