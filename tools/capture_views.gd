extends SceneTree

## Visual acceptance captures: FRONT, SIDE, THREE_QUARTER, DISTANT (mobile size) at full foliage, then LOW, MEDIUM,
## FULL, FLOWERING foliage from three-quarter. Writes /tmp/hedgepets-views/<name>.png; run on the real display:
##   DISPLAY=:0 godot --path . --script tools/capture_views.gd
const OUT := "/tmp/hedgepets-views"
const SHOTS := [
	["view_front", "FRONT", "FULL"], ["view_side", "SIDE", "FULL"], ["view_three_quarter", "THREE_QUARTER", "FULL"],
	["view_distant", "DISTANT", "FULL"],
	["foliage_low", "THREE_QUARTER", "LOW"], ["foliage_medium", "THREE_QUARTER", "MEDIUM"],
	["foliage_full", "THREE_QUARTER", "FULL"], ["foliage_flowering", "THREE_QUARTER", "FLOWERING"],
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: Node = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process_input(false)   # captures must not be turned by a live mouse on the window
	for i in range(10):
		await process_frame
	for shot in SHOTS:
		scene.set_foliage(shot[2])
		scene.set_view(shot[1])
		scene._yaw = 0.0
		scene._yaw_velocity = 0.0
		for i in range(8):
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [OUT, shot[0]])
	print("saved %d views to %s" % [SHOTS.size(), OUT])
	quit()
