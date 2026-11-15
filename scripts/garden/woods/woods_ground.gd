extends Elsewhere

## Woods 1/6 - the ground: the map of clearings and trails, the terrain height, the creek and pond water, and the stable IDs of hand-placed things.
##
## Everything else in the woods stands on this. NODES and EDGES are the map: the clearings and which trails join
## them. height() is the terrain (hills from noise, carved down where a trail or the creek runs) and water_at() /
## pond_level() say where water is. Nothing here builds a node: these are questions about the land, so every later
## layer can ask them in any order without changing what gets built.
##
## Hand-placed things (the world editor's woods overrides) get their stable IDs here too (_placement), because the
## scenery and landmark layers both register what they place.
##
## Part of the woods layer chain (see scripts/garden/woods.gd for the full order). Code here was moved verbatim from
## the old single file; only its place changed.

const ORIGIN := Vector3(0, -300, 0)             # far below everything: nothing of the garden is ever in view
const EYE := 1.5
const NODES := {
	"trailhead": {"at": Vector2(0, 0), "lift": 0.0, "name": "The trailhead"},
	"fork": {"at": Vector2(2, -24), "lift": 1.5, "name": "The mossy fork"},
	"hollow": {"at": Vector2(-22, -38), "lift": -6.0, "name": "Fern hollow"},
	"ridge": {"at": Vector2(22, -44), "lift": 10.0, "name": "The ridge"},
	"creek": {"at": Vector2(-28, -64), "lift": -3.0, "name": "Creek crossing"},
	"oak": {"at": Vector2(4, -70), "lift": 2.0, "name": "The old oak", "room": 10.0},
	"nursery": {"at": Vector2(24, -16), "lift": 0.5, "name": "The nursery", "flat": 9.0, "room": 12.0},
	"pond": {"at": Vector2(-42, -90), "lift": -3.0, "name": "Beaver pond", "room": 8.0},
	"cellar": {"at": Vector2(-40, -14), "lift": 1.0, "name": "The cellar hole", "room": 8.0},
	"pines": {"at": Vector2(36, -6), "lift": 0.5, "name": "The pine flats", "flat": 9.0, "room": 7.0},
}
const EDGES := [["trailhead", "fork"], ["fork", "hollow"], ["fork", "ridge"], ["hollow", "creek"], ["ridge", "oak"], ["creek", "oak"], ["fork", "nursery"],
	["creek", "pond"], ["trailhead", "cellar"], ["cellar", "hollow"],
	# no dead ends: the nursery goes on through the pine flats back round to the trailhead, the pond on to the old oak
	["nursery", "pines"], ["pines", "trailhead"], ["pond", "oak"]]
## The pine flats: level ground under white pines, deep in orange needles.
const PINES_R := 11.0                           # the needle bed: the level ground only, not the slopes round it
## From the pine flats a long view east-south-east: trunk behind trunk, thinning layer on layer, on into the land
## beyond (distant_land.gd carries the white pines on for miles).
const PINES_VIEW := Vector2(0.96, 0.28)
## The beaver pond (its middle, how wide), and the old farmhouse's cellar hole.
const POND_AT := Vector2(-46.0, -98.6)
const POND_R := 6.5
const CELLAR_AT := Vector2(-46.0, -17.0)
## Trails that don't lead anywhere yet: a few overgrown metres and a sign. {id: {from, toward: Vector2, name}}
const STUBS := {}
## The creek: a channel through the creek crossing's clearing (it stands on one bank; both its trails cross).
const CREEK_AT := Vector2(-23.8, -60.5)
const CREEK_DIR := Vector2(-0.643, 0.766)
## From the ridge, the way the land falls away (east-northeast, toward the moon).
const VIEW_DIR := Vector2(0.89, -0.456)
## The two forest vistas: from the old oak the land falls away north over a sea of treetops; from the mossy fork you
## look north-north-west through thinning trunks into miles more forest (distant_land.gd carries both on).
const OAK_VIEW := Vector2(-0.148, -0.989)
const FORK_VIEW := Vector2(-0.33, -0.944)
## The way home: behind the trailhead, the garden's creek and the same footbridge you just crossed, and past it the
## garden itself (a picture, tilt-shifted like the land beyond). HOME_DIR matches the "Home to the garden" sign.
const HOME_DIR := Vector2(0.287, 0.958)
const BROOK_AT := Vector2(2.01, 6.71)                    # HOME_DIR * 7: where the creek crosses the way home
## Toward the sun: low in the morning sky, out past the ridge.
const TO_SUN := Vector3(0.55, 0.5, -0.32)
var _noise: FastNoiseLite
var _fine: FastNoiseLite
func _baked_shadow(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
var things: Array = []                # authored woods placements: stable id, node, at, radius
const OVERRIDES_PATH := "res://world/woods_overrides.tres"
# ------------------------------------------------------------------ the ground
func height(x: float, z: float) -> float:
	var v := _noise.get_noise_2d(x, z) * 9.0 + _fine.get_noise_2d(x, z) * 1.4
	for id in NODES:
		var n: Dictionary = NODES[id]
		var d := Vector2(x, z).distance_to(n["at"])
		v += float(n["lift"]) * exp(-d * d / (2.0 * 11.0 * 11.0))
		var level := _base(n["at"]) + float(n["lift"])
		var flat := float(n.get("flat", 2.5))
		v = lerpf(v, level, smoothstep(flat + 4.5, flat, d))   # a flat-ish clearing to stand in
	var ov := Vector2(x, z) - (NODES["oak"]["at"] as Vector2)   # past the old oak: down into the treetops
	var os := ov.dot(OAK_VIEW)
	if os > 5.0:
		var olat := ov.dot(OAK_VIEW.orthogonal())
		v -= 24.0 * smoothstep(5.0, 30.0, os) * exp(-olat * olat / (2.0 * 26.0 * 26.0))
	var fv := Vector2(x, z) - (NODES["fork"]["at"] as Vector2)  # the fork's long view into the woods runs level...
	var fs := fv.dot(FORK_VIEW)
	if fs > 4.0:                                          # ...level: you look into the woods, not over them
		var flat := fv.dot(FORK_VIEW.orthogonal())
		var level := _base(NODES["fork"]["at"]) + float(NODES["fork"]["lift"])
		v = lerpf(v, level + (fs - 4.0) * 0.04, smoothstep(4.0, 14.0, fs) * exp(-flat * flat / (2.0 * 16.0 * 16.0)))
	var rv := Vector2(x, z) - (NODES["ridge"]["at"] as Vector2)
	var s := rv.dot(VIEW_DIR)
	if s > 2.5:                                          # past the rim the land falls away immediately
		var lat := rv.dot(VIEW_DIR.orthogonal())
		var ravine := 25.0 * smoothstep(2.5, 9.0, s) + 8.0 * smoothstep(9.0, 24.0, s)
		v -= ravine * exp(-lat * lat / (2.0 * 18.0 * 18.0))
	var dp := Vector2(x, z).distance_to(POND_AT)                # the pond: level banks round a bowl the water fills
	v = lerpf(v, _base(POND_AT) - 2.0, smoothstep(POND_R + 7.0, POND_R + 1.5, dp))
	v -= 1.5 * smoothstep(POND_R + 0.8, POND_R - 1.5, dp)
	var dc := (Vector2(x, z) - CELLAR_AT).abs()                 # the cellar hole: a square pit, stone-lined
	v -= 1.2 * smoothstep(3.6, 2.8, maxf(dc.x, dc.y))
	var pf: Dictionary = NODES["pines"]                          # the pine flats stay level whatever the land does round them
	var plevel := _base(pf["at"]) + float(pf["lift"])  # (stops short of the nursery: its own ground stays its own)
	v = lerpf(v, plevel, smoothstep(float(pf["flat"]) + 5.0, float(pf["flat"]), Vector2(x, z).distance_to(pf["at"])))
	var pv := Vector2(x, z) - (pf["at"] as Vector2)              # and their long view runs level into the pines
	var ps := pv.dot(PINES_VIEW)
	if ps > 4.0:
		var plat := pv.dot(PINES_VIEW.orthogonal())
		v = lerpf(v, plevel + (ps - 4.0) * 0.03, smoothstep(4.0, 12.0, ps) * exp(-plat * plat / (2.0 * 12.0 * 12.0)))
	var bq := Vector2(x, z) - BROOK_AT                          # the garden's creek behind the trailhead: level banks, a channel
	var bl := absf(bq.dot(HOME_DIR))
	var along := bq.dot(HOME_DIR.orthogonal())                   # (it runs off west; east it ends short of the pines' trail)
	var reach := smoothstep(26.0, 14.0, -along) if along < 0.0 else smoothstep(14.0, 8.0, along)
	v = lerpf(v, _base(Vector2.ZERO), smoothstep(10.0, 3.0, bl) * reach)
	v -= 0.85 * smoothstep(2.3, 0.9, bl) * reach
	var ch := _channel(x, z)
	v -= ch
	if _carve:                                           # the trail bed: the ground meets the trail, never above it or
		var t := _trail_near(Vector2(x, z))              # far below (no hill in your face, nothing floating beside it)
		if t.w < 3.2:                                    # - except in the creek's channel: there you cross on stones
			v = lerpf(v, t.y - 0.04, smoothstep(3.2, 1.1, t.w) * (1.0 - smoothstep(0.05, 0.5, ch)))
	return v


var _carve := false


## The nearest trail point to p: (x, y, z, distance in the ground plane); w = INF when none within ~4 m.
func _trail_near(p: Vector2) -> Vector4:
	var best := Vector4(0, 0, 0, INF)
	var c0 := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var pts = _cells3.get(c0 + Vector2i(dx, dz))
			if pts == null:
				continue
			for q: Vector3 in pts:
				var d := Vector2(q.x, q.z).distance_to(p)
				if d < best.w:
					best = Vector4(q.x, q.y, q.z, d)
	return best


## How deep the creek's channel is here.
func _channel(x: float, z: float) -> float:
	var d := Vector2(x, z) - CREEK_AT
	var lat := absf(_creek_lat(Vector2(x, z)))
	return 1.1 * smoothstep(3.2, 1.0, lat) * smoothstep(80.0, 72.0, absf(d.dot(CREEK_DIR)))   # off the map both ways


## The water's surface here (creek or pond), or -INF on dry land.
func water_at(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var along := (q - CREEK_AT).dot(CREEK_DIR)
	if absf(_creek_lat(q)) < 2.3 and absf(along) < 72.0:
		var mid := _creek_point(along)
		return height(mid.x, mid.y) + 0.72
	if q.distance_to(POND_AT) < POND_R + 0.8:
		return pond_level()
	return -INF


var _pond_y := INF


func pond_level() -> float:
	if _pond_y == INF:
		_pond_y = _base(POND_AT) - 2.0 - 0.3                 # just under the level banks
	return _pond_y


## The creek winds: how far its middle swings to the side at a distance along it.
func _meander(along: float) -> float:
	return sin(along * 0.13) * 2.2 + sin(along * 0.31 + 1.0) * 0.7


## Where the creek's middle is, a distance along it.
func _creek_point(along: float) -> Vector2:
	return CREEK_AT + CREEK_DIR * along + CREEK_DIR.orthogonal() * _meander(along)


## How far to the side of the creek's middle a point is (signed).
func _creek_lat(p: Vector2) -> float:
	var d := p - CREEK_AT
	return d.dot(CREEK_DIR.orthogonal()) - _meander(d.dot(CREEK_DIR))


func _base(p: Vector2) -> float:
	return _noise.get_noise_2d(p.x, p.y) * 9.0


func node_pos(id: String) -> Vector3:
	var p: Vector2 = NODES[id]["at"]
	return Vector3(p.x, height(p.x, p.y), p.y)


func _placement(id: String, node: Node3D, radius := 1.0) -> void:
	if node == null:
		return
	node.set_meta("woods_id", id)
	things.append({"id": id, "kind": "woods", "node": node, "at": Vector2(node.position.x, node.position.z), "radius": radius, "hidden": false})


func _scan_placements(n: Node) -> void:
	for c in n.get_children():
		if c is Node3D and c.has_meta("woods_id"):
			var id := str(c.get_meta("woods_id"))
			var exists := false
			for t in things:
				if t["id"] == id:
					exists = true
					break
			if not exists:
				things.append({"id": id, "kind": "woods", "node": c, "at": Vector2(c.position.x, c.position.z), "radius": 1.5, "hidden": false})
		_scan_placements(c)


func _apply_overrides() -> void:
	_scan_placements(self)
	var o := WorldOverrides.current(OVERRIDES_PATH)
	for t in things:
		if o.things.has(t["id"]):
			WorldOverrides.apply_one(t, o.things[t["id"]])
			if t.get("hidden", false):
				t["node"].visible = false


const CELL := 2.0
var _cells3 := {}                     # the same, with their heights (the camera walks them)


func _heading_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)
