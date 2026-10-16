# smoke: solo timeout=300s (verdict reads wall time: per-handler main-thread ms on stage entry)
extends SceneTree

# SWAP-HITCH (KB6, measured 2026-10-15 at f0d5cecb): entering a park stage froze the main thread
# for about 2 s, on the launch into stage 2 and on every retry, because the stage_entered
# handlers redid per-map work synchronously. This test plays the park table headless, wraps the
# real stage_entered listeners with a timer and checks the time each one spends on a retry of
# stage 1, the exit into stage 2 and a retry of stage 2.
#
# What is checked is the per-map work this unit moved, not the 33 ms frame, which stage entry
# still misses. At f0d5cecb activities spent 230 to 930 ms an entry (graph read about 50 ms,
# trade-pocket candidates about 180 ms, pocket-draw layout about 710 ms past stage 1) and the set
# dressing 250 to 600 ms rebuilding the stage it already had. Now a worker started on the previous
# entry hands activities that data, so its handler is left with the site nodes: about 6 ms a retry,
# and up to about 95 ms on a first entry that builds a trade interior, whose first-use materials
# (palette.gd, spillway_scenery.gd) are outside this unit. Budgets: activities RETRY_MS on a retry
# and FIRST_MS on the exit into stage 2, the set dressing DRESSING_MS on a stage it already dressed.
# World's handler (the natural event family's setup, about 750 ms; natural.gd, event_ground.gd)
# and the set dressing's first build of a new stage (about 250 ms; _build_props) are printed, not
# checked: they are the follow-up that brings stage entry under 33 ms.
#
# Also checked: the worker's results equal the synchronous computation on the live map, and the
# audio and activities share one graph per map.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")

const RETRY_MS := 20.0
const FIRST_MS := 150.0
const DRESSING_MS := 4.0
const SETTLE_TICKS := 30
const WAIT_TICKS_MAX := 3600
const TIMED := ["activities.gd", "set_dressing.gd", "world.gd"]

var _game
var _t := T.new("stage_entry_budget_test")
# Script file name -> ms of its last stage_entered call.
var _last := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("stage_entry_budget_test: machine load at start (1 min) %s" % FileAccess.get_file_as_string("/proc/loadavg").split(" ")[0])
	SimClock.ticks = true
	seed(11)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await physics_frame
	await physics_frame
	_game.presentation.audio.bake_now()
	_game.run.run_seed_override = 11
	_game.player.source = Intent.Scripted.new()
	_wrap()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _ticks(SETTLE_TICKS)
	_t.check("the run is on park stage 1", _game.flow.stage() == 1 and _park_id() != "", "stage %d map %s" % [_game.flow.stage(), _park_id()])
	_t.check("every timed handler is wired", _last.size() == TIMED.size(), str(_last.keys()))

	var first := _last.duplicate()
	_report("first entry, stage 1", first)
	_t.check("first entry of stage 1: the set dressing keeps its setup build", first.get("set_dressing.gd", INF) <= DRESSING_MS, _ms(first, "set_dressing.gd"))

	_game.flow.retry_stage()
	var retry_1 := _last.duplicate()
	_report("retry, stage 1", retry_1)
	_t.check("retry of stage 1: activities within %.0f ms" % RETRY_MS, retry_1.get("activities.gd", INF) <= RETRY_MS, _ms(retry_1, "activities.gd"))
	_t.check("retry of stage 1: set dressing within %.0f ms" % DRESSING_MS, retry_1.get("set_dressing.gd", INF) <= DRESSING_MS, _ms(retry_1, "set_dressing.gd"))
	await _ticks(SETTLE_TICKS)

	# The next stage builds the way play does (world.gd starts it when the Warden wakes).
	var terrain = _game.ctx.terrain
	terrain.prepare(2)
	var waited := 0
	while not terrain.is_ready(2) and waited < WAIT_TICKS_MAX:
		await physics_frame
		waited += 1
	_game.player.reset_to(terrain.spawn_point(1) + Vector3.UP * 2.0, Vector3(0.0, 0.0, 6.0))
	await _ticks(2)
	_game.flow._finish_stage()
	var exit_1 := _last.duplicate()
	_report("exit into stage 2", exit_1)
	_t.check("the exit entered park stage 2", _game.flow.stage() == 2 and _park_id() != "", "stage %d map %s" % [_game.flow.stage(), _park_id()])
	_t.check("exit into stage 2: activities within %.0f ms" % FIRST_MS, exit_1.get("activities.gd", INF) <= FIRST_MS, _ms(exit_1, "activities.gd"))
	_check_prepared()
	await _ticks(SETTLE_TICKS)

	_game.flow.retry_stage()
	var retry_2 := _last.duplicate()
	_report("retry, stage 2", retry_2)
	_t.check("retry of stage 2: activities within %.0f ms" % RETRY_MS, retry_2.get("activities.gd", INF) <= RETRY_MS, _ms(retry_2, "activities.gd"))
	_t.check("retry of stage 2: set dressing within %.0f ms" % DRESSING_MS, retry_2.get("set_dressing.gd", INF) <= DRESSING_MS, _ms(retry_2, "set_dressing.gd"))
	await _ticks(SETTLE_TICKS)

	# Audio's parameter sampler reads the same graph instance activities entered with.
	var audio = _game.presentation.audio
	audio.sample_run_parameters()
	var graph = _game.world.activities._graph
	_t.check("audio and activities share one graph per map", graph != null and audio._parameter_graph == graph,
		"activities %s, audio %s" % [str(graph), str(audio._parameter_graph)])
	_game.queue_free()
	await physics_frame
	quit(_t.verdict())


# Disconnect every stage_entered listener and reconnect it in the same order behind a timer.
func _wrap() -> void:
	var events = _game.ctx.events
	for connection in events.get_signal_connection_list("stage_entered"):
		var callable: Callable = connection["callable"]
		var object: Object = callable.get_object()
		var script: Script = object.get_script() if object != null else null
		var file := script.resource_path.get_file() if script != null else ""
		events.disconnect("stage_entered", callable)
		events.connect("stage_entered", func(stage: int, retry: bool):
			var t0 := Time.get_ticks_usec()
			callable.call(stage, retry)
			if file in TIMED:
				_last[file] = (Time.get_ticks_usec() - t0) / 1000.0)


# The worker's pool and layout for the stage just entered match a fresh synchronous computation.
func _check_prepared() -> void:
	var activities = _game.world.activities
	var map = _game.ctx.terrain.map()
	var id := _park_id()
	if not _t.check("activities has a per-map entry-data worker", "_prep" in activities and activities.has_method("graph_path")):
		return
	var data: Dictionary = activities._prep.get(id, {})
	_t.check("stage 2's entry data came from the worker", not data.is_empty() and not data.has("task"), str(data.keys()))
	var graph = ParkGraph.read(activities.graph_path(id))
	var pool: PackedInt32Array = data.get("pool", PackedInt32Array())
	var want_pool := TradePockets.candidates(graph, map)
	_t.check("worker pool equals the synchronous candidates", not want_pool.is_empty() and pool == want_pool, "%d nodes, want %d" % [pool.size(), want_pool.size()])
	var want: Dictionary = PocketDraw.prepare(graph, map)
	var got: Dictionary = data.get("layout", {})
	_t.check("worker layout equals the synchronous layout", not want.anchors.is_empty() and var_to_bytes(got) == var_to_bytes(want),
		"%d anchors, want %d" % [got.get("anchors", []).size(), want.anchors.size()])


func _park_id() -> String:
	var map = _game.ctx.terrain.map()
	return String(map.park.map) if "park" in map and not map.park.is_empty() else ""


func _report(label: String, times: Dictionary) -> void:
	var parts := PackedStringArray()
	for file in TIMED:
		parts.append("%s %s" % [file, _ms(times, file)])
	print("stage_entry_budget_test: %s: %s" % [label, ", ".join(parts)])


static func _ms(times: Dictionary, file: String) -> String:
	return "%.1f ms" % times[file] if times.has(file) else "not called"


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
