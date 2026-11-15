extends SceneTree

## Deterministic offline shadow atlas. It projects the static tree/crown silhouettes onto the ground and softly
## rasterizes them once; pets remain live and keep their small contact-shadow blobs. WorldOverrides are already
## applied during the garden build, so authored static moves are included in the atlas.

const SIZE := 128

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("HEDGEPETS_FRESH", "1")
	OS.set_environment("HEDGEPETS_HOUR", "16.5")
	# The game loads the atlas while it builds its lawn. Seed both paths before instantiating the scene on a
	# first bake; the real 512px images replace these placeholders below.
	_ensure_placeholder("res://assets/baked/shadows_garden.png")
	_ensure_placeholder("res://assets/baked/shadows_woods.png")
	var g: Node = (load("res://garden.tscn") as PackedScene).instantiate()
	root.add_child(g)
	while not g.is_built:
		await process_frame
	# The garden has already applied WorldOverrides before is_built, so its authored static positions are what gets
	# projected here. This keeps the atlas tied to the same stable world as the playable scene.
	var garden_shapes: Array = []
	for o in g.obstacles:
		garden_shapes.append([Vector2(o[0].x, o[0].y), float(o[1]) + 1.2, 5.0])
	for c: Vector3 in g._crowns:
		garden_shapes.append([Vector2(c.x, c.z), 2.4, maxf(c.y, 5.0)])
	for thing: Dictionary in g.things:
		var kind := str(thing.get("kind", ""))
		var h := 1.8 if kind not in ["stick", "leaf_pile"] else 0.45
		garden_shapes.append([thing["at"], float(thing["radius"]) + 0.2, h])
	var garden_ray := _light_ray(g.sun, Vector2.RIGHT)
	print("shadow raster: garden %d shapes" % garden_shapes.size())
	_write("res://assets/baked/shadows_garden.png", Vector4(-32.0, -20.0, 32.0, 24.0), garden_shapes, garden_ray)
	var woods_shapes: Array = []
	for id in g.woods.NODES:
		var at: Vector2 = g.woods.NODES[id]["at"]
		woods_shapes.append([at, 3.0, 12.0])
	var woods_sun: DirectionalLight3D = null
	for child in g.woods.get_children():
		if child is DirectionalLight3D:
			woods_sun = child
			break
	var woods_ray := _light_ray(woods_sun, Vector2(0.55, -0.32))
	print("shadow raster: woods %d shapes" % woods_shapes.size())
	_write("res://assets/baked/shadows_woods.png", Vector4(-64.0, -116.0, 44.0, 24.0), woods_shapes, woods_ray)
	print("baked shadows: garden %d shapes, woods %d shapes" % [garden_shapes.size(), woods_shapes.size()])
	quit(0)

func _write(path: String, bounds: Vector4, shapes: Array, sun: Vector2) -> void:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(lerpf(bounds.x, bounds.z, (x + 0.5) / SIZE), lerpf(bounds.y, bounds.w, (y + 0.5) / SIZE))
			var shade := 0.0
			for s: Array in shapes:
				var centre: Vector2 = s[0]
				var radius: float = s[1]
				var height: float = s[2]
				var ray := sun.normalized()
				# The light travels from the canopy toward the ground along ray. Start the soft penumbra
				# just before the trunk and let it trail in the same direction as the light.
				var projected := centre - ray * clampf(height * 0.42, 0.0, 8.0)
				var along := (p - projected).dot(ray)
				var across := absf((p - projected).cross(ray))
				var reach := radius + clampf(height * 0.08, 0.0, 1.3)
				var end := reach + clampf(height * 0.22, 0.0, 3.0)
				var across_shadow := 1.0 - smoothstep(reach * 0.45, end, across)
				var length_shadow := smoothstep(-radius, -radius + 0.8, along) * (1.0 - smoothstep(end - 0.8, end, along))
				shade = maxf(shade, across_shadow * length_shadow)
			var value := 1.0 - clampf(shade * 0.72, 0.0, 0.72)
			image.set_pixel(x, y, Color(value, value, value))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(path)

func _ensure_placeholder(path: String) -> void:
	if FileAccess.file_exists(path):
		return
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	image.save_png(path)


func _light_ray(light: DirectionalLight3D, fallback: Vector2) -> Vector2:
	if light == null:
		return fallback
	var travel := light.global_basis * Vector3(0.0, 0.0, -1.0)
	var horizontal := Vector2(travel.x, travel.z)
	return horizontal.normalized() if horizontal.length_squared() > 0.0001 else fallback
