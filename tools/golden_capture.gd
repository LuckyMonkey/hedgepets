extends SceneTree

## The golden views: fixed camera poses over the garden and the woods, captured after a fixed number of fixed-step
## frames, so two runs of the same build give the same pictures and a changed build shows up in tools/image_compare.py.
## Nothing here changes the game: it only pins the clock, the seeds and the camera, then reads the screen.
##   xvfb-run -a -s "-screen 0 540x960x24" godot --path . --audio-driver Dummy --rendering-driver opengl3 --resolution 540x960 \
##     --fixed-fps 60 --disable-vsync --script tools/golden_capture.gd
##   GOLDEN_OUT=dir (default /tmp/hedgepets-golden)   GOLDEN_ONLY=garden_overview,woods_ridge (a subset)
## Writes <view>.png and moving_<n>.png (a slow orbit: temporal stability), plus views.json (what each view is).
const SEED := 20261014
const SETTLE := 45                         # frames between placing the camera and the shot (all fixed-step)

var out := ""
var only: PackedStringArray = []
var views := {}


func _init() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(name: String, info: Dictionary) -> void:
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	views[name] = info


func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _garden_view(g: Node, target: Vector3, yaw_deg: float, dist: float, elev_deg := 49.5) -> void:
	g._target = target
	g._goal_target = target
	g._yaw = deg_to_rad(yaw_deg)
	g._goal_yaw = g._yaw
	g._elev = deg_to_rad(elev_deg)
	g._goal_elev = g._elev
	g._distance = dist
	g._goal_distance = dist
	g._place_camera()


func _run() -> void:
	out = OS.get_environment("GOLDEN_OUT") if OS.get_environment("GOLDEN_OUT") != "" else "/tmp/hedgepets-golden"
	if OS.get_environment("GOLDEN_ONLY") != "":
		only = OS.get_environment("GOLDEN_ONLY").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	OS.set_environment("HEDGEPETS_FRESH", "1")         # never the player's save
	OS.set_environment("HEDGEPETS_HOUR", "16.5")       # the sun at a fixed hour, not the wall clock
	seed(SEED)                                         # randf()/randi() in pet life, toasts, wild visitors
	Motion.speed = 0.0
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	g.set_process_input(false)
	g.set_process_unhandled_input(false)
	await _frames(SETTLE)
	var garden_views := {
		"garden_overview": [Vector3(0, 0, -0.8), 0.0, 12.5],
		"garden_closeup": [Vector3(-4.6, 0, -3.0), 25.0, 5.0],
		"garden_pet": [Vector3(0, 0, -0.8), 0.0, 4.6],
		"garden_to_woods": [Vector3(2.0, 0, -6.0), 180.0, 11.0],
		"garden_east": [Vector3(5.0, 0, 0.0), 95.0, 9.0],
	}
	for name in garden_views:
		if not _want(name):
			continue
		var v: Array = garden_views[name]
		_garden_view(g, v[0], v[1], v[2])
		await _frames(SETTLE)
		_shot(name, {"where": "garden", "target": var_to_str(v[0]), "yaw": v[1], "distance": v[2]})
	if _want("moving"):
		# a slow orbit: 12 consecutive frames at one degree each, then every 6th frame of a 60-frame sweep
		_garden_view(g, Vector3(0, 0, -0.8), -20.0, 11.0)
		await _frames(SETTLE)
		for i in range(24):
			_garden_view(g, Vector3(0, 0, -0.8), -20.0 + i * 1.5, 11.0)
			await process_frame
			if i % 2 == 0:
				_shot("moving_%02d" % (i / 2), {"where": "garden orbit", "yaw": -20.0 + i * 1.5})
	var woods_ids := ["trailhead", "fork", "ridge", "oak", "creek"]
	var any_woods := false
	for id in woods_ids:
		any_woods = any_woods or _want("woods_" + id)
	if any_woods:
		var woods: Node = g.woods
		woods.build_now()
		woods.enter()
		await _frames(90)
		woods.set_process_unhandled_input(false)
		var looks := {
			"trailhead": Vector3(1, 0, 0.6),
			"fork": Vector3(0.4, 0, -1),
			"ridge": Vector3(woods.VIEW_DIR.x, 0, woods.VIEW_DIR.y),            # the 1:16 land beyond
			"oak": Vector3(woods._oak_at().x, 0, woods._oak_at().y) - woods.node_pos("oak"),
			"creek": Vector3(woods.CREEK_AT.x, 0, woods.CREEK_AT.y) - woods.node_pos("creek"),
		}
		for id in woods_ids:
			if not _want("woods_" + id):
				continue
			var d: Vector3 = looks[id]
			d.y = 0.0
			woods._at = id
			woods._yaw = woods._heading_of(d.normalized())
			woods._goal_yaw = woods._yaw
			woods._pitch = deg_to_rad(4.0) if id == "oak" else deg_to_rad(-6.0)
			woods._refresh_finds()
			woods._settle(Vector3.INF)
			await _frames(SETTLE)
			_shot("woods_" + id, {"where": "woods", "node": id, "yaw": woods._yaw})
	var f := FileAccess.open(out.path_join("views.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed": SEED, "hour": 16.5, "size": var_to_str(root.get_texture().get_size()), "views": views}, "  ", true))
	f.close()
	print("golden: %d views -> %s" % [views.size(), out])
	quit(0)
