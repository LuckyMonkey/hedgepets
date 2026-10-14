class_name FilmProject
extends Resource

## A film: shots played in order (each cut is a shot boundary), with everything a render needs to be reproducible -
## the frame rate, the output size, the world seed and the hour of the sun. Shots are their own .tres files beside
## the project, so they can be edited, reordered and reused. See docs/FILMMAKER.md.

@export var title := "film"
@export var fps := 30
@export var size := Vector2i(540, 960)
@export var seed := 20261014
@export var hour := 16.5
@export var shots: Array[FilmShot] = []


func duration() -> float:
	var d := 0.0
	for s in shots:
		d += s.duration
	return d


func frame_count() -> int:
	return int(round(duration() * fps))


## [shot index, local time] at film time t.
func shot_at(t: float) -> Array:
	var start := 0.0
	for i in shots.size():
		if t < start + shots[i].duration or i == shots.size() - 1:
			return [i, clampf(t - start, 0.0, shots[i].duration)]
		start += shots[i].duration
	return [-1, 0.0]


func shot_start(i: int) -> float:
	var start := 0.0
	for j in range(i):
		start += shots[j].duration
	return start


## Save the project and each shot as its own file (dir/project.tres, dir/shot_001.tres, ...).
func save_to(dir: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for i in shots.size():
		var p := dir.path_join("shot_%03d.tres" % (i + 1))
		var err := ResourceSaver.save(shots[i], p)
		if err != OK:
			return err
		shots[i].take_over_path(p)
	return ResourceSaver.save(self, dir.path_join("project.tres"))
