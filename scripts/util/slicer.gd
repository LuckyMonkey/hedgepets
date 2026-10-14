class_name Slicer
extends RefCounted

## Time-slicing for long builds on the main thread (the web has no threads): `await Slicer.tick(self)` in a builder's
## loop gives the frame back once `budget_us` of work has gone by - but only while `active`. Inactive (the default:
## checks, bakes, compiling, the editor) every builder runs straight through exactly as before.
static var active := false
static var budget_us := 5000
static var _since := 0


static func tick(n: Node) -> void:
	if not active:
		return
	if Time.get_ticks_usec() - _since < budget_us:
		return
	await n.get_tree().process_frame
	_since = Time.get_ticks_usec()
