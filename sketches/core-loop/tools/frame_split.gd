extends RefCounted


var _phys_start := 0
var _phys_us := 0
var _tick_max_us := 0
var _proc_start := 0
var _proc_us := 0
var _pre_draw := 0
var _post_draw := 0
var _frame_start := 0
var _proc_end := 0
var _pre_proc_us := 0
var _post_proc_us := 0
var _bot_us := 0
var _record_events := false
var _events: Array = []


class PhysHead:
	extends Node
	var split

	func _init() -> void:
		process_physics_priority = -2147483648

	func _physics_process(_delta: float) -> void:
		split._phys_start = Time.get_ticks_usec()
		split._event("phys_head", split._phys_start)


class PhysTail:
	extends Node
	var split

	func _init() -> void:
		process_physics_priority = 2147483647

	func _physics_process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var span: int = now - split._phys_start
		split._event("phys_tail", now)
		split._phys_us += span
		split._tick_max_us = maxi(split._tick_max_us, span)
		if split._record_events:
			split._mark.call_deferred("phys_deferred")
			var sentinel := Sentinel.new()
			sentinel.split = split
			sentinel.queue_free()


class Sentinel:
	extends Node
	var split

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			split._mark("phys_deleted")


class ProcHead:
	extends Node
	var split

	func _init() -> void:
		process_priority = -2147483648

	func _process(_delta: float) -> void:
		split._proc_start = Time.get_ticks_usec()
		split._pre_proc_us += split._proc_start - split._frame_start
		split._event("proc_head", split._proc_start)


class ProcTail:
	extends Node
	var split

	func _init() -> void:
		process_priority = 2147483647

	func _process(_delta: float) -> void:
		split._proc_end = Time.get_ticks_usec()
		split._event("proc_tail", split._proc_end)
		split._proc_us += split._proc_end - split._proc_start


func watch(tree: SceneTree, record_events := false) -> void:
	_record_events = record_events
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	tree.process_frame.connect(_on_process_frame)
	tree.physics_frame.connect(func(): _event("physics_frame", Time.get_ticks_usec()))
	for node: Node in [PhysHead.new(), PhysTail.new(), ProcHead.new(), ProcTail.new()]:
		node.split = self
		tree.root.add_child(node)


func add_bot(us: int) -> void:
	_bot_us += us


func take(wall_ms: float) -> Dictionary:
	var row := {"t_us": Time.get_ticks_usec(), "phys_ms": _phys_us / 1000.0, "tick_max_ms": _tick_max_us / 1000.0, "proc_ms": _proc_us / 1000.0,
		"pre_proc_ms": _pre_proc_us / 1000.0, "post_proc_ms": _post_proc_us / 1000.0, "bot_ms": _bot_us / 1000.0,
		"net_ms": wall_ms - _bot_us / 1000.0}
	if _record_events and wall_ms > 40.0:
		row["events"] = _events.duplicate()
	_events.clear()
	_phys_us = 0
	_tick_max_us = 0
	_proc_us = 0
	_pre_proc_us = 0
	_post_proc_us = 0
	_bot_us = 0
	return row


func _event(name: String, at: int) -> void:
	if not _record_events:
		return
	var f := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
	var cpu_us := -1 if f == null else int(f.get_line().split(" ")[0]) / 1000
	_events.append("%s %d %d" % [name, at, cpu_us])


func _mark(name: String) -> void:
	_event(name, Time.get_ticks_usec())


func _on_pre_draw() -> void:
	_pre_draw = Time.get_ticks_usec()
	_event("pre_draw", _pre_draw)
	if _proc_end > 0:
		_post_proc_us += _pre_draw - _proc_end
		_proc_end = 0


func _on_post_draw() -> void:
	_post_draw = Time.get_ticks_usec()
	_event("post_draw", _post_draw)


func _on_process_frame() -> void:
	_frame_start = Time.get_ticks_usec()
	_event("process_frame", _frame_start)
