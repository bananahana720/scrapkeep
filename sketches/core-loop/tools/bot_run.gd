extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# Headless bot runs for the design feedback loop (DEMO-SPEC). Each seed plays one full
# demo run through a fresh Game.new() with one policy (tools/bot_driver.gd), in play
# (not calm), and leaves behind the real logs the spine writes: runs.ndjson from the
# run log and codex-log.ndjson from the codex. It lives outside tests/ because
# sketch-smoke.mjs runs every tests/*.gd.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd \
#     -- --out=<dir> --policy=skipper|completionist|random [--seeds=1,2,3,4] [--trace=1]
#
# --trace prints the bot's goal and the ball every two game seconds. --fixed-fps 90 makes one frame one physics tick, so runs go faster than real time.
# --stages=N ends the run ("stages_done") once stage N is cleared. --until=N ends each
# run as it enters stage N+1 (outcome "until"). The game reads its lab flags from the
# same args (tuning.gd's FLAGS).
# The game runs in test mode (no keyboard, no mouse capture) and its codex and run log
# are pointed at --out, the way test mode points them at a per-process folder; --out may
# be an absolute path or a user:// path. Next to the spine's two logs the runner writes:
#   bots.ndjson          one line per run: run_id, policy, seed, class, outcome, stage
#                        reached, ticks, game and wall seconds, and per-stage bot notes.
#   codex-entries.json   every declared codex entry (id, category, name, clue), so the
#                        report can name entries no run discovered.
# A run ends at stage-3 clear, death, a "boss" flow state or a stalled stage; a stalled
# or boss run has no spine record (the run log writes only at death and run end), so
# its bots.ndjson line is the only trace. Each seed seeds the global RNG, the run's
# stream and the bot's own streams (bot_driver.gd), and the runner switches the hit-stop
# gates to physics ticks (src/core/sim_clock.gd), so a seed replays the same run on the
# same machine and build, CPU load included. With the wall-clock gates, CPU load changed
# which hit-stops fired and so the physics: seed 1 drifted between runs.

var _settings := {}
var _seeds: Array[int] = []
var _index := -1
var _game
var _driver
var _started_msec := 0
var _out := ""
var _results: Array[Dictionary] = []


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	if not _settings.has("out"):
		printerr("bot_run: usage: -- --out=<dir> --policy=skipper|completionist|random [--seeds=1,2,3,4]")
		quit(2)
		return
	_out = _settings["out"]
	DirAccess.make_dir_recursive_absolute(_out)
	for part in String(_settings.get("seeds", "1")).split(",", false):
		_seeds.append(int(part))
	_next()


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
	seed(_seeds[_index])
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_driver = null


func _physics_process(delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	if _driver == null:
		# Point the codex and the run log at --out; nothing has been written yet.
		_game.codex.storage_dir = _out
		_game.run_log.storage_dir = _out
		_driver = BotDriver.new(_game, String(_settings.get("policy", "skipper")), _seeds[_index])
		_driver.trace = _settings.has("trace")
		_started_msec = Time.get_ticks_msec()
		_driver.start()
		return false
	var over: bool = _driver.tick(delta)
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
	_game.free()
	_game = null
	_next()
	return false


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
