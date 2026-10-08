extends SceneTree

## Headless visual check. Keeps the desktop free while producing a deterministic PNG.
const OUTPUT_PATH := "/tmp/hedgepets-headless.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if DisplayServer.get_name().to_lower() == "headless":
		print("Godot is using the dummy renderer; use the Xvfb capture command for a PNG.")
		quit()
		return
	var viewport_texture: Texture2D = root.get_texture()
	if viewport_texture == null:
		print("No readable viewport texture under Godot's dummy renderer; use the Xvfb capture command for a PNG.")
		quit()
		return
	var image: Image = viewport_texture.get_image()
	if image == null:
		print("The dummy renderer has no readable image; use the Xvfb capture command for a PNG.")
		quit()
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save screenshot: %s" % error)
	else:
		print("Saved %s (%sx%s)" % [OUTPUT_PATH, image.get_width(), image.get_height()])
	quit()
