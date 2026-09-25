extends SceneTree

# The Godot runner for one Jev Lab trial on Spillway Drop (JL-27; ball-lab's
# jev_run.gd is the reference and the tick contract is the same:
# tools/jev-player/protocol/PROTOCOL.md). It lives outside tests/ because
# sketch-smoke.mjs runs every tests/*.gd.
#
#   godot --headless --fixed-fps 90 --path sketches/spillway-drop --script res://src/jev/jev_run.gd \
#     -- --io=<dir> --scenario=<id> [--seed=N] [--mode=kinematic|rigid] [--snapshot-every=D]
#     [--hold-ticks=k] [--intent-timeout-s=S] [--max-ticks=N] [--time-limit-s=L]
#
# The stage is built with test_mode (no keyboard, HUD or screens) and `seed_override`
# set to --seed, so the scrap layout, the director and every stage roll follow the trial
# seed; hello.json reports that seed. `--fixed-fps 90` makes one frame one physics tick.
# Every D ticks it writes a state; it keeps flying the held intent for k ticks, then
# blocks inside _physics_process (OS.delay_msec, never tree.paused) until the intent
# arrives, and applies it at exactly t + k. It ends when the scenario succeeds, times
# out or the ball dies (EV-0555), or at --max-ticks. Exit codes: 0 done, 1 internal, 4 intent_invalid,
# 5 intent_timeout. The last stdout lines are the scenario's own result as
# `jev_run: scenario {json}`, which harness.mjs records, and a summary.

const Stage := preload("res://src/stage.gd")

var _trial
var _stage
var _frames := 0
var _counting := false


func _initialize() -> void:
	var settings := Trial.parse_args(OS.get_cmdline_user_args())
	if settings.has("usage"):
		printerr("jev_run: %s" % settings["usage"])
		if not settings.has("io"):
			quit(Trial.EXIT["internal"])
			return
	_stage = Stage.new()
	_stage.test_mode = true
	_stage.seed_override = maxi(0, int(settings.get("seed", Trial.DEFAULTS["seed"])))
	root.add_child(_stage)
	_trial = Trial.new(_stage, settings)


func _physics_process(_delta: float) -> bool:
	if _trial == null or _trial.outcome != "":
		return false
	if not _trial.started:
		if _stage.player == null:
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
	_stage.queue_free()
	quit(_trial.exit_code)


class Trial:
	extends RefCounted

	const PlayerBall := preload("res://src/player_ball.gd")
	const JevIO := preload("res://src/jev/jev_io.gd")
	const JevState := preload("res://src/jev/jev_state.gd")
	const JevAgent := preload("res://src/jev/jev_agent.gd")
	const Telemetry := preload("res://src/jev/telemetry.gd")
	const Scenarios := preload("res://src/jev/scenarios.gd")

	const SKETCH := "spillway-drop"
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

	var stage
	var settings: Dictionary
	var io
	var view
	var agent
	var telemetry
	var run
	var on_wait := Callable()

	var started := false
	var outcome := ""
	var exit_code := -1
	var snapshots := 0
	var applied := 0
	var blocked := 0
	# Applied intents by id, for the scenario result.
	var held_counts := {}
	# Choice counts for the stage metrics (scripts/lab/metrics/spillway.mjs), which see
	# only the scenario line: snapshots offering two or more options after the gate
	# (jev_io.gd offered_options, decide.mjs's gate), and every option offered and kept
	# by id.
	var multi := 0
	var offered_counts := {}
	var kept_counts := {}

	var _held = null
	var _pending := {}
	var _placed := false

	func _init(stage_ref, settings_ref: Dictionary) -> void:
		stage = stage_ref
		settings = DEFAULTS.duplicate()
		settings.merge(settings_ref, true)
		if settings.has("io"):
			io = JevIO.new(settings["io"])

	static func parse_args(args: PackedStringArray) -> Dictionary:
		var out := {}
		var numbers := ["seed", "snapshot-every", "hold-ticks", "intent-timeout-s", "max-ticks", "time-limit-s"]
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
			elif key in ["io", "scenario", "mode"]:
				out[key] = value
			else:
				out["usage"] = "unknown option --%s" % key
		if not out.has("io"):
			out["usage"] = "--io=<dir> is required"
		return out

	# Places the ball and writes hello.json. The trial's tick 0 is the next frame, so
	# every reading and the first hold() come at least one physics tick after place().
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
		if settings["time_limit_s"] > 0:
			scenario["time_limit_s"] = float(settings["time_limit_s"])
		seed(settings["seed"])
		stage.player.set_mode(mode)
		Scenarios.place(stage, scenario, settings["seed"])
		run = Scenarios.Run.new(scenario, Engine.physics_ticks_per_second)
		view = JevState.new(stage, run)
		view.attach()
		agent = JevAgent.new(stage, view)
		agent.install()
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
			_count_choice(state["jev"])
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
			_stop("internal", seq, t, "spillway-drop cannot execute %s" % id)
			return false
		if waited:
			blocked += 1
		agent.hold(id, _goal(id))
		telemetry.intent_applied(seq, id)
		_held = id
		_pending = {}
		applied += 1
		held_counts[id] = int(held_counts.get(id, 0)) + 1
		return true

	func _count_choice(jev: Dictionary) -> void:
		var kept: Array = JevIO.offered_options(jev)
		if kept.size() >= 2:
			multi += 1
		for option in jev["options"]:
			offered_counts[option["id"]] = int(offered_counts.get(option["id"], 0)) + 1
		for id in kept:
			kept_counts[id] = int(kept_counts.get(id, 0)) + 1

	func _goal(id: String) -> Dictionary:
		if id == "push_objective" or id == "hit_kicker":
			return {"point": run.objective(view)["point"]}
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

	# The scenario's own judgement for the harness's batch record; done.json is closed.
	# Knocks are Telemetry's collapsed contact stretches.
	func scenario_result() -> Dictionary:
		var progress: Dictionary = run.progress
		return {
			"id": run.scenario["label"],
			"result": run.result(),
			"end": run.end(),
			"epoch": Scenarios.EPOCH,
			"threat_rule": JevState.THREAT_RULE,
			"snapshots": snapshots,
			"multi": multi,
			"offered": offered_counts,
			"kept": kept_counts,
			"success_tick": run.success_tick,
			"limit_ticks": progress["limit_ticks"],
			"tick": view_tick(),
			"knocks": {"stomp": telemetry.knock_count("stomp"), "ram": telemetry.knock_count("ram")},
			"knocked": progress["knocked"],
			"route": progress["route"],
			"route_tick": progress["route_tick"],
			"corridors": progress["corridors"],
			"hp_min": snappedf(progress["hp_min"], 0.1),
			"damage": snappedf(progress["damage"], 0.1),
			"dead_tick": progress["dead_tick"],
			"submerged_ticks": progress["submerged_ticks"],
			"caught": progress["caught"],
			"hatch_open_tick": progress["hatch_open_tick"],
			"scrap": progress["scrap"],
			"anomalies": progress["anomalies"].size(),
			"held": held_counts,
			"applied": applied,
			"blocked": blocked,
		}

	func summary() -> String:
		var result: String = run.result() if run != null else "not started"
		var knocks: String = "stomp %d ram %d" % [telemetry.knock_count("stomp"), telemetry.knock_count("ram")] if telemetry != null else "none"
		return "%s %s seed %s: %s at tick %d, scenario %s, %d snapshots, knocks %s, blocked %d of %d intents" % [
			settings.get("scenario", "?"), settings["mode"], settings["seed"], outcome, view_tick(), result,
			snapshots, knocks, blocked, applied]
