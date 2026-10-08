class_name PlantProfile
extends RefCounted

var id: String
var label: String
var font_path: String
var geometry_path: String
var palette: Array[Color] = []
var primary_shoot_count: int = 7
var amplitude_range := Vector2(60.0, 110.0)
var frequency_range := Vector2(0.7, 1.2)
var leaf_spacing: float = 64.0
var leaf_scale_range := Vector2(30.0, 50.0)
var cluster_probability: float = 0.25
var branch_probability: float = 0.20
var branch_depth: int = 1
var overflow_tendency: float = 0.60
var interior_density: float = 0.60
var flower_probability: float = 0.05
var growth_habit: String = "trailing"


static func load_catalog(path: String) -> Array[PlantProfile]:
	var catalog: Array[PlantProfile] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return catalog
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return catalog
	for raw_profile in parsed.get("profiles", []):
		catalog.append(from_dictionary(raw_profile))
	return catalog


static func from_dictionary(raw_profile: Dictionary) -> PlantProfile:
	var profile := PlantProfile.new()
	profile.id = str(raw_profile.get("id", "plant"))
	profile.label = str(raw_profile.get("label", profile.id.capitalize()))
	profile.font_path = str(raw_profile.get("font", ""))
	profile.geometry_path = str(raw_profile.get("geometry", ""))
	for raw_color in raw_profile.get("palette", []):
		profile.palette.append(Color(str(raw_color)))
	var amplitude = raw_profile.get("amplitude_range", [60.0, 110.0])
	var frequency = raw_profile.get("frequency_range", [0.7, 1.2])
	var scale = raw_profile.get("leaf_scale_range", [30.0, 50.0])
	profile.primary_shoot_count = int(raw_profile.get("primary_shoot_count", 7))
	profile.amplitude_range = Vector2(float(amplitude[0]), float(amplitude[1]))
	profile.frequency_range = Vector2(float(frequency[0]), float(frequency[1]))
	profile.leaf_spacing = float(raw_profile.get("leaf_spacing", 64.0))
	profile.leaf_scale_range = Vector2(float(scale[0]), float(scale[1]))
	profile.cluster_probability = float(raw_profile.get("cluster_probability", 0.25))
	profile.branch_probability = float(raw_profile.get("branch_probability", 0.20))
	profile.branch_depth = int(raw_profile.get("branch_depth", 1))
	profile.overflow_tendency = float(raw_profile.get("overflow_tendency", 0.60))
	profile.interior_density = float(raw_profile.get("interior_density", 0.60))
	profile.flower_probability = float(raw_profile.get("flower_probability", 0.05))
	profile.growth_habit = str(raw_profile.get("growth_habit", "trailing"))
	return profile


func pigment(index: int, alpha: float = 1.0) -> Color:
	if palette.is_empty():
		return Color(0.35, 0.52, 0.24, alpha)
	var color: Color = palette[posmod(index, palette.size())]
	color.a = alpha
	return color
