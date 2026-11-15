extends "res://scripts/garden/land/land_forest.gd"

## Distant land 3/3 - landmarks in the land: the toy garden (home, seen from the woods), the village, the fire tower, clouds.
##
## Landmarks you can find again from different clearings: the toy garden (home, across the ravine), the white village
## with its steeple, the fire tower on the long west ridge, and clouds that drift slowly.
##
## Part of the distant land layer chain (the full order is at the top of scripts/garden/distant_land.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var _clouds: Array = []
const VILLAGE := Vector2(122.0, -18.0)
## A white village on the lake shore: houses, a red barn, and the church with its steeple.
## A toy's material: its own colour, never hazed by the distance - it stands out the way a dollhouse would.
static func _toy_mat(key: String, colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = colour
	m.roughness = 1.0
	m.disable_fog = true
	return m


func _toy_garden(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1008
	var c := TOY_GARDEN
	var y0 := height(c.x, c.y)
	var lawn := SurfaceTool.new()                      # the lawn, lying on the land
	lawn.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 3.4 * TOY_SCALE
	var d := 2.6 * TOY_SCALE
	for j in range(6):
		for i in range(6):
			var quad: Array = []
			for q: Vector2 in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var x := c.x - w + q.x / 6.0 * w * 2.0
				var z := c.y - d + q.y / 6.0 * d * 2.0
				quad.append(Vector3(x, height(x, z) + 0.03, z))
			for v in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
				lawn.add_vertex(v)
	lawn.generate_normals()
	var ln := MeshInstance3D.new()
	ln.mesh = lawn.commit()
	ln.material_override = _toy_mat("toylawn", Color("8a9a48"))
	world.add_child(ln)
	var parts: Array = [                                # [size, offset from c, colour key, colour]
		[Vector3(0.9, 0.55, 0.7), Vector2(0.0, 2.9), "toywhite", Color("eeeae0")],        # the white house
		[Vector3(0.8, 0.5, 0.65), Vector2(-1.5, 3.1), "toycream", Color("e8e2d2")],
		[Vector3(0.8, 0.5, 0.65), Vector2(1.5, 3.2), "toyred", Color("8a3a2a")],
		[Vector3(0.14, 0.26, 0.02), Vector2(0.0, 2.54), "toydoor", Color("3a5a8a")],       # its blue door
	]
	for pt: Array in parts:
		var at: Vector2 = c + (pt[1] as Vector2) * TOY_SCALE
		var n := MeshInstance3D.new()
		var b := BoxMesh.new()
		pt[0] = (pt[0] as Vector3) * TOY_SCALE
		b.size = pt[0]
		n.mesh = b
		n.material_override = _toy_mat(pt[2], pt[3])
		n.position = Vector3(at.x, height(at.x, at.y) + (pt[0] as Vector3).y * 0.5 + (0.0 if pt[2] != "toydoor" else 0.0), at.y)
		world.add_child(n)
		if pt[2] != "toydoor":
			var r := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3((pt[0] as Vector3).x * 1.1, 0.3 * TOY_SCALE, (pt[0] as Vector3).z * 1.1)
			r.mesh = pm
			r.material_override = _toy_mat("skyroof", Color("4a4440"))
			r.position = n.position + Vector3(0, (pt[0] as Vector3).y * 0.5 + 0.15, 0)
			world.add_child(r)
	var picket := _toy_mat("toypicket", Color("f4f0e6"))
	for side: Array in [[Vector2(-w, -d), Vector2(w, -d)], [Vector2(-w, -d), Vector2(-w, d)], [Vector2(w, -d), Vector2(w, d)]]:
		var a: Vector2 = c + side[0]
		var e: Vector2 = c + side[1]
		var n := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(a.distance_to(e), 0.08, 0.03)
		n.mesh = b
		n.material_override = picket
		var mid := (a + e) * 0.5
		n.position = Vector3(mid.x, height(mid.x, mid.y) + 0.07, mid.y)
		n.rotation.y = -atan2(e.y - a.y, e.x - a.x)
		world.add_child(n)
	var creek := MeshInstance3D.new()                  # the creek down the far side, and its bridge
	var cb := BoxMesh.new()
	cb.size = Vector3(0.35, 0.02, d * 2.6)
	creek.mesh = cb
	creek.material_override = _toy_mat("toycreek", Color("4a6e86"))
	creek.position = Vector3(c.x - w - 0.5, height(c.x - w - 0.5, c.y) + 0.02, c.y)
	world.add_child(creek)
	var br := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.6, 0.03, 0.14)
	br.mesh = bb
	br.material_override = _toy_mat("toybridge", Color("8a6e4e"))
	br.position = creek.position + Vector3(0, 0.03, 0.2)
	world.add_child(br)
	for k in range(9):                                  # autumn trees round the back, a pine or two
		var a := rng.randf_range(-PI, 0.0)
		var at := c + Vector2(cos(a) * (w + rng.randf_range(0.6, 1.6)), sin(a) * (d + rng.randf_range(0.6, 1.4)))
		var t := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.35, 0.55)
		sm.height = sm.radius * 2.2
		sm.radial_segments = 8
		sm.rings = 4
		t.mesh = sm
		t.material_override = _toy_mat("toytree%d" % (k % 3), [Color("c0662c"), Color("a8402a"), Color("4e6a3a")][k % 3])
		t.position = Vector3(at.x, height(at.x, at.y) + sm.radius * 1.4, at.y)
		world.add_child(t)


func _village(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1719
	var white := GardenProps.mat("skywhite", Color("eeeae0"))
	var roof := GardenProps.mat("skyroof", Color("4a4440"))
	for k in range(9):
		var p := VILLAGE + Vector2(rng.randf_range(-7, 7), rng.randf_range(-5, 5))
		var y := height(p.x, p.y)
		var body := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 0.35, 0.38)
		body.mesh = b
		body.material_override = white if k != 3 else GardenProps.mat("skybarn", Color("8a3a2a"))
		body.position = Vector3(p.x, y + 0.17, p.y)
		body.rotation.y = rng.randf_range(-0.4, 0.4)
		world.add_child(body)
		var r := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.56, 0.22, 0.42)
		r.mesh = pm
		r.material_override = roof
		r.position = body.position + Vector3(0, 0.28, 0)
		r.rotation = body.rotation
		world.add_child(r)
	var c := VILLAGE + Vector2(2.0, -2.0)            # the church: a white box, a tall white steeple
	var cy := height(c.x, c.y)
	for part: Array in [[BoxMesh.new(), Vector3(0.5, 0.45, 0.9), Vector3(0, 0.22, 0)], [BoxMesh.new(), Vector3(0.24, 0.6, 0.24), Vector3(0, 0.55, 0.42)]]:
		var n := MeshInstance3D.new()
		(part[0] as BoxMesh).size = part[1]
		n.mesh = part[0]
		n.material_override = white
		n.position = Vector3(c.x, cy, c.y) + part[2]
		world.add_child(n)
	var spire := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.0
	sc.bottom_radius = 0.14
	sc.height = 0.7
	sc.radial_segments = 4
	spire.mesh = sc
	spire.material_override = white
	spire.position = Vector3(c.x, cy + 1.2, c.y + 0.42)
	world.add_child(spire)


## A fire tower on the long ridge to the west: a lattice of legs and a little cab on top.
func _fire_tower(world: Node3D) -> void:
	var p: Array = PEAKS[3]
	var x: float = p[0] + 4.0
	var z: float = p[1] - 6.0
	var y := height(x, z)
	var steel := GardenProps.mat("skysteel", Color("6a6a66"))
	for sx: float in [-0.25, 0.25]:
		for sz: float in [-0.25, 0.25]:
			var leg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.025
			cm.bottom_radius = 0.025
			cm.height = 2.4
			cm.radial_segments = 4
			leg.mesh = cm
			leg.material_override = steel
			leg.position = Vector3(x + sx * 0.7, y + 1.2, z + sz * 0.7)
			leg.rotation = Vector3(sz * -0.25, 0, sx * 0.25)
			world.add_child(leg)
	var cab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.35, 0.5)
	cab.mesh = bm
	cab.material_override = GardenProps.mat("skycab", Color("8a6a4a"))
	cab.position = Vector3(x, y + 2.5, z)
	world.add_child(cab)


func _clouds_build(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1720
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 10
	puff.rings = 5
	for k in range(6):
		var cloud := Node3D.new()
		var a := rng.randf() * TAU
		var r := rng.randf_range(260.0, 520.0)
		cloud.position = Vector3(cos(a) * r, rng.randf_range(115.0, 165.0), sin(a) * r)
		cloud.set_meta("x0", cloud.position.x)
		cloud.set_meta("ph", rng.randf() * 120.0)
		for p in range(rng.randi_range(3, 5)):
			var b := MeshInstance3D.new()
			var slab := BoxMesh.new()
			slab.size = Vector3(10.0, 2.2, 6.0)
			b.mesh = slab
			b.material_override = m
			var s := rng.randf_range(0.8, 1.5)
			b.scale = Vector3(s * 1.5, 1.0, s)
			b.position = Vector3(rng.randf_range(-18, 18), rng.randf_range(-1.0, 1.0), rng.randf_range(-10, 10))
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(b)
		world.add_child(cloud)
		_clouds.append(cloud)
