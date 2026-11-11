extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const BotProfile := preload("res://tools/bot_profile.gd")
const BotAudit := preload("res://tools/bot_audit.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Terrain := preload("res://src/world/terrain.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const StageBeats := preload("res://src/core/stage_beats.gd")
const SignalTimer := preload("res://tools/signal_timer.gd")
const PhysicsProbe := preload("res://tools/physics_probe.gd")
const FrameSplit := preload("res://tools/frame_split.gd")
const BotPlants := preload("res://tools/bot_plants.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const QaWatch := preload("res://tools/qa_watch.gd")

# Headless bot runs for the design feedback loop (DEMO-SPEC). Each seed plays one full
# demo run through a fresh Game.new() with one policy (tools/bot_driver.gd), in play
# (not calm), and leaves behind the real logs the spine writes: runs.ndjson from the
# run log and codex-log.ndjson from the codex. It lives outside tests/ because
# sketch-smoke.mjs runs every tests/*.gd.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd \
#     -- --out=<dir> --policy=skipper|completionist|random [--seeds=1,2,3,4] [--trace=1]
#     [--pilot=<class id>] [--band=novice|learner|expert] [--attempt=N]
#
# --pilot plays that ClassDef id (pylon_engineer, runner_gunner, demolitions_caster, tarn,
# tally, remembered_cannon) whatever the seed; without it the seed picks seed % roster size.
#
# --band plays the driver at a skill band (tools/skill_band.gd: slower reactions, missed tells and
# a smaller kit below Expert); --attempt=N (default 1) is the attempt number a Learner has reached.
# Without --band the driver is unchanged. Multi-seed children are forwarded every flag.
#
# --trace prints the bot's goal and the ball every two game seconds. --trace-ticks=1
# writes full-precision pre-driver snapshots to trace-<seed>.ndjson. --ticks=N caps a
# diagnostic run. --fixed-fps 90 makes one frame one physics tick, faster than real time.
# --comic-page=1 ends a run cut short as a loss so it folds a comic page (run_moments.gd); with a
# rendering display (not --headless) the panels carry real stills.
# --bot-profile=1 writes runner/tick timings and sampled Performance monitors.
# --bot-audit=1 writes full-precision committed bus events with stable object tokens.
# --bot-no-mix=1 skips sample arithmetic while retaining music transport.
# --bot-no-pilot-tracks=1 skips pilot bone sampling, retaining playback and signals.
# --bot-no-visuals=1 skips selected unread idle callbacks and a park stage's render regions
# (park_terrain.gd draw_regions), only on the headless display. Camera, HUD, hit-stop and
# collision work remain active.
# --plant=name=value[,name=value] (test only, the anti-kiting gates' controls): pack_damage=K, damage=K, packs_passive=1,
# hide_pack_telegraphs=1, rut=K, fast_tax=K, ringless=K (tools/bot_plants.gd). Absent, the run is unchanged. --policy=orbit|terrain are the gates' arms (bot_kite.gd).
# --gate=1 enables all three switches, unless individually overridden with =0.
# --chain-hand=0 turns off the explorer's two-hook hand (bot_driver's control switch).
# --late-offer=take|skip (SG8) turns the tree's late_offer on, has the bot take a random branch at
# each plain offer so depth 4 can open, and answers the take_or_skip offer with that policy;
# bots.ndjson then carries a late_offer row. Without it the bot is unchanged.
# --relay-stake=<0..4> (SR10) has the skipper stake the park relay (src/world/hold_relay.gd
# set_stakes) once, before it rolls into the ring, work the relay to its pay, then go on to the
# Warden; the stage row in bots.ndjson carries relay_stakes [{stage, k, ...}]. 0 or absent leaves
# the bot byte-identical. Only the park table builds a relay (stages 1 and 5).
# --explore-by=<s> (pacing lab, scripts/pacing-check.mjs) lets the completionist roll optional content
# until stage second s instead of ENGAGE_BY (140), and stretches the stall cap by the same amount, so
# a park can be measured longer than the default explorer stays. Absent, the bot is unchanged.
# --run-tier=N (the HARD ladder lab, scripts/challenge/run.mjs --tier) picks run tier N on the start card as stage 1
# opens, without the first_win unlock (which would also open the secrets). With --from-stage the run takes tier N
# as that stage opens instead, over whatever tier the entrance kept (a lab override; the start card is past).
# Absent or 0, the run is unchanged; the row gains "run_tier".
# --panel-log=1 adds panel_kills (the build's kill_log: stage, kind, elite, rib, jackpot, dropped,
# yard; a yard lock crew's kill has yard true, a cleared yard is a yard_clear row)
# and panels (the run's pickups in order) to the bots.ndjson row.
# --stages=N ends the run ("stages_done") once stage N is cleared. --until=N ends each
# run as it enters stage N+1 (outcome "until"). The game reads its lab flags from the
# same args (tuning.gd's FLAGS).
# --from-stage=N continues a matching RunStore entrance in --out/entrance.json;
# otherwise it starts normally, then enters stage N for a bounded world run.
# Frame-time probes (stage-entry and mid-stage freezes; a bot run plays the legacy maps unless it
# passes --table=park, which a launched game plays):
# --wall-clock=1 leaves SimClock on the wall clock, as in a played game: park stages build on
# worker threads and hit-stop reads real time, so the seed no longer replays exactly.
# --threaded-stages=1 builds park stages on worker threads as --wall-clock=1 does, frees a left stage
# over the next frames, and reads later-world enemy scripts on the loader thread at stage entry, as a
# played game does, but keeps the hit-stop clock on physics ticks: for frame captures, where the next
# stage's one-frame build on the engage frame is a bot artifact. The seed no longer replays exactly.
# --warm-band=1 renders the band's other themes, keys and boss tracks (MusicEngine.prepare_rest) before
# the run, as a played run does on a worker behind stage 1. Without it each chord, note and riser
# renders on the main thread the first time a bar asks, 60 to 300 ms a frame that play never has.
# It also renders each queued stinger on a worker before its beat, as a played run does. Use it
# for frame captures and hitch hunts; the seed still replays exactly.
# --frame-log=1 writes frames-<seed>.ndjson: each frame's wall ms, stage and flow state; that ms split
# into idle_ms (the scene's _process), draw_ms (the RenderingServer's draw) and tick_ms (the physics
# ticks after it, ticks of them), timed per frame; Performance's process and physics times, which are
# each the slowest of the last second and update once a second, so they name no frame; the node,
# resource and object counts; the renderer's draw calls and
# objects in frame; video, texture and buffer memory (MB, totals, so an upload is a step between
# rows); and the five pipeline compilation counters ("pipelines": canvas, mesh, surface, draw,
# specialization), running totals whose difference from the previous row is that frame's compiles,
# so a frame that compiles pipelines or uploads a stage's buffers shows which (scrapkeep#241 row 28).
# The pipeline counters exist on the RenderingDevice renderers only and read 0 under Compatibility.
# --entry-profile=1 writes entry-<seed>.ndjson: every GameEvents handler's main-thread ms by
# frame (tools/signal_timer.gd), signals under 5 ms a frame dropped. It slows the run about 2.5x.
# --physics-probe=1 writes physics-<seed>.ndjson: for each physics tick over 100 ms, the Game
# children (and --probe-under=<child,...>'s children) that spent it (tools/physics_probe.gd).
# --frame-split=1 adds the parts of each --frame-log row's ms (tools/frame_split.gd): node physics
# and node _process time, the bot driver's own tick (bot_ms) and net_ms, the frame without that tick.
# The rest of the ms is the engine's own work. =2 also keeps a bracket-by-bracket events list with
# on-CPU time on frames over 40 ms. The bot's climb planner is bot_ms: 60 to 85 ms every 6 s
# while a stalled bot sits below its gate, which is the 6 s GATES hitch; read GATES frames by net_ms.
# --physics-hz=N sets the physics tick rate (the project's 90 stays when absent): a hitch whose period
# follows the tick count moves with it, one on a wall clock does not.
# --inject-ms=N sleeps N ms every 6 s of wall time outside the driver's tick: a planted frame cost
# for the net_ms read of a --frame-split frame log (the control that a game-side hitch still shows).
# --locks=0 turns off the Spillway's Warden gate and arena lock (src/world/stage_locks.gd), so one
# binary measures the pacing they add.
# --qa-log=1 writes qa-<seed>.ndjson (tools/qa_watch.gd): where the ball sat stuck, rested off the ground,
# wedged on a wall or fell through, and each objective text once per stage; the row gains "qa" counts.
# --unshaded=1 draws the root viewport unshaded, so a render cost can be told apart from the lights
# and shadows (for frame captures: it changes the picture).
# The game runs in test mode (no keyboard, no mouse capture) and its codex and run log
# are pointed at --out, the way test mode points them at a per-process folder; --out may
# be an absolute path or a user:// path. Next to the spine's two logs the runner writes:
#   bots.ndjson          one line per run: run_id, policy, seed, class, outcome, stage
#                        reached, ticks, game and wall seconds, per-stage bot notes (pockets_drawn
#                        names the pockets that stage drew by library id: [] for none, as on the
#                        legacy maps, and null when the run ended before the stage was played), and the
#                        beats column (src/core/stage_beats.gd): per stage entered, the physics
#                        ticks of arrive, loot, find, hold, fight and leave and whether it exited.
#   scrapbook/           the run-end comic page (src/core/run_moments.gd) of a run that ended:
#                        <run_id>.json and its stills <run_id>_<i>.png.
#   codex-entries.json   every declared codex entry (id, category, name, clue), so the
#                        report can name entries no run discovered.
# A run ends on run_ended (won or lost), death, stall, or --until/--stages; a stalled
# or missing-boss run has no spine record (the run log writes only at death and run end), so
# its bots.ndjson line is the only trace. Each seed gets a fresh process and data folder,
# seeded RNG streams, spawn-order signs instead of object-ID-dependent choices, a
# completed audio bake (stage 1's band too, as a player gets behind the title), and
# physics-tick hit-stop gates (src/core/sim_clock.gd).
# Replay evidence is specific to the checked machine, build, policy and table.

var _audit
var _settings := {}
var _seeds: Array[int] = []
var _index := -1
var _next_pending := false
var _game
var _driver
var _started_msec := 0
var _out := ""
var _results: Array[Dictionary] = []
var _tick_trace: FileAccess
var _scrap_serial := 0
var _counter_serial := 0
var _bot_options
var _allocation_noise: Array[RefCounted] = []
var _beats
var _frame_log: FileAccess
var _frame_usec := 0
# The frame log's own split of a frame (Performance's process and physics times are each the slowest of the last
# second, updated once a second, so they name no frame): the physics ticks since the last draw, and when the
# RenderingServer began and ended that draw.
var _ticks := 0
var _draw_began := 0
var _draw_ended := 0
var _frame_index := 0
var _signal_timer
var _physics_probe
var _frame_split
var _inject_ms := 0
var _inject_at := 0
# The test-only plants of --plant= (tools/bot_plants.gd); null, and untouched, without the flag.
var _plants
var _qa


func _initialize() -> void:
	_settings = _parse(OS.get_cmdline_user_args())
	SimClock.ticks = _settings.get("wall-clock", "0") != "1"
	Terrain.threaded_in_bot_runs = _settings.get("threaded-stages", "0") == "1"
	StageLocks.active = _settings.get("locks", "1") != "0"
	_bot_options = BotOptions.new(_settings, self)
	BotProfile.enabled = _settings.get("bot-profile", "0") == "1"
	if BotProfile.enabled:
		root.add_child(BotProfile.EndMarker.new(BotProfile))
	# The repeat test perturbs object IDs without touching policy, seed or physics.
	for i in int(_settings.get("allocation-noise", "0")):
		_allocation_noise.append(RefCounted.new())
	node_added.connect(_on_node_added)
	if not _settings.has("out"):
		printerr("bot_run: usage: -- --out=<dir> --policy=skipper|completionist|random [--seeds=1,2,3,4] [--pilot=<class id>]")
		quit(2)
		return
	if _settings.has("pilot") and (String(_settings["pilot"]) == "" or BotDriver.class_index_for(0, String(_settings["pilot"])) < 0):
		printerr("bot_run: unknown --pilot=%s; use pylon_engineer, runner_gunner, demolitions_caster, tarn, tally or remembered_cannon" % _settings["pilot"])
		quit(2)
		return
	if BotOptions.relay_stake(_settings) < 0:
		printerr("bot_run: --relay-stake=%s is out of range; use a whole number 0 to 4" % _settings["relay-stake"])
		quit(2)
		return
	if BotOptions.explore_by(_settings) < 0.0:
		printerr("bot_run: --explore-by=%s must be a number of seconds above %d" % [_settings["explore-by"], int(BotDriver.ENGAGE_BY)])
		quit(2)
		return
	if _settings.has("band") and String(_settings["band"]) not in SkillBand.BANDS:
		printerr("bot_run: unknown --band=%s; use novice, learner or expert" % _settings["band"])
		quit(2)
		return
	if _settings.has("attempt") and int(_settings["attempt"]) < 1:
		printerr("bot_run: --attempt must be 1 or more")
		quit(2)
		return
	if _settings.has("run-tier") and (not String(_settings["run-tier"]).is_valid_int() or int(_settings["run-tier"]) < RunTier.BASE
			or int(_settings["run-tier"]) > RunTier.TOP):
		printerr("bot_run: --run-tier=%s must be a whole number %d to %d" % [_settings["run-tier"], RunTier.BASE, RunTier.TOP])
		quit(2)
		return
	if _settings.has("plant") and BotPlants.parse(String(_settings["plant"])).has("error"):
		printerr("bot_run: --plant: %s" % BotPlants.parse(String(_settings["plant"]))["error"])
		quit(2)
		return
	_out = _absolute(_settings["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	for part in String(_settings.get("seeds", "1")).split(",", false):
		_seeds.append(int(part))
	if _seeds.size() > 1:
		_run_children()
		return
	_next()


# A fresh physics server and presentation caches for every seed, including list runs.
func _run_children() -> void:
	# Each child has its own data folder, so --out goes to it as an absolute path the parent resolved.
	var forwarded := PackedStringArray(["--out=" + _out])
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--seeds=") and not arg.begins_with("--out="):
			forwarded.append(arg)
	for i in _seeds.size():
		var previous := {}
		var state_dir := _out.path_join("state-%d" % i)
		for kind in ["DATA", "CONFIG", "CACHE"]:
			var key: String = "XDG_%s_HOME" % kind
			previous[key] = OS.get_environment(key)
			OS.set_environment(key, state_dir.path_join(kind.to_lower()))
		var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path",
			ProjectSettings.globalize_path("res://"), "--script", "res://tools/bot_run.gd", "--"])
		args.append_array(forwarded)
		args.append("--seeds=%d" % _seeds[i])
		var output := []
		var code := OS.execute(OS.get_executable_path(), args, output, true)
		for key in previous:
			if previous[key].is_empty():
				OS.unset_environment(key)
			else:
				OS.set_environment(key, previous[key])
		for chunk in output:
			print(String(chunk).strip_edges())
		if code != 0:
			quit(code)
			return
	var rows := FileAccess.get_file_as_string(_out.path_join("bots.ndjson")).split("\n", false).size()
	if rows < _seeds.size():
		printerr("bot_run: %d child run(s) but %d row(s) in %s" % [_seeds.size(), rows, _out.path_join("bots.ndjson")])
		quit(1)
		return
	print("bot_run: %d isolated run(s) written to %s" % [_seeds.size(), _out])
	quit(0)


# res:// and user:// resolve in this process; a relative path resolves against the working folder.
static func _absolute(path: String) -> String:
	var global := ProjectSettings.globalize_path(path)
	if global.is_absolute_path():
		return global
	return OS.get_environment("PWD").path_join(global)


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			var key := arg.substr(2, arg.find("=") - 2)
			out[key] = arg.substr(arg.find("=") + 1)
	return out


func _next() -> void:
	_index += 1
	if _index >= _seeds.size():
		_finish()
		return
	# A hit-stop cut short by the previous game's free would leave time slowed.
	Engine.time_scale = 1.0
	# Freeing Game leaves the viewport's Jolt space and its body allocation history alive.
	# Keep the old world alive until the viewport has detached its rendering scenario.
	var _previous_world := root.world_3d
	root.world_3d = World3D.new()
	_scrap_serial = 0
	_counter_serial = 0
	seed(_seeds[_index])
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = _out.path_join("entrance.json")
	root.add_child(_game)
	_driver = null
	if _settings.get("frame-log", "0") == "1":
		_frame_log = FileAccess.open(_out.path_join("frames-%d.ndjson" % _seeds[_index]), FileAccess.WRITE)
		_frame_usec = 0
		_frame_index = 0
		_ticks = 0
		if not RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
			RenderingServer.frame_pre_draw.connect(_on_pre_draw)
			RenderingServer.frame_post_draw.connect(_on_post_draw)
	if _settings.has("trace-ticks"):
		_tick_trace = FileAccess.open(_out.path_join("trace-%d.ndjson" % _seeds[_index]), FileAccess.WRITE)


func _on_pre_draw() -> void:
	_draw_began = Time.get_ticks_usec()


func _on_post_draw() -> void:
	_draw_ended = Time.get_ticks_usec()


func _physics_process(delta: float) -> bool:
	_ticks += 1
	if _next_pending:
		_next_pending = false
		_next()
	if BotProfile.enabled:
		BotProfile.begin_tick()
	var _bot_scope = BotProfile.scope("bot_driver")
	if _game == null or _game.flow == null:
		return false
	if _driver == null:
		# --director=interval|credit follows every fresh stage director, including retries.
		var director_mode := String(_settings.get("director", "interval"))
		if director_mode not in ["interval", "credit"]:
			printerr("bot_run: --director must be interval or credit")
			quit(2)
			return true
		var select_director := func(_stage: int, _retry: bool): _game.world.director.mode = director_mode
		_game.events.stage_entered.connect(select_director)
		_game.world.director.mode = director_mode
		# Point the codex and the run log at --out; nothing has been written yet.
		_game.codex.storage_dir = _out
		_game.run_log.storage_dir = _out
		_game.run_moments.storage_dir = _out
		_driver = BotDriver.new(_game, String(_settings.get("policy", "skipper")), _seeds[_index])
		if _settings.has("pilot"):
			_driver.class_index = BotDriver.class_index_for(_seeds[_index], String(_settings["pilot"]))
		if _settings.has("band"):
			_driver.band = SkillBand.make(String(_settings["band"]), int(_settings.get("attempt", "1")), _seeds[_index])
		_driver.trace = _settings.has("trace")
		if _driver.trace:
			_game.events.world_entered.connect(func(world: int): print("  trace world %d entered" % world))
		_driver.relay_stake = BotOptions.relay_stake(_settings)
		var explore_by := BotOptions.explore_by(_settings)
		if explore_by > 0.0:
			_driver.engage_by = explore_by
		_driver.chain_hand_enabled = String(_settings.get("chain-hand", "1")) != "0"
		if _settings.has("late-offer"):
			var late := String(_settings["late-offer"])
			if late not in ["take", "skip"]:
				printerr("bot_run: --late-offer must be take or skip")
				quit(2)
				return true
			_driver.late_offer_policy = late
			_driver.tree_policy = "random"
		if _settings.has("plant"):
			_plants = BotPlants.new()
			_plants.attach(_game, _driver, BotPlants.parse(String(_settings["plant"])))
		_game.presentation.audio.bake_opening_now()
		if _settings.get("warm-band", "0") == "1":
			MusicEngine.prepare_rest()
			_game.presentation.audio.engine.warm_stingers = true
		_game.run.run_seed_override = _seeds[_index]
		var run_tier := int(_settings.get("run-tier", "0"))
		if run_tier != 0:
			# Deferred: the flow is in its stage state only once stage_entered has returned.
			var choose := func():
				if not _game.flow.choose_run_tier(run_tier, false):
					printerr("bot_run: run tier %d refused on stage 1" % run_tier)
					quit(2)
			var from_stage := int(_settings.get("from-stage", "0"))
			var pick_tier := func(stage: int, retry: bool):
				if retry:
					return
				if from_stage > 1 and stage == from_stage:
					_game.run.lab_run_tier(run_tier)
					if _game.build != null:
						_game.build.recompute()
				elif from_stage <= 1 and stage == 1:
					choose.call_deferred()
			_game.events.stage_entered.connect(pick_tier)
		_started_msec = Time.get_ticks_msec()
		var resume := false
		if _settings.has("from-stage"):
			var entrance: Dictionary = _game.flow.saved_run()
			resume = int(entrance.get("stage", 0)) == int(_settings["from-stage"])
		if _settings.get("bot-audit", "0") == "1":
			_audit = BotAudit.new()
			_audit.setup(_game.events, _driver, _out.path_join("events-%d.ndjson" % _seeds[_index]))
		_bot_options.apply_audio(_game.presentation.audio)
		_beats = StageBeats.Recorder.new(_game.events, _game.flow)
		if _settings.get("entry-profile", "0") == "1":
			_signal_timer = SignalTimer.new()
			var names := []
			for row in _game.events.get_script().get_script_signal_list():
				names.append(row.name)
			_signal_timer.time_signals(_game.events, names)
		if _settings.has("physics-hz"):
			Engine.physics_ticks_per_second = int(_settings["physics-hz"])
		if _settings.get("unshaded", "0") == "1":
			root.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
		if _settings.get("frame-split", "0") in ["1", "2"]:
			_frame_split = FrameSplit.new()
			_frame_split.watch(self, _settings["frame-split"] == "2")
		_inject_ms = int(_settings.get("inject-ms", "0"))
		if _settings.get("physics-probe", "0") == "1":
			_physics_probe = PhysicsProbe.new()
			var parents := [_game]
			for name in String(_settings.get("probe-under", "")).split(",", false):
				var node: Node = _game.get_node_or_null(name)
				if node != null:
					parents.append(node)
			_physics_probe.watch(self, parents)
		if _settings.get("qa-log", "0") == "1":
			_qa = QaWatch.new()
			_qa.setup(_game, _driver, _out.path_join("qa-%d.ndjson" % _seeds[_index]))
		_driver.start(resume)
		if _settings.has("from-stage") and not resume and int(_settings["from-stage"]) != 1:
			_game.flow.enter_stage(int(_settings["from-stage"]), Vector3.ZERO, false)
		return false
	if _tick_trace != null:
		_tick_trace.store_line(JSON.stringify(_snapshot(delta)))
	_beats.step()
	if _plants != null:
		_plants.step()
	var tick_start := Time.get_ticks_usec()
	var over: bool = _driver.tick(delta)
	if _qa != null:
		_qa.step(delta)
		if _driver.ticks % 90 == 0:
			_qa.read_text()
	if _frame_split != null:
		_frame_split.add_bot(Time.get_ticks_usec() - tick_start)
	if _inject_ms > 0 and Time.get_ticks_msec() - _inject_at >= 6000:
		_inject_at = Time.get_ticks_msec()
		OS.delay_msec(_inject_ms)
	if not over and _settings.has("ticks") and _driver.ticks >= int(_settings["ticks"]):
		_driver._end("ticks_done")
		over = true
	if not over and _settings.has("stages") and _game.run.stage > int(_settings["stages"]):
		_driver._end("stages_done")
		over = true
	# --until=N ends a run as it enters stage N+1.
	if not over and _settings.has("until") and _game.run.stage > int(_settings["until"]):
		_driver._end("until")
		over = true
	if not over:
		return false
	var wall := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	var record: Dictionary = _driver.record(wall)
	_beats.finish()
	# --stages=N and --until=N end the run a tick or two into the next stage; that sliver is not an attempt.
	record["beats"] = StageBeats.within(_beats.rows, int(_settings.get("stages", _settings.get("until", "0"))))
	# --comic-page=1 folds a comic page from a run cut short (--ticks, --until, a stall) as a
	# loss, so a short rendered run can show its stills.
	if _settings.has("comic-page") and not _game.run.over:
		_game.flow._end_run(false)
	# The run-end comic page (run_moments.gd): its panel count and where it was saved.
	record["comic_panels"] = (_game.run_moments.last_page.get("panels", []) as Array).size()
	record["comic_page"] = _game.run_moments.saved_path()
	# --panel-log=1: the grey panels' recorded kill stream and what the run picked up, for
	# tests/panels_drop_sim_test.gd's fixtures.
	if _settings.has("panel-log"):
		record["panel_kills"] = _game.build.kill_log.duplicate()
		record["panels"] = Array(_game.run.panels)
	if _qa != null:
		record["qa"] = _qa.counts.duplicate()
		_qa = null
	if _settings.has("plant"):
		record["plant"] = String(_settings["plant"])
	if int(_settings.get("run-tier", "0")) != 0:
		record["run_tier"] = _game.run.selected_run_tier()
	_results.append(record)
	_game.codex.append_line(_out.path_join("bots.ndjson"), JSON.stringify(record))
	_write_entries()
	print("bot_run: %s seed %d (%s) -> %s at stage %d, %d ticks (%.1f s game), %.1f s wall"
		% [record["policy"], record["seed"], record["class"], record["outcome"], record["stage_reached"],
			record["ticks"], record["game_seconds"], wall])
	if BotProfile.enabled:
		_bot_scope = null
		BotProfile.finish(_out.path_join("profile-%d.json" % _seeds[_index]))
	_audit = null
	if _signal_timer != null:
		_signal_timer.flush()
		var file := FileAccess.open(_out.path_join("entry-%d.ndjson" % _seeds[_index]), FileAccess.WRITE)
		for row in _signal_timer.rows:
			file.store_line(JSON.stringify(row))
		_signal_timer = null
	if _physics_probe != null:
		var file := FileAccess.open(_out.path_join("physics-%d.ndjson" % _seeds[_index]), FileAccess.WRITE)
		for row in _physics_probe.rows:
			file.store_line(JSON.stringify(row))
		_physics_probe = null
	_game.free()
	if _settings.get("bot-no-pilot-tracks", "0") == "1":
		print("bot_run: %d cosmetic pilot tracks disabled; playback retained" % _bot_options.pilot_tracks_skipped)
	_game = null
	_plants = null
	_tick_trace = null
	_frame_log = null
	# Match a fresh process: start the driver before the new camera's first render update.
	Engine.time_scale = 1.0
	_next_pending = true
	return false


static func _vector(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	# A body the warm stands out of sight (BakeWarm.spawn_holder) is no spawn: counting it gave every
	# later unit the other side whenever the warm's list changed length (10 November 2026).
	var stood: bool = node.get_parent() != null and node.get_parent().has_meta("spawn_warm")
	if "_strafe" in node and not stood:
		node.set_meta("bot_strafe", 1.0 if (_counter_serial + _seeds[_index]) % 2 == 0 else -1.0)
		_counter_serial += 1
	if node.get_parent() == _game.build.scrap:
		node.set_meta("bot_side", 1.0 if (_scrap_serial + _seeds[_index]) % 2 == 0 else -1.0)
		_scrap_serial += 1


func _snapshot(delta: float) -> Dictionary:
	var enemies := []
	for enemy in get_nodes_in_group("enemy"):
		if enemy is Node3D and is_instance_valid(enemy):
			enemies.append({"kind": enemy.get("kind"), "position": _vector(enemy.global_position),
				"hp": enemy.get("hp"), "strafe": enemy.get("_strafe") if "_strafe" in enemy else null})
	var caught := []
	for item in _game.build.scrap._caught:
		caught.append({"position": _vector(item.global_position), "side": _game.build.scrap._caught[item]})
	var field = _game.build.scrap
	var items := []
	for item in field._items:
		items.append([_vector(item.global_position), field._caught.get(item),
			field._value.get(item), field._age.get(item), field._cogs.get(item)])
	var events := []
	# world.gd holds no event director between stages (its events is null from a stage's end to the next entry).
	var director = _game.world.events
	for state in (director._park_states if director != null else []):
		events.append({"id": state.row.id, "phase": state.phase, "due": state.due_s,
			"ready": state.ready_s, "elapsed": state.live_elapsed_s, "holding": state.holding})
	return {"tick": _driver.ticks + 1, "delta": delta, "flow": _game.flow.state_name(),
		"stage": _game.run.stage, "stage_time": _game.run.stage_time, "paused": paused,
		"scale": Engine.time_scale, "position": _vector(_game.player.ball_position()),
		"velocity": _vector(_game.player.body().linear_velocity), "hp": _game.run.hp,
		"mass": _game.run.mass, "heft": _game.run.heft(), "scrap": _game.run.scrap, "caught": caught,
		"field": items, "field_columns": ["position", "caught", "value", "age", "cogs"],
		"events": events, "music_clock": _game.presentation.audio.engine.clock,
		"bot_rng": str(_driver.rng.state), "run_rng": str(_game.ctx.rng.state),
		"loot_rng": str(_game.build.loot_rng.state), "director_rng": str(_game.world.director._rng.state),
		"event_rng": str(director.rng.state) if director != null else null, "tree_rng": str(_driver._tree_rng.state),
		"camera_rng": str(_game.camera._shake_rng.state),
		"aim_origin": _vector(_game.ctx.aim_origin()), "aim_forward": _vector(_game.ctx.aim_forward()),
		"yaw": _game.camera.yaw, "pitch": _game.camera.pitch, "enemies": enemies}


func _write_entries() -> void:
	var list := []
	for entry in _game.codex.entries():
		list.append({"id": entry["id"], "category": entry["category"], "name": entry["name"], "clue": entry["clue"]})
	var file := FileAccess.open(_out.path_join("codex-entries.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(list, "  "))
		file.close()


func _finish() -> void:
	var total := 0.0
	for r in _results:
		total += float(r["wall_seconds"])
	print("bot_run: %d run(s) written to %s, %.1f s wall in runs" % [_results.size(), ProjectSettings.globalize_path(_out), total])
	quit(0)


func _process(_delta: float) -> bool:
	if BotProfile.enabled:
		BotProfile.idle_begin()
	if _frame_log != null and _game != null and _game.run != null:
		var now := Time.get_ticks_usec()
		if _frame_usec > 0:
			# The row's ms runs from the last _process to this one: that idle step, the draw after it, then this frame's
			# physics ticks. A headless run draws nothing, so there the idle and draw split is null.
			var drew := _draw_began > _frame_usec and _draw_ended >= _draw_began
			var row := {"f": _frame_index, "ms": (now - _frame_usec) / 1000.0, "stage": _game.run.stage, "state": _game.flow.state,
				"idle_ms": (_draw_began - _frame_usec) / 1000.0 if drew else null, "draw_ms": (_draw_ended - _draw_began) / 1000.0 if drew else null,
				"tick_ms": (now - (_draw_ended if drew else _frame_usec)) / 1000.0, "ticks": _ticks,
				"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
				"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
				"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "drawn": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, "texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
				"buffer_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
				"pipelines": [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
					Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
					Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]}
			if _frame_split != null:
				row.merge(_frame_split.take(row["ms"]))
				var ball = _game.player.body() if _game.player != null else null
				if ball != null:
					var at: Vector3 = ball.global_position
					row["ball"] = [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1), snappedf(ball.linear_velocity.length(), 0.1)]
			_frame_log.store_line(JSON.stringify(row))
		_frame_usec = now
		_frame_index += 1
		_ticks = 0
	if _signal_timer != null:
		_signal_timer.flush()
		_signal_timer.frame = _frame_index
	if _physics_probe != null:
		_physics_probe.frame = _frame_index
	return false
