class_name BakeCache
extends RefCounted

## Startup cache for expensive, deterministic geometry: the garden's tree / hedge foliage (FoliageBuilder) and its
## stone, slate and rock meshes (HedgeAnatomy.build_mesh). Built in GDScript they take ~17 s on a desktop CPU,
## minutes on a phone; read from res://assets/baked/garden.res they take a moment. Same data, same look.
##
## Correctness:
##   - A key is the full set of inputs (sizes, shapes, palettes, seeds), so a changed call is simply a miss: built
##     live, as before.
##   - SALT = a fingerprint of the generator code. In the editor, if the generators changed since the bake, the whole
##     cache is ignored (everything is built live) and a warning says to rebake. In an export the code can't be
##     read, so the baked fingerprint is trusted: rebake before exporting (tools/bake_cache.gd).
##   - Nothing is ever written during play: only tools/bake_cache.gd (BakeCache.recording = true) writes the file.

const PATH := "res://assets/baked/garden.res"
## Code whose output is cached but not fully described by its keys: the woods' tree patches are keyed by patch only
## (woods.gd places, woods_trees.gd builds), the grass by its inputs but not its algorithm (garden.gd). A change to any
## of these makes the editor ignore the bake (built live, with a warning) instead of reading stale geometry.
const GENERATORS := ["res://scripts/art/foliage_builder.gd", "res://scripts/art/hedge_anatomy.gd", "res://scripts/util/bake_cache.gd",
	"res://scripts/garden/garden.gd", "res://scripts/garden/woods.gd", "res://scripts/garden/woods_trees.gd"]

static var recording := false
static var _data: BakedData
static var _usable := -1          # -1 unknown, 0 no, 1 yes
static var hits := 0
static var _memory := {}           # this run's own results (never saved): a tuned pet reuses its unchanged parts
static var misses := 0
## Recording only: what each entry belongs to ("garden", "woods", "pet:Gerald"...) and which generator made it, for the
## size manifest tools/bake_cache.gd writes (build/cache_manifest.json). Never shipped in the cache itself.
static var label := ""
static var labels := {}
## Diagnostics (tools/cache_usage.gd): with `track` on, every key read from the baked data is noted in `touched`.
static var track := false
static var touched := {}
## A composite build (a garden bush: its core mesh + its leaves, stored together under one key) doesn't record the
## pieces it was made from: the game reads the composite, never the pieces (measured: tools/cache_usage.gd).
static var _composite := 0


static func begin_composite() -> void:
	_composite += 1


static func end_composite() -> void:
	_composite -= 1


## Fingerprint of the generator sources, or "" where they can't be read (an exported game).
static func live_salt() -> String:
	var all := ""
	for path in GENERATORS:
		if not FileAccess.file_exists(path):
			return ""
		var text := FileAccess.get_file_as_string(path)
		if text == "":
			return ""
		all += text
	return all.sha256_text().substr(0, 16)


static func _ready_data() -> bool:
	if _usable >= 0:
		return _usable == 1
	_usable = 0
	if recording:
		_data = BakedData.new()
		_data.salt = live_salt()
		_usable = 1
		return true
	if not ResourceLoader.exists(PATH):
		return false
	_data = load(PATH) as BakedData
	if _data == null:
		return false
	var live := live_salt()
	if live != "" and live != _data.salt:
		push_warning("BakeCache: the foliage / anatomy code changed since %s was baked; building live. Run tools/bake_cache.gd." % PATH)
		_data = null
		return false
	_usable = 1
	return true


static func key(parts: Array) -> String:
	return var_to_str(parts).sha256_text().substr(0, 24)


static func fetch(k: String) -> Variant:
	if not recording and _memory.has(k):
		hits += 1
		return _memory[k]
	if recording or not _ready_data():
		misses += 1
		return null
	var v = _data.items.get(k)
	if v == null:
		misses += 1
	else:
		hits += 1
		if track:
			touched[k] = true
	return v


static func store(k: String, value: Variant) -> void:
	if recording:
		var gen := "?"
		for f in get_stack().slice(1):
			if not str(f["source"]).ends_with("bake_cache.gd"):
				gen = "%s:%s" % [str(f["source"]).get_file().get_basename(), f["function"]]
				break
		labels[k] = [label, gen]
	if recording and _composite > 0:
		return                                           # a piece of a composite: the composite is what's kept
	if recording and _ready_data():
		_data.items[k] = value
	elif not recording:
		if _memory.size() > 600:
			_memory.clear()
		_memory[k] = value


static func save() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	return ResourceSaver.save(_data, PATH, ResourceSaver.FLAG_COMPRESS)


static func reset() -> void:
	_data = null
	_usable = -1
	hits = 0
	misses = 0
