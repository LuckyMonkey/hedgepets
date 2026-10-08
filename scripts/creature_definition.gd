class_name CreatureDefinition
extends RefCounted

## Authored creature grammar. Plant composition reads this data but never
## needs to know how the face is drawn.
##
## The pet is a beaver made of ivy - a botanical creature, not an animal under plants (hedgepetsGoal.jpg), seen three-quarters from the front-right: a big
## rounded body, the head forward and to the right, the flat tail behind, four little feet (the far ones smaller).
## Everything is in viewport pixels (1080 x 1920).
const BODY_CENTER := Vector2(505.0, 1045.0)
const BODY_RADII := Vector2(318.0, 212.0)
const HEAD_CENTER := Vector2(805.0, 925.0)
const HEAD_RADII := Vector2(172.0, 148.0)
const TAIL_CENTER := Vector2(170.0, 1125.0)
const TAIL_RADII := Vector2(150.0, 92.0)
const EAR := Vector2(742.0, 792.0)
const FEET_Y := 1262.0                       # the ground: the pet breathes and hops from here
const EYE := Vector2(842.0, 900.0)
const EYE_RADIUS := 20.0
const NOSE := Vector2(955.0, 948.0)
const TEETH := Vector2(930.0, 998.0)
# feet: [centre, size, far?]
const FEET := [
	[Vector2(338.0, 1236.0), 0.82, true], [Vector2(640.0, 1230.0), 0.84, true],
	[Vector2(430.0, 1252.0), 1.0, false], [Vector2(742.0, 1246.0), 1.0, false],
]

## The first sketch's layout (the same beaver, drawn flat). Older composition anchors were authored against it;
## remap_legacy() carries them onto the current proportions.
const LEGACY_BODY_CENTER := Vector2(515.0, 1055.0)
const LEGACY_BODY_RADII := Vector2(330.0, 188.0)
const LEGACY_HEAD_CENTER := Vector2(795.0, 918.0)
const LEGACY_HEAD_RADII := Vector2(184.0, 150.0)


static func body_point(normalized_point: Vector2) -> Vector2:
	return BODY_CENTER + Vector2(normalized_point.x * BODY_RADII.x, normalized_point.y * BODY_RADII.y)


static func remap_legacy(point: Vector2) -> Vector2:
	var head_delta := (point - LEGACY_HEAD_CENTER) / LEGACY_HEAD_RADII
	var body_delta := (point - LEGACY_BODY_CENTER) / LEGACY_BODY_RADII
	if head_delta.length() < body_delta.length():
		return HEAD_CENTER + head_delta * HEAD_RADII
	return BODY_CENTER + body_delta * BODY_RADII


static func feature_anchors() -> Array[Dictionary]:
	# A fully botanical creature: leaves grow right up to the features and only part around the berry eye, the
	# seed nose and the seed teeth. The muzzle is mossy (smaller, lighter leaves), not bare.
	return [
		{"name": "eye", "center": EYE, "radius": 34.0, "weight": 1.0},
		{"name": "nose", "center": NOSE, "radius": 36.0, "weight": 1.0},
		{"name": "teeth", "center": TEETH, "radius": 38.0, "weight": 0.95},
		{"name": "muzzle", "center": Vector2(905.0, 960.0), "radius": 95.0, "weight": 0.45},
	]


static func face_anchor(name: String) -> Dictionary:
	for anchor in feature_anchors():
		if anchor["name"] == name:
			return anchor
	return {"name": name, "center": HEAD_CENTER, "radius": 80.0, "weight": 1.0}
