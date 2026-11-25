extends RefCounted

static var enabled := false
static var _stack: Array = []
static var _totals := {}
static var _samples := {}
static var _tick_start := 0
static var _tick_count := 0
static var _physics_end := 0
static var _pending := false
static var _monitors := {}

class Scope:
	extends RefCounted
	var recorder
	var label: String
	var started: int
	var frame := {"children": 0}

	func _init(id: String, profile) -> void:
		recorder = profile
		label = id
		started = Time.get_ticks_usec()
		recorder._stack.append(frame)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			var elapsed := Time.get_ticks_usec() - started
			recorder._stack.pop_back()
			if not recorder._stack.is_empty():
				recorder._stack[-1].children += elapsed
			recorder.add(label, elapsed - int(frame.children))

class EndMarker:
	extends Node
	var recorder
	func _init(profile) -> void:
		recorder = profile
		process_physics_priority = 2147483647
	func _physics_process(_delta: float) -> void:
		recorder._physics_end = Time.get_ticks_usec()
		recorder.add("physics_callbacks_wall", recorder._physics_end - recorder._tick_start)
		recorder._pending = true


static func scope(label: String):
	return Scope.new(label, load("res://tools/bot_profile.gd")) if enabled else null


static func add(label: String, usec: int) -> void:
	_totals[label] = int(_totals.get(label, 0)) + usec


static func begin_tick() -> void:
	var now := Time.get_ticks_usec()
	if _pending:
		add("native_physics_interval", now - _physics_end)
		_pending = false
	if _tick_start > 0:
		add("tick_wall", now - _tick_start)
		_flush()
	_tick_start = now


static func idle_begin() -> void:
	if _pending:
		add("native_physics_interval", Time.get_ticks_usec() - _physics_end)
		_pending = false


static func _flush() -> void:
	_tick_count += 1
	for label in _totals:
		if not _samples.has(label):
			_samples[label] = {"ticks": [], "usec": []}
		_samples[label].ticks.append(_tick_count)
		_samples[label].usec.append(_totals[label])
	_totals.clear()
	var ids := {"TIME_PROCESS": Performance.TIME_PROCESS, "TIME_PHYSICS_PROCESS": Performance.TIME_PHYSICS_PROCESS,
		"TIME_NAVIGATION_PROCESS": Performance.TIME_NAVIGATION_PROCESS, "PHYSICS_3D_ACTIVE_OBJECTS": Performance.PHYSICS_3D_ACTIVE_OBJECTS,
		"PHYSICS_3D_COLLISION_PAIRS": Performance.PHYSICS_3D_COLLISION_PAIRS, "RENDER_TOTAL_DRAW_CALLS_IN_FRAME": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME}
	for label in ids:
		var value: float = Performance.get_monitor(ids[label])
		if not _monitors.has(label):
			_monitors[label] = []
		_monitors[label].append(value)


static func finish(path: String) -> void:
	if not _totals.is_empty():
		_flush()
	var rows := {}
	for label in _samples:
		var values: Array = _samples[label].usec.duplicate()
		values.resize(_tick_count)
		for i in values.size():
			if values[i] == null:
				values[i] = 0
		values.sort()
		var total := 0.0
		for value in values:
			total += value
		rows[label] = {"mean_ms": total / maxf(1, _tick_count) / 1000.0,
			"p95_ms": float(values[maxi(0, int(ceil(values.size() * 0.95)) - 1)]) / 1000.0,
			"total_s": total / 1000000.0}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ticks": _tick_count, "systems": rows, "samples": _samples,
		"performance_monitors": _monitors}, "\t"))
