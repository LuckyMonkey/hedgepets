extends CanvasLayer

## The card over the garden while it's built step by step (garden.gd BUILD_STEPS): what's happening in a few words, a
## bar that moves, a leaf drifting. Same colours as the boot splash (assets/ui/splash.png), so the browser's loading
## bar, the engine starting and this card read as one screen. Fades away once the garden is ready.

const PAPER := Color("efe6d2")
const INK := Color(0.25, 0.2, 0.14)
const BAR_W := 640.0

var _root: Control
var _line: Label
var _fill: ColorRect
var _text := ""
var _goal := 0.0
var _shown := 0.0
var _t := 0.0
var note := "Waking the garden. The first visit takes a little while."


func _ready() -> void:
	layer = 120
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP           # nothing reaches the garden underneath while it's built
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var art := TextureRect.new()                          # Gerald and the title, exactly where the splash had them
	art.texture = load("res://assets/ui/splash.png")
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_root.add_child(art)
	_line = _label("", 38)
	_line.position = Vector2(0, 1010)
	_line.modulate.a = 0.8
	var track := ColorRect.new()
	track.color = INK * Color(1, 1, 1, 0.14)
	track.position = Vector2((1080 - BAR_W) * 0.5, 1110)      # where the browser's own bar sat (58%)
	track.size = Vector2(BAR_W, 14)
	_root.add_child(track)
	_fill = ColorRect.new()
	_fill.color = Color("8aa05a")
	_fill.position = track.position
	_fill.size = Vector2(0, 14)
	_root.add_child(_fill)
	var small := _label(note, 28)
	small.position = Vector2(0, 1160)
	small.modulate.a = 0.55


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(1080, size * 1.6)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	_root.add_child(l)
	return l


## A new step: its words and how far along the whole build is (0..1).
func stage(text: String, progress: float) -> void:
	_text = text
	_goal = clampf(progress, 0.0, 1.0)


func finish() -> void:
	_goal = 1.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	_shown = lerpf(_shown, _goal, clampf(delta * 6.0, 0.0, 1.0))
	_fill.size.x = BAR_W * _shown
	_line.text = _text + ".".repeat(1 + int(_t * 2.5) % 3) if _text != "" else ""
