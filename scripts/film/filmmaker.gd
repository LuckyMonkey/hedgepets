extends Node

## HedgePets Filmmaker (MVP): directs the real game - the real garden, pets, shaders, sun and soundscape - from a
## FilmProject. Two modes:
##
##   Preview (interactive):  godot --path . res://filmmaker.tscn -- --film=res://films/demo/project.tres
##     Space play / pause · ← → step a frame · Home start · K add a key at the current camera to the current shot ·
##     N new shot at the playhead · C toggles the free camera (WASD / QE / RF, wheel, right-drag) · Ctrl+S save.
##     The camera always follows the timeline exactly; the world itself runs live (scrubbing doesn't rewind pets).
##
##   Render (offline, exact):  see tools/film_render.sh. Godot's Movie Maker (--write-movie) steps the engine at the
##     project's fixed frame rate and records the audio mix in lockstep, so frame n is the world simulated from the
##     start for n fixed steps: same project, same build -> the same frames and the same sound. Never screen capture.
##
## The game's own camera (garden.camera) is the one that's moved, after the garden's own camera code each frame, so
## everything that listens to it (the soundscape's ears, the tilt-shift, the porch man) behaves as it does in play.

var project: FilmProject
var project_dir := ""
var garden: Node
var rendering := false
var playing := false
var free_cam := false
var t := 0.0
var _frame := 0
var _fired := {}                   # "shot:event" -> true (each event fires once per pass)
var _bar: HSlider
var _label: Label
var _setting_bar := false
signal ready_to_film
var is_ready := false


func _ready() -> void:
	process_priority = 1000                          # after garden._process has placed its camera
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var path: String = args.get("film", OS.get_environment("FILM"))
	rendering = args.has("render") or OS.get_environment("FILM_RENDER") != ""
	if path != "" and ResourceLoader.exists(path):
		project = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as FilmProject
		project_dir = path.get_base_dir()
	if project == null:
		project = FilmProject.new()
		project.shots.append(FilmShot.new())
		project_dir = "res://films/untitled"
	OS.set_environment("HEDGEPETS_FRESH", "1")       # a film never reads or writes the player's save
	OS.set_environment("HEDGEPETS_HOUR", str(project.hour))
	OS.set_environment("HEDGEPETS_SOUND_SEED", str(project.seed))   # bird calls etc. at the same moments every render
	seed(project.seed)
	garden = (load("res://garden.tscn") as PackedScene).instantiate()
	add_child(garden)
	if not garden.is_built:
		await garden.built
	garden.set_process_unhandled_input(false)
	if garden.game != null:
		garden.game.set_process_unhandled_input(false)
		garden.game._ui.visible = false              # the game's buttons and toasts aren't in the film
	playing = rendering
	if not rendering:
		_build_ui()
	_apply_camera()
	is_ready = true
	ready_to_film.emit()


func pets() -> Dictionary:
	var out := {}
	for p in garden.pets:
		out[p.profile.pet_name if "profile" in p and p.profile != null else str(p.name)] = p
	return out


func _process(delta: float) -> void:
	if project == null or garden == null or not is_ready:
		return
	if rendering:
		t = float(_frame) / project.fps                # time from the frame count: no accumulated drift
		_frame += 1
		if _frame > project.frame_count():
			get_tree().quit()
			return
	elif playing:
		t += delta
		if t >= project.duration():
			t = project.duration()
			playing = false
	if not free_cam:                                 # (free: the garden's own camera keys move it)
		_fire_events()
		_apply_camera()
	_sync_ui()


func _apply_camera() -> void:
	if free_cam or project.shots.is_empty():
		return
	var at := project.shot_at(t)
	var shot: FilmShot = project.shots[at[0]]
	_go(shot.place)
	var pose: Dictionary = shot.camera_at(at[1], pets())
	if pose.is_empty():
		return
	var cam: Camera3D = garden.camera
	var eye: Vector3 = pose["eye"]
	var look: Vector3 = pose["look"]
	if _place.begins_with("woods"):                     # offsets from standing at that place in the woods
		var w: Node3D = garden.woods
		var base: Vector3 = w.node_pos(_place.get_slice(":", 1)) + Vector3(0, w.EYE, 0)
		cam = w.cam
		eye = w.to_global(base + eye)
		look = w.to_global(base + look)
	cam.fov = pose["fov"]
	cam.global_position = eye
	if not look.is_equal_approx(eye):
		cam.look_at(look, Vector3.UP)
	if _place.begins_with("woods"):
		garden.woods.land.follow(cam, cam.position, 0.0)  # the 1:16 land beyond follows this frame's camera


var _place := "garden"


## Be where the shot is: the garden, or a place in the woods (built at once, no veil, its HUD hidden).
func _go(place: String) -> void:
	if place == _place:
		return
	var w: Node3D = garden.woods
	if place.begins_with("woods"):
		w.build_now()
		w.pause_garden(true)
		w.visible = true
		w.set_process(true)
		w._ui.visible = false
		w._at = place.get_slice(":", 1)
		w.cam.make_current()
		w.land.show_land(true)                           # the 1:16 land beyond renders while you're in the woods
	else:
		if w.land != null:
			w.land.show_land(false)
		w.visible = false
		w.set_process(false)
		w.pause_garden(false)
		garden.game._ui.visible = false
		garden.camera.make_current()
	_place = place


func _fire_events() -> void:
	var at := project.shot_at(t)
	var shot: FilmShot = project.shots[at[0]]
	for i in shot.events.size():
		var e: Dictionary = shot.events[i]
		var id := "%d:%d" % [at[0], i]
		if float(e["t"]) <= at[1] and not _fired.has(id):
			_fired[id] = true
			_event(e)


func _event(e: Dictionary) -> void:
	var p = pets().get(str(e.get("pet", "")))
	if p == null and not garden.pets.is_empty():
		p = garden.pets[0]
	match str(e["kind"]):
		"tap": p.tap()
		"shake": p.shake_off()
		"sleep": p.set_sleeping(true)
		"wake": p.set_sleeping(false)
		"emote": garden.emote(p, str(e.get("arg", "💚")))


## The current camera pose as a key at time `local` in shot `i` (the editor's "K").
func add_key(i: int, local: float) -> void:
	var cam: Camera3D = garden.camera
	var shot: FilmShot = project.shots[i]
	shot.keys = shot.keys.filter(func(k) -> bool: return absf(float(k["t"]) - local) > 0.001)
	shot.keys.append({"t": snappedf(local, 1.0 / project.fps), "eye": cam.global_position, "look": cam.global_position - cam.global_basis.z * 8.0, "fov": cam.fov})


func save() -> Error:
	return project.save_to(project_dir)


# ------------------------------------------------------------------ preview ui
func _unhandled_input(event: InputEvent) -> void:
	if rendering:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_SPACE:
				if t >= project.duration():
					seek(0.0)
				playing = not playing
			KEY_LEFT: seek(t - 1.0 / project.fps)
			KEY_RIGHT: seek(t + 1.0 / project.fps)
			KEY_HOME: seek(0.0)
			KEY_C: free_cam = not free_cam
			KEY_K:
				var at := project.shot_at(t)
				add_key(at[0], at[1])
			KEY_N:
				var s := FilmShot.new()
				s.title = "shot_%03d" % (project.shots.size() + 1)
				project.shots.append(s)
			KEY_S:
				if k.ctrl_pressed:
					_label.text = "saved %s: %s" % [project_dir, error_string(save())]
	elif free_cam and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			garden._zoom_by(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			garden._zoom_by(1.1)
	elif free_cam and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		garden._pan_by(event.relative)


func seek(to: float) -> void:
	t = clampf(to, 0.0, project.duration())
	_fired.clear()                                    # events before the playhead count as fired
	var at := project.shot_at(t)
	for i in range(at[0] + 1):
		var shot: FilmShot = project.shots[i]
		for j in shot.events.size():
			if i < at[0] or float(shot.events[j]["t"]) < at[1]:
				_fired["%d:%d" % [i, j]] = true
	_apply_camera()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -86
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_bar = HSlider.new()
	_bar.step = 0.0
	_bar.value_changed.connect(func(v: float) -> void:
		if not _setting_bar:
			playing = false
			seek(v))
	box.add_child(_bar)
	_label = Label.new()
	box.add_child(_label)


func _sync_ui() -> void:
	if _bar == null:
		return
	_setting_bar = true
	_bar.max_value = maxf(project.duration(), 0.01)
	_bar.value = t
	_setting_bar = false
	var at := project.shot_at(t)
	var f := int(round(t * project.fps))
	_label.text = "%s  %02d:%02d:%02d  shot %d/%d  %s%s" % [project.title, int(t) / 60, int(t) % 60, f % project.fps, at[0] + 1, project.shots.size(), "▶" if playing else "❚❚", "  FREE CAM" if free_cam else ""]
