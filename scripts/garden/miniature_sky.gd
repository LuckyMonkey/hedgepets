class_name MiniatureSky
extends Node

## A Source-engine-style 3D skybox: a 1:SCALE miniature world in its own SubViewport, its camera copying the host
## camera every frame (same turn and field of view, position divided by SCALE), its picture drawn behind everything
## as the host's sky (shaders/distant_sky.gdshader projects each sky direction through the matched camera). Used by
## the woods (distant_land.gd: the land beyond) and the garden (neighborhood.gd: the street, the houses, the town).
## A subclass builds the world; this is the machinery they share.
const SCALE := 16.0

var res := 0.6                                       # of the screen's resolution
var view: SubViewport
var sky_cam: Camera3D
var _sky_mat: ShaderMaterial
var _t := 0.0
var _host_vp: Viewport


## Make the viewport, its world (or adopt a ready-made one) and its camera; returns the world to build in.
func _make_view(host_vp: Viewport, env: Environment, world: Node3D = null) -> Node3D:
	_host_vp = host_vp
	view = SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.positional_shadow_atlas_size = 0
	add_child(view)
	if world == null:
		world = Node3D.new()
	world.name = "World"
	view.add_child(world)
	sky_cam = Camera3D.new()
	sky_cam.near = 0.05
	sky_cam.far = 1400.0
	sky_cam.keep_aspect = Camera3D.KEEP_WIDTH
	sky_cam.environment = env
	view.add_child(sky_cam)
	host_vp.size_changed.connect(_fit)
	_fit()
	return world


func _fit() -> void:
	var s := _host_vp.get_visible_rect().size if _host_vp != null else Vector2(540, 960)
	view.size = Vector2i(maxi(64, int(s.x * res)), maxi(64, int(s.y * res)))


func show_land(on: bool) -> void:
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		_fit()


## Follow the host camera: same turn and field of view, its position (host-local) scaled down.
func follow(cam: Camera3D, local_pos: Vector3, delta: float) -> void:
	_t += delta
	sky_cam.position = local_pos / SCALE
	sky_cam.rotation = cam.rotation
	sky_cam.fov = cam.fov
	if _sky_mat != null:                              # how the host's sky finds this picture's pixels
		var s := _host_vp.get_visible_rect().size
		_sky_mat.set_shader_parameter("view_inv", cam.global_basis.orthonormalized().transposed())
		_sky_mat.set_shader_parameter("tan_half_w", tan(deg_to_rad(cam.fov) * 0.5))
		_sky_mat.set_shader_parameter("aspect", s.x / maxf(s.y, 1.0))
	_tick(delta)


## Per-frame extras for a subclass (drifting clouds...).
func _tick(_delta: float) -> void:
	pass


## The host's sky: this miniature's picture, behind everything. `soften` blurs it a touch (pixels) - a low-poly
## miniature reads as distance under the garden's tilt-shift.
func sky_for_woods(fallback := Color(0.77, 0.83, 0.86), soften := 0.0) -> Sky:
	var m := ShaderMaterial.new()
	_sky_mat = m
	m.shader = preload("res://shaders/distant_sky.gdshader")
	m.set_shader_parameter("land", view.get_texture())
	m.set_shader_parameter("fallback", fallback)
	m.set_shader_parameter("soften", soften)
	var sky := Sky.new()
	sky.sky_material = m
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	return sky
