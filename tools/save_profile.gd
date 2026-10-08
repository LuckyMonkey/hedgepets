extends SceneTree

## Writes every pet's CharacterArtProfile to res://pets/<name>.tres from the defaults in
## scripts/art/character_art_profile.gd (gerald, clover, juniper, bramble).
##   godot --headless --path . --script tools/save_profile.gd
func _init() -> void:
	for p: CharacterArtProfile in [CharacterArtProfile.gerald(), CharacterArtProfile.clover(), CharacterArtProfile.juniper(), CharacterArtProfile.bramble()]:
		var path := "res://pets/%s.tres" % p.pet_name.to_lower()
		var err := ResourceSaver.save(p, path)
		print(("saved " if err == OK else "FAILED ") + path)
	quit()
