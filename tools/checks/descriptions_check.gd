extends SceneTree

## Quick, deterministic contract for text helpers moved out of GardenGame.
## Run: HEDGEPETS_FRESH=1 godot --headless --audio-driver Dummy --path . --script tools/checks/descriptions_check.gd
const Descriptions = preload("res://scripts/garden/garden_descriptions.gd")


func _init() -> void:
	var errors: Array[String] = []
	var volunteer := {"species": "clover", "stage": 0, "genes": "", "origin": "volunteer"}
	var sprout := {"species": "ivy", "stage": 1, "genes": "", "origin": "garden"}
	if Descriptions.plant_line(volunteer) != "Something's just come up here on its own.":
		errors.append("volunteer wording changed")
	if not Descriptions.plant_line(sprout).contains("sprout"):
		errors.append("sprout wording changed")
	if Descriptions.thing_name("grill") != "rusty grill":
		errors.append("known thing name changed")
	if Descriptions.thing_name("brand_new_kind") != "brand_new_kind":
		errors.append("unknown thing name fallback changed")
	if not Descriptions.thing_line({"kind": "sprinkler", "fixed": false}).contains("broken"):
		errors.append("broken sprinkler wording changed")
	if not Descriptions.thing_line({"kind": "sprinkler", "fixed": true}).contains("Every minute"):
		errors.append("fixed sprinkler wording changed")
	if Descriptions.thing_line({"kind": "unrecognized"}) != "Something in the grass.":
		errors.append("unknown thing description fallback changed")
	if errors.is_empty():
		print("PASS: garden descriptions")
		quit(0)
	else:
		for error in errors:
			push_error("FAIL: " + error)
		quit(1)
