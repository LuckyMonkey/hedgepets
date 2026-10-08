class_name FoliageBuilder
extends RefCounted

## Hierarchical, seeded foliage for one region:
##   level 1  the region's mass (drawn elsewhere: the inner green under the leaves)
##   level 2  clusters - evenly spaced clumps with gaps between them (negative space on purpose)
##   level 3  leaves - each belongs to a cluster: a big crown leaf and smaller ones around it, lying along the
##            surface and lifting off it no further than the region's max_displacement (the silhouette control)
##   level 4  flowers on a few clusters (never near the face)
## Same seed + same profile = the same Gerald, leaf for leaf.
##
## Output per leaf: [Transform3D, Color, Color custom]
##   custom.x sprite cell (0-7 leaves, 13 flower), custom.y wind phase, custom.z wind reach, custom.w rank
##   (0 = a cluster's crown leaf .. 1 = its smallest; the shader drops high ranks at lower detail levels).

const UP := Vector3.UP


static func build(profile: CharacterArtProfile, region_name: String, head_center: Vector3, key_dir: Vector3) -> Dictionary:
	# pure function of the profile and these inputs: every stored property of the profile goes in the key, so any
	# change is a cache miss (built live), never a stale result (util/bake_cache.gd)
	var parts: Array = ["foliage", region_name, head_center, key_dir]
	for prop in profile.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["name"] != "script" and prop["name"] != "resource_path":
			parts.append(profile.get(prop["name"]))
	var k := BakeCache.key(parts)
	var cached = BakeCache.fetch(k)
	if cached != null:
		return cached
	var out := _build_live(profile, region_name, head_center, key_dir)
	BakeCache.store(k, out)
	return out


static func _build_live(profile: CharacterArtProfile, region_name: String, head_center: Vector3, key_dir: Vector3) -> Dictionary:
	var region: Dictionary = profile.regions[region_name]
	# built in the space of the region's parent node: the head node sits at the HEAD centre (so HEAD is at the
	# origin there), regions attached to the head use their head-local centre, the rest creature space
	var c: Vector3 = Vector3.ZERO if region_name == "HEAD" else region["center"]
	var on_head: bool = region_name == "HEAD" or region.get("parent", "") == "HEAD"
	var flowers_only: bool = region.get("flowers", false)
	var r: Vector3 = region["radii"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(profile.seed) + region_name)
	var items: Array = []
	var clusters: Array = []
	var is_head := on_head
	var leaf_len: float = profile.leaf_size * float(region["leaf_scale"])
	var max_disp: float = float(region["max_displacement"]) * profile.silhouette_scale
	# ---- level 2: cluster centres, evenly spread (Fibonacci sphere, jittered), kept apart, sized by area
	var area := 4.0 * PI * pow((pow(r.x * r.y, 1.6) + pow(r.x * r.z, 1.6) + pow(r.y * r.z, 1.6)) / 3.0, 1.0 / 1.6)
	var wanted := int(area * 2.6 * float(region["density"]) * clampf(profile.growth, 0.2, 1.0))
	var candidates := maxi(wanted * 3, 12)
	var dirs: Array[Vector3] = []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in range(candidates):
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(candidates)
		var rad := sqrt(1.0 - y * y)
		var d := Vector3(cos(golden * i) * rad, y, sin(golden * i) * rad)
		d = (d + Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))).normalized()
		if d.y < -0.42:
			continue                                             # nothing grows on the underside
		var p := HedgeAnatomy.shape_point(region, c, d)
		var head_local := p if is_head else (p - head_center)
		if HedgeAnatomy.protection(profile, head_local) > 0.72 or HedgeAnatomy.in_patch(profile, p, is_head):
			continue                                             # no cluster is centred on the face or a patch
		var apart := true
		for other in dirs:
			if d.angle_to(other) < profile.cluster_min_gap * (0.8 if is_head else 1.0):
				apart = false
				break
		if apart:
			dirs.append(d)
	# shuffle deterministically, then keep as many as growth allows
	for i in range(dirs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := dirs[i]
		dirs[i] = dirs[j]
		dirs[j] = t
	dirs = dirs.slice(0, mini(dirs.size(), wanted))
	# ---- level 3: leaves in each cluster
	for ci in range(dirs.size()):
		var cd: Vector3 = dirs[ci]
		var cp := HedgeAnatomy.shape_point(region, c, cd)
		var cn := HedgeAnatomy.shape_normal(region, c, cp)
		var family := _family(profile, cn, key_dir, rng)
		if region.has("tint"):                                   # e.g. a face of younger, lighter leaves
			family = family.lerp(profile.palette[region["tint"]], float(region.get("tint_amount", 0.5)))
		elif region.has("tint_color"):                           # a marking: a mask of dark leaves, a pale stripe
			family = family.lerp(region["tint_color"], float(region.get("tint_amount", 0.5)))
		clusters.append({"position": cp, "normal": cn, "color": family})
		var count := int(float(region.get("leaves_per_cluster", profile.leaves_per_cluster)) * (0.75 if is_head else 1.0))
		for li in range(count):
			var crown := li == 0
			var offset := Vector2.ZERO if crown else Vector2(rng.randfn(0.0, 0.55), rng.randfn(0.0, 0.55)).limit_length(1.6)
			var t1 := cn.cross(UP if absf(cn.y) < 0.95 else Vector3.RIGHT).normalized()
			var t2 := cn.cross(t1).normalized()
			var d := (cd + (t1 * offset.x + t2 * offset.y) * profile.cluster_spread).normalized()
			var p := HedgeAnatomy.shape_point(region, c, d)
			if not is_head and p.y < 0.2 and region_name == "BODY":
				continue                                         # nothing touches the ground
			var n := HedgeAnatomy.shape_normal(region, c, p)
			var head_local := p if is_head else (p - head_center)
			var protect := HedgeAnatomy.protection(profile, head_local)
			if not crown and rng.randf() > float(region.get("coverage", profile.coverage)):
				continue
			if rng.randf() < protect:
				continue                                         # thinning smoothly toward the face
			if HedgeAnatomy.in_patch(profile, p, is_head):
				continue                                         # a moss patch (snout, marking) stays clear of leaves
			var dist := offset.length() / 1.6
			var size := leaf_len * lerpf(1.18, 0.62, dist) * rng.randf_range(0.88, 1.1) * lerpf(1.0, 0.3, protect)
			var leaf: Array = _leaf(p, n, size, max_disp, float(region["growth_up"]), cd, rng, family, profile, crown, dist)
			if flowers_only:                                     # a region made of blossom (a cotton tail)
				var custom: Color = leaf[2]
				custom.r = 13.0
				leaf[2] = custom
				leaf[1] = profile.palette.get("blossom", Color(1.0, 0.98, 0.94))
			items.append(leaf)
		# ---- level 4: a flower on some clusters, well away from the face
		if region_name == "BODY" and not flowers_only and rng.randf() < profile.flowering * 0.55 and cn.y > -0.1:
			var head_local := cp - head_center
			if HedgeAnatomy.protection(profile, head_local) < 0.05 and cp.distance_to(head_center) > 1.1:
				# a flower sits ON the leaves, facing out (not tucked under them), a little turned
				var fsize := leaf_len * 0.78
				var tan := cn.cross(Vector3.UP if absf(cn.y) < 0.9 else Vector3.RIGHT).normalized().rotated(cn, rng.randf_range(0.0, TAU))
				var up := cn.cross(tan).normalized()
				var centre := cp + cn * (max_disp * 0.85 + 0.05)
				var flower: Array = [Transform3D(Basis(tan * fsize, up * fsize, cn * fsize), centre - up * fsize * 0.62),
					profile.flower_color, Color(13.0, rng.randf_range(0.0, TAU), 0.6, 0.3)]   # the flower sprite; drawn at FAR detail
				items.append(flower)
	return {"items": items, "clusters": clusters}


## A cluster's colour family: lit, upward clusters lean to matcha and warm yellow-green; shaded ones to deep forest;
## the middle to muted ivy and sage. Picked deterministically among two neighbours, then gently varied.
static func _family(profile: CharacterArtProfile, n: Vector3, key_dir: Vector3, rng: RandomNumberGenerator) -> Color:
	var exposure := clampf(0.5 + 0.35 * n.dot(UP) + 0.35 * n.dot(-key_dir.normalized()), 0.0, 1.0)
	var ladder := ["deep_forest", "muted_ivy", "soft_sage", "matcha", "warm_yellow_green"]
	var at := exposure * float(ladder.size() - 1)
	var i := clampi(int(at + rng.randf_range(-0.6, 0.6)), 0, ladder.size() - 1)
	var base: Color = profile.palette[ladder[i]]
	return base.lerp(profile.palette["muted_ivy"], 0.18)


static func _leaf(p: Vector3, n: Vector3, size: float, max_disp: float, growth_up: float, cluster_dir: Vector3,
		rng: RandomNumberGenerator, family: Color, profile: CharacterArtProfile, crown: bool, dist: float) -> Array:
	# growth tangent: away from the cluster centre and a little upward (ivy climbs), with bounded variation
	var away := (p.normalized() - cluster_dir).normalized() if not crown else UP
	var grow := (away * 0.7 + UP * growth_up)
	var t := (grow - n * grow.dot(n))
	if t.length() < 0.05:
		t = n.cross(Vector3.FORWARD)
	t = t.normalized().rotated(n, rng.randf_range(-0.35, 0.35))
	# lift the tip off the surface, never further than max_displacement allows
	var max_lift := asin(clampf(max_disp / maxf(size, 0.01), 0.0, 1.0))
	var lift := rng.randf_range(0.12, 0.35) if max_lift < 0.12 else rng.randf_range(0.12, maxf(0.13, max_lift))
	var right := t.cross(n).normalized()
	var up := (t * cos(lift) + n * sin(lift)).normalized()
	var normal := right.cross(up).normalized()
	var basis := Basis(right * size, up * size, normal * size)
	var color := family.lightened(rng.randf_range(-profile.color_variation, profile.color_variation))
	if crown:
		color = color.lightened(0.05)                            # the newest leaf at the crown, a touch paler
	var rank := 0.0 if crown else clampf(0.2 + dist * 0.6 + rng.randf_range(-0.1, 0.15), 0.05, 1.0)
	var custom := Color(float(rng.randi_range(0, 7)), rng.randf_range(0.0, TAU), lerpf(0.5, 1.0, dist), rank)
	return [Transform3D(basis, p - n * 0.02), color, custom]
