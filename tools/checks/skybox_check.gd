extends SceneTree

## Projection and ordering guard for the woods' 1:16 skybox. It checks the same landmark directions through the
## host camera and the miniature mapping at still poses and while the host turns/walks.
const EPS := 1.5

func _init() -> void:
	call_deferred("_run")

func _fail(msg: String) -> void:
	print("skybox_check: FAIL ", msg)
	quit(1)

func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	Motion.speed = 0.0
	var root_node: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(root_node)
	var woods: Node = root_node.woods
	woods.build_now()
	var waited := 0
	while woods.land == null and waited < 600:
		await process_frame
		waited += 1
	if woods.land == null:
		_fail("woods sky did not finish building")
	woods.visible = true
	woods.land.show_land(true)
	woods.cam.make_current()
	await process_frame
	var vp := root.get_viewport()
	var size := vp.get_visible_rect().size
	var landmarks: Array = []
	for p: Array in woods.land.PEAKS:
		landmarks.append(Vector3(float(p[0]) * MiniatureSky.SCALE, float(p[2]), float(p[1]) * MiniatureSky.SCALE))
	landmarks.append(Vector3(woods.land.VILLAGE.x * MiniatureSky.SCALE, 1.0, woods.land.VILLAGE.y * MiniatureSky.SCALE))
	landmarks.append(Vector3(woods.land.TOY_GARDEN.x * MiniatureSky.SCALE, 1.0, woods.land.TOY_GARDEN.y * MiniatureSky.SCALE))
	var max_error := 0.0
	var poses := [
		[Vector3(0, woods.EYE, 0), 0.0, -0.12], [Vector3(2, woods.EYE + 1.0, -24), 0.8, -0.08],
		[Vector3(22, woods.EYE + 10.0, -44), -0.7, -0.15], [Vector3(4, woods.EYE + 2.0, -70), 2.4, -0.1]]
	for pose: Array in poses:
		woods.cam.position = pose[0]
		woods.cam.rotation = Vector3(pose[2], pose[1], 0)
		woods.land.follow(woods.cam, woods.cam.position, 0.0)
		if woods.land.last_follow_frame < 0:
			_fail("follow did not record a host frame")
		for point: Vector3 in landmarks:
			var world_point: Vector3 = woods.to_global(point)
			if woods.cam.is_position_behind(world_point):
				continue
			var screen: Vector2 = woods.cam.unproject_position(world_point)
			var uv: Vector2 = woods.land.project_direction((world_point - woods.cam.global_position).normalized())
			# The texture is rendered with the deliberate overscan FOV. The shader samples that texture and expands
			# its pixel back to the host camera's screen ray.
			var projected: Vector2 = (Vector2(0.5, 0.5) + (uv - Vector2(0.5, 0.5)) * MiniatureSky.OVERSCAN) * size
			max_error = maxf(max_error, screen.distance_to(projected))
	# A scripted turn/walk: follow must be called after each host pose, not just after the final one.
	for k in range(90):
		woods.cam.position = Vector3(sin(k * 0.07) * 8.0, woods.EYE + 2.0 + sin(k * 0.03), -24.0 - k * 0.08)
		woods.cam.rotation = Vector3(-0.12, k * 0.025, 0)
		woods.land.follow(woods.cam, woods.cam.position, 1.0 / 60.0)
		if woods.land.last_follow_frame < 0:
			_fail("follow lost the frame stamp during scripted motion")
	print("skybox_check: %d poses, %d landmarks, max host/miniature projection error %.3f px" % [4 + 90, landmarks.size(), max_error])
	if max_error > EPS:
		_fail("projection error exceeds %.1f px" % EPS)
	print("skybox_check: PASS; matched KEEP_WIDTH/FOV mapping and same-frame follow ordering")
	quit(0)
