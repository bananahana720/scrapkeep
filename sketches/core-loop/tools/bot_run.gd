extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const BotProfile := preload("res://tools/bot_profile.gd")
const BotAudit := preload("res://tools/bot_audit.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# Headless bot runs for the design feedback loop (DEMO-SPEC). Each seed plays one full
# demo run through a fresh Game.new() with one policy (tools/bot_driver.gd), in play
# (not calm), and leaves behind the real logs the spine writes: runs.ndjson from the
# run log and codex-log.ndjson from the codex. It lives outside tests/ because
# sketch-smoke.mjs runs every tests/*.gd.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd \
#     -- --out=<dir> --policy=skipper|completionist|random [--seeds=1,2,3,4] [--trace=1]
#     [--pilot=<class id>]
#
# --pilot plays that ClassDef id (pylon_engineer, runner_gunner, demolitions_caster, tarn,
# tally, remembered_cannon) whatever the seed; without it the seed picks seed % roster size.
#
# --trace prints the bot's goal and the ball every two game seconds. --trace-ticks=1
# writes full-precision pre-driver snapshots to trace-<seed>.ndjson. --ticks=N caps a
# diagnostic run. --fixed-fps 90 makes one frame one physics tick, faster than real time.
# --bot-profile=1 writes runner/tick timings and sampled Performance monitors.
# --bot-audit=1 writes full-precision committed bus events with stable object tokens.
# --bot-no-mix=1 skips sample arithmetic while retaining music transport.
# --bot-no-pilot-tracks=1 skips pilot bone sampling, retaining playback and signals.
# --bot-no-visuals=1 skips selected unread idle callbacks only
# on the headless display. Camera, HUD, hit-stop and collision work remain active.
# --gate=1 enables all three switches, unless individually overridden with =0.
# --chain-hand=0 turns off the explorer's two-hook hand (bot_driver's control switch).
# --late-offer=take|skip (SG8) turns the tree's late_offer on, has the bot take a random branch at
# each plain offer so depth 4 can open, and answers the take_or_skip offer with that policy;
# bots.ndjson then carries a late_offer row. Without it the bot is unchanged.
# --stages=N ends the run ("stages_done") once stage N is cleared. --until=N ends each
# run as it enters stage N+1 (outcome "until"). The game reads its lab flags from the
# same args (tuning.gd's FLAGS).
# --from-stage=N continues a matching RunStore entrance in --out/entrance.json;
# otherwise it starts normally, then enters stage N for a bounded world run.
# The game runs in test mode (no keyboard, no mouse capture) and its codex and run log
# are pointed at --out, the way test mode points them at a per-process folder; --out may
# be an absolute path or a user:// path. Next to the spine's two logs the runner writes:
#   bots.ndjson          one line per run: run_id, policy, seed, class, outcome, stage
#                        reached, ticks, game and wall seconds, and per-stage bot notes.
#   codex-entries.json   every declared codex entry (id, category, name, clue), so the
#                        report can name entries no run discovered.
# A run ends on run_ended (won or lost), death, stall, or --until/--stages; a stalled
# or missing-boss run has no spine record (the run log writes only at death and run end), so
# its bots.ndjson line is the only trace. Each seed gets a fresh process and data folder,
# seeded RNG streams, spawn-order signs instead of object-ID-dependent choices, a
# completed audio bake, and physics-tick hit-stop gates (src/core/sim_clock.gd).
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


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
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
	if _settings.has("trace-ticks"):
		_tick_trace = FileAccess.open(_out.path_join("trace-%d.ndjson" % _seeds[_index]), FileAccess.WRITE)


func _physics_process(delta: float) -> bool:
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
		_driver = BotDriver.new(_game, String(_settings.get("policy", "skipper")), _seeds[_index])
		if _settings.has("pilot"):
			_driver.class_index = BotDriver.class_index_for(_seeds[_index], String(_settings["pilot"]))
		_driver.trace = _settings.has("trace")
		if _driver.trace:
			_game.events.world_entered.connect(func(world: int): print("  trace world %d entered" % world))
		_driver.chain_hand_enabled = String(_settings.get("chain-hand", "1")) != "0"
		if _settings.has("late-offer"):
			var late := String(_settings["late-offer"])
			if late not in ["take", "skip"]:
				printerr("bot_run: --late-offer must be take or skip")
				quit(2)
				return true
			_driver.late_offer_policy = late
			_driver.tree_policy = "random"
		_game.presentation.audio.bake_now()
		_game.run.run_seed_override = _seeds[_index]
		_started_msec = Time.get_ticks_msec()
		var resume := false
		if _settings.has("from-stage"):
			var entrance: Dictionary = _game.flow.saved_run()
			resume = int(entrance.get("stage", 0)) == int(_settings["from-stage"])
		if _settings.get("bot-audit", "0") == "1":
			_audit = BotAudit.new()
			_audit.setup(_game.events, _driver, _out.path_join("events-%d.ndjson" % _seeds[_index]))
		_bot_options.apply_audio(_game.presentation.audio)
		_driver.start(resume)
		if _settings.has("from-stage") and not resume and int(_settings["from-stage"]) != 1:
			_game.flow.enter_stage(int(_settings["from-stage"]), Vector3.ZERO, false)
		return false
	if _tick_trace != null:
		_tick_trace.store_line(JSON.stringify(_snapshot(delta)))
	var over: bool = _driver.tick(delta)
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
	_game.free()
	if _settings.get("bot-no-pilot-tracks", "0") == "1":
		print("bot_run: %d cosmetic pilot tracks disabled; playback retained" % _bot_options.pilot_tracks_skipped)
	_game = null
	_tick_trace = null
	# Match a fresh process: start the driver before the new camera's first render update.
	Engine.time_scale = 1.0
	_next_pending = true
	return false


static func _vector(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	if "_strafe" in node:
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
	for state in _game.world.events._park_states:
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
		"event_rng": str(_game.world.events.rng.state), "tree_rng": str(_driver._tree_rng.state),
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
	return false
