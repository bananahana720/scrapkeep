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
# ENTRY-FRAMES (see the measured basis at FRAME_MS below): each module's handler is timed alone above,
# but a quick exit can put the set dressing's deferred build (DRESS-ENTRY) and ParkProps' node slices
# (3 ms a frame) in the same frames. From the entry until both are done, this test reads what the two
# nodes record of their own _process (last_process_usec and last_process_frame, as last_entry_usec above),
# pairs the readings by frame, and holds the main-thread time they spend together in a frame under FRAME_MS.
# It watches the exit into stage 2 and a quick exit (the planted slow plan, with ParkProps asked to build
# again), and checks that a props slice and the dressing's deferred build really ran in the timed frames
# and whether they shared one.
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
const SafeStore := preload("res://src/core/safe_store.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
# No park ships a vignette file yet, so stage 2 (park_flume) borrows park_props_test's park_dam file, which
# ParkProps places on park_flume's map, and so has nodes to build in the frames after the entry.
const PROPS_FIXTURE := "res://tests/fixtures/park_props/park_dam.json"
# ... with its spots copied to this many vignettes (park_props_test's _check_synthetic does the same), so the
# build takes many frames at the slice budget on any CPU and a build without it takes exactly one.
const SYNTHETIC_VIGNETTES := 60
const SLICE_FRAMES_MIN := 2
const NATURAL_PATH := "res://src/world/events/natural.gd"
const DIRECTOR_PATH := "res://src/world/director.gd"

const RETRY_MS := 20.0
const FIRST_MS := 50.0
const DRESSING_MS := 4.0
const NEW_DRESSING_MS := 15.0
# DRESS-ENTRY: a plan still drawing at the entry is built by _process when its worker is done.
const DRESSING_FRAMES_MAX := 240
# ENTRY-FRAMES (measured 2026-10-20 at 03f19df8 plus this unit, 4 vCPU cloud box, headless, loadavg 2 to 6, with
# the 60-vignette fixture: 470 instances, 659 views): the most main-thread ms the set dressing's _process and
# ParkProps' _process spend together in one frame after a stage entry. A ParkProps slice runs 3 ms
# (BUILD_SLICE_USEC) plus the job that crosses it, 3.3 to 4.7 ms; the dressing's deferred build adds about 1.9 ms.
# Good runs: the exit peaked at 8.2 ms over 30 slice frames; the quick exit at 9.6 ms (the entry frame, with the
# handlers) over 31 slice frames, the build and first slice sharing a frame at 5.9 ms. Planted (a temporary
# park_props.gd patch slicing without a budget, two runs): the whole build took 99.9 and 101.5 ms at the exit and
# 99.2 and 127.6 ms in the quick exit, in 1 slice frame, so both the frame check and the slice-frame count failed
# every time. The count is CPU-independent: a budgeted build spans many frames on any CPU, a whole one is 1.
# 12 ms clears the good peaks and sits 4.7 ms under the 16.7 ms frame.
const FRAME_MS := 12.0
# The held plan of the quick exit is let go after this many frames whatever ParkProps is doing.
const GATE_FRAMES_MAX := 600
const GATE_SPIN_MAX := 20000000
const FRAMES_WATCH_MAX := 3000
const SETTLE_TICKS := 30
const WAIT_TICKS_MAX := 3600
const TIMED := ["activities", "set_dressing"]

var _game
var _t := T.new("stage_entry_budget_test")
# The run's trade and pocket memory just before the exit into stage 2, for the fresh site draw.
var _before_exit := {}
# '<node id>_<frame>' of every _process reading already added to a frame's sum.
var _seen := {}
# The enlarged vignette file under user://, one folder per process (worktrees share user://).
var _big_file := ""


# park_dam.json with its spots copied to SYNTHETIC_VIGNETTES vignettes, written under user:// (ParkProps reads any path).
func _write_big_fixture() -> String:
	var file := ParkProps.load_json(PROPS_FIXTURE)
	var source: Array = file["spots"]
	var spots: Array = []
	for i in SYNTHETIC_VIGNETTES:
		var spot: Dictionary = (source[i % source.size()] as Dictionary).duplicate(true)
		spot["id"] = "synthetic_%d" % i
		spots.append(spot)
	file["spots"] = spots
	var dir := "user://stage_entry_budget_test_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/park_flume.json"
	SafeStore.write_atomic(path, JSON.stringify(file))
	return path


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
	_big_file = _write_big_fixture()
	ParkProps.file_overrides["park_flume"] = _big_file
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

	# The next stage builds before the exit, as in play (world.gd starts it when the Warden wakes).
	# Under SimClock.ticks (set above) prepare() builds it whole inside the call (terrain.gd
	# _worker_builds), so the wait loop below ends at once; the entry handlers timed here run after it.
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
	var helper = _game.world.contraptions[1]._cache_rules if _game.world.contraptions.has(1) else null
	var stage_1_helper: int = helper.get_instance_id() if is_instance_valid(helper) else 0
	_game.flow._finish_stage()
	var exit_1 := _times()
	_report("exit into stage 2", exit_1)
	_t.check("the exit entered park stage 2", _game.flow.stage() == 2 and _park_id() != "", "stage %d map %s" % [_game.flow.stage(), _park_id()])
	_t.check("exit into stage 2: activities within %.0f ms" % FIRST_MS, exit_1.get("activities", INF) <= FIRST_MS, _ms(exit_1, "activities"))
	_t.check("exit into stage 2: set dressing's entry frame within %.0f ms" % NEW_DRESSING_MS, exit_1.get("set_dressing", INF) <= NEW_DRESSING_MS, _ms(exit_1, "set_dressing"))
	var entry_deferred: bool = _game.presentation.set_dressing.entry_deferred
	var watch := await _watch_frames()
	var complete := {"done": watch.dressing_done, "frames": watch.dressing_frames}
	print("stage_entry_budget_test: exit into stage 2: dressing deferred %s, complete after %d frames" % [entry_deferred, complete.frames])
	_check_frames("exit into stage 2", watch, false)
	_check_watch_builds_same(watch)
	_t.check("exit into stage 2: the dressing is complete within %d frames" % DRESSING_FRAMES_MAX, complete.done and complete.frames <= DRESSING_FRAMES_MAX,
		"%d frames, deferred %s" % [complete.frames, entry_deferred])
	_check_big_fixture()
	_check_prepared()
	_check_stage_two_workers()
	_check_natural_fresh("exit into stage 2")
	_check_dressing_fresh("exit into stage 2")
	await _ticks(SETTLE_TICKS)
	_check_caches_survive_exit(stage_1_helper)

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
	await _check_slow_plan_control()
	_game.queue_free()
	await physics_frame
	ParkProps.file_overrides.clear()
	DirAccess.remove_absolute(_big_file)
	DirAccess.remove_absolute(_big_file.get_base_dir())
	quit(_t.verdict())


# ENTRY-FRAMES: from the frame of a stage entry until the set dressing is built and ParkProps has no work
# left (bounded), read what the two nodes record of their own _process (last_process_usec, stamped with
# last_process_frame). process_frame emits before the nodes' _process, so each wake sees the frame before:
# the readings are keyed by their frame stamp and paired by it into one sum per frame. Frame 0 is the
# entry itself: the two handlers' last_entry_usec and the first stamp's _process readings. Returns the
# frames' ms, and per frame whether each did its build work (the dressing's wait flag dropped; ParkProps'
# views grew).
func _watch_frames(gate := {}) -> Dictionary:
	var dressing = _game.presentation.set_dressing
	var props = _game.presentation.park_props
	# Readings up to now belong to frames before the entry; only newer stamps are the entry's and after.
	for node in [dressing, props]:
		_seen["%d_%d" % [node.get_instance_id(), node.last_process_frame]] = true
	var by_frame := {}
	var dress_at := {}
	var slice_at := {}
	var frames := 0
	var dressing_frames := -1
	var dressing_done: bool = not dressing.batches.is_empty() and not dressing._dress_when_planned
	var was_waiting: bool = dressing._dress_when_planned
	var views_was: int = props.views.size()
	var deferred_built := false
	while frames < FRAMES_WATCH_MAX and not (dressing_done and props.is_built()):
		await process_frame
		frames += 1
		_read_frame(by_frame, dressing, props, dress_at, slice_at, was_waiting, views_was)
		was_waiting = dressing._dress_when_planned
		views_was = props.views.size()
		# The quick-exit control: the planted plan is held until ParkProps' worker is done (or already taken),
		# then let go at once, so the deferred build and the first slice land in one frame, the worst the two
		# can do. A missed condition is let go after GATE_FRAMES_MAX frames.
		if not gate.is_empty() and not gate.open:
			var how := ""
			if props._task < 0:
				how = "worker taken"
			elif WorkerThreadPool.is_task_completed(props._task):
				how = "worker done"
			elif frames >= GATE_FRAMES_MAX:
				how = "frame limit"
			if how != "":
				gate.open = true
				gate.how = how
				gate.sem.post()
				var spins := 0
				while not dressing._prep.is_empty() and not WorkerThreadPool.is_task_completed(dressing._prep.task) and spins < GATE_SPIN_MAX:
					spins += 1
				print("stage_entry_budget_test: the held plan was let go at frame %d: %s" % [frames, how])
		dressing_done = not dressing.batches.is_empty() and not dressing._dress_when_planned
		if dressing_done and dressing_frames < 0:
			dressing_frames = frames
	if not gate.is_empty() and not gate.open:
		gate.open = true
		gate.how = "after the watch"
		gate.sem.post()
	await process_frame
	_read_frame(by_frame, dressing, props, dress_at, slice_at, was_waiting, views_was)
	var stamps := by_frame.keys()
	stamps.sort()
	# Frame 0 is the entry frame: the handlers and the nodes' own _process, which share the engine frame.
	var first_process: float = by_frame[stamps[0]] if not stamps.is_empty() else 0.0
	var entry_parts := {"dressing_entry": dressing.last_entry_usec / 1000.0, "props_entry": props.last_entry_usec / 1000.0, "process": first_process}
	var ms: Array[float] = [(dressing.last_entry_usec + props.last_entry_usec) / 1000.0 + first_process]
	var dress_ran: Array[bool] = [false]
	var slice_ran: Array[bool] = [false]
	for stamp in stamps.slice(1):
		ms.append(by_frame[stamp])
		dress_ran.append(dress_at.has(stamp))
		slice_ran.append(slice_at.has(stamp))
		deferred_built = deferred_built or dress_at.has(stamp)
	return {"entry_parts": entry_parts, "ms": ms, "dress_ran": dress_ran, "slice_ran": slice_ran, "frames": frames, "dressing_frames": dressing_frames, "dressing_done": dressing_done,
		"props_built": props.is_built(), "deferred_built": deferred_built, "views": props.views.size(), "batches": dressing.batches.size(),
		"children": dressing.get_child_count(), "instances": props.instances.size()}


# One wake's readings: both nodes' last _process, summed under the frame they ran in. A frame only one of them
# stamped counts that one alone; state changes since the last wake belong to the frame the stamps name.
func _read_frame(by_frame: Dictionary, dressing, props, dress_at: Dictionary, slice_at: Dictionary, was_waiting: bool, views_was: int) -> void:
	for node in [dressing, props]:
		var stamp: int = node.last_process_frame
		var key := "%d_%d" % [node.get_instance_id(), stamp]
		if stamp >= 0 and not _seen.has(key):
			_seen[key] = true
			by_frame[stamp] = by_frame.get(stamp, 0.0) + node.last_process_usec / 1000.0
	if was_waiting and not dressing._dress_when_planned:
		dress_at[dressing.last_process_frame] = true
	if props.views.size() > views_was:
		slice_at[props.last_process_frame] = true


# ENTRY-FRAMES: the frames after an entry stay under FRAME_MS together, and the check could fire: a props
# slice ran in the timed frames, and in a quick exit the dressing's deferred build did too.
func _check_frames(label: String, watch: Dictionary, quick: bool) -> void:
	var ms: Array = watch.ms
	var worst := 0.0
	var over := 0
	var slices := 0
	var dress_frames := 0
	var overlap_same := 0
	var overlap_adjacent := 0
	for i in ms.size():
		# Frame 0, the entry frame, is reported and not gated here: the handlers' own budgets cover it (SWAP-HITCH,
		# DRESS-ENTRY's 15 ms), and ParkProps' entry frees the previous stage's views, 8.9 to 15.7 ms of frame 0
		# under load with the 60-vignette fixture.
		if i > 0:
			worst = maxf(worst, ms[i])
			if ms[i] > FRAME_MS:
				over += 1
		if watch.slice_ran[i]:
			slices += 1
		if watch.dress_ran[i]:
			dress_frames += 1
			if watch.slice_ran[i]:
				overlap_same += 1
			elif (i > 0 and watch.slice_ran[i - 1]) or (i + 1 < ms.size() and watch.slice_ran[i + 1]):
				overlap_adjacent += 1
	var listing := PackedStringArray()
	for v in ms:
		listing.append("%.1f" % v)
	var parts: Dictionary = watch.entry_parts
	print("stage_entry_budget_test: %s: entry frame (reported, not gated) %.1f ms = dressing entry %.1f + props entry %.1f + first _process %.1f" % [
		label, ms[0], parts.dressing_entry, parts.props_entry, parts.process])
	print("stage_entry_budget_test: %s: %d frames, worst after entry %.1f ms, %d props slice frames, dressing deferred build %s (%d frames), same frame %d, adjacent %d, props instances %d, views %d, frames ms [%s]" % [
		label, watch.frames, worst, slices, watch.deferred_built, dress_frames, overlap_same, overlap_adjacent, watch.instances, watch.views, ", ".join(listing)])
	_t.check("%s: every frame after the entry frame within %.0f ms for the dressing's build and ParkProps' slices together" % [label, FRAME_MS], over == 0 and ms.size() > 1,
		"worst %.1f ms, %d of %d frames over" % [worst, over, ms.size()])
	_t.check("%s: the dressing and ParkProps both finished inside the timed frames" % label, watch.dressing_done and watch.props_built and watch.frames < FRAMES_WATCH_MAX,
		"%d frames, dressing %s, props %s" % [watch.frames, watch.dressing_done, watch.props_built])
	_t.check("%s: ParkProps' build spanned at least %d slice frames (a whole build in one frame is 1)" % [label, SLICE_FRAMES_MIN], slices >= SLICE_FRAMES_MIN,
		"%d slice frames, %d views" % [slices, watch.views])
	if quick:
		_t.check("%s: the dressing's deferred build ran in the timed frames" % label, watch.deferred_built, "%d frames" % dress_frames)
		_t.check("%s: the build and a props slice fell in the same or adjacent frames" % label, overlap_same + overlap_adjacent >= 1,
			"same %d, adjacent %d" % [overlap_same, overlap_adjacent])


# The enlarged vignette file is valid on park_flume's map, so a smaller build later means a real change.
func _check_big_fixture() -> void:
	var file := ParkProps.load_json(_big_file)
	var kit := ParkProps.load_json(String(file.get("kit", "")))
	var errors := ParkProps.file_errors(file, kit, _game.ctx.terrain.map_for(2)) + ParkProps.kit_errors(kit)
	_t.check("the enlarged vignette file has %d spots and no file errors on park_flume's map" % SYNTHETIC_VIGNETTES, file.get("spots", []).size() == SYNTHETIC_VIGNETTES and errors.is_empty(), str(errors))


# The timed build equals the others: ParkProps rebuilt whole by finish() has the same instance and view counts,
# and the dressing has the batch and child counts of a fresh synchronous plan (the instance buffers are
# compared to a fresh plan by _check_dressing_fresh).
func _check_watch_builds_same(watch: Dictionary) -> void:
	var props = _game.presentation.park_props
	props._built_for = []
	props._stage_entered(2, false)
	props.finish()
	_t.check("the timed ParkProps build equals a whole build by finish()", watch.instances > 0 and props.instances.size() == watch.instances and props.views.size() == watch.views,
		"timed %d instances %d views, finish() %d and %d" % [watch.instances, watch.views, props.instances.size(), props.views.size()])
	var dressing = _game.presentation.set_dressing
	var terrain = _game.ctx.terrain
	var map = terrain.map_for(2)
	var fresh: Dictionary = dressing.plan(dressing.map_rows(map), dressing.keepouts(map, 2), terrain.ground_callable(2),
		String(_game.ctx.stages.of(2).map).hash(), dressing._flags())
	var want := 0
	for key in ["rock", "dust", "streaks"]:
		want += 1 if fresh.get(key) != null else 0
	want += fresh.get("clutter", {}).size()
	_t.check("the timed dressing build has the batch and child counts of a fresh plan", want > 0 and watch.batches == want and watch.children == want,
		"timed %d batches %d children, fresh plan %d" % [watch.batches, watch.children, want])


# The planted control (lesson 34): the stage entered the moment its plan starts on a worker (the
# plan takes about 360 ms there). A handler that waits on the worker spends that in the entry and
# fails the budget; one that defers leaves the stage bare for the entry, then builds the same
# buffers in a later frame.
func _check_slow_plan_control() -> void:
	var dressing = _game.presentation.set_dressing
	var terrain = _game.ctx.terrain
	var map = terrain.map_for(2)
	var rows: Dictionary = dressing.map_rows(map)
	var keep: Array = dressing.keepouts(map, 2)
	var ground: Callable = terrain.ground_callable(2)
	var seed_two: int = String(_game.ctx.stages.of(2).map).hash()
	var flags: Dictionary = dressing._flags()
	var out := {}
	# Held open by _watch_frames once the entry has returned (armed), so a handler that waits on the plan waits
	# the plan only and fails the entry budget; the dressing's build can be made to share a frame with ParkProps' slices.
	# The pool runs one low-priority task at a time (4 threads, 0.3 of them), so a held low-priority plan would
	# starve ParkProps' worker; this one holds a normal-priority thread. In play the two workers run one after the other.
	var gate := {"open": false, "armed": false, "how": "", "sem": Semaphore.new()}
	# The built stage 2 stays up, so "bare" below is the deferral's own clear; a plan already in
	# flight (the next stage's) is collected first, not dropped.
	dressing._built_for = []
	if not dressing._prep.is_empty():
		WorkerThreadPool.wait_for_task_completion(dressing._prep.task)
	var planted := func():
		out.merge(dressing.plan(rows, keep, ground, seed_two, flags))
		if gate.armed:
			gate.sem.wait()
	dressing._prep = {"key": dressing._key(2, terrain.geometry_root(2)), "out": out,
		"task": WorkerThreadPool.add_task(planted, true, "planted slow plan")}
	dressing._stage_entered(2, false)
	gate.armed = true
	var entry_ms: float = dressing.last_entry_usec / 1000.0
	var bare: bool = dressing.get_child_count() == 0
	_t.check("planted slow plan: the entry stays within %.0f ms and leaves the stage bare" % NEW_DRESSING_MS,
		entry_ms <= NEW_DRESSING_MS and bare and dressing.entry_deferred, "%.1f ms, %d children, deferred %s" % [entry_ms, dressing.get_child_count(), dressing.entry_deferred])
	# A quick exit also starts ParkProps again, so its slices land in the frames the deferred build does.
	var props = _game.presentation.park_props
	props._built_for = []
	props._stage_entered(2, false)
	var watch := await _watch_frames(gate)
	var complete := {"done": watch.dressing_done, "frames": watch.dressing_frames}
	_t.check("planted slow plan: the dressing completes in a later frame, after the worker", complete.done and complete.frames >= 1, "%d frames" % complete.frames)
	_check_frames("quick exit (planted slow plan)", watch, true)
	_check_dressing_fresh("planted slow plan")


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


# SWAP-HITCH-3: freeing stage 1's root also frees its contraptions' cache helper (an Activities
# without setup). At 95053a4b that helper's _exit_tree released the game-wide caches, so the stage
# 2 retry planned its natural surfaces again on the main thread (427 to 455 ms). The caches stay
# until the Game's own Activities leaves the tree.
func _check_caches_survive_exit(helper_id: int) -> void:
	_t.check("stage 1 had a contraption cache helper, freed with its stage", helper_id != 0 and not is_instance_id_valid(helper_id),
		"helper %s" % ("none" if helper_id == 0 else "still live" if is_instance_id_valid(helper_id) else "freed"))
	var natural = load(NATURAL_PATH)
	var key: int = natural.call("_root_key", _game.ctx.terrain, 2)
	_t.check("after stage 1 is freed, stage 2's natural plan is still held for a retry", natural.get("_plans").get(key, {}).has("plan"),
		"key %d, held %s" % [key, str(natural.get("_plans").keys())])
	var park: Dictionary = load(DIRECTOR_PATH).get("_parks").get(_park_id(), {})
	_t.check("after stage 1 is freed, stage 2's director map is still held", not park.get("park", {}).is_empty(), str(park.keys()))
	_t.check("after stage 1 is freed, the dressing's shared rock mesh is still held", _game.presentation.set_dressing.get_script().get("_broken_rock") != null)


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
