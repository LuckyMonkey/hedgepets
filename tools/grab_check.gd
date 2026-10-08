extends SceneTree

## Yard work, driven like a real hand at 60 fps:
##   a stick yanks free with a few jerks and hauls to the wheelbarrow (sold, cleared, coins up);
##   a big rock does NOT come free for a steady pull, but does with jerks;
##   the tipped chair rights itself when yanked free; the grill scrubs clean in circles.
##   godot --headless --path . --script tools/grab_check.gd --fixed-fps 60
var garden: Node
var grab: Node


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	quit(1)


func screen_of(p: Vector3) -> Vector2:
	return garden.camera.unproject_position(p)


func frames(n: int) -> void:
	for i in range(n):
		await process_frame


## Hold on `t` and work it: jerk = big fast back-and-forth, else a steady pull toward `toward`.
func work(t: Dictionary, toward: Vector3, seconds: float, jerk: bool) -> void:
	if OS.get_environment("SHOTS") != "":         # frame it, for the screenshots
		garden._goal_target = t["node"].position
		garden._target = garden._goal_target
		garden._goal_distance = 8.0
		garden._distance = 8.0
		await frames(2)
	var start := screen_of(t["node"].position)
	if not grab.begin(start):
		return
	grab.move(start + Vector2(20, 0))
	var goal := screen_of(toward)
	for i in range(int(seconds * 60.0)):
		var pull := start.lerp(goal, clampf(i / 20.0, 0.0, 1.0))
		if jerk:
			pull += Vector2(70.0 if (i / 3) % 2 == 0 else -70.0, 0)
		grab.move(pull)
		await process_frame
		if i == 40 and OS.get_environment("SHOTS") != "":
			root.get_texture().get_image().save_png("/tmp/hedgepets-views/yank_%s.png" % t["kind"])
		if t["stuck"] <= 0.0:
			break


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	garden = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	await frames(3)
	var game: Node = garden.game
	grab = game.grab
	var of := func(kind: String) -> Array: return garden.things.filter(func(t) -> bool: return t["kind"] == kind)
	# a stick: yank, haul to the barrow, sell
	var stick: Dictionary = of.call("stick")[0]
	var coins0: int = game.coins
	var sticks0: int = of.call("stick").size()
	await work(stick, stick["node"].position + Vector3(2, 0, 0), 4.0, true)
	if stick["stuck"] > 0.0:
		return _fail("stick never came free")
	print("stick free")
	var barrow: Vector3 = grab.barrow["node"].position
	var from := screen_of(stick["node"].position)
	for i in range(150):
		grab.move(from.lerp(screen_of(barrow), clampf(i / 90.0, 0.0, 1.0)))
		await process_frame
		if i == 70 and OS.get_environment("SHOTS") != "":
			root.get_texture().get_image().save_png("/tmp/hedgepets-views/haul_stick.png")
	grab.end(screen_of(barrow))
	await frames(40)
	if of.call("stick").size() != sticks0 - 1 or game.coins <= coins0:
		return _fail("stick not sold (sticks %d -> %d, coins %d -> %d)" % [sticks0, of.call("stick").size(), coins0, game.coins])
	print("stick sold, coins %d -> %d" % [coins0, game.coins])
	# the biggest rock: a steady pull is not enough; jerks are
	var rocks: Array = of.call("rock")
	rocks.sort_custom(func(a, b) -> bool: return a["radius"] > b["radius"])
	var rock: Dictionary = rocks[0]
	grab.grabbable(rock)
	await work(rock, rock["node"].position + Vector3(2.5, 0, 0), 3.0, false)
	grab.end(screen_of(rock["node"].position))
	if rock["stuck"] <= 0.0:
		return _fail("a %d lb rock came free for a steady pull" % rock["lb"])
	print("rock (%d lb) holds against a steady pull" % rock["lb"])
	await work(rock, rock["node"].position + Vector3(2.5, 0, 0), 10.0, true)
	grab.end(screen_of(rock["node"].position))
	if rock["stuck"] > 0.0:
		return _fail("a %d lb rock never came free even with jerks" % rock["lb"])
	print("rock yanked free with jerks")
	# the chair rights itself
	var chair: Dictionary = of.call("lawn_chair")[0]
	await work(chair, chair["node"].position + Vector3(0, 0, 2.5), 8.0, true)
	grab.end(screen_of(chair["node"].position))
	await frames(50)
	if chair["tipped"]:
		return _fail("chair still tipped")
	print("chair righted")
	# the grill scrubs clean in circles
	var grill: Dictionary = of.call("grill")[0]
	var c := screen_of(grill["node"].position + Vector3(0, 0.9, 0))
	if not grab.begin(screen_of(grill["node"].position)):
		return _fail("couldn't get hold of the grill")
	for i in range(60 * 8):
		var a := i * 0.12
		grab.move(c + Vector2(cos(a), sin(a)) * 80.0)
		await process_frame
		if not grill["rusty"]:
			break
	grab.end(c)
	if grill["rusty"]:
		return _fail("grill still rusty (scrub %.2f)" % grill["scrub"])
	print("grill scrubbed clean")
	print("PASS")
	quit(0)
