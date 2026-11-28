extends RefCounted

const SimClock := preload("res://src/core/sim_clock.gd")

const STRIKE_STOP_FACTS := ["enemy_struck", "boss_weak_point_hit", "multi_kill", "harpoon_bit", "posture_changed",
	"posture_break", "boss_defeated", "piece_shattered", "test", "comfort"]
const STOP_FLOOR_MS := 4.0
const STOP_TRIM_FLOOR_MS := 8.0
const STOP_GAP_MS := 90
const STOP_WINDOW_MS := 300
const STOP_WINDOW_BUDGET_MS := 60.0
const STOP_BUDGET_MS := 100.0
const SPINE_CAP_MS := 60.0
const LOG_CAP := 2048

var entries: Array = []
var _stops: Array = []


func ask(seconds: float, fact: String, scale: float, in_play: bool) -> float:
	var now := SimClock.msec()
	if not STRIKE_STOP_FACTS.has(fact):
		_log([seconds, 0.0, fact, now])
		return 0.0
	var wanted := minf(seconds * 1000.0, SPINE_CAP_MS) * scale
	_stops = _stops.filter(func(stop: Array): return now - int(stop[0]) < 1000)
	var spent := 0.0
	var recent := 0.0
	for stop in _stops:
		spent += float(stop[1])
		if now - int(stop[0]) < STOP_WINDOW_MS:
			recent += float(stop[1])
	var sent := minf(wanted, minf(STOP_BUDGET_MS - spent, STOP_WINDOW_BUDGET_MS - recent))
	var spaced := _stops.is_empty() or now - int(_stops.back()[0]) - float(_stops.back()[1]) >= STOP_GAP_MS
	if not in_play or not spaced or wanted < STOP_FLOOR_MS or sent < minf(wanted, STOP_TRIM_FLOOR_MS):
		_log([seconds, 0.0, fact, now])
		return 0.0
	_stops.append([now, sent])
	_log([seconds, sent / 1000.0, fact, now])
	return sent / 1000.0


func reset() -> void:
	_stops.clear()


func _log(entry: Array) -> void:
	if entries.size() >= LOG_CAP:
		entries.pop_front()
	entries.append(entry)
