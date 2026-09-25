extends SceneTree

# JL-10: the Jev state exporter reads a running lab without changing it, and the
# ball-lab scenarios are well formed.
#
# Identity: for each physics mode three labs run the same scripted sequence for 900
# physics ticks, each in its own World3D so they step together: baseline A with no
# exporter, one with the exporter attached and snapshotting every tick, and baseline B
# with no exporter. Ball and dummy positions and velocities must match bit for bit;
# A against B measures the mode's own reproducibility first. A fourth lab, the
# control, gets one deliberate 1 mm/s nudge and must be reported as different.
#
# Set JEV_STATE_DUMP=<dir> to write the exporter's states (every 90 ticks) as protocol
# state files for protocol.mjs to validate.

const Lab := preload("res://src/lab.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const Field := preload("res://src/field.gd")
const JevState := preload("res://src/jev/jev_state.gd")
const Scenarios := preload("res://src/jev/scenarios.gd")

const TICKS := 900
const PLACE_TICKS := 45
const SNAPSHOT_EVERY := 90
const RAM_TICK := 270
const RAM_SPEED := 24.0
const MODES := [PlayerBall.KINEMATIC, PlayerBall.RIGID]
# `control` writes one 1 mm/s velocity nudge at CONTROL_TICK: the comparison must see it.
const VARIANTS := ["baseline_a", "exported", "baseline_b", "control"]
const CONTROL_TICK := 450


class ScriptedSource:
	extends RefCounted

	var move := Vector2.ZERO
	var jump := false
	var boost := false
	var brake := false

	func poll(out) -> void:
		out.clear()
		out.move = move
		out.jump_pressed = jump
		out.boost_pressed = boost
		out.brake_held = brake
		jump = false
		boost = false


var _identity := []
var _placed := []
var _tick := -1
var _failures := 0
var _dump := ""
var _check_errors := 0
var _snapshots := 0


func _initialize() -> void:
	_dump = OS.get_environment("JEV_STATE_DUMP")
	for mode in MODES:
		for variant in VARIANTS:
			_identity.append({"mode": mode, "variant": variant, "holder": _new_lab(), "trace": []})
	var placements := Scenarios.all()
	placements.append(Scenarios.make("kicker-gap@14"))
	placements.append(Scenarios.make("kicker-gap@28"))
	for scenario in placements:
		_placed.append({"scenario": scenario, "holder": _new_lab()})


# Each lab gets its own World3D, so its physics space is its own.
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
		for run in _identity + _placed:
			if run["holder"]["lab"].player == null:
				return false
		_start()
		_tick = 0
		return false
	_tick += 1
	for run in _identity:
		_step_identity(run)
	if _tick <= PLACE_TICKS:
		for run in _placed:
			run["view"].advance()
		if _tick == PLACE_TICKS:
			_check_placements()
	if _tick < TICKS:
		return false
	_finish()
	return true


func _start() -> void:
	for run in _identity:
		var lab = run["holder"]["lab"]
		var source := ScriptedSource.new()
		run["source"] = source
		lab.player.source = source
		lab.player.set_mode(run["mode"])
		# Tick 0 is a stomp: drop onto dummy 0 from 4 m at 14 m/s.
		lab.player.reset_to(lab.enemies[0].global_position + Vector3.UP * 4.0)
		lab.player.active_body().set_velocity_now(Vector3.DOWN * 14.0)
		if run["variant"] == "exported":
			var view = JevState.new(lab)
			view.attach()
			run["view"] = view
			# An independent record of every shockwave, to check the exporter's log.
			run["heard"] = []
			lab.player.shockwave.connect(func(at: Vector3, strength: float) -> void:
				run["heard"].append({"tick": view.tick, "strength": strength, "at": at}))
			_dump_state(run, 0)
	for run in _placed:
		var lab = run["holder"]["lab"]
		Scenarios.place(lab, run["scenario"])
		var tracker := Scenarios.Run.new(run["scenario"], Engine.physics_ticks_per_second)
		var view = JevState.new(lab, tracker)
		view.attach()
		run["run"] = tracker
		run["view"] = view


# Records the state after `_tick` ticks, lets the exporter read it, then sets the
# scripted input for the next tick. Every variant runs exactly this code; only the
# exported one touches `view`.
func _step_identity(run: Dictionary) -> void:
	var lab = run["holder"]["lab"]
	run["trace"].append(_sample(lab))
	if run.has("view"):
		var view = run["view"]
		view.advance()
		var snap: Dictionary = view.snapshot()
		_snapshots += 1
		_check_snapshot(lab, view, snap)
		if _tick % SNAPSHOT_EVERY == 0:
			_dump_state(run, _tick)
	_script(run, lab)


func _sample(lab) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var at: Vector3 = lab.player.ball_position()
	var v: Vector3 = lab.player.state.velocity
	var body_v: Vector3 = lab.player.active_body().velocity if lab.player.mode == PlayerBall.KINEMATIC \
		else lab.player.active_body().linear_velocity
	for vector in [at, v, body_v]:
		out.append_array([vector.x, vector.y, vector.z])
	for enemy in lab.enemies:
		out.append_array([enemy.global_position.x, enemy.global_position.y, enemy.global_position.z,
			enemy.velocity.x, enemy.velocity.y, enemy.velocity.z])
	return out


# The fixed input sequence: a function of the tick alone, plus one scripted ram setup.
func _script(run: Dictionary, lab) -> void:
	var source: ScriptedSource = run["source"]
	var t := _tick
	if t == RAM_TICK:
		# Line up on dummy 3 from 7 m on a side clear of pillars, above the fast tier.
		var target: Vector3 = lab.enemies[3].global_position
		var away := _clear_bearing(target, lab.player.ball_position())
		var start := Field.drop_point(target.x + away.x * 7.0, target.z + away.z * 7.0, 1.1)
		start.y = maxf(start.y, target.y - 0.4)
		lab.player.reset_to(start)
		lab.player.active_body().set_velocity_now(-away * RAM_SPEED)
	if t == CONTROL_TICK and run["variant"] == "control":
		lab.player.active_body().set_velocity_now(lab.player.state.velocity + Vector3(0.001, 0.0, 0.0))
	source.brake = false
	if t < 90:
		source.move = Vector2(0.0, 1.0)
	elif t < 180:
		source.move = Vector2(1.0, 0.5)
	elif t < 270:
		source.move = Vector2(-1.0, 1.0)
		source.brake = t >= 220 and t < 240
	elif t < 300:
		# Hands off during the ram run-in, so drive input cannot steer it off target.
		source.move = Vector2.ZERO
	elif t < 450:
		source.move = Vector2(0.0, 1.0)
	elif t < 600:
		source.move = Vector2(-0.7, -0.7)
	elif t < 750:
		source.move = Vector2(1.0, 0.0)
		source.brake = t >= 650 and t < 680
	else:
		source.move = Vector2(0.3, 1.0)
	if t in [90, 200, 215, 500, 820, 835]:
		source.jump = true
	if t in [135, 360, 800]:
		source.boost = true


# The first of eight bearings, starting from the ball's side, whose 7 m run-in keeps
# the ball clear of every pillar (ball 1 m + pillar 2.2 m, plus margin).
func _clear_bearing(target: Vector3, ball: Vector3) -> Vector3:
	var first := atan2(ball.z - target.z, ball.x - target.x)
	var flat := Vector2(target.x, target.z)
	for k in 8:
		var angle := first + k * TAU / 8.0
		var dir := Vector2(cos(angle), sin(angle))
		var clear := true
		for pillar in Scenarios.PILLARS:
			var near := Geometry2D.get_closest_point_to_segment(pillar, flat, flat + dir * 7.0)
			if near.distance_to(pillar) < 4.0:
				clear = false
		if clear:
			return Vector3(dir.x, 0.0, dir.y)
	return Vector3.BACK


# DoD 1 against direct reads of the same lab, on every snapshot.
func _check_snapshot(lab, view, snap: Dictionary) -> void:
	var problems := []
	var state: Dictionary = snap["jev"]["state"]
	var me: Dictionary = state["self"]
	if me["air_jump_available"] != (lab.player.state.air_actions > 0):
		problems.append("air_jump_available")
	if me["speed_tier"] != SpeedTier.label(lab.player.state.tier):
		problems.append("speed_tier")
	if not _on_tenth(me["speed_ms"]) or absf(me["speed_ms"] - lab.player.state.velocity.length()) > 0.05 + 1e-9:
		problems.append("speed_ms")
	if state["stage"]["time_s"] != int(floor(view.tick / 90.0)) or typeof(state["stage"]["time_s"]) != TYPE_INT:
		problems.append("time_s")
	var within := 0
	for enemy in lab.enemies:
		if enemy.global_position.distance_to(lab.player.ball_position()) <= 60.0:
			within += 1
	var threats: Array = state["threats"]
	if threats.size() != mini(within, 3):
		problems.append("threat count %d for %d within 60 m" % [threats.size(), within])
	for i in threats.size():
		if typeof(threats[i]["distance_m"]) != TYPE_INT or threats[i]["distance_m"] > 60:
			problems.append("threat distance")
		if i > 0 and threats[i]["distance_m"] < threats[i - 1]["distance_m"]:
			problems.append("threat order")
	if typeof(state["objective"]["distance_m"]) != TYPE_INT:
		problems.append("objective distance")
	var options: Array = snap["jev"]["options"]
	var ids := {}
	for option in options:
		ids[option["id"]] = true
		if option.has("requires_speed_ms") and not _on_tenth(option["requires_speed_ms"]):
			problems.append("requires_speed_ms")
	if options.is_empty() or options[0]["id"] != "push_objective" or ids.size() != options.size():
		problems.append("options")
	var sim: Dictionary = snap["sim"]
	if Vector3(sim["pos"][0], sim["pos"][1], sim["pos"][2]) != lab.player.ball_position():
		problems.append("sim.pos")
	if not problems.is_empty():
		_check_errors += 1
		if _check_errors <= 5:
			print("[snapshot] tick %d: %s" % [view.tick, ", ".join(problems)])


func _on_tenth(value) -> bool:
	return typeof(value) == TYPE_FLOAT and value >= 0.0 and is_equal_approx(value * 10.0, round(value * 10.0))


func _dump_state(run: Dictionary, tick: int) -> void:
	if _dump == "":
		return
	var dir: String = _dump.path_join(PlayerBall.MODE_NAMES[run["mode"]])
	DirAccess.make_dir_recursive_absolute(dir)
	var snap: Dictionary = run["view"].snapshot()
	var seq := tick / SNAPSHOT_EVERY
	var message := {"protocol": "scrapkeep-jev/1", "seq": seq, "tick": tick, "held": null,
		"jev": snap["jev"], "sim": snap["sim"]}
	var file := FileAccess.open(dir.path_join("state-%06d.json" % seq), FileAccess.WRITE)
	file.store_string(JSON.stringify(message) + "\n")
	file.close()


func _check_placements() -> void:
	for run in _placed:
		var scenario: Dictionary = run["scenario"]
		var lab = run["holder"]["lab"]
		var at: Vector3 = lab.player.ball_position()
		var clearance := at.y - Field.height(at.x, at.z)
		var tracker = run["run"]
		var snap: Dictionary = run["view"].snapshot()
		var ok: bool = at.is_finite() and absf(at.x) < Field.HALF and absf(at.z) < Field.HALF \
			and clearance > -0.5 and tracker.result() == "running" and tracker.progress["anomalies"].is_empty() \
			and snap["jev"]["state"]["objective"]["kind"] == scenario["objective"]["kind"]
		_report("place", ok, "%s: spawn %s, after %d ticks at (%.1f, %.1f, %.1f), %.2f m above the field, %s, objective %s %d m"
			% [scenario["label"], _fmt(scenario["spawn"]), PLACE_TICKS, at.x, at.y, at.z, clearance, tracker.result(),
			snap["jev"]["state"]["objective"]["kind"], snap["jev"]["state"]["objective"]["distance_m"]])
		run["view"].detach()
		run["holder"]["viewport"].queue_free()


func _fmt(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


# Largest absolute difference between two traces and the first tick they differ
# (-1 when identical). Sample i is the state after tick i + 1.
func _divergence(a: Array, b: Array) -> Dictionary:
	var first := -1
	var worst := 0.0
	for t in mini(a.size(), b.size()):
		var x: PackedFloat64Array = a[t]
		var y: PackedFloat64Array = b[t]
		if x == y:
			continue
		if first < 0:
			first = t
		for i in x.size():
			var d := absf(x[i] - y[i])
			if is_nan(d) or d > worst:
				worst = INF if is_nan(d) else d
	if a.size() != b.size():
		first = mini(a.size(), b.size()) if first < 0 else first
	return {"first": first + 1 if first >= 0 else -1, "max": worst}


func _finish() -> void:
	var stomps := 0
	var rams := 0
	for mode in MODES:
		var name: String = PlayerBall.MODE_NAMES[mode]
		var by := {}
		for run in _identity:
			if run["mode"] == mode:
				by[run["variant"]] = run
		var base: Dictionary = _divergence(by["baseline_a"]["trace"], by["baseline_b"]["trace"])
		var against_a: Dictionary = _divergence(by["baseline_a"]["trace"], by["exported"]["trace"])
		var against_b: Dictionary = _divergence(by["baseline_b"]["trace"], by["exported"]["trace"])
		var control: Dictionary = _divergence(by["baseline_a"]["trace"], by["control"]["trace"])
		var ticks: int = by["exported"]["trace"].size()
		_report("baseline", base["first"] < 0, "%s: two runs without the exporter over %d ticks: first difference at tick %d, max %s"
			% [name, ticks, base["first"], str(base["max"])])
		_report("identity", against_a["first"] < 0 and against_b["first"] < 0 and ticks == TICKS,
			"%s: exporter on vs off over %d ticks: first difference at tick %d / %d, max %s / %s (vs baseline A / B)"
			% [name, ticks, against_a["first"], against_b["first"], str(against_a["max"]), str(against_b["max"])])
		_report("control", control["first"] == CONTROL_TICK + 1, "%s: a 1 mm/s nudge applied after the tick-%d sample is seen from tick %d, max %s"
			% [name, CONTROL_TICK, control["first"], str(control["max"])])
		var view = by["exported"]["view"]
		var lab = by["exported"]["holder"]["lab"]
		var heard: Array = by["exported"]["heard"]
		var knocks_ok: bool = view.knocks.size() == heard.size() and not heard.is_empty()
		# Consecutive waves of one kind on one dummy are summarised as one stretch.
		var stretches := []
		for i in mini(view.knocks.size(), heard.size()):
			var knock: Dictionary = view.knocks[i]
			var expect := "stomp" if is_equal_approx(heard[i]["strength"], 0.6) else ("ram" if is_equal_approx(heard[i]["strength"], 1.0) else "other")
			if knock["tick"] != heard[i]["tick"] or knock["kind"] != expect or knock["enemy"] < 0 \
					or knock["enemy"] >= lab.enemies.size():
				knocks_ok = false
			var last = stretches.back() if not stretches.is_empty() else null
			if last != null and last["kind"] == knock["kind"] and last["enemy"] == knock["enemy"]:
				last["waves"] += 1
				last["to"] = knock["tick"]
			else:
				stretches.append({"kind": knock["kind"], "enemy": knock["enemy"], "waves": 1, "from": knock["tick"], "to": knock["tick"]})
		var described := []
		for stretch in stretches:
			described.append("%s on dummy %d: %d wave(s), ticks %d-%d" % [stretch["kind"], stretch["enemy"], stretch["waves"], stretch["from"], stretch["to"]])
		_report("knocks", knocks_ok, "%s: exporter logged %d of %d shockwaves (%s)" % [name, view.knocks.size(), heard.size(),
			"; ".join(described) if not described.is_empty() else "none"])
		stomps += view.knock_count("stomp")
		rams += view.knock_count("ram")
		view.detach()
	_report("knock kinds", stomps >= 1 and rams >= 1, "%d stomps (0.6) and %d rams (1.0) across both modes" % [stomps, rams])
	_report("snapshots", _check_errors == 0, "%d snapshots checked against direct reads, %d with a problem" % [_snapshots, _check_errors])
	_check_scenarios()
	print("jev_state_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	for run in _identity:
		run["holder"]["viewport"].free()
	quit(0 if _failures == 0 else 1)


# DoD 3: seven scenarios, each with spawn, objective, limit and a working predicate.
func _check_scenarios() -> void:
	var scenarios := Scenarios.all()
	var ids := []
	for scenario in scenarios:
		ids.append(scenario["id"])
		var spawn: Vector3 = scenario["spawn"]
		var point: Vector3 = scenario["objective"]["point"] if not scenario["dynamic_objective"] else spawn
		var ok: bool = spawn.is_finite() and absf(spawn.x) < Field.HALF and absf(spawn.z) < Field.HALF \
			and spawn.y > Field.height(spawn.x, spawn.z) and point.is_finite() and scenario["time_limit_s"] > 0.0 \
			and scenario["success"] is Callable and scenario["success"].is_valid()
		_report("scenario", ok, "%s: spawn %s, objective %s, limit %.0f s" % [scenario["label"], _fmt(spawn),
			scenario["objective"]["kind"], scenario["time_limit_s"]])
	_report("ids", ids == Scenarios.IDS and ids.size() == 7, "scenario ids %s" % ", ".join(ids))

	var cases := {
		"downhill-run": [{"reached": true}],
		"run-to-pad": [{"reached": true}],
		"bench-climb": [{"on_bench": true}],
		"kicker-gap": [{"on_bench": true}],
		"dummy-knock": [{"knocked": [0, 1, 2]}, {"knocked": [0, 4]}],
		"pillar-weave": [{"gates": 4}, {"gates": 3}],
		"soak": [{"tick": 10800}, {"tick": 10800, "anomalies": [{"tick": 5, "what": "tunnel"}]}],
	}
	for scenario in scenarios:
		var fresh := Scenarios.Run.new(scenario, 90)
		var pass_case: Dictionary = fresh.progress.duplicate(true)
		pass_case.merge(cases[scenario["id"]][0], true)
		var fail_case: Dictionary = fresh.progress.duplicate(true)
		if cases[scenario["id"]].size() > 1:
			fail_case.merge(cases[scenario["id"]][1], true)
		var ok: bool = not scenario["success"].call(fresh.progress) and scenario["success"].call(pass_case) \
			and not scenario["success"].call(fail_case)
		_report("predicate", ok, "%s: false at start, true on %s, false short of it" % [scenario["id"], JSON.stringify(cases[scenario["id"]][0])])

	var low := Scenarios.make("kicker-gap@14")
	var high := Scenarios.make("kicker-gap@28")
	var ok_range: bool = not low.is_empty() and not high.is_empty() and Scenarios.make("kicker-gap@13.9").is_empty() \
		and Scenarios.make("kicker-gap@28.1").is_empty() and high["velocity"] == Vector3(0.0, 0.0, 28.0) \
		and Scenarios.make("kicker-gap")["params"]["speed"] == Scenarios.KICKER_SPEED_DEFAULT
	_report("kicker-gap", ok_range, "speed parameter accepts 14 and 28 m/s, refuses 13.9 and 28.1")

	var crossing := Scenarios.Geo.crosses(Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)) \
		and not Scenarios.Geo.crosses(Vector2(0, 1), Vector2(0, 2), Vector2(-1, 0), Vector2(1, 0))
	_report("gates", crossing, "segment crossing detects a pass and ignores a miss")

	# Props field.gd builds from inline literals must still be where scenarios.gd says.
	var lab = _identity[0]["holder"]["lab"]
	var pillars := []
	var boxes := []
	for child in lab.get_children():
		if child is StaticBody3D:
			for shape in child.get_children():
				if shape is CollisionShape3D and shape.shape is CylinderShape3D:
					pillars.append(Vector2(child.position.x, child.position.z))
				elif shape is CollisionShape3D and shape.shape is BoxShape3D:
					boxes.append(child.position)
	var props_ok: bool = pillars.size() == Scenarios.PILLARS.size() and boxes.has(Scenarios.STEEP_KICKER) \
		and boxes.has(Scenarios.SERVICE_RAMP)
	for pillar in Scenarios.PILLARS:
		props_ok = props_ok and pillars.has(pillar)
	_report("props", props_ok, "%d pillars and both ramps where scenarios.gd expects them" % pillars.size())
