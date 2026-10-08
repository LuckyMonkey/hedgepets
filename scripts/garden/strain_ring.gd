extends Control

## The ring at your finger while you work something: it fills with strain (yellow to red, shaking near the end), a
## line under it says what it is and how heavy; while hauling, just the words. Eased in and out (Motion).

var _strain := 0.0
var _shown := 0.0
var _text := ""
var _yank := false
var _t := 0.0
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1, 1)
	modulate.a = 0.0
	visible = false
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0.2, 0.16, 0.1))
	_label.add_theme_constant_override("outline_size", 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-260, 78)
	_label.size = Vector2(520, 40)
	add_child(_label)


func show_ring(at: Vector2, strain: float, text: String, yank: bool) -> void:
	position = at
	_strain = strain
	_text = text
	_yank = yank
	_label.text = text
	if not visible or modulate.a < 0.99 and not Motion.busy(self, "fade"):
		Motion.fade(self, 1.0, Motion.FAST)


func hide_ring() -> void:
	if visible:
		Motion.fade(self, 0.0, Motion.FAST)


func _process(delta: float) -> void:
	_t += delta
	_shown = Motion.approach(_shown, maxf(_strain, 0.0), 18.0, delta)
	queue_redraw()


func _draw() -> void:
	if _strain < 0.0:
		return
	var shake := Vector2(sin(_t * 60.0), cos(_t * 53.0)) * 4.0 * _shown * _shown
	var r := 56.0 + (6.0 if _yank else 0.0)
	draw_arc(shake, r, 0, TAU, 48, Color(0, 0, 0, 0.25), 12.0, true)
	var col := Color("f2c84a").lerp(Color("d8452e"), _shown)
	draw_arc(shake, r, -PI * 0.5, -PI * 0.5 + TAU * _shown, 48, col, 12.0, true)
