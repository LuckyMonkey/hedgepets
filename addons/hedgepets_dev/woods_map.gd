@tool
extends Control

## The woods' trail graph (woods.gd NODES / EDGES), top-down: places as dots, trails as lines, the way home to the
## garden. Click a place to start the game there.
signal place_clicked(id: String)

var _nodes := {}
var _edges: Array = []
var _hover := ""


func _ready() -> void:
	var w = load("res://scripts/garden/woods.gd")
	_nodes = w.NODES
	_edges = w.EDGES
	mouse_filter = Control.MOUSE_FILTER_STOP


func _to_screen(p: Vector2) -> Vector2:
	var lo := Vector2(-55, -105)                     # the woods' extent (x, z), north up
	var hi := Vector2(50, 12)
	var t := (p - lo) / (hi - lo)
	var pad := 14.0
	return Vector2(pad + t.x * (size.x - pad * 2), pad + t.y * (size.y - pad * 2))


func _nearest(at: Vector2) -> String:
	var best := ""
	var bd := 14.0
	for id in _nodes:
		var d := _to_screen(_nodes[id]["at"]).distance_to(at)
		if d < bd:
			bd = d
			best = id
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _nearest(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _nearest(event.position)
		if id != "":
			place_clicked.emit(id)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.16, 0.13))
	var font := get_theme_default_font()
	draw_line(_to_screen(Vector2.ZERO), _to_screen(Vector2(0.287, 0.958) * 11.0), Color(0.6, 0.5, 0.3), 2.0)   # home
	for e: Array in _edges:
		draw_line(_to_screen(_nodes[e[0]]["at"]), _to_screen(_nodes[e[1]]["at"]), Color(0.75, 0.62, 0.42), 2.0)
	for id in _nodes:
		var p := _to_screen(_nodes[id]["at"])
		draw_circle(p, 6.0 if id != _hover else 8.0, Color(1.0, 0.86, 0.5) if id == _hover else Color(0.55, 0.75, 0.5))
		draw_string(font, p + Vector2(8, 4), str(_nodes[id]["name"]).trim_prefix("The "), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.9, 0.85))
	draw_string(font, _to_screen(Vector2(0.287, 0.958) * 11.0) + Vector2(4, 12), "home", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.7, 0.5))
