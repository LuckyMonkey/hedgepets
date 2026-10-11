extends SceneTree

## Clover (and two others) grown in cannabis leaves, in the pet viewer.
##   DISPLAY=:0 godot --path . --script tools/capture_contraband.gd --disable-vsync   (writes /tmp/hedgepets-views)
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/hedgepets-views")
	var v: Node = (load("res://main3d.tscn") as PackedScene).instantiate()
	root.add_child(v)
	await create_timer(1.0).timeout
	var roster: Array = CharacterArtProfile.roster()
	var shots := 0
	for i in roster.size():
		var p: CharacterArtProfile = roster[i]
		if p.pet_name in ["Clover", "Gerald", "Hazel"]:
			v._load_pet(i)
			await create_timer(0.8).timeout
			v.pet_node.set_plant("cannabis")
			v._show_plant("cannabis")
			await create_timer(1.5).timeout
			root.get_texture().get_image().save_png("/tmp/hedgepets-views/contraband_%s.png" % p.pet_name)
			shots += 1
	print("shots ", shots)
	quit(0)
