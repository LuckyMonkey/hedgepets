extends MultiMeshInstance3D

## The leaves on the ground: the litter the garden starts with, plus every leaf that drifts down from the oaks while
## you watch - they land and stay. With ✋ you can rake them: press on a drift and drag, the leaves under your hand
## are swept along and heap up where you gather them. Nothing counts them and nothing asks you to; it's just nice.
## One MultiMesh, so a few thousand leaves are one draw (no shadow: they lie flat).

const CAP := 7000                       # leaves at most; past this, new ones replace the oldest that fell
const RAKE_R := 0.45                    # how wide the rake's sweep is, metres
const CELL := 0.2                       # heaping: leaves in one cell stack up
const LAND_EVERY := Vector2(1.5, 3.5)   # seconds between leaves landing
const DRIFT_COUNT := 8                  # leaves within RAKE_R that make a spot worth raking (else ✋ turns the camera)

var garden: Node3D
var n := 0
var _start := 0                         # leaves made at the build (never replaced)
var _next := 0                          # next slot to reuse once CAP is reached
var _pos := PackedVector3Array()
var _basis: Array[Basis] = []
var _grid := {}                         # Vector2i -> leaves in that cell
var _sources: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func setup(g: Node3D, material: Material, quad: Mesh, items: Array, sources: Array) -> void:
	garden = g
	name = "LeafLitter"
	_sources = sources
	_rng.seed = 1031
	_t = _rng.randf_range(LAND_EVERY.x, LAND_EVERY.y)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = CAP
	multimesh = mm
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pos.resize(CAP)
	_basis.resize(CAP)
	for it: Array in items:
		var xf: Transform3D = it[0]
		_put(n, xf.origin, xf.basis, it[1])
		n += 1
	_start = n
	_next = n
	mm.visible_instance_count = n


func _put(i: int, p: Vector3, b: Basis, c = null) -> void:
	_pos[i] = p
	_basis[i] = b
	multimesh.set_instance_transform(i, Transform3D(b, p))
	if c != null:
		multimesh.set_instance_color(i, c)
	var k := _cell(p)
	_grid[k] = int(_grid.get(k, 0)) + 1


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func _unput(i: int) -> void:
	var k := _cell(_pos[i])
	_grid[k] = maxi(0, int(_grid.get(k, 1)) - 1)


## A leaf has come down from one of the trees and settles on the ground.
func _land() -> void:
	if _sources.is_empty():
		return
	var c: Vector3 = _sources[_rng.randi() % _sources.size()]
	var rr := sqrt(_rng.randf()) * 5.5
	var a := _rng.randf() * TAU
	var p := Vector3(c.x + cos(a) * rr, 0, c.z + sin(a) * rr)
	if garden._in_creek(Vector2(p.x, p.z)) or garden._in_puddle(Vector2(p.x, p.z)):
		return
	var s := _rng.randf_range(0.22, 0.4)
	var b := Basis.from_euler(Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf() * TAU, _rng.randf_range(-0.25, 0.25))).scaled(Vector3(s, s, s))
	var colors := [Color("c9923c"), Color("b8702e"), Color("9a3428"), Color("c0482e"), Color("d8a848")]
	var i := n
	if n < CAP:
		n += 1
		multimesh.visible_instance_count = n
	else:
		i = _next
		_unput(i)
		_next = _start + (_next - _start + 1) % (CAP - _start)
	p.y = 0.015 + _heap(p)
	_put(i, p, b, (colors[_rng.randi() % colors.size()] as Color).darkened(_rng.randf() * 0.12))


func _heap(p: Vector3) -> float:
	return minf(float(_grid.get(_cell(p), 0)) * 0.012, 0.32)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(LAND_EVERY.x, LAND_EVERY.y)
		_land()


## Enough leaves under this ground point to rake (otherwise a ✋ drag there turns the camera as usual).
func rakeable(p: Vector3) -> bool:
	var count := 0
	var r2 := RAKE_R * RAKE_R
	for i in range(n):
		var q := _pos[i]
		if (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z) < r2:
			count += 1
			if count >= DRIFT_COUNT:
				return true
	return false


## Sweep from a to b (ground points): leaves near the path move with it, most at the middle of the sweep, and pile
## up where they end (they stack in their cell, a little higher for each leaf already there).
func rake(a: Vector3, b: Vector3) -> int:
	var d := Vector3(b.x - a.x, 0, b.z - a.z).limit_length(0.6)
	if d.length() < 0.005:
		return 0
	var moved := 0
	var seg := Vector2(d.x, d.z)
	var a2 := Vector2(a.x, a.z)
	var len2 := seg.length_squared()
	for i in range(n):
		var q := _pos[i]
		var q2 := Vector2(q.x, q.z)
		var t := clampf((q2 - a2).dot(seg) / len2, 0.0, 1.0)
		var dist := q2.distance_to(a2 + seg * t)
		if dist > RAKE_R:
			continue
		var push := (1.0 - dist / RAKE_R) * (1.0 - t * 0.6)
		var to := q + d * push
		if garden._in_creek(Vector2(to.x, to.z)):
			continue
		_unput(i)
		to.y = 0.015
		to.y += _heap(to)
		var spin := Basis(Vector3.UP, d.length() * push * (2.0 if i % 2 == 0 else -2.0))
		_put(i, to, spin * _basis[i])
		moved += 1
	return moved
