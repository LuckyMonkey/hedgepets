class_name CreatureDefinition
extends RefCounted

## Authored creature grammar. Plant composition reads this data but never
## needs to know how the beaver features are drawn.
const BODY_CENTER := Vector2(515.0, 1055.0)
const BODY_RADII := Vector2(330.0, 188.0)
const HEAD_CENTER := Vector2(795.0, 918.0)
const HEAD_RADII := Vector2(184.0, 150.0)
const TAIL_CENTER := Vector2(190.0, 1070.0)
const TAIL_RADII := Vector2(155.0, 88.0)


static func body_point(normalized_point: Vector2) -> Vector2:
	return BODY_CENTER + Vector2(normalized_point.x * BODY_RADII.x, normalized_point.y * BODY_RADII.y)


static func feature_anchors() -> Array[Dictionary]:
	return [
		{"name": "eye", "center": Vector2(842.0, 900.0), "radius": 74.0, "weight": 1.0},
		{"name": "nose", "center": Vector2(962.0, 945.0), "radius": 78.0, "weight": 1.0},
		{"name": "teeth", "center": Vector2(930.0, 1018.0), "radius": 92.0, "weight": 0.92},
		{"name": "face", "center": Vector2(882.0, 944.0), "radius": 166.0, "weight": 0.30},
	]


static func face_anchor(name: String) -> Dictionary:
	for anchor in feature_anchors():
		if anchor["name"] == name:
			return anchor
	return {"name": name, "center": HEAD_CENTER, "radius": 80.0, "weight": 1.0}
