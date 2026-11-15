extends SceneTree

## Same seed + same profile = the same Gerald, leaf for leaf; a different seed = a different bush.
func _init() -> void:
	var p := CharacterArtProfile.gerald()
	var key := Vector3(0.5, -0.8, 0.3).normalized()
	var head_c: Vector3 = p.regions["HEAD"]["center"]
	var a: Array = FoliageBuilder.build(p, "BODY", head_c, key)["items"]
	var b: Array = FoliageBuilder.build(p, "BODY", head_c, key)["items"]
	var same: bool = a.size() == b.size()
	for i in range(mini(a.size(), b.size())):
		if a[i][0] != b[i][0] or a[i][1] != b[i][1] or a[i][2] != b[i][2]:
			same = false
			break
	p.seed = 2024
	var c: Array = FoliageBuilder.build(p, "BODY", head_c, key)["items"]
	var different: bool = c.size() != a.size() or c[0][0] != a[0][0]
	print("deterministic: %s (%d leaves) | another seed differs: %s" % [same, a.size(), different])
	quit(0 if same and different else 1)
