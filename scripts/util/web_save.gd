class_name WebSave
extends RefCounted

## The save, kept in the browser's localStorage as well (web build only). Godot's own user:// on the web is an
## IndexedDB copy that is written back a moment later, so closing the tab right after a change could lose it;
## localStorage is written at once. Loading takes whichever copy is newer ("last_visit"). Elsewhere: no-ops.

const PREFIX := "hedgepets:"


static func available() -> bool:
	return OS.has_feature("web")


static func put(path: String, text: String) -> void:
	if not available():
		return
	var ls = JavaScriptBridge.get_interface("localStorage")
	if ls != null:
		ls.setItem(PREFIX + path, text)


static func read(path: String) -> String:
	if not available():
		return ""
	var ls = JavaScriptBridge.get_interface("localStorage")
	if ls == null:
		return ""
	var v = ls.getItem(PREFIX + path)
	return v if v is String else ""


## The newer of the file and the browser copy (by last_visit), as text; "" if neither.
static func newest(path: String) -> String:
	var file := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var web := read(path)
	if web == "" or file == "":
		return web if web != "" else file
	var a = JSON.parse_string(file)
	var b = JSON.parse_string(web)
	var ta := float(a.get("last_visit", 0)) if a is Dictionary else -1.0
	var tb := float(b.get("last_visit", 0)) if b is Dictionary else -1.0
	return web if tb >= ta else file
