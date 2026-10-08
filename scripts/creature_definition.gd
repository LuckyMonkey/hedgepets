class_name CreatureDefinition
extends RefCounted

## Authored creature grammar. Plant composition reads this data but never
## needs to know how the face is drawn.
##
## The pet is a chibi hedge: a big round head on a small round body, standing on
## two little terracotta pot feet. Everything is in viewport pixels (1080 x 1920).
const HEAD_CENTER := Vector2(540.0, 820.0)
const HEAD_RADII := Vector2(255.0, 228.0)
const BODY_CENTER := Vector2(540.0, 1095.0)
const BODY_RADII := Vector2(232.0, 168.0)
const FEET_Y := 1262.0                       # where the pots stand; the pet breathes and hops from here
const EYE_LEFT := Vector2(452.0, 842.0)
const EYE_RIGHT := Vector2(628.0, 842.0)
const EYE_RADIUS := 37.0
const NOSE := Vector2(540.0, 902.0)
const SPROUT_BASE := Vector2(540.0, 600.0)

## The first sketch (a side-on hedge beaver). Older composition anchors were
## authored against it; remap_legacy() carries them onto the current shape.
const LEGACY_BODY_CENTER := Vector2(515.0, 1055.0)
const LEGACY_BODY_RADII := Vector2(330.0, 188.0)
const LEGACY_HEAD_CENTER := Vector2(795.0, 918.0)
const LEGACY_HEAD_RADII := Vector2(184.0, 150.0)


static func body_point(normalized_point: Vector2) -> Vector2:
	return BODY_CENTER + Vector2(normalized_point.x * BODY_RADII.x, normalized_point.y * BODY_RADII.y)


## A point authored on the legacy beaver, moved to the same place on the current
## body: head points to the head, everything else (body, tail) to the body.
static func remap_legacy(point: Vector2) -> Vector2:
	var head_delta := (point - LEGACY_HEAD_CENTER) / LEGACY_HEAD_RADII
	var body_delta := (point - LEGACY_BODY_CENTER) / LEGACY_BODY_RADII
	if head_delta.length() < body_delta.length():
		# the beaver looked right; the new face looks at you, so the head is mirrored to spread round the crown
		return HEAD_CENTER + Vector2(head_delta.x * HEAD_RADII.x * 0.9, head_delta.y * HEAD_RADII.y)
	return BODY_CENTER + Vector2(clampf(body_delta.x, -1.25, 1.25) * BODY_RADII.x * 0.82, body_delta.y * BODY_RADII.y)


static func feature_anchors() -> Array[Dictionary]:
	# Leaves stay clear of the face so the eyes always read.
	return [
		{"name": "eye_left", "center": EYE_LEFT, "radius": 82.0, "weight": 1.0},
		{"name": "eye_right", "center": EYE_RIGHT, "radius": 82.0, "weight": 1.0},
		{"name": "nose", "center": NOSE, "radius": 70.0, "weight": 1.0},
		{"name": "face", "center": Vector2(540.0, 880.0), "radius": 170.0, "weight": 0.86},
	]


static func face_anchor(name: String) -> Dictionary:
	for anchor in feature_anchors():
		if anchor["name"] == name:
			return anchor
	return {"name": name, "center": HEAD_CENTER, "radius": 80.0, "weight": 1.0}
