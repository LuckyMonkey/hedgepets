extends SceneTree

## Drag to turn: a scripted press, drag and release turns the pet (and keeps spinning a little); a short tap does not.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Motion.speed = 0.0                   # captures and checks: every transition instant, results deterministic
	var scene: Node = (load("res://main3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(5):
		await process_frame
	var start: float = scene.pet.rotation.y
	var at := Vector2(540, 800)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	scene._input(press)
	for k in range(12):
		var move := InputEventMouseMotion.new()
		move.position = at + Vector2(20.0 * (k + 1), 0)
		move.relative = Vector2(20, 0)
		scene._input(move)
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at + Vector2(240, 0)
	scene._input(release)
	var after_drag: float = scene.pet.rotation.y
	for i in range(20):
		await process_frame
	var after_spin: float = scene.pet.rotation.y
	print("turned %.2f rad by dragging, %.2f more with momentum; tap joy before drag test: hop works via _tap" % [after_drag - start, after_spin - after_drag])
	quit(0 if absf(after_drag - start) > 1.0 else 1)
