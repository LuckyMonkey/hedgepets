extends SceneTree

## Writes every pet's CharacterArtProfile to res://pets/<name>.tres from the defaults in
## scripts/art/character_art_profile.gd (gerald, clover, juniper, bramble, spruce, hazel, rascal).
##   godot --headless --path . --script tools/save_profile.gd
func _init() -> void:
	for p: CharacterArtProfile in [CharacterArtProfile.gerald(), CharacterArtProfile.clover(), CharacterArtProfile.juniper(), CharacterArtProfile.bramble(), CharacterArtProfile.spruce(), CharacterArtProfile.hazel(), CharacterArtProfile.rascal()]:
		var path := "res://pets/%s.tres" % p.pet_name.to_lower()
		var err := ResourceSaver.save(p, path)
		print(("saved " if err == OK else "FAILED ") + path)
	print("species.json: %d more (built at load time by SpeciesBuilder)" % SpeciesBuilder.load_all().size())
	quit()
