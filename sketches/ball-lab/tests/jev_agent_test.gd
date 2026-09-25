extends SceneTree

# JL-13: the Jev agent steers every ball-lab intent to its target, and telemetry writes
# a valid events.ndjson.
#
# Reach: each intent runs from one fixed placement in both physics modes, every trial in
# its own World3D so they all step together, and must reach its target within its
# BUDGETS tick count. The ball is placed at tick 0; the intent and telemetry start
# reading at tick 1 (JL-10 review, N1). A sixth placement pushes the ball into the
# bench's south wall to show stuck detection and the unstick manoeuvre.
#
# Telemetry: every trial's events.ndjson passes JevIO.validate_events, carries a trace
# every 9 ticks and no anomaly; synthetic readings cover the anomalies and the knock
# collapse rule. Trials are written to artifacts/local/jev-agent-test/ unless
# `-- --out=<dir>` names another directory.

const Lab := preload("res://src/lab.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const Field := preload("res://src/field.gd")
const Rules := preload("res://src/ball_rules.gd")
const Intent := preload("res://src/intent.gd")
const BallState := preload("res://src/ball_state.gd")
const JevState := preload("res://src/jev/jev_state.gd")
const JevIO := preload("res://src/jev/jev_io.gd")
const Scenarios := preload("res://src/jev/scenarios.gd")
const JevAgent := preload("res://src/jev/jev_agent.gd")
const Telemetry := preload("res://src/jev/telemetry.gd")

const MODES := [PlayerBall.KINEMATIC, PlayerBall.RIGID]
const TARGET_ENEMY := 0
const EVADE_CLEAR := 15.0
# Ticks at 90 Hz each placement may take, in both modes: 1.5x the slower mode's ticks
# when this was written (push 712, kicker 363, stomp 121, ram 151, evade 250, stuck 124),
# rounded up to a multiple of 30. They are regression guards, not reach criteria
# (JL-13 review, N2). JL-21 moved the ram placement off the shallow kicker and
# re-derived its budget.
const BUDGETS := {
	"push_objective": 1080,
	"hit_kicker": 570,
	"stomp_target": 210,
	"ram_target": 240,
	"evade_hazard": 390,
	"stuck": 210,
}
const INVERSION_LIMIT_DEG := 1.0
# An intent the game cannot credit in one mode is reported here, not hidden: its trial
# still runs to the same budget and must show the agent doing its own part.
const KNOWN_LIMITS := {
	"rigid stomp_target": "rigid reports the dummy contact after the solver has reversed the fall, so player_ball.gd reads v.y > -3 and emits no stomp; the agent must still land on the dummy's head falling faster than 3 m/s",
}
const STOMP_FALL := -3.0


class FakeView:
	extends RefCounted

	var tick := 0
	var tick_hz := 90
	var knocks: Array = []


var _trials := []
var _tick := -1
var _failures := 0
var _out := ""
var _kinds_seen := {}


func _initialize() -> void:
	_out = _out_dir()
	for mode in MODES:
		for name in BUDGETS:
			_trials.append({"mode": mode, "name": name, "holder": _new_lab(), "done": false, "reached_tick": -1})


func _new_lab() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var lab = Lab.new()
	lab.test_mode = true
	viewport.add_child(lab)
	return {"viewport": viewport, "lab": lab}


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _tick < 0:
		for trial in _trials:
			if trial["holder"]["lab"].player == null:
				return false
		_check_kicker_lip(_trials[0]["holder"]["lab"])
		for trial in _trials:
			_place(trial)
		_tick = 0
		return false
	_tick += 1
	var running := 0
	for trial in _trials:
		if trial["done"]:
			continue
		trial["view"].advance()
		trial["fall"] = trial["holder"]["lab"].player.state.velocity.y
		if _tick == 1:
			trial["agent"].hold(trial["intent"], trial["goal"])
			trial["telemetry"].intent_applied(0, trial["intent"])
		trial["telemetry"].step()
		if _reached(trial):
			trial["reached_tick"] = _tick
			_finish_trial(trial)
		elif _tick >= BUDGETS[trial["name"]]:
			_finish_trial(trial)
		else:
			running += 1
	if running > 0:
		return false
	_finish()
	return true


func _place(trial: Dictionary) -> void:
	var lab = trial["holder"]["lab"]
	var placement := _placement(trial["name"])
	lab.player.set_mode(trial["mode"])
	Scenarios.place(lab, placement)
	var agent := JevAgent.new(lab)
	agent.install()
	var view := JevState.new(lab)
	view.attach()
	var dir: String = _out.path_join(PlayerBall.MODE_NAMES[trial["mode"]]).path_join(trial["name"])
	_reset(dir)
	var io := JevIO.new(dir)
	var telemetry := Telemetry.new(view, io, agent)
	telemetry.placed()
	trial.merge({"intent": placement["intent"], "goal": placement["goal"], "agent": agent, "view": view,
		"io": io, "dir": dir, "telemetry": telemetry, "fall": 0.0, "landings": []})
	# A read-only second listener: every dummy contact that should be a stomp.
	lab.player.active_body().enemy_touched.connect(func(enemy: Node3D, normal: Vector3) -> void:
		if normal.y > 0.3 and trial["fall"] < STOMP_FALL:
			trial["landings"].append({"tick": _tick, "enemy": lab.enemies.find(enemy), "fall": trial["fall"]}))


# One fixed placement per intent. The enemy intents all use dummy 0, which starts at
# (18, 30), south-west of the pad; each trial has its own world, so they share it.
func _placement(name: String) -> Dictionary:
	var enemy := {"enemy": TARGET_ENEMY}
	var bench: Vector3 = Scenarios.Geo.bench_point()
	match name:
		"push_objective":
			# On the service ramp's axis 13 m short of its foot; the route climbs it.
			return _spot("push_objective", Field.drop_point(50.0, 44.0), {"point": bench})
		"hit_kicker":
			return _spot("hit_kicker", JevAgent.kicker_frame()["runup"], {})
		"stomp_target":
			return _spot("stomp_target", Field.drop_point(6.0, 30.0), enemy)
		"ram_target":
			# East of the shallow kicker's footprint (x -13..1, z 15..37); inside it the
			# ball started wedged under the box (JL-13 review, N1).
			return _spot("ram_target", Field.drop_point(8.0, 12.0), enemy)
		"evade_hazard":
			return _spot("evade_hazard", Field.drop_point(24.0, 24.0), enemy)
		"stuck":
			# Straight at the bench's south wall with no route: nothing gets over it.
			return _spot("push_objective", Field.drop_point(30.0, 60.0), {"waypoints": [bench]})
	return {}


func _spot(intent: String, spawn: Vector3, goal: Dictionary) -> Dictionary:
	return {"intent": intent, "spawn": spawn, "velocity": Vector3.ZERO, "goal": goal}


func _reached(trial: Dictionary) -> bool:
	var lab = trial["holder"]["lab"]
	var telemetry = trial["telemetry"]
	var at: Vector3 = lab.player.ball_position()
	match trial["name"]:
		"push_objective", "hit_kicker":
			return Scenarios.Geo.on_bench(at, lab.player.state.grounded)
		"stomp_target":
			return _knocked(telemetry, "stomp") or (_known(trial) and _landed(trial))
		"ram_target":
			return _knocked(telemetry, "ram")
		"evade_hazard":
			var enemy: Vector3 = lab.enemies[TARGET_ENEMY].global_position
			return Vector2(at.x - enemy.x, at.z - enemy.z).length() >= EVADE_CLEAR
		"stuck":
			var kinds: Array = telemetry.events.map(func(event): return event["kind"])
			return kinds.has("stuck_begin") and kinds.has("stuck_end")
	return false


func _known(trial: Dictionary) -> bool:
	return KNOWN_LIMITS.has(_key(trial))


func _key(trial: Dictionary) -> String:
	return "%s %s" % [PlayerBall.MODE_NAMES[trial["mode"]], trial["name"]]


func _landed(trial: Dictionary) -> bool:
	return trial["landings"].any(func(landing): return landing["enemy"] == TARGET_ENEMY)


func _knocked(telemetry, kind: String) -> bool:
	return telemetry.knocks.any(func(knock): return knock["enemy"] == TARGET_ENEMY and knock["kind"] == kind)


func _finish_trial(trial: Dictionary) -> void:
	trial["done"] = true
	var lab = trial["holder"]["lab"]
	var at: Vector3 = lab.player.ball_position()
	var telemetry = trial["telemetry"]
	var mode: String = PlayerBall.MODE_NAMES[trial["mode"]]
	var budget: int = BUDGETS[trial["name"]]
	var reached: bool = trial["reached_tick"] >= 0
	var how := "reached"
	if _known(trial) and not _knocked(telemetry, "stomp"):
		how = "KNOWN LIMIT, not credited by the game (%s); landed" % KNOWN_LIMITS[_key(trial)]
		if not trial["landings"].is_empty():
			how += " at tick %d falling %.1f m/s" % [trial["landings"][0]["tick"], trial["landings"][0]["fall"]]
	_report("reach", reached, "%s %s: %s at tick %d of %d, ball at (%.1f, %.1f, %.1f), phase %s, %d raw waves as %d knocks"
		% [mode, trial["name"], how if reached else "not reached", _tick, budget, at.x, at.y, at.z,
		trial["agent"].phase, telemetry.raw_waves, telemetry.knocks.size()])
	var write_errors: Array = trial["io"].write_done("complete", _tick, 0)
	var text := FileAccess.get_file_as_string(trial["dir"].path_join(JevIO.EVENTS_FILE))
	var invalid := JevIO.validate_events(text)
	var counts := {}
	for event in telemetry.events:
		counts[event["kind"]] = counts.get(event["kind"], 0) + 1
		_kinds_seen[event["kind"]] = true
	var traces := 0
	for t in range(1, _tick + 1):
		traces += 1 if t % 9 == 0 else 0
	var lines := text.count("\n")
	var ok: bool = invalid.is_empty() and write_errors.is_empty() and telemetry.errors.is_empty() \
		and lines == telemetry.events.size() and counts.get("trace", 0) == traces and not counts.has("anomaly") \
		and counts.get("knock", 0) == telemetry.knocks.size() and telemetry.raw_waves >= telemetry.knocks.size()
	_report("events", ok, "%s %s: %d lines valid=%s, %d traces of %d expected, kinds %s%s" % [mode, trial["name"], lines,
		str(invalid.is_empty()), counts.get("trace", 0), traces, JSON.stringify(counts),
		"" if invalid.is_empty() else " first error " + JSON.stringify(invalid[0])])
	trial["view"].detach()
	trial["holder"]["viewport"].queue_free()


func _finish() -> void:
	_check_inversion()
	_check_seek()
	_check_synthetic()
	_check_knock_collapse()
	var wanted := ["intent", "trace", "tier", "takeoff", "landing", "knock", "stuck_begin", "stuck_end"]
	var missing := wanted.filter(func(kind): return not _kinds_seen.has(kind))
	_report("kinds", missing.is_empty(), "live trials emitted %s; missing %s" % [", ".join(_kinds_seen.keys()), str(missing)])
	print("jev_agent_test: %s (trials under %s)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _out])
	quit(0 if _failures == 0 else 1)


# stick_for inverts ball_rules.gd wish_direction for every heading and yaw, airborne
# and on flat ground.
func _check_inversion() -> void:
	var worst := 0.0
	var cases := 0
	for yaw in [0.0, 0.7, PI, -2.2, 4.0]:
		var basis := Basis(Vector3.UP, yaw)
		for step in 24:
			var angle := step * TAU / 24.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			for grounded in [false, true]:
				var intent := Intent.new()
				intent.move = JevAgent.stick_for(direction, basis)
				var state := BallState.new()
				state.grounded = grounded
				var wish: Vector3 = Rules.wish_direction(intent, basis, state)
				var error := 180.0 if wish == Vector3.ZERO else rad_to_deg(wish.angle_to(direction))
				worst = maxf(worst, error)
				cases += 1
	_report("inversion", worst <= INVERSION_LIMIT_DEG, "stick_for through wish_direction: worst %.6f deg over %d cases (limit %.1f)"
		% [worst, cases, INVERSION_LIMIT_DEG])


# seek from rest points the wish straight at the target, under the lab's own yaw. The
# agent's per-tick readings are set by hand, as poll() would set them from a lab.
func _check_seek() -> void:
	var worst := 0.0
	var basis := Basis(Vector3.UP, PI)
	for step in 16:
		var angle := step * TAU / 16.0
		var agent := JevAgent.new(null)
		agent._state = BallState.new()
		agent._state.grounded = true
		agent._basis = basis
		agent._at = Vector3(5.0, 1.0, -3.0)
		var point := agent._at + Vector3(cos(angle), 0.4, sin(angle)) * 12.0
		var out := Intent.new()
		var dir: Vector3 = agent.seek(out, point)
		var wish: Vector3 = Rules.wish_direction(out, basis, agent._state)
		var flat := Vector3(point.x - agent._at.x, 0.0, point.z - agent._at.z)
		worst = maxf(worst, rad_to_deg(wish.angle_to(flat)) + rad_to_deg(dir.angle_to(flat)))
	_report("seek", worst <= INVERSION_LIMIT_DEG, "seek(point) from rest: worst wish error %.6f deg over 16 bearings" % worst)


# Every anomaly, edge and trace from readings no live ball should produce.
func _check_synthetic() -> void:
	var dir := _out.path_join("synthetic")
	_reset(dir)
	var telemetry := Telemetry.new(null, JevIO.new(dir))
	var ground := Field.drop_point(30.0, 60.0, 1.0)
	var slow := Vector3(1.0, 0.0, 0.0)
	var readings := [
		[1, ground, slow, true, "walk", false],
		[2, ground, slow, true, "cruise", false],
		[3, ground, slow, false, "cruise", false],
		[4, ground, slow, true, "cruise", false],
		[5, ground, slow, true, "cruise", true],
		[6, ground, slow, true, "cruise", false],
		[7, Vector3(NAN, 0.0, 0.0), slow, true, "cruise", false],
		[8, ground - Vector3(0.0, 2.0, 0.0), slow, true, "cruise", false],
		[9, Vector3(200.0, 100.0, 0.0), slow, true, "cruise", false],
		[10, ground, Vector3(90.0, 0.0, 0.0), true, "blazing", false],
		[11, ground, Vector3(91.0, 0.0, 0.0), true, "blazing", false],
	]
	for r in readings:
		telemetry.record(r[0], r[1], r[2], r[3], r[4], r[5])
	var got := telemetry.events.map(func(e): return e["kind"] + ("/" + e["what"] if e.has("what") else ""))
	var expected := ["tier", "takeoff", "landing", "stuck_begin", "stuck_end", "anomaly/nan", "anomaly/tunnel",
		"anomaly/out_of_bounds", "trace", "tier", "anomaly/overspeed"]
	var errors: Array = telemetry.io.write_done("complete", 11, 0)
	var invalid := JevIO.validate_events(FileAccess.get_file_as_string(dir.path_join(JevIO.EVENTS_FILE)))
	_report("anomalies", got == expected and errors.is_empty() and invalid.is_empty() and telemetry.errors.is_empty(),
		"synthetic readings gave %s" % ", ".join(got))


# One kinematic ram's 45 consecutive waves on one dummy are one knock; a later wave on
# the same dummy past the gap is another; a different dummy's waves never merge.
func _check_knock_collapse() -> void:
	var view := FakeView.new()
	var telemetry := Telemetry.new(view)
	for t in range(10, 55):
		view.knocks.append({"tick": t, "strength": 1.0, "kind": "ram", "enemy": 2})
		if t == 20:
			view.knocks.append({"tick": t, "strength": 0.6, "kind": "stomp", "enemy": 3})
	view.knocks.append({"tick": 54 + Telemetry.KNOCK_GAP_TICKS, "strength": 1.0, "kind": "ram", "enemy": 2})
	view.knocks.append({"tick": 55 + Telemetry.KNOCK_GAP_TICKS * 2, "strength": 0.6, "kind": "stomp", "enemy": 2})
	telemetry.drain_knocks()
	var got := telemetry.knocks.map(func(k): return [k["tick"], k["enemy"], k["kind"], k["waves"]])
	var expected := [[10, 2, "ram", 46], [20, 3, "stomp", 1], [55 + Telemetry.KNOCK_GAP_TICKS * 2, 2, "stomp", 1]]
	_report("knock collapse", got == expected and telemetry.raw_waves == 48 and telemetry.knock_count("ram") == 1,
		"48 waves collapse to %s (gap %d ticks)" % [JSON.stringify(got), Telemetry.KNOCK_GAP_TICKS])
	# JevState's sim block and Scenarios.Run count the same stretches (JL-13 review, N5).
	var state := JevState.new(null)
	state.knocks = view.knocks
	var counts := {}
	for kind in ["stomp", "ram", "other"]:
		counts[kind] = [state.knock_count(kind), telemetry.knock_count(kind)]
	_report("knock count", counts.values().all(func(pair): return pair[0] == pair[1]),
		"JevState vs Telemetry per kind %s" % JSON.stringify(counts))


# The lip jev_agent.gd computes is the built kicker's top far edge.
func _check_kicker_lip(lab) -> void:
	var lip: Vector3 = JevAgent.kicker_frame()["lip"]
	var built := Vector3.INF
	for child in lab.get_children():
		if child is StaticBody3D and child.position.is_equal_approx(Scenarios.STEEP_KICKER):
			for shape in child.get_children():
				if shape is CollisionShape3D and shape.shape is BoxShape3D:
					var size: Vector3 = shape.shape.size
					built = child.transform * Vector3(0.0, size.y * 0.5, size.z * 0.5)
	var offered: Vector3 = JevState.kicker_lip()
	_report("kicker lip", built.distance_to(lip) < 0.001 and built.distance_to(offered) < 0.001,
		"lip (%.2f, %.2f, %.2f), built (%.2f, %.2f, %.2f), JevState's hit_kicker point (%.2f, %.2f, %.2f)"
		% [lip.x, lip.y, lip.z, built.x, built.y, built.z, offered.x, offered.y, offered.z])


func _out_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return ProjectSettings.globalize_path(arg.trim_prefix("--out="))
	return ProjectSettings.globalize_path("res://").path_join("../../artifacts/local/jev-agent-test").simplify_path()


func _reset(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(name))
