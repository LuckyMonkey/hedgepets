extends SceneTree

## Writes the demo film (res://films/demo/): the acceptance cinematic of docs/FILMMAKER.md. Shot 1 opens on the
## garden and dollies down to Gerald, who hops when tapped (his own tap behaviour); cut to shot 2, low beside him,
## a slow arc while he shows a heart. Real garden, real pets, real soundscape.
##   godot --headless --path . --script tools/film_make_demo.gd
func _init() -> void:
	var p := FilmProject.new()
	p.title = "HedgePets demo"
	var a := FilmShot.new()
	a.title = "garden to Gerald"
	a.duration = 4.0
	a.keys = [
		{"t": 0.0, "eye": Vector3(0.0, 8.0, 9.5), "look": Vector3(0.0, 0.0, -0.8), "fov": 46.0},
		{"t": 2.0, "eye": Vector3(1.0, 4.5, 6.0), "look": Vector3(0.0, 0.3, -0.8), "fov": 44.0, "track": "Gerald"},
		{"t": 4.0, "eye": Vector3(1.6, 2.0, 3.4), "look": Vector3(0.0, 0.3, -0.8), "fov": 40.0, "track": "Gerald"},
	]
	a.events = [{"t": 2.6, "kind": "tap", "pet": "Gerald"}]
	var b := FilmShot.new()
	b.title = "beside Gerald"
	b.duration = 3.0
	b.keys = [
		{"t": 0.0, "eye": Vector3(-3.6, 1.1, 0.6), "look": Vector3(0.0, 0.3, -0.8), "fov": 38.0, "track": "Gerald"},
		{"t": 3.0, "eye": Vector3(-2.4, 1.3, 2.4), "look": Vector3(0.0, 0.3, -0.8), "fov": 36.0, "track": "Gerald"},
	]
	b.events = [{"t": 0.8, "kind": "emote", "pet": "Gerald", "arg": "💚"}]
	p.shots = [a, b]
	var err := p.save_to("res://films/demo")
	print("films/demo: %s (%d frames at %d fps)" % [error_string(err), p.frame_count(), p.fps])
	quit(0 if err == OK else 1)
