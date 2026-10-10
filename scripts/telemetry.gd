class_name Telemetry
extends RefCounted

## Play events, so the gardener can see what people do and where they get stuck (go.fridge.run/hedgepets/telemetry/
## report). Web build only, and never in checks or captures (HEDGEPETS_FRESH). Events queue here and go in small
## batches with navigator.sendBeacon (same origin: the play pass rides along), every 20 s and whenever the page is
## left. pid is a random id the browser keeps; sid one per visit. Nothing else identifies anyone.
##   Telemetry.event("dig")   Telemetry.event("sow", {"species": "clover"})

const VERSION := "2026.10.10"
const URL := "/hedgepets/telemetry"

static var on := false
static var _buf: Array = []
static var _t0 := 0
static var _pid := ""
static var _sid := ""


static func start() -> void:
	on = OS.has_feature("web") and OS.get_environment("HEDGEPETS_FRESH") == ""
	if not on:
		return
	_t0 = Time.get_ticks_msec()
	var pid = JavaScriptBridge.eval("(function(){try{var v=localStorage.getItem('hp_pid');if(!v||!/^[a-z0-9]{8,32}$/.test(v)){v=(Math.random().toString(36).slice(2)+Math.random().toString(36).slice(2)).slice(0,14);localStorage.setItem('hp_pid',v)}return v}catch(e){return ''}})()")
	_pid = str(pid) if pid != null and str(pid) != "" else _rand_id()
	_sid = _rand_id()


static func _rand_id() -> String:
	var s := ""
	for k in range(14):
		s += "abcdefghijklmnopqrstuvwxyz0123456789"[randi() % 36]
	return s


static func event(name: String, data: Dictionary = {}) -> void:
	if not on:
		return
	_buf.append([Time.get_ticks_msec() - _t0, name, data])
	if _buf.size() >= 120:
		flush()


static func flush() -> void:
	if not on or _buf.is_empty():
		return
	var body := JSON.stringify({"pid": _pid, "sid": _sid, "v": VERSION, "ev": _buf})
	_buf = []
	JavaScriptBridge.eval("try{navigator.sendBeacon(%s, new Blob([%s], {type: 'text/plain'}))}catch(e){}" % [JSON.stringify(URL), JSON.stringify(body)])
