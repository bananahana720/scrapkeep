# smoke: solo timeout=300s (verdict reads wall time: per-handler main-thread ms on stage entry)
extends SceneTree

# SWAP-HITCH (KB6, measured 2026-10-15 at f0d5cecb): entering a park stage froze the main thread
# for about 2 s, on the launch into stage 2 and on every retry, because the stage_entered
# handlers redid per-map work synchronously. This test plays the park table headless through the
# real flow and reads the main-thread time activities and the set dressing record for their own
# stage_entered handler (last_entry_usec) on the first entry, a retry of stage 1, the exit into
# stage 2 and a retry of stage 2.
#
# What is checked is the per-map work this unit moved, not the 33 ms frame, which stage entry
# still misses. At f0d5cecb activities spent 230 to 930 ms an entry (graph read about 50 ms,
# trade-pocket candidates about 180 ms, pocket-draw layout about 710 ms past stage 1) and the set
# dressing 250 to 600 ms rebuilding the stage it already had. Now a worker started on the previous
# entry hands activities that data, so its handler is left with the site nodes: about 6 ms a retry,
# and up to about 95 ms on a first entry that builds a trade interior, whose first-use materials
# were outside that unit (see SWAP-HITCH-2 below). Budgets: activities RETRY_MS on a retry
# and FIRST_MS on the exit into stage 2, the set dressing DRESSING_MS on a stage it already dressed.
# World's whole handler and the entry frame stay measured by tools/perf_bench.gd, not here.
#
# Also checked: the worker's results equal the synchronous computation on the live map, and the
# audio and activities share one graph per map.
#
# SWAP-HITCH-2 (perf_bench p2, measured at 7dbdebae): the launch into stage 2 still spent 809 ms in
# the natural family's setup (natural.gd, the flood and collapse surfaces; 1,054 ms on stage 1's
# map), 275 to 285 ms in the set dressing's first build of the new stage, and 65 to 67 ms in the
# director's map and graph read; the trade devices' plate texture added about 55 ms to the first
# entry that builds a trade pocket, so FIRST_MS drops from 150 to 50 once activities makes it at
# setup. Workers started once stage 2's ground is built now plan all three, so this test also checks that
# stage 2's natural plan, dressing plan and director map came from a worker, that activities'
# pocket layout came from its worker (not from _enter_stage), that the set dressing builds the new
# stage within NEW_DRESSING_MS, and that every worker result and the stage 2 retry equal a fresh
# synchronous build: the natural surfaces, the dressing's instance buffers, and the trade and drawn
# site specs drawn again from a fresh graph and the run's memory as it stood before the exit.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const NATURAL_PATH := "res://src/world/events/natural.gd"
const DIRECTOR_PATH := "res://src/world/director.gd"

const RETRY_MS := 20.0
const FIRST_MS := 50.0
const DRESSING_MS := 4.0
const NEW_DRESSING_MS := 15.0
const SETTLE_TICKS := 30
const WAIT_TICKS_MAX := 3600
const TIMED := ["activities", "set_dressing"]

var _game
var _t := T.new("stage_entry_budget_test")
# The run's trade and pocket memory just before the exit into stage 2, for the fresh site draw.
var _before_exit := {}


# The run fields TradePockets.stage_site and PocketDraw.stage_sites read, so a fresh draw can use
# the run's memory as it stood before the exit without touching the live run.
class RunCopy:
	extends RefCounted
	var stage := 1
	var run_seed := 0
	var hp := 0
	var max_hp := 0
	var trade_memory := {}
	var pocket_draw_cache := {}


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
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _ticks(SETTLE_TICKS)
	_t.check("the run is on park stage 1", _game.flow.stage() == 1 and _park_id() != "", "stage %d map %s" % [_game.flow.stage(), _park_id()])
	_t.check("both handlers record their entry time", _times().size() == TIMED.size(), str(_times()))

	var first := _times()
	_report("first entry, stage 1", first)
	_t.check("first entry of stage 1: the set dressing keeps its setup build", first.get("set_dressing", INF) <= DRESSING_MS, _ms(first, "set_dressing"))

	_game.flow.retry_stage()
	var retry_1 := _times()
	_report("retry, stage 1", retry_1)
	_t.check("retry of stage 1: activities within %.0f ms" % RETRY_MS, retry_1.get("activities", INF) <= RETRY_MS, _ms(retry_1, "activities"))
	_t.check("retry of stage 1: set dressing within %.0f ms" % DRESSING_MS, retry_1.get("set_dressing", INF) <= DRESSING_MS, _ms(retry_1, "set_dressing"))
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
	var run = _game.ctx.run
	_before_exit = {"trade_memory": run.trade_memory.duplicate(true), "pocket_draw_cache": run.pocket_draw_cache.duplicate(true),
		"hp": run.hp, "max_hp": run.max_hp, "run_seed": run.run_seed}
	_game.flow._finish_stage()
	var exit_1 := _times()
	_report("exit into stage 2", exit_1)
	_t.check("the exit entered park stage 2", _game.flow.stage() == 2 and _park_id() != "", "stage %d map %s" % [_game.flow.stage(), _park_id()])
	_t.check("exit into stage 2: activities within %.0f ms" % FIRST_MS, exit_1.get("activities", INF) <= FIRST_MS, _ms(exit_1, "activities"))
	_t.check("exit into stage 2: set dressing builds the new stage within %.0f ms" % NEW_DRESSING_MS, exit_1.get("set_dressing", INF) <= NEW_DRESSING_MS, _ms(exit_1, "set_dressing"))
	_check_prepared()
	_check_stage_two_workers()
	_check_natural_fresh("exit into stage 2")
	_check_dressing_fresh("exit into stage 2")
	await _ticks(SETTLE_TICKS)

	_game.flow.retry_stage()
	var retry_2 := _times()
	_report("retry, stage 2", retry_2)
	_t.check("retry of stage 2: activities within %.0f ms" % RETRY_MS, retry_2.get("activities", INF) <= RETRY_MS, _ms(retry_2, "activities"))
	_t.check("retry of stage 2: set dressing within %.0f ms" % DRESSING_MS, retry_2.get("set_dressing", INF) <= DRESSING_MS, _ms(retry_2, "set_dressing"))
	_check_natural_fresh("retry of stage 2")
	_check_dressing_fresh("retry of stage 2")
	_check_sites_fresh()
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


# Each handler's recorded time of the last stage entry, in ms; a handler that records none is absent.
func _times() -> Dictionary:
	var out := {}
	var modules := {"activities": _game.world.activities, "set_dressing": _game.presentation.set_dressing}
	for key in TIMED:
		var module = modules[key]
		if module != null and "last_entry_usec" in module:
			out[key] = module.last_entry_usec / 1000.0
	return out


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
	# _enter_stage computes the layout itself when the worker gave none, so only this flag, set when
	# the worker's own layout was non-empty, tells the worker's from the main thread's.
	_t.check("stage 2's pocket layout came from the worker, not from _enter_stage", data.get("worker_layout", false), str(data.keys()))


# Stage 2's natural plan, dressing plan and director map were each made on a worker before the entry.
func _check_stage_two_workers() -> void:
	var natural = load(NATURAL_PATH)
	var plans = natural.get("_plans")
	var key: int = natural.call("_root_key", _game.ctx.terrain, 2) if natural.has_method("_root_key") else 0
	var entry: Dictionary = plans.get(key, {}) if plans is Dictionary else {}
	_t.check("stage 2's natural plan came from a worker", entry.get("worker", false), "key %d entry %s" % [key, str(entry.keys())])
	var dressing = _game.presentation.set_dressing
	_t.check("stage 2's set dressing was built from a worker's plan", dressing.get("built_from_worker") == true)
	var parks = load(DIRECTOR_PATH).get("_parks")
	var park: Dictionary = parks.get(_park_id(), {}) if parks is Dictionary else {}
	_t.check("stage 2's director map came from a worker", park.get("worker", false) and not park.get("park", {}).is_empty(), str(park.keys()))
	_t.check("the director's graph is the shared one", _game.world.director.has_method("_graph") and _game.world.director.call("_graph") == _game.world.activities._graph)


# The natural handler's installed surfaces equal a fresh plan of the live stage 2 ground.
func _check_natural_fresh(label: String) -> void:
	var natural = load(NATURAL_PATH)
	var handler = _game.world.event_families.get("natural")
	if not _t.check(label + ": a natural handler and plan() exist", handler != null and natural.has_method("plan")):
		return
	var fresh: Dictionary = natural.call("plan", _game.world, _game.ctx.terrain.map().park)
	var rows := 0
	var surfaces := 0
	var mismatches := PackedStringArray()
	for id in fresh:
		var want: Dictionary = fresh[id]
		var got: Dictionary = handler._prepared.get(id, {})
		rows += 1
		# A span collapse stands on its span (prepare_overlay moves it), so only its crack foot compares.
		var moved: bool = got.get("geometry", {}).get("span", false)
		if got.is_empty() or (not moved and not got.at.is_equal_approx(want.at)) or got.geometry.get("crack_foot_x", 0.0) != want.geometry.get("crack_foot_x", 0.0):
			mismatches.append(id + " placement")
			continue
		var pairs := []
		if want.has("water"):
			pairs.append([got.get("water_surface"), want.water])
		if want.has("surface"):
			var swap: Dictionary = handler._overlay_map.swaps[got.swap]
			pairs.append([swap.baseline, want.surface])
			if want.has("target"):
				pairs.append([swap.target, want.target])
		for pair in pairs:
			surfaces += 1
			if pair[0] == null or pair[0].vertices != pair[1].vertices or var_to_bytes(pair[0].cells) != var_to_bytes(pair[1].cells):
				mismatches.append(id + " surface")
	_t.check("%s: every natural row's placement and surface equal a fresh plan" % label, rows > 0 and surfaces > 0 and mismatches.is_empty(),
		"%d rows, %d surfaces, mismatched %s" % [rows, surfaces, ", ".join(mismatches)])


# The set dressing's instance buffers equal a fresh synchronous plan of stage 2.
func _check_dressing_fresh(label: String) -> void:
	var dressing = _game.presentation.set_dressing
	if not _t.check(label + ": the set dressing has plan()", dressing.has_method("plan") and dressing.has_method("_flags")):
		return
	var terrain = _game.ctx.terrain
	var map = terrain.map_for(2)
	var fresh: Dictionary = dressing.plan(dressing.map_rows(map), dressing.keepouts(map, 2), terrain.ground_callable(2),
		String(_game.ctx.stages.of(2).map).hash(), dressing._flags())
	var want := {"BrokenRock": fresh.get("rock"), "DustMotes": fresh.get("dust"), "SandStreaks": fresh.get("streaks")}
	for kit in fresh.get("clutter", {}):
		want["Clutter_" + kit] = fresh.clutter[kit]
	var compared := 0
	var mismatches := PackedStringArray()
	for batch in dressing.batches:
		if want.get(batch.name) == null:
			continue
		compared += 1
		if batch.get_meta("instance_buffer") != want[batch.name]:
			mismatches.append(batch.name)
	_t.check("%s: the dressing's instance buffers equal a fresh plan" % label, compared > 0 and compared == dressing.batches.size() and mismatches.is_empty(),
		"%d of %d batches compared, mismatched %s" % [compared, dressing.batches.size(), ", ".join(mismatches)])


# The retry's trade and drawn sites equal specs drawn again from a fresh graph, pool and layout and
# the run's memory as it stood before the exit into stage 2.
func _check_sites_fresh() -> void:
	var activities = _game.world.activities
	var map = _game.ctx.terrain.map()
	var graph = ParkGraph.read(activities.graph_path(_park_id()))
	var run := RunCopy.new()
	run.stage = 2
	run.run_seed = _before_exit.run_seed
	run.hp = _before_exit.hp
	run.max_hp = _before_exit.max_hp
	run.trade_memory = _before_exit.trade_memory.duplicate(true)
	run.pocket_draw_cache = _before_exit.pocket_draw_cache.duplicate(true)
	var seed_value: int = _game.ctx.rng.seed
	var trade := TradePockets.stage_site(graph, map, run, seed_value, TradePockets.candidates(graph, map))
	var drawn := PocketDraw.stage_sites(graph, map, run, seed_value, trade, PocketDraw.prepare(graph, map))
	var live = _game.ctx.run
	_t.check("retry of stage 2: the trade spec equals a fresh draw", not trade.is_empty() and var_to_bytes(live.trade_memory.offers.get("2", {})) == var_to_bytes(trade),
		"fresh %s" % str(trade.get("id", "none")))
	_t.check("retry of stage 2: the drawn site specs equal a fresh draw", not drawn.is_empty() and var_to_bytes(live.pocket_draw_cache.get("2", {}).get("sites", [])) == var_to_bytes(drawn),
		"%d fresh" % drawn.size())
	var want := PackedStringArray()
	for spec in [trade] + drawn:
		if not _game.ctx.calm or activities.RULES[spec.id].finishes == "wall_broken" or spec == trade:
			want.append("%s %.2f %.2f" % [spec.id, spec.at.x, spec.at.y])
	var got := PackedStringArray()
	for s in activities.sites:
		if s.drawn or not s.trade.is_empty():
			got.append("%s %.2f %.2f" % [s.id, s.global_position.x, s.global_position.z])
	_t.check("retry of stage 2: the built trade and drawn sites stand where a fresh draw puts them", not want.is_empty() and got == want,
		"built %s, want %s" % [", ".join(got), ", ".join(want)])


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
