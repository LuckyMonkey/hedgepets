extends SceneTree

## How expensive is the rustle? Runs the scene for 4 s and reports frames per second and the leaf count.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Motion.speed = 0.0                   # captures and checks: every transition instant, results deterministic
	var scene: Node = (load("res://main3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var started := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - started < 4000:
		await process_frame
		frames += 1
	var leaves := 0
	for node in scene.find_children("*", "MultiMeshInstance3D", true, false):
		leaves += (node as MultiMeshInstance3D).multimesh.instance_count
	if scene.has_node("Pet/GrowthRenderer"):
		leaves = scene.get_node("Pet/GrowthRenderer").composition_marks.size()
	print("fps %.0f over 4 s, %d leaves" % [frames / 4.0, leaves])
	quit()
