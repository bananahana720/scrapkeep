extends RefCounted


const PAR := 9.0
const MARK_RADIUS := 5.5
const GIVE_UP := 40.0
const MIN_SPEED := 4.0

var marks: Array[Vector2] = []
var running := false
var time := 0.0
var best := INF
var laps := 0
var _seen := {}
var _left_start := false


func _init(mark_points: Array) -> void:
	for p in mark_points:
		marks.append(p)


func reset() -> void:
	running = false
	time = 0.0
	_seen = {}
	_left_start = false


func step(delta: float, local: Vector2, speed: float) -> Array:
	var facts := []
	var at_start := local.distance_to(marks[0]) <= MARK_RADIUS
	if not running:
		if at_start and speed >= MIN_SPEED:
			running = true
			time = 0.0
			_seen = {0: true}
			_left_start = false
			facts.append({"kind": "lap_started"})
		return facts
	time += delta
	if time > GIVE_UP:
		reset()
		return facts
	if not at_start:
		_left_start = true
	for i in range(1, marks.size()):
		if not _seen.has(i) and local.distance_to(marks[i]) <= MARK_RADIUS:
			_seen[i] = true
			facts.append({"kind": "lap_checkpoint", "index": i})
	if at_start and _left_start and _seen.size() == marks.size():
		laps += 1
		var seconds := time
		best = minf(best, seconds)
		facts.append({"kind": "lap_finished", "seconds": seconds, "best": best, "under_par": seconds <= PAR})
		running = false
		_left_start = false
	return facts
