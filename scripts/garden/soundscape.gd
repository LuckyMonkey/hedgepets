extends Node3D

## The backyard, heard: leaves rustling high above the fence, always; and now and then a chickadee, a crow
## somewhere behind the trees, a branch creaking, the neighbours' wind chimes (often), and the ordinary
## neighbourhood far off: a leaf blower, a dog, a car out front, a screen door, a church bell from town. Then
## quiet again. Every sound comes from a place (trees, the houses), so turning the camera turns the yard.
## Sounds are made by tools/make_soundscape.py (assets/audio). M mutes / unmutes.

const EVENTS := {
	# name: [files, gap seconds (min, max), volume dB, where: "trees" | "houses" | "near" | "road" | "town"]
	# the bird chorus: someone is always singing somewhere, never all at once
	"chickadee": [["chickadee_1", "chickadee_2", "chickadee_3"], Vector2(14, 40), -13.0, "near"],
	"robin": [["robin_1", "robin_2", "robin_3"], Vector2(12, 35), -14.0, "trees"],
	"cardinal": [["cardinal_1", "cardinal_2", "cardinal_3"], Vector2(18, 50), -13.0, "near"],
	"song_sparrow": [["song_sparrow_1", "song_sparrow_2"], Vector2(20, 60), -15.0, "near"],
	"mourning_dove": [["mourning_dove"], Vector2(40, 110), -16.0, "houses"],
	"blue_jay": [["blue_jay_1", "blue_jay_2"], Vector2(50, 150), -18.0, "trees"],
	"crow": [["crow_1", "crow_2"], Vector2(70, 200), -20.0, "trees"],
	# the neighbours' porches: wind chimes (bright, deep, bamboo), often
	"chimes": [["chimes_1", "chimes_2", "chimes_3"], Vector2(12, 35), -16.0, "houses"],
	"bamboo": [["bamboo_1", "bamboo_2"], Vector2(25, 70), -17.0, "houses"],
	# the neighbourhood, far off and ordinary
	"dog": [["dog_1", "dog_2"], Vector2(40, 130), -20.0, "houses"],
	"leaf_blower": [["leaf_blower"], Vector2(180, 420), -28.0, "houses"],
	"car": [["car_1"], Vector2(50, 140), -26.0, "road"],
	"screen_door": [["screen_door"], Vector2(90, 240), -22.0, "houses"],
	"church_bell": [["church_bell"], Vector2(240, 600), -26.0, "town"],
}
## The wind in the leaves is a real recording (assets/audio/wind_leaves.ogg: Robert EA Harvey, "Wind sounds
## 2020-05-10", Wikimedia Commons, CC BY-SA 4.0; see docs/CREDITS.md), cut to a quiet minute and looped. The
## synthesised attempts sounded like surf, then static.
const WIND := true

var garden: Node3D
var muted := false
var wind_on := true                # the sound menu (garden_game: 🔊): the wind loop, and the birds and neighbours
var events_on := true
const SETTINGS := "user://settings.cfg"
var _wind: AudioStreamPlayer
var _players := {}
var _wait := {}
var _rng := RandomNumberGenerator.new()
var _film_clock := -1.0            # HEDGEPETS_SOUND_SEED (films, tests): seeded events, the swell on game time


func setup(g: Node3D) -> void:
	garden = g
	load_settings()
	if OS.get_environment("HEDGEPETS_SOUND_SEED") != "":
		_rng.seed = int(OS.get_environment("HEDGEPETS_SOUND_SEED"))
		_film_clock = 0.0
	else:
		_rng.randomize()
	_wind = AudioStreamPlayer.new()
	var loop := load("res://assets/audio/wind_leaves.ogg") as AudioStreamOggVorbis
	loop.loop = true
	_wind.stream = loop
	_wind.volume_db = -22.0
	add_child(_wind)
	if WIND:
		_wind.play()
	for k in EVENTS:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_db = 0.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players[k] = p
		_wait[k] = _rng.randf_range(6.0, EVENTS[k][1].x)      # the first ones come along fairly soon


func _process(delta: float) -> void:
	if _wind == null:
		return
	# the wind swells and settles slowly, never quite the same
	var ms := float(Time.get_ticks_msec())
	if _film_clock >= 0.0:
		_film_clock += delta
		ms = _film_clock * 1000.0
	_wind.volume_db = (-22.0 + 2.0 * sin(ms * 0.00011)) if not muted and wind_on else -80.0
	for k in EVENTS:
		_wait[k] = float(_wait[k]) - delta
		if _wait[k] <= 0.0:
			var e: Array = EVENTS[k]
			_wait[k] = _rng.randf_range(e[1].x, e[1].y)
			if not muted and events_on:
				_play(k, e)


func _play(k: String, e: Array) -> void:
	var p: AudioStreamPlayer3D = _players[k]
	if p.playing:
		return
	var files: Array = e[0]
	p.stream = load("res://assets/audio/%s.wav" % files[_rng.randi() % files.size()])
	p.volume_db = float(e[2]) + _rng.randf_range(-2.0, 2.0)
	p.pitch_scale = _rng.randf_range(0.94, 1.06)
	p.global_position = _where(str(e[3]))
	p.play()


## Where a sound comes from: up in the trees around the yard, a porch on one of the houses, or a tree near the lawn.
func _where(kind: String) -> Vector3:
	match kind:
		"houses":
			return Vector3([-12.5, 0.0, 12.5, -26.0, 26.0][_rng.randi() % 5], 3.0, _rng.randf_range(17.0, 24.0))
		"road":
			return Vector3(_rng.randf_range(-20.0, 20.0), 1.0, 34.0)
		"town":
			return Vector3(30.0, 12.0, -40.0)
		"near":
			var crowns: Array = garden._crowns
			if not crowns.is_empty():
				return (crowns.pick_random() as Vector3) + Vector3(0, 1.5, 0)
	var a := _rng.randf_range(-PI, PI)
	return Vector3(cos(a) * 22.0, 9.0, sin(a) * 22.0 - 4.0)


## A one-off sound from somewhere (the garbage truck out front when it empties the barrel).
func play_once(file: String, at: Vector3, db: float) -> void:
	if muted:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load("res://assets/audio/%s.wav" % file)
	p.unit_size = 16.0
	p.volume_db = db
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		muted = not muted
		for k in _players:
			if muted:
				(_players[k] as AudioStreamPlayer3D).stop()


## The sound menu's choices, kept between visits: all sound on/off, the wind, the birds and neighbours.
func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS) != OK:
		return
	wind_on = bool(c.get_value("sound", "wind", true))
	events_on = bool(c.get_value("sound", "events", true))
	set_all(bool(c.get_value("sound", "all", true)), false)


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("sound", "all", not AudioServer.is_bus_mute(0))
	c.set_value("sound", "wind", wind_on)
	c.set_value("sound", "events", events_on)
	c.save(SETTINGS)


func set_all(on: bool, save := true) -> void:
	AudioServer.set_bus_mute(0, not on)
	if save:
		save_settings()


func set_wind(on: bool) -> void:
	wind_on = on
	save_settings()


func set_events(on: bool) -> void:
	events_on = on
	if not on:
		for k in _players:
			(_players[k] as AudioStreamPlayer3D).stop()
	save_settings()
