class_name WorldOverrides
extends Resource

## Authored changes to the generated world: the world editor's data (scripts/world/world_editor.gd).
## The garden is still generated exactly as before - same calls, same order, same random numbers - and these are
## applied to the finished objects afterwards, by stable id (garden.things[i].id, "<kind>_<index>"). So an empty or
## missing file changes nothing, and moving one thing can never shift another.
## Applied before the player's save is read (garden_game.setup), so the player's own moves still win.
##   things: id -> {"position": Vector3, "yaw": float (radians), "scale": Vector3, "hidden": bool}

const PATH := "res://world/garden_overrides.tres"

@export var version := 1
@export var things := {}


## The overrides in use: HEDGEPETS_WORLD=path (tools, tests) or PATH; an empty set when there's no file.
static func current() -> WorldOverrides:
	var path := OS.get_environment("HEDGEPETS_WORLD")
	if path == "":
		path = PATH
	if ResourceLoader.exists(path):
		var r := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as WorldOverrides
		if r != null:
			return r
	return WorldOverrides.new()


static func save_to(o: WorldOverrides, path := "") -> Error:
	if path == "":
		path = OS.get_environment("HEDGEPETS_WORLD") if OS.get_environment("HEDGEPETS_WORLD") != "" else PATH
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return ResourceSaver.save(o, path)


## Put one thing where an override says. `at` (where pets see it) keeps its offset from the node, turned with it.
static func apply_one(t: Dictionary, o: Dictionary) -> void:
	var node: Node3D = t["node"]
	var offset: Vector2 = t["at"] - Vector2(node.position.x, node.position.z)
	var yaw0 := node.rotation.y
	if o.has("position"):
		node.position = o["position"]
	if o.has("yaw"):
		node.rotation.y = float(o["yaw"])
		offset = offset.rotated(-(float(o["yaw"]) - yaw0))      # Godot's +yaw turns x toward -z
	if o.has("scale"):
		node.scale = o["scale"]
	t["at"] = Vector2(node.position.x, node.position.z) + offset
	if o.get("hidden", false):
		node.visible = false
		t["hidden"] = true


## Apply every override to the garden's things; returns the ids that matched (unknown ids are reported, not fatal).
func apply(garden: Node) -> Array:
	var done: Array = []
	if things.is_empty():
		return done
	var hidden: Array = []
	for t in garden.things:
		if things.has(t["id"]):
			apply_one(t, things[t["id"]])
			done.append(t["id"])
			if t.get("hidden", false):
				hidden.append(t)
	for t in hidden:                                     # a hidden thing is gone from play, like a cleared one
		garden.things.erase(t)
		if garden.hideouts != null:
			garden.hideouts.remove_spot(t)
	for id in things:
		if not done.has(id):
			push_warning("WorldOverrides: no thing with id %s (generator changed?)" % id)
	return done
