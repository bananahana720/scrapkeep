extends RefCounted

# What built each slow frame of a launched self-play game (tools/self_play.gd --self-play-probe=<file>),
# for a hitch hunt on a rendering display. Reads only. One ndjson row per drawn frame over SLOW_MS:
#   t            seconds since launch at the frame's end (the self-play lines' clock)
#   ms           the drawn frame, post_draw to post_draw (the frame log's ms)
#   stage, state, stage_time   where the run was
#   bot_ms       the self-play bot's cost, not the game's: its own physics callbacks (the driver's tick,
#                at its own priority) plus its subtree's node _process and _physics_process spans
#   net_ms       ms less bot_ms: read a hitch by this (LESSONS 56)
#   draw_ms      frame_pre_draw to frame_post_draw: the render server's draw of the frame
#   split        tools/frame_split.gd's parts: phys_ms, tick_max_ms, proc_ms, pre_proc_ms, post_proc_ms
#   added        nodes that entered the tree this frame, and the busiest sources by script or scene
#   freed        nodes that left the tree this frame
#   d_nodes, d_resources, d_objects   Performance count changes since the last drawn frame
#   d_pipelines  pipeline compilations this frame: canvas, mesh, surface, draw, specialization
#   proc_top, phys_top   the subtrees under the game (three levels down) whose node _process and
#                _physics_process took longest this frame: a marker node stands before each one in
#                tree order and the span to the next marker is its subtree's. A node with its own
#                priority runs outside that order and lands on no subtree.
#   signals      with --self-play-probe-signals=1, each GameEvents signal whose handlers took 5 ms or
#                more this frame (tools/signal_timer.gd), slowest handler first. It wraps every
#                handler, so it adds its own cost; leave it off for a frame-time reading.
# The rows are written as the game quits (write()).

const FrameSplit := preload("res://tools/frame_split.gd")
const SignalTimer := preload("res://tools/signal_timer.gd")

const SLOW_MS := 25.0
const TOP_SOURCES := 6

var path := ""
var rows: Array[Dictionary] = []
var bot_us := 0

var _game: Node
var _bot: Node
var _bot_label := ""
var _split
var _signals
var _last_post := -1
var _pre_draw := 0
var _added := 0
var _freed := 0
var _sources := {}
var _counts := []
var _proc := {}
var _phys := {}
var _proc_at := 0
var _proc_label := ""
var _phys_at := 0
var _phys_label := ""


class Tail:
	extends Node
	var probe

	func _init() -> void:
		process_priority = 2147483647
		process_physics_priority = 2147483647

	func _process(_delta: float) -> void:
		probe._close_spans()

	func _physics_process(_delta: float) -> void:
		probe._mark(true, "")


class Marker:
	extends Node
	var probe
	var label := ""

	func _process(_delta: float) -> void:
		probe._mark(false, label)

	func _physics_process(_delta: float) -> void:
		probe._mark(true, label)


func _place_markers(root: Node, depth: int) -> void:
	for child in root.get_children():
		if child is Marker:
			continue
		var marker := Marker.new()
		marker.probe = self
		var own := String(child.name)
		if own.begins_with("@") and child.get_script() != null:
			own = child.get_script().resource_path.get_file()
		marker.label = "%s/%s" % [root.name, own] if root != _game else own
		if child == _bot:
			_bot_label = marker.label
		marker.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(marker)
		root.move_child(marker, child.get_index())
		if depth > 1:
			_place_markers(child, depth - 1)


func _mark(physics: bool, label: String) -> void:
	var now := Time.get_ticks_usec()
	if physics:
		if not _phys_label.is_empty():
			_phys[_phys_label] = int(_phys.get(_phys_label, 0)) + now - _phys_at
		_phys_at = now
		_phys_label = label
	else:
		if not _proc_label.is_empty():
			_proc[_proc_label] = int(_proc.get(_proc_label, 0)) + now - _proc_at
		_proc_at = now
		_proc_label = label


func _close_spans() -> void:
	var now := Time.get_ticks_usec()
	if not _proc_label.is_empty():
		_proc[_proc_label] = int(_proc.get(_proc_label, 0)) + now - _proc_at
	_proc_label = ""


static func _top(spans: Dictionary) -> Array:
	var labels := spans.keys()
	labels.sort_custom(func(a, b): return spans[a] > spans[b])
	var out := []
	for label in labels.slice(0, TOP_SOURCES):
		out.append([label, snappedf(spans[label] / 1000.0, 0.01)])
	return out


func watch(game: Node, file: String, time_signals: bool, bot: Node = null) -> void:
	_game = game
	_bot = bot
	path = file
	var tree := game.get_tree()
	_split = FrameSplit.new()
	_split.watch(tree)
	if time_signals:
		_signals = SignalTimer.new()
		var names := []
		for row in game.events.get_script().get_script_signal_list():
			names.append(row.name)
		_signals.time_signals(game.events, names)
	_place_markers(game, 3)
	var tail := Tail.new()
	tail.probe = self
	tail.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(tail)
	tree.node_added.connect(_on_added)
	tree.node_removed.connect(func(_node: Node): _freed += 1)
	RenderingServer.frame_pre_draw.connect(func(): _pre_draw = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_counts = _read_counts()


func _on_added(node: Node) -> void:
	_added += 1
	var label := node.scene_file_path
	if label.is_empty():
		var script = node.get_script()
		label = script.resource_path if script != null and not script.resource_path.is_empty() else node.get_class()
	_sources[label] = int(_sources.get(label, 0)) + 1


func _read_counts() -> Array:
	return [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _on_post_draw() -> void:
	var now := Time.get_ticks_usec()
	var counts := _read_counts()
	if _last_post >= 0:
		var ms := (now - _last_post) / 1000.0
		var split: Dictionary = _split.take(ms)
		if _signals != null:
			_signals.flush()
		if ms >= SLOW_MS:
			var top := _sources.keys()
			top.sort_custom(func(a, b): return _sources[a] > _sources[b])
			var sources := {}
			for label in top.slice(0, TOP_SOURCES):
				sources[label] = _sources[label]
			var run = _game.run
			var bot_ms := (bot_us + int(_proc.get(_bot_label, 0)) + int(_phys.get(_bot_label, 0))) / 1000.0
			var row := {"t": snappedf(now / 1000000.0, 0.001), "ms": snappedf(ms, 0.01), "stage": run.stage if run != null else 0,
				"state": _game.flow.state_name() if _game.flow != null else "", "stage_time": snappedf(run.stage_time, 0.01) if run != null else 0.0,
				"bot_ms": snappedf(bot_ms, 0.01), "net_ms": snappedf(ms - bot_ms, 0.01), "draw_ms": snappedf((now - _pre_draw) / 1000.0, 0.01),
				"split": {"phys_ms": snappedf(split.phys_ms, 0.01), "tick_max_ms": snappedf(split.tick_max_ms, 0.01), "proc_ms": snappedf(split.proc_ms, 0.01),
					"pre_proc_ms": snappedf(split.pre_proc_ms, 0.01), "post_proc_ms": snappedf(split.post_proc_ms, 0.01)},
				"added": _added, "sources": sources, "freed": _freed,
				"d_nodes": counts[0] - _counts[0], "d_resources": counts[1] - _counts[1], "d_objects": counts[2] - _counts[2],
				"d_pipelines": [counts[3] - _counts[3], counts[4] - _counts[4], counts[5] - _counts[5], counts[6] - _counts[6], counts[7] - _counts[7]],
				"proc_top": _top(_proc), "phys_top": _top(_phys)}
			if _signals != null:
				row["signals"] = _signals.rows.duplicate()
			rows.append(row)
		if _signals != null:
			_signals.rows.clear()
			_signals.frame += 1
	_last_post = now
	_counts = counts
	bot_us = 0
	_proc.clear()
	_phys.clear()
	_added = 0
	_freed = 0
	_sources.clear()


func write() -> void:
	# The render server outlives the tree: a frame signal still bound to this probe or its split at
	# engine shutdown crashed the quit (signal 11), so every connection goes first.
	for sig in [RenderingServer.frame_pre_draw, RenderingServer.frame_post_draw]:
		for c in sig.get_connections():
			if c.callable.get_object() in [self, _split]:
				sig.disconnect(c.callable)
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("frame_probe: cannot write %s" % path)
		return
	for row in rows:
		file.store_line(JSON.stringify(row))
	file.close()
	print("self-play: probe %d slow frames in %s" % [rows.size(), path])
	path = ""
