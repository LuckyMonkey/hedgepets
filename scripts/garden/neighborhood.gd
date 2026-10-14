extends MiniatureSky

## The neighbourhood beyond the garden's back fence, as the garden's 3D skybox (the same MiniatureSky machinery as the
## land beyond the woods): the two houses next door, their yards and fences, the street with its poles and maples and
## parked cars, the houses across the road, rooftops and trees going on to the hills, a church steeple. All low-poly,
## built in metres under a 1:16 root, one mesh per material; the garden's own fog and sage background, so it softens
## into the distance like the garden does, and the tilt-shift does the rest. The white house with the blue door (the
## porch, the stairs, the man on it) is NOT here: it's real, in the garden, so he can come and go.
var host: Node3D                                     # the garden
var _sun: DirectionalLight3D
var _mats := {}


func setup(garden: Node3D) -> void:
	name = "Neighborhood"
	host = garden
	res = 0.5
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7b37a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.74)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("a7b37a")
	env.fog_density = 0.01 * SCALE                    # the garden's fog, in miniature units
	var world := _make_view(garden.get_viewport(), env)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = false
	world.add_child(_sun)
	var root := Node3D.new()
	root.scale = Vector3.ONE / SCALE                  # built in metres
	world.add_child(root)
	_build(root)


func _tick(_delta: float) -> void:
	var s: DirectionalLight3D = host.sun
	if s != null:                                     # the garden's sun, wherever the hour has put it
		_sun.basis = s.global_basis
		_sun.light_color = s.light_color
		_sun.light_energy = s.light_energy


func _m(c: Color) -> StandardMaterial3D:
	var k := c.to_html(false)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_mats[k] = m
	return _mats[k]


func _box(p: Node3D, size: Vector3, at: Vector3, c: Color, yaw := 0.0) -> void:
	var b := BoxMesh.new()
	b.size = size
	var n := MeshInstance3D.new()
	n.mesh = b
	n.material_override = _m(c)
	n.position = at
	n.rotation.y = yaw
	p.add_child(n)


func _roof(p: Node3D, size: Vector3, at: Vector3, c: Color) -> void:
	var pm := PrismMesh.new()
	pm.size = size
	var n := MeshInstance3D.new()
	n.mesh = pm
	n.material_override = _m(c)
	n.position = at
	p.add_child(n)


func _blob(p: Node3D, r: float, at: Vector3, c: Color, squash := 0.85) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 * squash
	s.radial_segments = 7
	s.rings = 4
	var n := MeshInstance3D.new()
	n.mesh = s
	n.material_override = _m(c)
	n.position = at
	p.add_child(n)


func _cyl(p: Node3D, r: float, h: float, at: Vector3, c: Color) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 0
	var n := MeshInstance3D.new()
	n.mesh = cm
	n.material_override = _m(c)
	n.position = at
	p.add_child(n)


## A house seen from behind (its back toward the garden, -z): siding, a gable roof, windows, a back door, a chimney.
func _house(p: Node3D, at: Vector3, size: Vector3, siding: Color, roof: Color, rng: RandomNumberGenerator, facing := -1.0) -> void:
	_box(p, size, at + Vector3(0, size.y * 0.5, 0), siding)
	_roof(p, Vector3(size.x * 1.08, size.y * 0.5, size.z * 1.1), at + Vector3(0, size.y + size.y * 0.25, 0), roof)
	var face := at.z + facing * size.z * 0.5
	for k in range(3):                               # two floors of windows, dark glass, white trim
		for fl in range(2):
			var x := at.x - size.x * 0.3 + k * size.x * 0.3
			_box(p, Vector3(1.0, 1.25, 0.06), Vector3(x, 1.4 + fl * 2.1, face + facing * 0.03), Color("f2efe6"))
			_box(p, Vector3(0.8, 1.05, 0.08), Vector3(x, 1.4 + fl * 2.1, face + facing * 0.05), Color("2c3440"))
	_box(p, Vector3(0.9, 2.0, 0.08), Vector3(at.x + size.x * 0.32, 1.0, face + facing * 0.05), Color("4a4a42"))
	_box(p, Vector3(0.7, 1.6, 0.7), at + Vector3(-size.x * 0.32, size.y * 1.35, rng.randf_range(-1.0, 1.0)), Color("7a4636"))


func _maple(p: Node3D, at: Vector3, rng: RandomNumberGenerator, big := 1.0) -> void:
	var h := rng.randf_range(4.0, 6.0) * big
	_cyl(p, 0.22 * big, h, at + Vector3(0, h * 0.5, 0), Color("4e3c2c"))
	var cols := [Color("c0662c"), Color("a8402a"), Color("d0902e"), Color("6a7a3a"), Color("b85a2a")]
	var c: Color = cols[rng.randi() % cols.size()]
	for k in range(3):
		var o := Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.4, 0.8), rng.randf_range(-1.2, 1.2)) * big
		_blob(p, rng.randf_range(1.6, 2.4) * big, at + Vector3(0, h + 0.8 * big, 0) + o, c.darkened(rng.randf() * 0.15))


func _pine(p: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(9.0, 14.0)
	_cyl(p, 0.25, h * 0.4, at + Vector3(0, h * 0.2, 0), Color("4e3a2c"))
	for k in range(3):
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = lerpf(2.6, 1.2, k / 2.0)
		cm.height = h * 0.4
		cm.radial_segments = 7
		cm.rings = 0
		var n := MeshInstance3D.new()
		n.mesh = cm
		n.material_override = _m(Color("2a4632"))
		n.position = at + Vector3(0, h * (0.35 + k * 0.22), 0)
		p.add_child(n)


func _build(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var near := Node3D.new()
	root.add_child(near)
	# the ground beyond the back fence: yards and verges (the garden's real lawn stops just behind its fence)
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(40):
		for i in range(60):
			var x0 := -300.0 + i * 10.0
			var z0 := 8.0 + j * 8.0
			var c := Color("86964e").lerp(Color("9aa25a"), rng.randf()).darkened(rng.randf() * 0.08)
			for v: Vector3 in [Vector3(x0, 0, z0), Vector3(x0 + 10, 0, z0), Vector3(x0 + 10, 0, z0 + 8), Vector3(x0, 0, z0), Vector3(x0 + 10, 0, z0 + 8), Vector3(x0, 0, z0 + 8)]:
				ground.set_color(c)
				ground.set_normal(Vector3.UP)
				ground.add_vertex(v + Vector3(0, -0.03, 0))
	var gm := MeshInstance3D.new()
	gm.mesh = ground.commit()
	var gmat := StandardMaterial3D.new()
	gmat.vertex_color_use_as_albedo = true
	gmat.roughness = 1.0
	gm.material_override = gmat
	root.add_child(gm)
	# next door, both sides of the white house (which is real: it's in the garden)
	_house(near, Vector3(-12.5, 0, 20.0), Vector3(8.0, 5.0, 6.5), Color("e8e2d2"), Color("4a4440"), rng)
	_house(near, Vector3(12.5, 0, 20.5), Vector3(8.0, 5.0, 6.5), Color("8a3a2a"), Color("3e3a38"), rng)
	for x: float in [-6.6, 6.6]:                     # fences between the yards
		for k in range(14):
			_box(near, Vector3(0.08, 1.0, 0.95), Vector3(x, 0.5, 11.5 + k), Color("eeeae0"))
	_box(near, Vector3(2.2, 2.2, 2.6), Vector3(-15.2, 1.1, 14.0), Color("8a6a4a"))          # a shed
	_roof(near, Vector3(2.5, 0.9, 2.9), Vector3(-15.2, 2.65, 14.0), Color("4a4440"))
	for x: float in [9.0, 15.0]:                     # a washing line, a few things pegged out
		_cyl(near, 0.05, 2.2, Vector3(x, 1.1, 14.5), Color("9a9a92"))
	_box(near, Vector3(6.0, 0.02, 0.02), Vector3(12.0, 2.1, 14.5), Color("dddddd"))
	for k in range(4):
		_box(near, Vector3(0.6, 0.7, 0.04), Vector3(10.0 + k * 1.3, 1.7, 14.5), [Color("d8c8a8"), Color("8aa0c0"), Color("f0f0ea"), Color("c06a5a")][k])
	_maple(near, Vector3(-9.0, 0, 13.0), rng)
	_maple(near, Vector3(18.0, 0, 15.0), rng, 1.2)
	# the street out front
	var street := Node3D.new()
	root.add_child(street)
	_box(street, Vector3(600, 0.05, 1.6), Vector3(0, 0.02, 29.6), Color("b8b4a8"))         # sidewalk
	_box(street, Vector3(600, 0.04, 7.0), Vector3(0, 0.0, 34.0), Color("4a4a4c"))          # asphalt
	_box(street, Vector3(600, 0.05, 1.6), Vector3(0, 0.02, 38.4), Color("b8b4a8"))
	for k in range(40):
		_box(street, Vector3(2.4, 0.05, 0.14), Vector3(-200.0 + k * 10.0, 0.03, 34.0), Color("d8b440"))   # the centre line
	for k in range(24):                               # poles and wires
		var x := -240.0 + k * 22.0
		_cyl(street, 0.14, 9.0, Vector3(x, 4.5, 29.0), Color("5a4a3a"))
		_box(street, Vector3(1.8, 0.12, 0.12), Vector3(x, 8.6, 29.0), Color("5a4a3a"))
	_box(street, Vector3(530, 0.04, 0.04), Vector3(0, 8.4, 29.0), Color("2a2a2a"))
	for k in range(30):                               # maples along both sides
		_maple(street, Vector3(-150.0 + k * 10.5 + rng.randf_range(-1.5, 1.5), 0, 28.3 if k % 2 == 0 else 39.8), rng)
	for c: Array in [[Vector3(-7.0, 0, 32.2), Color("8a2a2a")], [Vector3(19.0, 0, 36.0), Color("3a5a7a")], [Vector3(-31.0, 0, 36.0), Color("d8d4c8")]]:
		_box(street, Vector3(4.2, 0.9, 1.8), c[0] + Vector3(0, 0.7, 0), c[1])                 # parked cars
		_box(street, Vector3(2.2, 0.7, 1.6), c[0] + Vector3(-0.2, 1.45, 0), (c[1] as Color).darkened(0.3))
	# the houses across the road, a second row, then rooftops and trees to the hills
	var far := Node3D.new()
	root.add_child(far)
	var sidings := [Color("eeeae0"), Color("e8d9a8"), Color("8a9aaa"), Color("a8483a"), Color("d8d0c0"), Color("7a8a6a"), Color("f0e8d8")]
	for k in range(20):
		var x := -140.0 + k * 14.0 + rng.randf_range(-1.5, 1.5)
		_house(far, Vector3(x, 0, 47.0), Vector3(rng.randf_range(8.0, 10.0), rng.randf_range(5.0, 6.5), 7.0), sidings[rng.randi() % sidings.size()], Color("3e3a38").lightened(rng.randf() * 0.15), rng)
	for k in range(16):
		var x := -150.0 + k * 19.0 + rng.randf_range(-3, 3)
		_house(far, Vector3(x, 0, 74.0 + rng.randf_range(-3, 3)), Vector3(9.0, 5.5, 7.0), sidings[rng.randi() % sidings.size()].darkened(0.1), Color("3a3634"), rng)
	for k in range(260):                              # the canopy of a town in the trees
		var p := Vector3(rng.randf_range(-260, 260), 0, rng.randf_range(58, 240))
		if p.z < 90.0 and rng.randf() < 0.5:
			continue
		if rng.randf() < 0.3:
			_pine(far, p, rng)
		else:
			_maple(far, p, rng, rng.randf_range(1.2, 2.0))
	_box(far, Vector3(8.0, 9.0, 14.0), Vector3(40.0, 4.5, 160.0), Color("f2efe6"))         # the church, its steeple
	_box(far, Vector3(3.6, 16.0, 3.6), Vector3(40.0, 8.0, 151.0), Color("f2efe6"))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.0
	spire.bottom_radius = 2.4
	spire.height = 10.0
	spire.radial_segments = 6
	spire.rings = 0
	var sp := MeshInstance3D.new()
	sp.mesh = spire
	sp.material_override = _m(Color("f2efe6"))
	sp.position = Vector3(40.0, 21.0, 151.0)
	far.add_child(sp)
	for k in range(7):                                # the hills, blue with distance (the fog does that)
		_blob(far, rng.randf_range(80.0, 140.0), Vector3(-450.0 + k * 150.0, -30.0, rng.randf_range(330.0, 420.0)), Color("6a7a5a"), 0.5)
	for g: Node3D in [near, street, far]:
		GardenProps.bake_static(g)                     # one mesh per material per group
