extends "res://scripts/garden/woods/woods_finds.gd"

## Woods 6/6 - building it: the build steps, the compiled woods, streaming by distance, quality tiers.
##
## The woods are built in steps behind the loading card (build_steps), so the phone never freezes for a whole
## second. Each static step can instead be read from a compiled scene (res://world/woods_compiled.scn, made by
## tools/bake/compile_woods.gd); SOURCES are the files whose text is fingerprinted to tell whether that compile is
## stale. If it is stale or missing, everything is built live: same result, just slower.
##
## Streaming: only cells within STREAM_RADIUS of you are shown; the radius follows the quality tier.
##
## Part of the woods layer chain (see scripts/garden/woods.gd for the full order). Code here was moved verbatim from
## the old single file; only its place changed.

const STREAM_RADIUS := 33.0
const STREAM_RADIUS_LOW := 20.0
const STREAM_RADIUS_HIGH := 72.0
var _stream_chunks := {}
var _stream_last := Vector3.INF


var _pail: Node3D
var nursery: Node3D                   # nursery.gd
# ------------------------------------------------------------------ building it (once)
## Built in steps (Elsewhere shows a loading card between them; the bake runs them all at once).
func build_steps() -> Array:
	return [["Finding the trails", _build_trails], ["Shaping the hills and the creek", _static_step.bind("land", _build_land)],
		["Growing the trees", _build_trees], ["Ferns and fallen logs", _static_step.bind("undergrowth", _build_undergrowth)],
		["The old oak, the pond, the signs", _build_places], ["Letting the sun in", _build_sky],
		["Down to the nursery", _build_nursery], ["Applying woods placements", _apply_overrides], ["Tidying up", _merge_static]]


# ------------------------------------------------------------------ the compiled woods
## A hybrid: the woods' BASE MAP - ground, trail beds, litter, the creek and footbridge home, the undergrowth, and the
## 1:16 land's world - is compiled once (tools/bake/compile_woods.gd) into res://world/woods_compiled.scn and loaded
## instead of generated. The TREES stay code-driven entities (built by woods_trees.gd, from the bake cache), and so
## does everything you interact with (signs, finds, the nursery, willows, the campfire, sunbeams, trinkets), drawing
## the same random numbers it always did (each skipped step's generator state is stored): it lands exactly where it did.
## The compiled file carries a fingerprint of the generator code; a changed generator means it's ignored (built live,
## with a warning) - unless res://world/woods.lock exists, which keeps the compiled woods as they are (a saved version).
const COMPILED := "res://world/woods_compiled.scn"
const LOCK := "res://world/woods.lock"
const SOURCES := ["res://scripts/garden/woods.gd",
	"res://scripts/garden/woods/woods_ground.gd",
	"res://scripts/garden/woods/woods_trails.gd",
	"res://scripts/garden/woods/woods_scenery.gd",
	"res://scripts/garden/woods/woods_landmarks.gd",
	"res://scripts/garden/woods/woods_finds.gd",
	"res://scripts/garden/woods/woods_build.gd",
	"res://scripts/garden/woods_trees.gd", "res://scripts/garden/distant_land.gd",
	"res://scripts/garden/garden_props.gd", "res://scripts/art/foliage_builder.gd", "res://scripts/art/hedge_anatomy.gd"]
var compiling := false                 # tools/bake/compile_woods.gd: copy what each static step makes
var recorded := {}                     # compiling: key -> {"nodes": [detached copies], "state": int}
var _compiled: Node                    # the instanced compiled scene while building from it, or null
var compiled_used := false


func enter() -> void:
	await WoodsPack.ensure()
	await super.enter()


static func source_stamp() -> String:
	var all := ""
	for path in SOURCES:
		var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if text == "":
			return ""                                    # an export: the code can't be read; the file is trusted
		all += text
	return all.sha256_text().substr(0, 16)


func _open_compiled() -> bool:
	if compiling or OS.get_environment("HEDGEPETS_NO_COMPILED") != "" or not ResourceLoader.exists(COMPILED):
		return false
	var ps := load(COMPILED) as PackedScene
	if ps == null:
		return false
	var root := ps.instantiate()
	var live := source_stamp()
	if live != "" and live != str(root.get_meta("stamp", "")) and not FileAccess.file_exists(LOCK):
		push_warning("Woods: the generators changed since %s was compiled; building live. Run tools/bake/compile_woods.gd." % COMPILED)
		root.free()
		return false
	_compiled = root
	compiled_used = true
	return true


## A static step: from the compiled woods when there is one (its nodes moved in, the generator left where the step
## would have left it), otherwise generated - and, when compiling, copied for the compiled file.
func _static_step(key: String, f: Callable) -> void:
	if _compiled == null and not compiling and not _tried_compiled:
		_tried_compiled = true
		_open_compiled()
	if _compiled != null:
		var group := _compiled.get_node(key)
		for n in group.get_children():
			group.remove_child(n)
			_unown(n)
			add_child(n)
		_brng.state = int(_compiled.get_meta("states")[key])
		return
	var before := {}
	for n in get_children():
		before[n] = true
	await f.call()
	if compiling:
		var copies: Array = []
		for n in get_children():
			if not before.has(n):
				copies.append(n.duplicate())
		recorded[key] = {"nodes": copies, "state": _brng.state}


var _tried_compiled := false


## The 1:16 land's world from the compiled woods (clouds aren't in it: they drift, so they're built live), or null.
func compiled_land_world() -> Node3D:
	if _compiled == null or not _compiled.has_node("sky"):
		return null
	var sky := _compiled.get_node("sky")
	var world: Node3D = sky.get_child(0)
	sky.remove_child(world)
	_unown(world)
	return world


## Nodes moved out of the compiled scene: no longer owned by it.
func _unown(n: Node) -> void:
	n.owner = null
	for c in n.get_children():
		_unown(c)


var _brng: RandomNumberGenerator


func _build() -> void:
	for step: Array in build_steps():
		await (step[1] as Callable).call()


## Everything that never moves again - rocks, logs, cattails, stepping stones, the lodge's sticks, lily pads, the
## bridge... - merged into one mesh per material per 24 m patch (GardenProps.merge_static): ~1300 fewer draw calls at
## the trailhead. What moves or answers a tap stays itself: finds, motes, willows, the campfire, the nursery, signs.
func _merge_static() -> void:
	if _compiled != null:
		_compiled.free()                                 # (its contents are in the woods now)
		_compiled = null
	if OS.get_environment("HEDGEPETS_NO_MERGE") != "":     # (benchmarks: the unmerged woods, for comparison)
		return
	var keep := {}
	for n in _fireflies + _willows_sway:
		keep[n] = true
	for f: Dictionary in _finds:
		keep[f["node"]] = true
	for n in [_pail, campfire, nursery, land]:
		if n != null:
			keep[n] = true
	var batch: Array = []
	for n in get_children():
		if not keep.has(n) and n is Node3D and (n as Node3D).visible and _static_meshes_only(n):
			batch.append(n)
	set_meta("merged", await GardenProps.merge_static(self, batch, 16.0))
	set_meta("merged_from", batch.size())
	_stream_prepare()
	quality_tier_changed(Quality.tier_name())


## Static woods geometry is grouped by its 24 m map cell. Only the cells around the current clearing are drawn;
## nothing is rebuilt while walking, so entering a new cell is a visibility change rather than a hitch.
func _stream_prepare() -> void:
	var keep := {cam: true, land: true, nursery: true, campfire: true, _ui: true}
	for n in get_children():
		if keep.has(n) or n is Camera3D or n is DirectionalLight3D or n is WorldEnvironment:
			continue
		if not n is GeometryInstance3D:
			continue
		var g := n as GeometryInstance3D
		var box := g.get_aabb()
		if maxf(box.size.x, box.size.z) > 40.0:
			continue
		var c: Vector3 = box.get_center() + n.position
		var key := Vector2i(floori(c.x / 24.0), floori(c.z / 24.0))
		if not _stream_chunks.has(key):
			var chunk := Node3D.new()
			chunk.name = "StreamChunk_%d_%d" % [key.x, key.y]
			chunk.set_meta("stream_key", key)
			add_child(chunk)
			_stream_chunks[key] = chunk
		n.reparent(_stream_chunks[key], true)
		g.set_meta("woods_stream_static", true)
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_stream_update(true)


func _stream_update(force := false) -> void:
	if _stream_chunks.is_empty() or cam == null:
		return
	# Keep all buckets present. GeometryInstance3D visibility ranges do the
	# actual culling, with a dither fade margin. A parent visibility toggle is a
	# hard, screen-wide pop at a cell boundary even when the children are distant.
	for chunk: Node3D in _stream_chunks.values():
		chunk.visible = true
	_stream_last = cam.position


func quality_tier_changed(tier: String) -> void:
	set_meta("quality_tier", tier)
	_stream_update(true)
	for node in find_children("*", "", true, false):
		if not node is GeometryInstance3D:
			continue
		var kind := str(node.get_meta("woods_lod_kind", ""))
		if kind == "leaves":
			node.visibility_range_end = _leaf_range(tier)
			node.visibility_range_end_margin = _fade_margin(tier)
			var leaves := node as MultiMeshInstance3D
			if leaves.multimesh != null:
				if not node.has_meta("woods_full_instances"):
					node.set_meta("woods_full_instances", leaves.multimesh.instance_count)
				var full := int(node.get_meta("woods_full_instances"))
				var centre: Vector3 = node.global_transform * _multimesh_centre(node, leaves.multimesh)
				var distance := Vector2(cam.global_position.x, cam.global_position.z).distance_to(Vector2(centre.x, centre.z))
				if tier == "low":
					var keep := 0.55 if distance < 14.0 else 0.18
					leaves.multimesh.visible_instance_count = maxi(1, int(full * keep))
				else:
					leaves.multimesh.visible_instance_count = -1
		elif kind == "mass":
			node.visibility_range_end = 120.0 if tier == "high" else 42.0 if tier == "low" else 58.0
			node.visibility_range_end_margin = _fade_margin(tier)
		elif kind == "trunk":
			node.visibility_range_end = 140.0 if tier == "high" else 48.0 if tier == "low" else 68.0
			node.visibility_range_end_margin = _fade_margin(tier)
		elif node.has_meta("woods_stream_static"):
			node.visibility_range_end = _stream_radius() + 10.0
			node.visibility_range_end_margin = _fade_margin(tier)


func _multimesh_centre(node: Node, multimesh: MultiMesh) -> Vector3:
	if node.has_meta("woods_local_centre"):
		return node.get_meta("woods_local_centre")
	var centre := Vector3.ZERO
	var samples := 0
	var step := maxi(1, ceili(multimesh.instance_count / 64.0))
	for i in range(0, multimesh.instance_count, step):
		centre += multimesh.get_instance_transform(i).origin
		samples += 1
	centre /= maxf(samples, 1)
	node.set_meta("woods_local_centre", centre)
	return centre


func _stream_radius() -> float:
	match str(get_meta("quality_tier", "medium")):
		"low": return STREAM_RADIUS_LOW
		"high": return STREAM_RADIUS_HIGH
	return STREAM_RADIUS


func _fade_margin(tier: String) -> float:
	return 6.0 if tier == "low" else 8.0 if tier == "medium" else 12.0


func _leaf_range(tier: String) -> float:
	return 120.0 if tier == "high" else 24.0 if tier == "low" else 36.0


func _static_meshes_only(n: Node) -> bool:
	if n.get_script() != null or not n.get_meta_list().is_empty():
		return false
	if n is MeshInstance3D:                              # small things only: never the ground, trails or tree patches
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			return false
		var size := mi.mesh.get_aabb().size * mi.scale.abs()
		return mi.material_override is StandardMaterial3D and maxf(size.x, maxf(size.y, size.z)) < 6.0
	if n.get_class() != "Node3D":
		return false
	if n.get_child_count() == 0:
		return false
	for c in n.get_children():
		if not _static_meshes_only(c):
			return false
	return true


func _build_trails() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 77
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.022
	_noise.fractal_octaves = 3
	_fine = FastNoiseLite.new()
	_fine.seed = 78
	_fine.frequency = 0.11
	_brng = RandomNumberGenerator.new()
	_brng.seed = 4242
	var rng := _brng
	for e: Array in EDGES:
		_paths.append({"a": e[0], "b": e[1], "pts": _trail(node_pos(e[0]), node_pos(e[1]), rng)})
	for id in NODES:
		_labels[id] = []
	for i in _paths.size():
		var e: Dictionary = _paths[i]
		_add_way(e["a"], e["b"], e["pts"], i)
		_add_way(e["b"], e["a"], _reversed(e["pts"]), i)
	_labels["trailhead"].append({"to": "garden", "dir": Vector3(0.3, 0, 1).normalized(), "name": "Home to the garden"})
	for sid in STUBS:
		var st: Dictionary = STUBS[sid]
		var from := node_pos(st["from"])
		var to2: Vector2 = Vector2(from.x, from.z) + (st["toward"] as Vector2)
		var pts := _trail(from, Vector3(to2.x, height(to2.x, to2.y), to2.y), rng)
		_paths.append({"a": st["from"], "b": sid, "pts": pts, "stub": true})
		_labels[st["from"]].append({"to": sid, "dir": _dir_of(pts), "name": "%s (overgrown)" % st["name"], "stub": true})
		_brambles(pts[pts.size() - 1], rng)
	_smooth_trails()
	_index_trails()
	_densify_trails()
	_carve = true                                        # from here on the ground is shaped to the trails


func _build_land() -> void:
	await _ground(_brng)
	for e in _paths:
		await Slicer.tick(self)
		_ribbon(e["pts"], e.get("stub", false))
	await Slicer.tick(self)
	_home_way()
	await _trail_litter(_brng)


func _build_trees() -> void:
	await _trees(_brng)                                  # trees are code-driven entities (never compiled): the base map is
	_willows(_brng)                                      # what's compiled; willows sway: always built live
	_asters()


func _build_undergrowth() -> void:
	await _undergrowth(_brng)
	await _forest_floor(_brng)


func _build_places() -> void:
	await _clearings(_brng)
	await Slicer.tick(self)
	_pine_flats()
	for id in _labels:
		await Slicer.tick(self)
		for way: Dictionary in _labels[id]:
			await Slicer.tick(self)
			way["label"] = _sign(id, way["dir"], str(way["name"]))
			way["marks"] = _chevrons(id, way)
	_setup_ravine_viewer()


func _build_sky() -> void:
	var rng := _brng
	var to_sun := TO_SUN.normalized()
	land = preload("res://scripts/garden/distant_land.gd").new()   # the land beyond: a 1:16 miniature (3D skybox)
	add_child(land)
	await land.setup(self, to_sun, compiled_land_world())
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe4b8")
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 24.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY                # behind everything: the distant land's picture
	env.sky = land.sky_for_woods()
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("56697a")                 # the shade is blue - but light enough to see the path
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("47637a")                     # and the distance is a blue haze
	env.fog_density = 0.0055                                  # matched by the distant land's baked haze at the edge
	env.fog_sky_affect = 0.0
	env.fog_height = ORIGIN.y + node_pos("ridge").y - 9.0       # mist lies in the low ground; the ridge is above it
	env.fog_height_density = 0.06
	_sunbeams(rng, to_sun)
	cam.environment = env


func _build_nursery() -> void:
	cam.fov = 70.0
	cam.near = 0.08
	_pail = GardenProps.paint_bucket(self, Vector3.ZERO, 0.0)
	_pail.visible = false
	# it stands on the side of its clearing away from both its trails (the fork's, the pines'): not on a trail, not up
	# the slope to the pine flats behind, and in front of you when you arrive (_nursery_heading)
	var away := Vector3.ZERO
	for way: Dictionary in _labels["nursery"]:
		away -= (way["dir"] as Vector3)
	away.y = 0.0
	if away.length() < 0.1:
		away = (_labels["nursery"][0]["dir"] as Vector3).cross(Vector3.UP)
	nursery = preload("res://scripts/garden/nursery.gd").new()
	add_child(nursery)
	nursery.setup(self, node_pos("nursery"), away.normalized())
	_place_finds()
