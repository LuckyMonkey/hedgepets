extends "res://scripts/pet/node/pet_body.gd"

## Pet 2/4 - the face: anchors on the head, and the strokes of its features.
##
## The face is placed by anchors on the head (_anchor), in the head's own space, so it follows the head when it tilts.
## Features are short strokes (_stroke), drawn like ink.
##
## Part of the pet layer chain (the full order is at the top of scripts/pet/hedge_pet_node.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var eyes: Array[Node3D] = []
var heart: Label3D
# ------------------------------------------------------------------ the face (head-local anchors)


func _anchor(name: String) -> Vector3:
	return HedgeAnatomy.anchor_point(profile, name)


func _build_face() -> void:
	var f: Dictionary = profile.features
	# eyes: dark, round, a little oversized, like ceramic or ink; one restrained highlight; an ink rim
	for name in ["EYE_LEFT", "EYE_RIGHT"]:
		await _slice()
		if not profile.anchors.has(name):
			continue
		var holder := Node3D.new()
		holder.position = _anchor(name)
		# a steady frame on the face: +z out of the face, +y up, so "white below" or "toward the nose" means the
		# same on every pet and both eyes
		var n := HedgeAnatomy.anchor_normal(profile, name).normalized()
		var up := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
		holder.basis = Basis(up.cross(n), up, n)
		head.add_child(holder)
		_build_eye(holder, name, Vector3.RIGHT.dot(holder.basis.x))
		eyes.append(holder)
	if profile.anchors.has("NOSE"):
		await _slice()
		_ellipsoid(head, _anchor("NOSE"), f.get("nose", Vector3(0.1, 0.08, 0.12)), "nose", 0.012)
	if profile.anchors.has("MOUTH"):
		await _slice()
		var nose := _anchor("NOSE")
		var mouth := _anchor("MOUTH")
		var w: float = f.get("nose", Vector3(0.1, 0.08, 0.12)).z
		match str(f.get("mouth", "smile")):
			"beaver", "bunny":   # down from the nose, then a small curve each side
				_stroke([nose + Vector3(0, -w * 0.5, 0), mouth])
				for side: float in [1.0, -1.0]:
					var pts: Array[Vector3] = []
					for k in range(6):
						var t := float(k) / 5.0
						pts.append(mouth + Vector3(-w * 0.15 * sin(t * PI), w * 0.25 * sin(t * PI), side * t * w * 0.9))
					_stroke(pts)
			_:                   # a simple smile
				var pts: Array[Vector3] = []
				for k in range(9):
					var t := float(k) / 8.0 * 2.0 - 1.0
					pts.append(mouth + Vector3(0.0, (1.0 - t * t) * -w * 0.25 + w * 0.2, t * w * 1.3))
				_stroke(pts)
	if f.get("teeth", false) and profile.anchors.has("TEETH"):
		await _slice()
		var w2: float = f.get("nose", Vector3(0.1, 0.08, 0.12)).z
		for side: float in [1.0, -1.0]:
			var tooth := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.36, 1.2, 0.6) * w2 * 0.85
			tooth.mesh = box
			tooth.material_override = _mat("tooth")
			tooth.position = _anchor("TEETH") + Vector3(0.06, -0.05, side * w2 * 0.33) * (w2 / 0.14)
			head.add_child(tooth)
			tooth.material_overlay = _hull(0.008)
	if f.get("cheeks", false):
		for name in ["CHEEK_LEFT", "CHEEK_RIGHT"]:
			await _slice()
			if not profile.anchors.has(name):
				continue
			var cheek := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = profile.eye_size * 0.8
			disc.bottom_radius = profile.eye_size * 0.8
			disc.height = 0.005
			cheek.mesh = disc
			cheek.material_override = _mat("cheek")
			cheek.position = _anchor(name)
			cheek.basis = Basis(Quaternion(Vector3.UP, HedgeAnatomy.anchor_normal(profile, name))).scaled(Vector3(1.0, 1.0, 0.7))
			head.add_child(cheek)
	heart = Label3D.new()
	heart.text = "♥"
	heart.font_size = 140
	heart.modulate = Color(0.93, 0.45, 0.48, 0.0)
	heart.outline_modulate = Color(0, 0, 0, 0)
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.position = Vector3(0.2, 1.1, 0.0)
	head.add_child(heart)


func _stroke(points: Array[Vector3]) -> void:
	var width := clampf(profile.eye_size * 0.09, 0.008, 0.016)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = width
		cyl.bottom_radius = width
		cyl.height = a.distance_to(b) + width
		cyl.radial_segments = 6
		seg.mesh = cyl
		seg.material_override = _mat("ink")
		seg.position = (a + b) * 0.5
		seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		head.add_child(seg)
