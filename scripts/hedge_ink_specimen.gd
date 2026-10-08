extends Control

const PROFILE_CATALOG_PATH := "res://assets/plants/plant_profiles.json"
const PAPER := Color("f8f1e4")
const INK := Color("293326")
const RULE := Color(0.16, 0.22, 0.14, 0.30)

var profiles: Array[PlantProfile] = []
var active_profile: PlantProfile
var active_font: Font


func _ready() -> void:
	profiles = PlantProfile.load_catalog(PROFILE_CATALOG_PATH)
	if not profiles.is_empty():
		set_profile(profiles[0])
	queue_redraw()


func set_profile(next_profile: PlantProfile) -> void:
	active_profile = next_profile
	active_font = load(active_profile.font_path) as Font
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	draw_rect(Rect2(0, 0, size.x - 1, size.y - 1), RULE, false, 3.0)
	var title := "HEDGE%s / BOTANICAL VOCABULARY" % (active_profile.label.to_upper() if active_profile != null else "INK")
	draw_string(ThemeDB.fallback_font, Vector2(42, 64), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, INK)
	draw_string(ThemeDB.fallback_font, Vector2(42, 96), "same contract / different species grammar", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(INK, 0.65))

	if active_profile == null or active_font == null:
		return
	var columns := 4
	var cell_width := (size.x - 88.0) / float(columns)
	var start_y := 178.0
	var row_height := 286.0
	for index in range(HedgeGlyph.NAMES.size()):
		var column := index % columns
		var row := index / columns
		var center := Vector2(44.0 + cell_width * (float(column) + 0.5), start_y + row_height * float(row))
		draw_string(active_font, center + Vector2(-42, 44), HedgeGlyph.glyph_for_index(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 94, INK)
		draw_line(center + Vector2(-cell_width * 0.34, 70), center + Vector2(cell_width * 0.34, 70), RULE, 2.0, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(-cell_width * 0.43, 101), HedgeGlyph.name_for_index(index), HORIZONTAL_ALIGNMENT_LEFT, cell_width * 0.86, 15, INK)


func _on_toggle_pressed() -> void:
	visible = true
	queue_redraw()


func _on_close_pressed() -> void:
	visible = false
