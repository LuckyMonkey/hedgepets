extends CanvasLayer

## Developer-only art inspection (F1 toggles it; it never appears in the player's view).
## Toggles show the parts of the illustration separately: base primitives, anatomical regions, facial anchors,
## face-protection zones, foliage clusters, leaves, silhouette bounds (max displacement), surface normals,
## lighting. Sliders tune the profile live and regrow the foliage from the same seed.

var pet3d: Node3D           # the hedge_pet_3d.gd node
var overlay: Node3D
var _toggles := {}
const REGION_COLORS := {"BODY": Color(0.2, 0.6, 1.0, 0.25), "HEAD": Color(1.0, 0.6, 0.2, 0.3), "MUZZLE": Color(1.0, 1.0, 0.2, 0.35),
	"TAIL": Color(0.8, 0.3, 0.9, 0.3), "EARS": Color(0.3, 1.0, 0.6, 0.35), "FEET": Color(1.0, 0.3, 0.3, 0.35)}


func _ready() -> void:
	pet3d = get_parent()
	layer = 50
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.1, 0.82)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ART DEBUG · %s (F1)" % pet3d.profile.pet_name
	box.add_child(title)
	for t in ["base primitives", "regions", "anchors", "face zones", "clusters", "leaves", "silhouette bounds", "normals", "lighting"]:
		var cb := CheckBox.new()
		cb.text = t
		cb.button_pressed = t in ["leaves", "lighting"]
		cb.toggled.connect(func(_on: bool) -> void: _apply())
		_toggles[t] = cb
		box.add_child(cb)
	var p: CharacterArtProfile = pet3d.profile
	_slider(box, "foliage density", 0.3, 2.0, 1.0, func(v: float) -> void: _scale_density(v))
	_slider(box, "cluster size", 0.2, 0.9, p.cluster_spread, func(v: float) -> void: p.cluster_spread = v)
	_slider(box, "leaf scale", 0.2, 0.7, p.leaf_size, func(v: float) -> void: p.leaf_size = v)
	_slider(box, "silhouette displacement", 0.0, 2.5, p.silhouette_scale, func(v: float) -> void: p.silhouette_scale = v)
	_slider(box, "face clearing", 0.0, 2.0, p.face_clearing, func(v: float) -> void: p.face_clearing = v)
	_slider(box, "color variation", 0.0, 0.2, p.color_variation, func(v: float) -> void: p.color_variation = v)
	_slider(box, "outline strength", 0.0, 2.0, p.silhouette_ink, _set_outline, false)
	_slider(box, "shadow softness", 0.0, 10.0, p.shadow_softness, _set_shadow, false)
	var lod := OptionButton.new()
	for level in ["AUTO", "CLOSE", "MEDIUM", "FAR"]:
		lod.add_item(level)
	lod.item_selected.connect(func(i: int) -> void:
		pet3d.auto_detail = i == 0
		if i > 0:
			pet3d.set_detail(["", "CLOSE", "MEDIUM", "FAR"][i]))
	box.add_child(lod)
	overlay = Node3D.new()
	overlay.name = "ArtDebugOverlay"
	pet3d.pet.add_child(overlay)
	_apply()


func _exit_tree() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if is_instance_valid(pet3d):
		for node in pet3d.foliage_nodes:
			node.visible = true
		pet3d.sun.visible = true
		pet3d.fill.visible = true


var _density_base := {}


func _set_outline(v: float) -> void:
	pet3d.profile.silhouette_ink = v
	pet3d.profile.interior_ink = v * 0.35


func _set_shadow(v: float) -> void:
	pet3d.profile.shadow_softness = v
	pet3d.sun.shadow_blur = v


func _scale_density(v: float) -> void:
	for name in pet3d.profile.regions:
		if not _density_base.has(name):
			_density_base[name] = float(pet3d.profile.regions[name]["density"])
		pet3d.profile.regions[name]["density"] = _density_base[name] * v


func _slider(box: VBoxContainer, label: String, lo: float, hi: float, value: float, setter: Callable, regrow := true) -> void:
	var l := Label.new()
	l.text = "%s  %.2f" % [label, value]
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = value
	s.custom_minimum_size = Vector2(260, 18)
	s.value_changed.connect(func(v: float) -> void: l.text = "%s  %.2f" % [label, v])
	s.drag_ended.connect(func(_changed: bool) -> void:
		setter.call(s.value)
		if regrow:
			pet3d.rebuild_foliage()
		else:
			pet3d.leaves_mat.set_shader_parameter("silhouette_ink", pet3d.profile.silhouette_ink)
			pet3d.leaves_mat.set_shader_parameter("interior_ink", pet3d.profile.interior_ink)
		_apply())
	box.add_child(s)


func _on(name: String) -> bool:
	return _toggles[name].button_pressed


func _apply() -> void:
	for child in overlay.get_children():
		child.queue_free()
	var p: CharacterArtProfile = pet3d.profile
	for node in pet3d.foliage_nodes:
		node.visible = _on("leaves")
	pet3d.sun.visible = _on("lighting")
	pet3d.fill.visible = _on("lighting")
	var head_c: Vector3 = p.regions["HEAD"]["center"]
	if _on("regions") or _on("base primitives") or _on("silhouette bounds"):
		for name in p.regions:
			var r: Dictionary = p.regions[name]
			var c: Vector3 = r["center"] + (head_c if r.get("parent", "") == "HEAD" else Vector3.ZERO)
			if name == "FEET":
				continue
			if _on("regions") or _on("base primitives"):
				_blob(c, r["radii"], REGION_COLORS.get(name, Color(1, 1, 1, 0.3)) if _on("regions") else Color(0.8, 0.8, 0.8, 0.35))
			if _on("silhouette bounds") and r.get("foliage", false):
				var grow := float(r["max_displacement"]) * p.silhouette_scale + p.leaf_size * float(r["leaf_scale"]) * 0.5
				_blob(c, r["radii"] + Vector3.ONE * grow, Color(1.0, 0.2, 0.2, 0.12))
	if _on("anchors") or _on("face zones"):
		for name in p.anchors:
			var a := HedgeAnatomy.anchor_point(p, name) + head_c
			if _on("anchors"):
				_blob(a, Vector3.ONE * 0.05, Color(1, 0, 0.6, 0.9))
			if _on("face zones") and p.protected_zones.has(name):
				var zr := float(p.protected_zones[name]["radius"]) * p.face_clearing * 0.7
				_blob(a, Vector3.ONE * zr, Color(1.0, 0.9, 0.2, 0.18))
	if _on("clusters") or _on("normals"):
		for c in pet3d.cluster_debug:
			var parent: Node3D = c["parent"]
			var pos: Vector3 = c["position"] + (head_c if parent == pet3d.head else Vector3.ZERO)
			if _on("clusters"):
				_blob(pos, Vector3.ONE * 0.07, Color(c["color"].r, c["color"].g, c["color"].b, 1.0))
			if _on("normals"):
				_blob(pos + c["normal"] * 0.2, Vector3(0.02, 0.02, 0.02), Color(0.2, 0.4, 1.0, 1.0))
				_blob(pos + c["normal"] * 0.1, Vector3(0.015, 0.015, 0.015), Color(0.2, 0.4, 1.0, 1.0))


func _blob(center: Vector3, radii: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = center
	node.scale = radii
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
	node.material_override = m
	overlay.add_child(node)
