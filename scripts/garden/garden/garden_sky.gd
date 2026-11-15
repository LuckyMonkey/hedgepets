extends "res://scripts/garden/garden/garden_layout.gd"

## Garden 2/6 - the sky: the sun through the day, weather and fog, light shafts, the soundscape.
##
## The light and the weather. The sun moves with the real hour (sun_at); weather() picks the day's weather (fog is
## occasional). Light shafts are the slanted sunbeams through the trees. The soundscape (soundscape.gd) starts here
## because it follows the time of day too.
##
## Part of the garden layer chain (the full order is at the top of scripts/garden/garden.gd). Code here was moved verbatim
## from the old single file; only its place changed.

# ------------------------------------------------------------------ the sun
## The sun follows the real time of day: up in the east over the woods in the morning, round the south over the
## houses at midday, down in the west past the creek in the evening, golden when it's low. At night it holds a soft
## dusk (nothing goes dark: no punishing a late visit). Shafts of light slant down through the trees along it,
## strongest when the sun is low. HEDGEPETS_HOUR=16.5 pins the hour (captures, checks).
var _shafts: Array = []
var _sun_goal := Basis.IDENTITY
var _sun_check := 0.0


## The weather of the day (owner 2026-11-13: "the fog is heavy and hazy - let it happen occasionally, not all the
## time"). One per calendar day, the same all day (nothing to catch or miss): mostly clear, sometimes a light haze, now
## and then a misty day; and on any day an early-morning mist that lifts by noon. Clear air is cooler and bluer with
## distance, mist is the old sage. HEDGEPETS_WEATHER=clear|haze|mist pins it; captures and checks (HEDGEPETS_HOUR) keep
## the misty look they were made with.
const WEATHER_FOG := {"clear": 0.0035, "haze": 0.006, "mist": 0.01}
var _env: Environment
var _fog_goal := 0.01


func weather() -> String:
	var pinned := OS.get_environment("HEDGEPETS_WEATHER")
	if WEATHER_FOG.has(pinned):
		return pinned
	if OS.get_environment("HEDGEPETS_HOUR") != "":
		return "mist"
	var d := Time.get_date_dict_from_system()
	var roll := absi(hash("%d-%d-%d" % [d["year"], d["month"], d["day"]])) % 100
	return "mist" if roll < 10 else ("haze" if roll < 40 else "clear")


func fog_at(hour: float) -> float:
	var base: float = WEATHER_FOG[weather()]
	var morning := 1.0 - smoothstep(8.0, 12.0, hour)          # early mist, lifting by noon
	return lerpf(base, maxf(base, 0.011), morning * 0.8)


## Fog and its colour for a density: the garden's, and the neighbourhood miniature's (its own world, the same air).
func _apply_fog(density: float) -> void:
	if _env == null:
		return
	var clear := clampf((0.01 - density) / (0.01 - 0.0035), 0.0, 1.0)
	var tint := Color("a7b37a").lerp(Color("b2bfc2"), clear * 0.75)
	_env.fog_density = density
	_env.fog_light_color = tint
	if neighborhood != null:
		neighborhood.set_air(density, tint)


func _hour() -> float:
	if OS.get_environment("HEDGEPETS_HOUR") != "":
		return float(OS.get_environment("HEDGEPETS_HOUR"))
	var t := Time.get_datetime_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0


## Where the sun is (a unit vector toward it), how low it is (0 = horizon .. 1 = noon), for an hour of the day.
func sun_at(hour: float) -> Array:
	var day := clampf((hour - 6.0) / 14.0, 0.04, 0.96)         # 06:00 .. 20:00; outside that, a held dusk / dawn
	var theta := day * PI                                       # east (+x) .. south (+z) .. west (-x)
	var el := deg_to_rad(lerpf(9.0, 58.0, sin(day * PI)))
	var to_sun := Vector3(cos(theta) * cos(el), sin(el), sin(theta) * cos(el)).normalized()
	return [to_sun, sin(day * PI)]


func _build_sun() -> void:
	var s: Array = sun_at(_hour())
	_aim_sun(s, true)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/light_shaft.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2210
	for i in range(5):
		# where light gets through the canopy: near the edges of the yard, under the trees
		var a := rng.randf() * TAU
		var hit := Vector3(cos(a) * rng.randf_range(7.0, 11.0), 0, sin(a) * rng.randf_range(5.5, 8.5) - 1.0)
		var shaft := Node3D.new()
		shaft.name = "LightShaft"
		add_child(shaft)
		var mat_i := m.duplicate() as ShaderMaterial
		mat_i.set_shader_parameter("seed", rng.randf())
		for k in range(2):                                      # two crossed cards: a shaft from any side
			var card := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(rng.randf_range(0.6, 1.3), 18.0)
			card.mesh = q
			card.material_override = mat_i
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			card.rotation.y = k * PI * 0.5
			card.position = Vector3(0, 9.0, 0)
			shaft.add_child(card)
		_shafts.append({"node": shaft, "hit": hit, "mat": mat_i})
	_place_shafts(s)


func _aim_sun(s: Array, at_once: bool) -> void:
	var to_sun: Vector3 = s[0]
	var low: float = 1.0 - float(s[1])
	_sun_goal = Basis.looking_at(-to_sun, Vector3.UP)
	if at_once:
		sun.basis = _sun_goal
	sun.light_color = Color(1.0, 0.93, 0.82).lerp(Color(1.0, 0.72, 0.45), low * low)
	sun.light_energy = lerpf(0.55, 0.78, float(s[1]))


func _place_shafts(s: Array) -> void:
	var to_sun: Vector3 = s[0]
	var low: float = 1.0 - float(s[1])
	for sh in _shafts:
		var node: Node3D = sh["node"]
		node.position = sh["hit"]
		# the shaft's long axis points back up toward the sun
		var up := to_sun
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		node.basis = Basis(side, up, side.cross(up).normalized())
		(sh["mat"] as ShaderMaterial).set_shader_parameter("strength", lerpf(0.008, 0.028, low))   # a hint, not a searchlight
		(sh["mat"] as ShaderMaterial).set_shader_parameter("colour", sun.light_color)


func _tend_sun(delta: float) -> void:
	_sun_check -= delta
	if _sun_check <= 0.0:
		_sun_check = 30.0
		var s: Array = sun_at(_hour())
		_aim_sun(s, false)
		_place_shafts(s)
		_fog_goal = fog_at(_hour())
	if _env != null and absf(_env.fog_density - _fog_goal) > 0.00002:   # the air changes slowly, never jumps
		_apply_fog(move_toward(_env.fog_density, _fog_goal, delta * 0.0002))
	sun.basis = sun.basis.orthonormalized().slerp(_sun_goal.orthonormalized(), clampf(delta * 0.05, 0.0, 1.0))   # glides, never jumps (re-squared: slerping drifts)


## The backyard, heard (scripts/garden/soundscape.gd).
func _build_sounds() -> void:
	var sounds := preload("res://scripts/garden/soundscape.gd").new()
	sounds.name = "Soundscape"
	add_child(sounds)
	sounds.setup(self)


var neighborhood: Node                            # scripts/garden/neighborhood.gd: the street, the houses, the town (skybox)
