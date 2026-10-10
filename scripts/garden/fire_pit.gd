extends Node3D

## A fire pit: a ring of stones round a few split logs. ✋ on it lights it: flames lick up, it crackles and glows warm
## on everything near it, and burns down over a few minutes to embers, then out. Light it again whenever you like.
## Built with 🧺 in the garden (garden_game.BUILDS), and there's one in the woods at fern hollow (woods.gd).

const BURN := 240.0                      # seconds of flame, then embers for EMBERS
const EMBERS := 90.0

var _fire := 0.0                         # seconds of burning left (flame + embers)
var _t := 0.0
var _flames: Array = []
var _light: OmniLight3D
var _glow := 0.0


static func build(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var r: Node3D = preload("res://scripts/garden/fire_pit.gd").new()
	r.name = "FirePit"
	r.position = at
	r.rotation_degrees.y = yaw
	parent.add_child(r)
	r._build()
	return r


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var stone := GardenProps.mat("pitstone", Color("8a8478"))
	for k in range(9):
		var a := k * TAU / 9.0
		GardenProps.part(self, GardenProps.blob(Vector3(0.17, 0.12, 0.13) * rng.randf_range(0.85, 1.15), "pebble"), stone, Vector3(cos(a), 0.0, sin(a)) * 0.5 + Vector3(0, 0.08, 0), Vector3(0, -rad_to_deg(a), 0), 0.006)
	GardenProps.part(self, GardenProps.blob(Vector3(0.42, 0.03, 0.42), "pebble"), GardenProps.mat("ash", Color("3a3430")), Vector3(0, 0.02, 0), Vector3.ZERO, 0.0)
	var wood := GardenProps.mat("splitlog", Color("6a4a30"))
	for k in range(3):
		GardenProps.part(self, GardenProps.cyl(0.05, 0.06, 0.6, 7), wood, Vector3(0, 0.14, 0), Vector3(55, k * 120.0, 0), 0.005).position += Vector3(cos(k * TAU / 3.0), 0, sin(k * TAU / 3.0)) * 0.1
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color("ffb04a")
	flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame.albedo_color.a = 0.85
	var core := flame.duplicate() as StandardMaterial3D
	core.albedo_color = Color(1.0, 0.92, 0.6, 0.9)
	for k in range(5):
		var f := MeshInstance3D.new()
		f.mesh = GardenProps.blob(Vector3(0.09, 0.26, 0.09), {"exponent": 2.0, "taper": 0.8}, 8, 10)
		f.material_override = core if k == 0 else flame
		f.position = Vector3(cos(k * 1.3), 0, sin(k * 1.3)) * (0.0 if k == 0 else 0.1) + Vector3(0, 0.3, 0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.scale = Vector3.ONE * 0.001
		f.set_meta("phase", k * 1.7)
		add_child(f)
		_flames.append(f)
	_light = OmniLight3D.new()
	_light.light_color = Color("ffa050")
	_light.light_energy = 0.0
	_light.omni_range = 6.0
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)


func lit() -> bool:
	return _fire > EMBERS


## ✋: light it (or, lit, just enjoy it).
func tapped(game: Node) -> void:
	if lit():
		game.toast(["🔥 The fire crackles.", "🔥 Warm. Somebody might come and sit by it.", "🔥 Sparks go up into the dark."].pick_random())
		return
	_fire = BURN + EMBERS
	Telemetry.event("fire")
	game.toast("🔥 You light the fire. It'll burn a good while.")


func _process(delta: float) -> void:
	_t += delta
	_fire = maxf(0.0, _fire - delta)
	var want := 1.0 if _fire > EMBERS else (0.25 * _fire / EMBERS)
	_glow = Motion.approach(_glow, want, 1.5, delta)
	_light.light_energy = _glow * (2.4 + 0.5 * sin(_t * 9.0) + 0.3 * sin(_t * 23.0))
	for f: MeshInstance3D in _flames:
		var ph: float = f.get_meta("phase")
		var flick := 0.8 + 0.25 * sin(_t * 11.0 + ph) + 0.12 * sin(_t * 27.0 + ph * 2.0)
		f.scale = Vector3(1.0, flick, 1.0) * maxf(_glow, 0.001) * (1.0 if _glow > 0.3 else 0.6)
		f.visible = _glow > 0.02
