class_name FruitUnlocks
extends RefCounted

## HedgePets visitors you unlock with Fruit on fridge.run (go.fridge.run/fruit/stand). A species with "dlc" in
## res://pets/species.json is locked until the player owns that Fruitstand add-on: it never notices the garden, and the
## journal points at the Fruitstand. The game only asks go which add-ons this player owns (GET /api/fruit/owned?app=
## hedgepets, same origin, the player's own sign-in); buying happens on fridge.run, never in the game. Guests, offline
## play and desktop builds: nothing unlocked. In the editor everything is, so the pets can be worked on.

const URL := "/api/fruit/owned?app=hedgepets"
const ASK_EVERY := 60.0          # seconds: a purchase on fridge.run shows up within a minute
static var _ids := PackedStringArray()
static var _asked_at := -1000.0
static var _read_at := -1000.0


static func ask() -> void:
	if not OS.has_feature("web"):
		return
	_asked_at = Time.get_ticks_msec() / 1000.0
	JavaScriptBridge.eval("(function(){fetch(%s,{credentials:'same-origin'}).then(function(r){return r.ok?r.json():{ids:[]}}).then(function(j){window.__hpFruit=(j.ids||[]).join(',')},function(){})})()" % JSON.stringify(URL))


static func unlocked(p: CharacterArtProfile) -> bool:
	if p.dlc == "" or OS.has_feature("editor"):
		return true
	if not OS.has_feature("web"):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - _asked_at > ASK_EVERY:
		ask()
	if now - _read_at > 2.0:
		_read_at = now
		_ids = str(JavaScriptBridge.eval("window.__hpFruit||''")).split(",", false)
	return _ids.has(p.dlc)
