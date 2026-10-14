@tool
extends EditorPlugin

## Adds the HedgePets dock (dock.gd) to the editor's right side.
var dock: Control


func _enter_tree() -> void:
	dock = preload("res://addons/hedgepets_dev/dock.gd").new()
	dock.name = "HedgePets"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
