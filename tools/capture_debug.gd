extends SceneTree

## The art debug view with regions, anchors, face zones and clusters on: /tmp/hedgepets-views/debug.png
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(6):
		await process_frame
	var dbg: CanvasLayer = preload("res://scripts/art/art_debug.gd").new()
	dbg.name = "ArtDebug"
	scene.add_child(dbg)
	await process_frame
	for t in ["regions", "anchors", "face zones", "clusters"]:
		dbg._toggles[t].button_pressed = true
	dbg._toggles["leaves"].button_pressed = false
	for i in range(6):
		await process_frame
	root.get_texture().get_image().save_png("/tmp/hedgepets-views/debug.png")
	print("saved debug view")
	quit()
