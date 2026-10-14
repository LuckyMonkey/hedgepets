@tool
extends VBoxContainer

## The HedgePets dock. The world is built by code when the game runs (it isn't in the scene tree), so this is how you
## get around it from the editor:
##   Play     - the garden, the woods at any place (click it on the map), the pet viewer, the world editor, the
##              filmmaker; "Debug" adds the 🪙+ coin button and F9.
##   Woods map- the trail graph from woods.gd (places and trails), top-down; click a place to play from there.
##   Checks   - run any tools/*_check.gd headless and read its output here.
const WOODS := "res://scripts/garden/woods.gd"

var _debug: CheckBox
var _out: TextEdit
var _map: Control
var _check: OptionButton
var _proc := {}                       # a running check: {pid, stdio}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_label("Play")
	var row := HBoxContainer.new()
	add_child(row)
	_button(row, "Garden", func() -> void: _play("res://garden.tscn", []))
	_button(row, "Pet viewer", func() -> void: _play("res://main3d.tscn", []))
	var row2 := HBoxContainer.new()
	add_child(row2)
	_button(row2, "World editor", func() -> void: _play("res://world_editor.tscn", []))
	_button(row2, "Filmmaker", func() -> void: _play("res://filmmaker.tscn", ["--film=res://films/demo/project.tres"]))
	_debug = CheckBox.new()
	_debug.text = "Debug (coins: 🪙+ / F9)"
	_debug.button_pressed = true
	add_child(_debug)
	_label("Woods map (click a place to play from there)")
	_map = preload("res://addons/hedgepets_dev/woods_map.gd").new()
	_map.custom_minimum_size = Vector2(260, 300)
	_map.place_clicked.connect(func(id: String) -> void: _play("res://garden.tscn", ["--start=woods:" + id]))
	add_child(_map)
	_label("Checks")
	var row3 := HBoxContainer.new()
	add_child(row3)
	_check = OptionButton.new()
	_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dir := DirAccess.open("res://tools")
	if dir:
		for f in dir.get_files():
			if f.ends_with("_check.gd"):
				_check.add_item(f.trim_suffix(".gd"))
	row3.add_child(_check)
	_button(row3, "Run", _run_check)
	_out = TextEdit.new()
	_out.custom_minimum_size = Vector2(0, 160)
	_out.editable = false
	add_child(_out)


func _label(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	add_child(l)


func _button(parent: Node, t: String, f: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(f)
	parent.add_child(b)


## A game window of its own (so the editor stays usable), with this dock's options.
func _play(scene: String, user_args: Array) -> void:
	var args := ["--path", ProjectSettings.globalize_path("res://"), scene, "--"]
	args.append_array(user_args)
	if _debug.button_pressed:
		args.append("--debug")
	OS.create_process(OS.get_executable_path(), args)


func _run_check() -> void:
	if _check.item_count == 0 or not _proc.is_empty():
		return
	var name := _check.get_item_text(_check.selected)
	_out.text = "running %s ...\n" % name
	OS.set_environment("HEDGEPETS_FRESH", "1")
	_proc = OS.execute_with_pipe(OS.get_executable_path(), ["--headless", "--audio-driver", "Dummy", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://tools/%s.gd" % name, "--fixed-fps", "60"], false)


func _process(_delta: float) -> void:
	if _proc.is_empty():
		return
	var io: FileAccess = _proc["stdio"]
	var got := io.get_as_text()
	if got != "":
		for line in got.split("\n"):
			if line.strip_edges() != "" and not line.contains("RID allocations") and not line.contains("resources still"):
				_out.text += line + "\n"
		_out.scroll_vertical = _out.get_line_count()
	if not OS.is_process_running(_proc["pid"]):
		_out.text += "(done)\n"
		_proc = {}
