extends SceneTree

## Writes Gerald's CharacterArtProfile to res://pets/gerald.tres (edit that file, or the defaults in
## scripts/art/character_art_profile.gd, then re-run).
##   godot --headless --path . --script tools/save_profile.gd
func _init() -> void:
	var err := ResourceSaver.save(CharacterArtProfile.gerald(), "res://pets/gerald.tres")
	print("saved pets/gerald.tres" if err == OK else "save failed: %s" % err)
	quit()
