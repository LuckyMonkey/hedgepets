extends Node3D

## Pet 1/4 - the body: the shared build budget (slices), materials, primitive regions (ellipsoids, patches, engraved shells), the eyes.
##
## A pet's body is a set of regions (head, body, ears, snout...) from its CharacterArtProfile, each a primitive (an
## ellipsoid or a patch) with an ink hull for the outline. Building a pet is expensive, so it is done in slices:
## _slice() spends a shared budget of SLICE_BUDGET_US microseconds a frame across every pet being built, so a pet
## arriving never stalls the frame. Eyes have no whites: a dark disc and a small crisp light dot (the owner's rule).
##
## Part of the pet layer chain (the full order is at the top of scripts/pet/hedge_pet_node.gd). Code here was moved verbatim
## from the old single file; only its place changed.

var profile: CharacterArtProfile
var pet: Node3D                                  # body root: hops and steps move this
var head: Node3D
var _materials := {}


## Lazy materialisation (the compact cache profile, hedgepets/pets_baked = "starters"): a visitor that isn't baked is
## built from its recipe (its profile + seed: the same code, so the same pet) a slice at a time - a shared budget of a
## few milliseconds a frame across every pet building - with its body hidden until it's whole. The node itself is made
## at the usual moment with the usual random draws, so nothing about when or where it turns up changes.
var sliced := false
static var _budget_frame := -1
static var _budget_used := 0
const SLICE_BUDGET_US := 1500


## "starters" (compact: only starting pets baked, visitors built lazily) or "all" (baseline: every pet baked).
static func pets_baked() -> String:
	var env := OS.get_environment("HEDGEPETS_PETS_BAKED")
	if env != "":
		return env
	return str(ProjectSettings.get_setting("hedgepets/pets_baked", "all"))


static var _t_last := 0


## A slice point: time since the last one (this frame, any pet) counts against the budget; over it, wait a frame.
func _slice() -> void:
	if not sliced or not is_inside_tree():
		return
	HitchLog.tag("pet_build:" + profile.pet_name)
	var now := Time.get_ticks_usec()
	var f := Engine.get_process_frames()
	if f != _budget_frame:
		_budget_frame = f
		_budget_used = 0
		_t_last = now
	elif _t_last > 0:
		_budget_used += now - _t_last
	_t_last = now
	if _budget_used > SLICE_BUDGET_US:
		await get_tree().process_frame
		_t_last = Time.get_ticks_usec()


## The eye: a soft vertical oval, deep brown-black and only gently glossy, with one crisp almost-white dot of light
## and a tiny second one, both on the same side (as if lit from one direction). No whites, no blurred sheen.
const EYE_POP := 0.22                          # eyes stand this much (x eye size) proud of the face, over the leaves
const EYE_PULL := 1.1                         # and draw this far (x eye size) toward the camera (pet_eye.gdshader)


func _build_eye(holder: Node3D, name: String, _nose_side: float) -> void:
	var s := profile.eye_size
	holder.position += holder.basis.z * s * EYE_POP
	var eye := _ellipsoid(holder, Vector3(0, 0, -s * 0.28), Vector3(s * 0.88, s * 1.12, s * 0.55), "eye", 0.035 * s / 0.155)
	eye.name = name
	if eye.material_overlay is ShaderMaterial:
		(eye.material_overlay as ShaderMaterial).set_shader_parameter("pull", s * EYE_PULL)
	var lit := -1.0 if holder.basis.x.z >= 0.0 else 1.0
	var r := Vector3(s * 0.88, s * 1.12, s * 0.55)
	for dot: Array in [[Vector2(-0.26 * lit, 0.34), 0.2], [Vector2(0.2 * lit, -0.3), 0.075]]:
		# sit exactly on the eye's curved front (inside it, a dot can't be seen)
		var xy: Vector2 = dot[0] * s
		var z := r.z * sqrt(maxf(0.0, 1.0 - pow(xy.x / r.x, 2.0) - pow(xy.y / r.y, 2.0))) + 0.004
		_ellipsoid(eye, Vector3(xy.x, xy.y, z), Vector3(1.0, 1.0, 0.25) * s * float(dot[1]), "glint")


func _mat(kind: String, region := {}) -> Material:
	var key := kind + str(region.get("color", "")) + str(region.get("mass_color", ""))
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.metallic_specular = 0.0
	match kind:
		"inner", "foliage":
			m.albedo_color = region.get("mass_color", profile.inner_mass)   # a head can be fur under its leaves
		"moss":
			m.albedo_color = profile.palette["matcha"].darkened(0.08)
		"sage":
			m.albedo_color = Color("9aa47e")
		"blossom":
			m.albedo_color = Color("efe8dc")
		"terracotta":
			m.albedo_color = Color("87634c")
		"ear":
			m.albedo_color = profile.palette["muted_ivy"].darkened(0.15) if region.get("foliage", false) else profile.palette["muted_ivy"]
		"ear_inner":
			m.albedo_color = profile.palette["muted_ivy"].darkened(0.18)
		"eye", "glint":                                  # drawn over the leaves round the face (pet_eye.gdshader)
			var e := ShaderMaterial.new()
			e.shader = preload("res://shaders/pet_eye.gdshader")
			e.set_shader_parameter("albedo", Color("1a120c") if kind == "eye" else Color("f8f4ea"))   # glint: crisp, almost white
			e.set_shader_parameter("roughness_value", 0.6)  # only gently glossy: the dots do the shining
			e.set_shader_parameter("specular_value", 0.25)
			e.set_shader_parameter("glow", 0.0 if kind == "eye" else 1.0)
			e.set_shader_parameter("pull", profile.eye_size * EYE_PULL)
			_materials[key] = e
			return e
		"nose":
			m.albedo_color = Color("2e2018")
			m.roughness = 0.32                            # a glossy nose
			m.metallic_specular = 0.6
		"tooth":
			m.albedo_color = Color("f3ead0")
		"ink":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = profile.ink_color
		"cheek":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1.0, 0.70, 0.66, 0.62)
		"tail":
			m.albedo_texture = _engraved_texture()
			m.uv1_scale = Vector3(3.0, 2.0, 1.0)
	if region.has("color"):
		m.albedo_color = region["color"]
		if kind == "ear_inner":
			m.albedo_color = (region["color"] as Color).darkened(0.3)
	_materials[key] = m
	return m


func _hull(width: float) -> ShaderMaterial:
	var hull := ShaderMaterial.new()
	hull.shader = load("res://shaders/ink_hull.gdshader")
	hull.set_shader_parameter("ink", Color(profile.ink_color.r, profile.ink_color.g, profile.ink_color.b))
	hull.set_shader_parameter("width", width * profile.outline_strength)
	return hull


const PET_FULL := 0.75                        # a head this size keeps the full 24 x 48 mesh (HedgeAnatomy.detail)


## A region's own primitive (scripts/art/hedge_anatomy.gd): bean, cushion, paddle, dome... at a centre.
func _primitive(parent: Node3D, region: Dictionary, center: Vector3, kind: String, outline := 0.0, scale := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var d := HedgeAnatomy.detail(region["radii"], PET_FULL, 48, 12)
	node.mesh = HedgeAnatomy.build_mesh(region, d.x, d.y)
	node.position = center
	node.scale = Vector3.ONE * scale
	node.material_override = _mat(kind, region)
	parent.add_child(node)
	if outline > 0.0 and profile.outline_strength > 0.0:
		node.material_overlay = _hull(outline)
	return node


func _ellipsoid(parent: Node3D, center: Vector3, radii: Vector3, kind: String, outline := 0.0) -> MeshInstance3D:
	return _primitive(parent, {"radii": radii}, center, kind, outline)


func _build_regions() -> void:
	for name in profile.regions:
		await _slice()
		HitchLog.tag("pet_part:%s/%s" % [profile.pet_name, name])
		var r: Dictionary = profile.regions[name]
		var parent: Node3D = head if (name == "HEAD" or r.get("parent", "") == "HEAD") else pet
		var center: Vector3 = Vector3.ZERO if name == "HEAD" else r["center"]
		var kind: String = "inner" if r.get("foliage", false) else str(r.get("material", "moss"))
		var outline: float = 0.0 if r.get("foliage", false) else float(r.get("outline", 0.0))
		if name == "FEET":
			var lift: float = r["radii"].y * float(HedgeAnatomy._shape(r).get("flat_bottom", 1.0))
			for f in profile.feet:
				await _slice()
				var foot := _primitive(pet, r, f + Vector3(0, lift, 0), kind, outline)
				foot.name = "FOOT"
				# little toes along the front of each foot
				var rr: Vector3 = r["radii"]
				for k in range(int(r.get("toes", 0))):
					await _slice()
					var z := (float(k) / maxf(1.0, float(r.get("toes", 1)) - 1.0) - 0.5) * rr.z * 1.1
					var toe := {"radii": rr * Vector3(0.3, 0.42, 0.26), "shape": {"exponent": 2.0, "flat_bottom": 0.4}}
					_primitive(foot, toe, Vector3(rr.x * 0.86, -rr.y * 0.35, z), kind, outline * 0.7)
			continue
		if r.has("surface"):
			await _build_patch(name, r, parent, center)
			continue
		if kind == "inner":
			# the mass under the leaves is dense moss too (a few short shells), so a gap reads as moss, not skin
			await _build_patch(name, r, parent, center, 3, profile.inner_mass.lightened(0.4), 0.97)
			continue
		var sides := [1.0, -1.0] if r.get("mirror", false) else [1.0]
		for side: float in sides:
			await _slice()
			var node := _primitive(parent, r, center * Vector3(1, 1, side), kind, outline, 0.97 if r.get("foliage", false) else 1.0)
			node.name = name
			var rot: Vector3 = r.get("rotation", Vector3.ZERO)
			node.rotation_degrees = Vector3(rot.x * side, rot.y * side, rot.z)
			if kind == "ear":   # a little cup inside
				var inner := _primitive(node, r, Vector3(0.03, -0.01, 0.0), "ear_inner", 0.0, 0.62)
				inner.scale.z = 0.9


## A patch: a region surfaced in short grass / moss fibres instead of leaves (shaders/moss_patch.gdshader): the
## region's mesh as a solid base plus shells. Snouts and markings; any region with "surface": "moss".
const PATCH_SHELLS := 9


func _build_patch(name: String, r: Dictionary, parent: Node3D, center: Vector3, shells := PATCH_SHELLS, colour := Color(0, 0, 0, 0), scale := 1.0) -> void:
	await _slice()
	var d := HedgeAnatomy.detail(r["radii"], PET_FULL, 48, 12)
	var mesh := HedgeAnatomy.build_mesh(r, d.x, d.y)
	await _slice()
	var radii: Vector3 = r["radii"]
	var size := (radii.x + radii.y + radii.z) / 3.0
	var tint: Color = colour if colour.a > 0.0 else r.get("tint_color", patch_tint(profile))
	var sides := [1.0, -1.0] if r.get("mirror", false) else [1.0]
	for side: float in sides:
		await _slice()
		var holder := Node3D.new()
		holder.name = name
		holder.position = center * Vector3(1, 1, side)
		var rot: Vector3 = r.get("rotation", Vector3.ZERO)
		holder.rotation_degrees = Vector3(rot.x * side, rot.y * side, rot.z)
		holder.scale = Vector3.ONE * scale
		parent.add_child(holder)
		for k in range(shells + 1):
			await _slice()
			var m := ShaderMaterial.new()
			m.shader = preload("res://shaders/moss_patch.gdshader")
			m.set_shader_parameter("layer", float(k) / shells)
			m.set_shader_parameter("pile", clampf(size * 0.22, 0.02, 0.07) if shells == PATCH_SHELLS else 0.035)
			m.set_shader_parameter("density", clampf(10.0 / size, 32.0, 90.0) if shells == PATCH_SHELLS else 46.0)   # fine fibres, never dots
			m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
			var shell := MeshInstance3D.new()
			shell.mesh = mesh
			shell.material_override = m
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if k == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(shell)


## The patch colour for any plant: the palette's fresh yellow-green, nudged in hue and a little lighter and softer,
## so green ivy gets a fresh moss, a crimson maple fox a warm rust moss (no separate texture per plant).
static func patch_tint(p: CharacterArtProfile) -> Color:
	var base: Color = p.palette["warm_yellow_green"]
	return Color.from_hsv(fposmod(base.h + 0.035, 1.0), base.s * 0.78, minf(1.0, base.v * 1.12))


## Engraved crosshatch for a paddle tail: warm wood with a restrained diamond pattern (painted once, shared).
static var _engraved: Texture2D


func _engraved_texture() -> Texture2D:
	if _engraved != null:
		return _engraved
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in range(128):
		for x in range(128):
			# warm wood, a little lighter in the middle of each diamond, crisp dark scale lines
			var u := posmod(x + y, 21)
			var v := posmod(x - y, 21)
			var mid := (1.0 - absf(u - 10.5) / 10.5) * (1.0 - absf(v - 10.5) / 10.5)
			var c := Color("6e4a2e").lerp(Color("9a6c44"), mid * 0.8)
			if u < 2 or v < 2:
				c = Color("3a2416")
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_engraved = ImageTexture.create_from_image(img)
	return _engraved
