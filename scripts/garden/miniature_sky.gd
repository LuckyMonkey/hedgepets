class_name MiniatureSky
extends Node

## A Source-engine-style 3D skybox: a 1:SCALE miniature world in its own SubViewport, its camera copying the host
## camera every frame (same turn and field of view, position divided by SCALE), its picture drawn behind everything
## as the host's sky (shaders/distant_sky.gdshader projects each sky direction through the matched camera). Used by
## the woods (distant_land.gd: the land beyond) and the garden (neighborhood.gd: the street, the houses, the town).
## A subclass builds the world; this is the machinery they share.
const SCALE := 16.0

var res := 0.6                                       # of the screen's resolution
## The picture is a little wider than the screen: while the camera turns it is redrawn a frame late, and without the
## margin its edge (the shader's flat fallback colour) showed as a seam down the side of the sky.
const OVERSCAN := 1.1
var view: SubViewport
var sky_cam: Camera3D
var _sky_mat: ShaderMaterial
var _t := 0.0
var _host_vp: Viewport
var _shown := false
var _has_pose := false
var _last_pos := Vector3.ZERO
var _last_basis := Basis.IDENTITY
var _last_fov := -1.0
var _last_aspect := -1.0
var redraws := 0                                      # tools/pan_trace.gd: requested miniature frames


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
	var wanted := Vector2i(maxi(64, int(s.x * res * OVERSCAN)), maxi(64, int(s.y * res * OVERSCAN)))
	if view.size != wanted:
		view.size = wanted
		_request_redraw()


func show_land(on: bool) -> void:
	_shown = on
	view.render_target_update_mode = SubViewport.UPDATE_ONCE if on else SubViewport.UPDATE_DISABLED
	if on:
		_fit()
		_request_redraw()


## Follow the host camera: same turn and field of view, its position (host-local) scaled down.
func follow(cam: Camera3D, local_pos: Vector3, delta: float) -> void:
	_t += delta
	var pos := local_pos / SCALE
	var basis := cam.global_basis.orthonormalized()
	var pose_changed := not _has_pose or not pos.is_equal_approx(_last_pos) or not basis.is_equal_approx(_last_basis) \
		or not is_equal_approx(cam.fov, _last_fov)
	if pose_changed:
		sky_cam.position = pos
		sky_cam.rotation = cam.rotation
		sky_cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(cam.fov) * 0.5) * OVERSCAN))
		_last_pos = pos
		_last_basis = basis
		_last_fov = cam.fov
		_has_pose = true
	var s := _host_vp.get_visible_rect().size
	var aspect := s.x / maxf(s.y, 1.0)
	var projection_changed := pose_changed or not is_equal_approx(aspect, _last_aspect)
	if projection_changed and _sky_mat != null:       # how the host's sky finds this picture's pixels
		_sky_mat.set_shader_parameter("view_inv", basis.transposed())
		_sky_mat.set_shader_parameter("tan_half_w", tan(deg_to_rad(cam.fov) * 0.5) * OVERSCAN)
		_sky_mat.set_shader_parameter("aspect", aspect)
		_last_aspect = aspect
	if pose_changed or _tick(delta):
		_request_redraw()


## Per-frame extras for a subclass (drifting clouds...).
func _tick(_delta: float) -> bool:
	return false


func _request_redraw() -> void:
	if not _shown or view == null:
		return
	HitchLog.tag("sky")
	redraws += 1
	view.render_target_update_mode = SubViewport.UPDATE_ONCE


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
