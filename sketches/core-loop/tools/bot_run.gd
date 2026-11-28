extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const BotProfile := preload("res://tools/bot_profile.gd")
const BotAudit := preload("res://tools/bot_audit.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const StageBeats := preload("res://src/core/stage_beats.gd")
const SignalTimer := preload("res://tools/signal_timer.gd")
const PhysicsProbe := preload("res://tools/physics_probe.gd")
const FrameSplit := preload("res://tools/frame_split.gd")
const BotPlants := preload("res://tools/bot_plants.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const QaWatch := preload("res://tools/qa_watch.gd")


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
var _struck: Array = []
var _scrap_serial := 0
var _counter_serial := 0
var _bot_options
var _allocation_noise: Array[RefCounted] = []
var _beats
var _frame_log: FileAccess
var _frame_usec := 0
var _ticks := 0
var _draw_began := 0
var _draw_ended := 0
var _frame_index := 0
var _signal_timer
var _physics_probe
var _frame_split
var _inject_ms := 0
var _inject_at := 0
var _plants
var _qa


func _initialize() -> void:
	_settings = _parse(OS.get_cmdline_user_args())
	SimClock.ticks = _settings.get("wall-clock", "0") != "1"
	SimClock.threaded_in_bot_runs = _settings.get("threaded-stages", "0") == "1"
	StageLocks.active = _settings.get("locks", "1") != "0"
	_bot_options = BotOptions.new(_settings, self)
	BotProfile.enabled = _settings.get("bot-profile", "0") == "1"
	if BotProfile.enabled:
		root.add_child(BotProfile.EndMarker.new(BotProfile))
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


func _run_children() -> void:
	var forwarded := PackedStringArray(["--out=" + _out])
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--seeds=") and not arg.begins_with("--out="):
			forwarded.append(arg)
	for i in _seeds.size():
		var state_dir := _out.path_join("state-%d" % i)
		for dir_name in ["data", "config", "cache"]:
			DirAccess.make_dir_recursive_absolute(state_dir.path_join(dir_name))
		var env_args := PackedStringArray([
			"XDG_DATA_HOME=" + state_dir.path_join("data"),
			"XDG_CONFIG_HOME=" + state_dir.path_join("config"),
			"XDG_CACHE_HOME=" + state_dir.path_join("cache"),
		])
		if OS.get_name() == "macOS":
			env_args.append("HOME=" + state_dir.path_join("data"))
		var args := PackedStringArray(env_args)
		args.append_array(PackedStringArray([OS.get_executable_path(), "--headless", "--fixed-fps", "90", "--path",
			ProjectSettings.globalize_path("res://"), "--script", "res://tools/bot_run.gd", "--"]))
		args.append_array(forwarded)
		args.append("--seeds=%d" % _seeds[i])
		var output := []
		var code := OS.execute("env", args, output, true)
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
	Engine.time_scale = 1.0
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
		var director_mode := String(_settings.get("director", "interval"))
		if director_mode not in ["interval", "credit"]:
			printerr("bot_run: --director must be interval or credit")
			quit(2)
			return true
		var select_director := func(_stage: int, _retry: bool): _game.world.director.mode = director_mode
		_game.events.stage_entered.connect(select_director)
		_game.world.director.mode = director_mode
		_game.codex.storage_dir = _out
		_game.run_log.storage_dir = _out
		_game.run_moments.storage_dir = _out
		_driver = BotDriver.new(_game, String(_settings.get("policy", "skipper")), _seeds[_index])
		if _settings.has("pilot"):
			_driver.class_index = BotDriver.class_index_for(_seeds[_index], String(_settings["pilot"]))
		if _settings.has("band"):
			_driver.band = SkillBand.make(String(_settings["band"]), int(_settings.get("attempt", "1")), _seeds[_index])
		if _tick_trace != null:
			_struck.clear()
			_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float):
				_struck.append([enemy.get("kind"), _vector(enemy.global_position), kind, force]))
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
			MusicPrebake.prepare_rest()
			_game.presentation.audio.engine.warm_stingers = true
		_game.run.run_seed_override = _seeds[_index]
		var run_tier := int(_settings.get("run-tier", "0"))
		if run_tier != 0:
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
	if not over and _settings.has("until") and _game.run.stage > int(_settings["until"]):
		_driver._end("until")
		over = true
	if not over:
		return false
	var wall := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	var record: Dictionary = _driver.record(wall)
	_beats.finish()
	record["beats"] = StageBeats.within(_beats.rows, int(_settings.get("stages", _settings.get("until", "0"))))
	if _settings.has("comic-page") and not _game.run.over:
		_game.flow._end_run(false)
	record["comic_panels"] = (_game.run_moments.last_page.get("panels", []) as Array).size()
	record["comic_page"] = _game.run_moments.saved_path()
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
	Engine.time_scale = 1.0
	_next_pending = true
	return false


static func _vector(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
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
	var director = _game.world.events
	for state in (director._park_states if director != null else []):
		events.append({"id": state.row.id, "phase": state.phase, "due": state.due_s,
			"ready": state.ready_s, "elapsed": state.live_elapsed_s, "holding": state.holding})
	var struck := _struck.duplicate()
	_struck.clear()
	return {"tick": _driver.ticks + 1, "delta": delta, "struck": struck, "flow": _game.flow.state_name(),
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
