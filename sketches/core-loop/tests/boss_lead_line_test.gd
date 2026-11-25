extends SceneTree
# smoke: timeout=300s

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Arena := preload("res://src/boss/arena.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# Bosses lead a ball that holds a line; a turn escapes (PackPressure.lead_aim, card MG-11). Andrew after
# his world 1 sitting: "bosses (mini or main lineup) are a pushover". Every boss attack aimed at where the
# ball was at the commit, so a ball that kept rolling was never where the attack landed.
#
# Each attack runs on its real code with a scripted ball at cruise: Brindle's charge and his hook turn's
# cued charge, the gate crane's sweep and drop in phases 1 and 2, and the miniboss's slam and charge in
# phases 1 and 2 and its cued charge. Tells are read from the enemy at the commit. Each trial picks a
# landing point inside the attack's reach and runs a ball through it. Cases:
#   straight: the ball holds its line for PRE_ROLL before the commit and through the attack. With a tell
#     of LEAD_TELL_FULL or more at least STRAIGHT_SHARE are hit, and the plant lead_plant = "none" must
#     drop that under the share. With a tell of LEAD_TELL_NONE or less (the cued commits) every mark is
#     drawn on the ball, unled.
#   arc: the ball turns ARC_DEG over the tell at a steady rate that started before the commit, on the side
#     away from the attacker. None may be hit. The plant lead_plant = "full" must hit some.
#   swerve: the ball holds its line, then REACT_S after the commit turns outward at SWERVE_RATE (the
#     drive's full side push at cruise) and holds the new line. SWERVE_TRIALS over four seeds, at 30 and
#     45 degrees. Each attack's 30 degree share is pinned under its ceiling in SWERVE_30_MAX; the 45
#     degree shares are printed.
#   stop: the ball rests on the landing point. Every trial is hit.
#   head-on: the ball rolls at the attacker (dead on and 10 degrees off) from 12 m and 16 m and stops
#     against its body, where the body is at each tick (the slam's body has left its spot by the time the ball
#     arrives). A ball cannot roll through the attacker, so the lead must not carry the line past it.
#     Every one is hit, for the miniboss's slam and charge and Brindle's charge.
#   pace: the ball holds its line at 50% and 80% of cruise, or brakes to 60% of cruise as the attack
#     commits (a stop 0.25 s after the commit is printed only). At least STRAIGHT_SHARE are hit, as for a ball at cruise, for the miniboss's slam and Brindle's charge.
#   bank: balls rolling outward from the centre and from mid-floor and inward from near the rim, at cruise.
#     The bank stun fires only with the hull at the rim, and a charge without it ends at least 0.5 m short.
# Every committed mark is also checked: its tell is at least ChallengeDials.TELL_FLOOR, the drawn
# descriptor is the same at the landing as at the commit, and every hit lands inside it.
# Beside the trials: a ball circling the Slag Bowl's bank at cruise is never hit by Brindle's charge; the
# slam stops short of a wall and does not leave the stage; a ball faster than a charge is not led; and the
# heading record keeps game time under a hit stop.
#
# Evidence limit: geometry only. It cannot show whether a hit feels fair, how a player or the bots fare,
# or what the camera shows. The band read on the pushed head does that (MG-11 in BACKLOG.md).

const SEED := 4417
const TRIALS := 20
const SWERVE_SEEDS := [4417, 5113, 6029, 7211]
const SWERVE_TRIALS := 100
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
# The test's own flat stage, far above the game's world: the slab's top is at STAGE_Y.
const STAGE_Y := 2000.0
const STAGE_HALF := 200.0
# The most of SWERVE_TRIALS balls an attack may still catch after a 30 degree turn REACT_S into its tell,
# pinned at the seeded reading (17 Nov) rounded up to the next 5%. A ring is pinned at none, except the
# miniboss's phase 2 slam: its 1.27 s tell takes the full lead and leaves too little time for 30 degrees
# to clear a 7 m ring (45 degrees clears every one). That is an open call for the coordinator, pinned as read.
const SWERVE_30_MAX := {
	"Brindle's charge": 0.25,
	"Brindle's hook turn": 0.0,
	"the gate crane's sweep": 0.15,
	"the gate crane's sweep, phase 2": 0.25,
	"the miniboss's charge": 0.25,
	"the miniboss's charge, phase 2": 0.0,
	"the miniboss's cued charge": 0.0,
	"the miniboss's slam, phase 2": 1.0,
}


class Roller extends RefCounted:
	var at := Vector3.ZERO
	var v := Vector3.ZERO

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return Vector3(v.x, 0.0, v.z)


class FlatTerrain extends RefCounted:
	func height(_x: float, _z: float) -> float:
		return STAGE_Y


var _game
var _failures := 0
var _rng := RandomNumberGenerator.new()
var _hits := 0
var _hits_outside := 0
var _roller := Roller.new()
var _drawn := {}
# The ball's speed as a share of cruise before the commit and from it, read by _line.
var _pre_pace := 1.0
var _pace := 1.0


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
	await _hit_stop_check()
	_fast_ball_check()
	var stage := _box(Vector3(0.0, STAGE_Y - 1.0, 0.0), Vector3(STAGE_HALF * 2.0, 2.0, STAGE_HALF * 2.0))
	await physics_frame
	await physics_frame
	for variant in _enemy_variants():
		_variant(variant)
	await _slam_reach_checks()
	_enemy_scenarios()
	stage.queue_free()
	await _brindle()
	PackPressure.lead_plant = ""
	print("boss_lead_line_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	return body


# --- The scripted ball -------------------------------------------------------------------

# A trial's line: the landing point `land` reached `t` seconds after the commit by a straight ball, and
# the heading it holds. `turn_sign` is the side that turns it away from `from`.
func _line(from: Vector3, reach_min: float, reach_max: float, land_time: Callable) -> Dictionary:
	var d := _rng.randf_range(reach_min, reach_max)
	var base := _rng.randf_range(-PI, PI)
	var cross := deg_to_rad(_rng.randf_range(30.0, 150.0)) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var land := Vector3(from.x, 0.0, from.z) + Vector3(cos(base), 0.0, sin(base)) * d
	var heading := base + cross
	var t: float = land_time.call(d)
	var dir := Vector3(cos(heading), 0.0, sin(heading))
	return {"land": land, "heading": heading, "at0": land - dir * CRUISE * _pace * t, "turn_sign": -signf(cross), "t": t, "deg": ARC_DEG,
		"pre_speed": CRUISE * _pre_pace, "speed": CRUISE * _pace}


func _rate(case: String, line: Dictionary, tell: float, t: float) -> float:
	var s: float = line["turn_sign"]
	match case:
		"arc":
			return s * deg_to_rad(ARC_DEG) / tell if t < tell else 0.0
		"swerve":
			var end: float = REACT_S + deg_to_rad(line["deg"]) / SWERVE_RATE
			return s * SWERVE_RATE if t >= REACT_S and t < end else 0.0
	return 0.0


# Ticks of the path from -PRE_ROLL to POST_S as [position, velocity]; index PRE is the commit. `y` lifts
# a point onto its ground.
func _path(case: String, line: Dictionary, tell: float, y: Callable) -> Array:
	var pre := int(round(PRE_ROLL / DT))
	var post := int(round(POST_S / DT))
	var out := []
	out.resize(pre + post + 1)
	if case == "stop":
		var rest: Vector3 = line["land"]
		for i in out.size():
			out[i] = [Vector3(rest.x, y.call(rest), rest.z), Vector3.ZERO]
		return out
	var speed: float = line.get("speed", CRUISE)
	var pre_speed: float = line.get("pre_speed", CRUISE)
	var at: Vector3 = line["at0"]
	var h: float = line["heading"]
	out[pre] = [at, Vector3(cos(h), 0.0, sin(h)) * speed]
	for k in range(1, pre + 1):
		h -= _rate(case, line, tell, -k * DT) * DT
		at -= Vector3(cos(h), 0.0, sin(h)) * pre_speed * DT
		out[pre - k] = [at, Vector3(cos(h), 0.0, sin(h)) * pre_speed]
	at = line["at0"]
	h = line["heading"]
	var stop_after: float = line.get("stop_after", INF)
	for k in range(1, post + 1):
		h += _rate(case, line, tell, (k - 1) * DT) * DT
		var rolling: bool = k * DT <= stop_after
		if rolling:
			at += Vector3(cos(h), 0.0, sin(h)) * speed * DT
		out[pre + k] = [at, Vector3(cos(h), 0.0, sin(h)) * speed if rolling else Vector3.ZERO]
	for i in out.size():
		var p: Vector3 = out[i][0]
		out[i][0] = Vector3(p.x, y.call(p), p.z)
	return out


# Feeds the heading record ticks [first, last) of `path`, as combat's observe() would.
func _feed(path: Array, first: int, last: int) -> void:
	for i in range(first, last):
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


# Whether the drawn mark is laid on the ball itself (no lead): a ring centred on it, a lane through it.
func _on_ball(d: Dictionary, ball: Vector3) -> bool:
	var c: Vector3 = d["centre"]
	var flat := Vector3(ball.x - c.x, 0.0, ball.z - c.z)
	if d.get("form", "") == "lane":
		return flat.length() < 0.5 or flat.normalized().dot(d["dir"]) > 0.9999
	return flat.length() < 0.05


# One variant's cases: the main checks, then the swerve shares.
func _judge(v: Dictionary, shares: Dictionary, tells: Array, moved: int, outside: int, unled: int) -> void:
	var name: String = v["name"]
	var tell: float = tells.min()
	_report(name + " tells at least the floor", tell >= ChallengeDials.TELL_FLOOR - 0.0001,
		"tell %.2f s (floor %.2f)" % [tell, ChallengeDials.TELL_FLOOR])
	if tell >= PackPressure.LEAD_TELL_FULL:
		_report(name + " meets a straight line", shares["straight"] >= STRAIGHT_SHARE,
			"%d of %d straight balls hit (at least %d%%)" % [roundi(shares["straight"] * TRIALS), TRIALS, roundi(STRAIGHT_SHARE * 100)])
		_report(name + " without the lead misses it (plant)", shares["straight_none"] < STRAIGHT_SHARE,
			"%d of %d hit with lead_plant none (the check must fall under %d%%)" % [roundi(shares["straight_none"] * TRIALS), TRIALS, roundi(STRAIGHT_SHARE * 100)])
		_report(name + " with a full lead for a turning ball hits it (plant)", shares["arc_full"] > 0.0,
			"%d of %d hit with lead_plant full (the turning check must fail)" % [roundi(shares["arc_full"] * TRIALS), TRIALS])
	elif tell <= PackPressure.LEAD_TELL_NONE + 0.0001:
		_report(name + " lays every mark on the ball (no lead on a cued tell)", unled == TRIALS,
			"%d of %d straight-line marks drawn on the ball; %d of %d hit" % [unled, TRIALS, roundi(shares["straight"] * TRIALS), TRIALS])
	else:
		print("[%s: part lead at a %.2f s tell (report)] %d of %d straight balls hit, %d of %d without the lead"
			% [name, tell, roundi(shares["straight"] * TRIALS), TRIALS, roundi(shares["straight_none"] * TRIALS), TRIALS])
	_report(name + " never leads a ball turning %d degrees in the tell" % ARC_DEG, shares["arc"] == 0.0,
		"%d of %d turning balls hit" % [roundi(shares["arc"] * TRIALS), TRIALS])
	_report(name + " still hits a stopped ball", shares["stop"] == 1.0, "%d of %d stopped balls hit" % [roundi(shares["stop"] * TRIALS), TRIALS])
	_report(name + " lands on the geometry it drew", moved == 0 and outside == 0,
		"%d trials whose drawn geometry moved after the commit, %d hits outside it" % [moved, outside])
	var s30: float = shares["swerve30"]
	var s45: float = shares["swerve45"]
	var detail := "after a 30 degree outward turn %.2f s into a %.2f s tell %d of %d hit; after 45 degrees %d of %d" % [
		REACT_S, tell, roundi(s30 * SWERVE_TRIALS), SWERVE_TRIALS, roundi(s45 * SWERVE_TRIALS), SWERVE_TRIALS]
	if name == "the miniboss's slam, phase 2":
		_report(name + " is escaped by a 45 degree turn made by the middle of its tell", 1.0 - s45 >= 0.9 - 0.0001,
			"%d of %d balls that turned 45 degrees %.2f s into the %.2f s tell escaped (at least 90)" % [roundi((1.0 - s45) * SWERVE_TRIALS), SWERVE_TRIALS, REACT_S, tell])
	print("[%s: the stage's own reading (lead_plant none)] after 30 degrees %d of %d hit, after 45 degrees %d of %d (with the lead: %d and %d)"
		% [name, roundi(shares["swerve30_none"] * SWERVE_TRIALS), SWERVE_TRIALS, roundi(shares["swerve45_none"] * SWERVE_TRIALS), SWERVE_TRIALS,
			roundi(s30 * SWERVE_TRIALS), roundi(s45 * SWERVE_TRIALS)])
	var ceiling: float = SWERVE_30_MAX.get(name, 0.0)
	_report(name + " catches at most %d%% of balls that turn 30 degrees after the commit" % roundi(ceiling * 100), s30 <= ceiling + 0.0001, detail)


# Runs every case of a variant. `trial` takes (case, line) and returns {hit, moved, outside, tell, unled};
# `line_for` makes a line with the shared RNG.
func _cases(v: Dictionary, trial: Callable, line_for: Callable) -> void:
	var shares := {}
	var tells := []
	var moved := 0
	var outside := 0
	var unled := 0
	for case in ["straight", "straight_none", "arc", "arc_full", "stop"]:
		_rng.seed = SEED
		PackPressure.lead_plant = "none" if case == "straight_none" else ("full" if case == "arc_full" else "")
		var hit := 0
		for i in TRIALS:
			var line: Dictionary = line_for.call()
			var r: Dictionary = trial.call(case.trim_suffix("_none").trim_suffix("_full"), line)
			hit += 1 if r["hit"] else 0
			moved += r["moved"]
			outside += r["outside"]
			tells.append(r["tell"])
			if case == "straight" and r["unled"]:
				unled += 1
		shares[case] = float(hit) / TRIALS
	PackPressure.lead_plant = ""
	for deg in [30.0, 45.0]:
		var hit := 0
		for s in SWERVE_SEEDS:
			_rng.seed = s
			for i in SWERVE_TRIALS / SWERVE_SEEDS.size():
				var line: Dictionary = line_for.call()
				line["deg"] = deg
				var r: Dictionary = trial.call("swerve", line)
				hit += 1 if r["hit"] else 0
				moved += r["moved"]
				outside += r["outside"]
		shares["swerve%d" % int(deg)] = float(hit) / SWERVE_TRIALS
	PackPressure.lead_plant = "none"
	for deg in [30.0, 45.0]:
		var hit := 0
		for s in SWERVE_SEEDS:
			_rng.seed = s
			for i in SWERVE_TRIALS / SWERVE_SEEDS.size():
				var line: Dictionary = line_for.call()
				line["deg"] = deg
				hit += 1 if trial.call("swerve", line)["hit"] else 0
		shares["swerve%d_none" % int(deg)] = float(hit) / SWERVE_TRIALS
	PackPressure.lead_plant = ""
	_judge(v, shares, tells, moved, outside, unled)


# --- The heading record and the travel solve -----------------------------------------------

# A hit stop (Engine.time_scale 0.05) keeps ticks coming at the real rate, each a twentieth as long. The
# record must count game time: a ball that was turning and is frozen by a stop is still unsteady after
# it. Control: the same ticks at full speed fill the record with the frozen heading, and it is led.
func _hit_stop_check() -> void:
	var held := {}
	for scale in [0.05, 1.0]:
		await physics_frame
		var turning := Vector3(CRUISE, 0.0, 0.0)
		PackPressure.observe(turning, CRUISE)
		var h := 0.0
		for i in 120:
			h += deg_to_rad(30.0) * DT
			PackPressure.observe_tick(Vector3(cos(h), 0.0, sin(h)) * CRUISE, DT, CRUISE)
		var frozen := Vector3(cos(h), 0.0, sin(h)) * CRUISE
		Engine.time_scale = scale
		for i in 110:
			await physics_frame
			PackPressure.observe(frozen, CRUISE)
		Engine.time_scale = 1.0
		_roller.at = Vector3.ZERO
		_roller.v = frozen
		held[scale] = PackPressure.lead_aim(_roller, Vector3(-20.0, 0.0, 0.0), 1.4) != _roller.at
	_report("a hit stop does not make a turning ball look steady", not held[0.05] and held[1.0],
		"led after 110 hit-stop ticks %s (must be false); led after 110 full-speed ticks %s (control, must be true)" % [held[0.05], held[1.0]])


# A FAST or BLAZING ball can outrun Brindle's 24 m/s charge, so its travel solve cannot settle: it is not
# led. A ring that lands all at once still leads it.
func _fast_ball_check() -> void:
	var speed: float = SpeedTier.MULTIPLES[SpeedTier.BLAZING] * CRUISE + 1.0
	var v := Vector3(0.0, 0.0, speed)
	for i in 120:
		PackPressure.observe_tick(v, DT, CRUISE, i == 0)
	_roller.at = Vector3.ZERO
	_roller.v = v
	var lane := PackPressure.lead_aim(_roller, Vector3(-20.0, 0.0, 0.0), 1.4, Rules.CHARGE_SPEED, 8.5)
	var ring := PackPressure.lead_aim(_roller, Vector3(-20.0, 0.0, 0.0), 1.4)
	_report("a ball faster than a charge is not led by it", lane == _roller.at and ring != _roller.at,
		"a %.1f m/s ball (BLAZING is %.1f, the charge %.0f): the charge aims %.1f m from it, a ring %.1f m"
			% [speed, SpeedTier.MULTIPLES[SpeedTier.BLAZING] * CRUISE, Rules.CHARGE_SPEED, lane.distance_to(_roller.at), ring.distance_to(_roller.at)])


# --- The rogue crane and the miniboss ----------------------------------------------------

func _enemy_variants() -> Array:
	return [
		{"name": "the gate crane's sweep", "kind": "rogue_crane", "attack": 0, "lane": true, "phase": 1},
		{"name": "the gate crane's sweep, phase 2", "kind": "rogue_crane", "attack": 0, "lane": true, "phase": 2},
		{"name": "the gate crane's drop", "kind": "rogue_crane", "attack": 1, "lane": false, "phase": 1},
		{"name": "the gate crane's drop, phase 2", "kind": "rogue_crane", "attack": 1, "lane": false, "phase": 2},
		{"name": "the miniboss's slam", "kind": "miniboss", "attack": 0, "lane": false, "phase": 1},
		{"name": "the miniboss's slam, phase 2", "kind": "miniboss", "attack": 0, "lane": false, "phase": 2},
		{"name": "the miniboss's charge", "kind": "miniboss", "attack": 1, "lane": true, "phase": 1},
		{"name": "the miniboss's charge, phase 2", "kind": "miniboss", "attack": 1, "lane": true, "phase": 2},
		{"name": "the miniboss's cued charge", "kind": "miniboss", "attack": 1, "lane": true, "phase": 2, "cued": true},
	]


func _spawn(v: Dictionary):
	var from := _origin(v)
	var enemy = _game.ctx.spawner.spawn_enemy(v["kind"], from)
	enemy.set_physics_process(false)
	enemy.terrain = FlatTerrain.new()
	enemy.target = _roller
	enemy.live = func(): return true
	enemy.hit_player.connect(_on_hit)
	if v["phase"] >= 2:
		enemy.enter_phase(2)
	return enemy


func _origin(v: Dictionary) -> Vector3:
	var half: float = Miniboss.HALF_HEIGHT if v["kind"] == "miniboss" else float(Rogue.ROWS["rogue_crane"].half_height)
	return Vector3(0.0, STAGE_Y + half + 0.05, 0.0)


func _variant(v: Dictionary) -> void:
	var enemy = _spawn(v)
	var tell := _enemy_tell(enemy, v)
	var reach := _enemy_reach(enemy, v, tell)
	var from := _origin(v)
	_cases(v, func(case: String, line: Dictionary) -> Dictionary: return _enemy_trial(enemy, v, case, line, tell),
		func() -> Dictionary: return _line(from, reach["min"], reach["max"], reach["time"]))
	enemy.free()


# The tell the enemy commits with, read from a dry commit: wind (lane) or wind and strike (ring) for the
# crane; crouch and leap for the slam; the brace for the charge, through the cue for the cued one.
func _enemy_tell(enemy, v: Dictionary) -> float:
	var rest := _origin(v) + Vector3(15.0, 0.0, 0.0)
	var still := []
	for i in 90:
		still.append([rest, Vector3.ZERO])
	_commit(enemy, v, still, still.size() - 1)
	var tell: float
	if v["kind"] == "rogue_crane":
		tell = enemy._seconds("wind") + (0.0 if v["lane"] else enemy._seconds("strike"))
	elif v["attack"] == 0:
		tell = enemy.slam_crouch + Miniboss.SLAM_LEAP
	else:
		tell = enemy.charge_brace
	enemy._clear_telegraph()
	return tell


# Commits the variant's attack with the ball on path[at]: by hand, or through the cue for a cued
# charge, whose ticks run on the path just before `at`. Returns the path index of the commit.
func _commit(enemy, v: Dictionary, path: Array, at: int) -> int:
	enemy._clear_telegraph()
	enemy.global_position = _origin(v)
	enemy.velocity = Vector3.ZERO
	if v["kind"] == "rogue_crane":
		enemy._next = v["attack"]
		enemy._enter(Rogue.State.STALK)
	else:
		enemy._next_attack = v["attack"]
		enemy._enter(Miniboss.State.STALK)
	if v.get("cued", false):
		var cue := int(ceil(FightPhases.CUE_LEAD / DT))
		var k := maxi(0, at - cue)
		enemy._enter(Miniboss.State.CUE)
		while enemy.state == Miniboss.State.CUE and k < path.size():
			_roller.at = path[k][0]
			_roller.v = path[k][1]
			PackPressure.observe_tick(_roller.v, DT, CRUISE)
			enemy._physics_process(DT)
			k += 1
		return k - 1
	_roller.at = path[at][0]
	_roller.v = path[at][1]
	var to_ball: Vector3 = _roller.at - enemy.global_position
	to_ball.y = 0.0
	enemy._begin_attack(to_ball)
	return at


func _enemy_reach(enemy, v: Dictionary, tell: float) -> Dictionary:
	if not v["lane"]:
		return {"min": 8.0, "max": 30.0, "time": func(_d: float) -> float: return tell}
	if v["kind"] == "rogue_crane":
		var a: Dictionary = Rogue.ATTACKS["sweep"]
		var length: float = float(a.length) * enemy.site_scale
		var swing: float = 2.0 * length / (float(a.strike) * enemy.beat())
		return {"min": 6.0, "max": 0.8 * length, "time": func(d: float) -> float: return tell + d / swing}
	var speed := Miniboss.CHARGE_LENGTH / Miniboss.CHARGE_TIME
	return {"min": 6.0, "max": 0.8 * Miniboss.CHARGE_LENGTH, "time": func(d: float) -> float: return tell + d / speed}


func _flat_y(_p: Vector3) -> float:
	return STAGE_Y + 1.0


func _enemy_trial(enemy, v: Dictionary, case: String, line: Dictionary, tell: float) -> Dictionary:
	var path := _path(case, line, tell, _flat_y)
	var pre := int(round(PRE_ROLL / DT))
	var cue := int(ceil(FightPhases.CUE_LEAD / DT)) if v.get("cued", false) else 0
	_feed(path, 0, pre - cue)
	var at := _commit(enemy, v, path, pre)
	var shown = enemy.telegraph()
	_drawn = shown.descriptor() if shown != null else {}
	var out := {"hit": false, "moved": 0, "outside": 0, "tell": tell, "unled": not _drawn.is_empty() and _on_ball(_drawn, path[at][0])}
	var drawn := _geometry(_drawn)
	_hits = 0
	_hits_outside = 0
	var rest := {"stopped": false}
	for k in range(at + 1, path.size()):
		var tick: Array = _meet_body(rest, path[k], enemy.global_position, float(line.get("contact", 0.0)), enemy.half_height)
		_roller.at = tick[0]
		_roller.v = tick[1]
		PackPressure.observe_tick(_roller.v, DT, CRUISE)
		enemy._physics_process(DT)
		shown = enemy.telegraph()
		if shown != null and _geometry(shown.descriptor()) != drawn:
			out["moved"] = 1
		if enemy.state_name() in ["weak", "stalk", "cue"]:
			break
	_drawn = {}
	out["hit"] = _hits > 0
	out["outside"] = _hits_outside
	return out


# A rolling ball cannot pass through the attacker: the tick `nominal` ([position, velocity] as if it rolled on)
# puts it within `contact` of the attacker where it is at that tick, the ball stops against it and stays
# there. The body has height: a ball passes under one that has leapt more than its half height plus the
# ball's radius clear of it. `rest` carries the stop between ticks. A `contact` of 0 leaves the ball rolling.
func _meet_body(rest: Dictionary, nominal: Array, body: Vector3, contact: float, half_height: float) -> Array:
	if contact <= 0.0:
		return nominal
	var p: Vector3 = nominal[0]
	if not rest["stopped"]:
		var off := Vector3(p.x - body.x, 0.0, p.z - body.z)
		if off.length() >= contact or absf(p.y - body.y) >= half_height + Tuning.RADIUS:
			return nominal
		rest["stopped"] = true
		var away := off.normalized() if off.length() > 0.01 else Vector3.RIGHT
		rest["at"] = Vector3(body.x + away.x * contact, p.y, body.z + away.z * contact)
	return [rest["at"], Vector3.ZERO]


func _on_hit(_amount: float, _shove: Vector3) -> void:
	_hits += 1
	if not _drawn.is_empty() and not _inside(_drawn, _roller.at):
		_hits_outside += 1


# The slam's leap sets the body's position with no collision check, so a led slam must stop short of a
# wall across the ball's line, and fall back to the ball where the led point is off the stage.
func _slam_reach_checks() -> void:
	var v := {"name": "the miniboss's slam", "kind": "miniboss", "attack": 0, "lane": false, "phase": 1}
	var enemy = _spawn(v)
	var tell := _enemy_tell(enemy, v)
	# A straight line across the stage, +x, committed 12 m from the miniboss; a straight ball lands 19.6 m on.
	var line := {"at0": Vector3(-10.0, 0.0, 12.0), "heading": 0.0, "turn_sign": 1.0, "deg": ARC_DEG, "land": Vector3(-10.0 + CRUISE * tell, 0.0, 12.0)}
	var wall_x := -10.0 + CRUISE * tell * 0.5
	var wall := _box(Vector3(wall_x, STAGE_Y + 3.0, 12.0), Vector3(1.0, 6.0, 20.0))
	await physics_frame
	await physics_frame
	var r := _slam_once(enemy, v, line, tell)
	var limit := wall_x - 0.5 - Miniboss.LEAP_CLEAR
	_report("a led slam stops short of a wall across the line", r["centre"].x <= limit + 0.01 and r["centre"].x > -10.0 + 0.5 and r["body"].x <= wall_x - 0.5,
		"wall face at x %.1f; ring centre x %.2f (at most %.2f, past the ball's %.1f); body landed at x %.2f" % [wall_x - 0.5, r["centre"].x, limit, -10.0, r["body"].x])
	wall.queue_free()
	# A stage edge: the line runs from this slab toward open air.
	var island := _box(Vector3(400.0, STAGE_Y - 1.0, 12.0), Vector3(16.0, 2.0, 16.0))
	await physics_frame
	await physics_frame
	var from_edge := Vector3(400.0 - 4.0, 0.0, 12.0)
	var edge_line := {"at0": from_edge, "heading": 0.0, "turn_sign": 1.0, "deg": ARC_DEG, "land": from_edge + Vector3(CRUISE * tell, 0.0, 0.0)}
	enemy.global_position = Vector3(400.0, STAGE_Y + Miniboss.HALF_HEIGHT, 4.0)
	var e := _slam_once(enemy, v, edge_line, tell, Vector3(400.0, STAGE_Y + Miniboss.HALF_HEIGHT, 4.0))
	_report("a slam led off the stage falls back to the ball", e["on_ball"],
		"the led point is %.1f m past the edge; ring centre %.2f m from the ball at the commit" % [from_edge.x + CRUISE * tell - 408.0, e["off"]])
	island.queue_free()
	enemy.free()


func _slam_once(enemy, v: Dictionary, line: Dictionary, tell: float, origin = null) -> Dictionary:
	var path := _path("straight", line, tell, _flat_y)
	var pre := int(round(PRE_ROLL / DT))
	_feed(path, 0, pre)
	_commit(enemy, v, path, pre)
	if origin != null:
		enemy.global_position = origin
	var ring = enemy.telegraph()
	var centre: Vector3 = ring.center
	var ball: Vector3 = path[pre][0]
	for k in range(pre + 1, path.size()):
		_roller.at = path[k][0]
		_roller.v = path[k][1]
		enemy._physics_process(DT)
		if enemy.state_name() in ["weak", "stalk", "cue"]:
			break
	var off := Vector2(centre.x - ball.x, centre.z - ball.z).length()
	return {"centre": centre, "body": enemy.global_position, "on_ball": off < 0.05, "off": off}


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
		_game.run.heal(1000.0)
		_place(centre + Vector3.UP, Vector3.ZERO)
		boss.advance(DT)
		if not boss._in_transition() and boss._charge.get("state", "") == boss.CHARGE_REST:
			break
	var nose: float = Requisition.HULL.z * 0.5 + boss.CHARGE_REACH
	for v in [
		{"name": "Brindle's charge", "lane": true, "hold": boss.CHARGE_REST, "tell": ChallengeDials.tell("brindle", Rules.CHARGE_WARN, Hazard.MIN_WARN)},
		{"name": "Brindle's hook turn", "lane": true, "hold": boss.CHARGE_HOOK, "tell": FightPhases.CUED_WARN},
	]:
		var tell: float = v["tell"]
		_cases(v, func(case: String, line: Dictionary) -> Dictionary: return _brindle_trial(boss, v, case, line),
			func() -> Dictionary: return _bowl_line(boss, centre, tell, nose))
	_bank_check(boss, centre)
	_brindle_scenarios(boss, centre, nose)
	_bank_stun_check(boss, centre)
	_rest_at_bank_check(boss, centre)
	boss.set_physics_process(true)


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
	_feed(path, 0, pre)
	boss._charge = {"state": hold, "timer": 0.5 * DT}
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


# --- A ball that rolls at the attacker, and a ball at other speeds ------------------------------

const HEAD_ON_FROM := [12.0, 16.0]
const SLAM_HEAD_ON_FROM := [6.0, 9.0]
const HEAD_ON_OFF_DEG := [0.0, 10.0, -10.0]
# The ball's speed as a share of cruise before the commit and from it, and when it stops (seconds after the
# commit, INF for never).
const PACES := [["50% of cruise", 0.5, 0.5, INF], ["80% of cruise", 0.8, 0.8, INF],
	["braking from cruise to 60% at the commit", 1.0, 0.6, INF], ["stopping dead 0.25 s after the commit", 1.0, 1.0, 0.25]]
# The attacks whose head-on and pace counts are asserted (the rest are printed): each must hit every head-on
# ball, and at STRAIGHT_SHARE or more of the balls at 50% and 80% of cruise and braking at the commit.
const HEAD_ON_ASSERTED := ["the miniboss's slam", "the miniboss's charge", "Brindle's charge"]
const PACE_ASSERTED := ["the miniboss's slam", "Brindle's charge"]


func _head_on_line(from: Vector3, dist: float, off_deg: float, contact: float) -> Dictionary:
	var base := 0.7
	var at := Vector3(from.x, 0.0, from.z) + Vector3(cos(base), 0.0, sin(base)) * dist
	return {"at0": at, "heading": base + PI + deg_to_rad(off_deg), "turn_sign": 1.0, "deg": ARC_DEG, "land": at,
		"contact": contact, "pre_speed": CRUISE, "speed": CRUISE}


# One attack's head-on and pace counts, led and with lead_plant "none" (what the stage did). `prepare` runs
# before each trial and returns where the attacker is; `pace_line` makes a line with the shared RNG and
# the pace members; `hit` runs a line and says whether the ball was hit.
func _scenarios(name: String, contact: float, prepare: Callable, pace_line: Callable, hit: Callable) -> void:
	# The slam's body leaves its spot 0.5 s in and is airborne after, so a ball only meets it standing
	# on the ground if it starts within SLAM_HEAD_ON_FROM; the 12 m and 16 m balls are printed (they roll
	# under the leaping body).
	var asserted: Array = SLAM_HEAD_ON_FROM if name.begins_with("the miniboss's slam") else HEAD_ON_FROM
	for dists in ([asserted] if asserted == HEAD_ON_FROM else [asserted, HEAD_ON_FROM]):
		var head_on := {}
		var total := 0
		for plant in ["", "none"]:
			PackPressure.lead_plant = plant
			var n := 0
			total = 0
			var missed := []
			for dist in dists:
				for off in HEAD_ON_OFF_DEG:
					total += 1
					var from: Vector3 = prepare.call()
					if hit.call(_head_on_line(from, dist, off, contact)):
						n += 1
					else:
						missed.append("%d m %+d deg" % [dist, off])
			head_on[plant] = n
			if plant == "" and dists == asserted and name in HEAD_ON_ASSERTED:
				_report(name + " hits a ball rolling at it", n == total, "%d of %d head-on balls hit (from %s m); missed %s" % [n, total, dists, missed])
		print("[%s head-on from %s m, 0 and 10 degrees off, stopping against the body] %d of %d hit with the lead, %d of %d with lead_plant none (the stage)"
			% [name, dists, head_on[""], total, head_on["none"], total])
	for pace in PACES:
		_pre_pace = pace[1]
		_pace = pace[2]
		var counts := {}
		for plant in ["", "none"]:
			PackPressure.lead_plant = plant
			_rng.seed = SEED
			var n := 0
			for i in TRIALS:
				prepare.call()
				var line: Dictionary = pace_line.call()
				line["stop_after"] = pace[3]
				if hit.call(line):
					n += 1
			counts[plant] = n
		if name in PACE_ASSERTED and pace[3] == INF:
			_report("%s hits a ball %s" % [name, pace[0]], counts[""] >= int(STRAIGHT_SHARE * TRIALS),
				"%d of %d straight balls hit (at least %d%%)" % [counts[""], TRIALS, roundi(STRAIGHT_SHARE * 100)])
		print("[%s, a ball %s] %d of %d hit with the lead, %d of %d with lead_plant none (the stage)" % [name, pace[0], counts[""], TRIALS, counts["none"], TRIALS])
	PackPressure.lead_plant = ""
	_pre_pace = 1.0
	_pace = 1.0


func _enemy_scenarios() -> void:
	for v in _enemy_variants():
		var enemy = _spawn(v)
		var tell := _enemy_tell(enemy, v)
		var reach := _enemy_reach(enemy, v, tell)
		var from := _origin(v)
		var contact: float = Miniboss.BODY_CONTACT if v["kind"] == "miniboss" else enemy.radius + Tuning.RADIUS
		_scenarios(v["name"], contact, func() -> Vector3: return from,
			func() -> Dictionary: return _line(from, reach["min"], reach["max"], reach["time"]),
			func(line: Dictionary) -> bool: return _enemy_trial(enemy, v, "straight", line, tell)["hit"])
		enemy.free()


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
		_feed(path, 0, pre)
		boss._charge = {"state": boss.CHARGE_REST, "timer": 0.5 * DT}
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
