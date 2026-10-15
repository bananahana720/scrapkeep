# smoke: solo timeout=360s (four fresh game processes on --table=park, timed one after another)
extends SceneTree

# SR14 2026-10-15: quick restart, measured. BIBLE.md:582 and ruling R14 (Andrew's veto list,
# 2026-10-15) set two targets: a retry reaches the first frame that accepts control in at most
# 2.0 s, and a stage exit reaches the next stage's first control frame in at most 6.0 s. This test
# plays the park table (stages 1 and 2) headless in three fresh processes (seeds 11, 12, 13) and
# asserts the medians against the targets. A fourth process replays seed 11: the same seed must give
# the same tick counts, run seed and ball pose at every control frame.
#
# What is timed. The clock starts on the call that triggers the event (flow.retry_stage(), the
# result of holding R past Game.RESTART_HOLD, which the player holds before this clock starts; or
# flow._finish_stage(), the end of the launch flight) and stops at the first physics tick after it
# on which control is accepted: the flow is in play, the ball is not frozen and, on a stage, the
# stage's terrain is built with the ball inside it (in the boss arena, the arena stands in for the
# terrain). The wall time includes every frame the headless loop spends in between; it carries no
# rendering and no draw time. An exit is timed with the next stage already built, as play has it
# (world.gd starts the build when the Warden wakes or the gates open); the build wait is reported
# apart as build_s. Evidence limit: a loaded machine, a GPU or a real display change these numbers;
# the test measures the load path and does not change it.
#
# Why processes. bot_run.gd gives each seed its own process for the same reason: a second game in
# one process finds the first one's caches warm, and a latency probe must see a cold start.
#
#   godot --headless --path sketches/core-loop --script res://tests/restart_latency_test.gd -- --probe=<seed>
#
# prints one "RLPROBE {json}" line and exits; without --probe the test runs the four children.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const RETRY_TARGET_S := 2.0
const EXIT_TARGET_S := 6.0
const SEEDS := [11, 12, 13]
const REPLAY_SEED := 11
const SETTLE_TICKS := 60
const WAIT_TICKS_MAX := 3600
const PROBE_PREFIX := "RLPROBE "
const MEASURES := ["retry_1", "exit_1", "retry_2", "exit_2"]

var _game
var _t := T.new("restart_latency_test")


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe="):
			_probe.call_deferred(int(arg.trim_prefix("--probe=")))
			return
	_parent()


# ---- the parent: four children, then the checks ----

func _parent() -> void:
	print("restart_latency_test: machine load at start (1 min) %s" % FileAccess.get_file_as_string("/proc/loadavg").split(" ")[0])
	var runs: Array[Dictionary] = []
	for seed_value in SEEDS + [REPLAY_SEED]:
		runs.append(_run_child(seed_value))
	_t.eq("four probe runs reported", runs.filter(func(r): return not r.is_empty()).size(), 4)
	if runs.any(func(r): return r.is_empty()):
		quit(_t.verdict())
		return
	for i in 3:
		var r: Dictionary = runs[i]
		print("restart_latency_test: seed %d run_seed %d start %.2f s (%d ticks)" % [r["seed"], r["run_seed"], r["start"]["wall_s"], r["start"]["ticks"]])
	_t.check("the control detector refuses a frozen ball", runs.all(func(r): return r["frozen_refused"]), "positive control")
	_t.check("the control detector accepts the ball again", runs.all(func(r): return r["thawed_accepted"]), "positive control")
	for name in MEASURES:
		var walls: Array[float] = []
		var capped := 0
		for i in 3:
			var m: Dictionary = runs[i][name]
			walls.append(m["wall_s"])
			if m["ticks"] >= WAIT_TICKS_MAX:
				capped += 1
			print("restart_latency_test: %s seed %d: %.3f s, %d ticks, call %.1f ms, terrain use %.1f ms, build wait %.2f s, stage %d, %s"
				% [name, runs[i]["seed"], m["wall_s"], m["ticks"], m["call_us"] / 1000.0, m["use_us"] / 1000.0, m.get("build_s", 0.0), m["stage"], m["state"]])
		walls.sort()
		var median: float = walls[1]
		var target: float = RETRY_TARGET_S if name.begins_with("retry") else EXIT_TARGET_S
		print("restart_latency_test: %s median %.3f s max %.3f s (target %.1f s)" % [name, median, walls[2], target])
		_t.eq("%s reached control within %d ticks in all runs" % [name, WAIT_TICKS_MAX], capped, 0)
		_t.check("%s median under %.1f s" % [name, target], median <= target, "median %.3f s, max %.3f s" % [median, walls[2]])
	# Where each event lands. Stage 2 closes world 1, so its exit is the Brindle arena entry, not a stage 3 build.
	for i in 3:
		var r: Dictionary = runs[i]
		var tag := "seed %d" % r["seed"]
		_t.eq("%s retry_1 stays on stage 1" % tag, r["retry_1"]["stage"], 1)
		_t.eq("%s exit_1 lands on stage 2" % tag, r["exit_1"]["stage"], 2)
		_t.eq("%s retry_2 stays on stage 2" % tag, r["retry_2"]["stage"], 2)
		_t.check("%s exit_2 enters the Brindle arena" % tag, r["exit_2"]["arena"] == true, "state %s" % r["exit_2"]["state"])
	_replay(runs)
	quit(_t.verdict())


func _replay(runs: Array[Dictionary]) -> void:
	var first: Dictionary = runs[0]
	var again: Dictionary = runs[3]
	_t.eq("a replayed seed gives the same run seed", again["run_seed"], first["run_seed"])
	_t.check("a different seed gives a different run seed", first["run_seed"] != runs[1]["run_seed"], "control for the equality above")
	for name in ["start"] + MEASURES:
		var a: Dictionary = first[name]
		var b: Dictionary = again[name]
		_t.eq("%s replays the same ticks to control" % name, b["ticks"], a["ticks"])
		_t.eq("%s replays the same stage" % name, b["stage"], a["stage"])
		_t.eq("%s replays the ball pose at the control frame" % name, [b["pos"], b["vel"]], [a["pos"], a["vel"]])


func _run_child(seed_value: int) -> Dictionary:
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/restart_latency_test.gd", "--", "--probe=%d" % seed_value])
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	for chunk in output:
		for line in String(chunk).split("\n", false):
			if line.begins_with(PROBE_PREFIX):
				var parsed = JSON.parse_string(line.trim_prefix(PROBE_PREFIX))
				if parsed is Dictionary:
					return parsed
	print("restart_latency_test: probe seed %d produced no result (exit %d)" % [seed_value, code])
	return {}


# ---- the child: one fresh game, four timed events ----

func _probe(seed_value: int) -> void:
	# The replay setup bot_run.gd uses: physics-tick hit-stop gates, a seeded global RNG, a finished audio bake.
	SimClock.ticks = true
	seed(seed_value)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await physics_frame
	await physics_frame
	_game.presentation.audio.bake_now()
	_game.run.run_seed_override = seed_value
	_game.player.source = Intent.Scripted.new()
	var out := {"seed": seed_value}
	out["start"] = await _timed(func():
		_game.flow.press_start()
		_game.flow.choose_class(0), 1)
	out["run_seed"] = _game.run.run_seed
	await _ticks(SETTLE_TICKS)
	_game.player.set_frozen(true)
	out["frozen_refused"] = not _control()
	_game.player.set_frozen(false)
	out["thawed_accepted"] = _control()
	out["retry_1"] = await _timed(func(): _game.flow.retry_stage(), 1)
	await _ticks(SETTLE_TICKS)
	out["exit_1"] = await _exit(2)
	await _ticks(SETTLE_TICKS)
	out["retry_2"] = await _timed(func(): _game.flow.retry_stage(), 2)
	await _ticks(SETTLE_TICKS)
	out["exit_2"] = await _exit(3)
	out["exit_2"]["arena"] = _game.flow.in_arena
	print(PROBE_PREFIX + JSON.stringify(out))
	_game.queue_free()
	await physics_frame
	quit(0)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


# Builds the next stage the way play does, timing the wait, then exits the current one. A world's
# last stage exits into the arena instead.
func _exit(next_stage: int) -> Dictionary:
	var build_s := 0.0
	var terrain = _game.ctx.terrain
	# Stage 2 closes world 1: its exit goes to the Warden's arena (flow.enter_boss), which has no terrain build.
	if not _game.ctx.stages.is_world_last(_game.flow.stage()):
		var b0 := Time.get_ticks_usec()
		terrain.prepare(next_stage)
		var waited := 0
		while not terrain.is_ready(next_stage) and waited < WAIT_TICKS_MAX:
			await physics_frame
			waited += 1
		build_s = (Time.get_ticks_usec() - b0) / 1e6
	# The build wait lasts a different number of ticks each run (worker threads), and the ball moves
	# through them, so the ball is put back on a fixed pose before the exit: the replay then compares
	# the exit's own path, not the wait's length.
	var here: int = _game.flow.stage()
	_game.player.reset_to(terrain.spawn_point(here) + Vector3.UP * 2.0, Vector3(0.0, 0.0, 6.0))
	await _ticks(2)
	var m: Dictionary = await _timed(func(): _game.flow._finish_stage(), next_stage)
	m["build_s"] = build_s
	return m


# Triggers an event, then counts physics ticks until the first one that accepts control.
func _timed(trigger: Callable, _stage_after: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	trigger.call()
	var call_us := Time.get_ticks_usec() - t0
	var ticks := 0
	while ticks < WAIT_TICKS_MAX:
		await physics_frame
		ticks += 1
		if _control():
			break
	var ball: Vector3 = _game.player.ball_position()
	return {"call_us": call_us, "ticks": ticks, "wall_s": (Time.get_ticks_usec() - t0) / 1e6,
		"use_us": _game.ctx.terrain.last_use_usec, "stage": _game.flow.stage(), "state": _game.flow.state_name(),
		"pos": var_to_bytes(ball).hex_encode(), "vel": var_to_bytes(_game.player.body().linear_velocity).hex_encode()}


# True when this tick accepts control.
func _control() -> bool:
	var flow = _game.flow
	if not flow.in_play() or _game.player.frozen():
		return false
	if flow.in_arena:
		return true
	var terrain = _game.ctx.terrain
	return terrain.is_ready(flow.stage()) and terrain.contains(_game.player.ball_position())
