extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var s: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(s)
	s.set_process_unhandled_input(false)
	for i in range(60):
		await process_frame
	var t := Time.get_ticks_usec()
	for i in range(300):
		await process_frame
	print("ms/frame ", (Time.get_ticks_usec() - t) / 300000.0)
	quit()
