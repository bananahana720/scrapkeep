extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Hazard := preload("res://src/boss/hazard.gd")

# The Scuttle's charge wind-up never flings the ball. A charge aims at the ball, and the hull
# used to take that heading in one tick: a 14 m kinematic box that swings 90 degrees in a
# ninetieth of a second hits a ball resting beside it at hundreds of metres a second (the
# speedrunner red team saw 259 to 500 m/s in 4 of 18 runs). The hull now turns to its lane
# inside the tell, no faster than its own charge moves, and is square in the lane before the
# lane can hurt.
#
# Each case puts the ball beside the hull, on the real rigid ball and physics, lets a charge
# commit, and reads the whole tell: the ball's speed and its largest one-tick change, the
# hull's turn per tick, and the hull's heading when the lane goes live. The hook case does
# the same for the cued follow-up charge, whose tell is the short one, and the last case
# asks a full reverse inside the shortest tell a dial allows.
#
# Evidence limit: the ball is unsteered and the dials are the defaults; a pilot's latch on
# the hull is not driven here.

# The red team's fling monitor: a one-tick speed change over this is a kick.
const KICK := 40.0
# A turning hull may bat the ball about as hard as the charge itself would carry it.
const SHOVE_CEILING := Rules.CHARGE_SPEED * 1.5
const SQUARE := 0.01
# Where the ball waits, in the hull's own frame: x metres to starboard and z metres toward the
# bow from the ship's centre. The hull is 9 m by 14 m and the ball 1 m in radius. A leaning ball
# is pressed on the flank the whole time, as a pilot rolling into the hull is: the old snap
# drove the flank ahead of the centre into it at the hull's one-tick turn rate (the kick). A
# ball amidships was swallowed whole instead, and sat inside the hull until the charge left.
const PRESS := 25.0
const SPOTS := [
	{"name": "leaning on the starboard flank ahead of the centre", "x": 5.52, "z": 3.5, "lean": true},
	{"name": "leaning on the port flank by the bow", "x": -5.52, "z": 6.0, "lean": true},
	{"name": "leaning on the starboard flank amidships", "x": 5.52, "z": 0.0, "lean": true},
	{"name": "resting off the port flank", "x": -7.5, "z": 0.0, "lean": false},
	{"name": "resting off the starboard quarter", "x": 5.7, "z": -6.0, "lean": false},
	{"name": "resting dead astern", "x": 0.0, "z": -8.4, "lean": false},
]

var _game
var _boss
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _starboard() -> Vector3:
	return (_boss.ship.heading as Vector3).rotated(Vector3.UP, -PI * 0.5)


func _spot(spot: Dictionary) -> Vector3:
	var at: Vector3 = _boss.ship.global_position + _boss.ship.heading * spot["z"] + _starboard() * spot["x"]
	return Vector3(at.x, _boss.arena.ground(at) + Tuning.RADIUS + 0.02, at.z)


func _yaw_between(a: Vector3, b: Vector3) -> float:
	return absf(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))


# Holds the ball at `spot` while the charge is in its waiting state, then watches the tell of
# the charge that commits next. A resting ball is set there every tick; a leaning one is set
# there once and pressed on the flank from then on, through the tell too. `cued` waits for the
# hook turn's charge instead of the lead.
func _watch(spot: Dictionary, cued: bool) -> Dictionary:
	var out := {"committed": false, "turn": 0.0, "speed": 0.0, "kick": 0.0, "step": 0.0, "residual": -1.0,
		"aimed": -1.0, "ticks": 0, "square_at": -1.0, "warn": 0.0, "inside": false}
	var lane = null
	var last_v := Vector3.ZERO
	var last_heading: Vector3 = _boss.ship.heading
	var hold: String = _boss.CHARGE_HOOK if cued else _boss.CHARGE_REST
	var placed := false
	var press := Vector3.ZERO
	for i in 90 * 14:
		var state: String = _boss._charge.get("state", "")
		if lane == null and state == hold and not (placed and spot["lean"]):
			Harness.put_ball(_game, _spot(spot))
			last_v = Vector3.ZERO
			placed = true
			press = -_starboard() * signf(spot["x"]) * PRESS
		if placed and spot["lean"]:
			_game.player.add_external_accel(press)
		last_heading = _boss.ship.heading
		await physics_frame
		state = _boss._charge.get("state", "")
		if lane == null:
			if state == _boss.CHARGE_BRACE and bool(_boss._charge.get("cued", false)) == cued:
				lane = _boss._charge["hazard"]
				out["committed"] = true
				out["warn"] = lane.warn_seconds
				out["turn"] = _yaw_between(last_heading, lane.heading)
				var ball: Vector3 = _game.player.ball_position()
				var to_ball := Vector3(ball.x - lane.centre.x, 0.0, ball.z - lane.centre.z)
				out["aimed"] = _yaw_between(to_ball, lane.heading)
			else:
				last_v = _game.player.state.velocity
				continue
		var v: Vector3 = _game.player.state.velocity
		out["speed"] = maxf(out["speed"], v.length())
		out["kick"] = maxf(out["kick"], (v - last_v).length())
		last_v = v
		out["step"] = maxf(out["step"], _yaw_between(last_heading, _boss.ship.heading))
		out["ticks"] += 1
		if out["square_at"] < 0.0 and _yaw_between(_boss.ship.heading, lane.heading) <= SQUARE:
			out["square_at"] = lane.age
		if not is_instance_valid(lane) or lane.is_live() or state != _boss.CHARGE_BRACE:
			out["residual"] = _yaw_between(last_heading, _boss._charge.get("heading", last_heading))
			break
	var local: Vector3 = _boss.ship.hull.to_local(_game.player.ball_position())
	var half := Requisition.HULL * 0.5
	out["inside"] = absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z
	return out


# `rate` is the turn rate the case may reach: the rule's, or what a short tell forces.
func _judge(label: String, r: Dictionary, min_turn: float, rate := Rules.CHARGE_TURN_RATE) -> void:
	var cap: float = rate / 90.0
	_report(label, r["committed"] and r["turn"] >= min_turn and r["aimed"] <= 0.02 and r["kick"] <= KICK and r["speed"] <= SHOVE_CEILING
			and r["residual"] >= 0.0 and r["residual"] <= SQUARE and r["square_at"] >= 0.0 and r["square_at"] < r["warn"]
			and r["step"] <= cap * 1.05 and not r["inside"],
		"the lane aimed %.3f rad off the ball and asked a %.0f degree turn inside a %.2f s tell; the hull turned at most %.2f degrees a tick (rate cap %.2f), was square in its lane at %.2f s and %.4f rad off it when the lane went live; the ball's top speed was %.1f m/s (ceiling %.0f), its largest one-tick change %.1f m/s (a kick is %.0f), and it ended inside the hull %s"
			% [r["aimed"], rad_to_deg(r["turn"]), r["warn"], rad_to_deg(r["step"]), rad_to_deg(cap), r["square_at"], r["residual"], r["speed"],
				SHOVE_CEILING, r["kick"], KICK, r["inside"]])


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_boss = _game.boss
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	for spot in SPOTS:
		_game.flow.retry_stage()
		_game.run.heal(1000.0)
		_boss.jump_to_phase(3)
		var r: Dictionary = await _watch(spot, false)
		_judge("a ball %s is not flung by the wind-up" % spot["name"], r, absf(atan2(spot["x"], spot["z"])) - 0.2)
	await _hook_check()
	await _short_tell_check()
	var corner := Vector2(Requisition.HULL.x, Requisition.HULL.z).length() * 0.5
	_report("no corner of the turning hull outruns the charge", Rules.CHARGE_TURN_RATE * corner <= Rules.CHARGE_SPEED,
		"%.2f rad/s at the %.2f m corner is %.1f m/s (charge %.0f m/s)" % [Rules.CHARGE_TURN_RATE, corner, Rules.CHARGE_TURN_RATE * corner, Rules.CHARGE_SPEED])
	ChallengeDials.reset()
	print("brindle_charge_turn_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# The hook turn: a lead charge that ends short of the rim is answered by a cued charge with the
# short tell. The ball waits mid-bowl ahead of the hull so the lead overshoots it and stops
# short, then leans on the stopped hull's flank through the cue.
func _hook_check() -> void:
	_game.flow.retry_stage()
	_game.run.heal(1000.0)
	_boss.jump_to_phase(3)
	var ship = _boss.ship
	var centre: Vector3 = _boss.arena.global_position
	var inward := Vector3(centre.x - ship.global_position.x, 0.0, centre.z - ship.global_position.z).normalized()
	var bait: Vector3 = ship.global_position + inward * 12.0
	bait.y = _boss.arena.ground(bait) + Tuning.RADIUS + 0.05
	var lead := false
	for i in 90 * 10:
		var state: String = _boss._charge.get("state", "")
		if state == _boss.CHARGE_REST:
			Harness.put_ball(_game, bait)
		elif state == _boss.CHARGE_BRACE:
			lead = true
			# Clear of the lane before it runs: the hook turn is the case, not the hit.
			Harness.put_ball(_game, bait + Vector3.UP * 40.0)
		elif state == _boss.CHARGE_RUN:
			Harness.put_ball(_game, bait + Vector3.UP * 40.0)
		elif state == _boss.CHARGE_HOOK:
			break
		await physics_frame
	_report("the lead charge stopped short and cued its hook turn", lead and _boss._charge.get("state", "") == _boss.CHARGE_HOOK,
		"lead committed %s, charge state %s" % [lead, _boss._charge.get("state", "")])
	if _boss._charge.get("state", "") != _boss.CHARGE_HOOK:
		return
	var r: Dictionary = await _watch(SPOTS[0], true)
	_judge("a ball %s through the hook turn's cue is not flung" % SPOTS[0]["name"], r, 0.0)
	_report("the hook turn's tell is the short one", r["committed"] and is_equal_approx(r["warn"], FightPhases.CUED_WARN),
		"cued tell %.2f s (CUED_WARN %.2f)" % [r["warn"], FightPhases.CUED_WARN])


# The shortest lead tell a dial can ask is Hazard.MIN_WARN. A full reverse does not fit in it
# at the rule's rate, so the hull turns as much faster as it takes to be square in the lane
# before it goes live: it is never late, and the ball still only takes a shove.
func _short_tell_check() -> void:
	ChallengeDials.set_overrides({"brindle.tell_mult": 0.1})
	_game.flow.retry_stage()
	_game.run.heal(1000.0)
	_boss.jump_to_phase(3)
	var astern: Dictionary = SPOTS[SPOTS.size() - 1]
	var r: Dictionary = await _watch(astern, false)
	var forced: float = PI / (Hazard.MIN_WARN - Rules.CHARGE_TURN_SETTLE)
	_judge("a full reverse inside the shortest tell is square in time and still no fling", r, PI - 0.2, forced)
	_report("the shortest tell forced a faster turn than the rule's rate", r["committed"] and is_equal_approx(r["warn"], Hazard.MIN_WARN)
			and r["step"] > Rules.CHARGE_TURN_RATE / 90.0,
		"tell %.2f s, largest turn %.2f degrees a tick (the rule's rate is %.2f)" % [r["warn"], rad_to_deg(r["step"]), rad_to_deg(Rules.CHARGE_TURN_RATE / 90.0)])
	ChallengeDials.reset()
