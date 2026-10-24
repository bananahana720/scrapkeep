extends SceneTree

const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const T := preload("res://tests/support/t.gd")

# A park cue cell due as it is booked (a riser's first, booked as its event is announced) renders on a worker
# and starts late, from the frame it would have reached, instead of rendering on the main thread in the beat
# that plays it (music_engine.gd _warm_park, _late_cell_waits). Stage 6 announces six at once (PR #372).

const LEAD := Harmony.BAR * 5
const LATE := 100

var _t := T.new("park_cue_late_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cold := _engine(false)
	cold.park_cue("riser_ancient", LEAD, -1, {"ancient": "reactor"})
	_t.check("with warming off a cell due now is not marked late", not cold._actions[0].get("late", false))

	var e := _engine(true)
	e.park_cue("riser_ancient", LEAD, -1, {"ancient": "reactor"})
	var first: Dictionary = e._actions[0]
	var later: Dictionary = e._actions[1]
	_t.check("the cell due now is marked late", first.get("late", false) and first.at == 0)
	_t.check("a later cell is not", not later.get("late", false))
	var signature := MusicEngine._park_signature(first, e.key, e.step_len)
	var task: int = MusicEngine._park_tasks.get(signature, -1)
	_t.check("the cell due now renders on a worker", task >= 0)
	_t.check("it waits while its worker runs", e._late_cell_waits(first) == (task >= 0 and not WorkerThreadPool.is_task_completed(task)))
	for frame in 600:
		if task < 0 or WorkerThreadPool.is_task_completed(task):
			break
		await process_frame
	_t.check("a late cell with its worker done does not wait", not e._late_cell_waits(first))
	_t.check("the worker's buffer is ready", MusicEngine._park_warm.has(signature))
	e.clock = LATE
	e._run_due()
	_t.check("the beat took the worker's buffer, not a render of its own", not MusicEngine._park_warm.has(signature))
	_t.eq("it starts once, at the first beat after its worker", e._voices.size(), 1)
	if not e._voices.is_empty():
		var voice = e._voices[0]
		_t.eq("it plays from the frame it would have reached", voice.pos, LATE)
		var main := MusicEngine._render_park(first.row, first.cell, first.length, first.progress, 0, e.key, e.step_len, e.theme)
		_t.check("its buffer is the one a main-thread render makes", voice.buf == main, "%d / %d" % [voice.buf.size(), main.size()])
	_t.check("the next cell still waits for its own beat", e._actions.has(later))

	var past := _engine(true)
	past.park_cue("riser_fleet", LEAD, -1, {})
	var cell: Dictionary = past._actions[0]
	past.clock = int(cell.length)
	_t.check("a late cell past its length no longer waits for its worker", not past._late_cell_waits(cell))
	MusicEngine.settle_stingers()
	quit(_t.verdict())


func _engine(warm: bool) -> MusicEngine:
	var e := MusicEngine.new()
	e.key = 3
	e.band_muted = true
	e.warm_stingers = warm
	return e
