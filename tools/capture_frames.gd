extends SceneTree

## Animation check: saves frames over a few seconds, with a tap on the pet at 1.0 s.
## xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --script tools/capture_frames.gd
const TIMES := [0.4, 1.05, 1.2, 1.45, 2.2, 3.0]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var started := Time.get_ticks_msec()
	var tapped := false
	var index := 0
	while index < TIMES.size():
		await process_frame
		var t := float(Time.get_ticks_msec() - started) / 1000.0
		if not tapped and t >= 1.0:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = Vector2(270, 420)   # on Gerald's face (window pixels, half scale)
			root.push_input(press)
			tapped = true
		if t >= TIMES[index]:
			var image := root.get_texture().get_image()
			image.save_png("/tmp/hedgepets-frame-%d.png" % index)
			index += 1
	print("saved %d frames" % TIMES.size())
	quit()
