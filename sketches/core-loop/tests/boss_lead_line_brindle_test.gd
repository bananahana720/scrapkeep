extends "res://tests/boss_lead_line_test.gd"
# smoke: timeout=300s
# fast-lane sources: res://src/game.gd res://src/boss/boss_rules.gd res://src/movement/tuning.gd res://src/combat/pack_pressure.gd

const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Arena := preload("res://src/boss/arena.gd")


func _run() -> void:
	_game.ctx.calm = true
	var fight := await _brindle()
	var boss = fight["boss"]
	var centre: Vector3 = fight["centre"]
	var nose: float = fight["nose"]
	for v in [
		{"name": "Brindle's charge", "lane": true, "hold": boss.CHARGE_REST, "tell": ChallengeDials.tell("brindle", Rules.CHARGE_WARN, Hazard.MIN_WARN)},
		{"name": "Brindle's hook turn", "lane": true, "hold": boss.CHARGE_HOOK, "tell": FightPhases.CUED_WARN},
	]:
		var tell: float = v["tell"]
		_cases(v, func(case: String, line: Dictionary) -> Dictionary: return _brindle_trial(boss, v, case, line),
			func() -> Dictionary: return _bowl_line(boss, centre, tell, nose))
	_bank_check(boss, centre)
	boss.set_physics_process(true)
	_finish("boss_lead_line_brindle_test", 15)


# --- Brindle's charge --------------------------------------------------------------------

func _brindle() -> Dictionary:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.calm = false
	_game.ctx.spawner = _game.combat
	var boss = _game.boss
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	_game.flow.retry_stage()
	_game.run.heal(1000.0)
	boss.jump_to_phase(3)
	boss.set_physics_process(false)
	var centre: Vector3 = boss.arena.global_position
	# Through the phase's transition beat, the ball parked at the centre.
	for i in 90 * 6:
		_game.run.heal(1000.0)
		_place(centre + Vector3.UP, Vector3.ZERO)
		boss.advance(DT)
		if not boss._in_transition() and boss._charge.get("state", "") == boss.CHARGE_REST:
			break
	return {"boss": boss, "centre": centre, "nose": Requisition.HULL.z * 0.5 + boss.CHARGE_REACH}


func _bowl_line(boss, centre: Vector3, tell: float, nose: float) -> Dictionary:
	var from: Vector3 = boss.ship.global_position
	var line := {}
	for attempt in 400:
		line = _line(from, 15.0, 38.0, func(d: float) -> float: return tell + maxf(0.0, d - nose) / Rules.CHARGE_SPEED)
		if _in_bowl(boss, line, centre):
			break
	return line


# The whole line, from the pre-roll to a second past the landing, stays well inside the bowl.
func _in_bowl(boss, line: Dictionary, centre: Vector3) -> bool:
	var land: Vector3 = line["land"]
	var at0: Vector3 = line["at0"]
	var dir: Vector3 = (land - at0).normalized()
	for p in [at0 - dir * CRUISE * PRE_ROLL, land + dir * CRUISE, at0, land]:
		if Vector2(p.x - centre.x, p.z - centre.z).length() > 40.0:
			return false
	return Vector2(land.x - boss.ship.global_position.x, land.z - boss.ship.global_position.z).length() > 12.0


func _place(at: Vector3, v: Vector3) -> void:
	_game.player.body().global_position = at
	_game.player.state.velocity = v


func _brindle_trial(boss, v: Dictionary, case: String, line: Dictionary) -> Dictionary:
	_game.run.heal(1000.0)
	var arena = boss.arena
	var path := _path(case, line, v["tell"], func(p: Vector3) -> float: return arena.ground(p) + 1.0)
	return _brindle_run(boss, v["hold"], path)


# Runs one charge committed on path index PRE: the pre-roll fed, the wait state's timer set to end on
# the commit tick, then the tell and the run.
func _brindle_run(boss, hold: String, path: Array, contact := 0.0) -> Dictionary:
	var pre := int(round(PRE_ROLL / DT))
	_arm_charge(boss, hold, path, pre)
	var out := {"hit": false, "moved": 0, "outside": 0, "tell": 0.0, "unled": false}
	var lane = null
	var drawn := {}
	var rest := {"stopped": false}
	for k in range(0, path.size() - pre):
		var tick: Array = _meet_body(rest, path[pre + k], boss.ship.global_position, contact, Requisition.HULL.y) if k > 0 else path[pre]
		path[pre + k] = tick
		_place(tick[0], tick[1])
		PackPressure.observe_tick(tick[1], DT, CRUISE)
		boss.advance(DT)
		var state: String = boss._charge.get("state", "")
		if lane == null:
			if state != boss.CHARGE_BRACE:
				continue
			lane = boss._charge["hazard"]
			out["tell"] = lane.warn_seconds
			drawn = lane.descriptor()
			out["unled"] = _on_ball(drawn, path[pre + k][0])
			continue
		if not is_instance_valid(lane):
			break
		if _geometry(lane.descriptor()) != _geometry(drawn):
			out["moved"] = 1
		if boss._grace.has(lane.get_instance_id()) and not out["hit"]:
			out["hit"] = true
			if not _inside(drawn, _game.player.ball_position()):
				out["outside"] = 1
		if state != boss.CHARGE_BRACE and state != boss.CHARGE_RUN:
			break
	return out


func _arm_charge(boss, hold: String, path: Array, pre: int) -> void:
	for h in boss.hazards.duplicate():
		if is_instance_valid(h) and h.is_done():
			boss.hazards.erase(h)
			h.get_parent().remove_child(h)
			h.queue_free()
	_feed(path, 0, pre)
	boss._charge = {"state": hold, "timer": 0.5 * DT}


# A ball circling the bowl's bank (radius FLOOR_R to BANK_R) at cruise turns about 13 to 18 degrees a
# second: it is turning, not holding a line, and the charge must not lead it onto its curve.
func _bank_check(boss, centre: Vector3) -> void:
	_rng.seed = SEED
	var hit := 0
	var led := 0
	for i in TRIALS:
		_game.run.heal(1000.0)
		var r := _rng.randf_range(Arena.FLOOR_R + 6.0, Arena.BANK_R)
		var a0 := _rng.randf_range(-PI, PI)
		var dir := 1.0 if _rng.randf() < 0.5 else -1.0
		var w := dir * CRUISE / r
		var pre := int(round(PRE_ROLL / DT))
		var path := []
		path.resize(pre + int(round(POST_S / DT)) + 1)
		for k in path.size():
			var a := a0 + w * (k - pre) * DT
			var p := centre + Vector3(cos(a), 0.0, sin(a)) * r
			path[k] = [Vector3(p.x, boss.arena.ground(p) + 1.0, p.z), Vector3(-sin(a), 0.0, cos(a)) * CRUISE * dir]
		var out := _brindle_run(boss, boss.CHARGE_REST, path)
		hit += 1 if out["hit"] else 0
		led += 0 if out["unled"] else 1
	_report("a ball circling the Slag Bowl's bank is not hit by Brindle's charge", hit == 0,
		"%d of %d circling balls hit; %d of %d lanes led off the ball" % [hit, TRIALS, led, TRIALS])


func _brindle_scenarios(boss, centre: Vector3, nose: float) -> void:
	var tell: float = ChallengeDials.tell("brindle", Rules.CHARGE_WARN, Hazard.MIN_WARN)
	var arena = boss.arena
	var contact: float = Requisition.HULL.z * 0.5 + Tuning.RADIUS
	_scenarios("Brindle's charge", contact,
		func() -> Vector3:
			_game.run.heal(1000.0)
			return _park_ship(boss, centre),
		func() -> Dictionary: return _bowl_line(boss, centre, tell, nose),
		func(line: Dictionary) -> bool:
			var path := _path("straight", line, tell, func(p: Vector3) -> float: return arena.ground(p) + 1.0)
			return _brindle_run(boss, boss.CHARGE_REST, path, contact)["hit"])


# The ship at `at` (the centre when null), still, facing +x. Returns where it is.
func _park_ship(boss, centre: Vector3, at = null) -> Vector3:
	var p: Vector3 = centre if at == null else at
	boss.ship.move_to(Vector3(p.x, boss.arena.ground(p), p.z), Vector3(1.0, 0.0, 0.0))
	return boss.ship.global_position


# --- The bank ram ------------------------------------------------------------------------

# Brindle's stun is for burying his nose in the bank, so it must come only where the hull is at the rim, and
# a charge that is not a ram must end short of it. Counted from where the hull stops, not from the rule.
# Lines at cruise: outward from the ship at the centre and at mid-floor, and a ball near the rim rolling in.
func _bank_stun_check(boss, centre: Vector3) -> void:
	var arena = boss.arena
	var scenes := [["outward from the centre", 0.0, 12.0, 20.0, 0.0], ["outward from mid-floor", Arena.FLOOR_R * 0.5, 12.0, 20.0, 0.0],
		["inward from near the rim", Arena.FLOOR_R * 0.5, 14.0, 20.0, PI]]
	for scene in scenes:
		_rng.seed = SEED
		var rams := 0
		var stray := 0
		var rest_min := INF
		var ram_gap := 0.0
		var outward: bool = scene[4] == 0.0
		for i in 40:
			_game.run.heal(1000.0)
			var from := _park_ship(boss, centre, centre + Vector3(scene[1], 0.0, 0.0))
			var dir := _rng.randf_range(-PI / 3.0, PI / 3.0)
			var start := Vector3(from.x, 0.0, from.z) + Vector3(cos(dir), 0.0, sin(dir)) * _rng.randf_range(scene[2], scene[3])
			var heading: float = dir + scene[4] + deg_to_rad(_rng.randf_range(-15.0, 15.0))
			var line := {"at0": start, "heading": heading, "turn_sign": 1.0, "deg": ARC_DEG, "land": start, "pre_speed": CRUISE, "speed": CRUISE}
			var path := _path("straight", line, 0.0, func(p: Vector3) -> float: return arena.ground(p) + 1.0)
			var stuns_before: int = boss.stuns
			_brindle_run(boss, boss.CHARGE_REST, path)
			var gap: float = Rules.CHARGE_STOP_R - Vector2(boss.ship.global_position.x - centre.x, boss.ship.global_position.z - centre.z).length()
			if boss.stuns > stuns_before:
				rams += 1
				ram_gap = maxf(ram_gap, absf(gap))
				if absf(gap) > 0.05:
					stray += 1
			else:
				rest_min = minf(rest_min, gap)
				if gap < 0.5:
					stray += 1
		_report("Brindle takes the bank stun only with the hull at the rim, " + scene[0], stray == 0,
			"%d of 40 charges ended in the stun, the farthest %.2f m from the rim; the others ended at least %.2f m short of it; %d stray" % [rams, ram_gap, rest_min if rest_min != INF else -1.0, stray])


# A ram leaves the hull at the stop radius. The next charge, at a ball about 28 m away rolling toward the
# nearby bank on a held line, leads to a point outside the bowl: its lane must still be a charge (positive
# length) and the hull must never go backward along it.
func _rest_at_bank_check(boss, centre: Vector3) -> void:
	var arena = boss.arena
	var shortest := INF
	var backward := 0.0
	for i in 20:
		_game.run.heal(1000.0)
		var a := _rng.randf_range(-0.5, 0.5)
		var rim := centre + Vector3(cos(a), 0.0, sin(a)) * Rules.CHARGE_STOP_R
		var from := _park_ship(boss, centre, rim)
		var radial := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-radial.z, 0.0, radial.x) * (1.0 if i % 2 == 0 else -1.0)
		# 28 m out along a line mostly sideways to the ship and drifting toward the bank.
		var start := Vector3(from.x, 0.0, from.z) - radial * 16.0 + side * 23.0
		var dir := (-side * 0.6 + radial * 0.8).normalized()
		var heading := atan2(dir.z, dir.x)
		var line := {"at0": start, "heading": heading, "turn_sign": 1.0, "deg": ARC_DEG, "land": start, "pre_speed": CRUISE, "speed": CRUISE}
		var path := _path("straight", line, 0.0, func(p: Vector3) -> float: return arena.ground(p) + 1.0)
		var pre := int(round(PRE_ROLL / DT))
		_arm_charge(boss, boss.CHARGE_REST, path, pre)
		var length := -1.0
		for k in range(0, 400):
			_place(path[pre + k][0], path[pre + k][1])
			PackPressure.observe_tick(path[pre + k][1], DT, CRUISE)
			boss.advance(DT)
			if length < 0.0 and boss._charge.get("state", "") == boss.CHARGE_BRACE:
				length = float(boss._charge["length"])
			if length >= 0.0:
				var back: float = (boss.ship.global_position - from).dot(Vector3(boss._charge["heading"])) if boss._charge.has("heading") else 0.0
				backward = maxf(backward, -back)
				if boss._charge.get("state", "") not in [boss.CHARGE_BRACE, boss.CHARGE_RUN]:
					break
		shortest = minf(shortest, length)
	_report("Brindle's charge from the bank is a charge, not a step back", shortest >= boss.CHARGE_MIN_LANE and backward < 0.05,
		"20 charges from the stop radius: shortest committed lane %.2f m (must be at least the %.0f m floor); farthest the hull went backward along its heading %.2f m" % [shortest, boss.CHARGE_MIN_LANE, backward])
