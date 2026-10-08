extends SceneTree

## Nothing walks through anything: a dozen pets roam the garden for 40 s (at 60 fps) and no pet may sit inside a
## solid (trunk, wall, junk, a built thing, another pet) by more than a hair for long.
##   godot --headless --path . --script tools/collision_check.gd --fixed-fps 60
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	var garden: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process_unhandled_input(false)
	for i in range(3):
		await process_frame
	var game: Node = garden.game
	var n := 0
	for p: CharacterArtProfile in garden.roster:
		if n >= 12:
			break
		game.pet_state[p.pet_name] = "resident"
		game._apply_mode(game._node(p), true)
		n += 1
	var worst := 0.0
	var worst_what := ""
	var frames_over := 0
	for f in range(60 * 40):
		await process_frame
		if f < 60:
			continue                                     # let the opening overlaps resolve
		for node in garden.pets:
			if not node.visible:
				continue
			var p := Vector2(node.position.x, node.position.z)
			var pr: float = garden.pet_radius(node)
			for c in garden.colliders(node):
				var depth: float = float(c[1]) + pr - p.distance_to(c[0])
				if depth > 0.15:
					frames_over += 1
				if depth > worst:
					worst = depth
					worst_what = "%s into something at %s" % [node.profile.pet_name, c[0]]
	print("worst overlap %.2f (%s), frames over 0.15: %d" % [worst, worst_what, frames_over])
	if frames_over > 60 * 3:
		print("FAIL: pets spend too long inside things")
		quit(1)
		return
	print("PASS")
	quit(0)
