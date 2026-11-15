extends "res://scripts/garden/land/land_landmarks.gd"

## The land beyond the woods, as a 1:16 miniature in its own world (the "3D skybox" of the Source engine's sky_camera):
## a SubViewport holds the model and a camera that copies the woods camera - same turn, same field of view, its
## position divided by SCALE - so walking a trail gives true parallax: near hills slide, far mountains barely move.
## Its picture becomes the woods' sky (shaders/distant_sky.gdshader projects each sky direction through the matched
## camera to find its pixel), drawn per pixel behind
## everything in the woods, so the two worlds never share a depth buffer. (A canvas background, the first try, drew
## over the 3D in the Compatibility renderer.)
##
## The model: rolling New England hills under forest, a valley to the east-northeast (the ridge's view) with a lake,
## an island, farm fields and a white village with a church steeple; landmarks you can find again from different
## clearings - THE MOUNTAIN (a granite dome with a bare summit) out past the ridge, the twin peaks to the north, the
## long ridge to the west with its fire tower - and a blue far range all round. Clouds, haze, the sun where the
## woods' sun is. Everything near the middle sits low, under the woods' own ground (which is drawn over it).
## Built once (fixed seeds); rendered at RES of the screen; only while you're in the woods.


##
## This file is the top of a layer chain (scripts/garden/land/):
##   land_terrain -> land_forest -> land_landmarks -> distant_land.gd (here: setup, ticking, quality, environment)

var _cloud_tick := 0.0
var _forest_cluster: FastNoiseLite

func setup(woods: Node3D, to_sun: Vector3, compiled_world: Node3D = null) -> void:
	name = "DistantLand"
	_woods = woods
	_noise = FastNoiseLite.new()
	_noise.seed = 1716
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_hills = FastNoiseLite.new()
	_hills.seed = 1717
	_hills.frequency = 0.045
	_forest_noise = FastNoiseLite.new()
	_forest_noise.seed = 271828
	_forest_noise.frequency = 0.024
	_forest_noise.fractal_octaves = 3
	_forest_cluster = FastNoiseLite.new()
	_forest_cluster.seed = 271829
	_forest_cluster.frequency = 0.075
	_forest_cluster.fractal_octaves = 2
	var world := _make_view(woods.get_viewport(), _environment(), compiled_world)   # (compiled: terrain, forest... ready made)
	_toy_y = INF
	_toy_y = _own_height_raw(TOY_GARDEN.x, TOY_GARDEN.y)
	if compiled_world == null:
		var sun := DirectionalLight3D.new()
		sun.light_color = Color("ffe4b8")
		sun.light_energy = 1.1
		sun.shadow_enabled = false
		sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
		world.add_child(sun)
		await _terrain(world)
		_lake(world)
		await _forest(world)
		_village(world)
		_toy_garden(world)
		_fire_tower(world)
	_clouds_build(world)


func _tick(delta: float) -> bool:
	# The land is a skybox, not a foreground animation. Redrawing its trees, snags,
	# hills and clouds at 12 Hz made an otherwise still woods camera hitch on phones.
	# Keep the cloud card still; MiniatureSky redraws when the matched camera pose changes.
	return false


func quality_tier_changed(tier: String) -> void:
	# The miniature is a texture-backed sky. On the low tier, spend fewer pixels
	# on it; the near woods carry the readable detail. Keep a little overscan so
	# camera turns still cannot expose the fallback colour at the edge.
	res = 0.42 if tier == "low" else 0.52 if tier == "medium" else 0.60
	_fit()


func _environment() -> Environment:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5a86b4")
	sky.sky_horizon_color = Color("c4d4dc")
	sky.ground_bottom_color = Color("2c3c34")
	sky.ground_horizon_color = Color("8aa0ac")
	sky.sun_angle_max = 8.0
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a7088")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true                            # air between you and the hills: further = bluer, paler
	env.fog_light_color = Color("b2c4ce")
	env.fog_density = 0.0012                          # (the haze is baked into the colours; this only softens the horizon)
	env.fog_sky_affect = 0.0
	env.fog_height = -2.0
	env.fog_height_density = 0.08                     # and mist in the low ground
	return env
