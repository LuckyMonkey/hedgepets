class_name WoodsPack
extends RefCounted

## Web-only lazy fetch for the compiled woods resource pack. Desktop/editor builds read res:// directly.
## HTTPRequest writes into the browser's persistent user filesystem, so a second visit does not download it again.

const PACK_PATH := "user://woods.pck"
const PACK_URL := "/hedgepets/woods.pck"
static var _ready := false
static var _loading := false

static func ensure() -> bool:
	if _ready or not OS.has_feature("web"):
		return true
	if ResourceLoader.exists("res://world/woods_compiled.scn"):
		_ready = true
		return true
	if FileAccess.file_exists(PACK_PATH) and ProjectSettings.load_resource_pack(PACK_PATH, false):
		_ready = true
		return true
	if _loading:
		return false
	_loading = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_loading = false
		return false
	var request := HTTPRequest.new()
	tree.root.add_child(request)
	request.download_file = PACK_PATH
	var err := request.request(PACK_URL)
	if err != OK:
		request.queue_free()
		_loading = false
		return false
	var result: Array = await request.request_completed
	var ok := int(result[0]) == HTTPRequest.RESULT_SUCCESS and int(result[1]) == 200
	if ok:
		ok = ProjectSettings.load_resource_pack(PACK_PATH, false)
	request.queue_free()
	_loading = false
	_ready = ok
	return ok
