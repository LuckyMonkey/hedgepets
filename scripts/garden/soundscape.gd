extends Node3D

## The backyard, heard: wind in the leaves high above the fence, always; and now and then a chickadee, a crow
## somewhere behind the trees, a branch creaking, a neighbour's wind chimes. Then quiet again: most of the time
## nothing but the wind. Every sound comes from a place (trees, the houses), so turning the camera turns the yard.
## Sounds are made by tools/make_soundscape.py (assets/audio). M mutes / unmutes.

const EVENTS := {
	# name: [files, gap seconds (min, max), volume dB, where: "trees" | "houses" | "near"]
	"chickadee": [["chickadee_1", "chickadee_2", "chickadee_3"], Vector2(25, 80), -14.0, "near"],
	"crow": [["crow_1", "crow_2"], Vector2(70, 200), -20.0, "trees"],
	"creak": [["creak_1", "creak_2"], Vector2(60, 180), -18.0, "trees"],
	"chimes": [["chimes_1", "chimes_2"], Vector2(45, 140), -24.0, "houses"],
}

var garden: Node3D
var muted := false
var _wind: AudioStreamPlayer
var _players := {}
var _wait := {}
var _rng := RandomNumberGenerator.new()


func setup(g: Node3D) -> void:
	garden = g
	_rng.randomize()
	_wind = AudioStreamPlayer.new()
	var loop := load("res://assets/audio/wind_loop.wav") as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.get_length() * loop.mix_rate
	_wind.stream = loop
	_wind.volume_db = -16.0
	add_child(_wind)
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
	_wind.volume_db = (-16.0 + 2.5 * sin(Time.get_ticks_msec() * 0.00011)) if not muted else -80.0
	for k in EVENTS:
		_wait[k] = float(_wait[k]) - delta
		if _wait[k] <= 0.0:
			var e: Array = EVENTS[k]
			_wait[k] = _rng.randf_range(e[1].x, e[1].y)
			if not muted:
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
			return Vector3([-12.5, 0.0, 12.5][_rng.randi() % 3], 3.0, 18.0)
		"near":
			var crowns: Array = garden._crowns
			if not crowns.is_empty():
				return (crowns.pick_random() as Vector3) + Vector3(0, 1.5, 0)
	var a := _rng.randf_range(-PI, PI)
	return Vector3(cos(a) * 22.0, 9.0, sin(a) * 22.0 - 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		muted = not muted
		for k in _players:
			if muted:
				(_players[k] as AudioStreamPlayer3D).stop()
