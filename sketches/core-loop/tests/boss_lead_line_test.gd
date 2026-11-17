extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")

# Bosses lead a ball that holds a line; a turn escapes (PackPressure.lead_aim). Andrew after his
# world 1 sitting: "bosses (mini or main lineup) are a pushover". Every boss attack aimed at where
# the ball was at the commit, so a ball that kept rolling was never where the attack landed.
#
# Five attacks, each driven on its real code with a scripted ball and a pinned seed: Brindle's
# charge, the gate crane's sweep and drop, and the event miniboss's slam and charge. Each trial
# picks a landing point inside the attack's reach and runs a ball through it at cruise. Cases:
#   straight: the ball holds its line for PRE_ROLL before the commit and through the attack. At
#     least STRAIGHT_SHARE of trials must be hit. Plant: SCRAPKEEP_PLANT_BOSS_LEAD=none (no lead)
#     must drop it under that share.
#   arc: the ball turns ARC_DEG over the tell, at a steady rate that started before the commit, on
#     the side that carries it away from the attacker. None may be hit. Plant: =full (a full lead
#     for a turning ball, along its curve) must hit some.
#   swerve: the ball holds its line, then REACT_S after the commit turns ARC_DEG outward at the
#     drive's turn rate (SWERVE_RATE) and holds the new line. Rings must hit none; for lanes the
#     share is printed as a report, not judged (a lane runs along the ball's new line, so a 30
#     degree turn does not always leave it).
#   stop: the ball rests on the landing point. Every trial must be hit (no regression).
# Every attack also: its tell is at least ChallengeDials.TELL_FLOOR (0.6 s); its drawn geometry
# (the descriptor the painter reads) is the same at the landing as at the commit; and every hit
# lands with the ball inside that drawn footprint.
#
# Evidence limit: this shows geometry only. It cannot show whether a hit feels fair, how a real
# player or the bots fare, or whether the mark is in the camera's view. The band read does that:
#   npm run challenge:bands (Brindle rows, brindle-worst-minute and brindle-stop-tax).

const SEED := 4417
const TRIALS := 20
const CRUISE := 14.0
const DT := 1.0 / 90.0
const PRE_ROLL := 1.4
const ARC_DEG := 30.0
const REACT_S := 0.25
# A full sideways stick at cruise turns the ball at drive_accel / cruise = 34 / 14 rad/s.
const SWERVE_RATE := 2.4
const STRAIGHT_SHARE := 0.8
const POST_S := 6.0
const GEOMETRY := ["centre", "dir", "back", "length", "half_width", "r_in", "r_out", "a0", "a1"]


class Roller extends RefCounted:
	var at := Vector3.ZERO
	var v := Vector3.ZERO

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return Vector3(v.x, 0.0, v.z)


class FlatTerrain extends RefCounted:
	func height(_x: float, _z: float) -> float:
		return 0.0


var _game
var _failures := 0
var _rng := RandomNumberGenerator.new()
var _hits := 0
var _hits_outside := 0
var _roller := Roller.new()
var _drawn := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	_game.ctx.calm = true
	_enemies()
	await _brindle()
	OS.set_environment(PackPressure.PLANT_ENV, "")
	print("boss_lead_line_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# --- The scripted ball -------------------------------------------------------------------

# A trial's line: the landing point `land` at `land_t` seconds after the commit for a straight
# ball, and the heading the ball holds. `turn_sign` is the side that turns away from `from`.
func _line(from: Vector3, reach_min: float, reach_max: float, land_time: Callable) -> Dictionary:
	var d := _rng.randf_range(reach_min, reach_max)
	var base := _rng.randf_range(-PI, PI)
	var cross := deg_to_rad(_rng.randf_range(30.0, 150.0)) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var land := from + Vector3(cos(base), 0.0, sin(base)) * d
	var heading := base + cross
	var t: float = land_time.call(d)
	var dir := Vector3(cos(heading), 0.0, sin(heading))
	return {"land": Vector3(land.x, 0.0, land.z), "heading": heading, "at0": land - dir * CRUISE * t,
		"turn_sign": -signf(cross), "t": t}


# The ball's heading rate at `t` seconds from the commit, for a case.
func _rate(case: String, line: Dictionary, tell: float, t: float) -> float:
	var s: float = line["turn_sign"]
	match case:
		"arc":
			return s * deg_to_rad(ARC_DEG) / tell if t < tell else 0.0
		"swerve":
			var end := REACT_S + deg_to_rad(ARC_DEG) / SWERVE_RATE
			return s * SWERVE_RATE if t >= REACT_S and t < end else 0.0
	return 0.0


# Ticks of the path from -PRE_ROLL to POST_S: [position, velocity], index 0 at -PRE_ROLL.
func _path(case: String, line: Dictionary, tell: float) -> Array:
	var pre := int(round(PRE_ROLL / DT))
	var post := int(round(POST_S / DT))
	var out := []
	out.resize(pre + post + 1)
	if case == "stop":
		for i in out.size():
			out[i] = [line["land"] + Vector3.UP, Vector3.ZERO]
		return out
	var at: Vector3 = line["at0"]
	var h: float = line["heading"]
	out[pre] = [at + Vector3.UP, Vector3(cos(h), 0.0, sin(h)) * CRUISE]
	for k in range(1, pre + 1):
		h -= _rate(case, line, tell, -k * DT) * DT
		at -= Vector3(cos(h), 0.0, sin(h)) * CRUISE * DT
		out[pre - k] = [at + Vector3.UP, Vector3(cos(h), 0.0, sin(h)) * CRUISE]
	at = line["at0"]
	h = line["heading"]
	for k in range(1, post + 1):
		h += _rate(case, line, tell, (k - 1) * DT) * DT
		at += Vector3(cos(h), 0.0, sin(h)) * CRUISE * DT
		out[pre + k] = [at + Vector3.UP, Vector3(cos(h), 0.0, sin(h)) * CRUISE]
	return out


# Feeds the lead's heading record the pre-roll, as combat's observe() would, ending on the tick
# before the commit.
func _pre_roll(path: Array) -> void:
	var pre := int(round(PRE_ROLL / DT))
	for i in pre:
		PackPressure.observe_tick(path[i][1], DT, CRUISE, i == 0)


func _geometry(d: Dictionary) -> Dictionary:
	var g := {}
	for key in GEOMETRY:
		if d.has(key):
			g[key] = d[key]
	return g


# Whether `p` is inside the drawn footprint, read from the descriptor alone.
func _inside(d: Dictionary, p: Vector3) -> bool:
	var c: Vector3 = d["centre"]
	var flat := Vector3(p.x - c.x, 0.0, p.z - c.z)
	if d.get("form", "") == "lane":
		var dir: Vector3 = d["dir"]
		var along := flat.dot(dir)
		var lateral := (flat - dir * along).length()
		return along >= -float(d.get("back", 0.0)) - 0.01 and along <= float(d["length"]) + 0.01 and lateral <= float(d["half_width"]) + 0.01
	return flat.length() <= float(d["r_out"]) + 0.01


func _tally(name: String, shares: Dictionary, tells: Array, moved: int, outside: int) -> void:
	var min_tell: float = tells.min()
	_report(name + " holds a straight line and is met", shares["straight"] >= STRAIGHT_SHARE,
		"%d of %d straight balls hit (at least %d%%)" % [roundi(shares["straight"] * TRIALS), TRIALS, roundi(STRAIGHT_SHARE * 100)])
	_report(name + " without the lead misses the straight ball (plant)", shares["straight_none"] < STRAIGHT_SHARE,
		"%d of %d hit with SCRAPKEEP_PLANT_BOSS_LEAD=none (the check must fall under %d%%)" % [roundi(shares["straight_none"] * TRIALS), TRIALS, roundi(STRAIGHT_SHARE * 100)])
	_report(name + " never leads a ball turning %d degrees in the tell" % ARC_DEG, shares["arc"] == 0.0,
		"%d of %d turning balls hit" % [roundi(shares["arc"] * TRIALS), TRIALS])
	_report(name + " with a full lead for a turning ball hits it (plant)", shares["arc_full"] > 0.0,
		"%d of %d hit with SCRAPKEEP_PLANT_BOSS_LEAD=full (the turning check must fail)" % [roundi(shares["arc_full"] * TRIALS), TRIALS])
	_report(name + " still hits a stopped ball", shares["stop"] == 1.0,
		"%d of %d stopped balls hit" % [roundi(shares["stop"] * TRIALS), TRIALS])
	_report(name + " tells at least the floor", min_tell >= ChallengeDials.TELL_FLOOR - 0.0001,
		"shortest tell %.2f s (floor %.2f)" % [min_tell, ChallengeDials.TELL_FLOOR])
	_report(name + " lands on the geometry it drew", moved == 0 and outside == 0,
		"%d trials whose drawn geometry moved after the commit, %d hits outside it" % [moved, outside])


# --- The rogue crane and the miniboss ----------------------------------------------------

func _enemies() -> void:
	var from := Vector3(0.0, 200.0, 0.0)
	for spec in [
		{"name": "the gate crane's sweep", "kind": "rogue_crane", "attack": 0, "lane": true},
		{"name": "the gate crane's drop", "kind": "rogue_crane", "attack": 1, "lane": false},
		{"name": "the miniboss's slam", "kind": "miniboss", "attack": 0, "lane": false},
		{"name": "the miniboss's charge", "kind": "miniboss", "attack": 1, "lane": true},
	]:
		var enemy = _game.ctx.spawner.spawn_enemy(spec["kind"], from)
		enemy.set_physics_process(false)
		enemy.terrain = FlatTerrain.new()
		enemy.target = _roller
		enemy.live = func(): return true
		enemy.hit_player.connect(_on_hit)
		var tell := _enemy_tell(enemy, spec)
		var reach := _enemy_reach(enemy, spec, tell)
		var shares := {}
		var tells := [tell]
		var moved := 0
		var outside := 0
		for case in ["straight", "straight_none", "arc", "arc_full", "swerve", "stop"]:
			_rng.seed = SEED
			OS.set_environment(PackPressure.PLANT_ENV, "none" if case == "straight_none" else ("full" if case == "arc_full" else ""))
			var hit := 0
			for i in TRIALS:
				var line := _line(Vector3(from.x, 0.0, from.z), reach["min"], reach["max"], reach["time"])
				var r := _enemy_trial(enemy, spec, case.trim_suffix("_none").trim_suffix("_full"), line, from, tell)
				hit += 1 if r["hit"] else 0
				moved += r["moved"]
				outside += r["outside"]
			shares[case] = float(hit) / TRIALS
		OS.set_environment(PackPressure.PLANT_ENV, "")
		_tally(spec["name"], shares, tells, moved, outside)
		_swerve_line(spec["name"], spec["lane"], shares["swerve"])
		_phase_two_tells(enemy, spec)
		enemy.free()


func _swerve_line(name: String, lane: bool, share: float) -> void:
	var detail := "%d of %d balls hit after a %d degree outward turn %.2f s into the tell" % [roundi(share * TRIALS), TRIALS, ARC_DEG, REACT_S]
	if lane:
		print("[%s: a turn made after the commit (report)] %s" % [name, detail])
	else:
		_report(name + " misses a ball that turns after the commit", share == 0.0, detail)


func _on_hit(_amount: float, _shove: Vector3) -> void:
	_hits += 1
	if not _drawn.is_empty() and not _inside(_drawn, _roller.at):
		_hits_outside += 1


# The phase 1 tell: wind (lane) or wind and strike (ring) for the crane; crouch and leap for the
# slam; the brace for the charge.
func _enemy_tell(enemy, spec: Dictionary) -> float:
	if spec["kind"] == "rogue_crane":
		var a: Dictionary = Rogue.ATTACKS[enemy.row.attacks[spec["attack"]]]
		return (float(a.wind) + (0.0 if spec["lane"] else float(a.strike))) * enemy.beat()
	return enemy.slam_crouch + Miniboss.SLAM_LEAP if spec["attack"] == 0 else enemy.charge_brace


# Where the landing point may lie (metres from the attacker) and when a straight ball reaches it.
func _enemy_reach(enemy, spec: Dictionary, tell: float) -> Dictionary:
	if not spec["lane"]:
		return {"min": 8.0, "max": 30.0, "time": func(_d: float) -> float: return tell}
	if spec["kind"] == "rogue_crane":
		var a: Dictionary = Rogue.ATTACKS["sweep"]
		var length: float = float(a.length) * enemy.site_scale
		var swing: float = 2.0 * length / (float(a.strike) * enemy.beat())
		return {"min": 6.0, "max": 0.8 * length, "time": func(d: float) -> float: return tell + d / swing}
	var speed := Miniboss.CHARGE_LENGTH / Miniboss.CHARGE_TIME
	return {"min": 6.0, "max": 0.8 * Miniboss.CHARGE_LENGTH, "time": func(d: float) -> float: return tell + d / speed}


func _enemy_trial(enemy, spec: Dictionary, case: String, line: Dictionary, from: Vector3, tell: float) -> Dictionary:
	var path := _path(case, line, tell)
	var pre := int(round(PRE_ROLL / DT))
	enemy._clear_telegraph()
	enemy.global_position = from
	enemy.velocity = Vector3.ZERO
	_pre_roll(path)
	_roller.at = path[pre][0]
	_roller.v = path[pre][1]
	if spec["kind"] == "rogue_crane":
		enemy._next = spec["attack"]
		enemy._enter(Rogue.State.STALK)
	else:
		enemy._next_attack = spec["attack"]
		enemy._enter(Miniboss.State.STALK)
	var to_ball: Vector3 = _roller.at - enemy.global_position
	to_ball.y = 0.0
	enemy._begin_attack(to_ball)
	var shown = enemy.telegraph()
	_drawn = shown.descriptor() if shown != null else {}
	var drawn := _geometry(_drawn)
	var moved := 0
	_hits = 0
	_hits_outside = 0
	for k in range(1, path.size() - pre):
		_roller.at = path[pre + k][0]
		_roller.v = path[pre + k][1]
		PackPressure.observe_tick(_roller.v, DT, CRUISE)
		enemy._physics_process(DT)
		shown = enemy.telegraph()
		if shown != null and _geometry(shown.descriptor()) != drawn:
			moved = 1
		if enemy.state_name() in ["weak", "stalk", "cue"]:
			break
	_drawn = {}
	return {"hit": _hits > 0, "moved": moved, "outside": _hits_outside}


func _phase_two_tells(enemy, spec: Dictionary) -> void:
	if spec["kind"] == "rogue_crane":
		return
	# The miniboss's phase 2 and cued tells; the crane's phase 2 floor is pinned in rogue_phase_test.
	var tells := [Miniboss.SLAM_LEAP + maxf(ChallengeDials.TELL_FLOOR - Miniboss.SLAM_LEAP, Miniboss.SLAM_CROUCH * Miniboss.PHASE_TWO_WIND),
		maxf(ChallengeDials.TELL_FLOOR, Miniboss.CHARGE_BRACE * Miniboss.PHASE_TWO_WIND), FightPhases.CUED_WARN]
	_report(spec["name"] + " phase 2 and cued tells hold the floor", tells.min() >= ChallengeDials.TELL_FLOOR - 0.0001,
		"phase 2 slam %.2f s, phase 2 charge %.2f s, cued charge %.2f s" % tells)


# --- Brindle's charge --------------------------------------------------------------------

func _brindle() -> void:
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
		_place(centre + Vector3.UP, Vector3.ZERO)
		boss.advance(DT)
		if not boss._in_transition() and boss._charge.get("state", "") == boss.CHARGE_REST:
			break
	var warn: float = ChallengeDials.tell("brindle", Rules.CHARGE_WARN, Hazard.MIN_WARN)
	var nose: float = Requisition.HULL.z * 0.5 + boss.CHARGE_REACH
	var shares := {}
	var tells := []
	var moved := 0
	var outside := 0
	var swerve := 0.0
	for case in ["straight", "straight_none", "arc", "arc_full", "swerve", "stop"]:
		_rng.seed = SEED
		OS.set_environment(PackPressure.PLANT_ENV, "none" if case == "straight_none" else ("full" if case == "arc_full" else ""))
		var hit := 0
		for i in TRIALS:
			_game.run.heal(1000.0)
			var from: Vector3 = boss.ship.global_position
			var line := {}
			for attempt in 400:
				line = _line(from, 15.0, 38.0, func(d: float) -> float: return warn + maxf(0.0, d - nose) / Rules.CHARGE_SPEED)
				if _in_bowl(boss, line, centre):
					break
			var r := _brindle_trial(boss, case.trim_suffix("_none").trim_suffix("_full"), line, warn)
			hit += 1 if r["hit"] else 0
			moved += r["moved"]
			outside += r["outside"]
			if r["tell"] > 0.0:
				tells.append(r["tell"])
		shares[case] = float(hit) / TRIALS
	OS.set_environment(PackPressure.PLANT_ENV, "")
	tells.append(FightPhases.CUED_WARN)
	_tally("Brindle's charge", shares, tells, moved, outside)
	_swerve_line("Brindle's charge", true, shares["swerve"])
	boss.set_physics_process(true)


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


func _brindle_trial(boss, case: String, line: Dictionary, warn: float) -> Dictionary:
	var arena = boss.arena
	var path := _path(case, line, warn)
	for i in path.size():
		var p: Vector3 = path[i][0]
		path[i][0] = Vector3(p.x, arena.ground(p) + 1.0, p.z)
	var pre := int(round(PRE_ROLL / DT))
	_pre_roll(path)
	boss._charge = {"state": boss.CHARGE_REST, "timer": 0.5 * DT}
	var out := {"hit": false, "moved": 0, "outside": 0, "tell": 0.0}
	var lane = null
	var drawn := {}
	for k in range(0, path.size() - pre):
		_place(path[pre + k][0], path[pre + k][1])
		PackPressure.observe_tick(path[pre + k][1], DT, CRUISE)
		boss.advance(DT)
		var state: String = boss._charge.get("state", "")
		if lane == null:
			if state != boss.CHARGE_BRACE:
				continue
			lane = boss._charge["hazard"]
			out["tell"] = lane.warn_seconds
			drawn = lane.descriptor()
			continue
		if not is_instance_valid(lane):
			break
		var now: Dictionary = lane.descriptor()
		if _geometry(now) != _geometry(drawn):
			out["moved"] = 1
		if boss._grace.has(lane.get_instance_id()) and not out["hit"]:
			out["hit"] = true
			if not _inside(drawn, _game.player.ball_position()):
				out["outside"] = 1
		if state != boss.CHARGE_BRACE and state != boss.CHARGE_RUN:
			break
	return out
