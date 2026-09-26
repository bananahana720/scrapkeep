extends SceneTree

# The Godot runner for one Jev Lab trial (plan section 2, "Runner" and "Timing";
# tools/jev-player/protocol/PROTOCOL.md). It lives outside tests/ because
# sketch-smoke.mjs runs every tests/*.gd.
#
#   godot --headless --fixed-fps 90 --path sketches/ball-lab --script res://src/jev/jev_run.gd \
#     -- --io=<dir> --scenario=<id> [--seed=N] [--mode=kinematic|rigid] [--snapshot-every=D]
#     [--hold-ticks=k] [--intent-timeout-s=S] [--max-ticks=N] [--time-limit-s=L]
#
# `--fixed-fps 90` makes one frame one physics tick, so a run goes faster than real
# time and the summary line's frame count equals its tick count. The trial counts
# ticks from the frame after the ball is placed. Every D ticks it writes a state; it
# keeps flying the held intent for k ticks, then blocks inside _physics_process
# (OS.delay_msec, never tree.paused, which would pause Jolt) until the intent for that
# state arrives, and applies it at exactly t + k. It ends when the scenario succeeds
# or times out, or at --max-ticks. Exit codes follow PROTOCOL.md: 0 done, 1 internal,
# 4 intent_invalid, 5 intent_timeout. --time-limit-s replaces the scenario's own time
# limit, for JL-21's calibration probes past it. The last stdout lines are the
# scenario's own result as `jev_run: scenario {json}`, which harness.mjs records, and
# a summary.
#
# Trial holds the whole contract so tests/jev_bridge_test.gd can run it on a lab of
# its own; this SceneTree only parses the arguments and owns the process.
#
# Watch mode (JL-31, `scrapkeep lab watch`): with --watch=<dir> the runner also adds
# watch_overlay.gd, which draws each decision from <dir>'s side files, and on the end
# holds the last frame for a few seconds before quitting. --marks=<file>,
# --shots=<tick,...> and --mark-at=<tick> go to the overlay. Without --watch nothing
# here changes: the overlay is never loaded and the trial is the same.

const Lab := preload("res://src/lab.gd")

var _trial
var _lab
var _overlay
var _frames := 0
var _counting := false


func _initialize() -> void:
	var settings := Trial.parse_args(OS.get_cmdline_user_args())
	if settings.has("usage"):
		printerr("jev_run: %s" % settings["usage"])
		if not settings.has("io"):
			quit(Trial.EXIT["internal"])
			return
	_lab = Lab.new()
	_lab.test_mode = true
	root.add_child(_lab)
	_trial = Trial.new(_lab, settings)
	if settings.has("watch"):
		_overlay = load("res://src/jev/watch_overlay.gd").new()
		root.add_child(_overlay)
		_overlay.setup(_trial, settings)


func _physics_process(_delta: float) -> bool:
	if _trial == null or _trial.outcome != "":
		return false
	if not _trial.started:
		if _lab.player == null:
			return false
		if not _trial.begin():
			_end()
		return false
	_counting = true
	if _trial.tick():
		_end()
	return false


func _process(_delta: float) -> bool:
	if _counting and _trial.outcome == "":
		_frames += 1
	return false


func _end() -> void:
	if _trial.run != null:
		print("jev_run: scenario %s" % JSON.stringify(_trial.scenario_result()))
	print("jev_run: %s; %d frames, %d ticks" % [_trial.summary(), _frames, _trial.view_tick()])
	_trial.close()
	if _overlay != null:
		_overlay.finish()
		_lab.process_mode = Node.PROCESS_MODE_DISABLED
		var code: int = _trial.exit_code
		create_timer(_overlay.LINGER_S).timeout.connect(func() -> void:
			_lab.queue_free()
			quit(code))
		return
	_lab.queue_free()
	quit(_trial.exit_code)


class Trial:
	extends RefCounted

	const PlayerBall := preload("res://src/player_ball.gd")
	const JevIO := preload("res://src/jev/jev_io.gd")
	const JevState := preload("res://src/jev/jev_state.gd")
	const JevAgent := preload("res://src/jev/jev_agent.gd")
	const Telemetry := preload("res://src/jev/telemetry.gd")
	const Scenarios := preload("res://src/jev/scenarios.gd")

	const SKETCH := "ball-lab"
	# Protocol v1's schedule (PROTOCOL.md, hello.json).
	const DEFAULTS := {
		"seed": 0,
		"mode": "kinematic",
		"snapshot_every": 90,
		"hold_ticks": 26,
		"intent_timeout_s": 30,
		"max_ticks": 0,
		"time_limit_s": 0,
	}
	const EXIT := {"complete": 0, "aborted": 0, "internal": 1, "intent_invalid": 4, "intent_timeout": 5}
	const POLL_MS := 2

	var lab
	var settings: Dictionary
	var io
	var view
	var agent
	var telemetry
	var run
	# While the trial blocks for an intent this is called with the seq on every poll.
	# The runner leaves it empty; a test answers through it.
	var on_wait := Callable()

	var started := false
	# "" while running, then complete, aborted or an error.json code.
	var outcome := ""
	var exit_code := -1
	var snapshots := 0
	var applied := 0
	# Intents that were not there at t + k, so the trial had to wait for them.
	var blocked := 0

	var _held = null
	var _pending := {}
	var _placed := false

	func _init(lab_ref, settings_ref: Dictionary) -> void:
		lab = lab_ref
		settings = DEFAULTS.duplicate()
		settings.merge(settings_ref, true)
		if settings.has("io"):
			io = JevIO.new(settings["io"])

	# `--key=value` user arguments. A malformed one leaves `usage` set.
	static func parse_args(args: PackedStringArray) -> Dictionary:
		var out := {}
		var numbers := ["seed", "snapshot-every", "hold-ticks", "intent-timeout-s", "max-ticks", "time-limit-s",
			"mark-at"]
		for arg in args:
			var at := arg.find("=")
			if not arg.begins_with("--") or at < 0:
				out["usage"] = "unexpected argument %s" % arg
				continue
			var key := arg.substr(2, at - 2)
			var value := arg.substr(at + 1)
			if numbers.has(key):
				if not value.is_valid_int():
					out["usage"] = "--%s must be a whole number, got %s" % [key, value]
					continue
				out[key.replace("-", "_")] = value.to_int()
			elif key in ["io", "scenario", "mode", "watch", "marks", "shots"]:
				out[key] = value
			else:
				out["usage"] = "unknown option --%s" % key
		if not out.has("io"):
			out["usage"] = "--io=<dir> is required"
		return out

	# Places the ball and writes hello.json. The ball is placed on this frame and the
	# trial's tick 0 is the next one, so every reading and the first hold() come at
	# least one physics tick after Scenarios.place() (JL-10 review, N1).
	func begin() -> bool:
		started = true
		if io == null:
			return _stop("internal", null, 0, "no io directory")
		if settings.has("usage"):
			return _stop("internal", null, 0, settings["usage"])
		var mode: int = PlayerBall.MODE_NAMES.find(settings["mode"])
		var scenario := Scenarios.make(str(settings.get("scenario", "")))
		var every: int = settings["snapshot_every"]
		var hold: int = settings["hold_ticks"]
		if mode < 0:
			return _stop("internal", null, 0, "unknown physics mode %s" % settings["mode"])
		if scenario.is_empty():
			return _stop("internal", null, 0, "unknown scenario %s" % settings.get("scenario", ""))
		if every < 1 or hold < 0 or hold >= every or settings["intent_timeout_s"] < 1 or settings["max_ticks"] < 0 \
				or settings["time_limit_s"] < 0:
			return _stop("internal", null, 0, "bad schedule D=%d k=%d timeout %d s limit %d s" % [every, hold,
				settings["intent_timeout_s"], settings["time_limit_s"]])
		seed(settings["seed"])
		lab.player.set_mode(mode)
		Scenarios.place(lab, scenario, settings["seed"])
		# After place(), which sets the mode's limit, so an override always wins.
		if settings["time_limit_s"] > 0:
			scenario["time_limit_s"] = float(settings["time_limit_s"])
		agent = JevAgent.new(lab)
		agent.install()
		run = Scenarios.Run.new(scenario, Engine.physics_ticks_per_second)
		view = JevState.new(lab, run)
		view.attach()
		telemetry = Telemetry.new(view, io, agent)
		var errors: Array = io.write_hello({
			"sketch": SKETCH,
			"scenario": settings["scenario"],
			"seed": settings["seed"],
			"physics_mode": settings["mode"],
			"godot": Engine.get_version_info()["string"],
			"tick_hz": Engine.physics_ticks_per_second,
			"snapshot_every": every,
			"hold_ticks": hold,
			"intent_timeout_s": settings["intent_timeout_s"],
		})
		if not errors.is_empty():
			return _stop("internal", null, 0, "hello.json: %s" % JSON.stringify(errors[0]))
		return true

	# One physics tick, called before any node's _physics_process. Returns true once
	# the trial has ended and its last file is written.
	func tick() -> bool:
		if outcome != "":
			return true
		if not _placed:
			_placed = true
			telemetry.placed()
		else:
			view.advance()
		var t: int = view.tick
		var every: int = settings["snapshot_every"]
		# The end is judged before a state falls due, so none is written once the trial
		# has ended (JL-17 review, N1). An intent due this tick still applies: its state
		# was written while the trial ran, and PROTOCOL.md needs its intent event.
		var limit: int = settings["max_ticks"]
		var ended: bool = run.result() != "running" or (limit > 0 and t >= limit)
		if not ended and t % every == 0:
			if _abort_seen():
				return _done("aborted")
			var state := {"seq": t / every, "tick": t, "held": _held}
			state.merge(view.snapshot())
			var errors: Array = io.write_state(state)
			if not errors.is_empty():
				_stop("internal", state["seq"], t, "state: %s" % JSON.stringify(errors[0]))
				return true
			_pending = state
			snapshots += 1
		if not _pending.is_empty() and t == int(_pending["tick"]) + int(settings["hold_ticks"]):
			if not _apply():
				return true
		telemetry.step()
		if not telemetry.errors.is_empty():
			_stop("internal", null, t, "events: %s" % JSON.stringify(telemetry.errors[0]))
			return true
		if ended:
			return _done("complete")
		return false

	# Blocks until intent-<seq> arrives, abort.json appears or the timeout passes.
	func _apply() -> bool:
		var seq: int = _pending["seq"]
		var t: int = view.tick
		var started_ms := Time.get_ticks_msec()
		var limit_ms: int = int(settings["intent_timeout_s"]) * 1000
		var waited := false
		var read: Dictionary = io.read_intent(seq, _pending)
		while read.status == JevIO.Read.ABSENT:
			if _abort_seen():
				_done("aborted")
				return false
			if Time.get_ticks_msec() - started_ms >= limit_ms:
				_stop("intent_timeout", seq, t, "no intent-%06d.json %d s after blocking" % [seq, settings["intent_timeout_s"]])
				return false
			waited = true
			if on_wait.is_valid():
				on_wait.call(seq)
			OS.delay_msec(POLL_MS)
			read = io.read_intent(seq, _pending)
		if read.status == JevIO.Read.INVALID:
			var first: Dictionary = read.errors[0]
			_stop("intent_invalid", seq, t, "%s %s" % [first.path, first.message])
			return false
		var id: String = read.message["intent"]
		if not JevAgent.INTENTS.has(id):
			_stop("internal", seq, t, "ball-lab cannot execute %s" % id)
			return false
		if waited:
			blocked += 1
		agent.hold(id, _goal(id))
		telemetry.intent_applied(seq, id)
		_held = id
		_pending = {}
		applied += 1
		return true

	# The objective's point for a push. Stomp and ram act on the threat the state
	# offered them for, its nearest (jev_state.gd options()), so never on a knocked
	# dummy; if that one was knocked before the intent applied, on the nearest threat
	# now, and on none (-1) if there is none. Evade keeps the agent's own pick.
	func _goal(id: String) -> Dictionary:
		if id == "push_objective":
			return {"point": run.objective(view)["point"]}
		if id == "stomp_target" or id == "ram_target":
			var reported: Array = _pending["sim"]["threat_ids"]
			var target: int = reported[0] if not reported.is_empty() else -1
			if target < 0 or view.knocked_enemies().has(target):
				var now: Array = view.threat_indices()
				target = now[0] if not now.is_empty() else -1
			return {"enemy": target}
		return {}

	func _abort_seen() -> bool:
		return io.read_abort().status != JevIO.Read.ABSENT

	func _done(reason: String) -> bool:
		var errors: Array = io.write_done(reason, view_tick(), snapshots)
		if not errors.is_empty():
			printerr("jev_run: done.json: %s" % JSON.stringify(errors[0]))
			outcome = "internal"
			exit_code = EXIT["internal"]
			return true
		outcome = reason
		exit_code = EXIT[reason]
		return true

	# Writes error.json. Returns false, so begin() can return it as "ended".
	func _stop(code: String, seq: Variant, t: int, text: String) -> bool:
		printerr("jev_run: %s: %s" % [code, text])
		outcome = code
		exit_code = EXIT[code]
		if io != null:
			var errors: Array = io.write_error(code, seq, t, text)
			if not errors.is_empty():
				printerr("jev_run: error.json: %s" % JSON.stringify(errors[0]))
		return false

	func view_tick() -> int:
		return view.tick if view != null else 0

	func close() -> void:
		if view != null:
			view.detach()

	# The scenario's own judgement, for the harness's batch record (JL-17 review, N2).
	# PROTOCOL.md's done.json is closed, so this travels on stdout as one JSON line.
	func scenario_result() -> Dictionary:
		var progress: Dictionary = run.progress
		return {
			"id": run.scenario["label"],
			"result": run.result(),
			"success_tick": run.success_tick,
			"limit_ticks": progress["limit_ticks"],
			"tick": view_tick(),
			"knocks": {"stomp": telemetry.knock_count("stomp"), "ram": telemetry.knock_count("ram")},
			"knocked": progress["knocked"].size(),
			"gates": progress["gates"],
			"route": progress["route"],
			"bench_tick": progress["bench_tick"],
			"lip": progress["lip"],
			"anomalies": progress["anomalies"].size(),
			"applied": applied,
			"blocked": blocked,
		}

	# Knocks are Telemetry's collapsed contact stretches, not JevState's raw waves
	# (JL-13 review).
	func summary() -> String:
		var result: String = run.result() if run != null else "not started"
		var knocks: String = "stomp %d ram %d" % [telemetry.knock_count("stomp"), telemetry.knock_count("ram")] if telemetry != null else "none"
		return "%s %s seed %s: %s at tick %d, scenario %s, %d snapshots, knocks %s, blocked %d of %d intents" % [
			settings.get("scenario", "?"), settings["mode"], settings["seed"], outcome, view_tick(), result,
			snapshots, knocks, blocked, applied]
