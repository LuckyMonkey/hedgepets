class_name FilmShot
extends Resource

## One shot of a film (FilmProject): a camera move as keyframes, and events that trigger the game's own behaviours.
##   keys: [{t: seconds, eye: Vector3, look: Vector3, fov: float, track: "<pet name>" (optional: look at that pet)}]
##   events: [{t: seconds, kind: "tap" | "shake" | "emote" | "sleep" | "wake", pet: "<name>", arg: String}]
## The camera at any time is a pure function of these keys (FilmShot.camera_at), so a frame is reproducible.

@export var title := "shot"
@export var duration := 3.0
@export var keys: Array = []
@export var events: Array = []


func sorted_keys() -> Array:
	var k := keys.duplicate()
	k.sort_custom(func(a, b) -> bool: return float(a["t"]) < float(b["t"]))
	return k


## Camera pose at local time t: Catmull-Rom through the eye / look keys (C1-smooth, passes through every key), with
## eased ends; fov eased between keys. `pets` maps names to nodes for tracking keys.
func camera_at(t: float, pets := {}) -> Dictionary:
	var k := sorted_keys()
	if k.is_empty():
		return {}
	if k.size() == 1 or t <= float(k[0]["t"]):
		return _pose(k[0], k[0], k[0], k[0], 0.0, pets)
	if t >= float(k[-1]["t"]):
		return _pose(k[-1], k[-1], k[-1], k[-1], 0.0, pets)
	var i := 0
	while i < k.size() - 2 and t >= float(k[i + 1]["t"]):
		i += 1
	var a: Dictionary = k[i]
	var b: Dictionary = k[i + 1]
	var u := (t - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 0.0001)
	if i == 0:
		u = u * u * (3.0 - 2.0 * u) if k.size() == 2 else _ease_in(u)
	elif i == k.size() - 2:
		u = _ease_out(u)
	return _pose(k[maxi(i - 1, 0)], a, b, k[mini(i + 2, k.size() - 1)], u, pets)


func _ease_in(u: float) -> float:
	return u * u * (2.0 - u)          # starts at rest, leaves at the spline's speed


func _ease_out(u: float) -> float:
	return u * (1.0 + u - u * u)      # arrives at rest


func _look(key: Dictionary, pets: Dictionary) -> Vector3:
	if key.has("track") and pets.has(key["track"]) and is_instance_valid(pets[key["track"]]):
		return (pets[key["track"]] as Node3D).global_position + Vector3(0, 0.35, 0)
	return key["look"]


func _pose(p0: Dictionary, p1: Dictionary, p2: Dictionary, p3: Dictionary, u: float, pets: Dictionary) -> Dictionary:
	var eye: Vector3 = (p1["eye"] as Vector3).cubic_interpolate(p2["eye"], p0["eye"], p3["eye"], u)
	var look: Vector3 = _look(p1, pets).cubic_interpolate(_look(p2, pets), _look(p0, pets), _look(p3, pets), u)
	var fov := lerpf(float(p1.get("fov", 46.0)), float(p2.get("fov", 46.0)), u * u * (3.0 - 2.0 * u))
	return {"eye": eye, "look": look, "fov": fov}
