extends SceneTree

## Small birds perching (perches.gd): every thing a bird can perch on and its height, then one bird actually sent up
## onto each in turn (walk skipped: placed at the spot beside it), checked to be on top, and hopped back down.
## With a display it also saves /tmp/hedgepets-views/perch.png of a bird on the trash barrel.
##   DISPLAY=:0 godot --audio-driver Dummy --path . --script tools/perch_check.gd
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Motion.speed = 0.0
	var scene: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	for i in range(60):
		await process_frame
	var p: Node = scene.perches
	var bird: HedgePetNode = null
	for prof: CharacterArtProfile in scene.roster:
		if p._birds.has(prof.species):
			bird = scene.node_for(prof)
			break
	for i in range(60):
		await process_frame                              # a visitor's node grows in slices
	var fails := 0
	if bird == null:
		print("PERCH FAIL no small bird among the garden's pets")
		quit(1)
		return
	print("PERCH bird ", bird.profile.pet_name, " (", bird.profile.species, "), birds: ", p._birds.keys())
	scene.set_pet_mode(bird, "roam", true)
	var w: Dictionary = scene._wander[bird]
	var tops := {}
	for t in scene.things:
		var top: Vector3 = p.top_of(t)
		if t["kind"] in p.SKIP or top == Vector3.INF or top.y < p.MIN_H or top.y > p.MAX_H:
			continue
		tops[t["id"]] = top
	print("PERCH perches: ", ", ".join(tops.keys().map(func(k): return "%s %.2fm" % [k, tops[k].y])))
	var shot := ""
	for t in scene.things:
		if not tops.has(t["id"]):
			continue
		bird.position = Vector3(t["at"].x + float(t["radius"]) + 0.3, 0, t["at"].y)
		w["mode"] = "roam"
		w["wait"] = 0.0
		var tries := 0
		while not (w["mode"] == "to_perch" and w["perch"] == t) and tries < 400:
			if w.get("perch") != null:
				p.release(bird, w)
			bird.position = Vector3(t["at"].x + float(t["radius"]) + 0.3, 0, t["at"].y)
			p.go_perch(bird, w)
			tries += 1
		if w["perch"] != t:
			print("PERCH FAIL never chose ", t["id"])
			fails += 1
			continue
		bird.position = w["target"]
		p.hop_up(bird, w)
		for i in range(4):
			await process_frame
		var on_top: bool = w["mode"] == "perched" and bird.position.distance_to(tops[t["id"]]) < 0.05
		if not on_top:
			print("PERCH FAIL ", t["id"], " mode ", w["mode"], " at ", bird.position, " top ", tops[t["id"]])
			fails += 1
			continue
		if t["kind"] == "barrel":
			shot = t["id"]
			break
		w["wait"] = 0.0
		for i in range(4):
			await process_frame
		if w["mode"] != "roam" or bird.position.y != 0.0 or w.get("perch") != null:
			print("PERCH FAIL ", t["id"], " didn't come down: mode ", w["mode"], " y ", bird.position.y)
			fails += 1
	if shot != "" and DisplayServer.get_name() != "headless":
		scene._goal_target = Vector3(bird.position.x, 0, bird.position.z)
		scene._target = scene._goal_target
		scene._distance = 3.2
		scene._goal_distance = 3.2
		scene._place_camera()
		w["wait"] = 999.0
		for i in range(30):
			await process_frame
		scene.get_node("TiltShift").visible = false
		await process_frame
		root.get_texture().get_image().save_png("/tmp/hedgepets-views/perch.png")
	# taken along mid-perch: hauling the barrel away makes the bird hop off
	if shot != "":
		var t: Dictionary = w["perch"]
		(t["node"] as Node3D).position += Vector3(0.5, 0, 0)
		for i in range(4):
			await process_frame
		if w["mode"] != "roam" or bird.position.y != 0.0:
			print("PERCH FAIL stayed up on a moved perch: mode ", w["mode"])
			fails += 1
		(t["node"] as Node3D).position -= Vector3(0.5, 0, 0)
	print("PERCH ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails else 0)
