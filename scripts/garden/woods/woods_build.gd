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
var _stream_last := Vector3.INF


var _pail: Node3D
var nursery: Node3D                   # nursery.gd
# ------------------------------------------------------------------ building it (once)
## Built in steps (Elsewhere shows a loading card between them; the bake runs them all at once).
func build_steps() -> Array:
	return [["Finding the trails", _build_trails],
		["Shaping the hills and the creek", _layered.bind("Ground", _static_step.bind("land", _build_land))],
		["Growing the trees", _layered.bind("Trees", _build_trees)],
		["Ferns and fallen logs", _layered.bind("Undergrowth", _static_step.bind("undergrowth", _build_undergrowth))],
		["The old oak, the pond, the signs", _layered.bind("Places", _build_places)],
		["Letting the sun in", _layered.bind("Sky", _build_sky)],
		["Down to the nursery", _layered.bind("NurseryGlade", _build_nursery)],
		["Applying woods placements", _apply_overrides], ["Tidying up", _merge_static]]


## The woods' layers in the scene tree: one node per build step, so the remote scene tree (and the woods view in the
## editor) reads Ground / Trees / Undergrowth / Places / Sky / NurseryGlade instead of thousands of loose nodes. A layer
## is a plain Node3D at the woods' origin: positions inside it are woods positions.
const LAYERS := ["Ground", "Trees", "Undergrowth", "Places", "Sky", "NurseryGlade"]   # ("NurseryGlade": the nursery node itself is "Nursery")


## Runs one build step, then moves whatever it added to the woods into that step's layer.
func _layered(layer: String, step: Callable) -> void:
	var before := {}
	for n in get_children():
		before[n] = true
	await step.call()
	var holder := _layer(layer)
	if holder == null:
		holder = Node3D.new()
		holder.name = layer
		holder.set_meta("woods_layer", true)
		add_child(holder)
	for n in get_children():
		# (the distant land stays at the root: its SubViewport's picture is the woods' sky)
		if not before.has(n) and n != holder and n != cam and n != _ui and n != land:
			n.reparent(holder, false)


## Every layer node built so far.
func layers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for name_: String in LAYERS:
		var n := _layer(name_)
		if n != null:
			out.append(n)
	return out


## A layer node by name, only if it really is one (made by _layered, marked woods_layer).
func _layer(name_: String) -> Node3D:
	var n := get_node_or_null(name_) as Node3D
	return n if n != null and n.has_meta("woods_layer") else null


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
const SOURCES := [
	"res://scripts/garden/woods.gd",
	"res://scripts/garden/woods/woods_ground.gd",
	"res://scripts/garden/woods/woods_trails.gd",
	"res://scripts/garden/woods/woods_scenery.gd",
	"res://scripts/garden/woods/woods_landmarks.gd",
	"res://scripts/garden/woods/woods_finds.gd",
	"res://scripts/garden/woods/woods_build.gd",
	"res://scripts/garden/woods_trees.gd",
	"res://scripts/art/tree_factory.gd",
	"res://scripts/garden/distant_land.gd",
	"res://scripts/garden/land/land_terrain.gd",
	"res://scripts/garden/land/land_forest.gd",
	"res://scripts/garden/land/land_landmarks.gd",
	"res://scripts/garden/garden_props.gd",
	"res://scripts/garden/props/props_kit.gd",
	"res://scripts/garden/props/props_yard.gd",
	"res://scripts/garden/props/props_builds.gd",
	"res://scripts/garden/props/props_surroundings.gd",
	"res://scripts/art/foliage_builder.gd",
	"res://scripts/art/hedge_anatomy.gd",
]
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
	var merged := 0
	var merged_from := 0
	for layer in layers():                               # merged within each layer, so the layers stay what they say
		var batch: Array = []
		for n in layer.get_children():
			if not keep.has(n) and n is Node3D and (n as Node3D).visible and _static_meshes_only(n):
				batch.append(n)
		merged += await GardenProps.merge_static(layer, batch, 16.0)
		merged_from += batch.size()
	set_meta("merged", merged)
	set_meta("merged_from", merged_from)
	_stream_prepare()
	quality_tier_changed(Quality.tier_name())


## Static woods geometry is drawn by distance: each mesh fades out past the stream radius (visibility ranges, set in
## quality_tier_changed), so nothing is rebuilt or reparented while walking. (It used to be regrouped into 24 m
## "StreamChunk" nodes; those were always visible by then, so they only scrambled the layers.)
func _stream_prepare() -> void:
	var keep := {cam: true, land: true, nursery: true, campfire: true, _ui: true}
	for layer in layers():
		for n in layer.find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if g.has_meta("woods_lod_kind") or _inside_kept(g, keep):
				continue
			var box := g.get_aabb()
			if maxf(box.size.x, box.size.z) > 40.0:
				continue
			g.set_meta("woods_stream_static", true)
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Whether n is, or is inside, one of the kept nodes (animated or interactive: never streamed).
func _inside_kept(n: Node, keep: Dictionary) -> bool:
	var p := n
	while p != null and p != self:
		if keep.has(p):
			return true
		p = p.get_parent()
	return false


func _stream_update(_force := false) -> void:
	if cam != null:
		_stream_last = cam.position


func quality_tier_changed(tier: String) -> void:
	set_meta("quality_tier", tier)
	_stream_update(true)
	TreeFactory.set_detail(tier)                     # how soon far trees thin to their crown leaves
	for node in find_children("*", "", true, false):
		if not node is GeometryInstance3D:
			continue
		var kind := str(node.get_meta("woods_lod_kind", ""))
		if kind in ["leaves", "mass", "trunk"]:      # a tree's parts go together: never a bare trunk or a floating crown
			node.visibility_range_end = _leaf_range(tier)
			node.visibility_range_end_margin = _fade_margin(tier)
		elif node.has_meta("woods_stream_static"):
			node.visibility_range_end = _stream_radius() + 10.0
			node.visibility_range_end_margin = _fade_margin(tier)


func _stream_radius() -> float:
	match str(get_meta("quality_tier", "medium")):
		"low": return STREAM_RADIUS_LOW
		"high": return STREAM_RADIUS_HIGH
	return STREAM_RADIUS


func _fade_margin(tier: String) -> float:
	return 6.0 if tier == "low" else 8.0 if tier == "medium" else 12.0


## How far trees (trunks, cores and leaves alike) are drawn.
func _leaf_range(tier: String) -> float:
	return 140.0 if tier == "high" else 48.0 if tier == "low" else 68.0


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
