extends RefCounted

const Rules := preload("res://src/boss/boss_rules.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")

const CHARGE_REACH := 1.5
const CHARGE_RIM_CLEAR := 1.0
const CHARGE_MIN_LANE := 4.0
const CHARGE_REST := "rest"
const CHARGE_BRACE := "brace"
const CHARGE_RUN := "run"
const CHARGE_RECOVER := "recover"
const CHARGE_STUN := "stun"
const CHARGE_HOOK := "hook"

var charge := {}
var hook_token := 0
var ghost_until := -1.0
var short_tries := 0
var scuttle_punch := 0.0
var hint_next := 0.0


func reset() -> void:
	charge = {}
	ghost_until = -1.0


func enter_phase() -> void:
	short_tries = 0
	scuttle_punch = 0.0
	hint_next = 0.0
	charge = {"state": CHARGE_REST, "timer": ChallengeDials.period("brindle", Rules.CHARGE_REST, 3)}


func step(boss, delta: float, ball: Vector3) -> void:
	scuttle_punch = maxf(scuttle_punch, boss.ctx.flow.punch_now())
	match charge.get("state", CHARGE_REST):
		CHARGE_REST, CHARGE_RECOVER, CHARGE_STUN, CHARGE_HOOK:
			if charge["state"] == CHARGE_HOOK:
				if boss.reel_plant_mode() != "no_brace" and not boss.ship.bracing():
					boss.ship.set_hook_brace(true, hook_token)
				turn_ship(boss, aim_at(boss, ball), Rules.CHARGE_TURN_RATE, delta)
			if charge["state"] == CHARGE_STUN:
				boss.note_commit()
			charge["timer"] -= delta
			if charge["state"] == CHARGE_REST and boss.reeling() and boss.reel_plant_mode() != "stop" and not boss.in_transition() \
					and boss.last_commit_at() >= 0.0 and boss.clock + float(charge["timer"]) - boss.last_commit_at() > Rules.REEL_MAX_GAP:
				charge["timer"] = maxf(0.0, boss.last_commit_at() + Rules.REEL_MAX_GAP - boss.clock)
			if charge["timer"] <= 0.0:
				if charge["state"] == CHARGE_REST:
					if boss.in_transition() or (boss.reeling() and boss.reel_plant_mode() == "stop"):
						return
					commit_charge(boss)
				elif charge["state"] == CHARGE_HOOK:
					commit_charge(boss, true)
				else:
					charge = {"state": CHARGE_REST, "timer": boss.rest_time_now()}
		CHARGE_BRACE:
			var h = charge.get("hazard")
			if h == null or not is_instance_valid(h) or h.is_done():
				charge = {"state": CHARGE_REST, "timer": boss.rest_time_now()}
				return
			brace_turn(boss, delta)
			if h.is_live():
				charge["state"] = CHARGE_RUN
		CHARGE_RUN:
			run_charge(boss, delta, ball)
		_:
			push_error("brindle charge in unknown state %s" % charge.get("state"))
			charge = {"state": CHARGE_REST, "timer": boss.rest_time_now()}


func aim_at(boss, ball: Vector3) -> Vector3:
	var to_ball := Vector3(ball.x - boss.ship.global_position.x, 0.0, ball.z - boss.ship.global_position.z)
	return to_ball.normalized() if to_ball.length() > 2.0 else boss.ship.heading


func turn_ship(boss, heading: Vector3, rate: float, delta: float) -> void:
	var owed := Vector2(boss.ship.heading.x, boss.ship.heading.z).angle_to(Vector2(heading.x, heading.z))
	var step_ang := clampf(owed, -rate * delta, rate * delta)
	var arrives := absf(owed - step_ang) < Rules.CHARGE_TURN_SNAP
	boss.ship.move_to(boss.ship.global_position, heading if arrives else (boss.ship.heading as Vector3).rotated(Vector3.UP, -step_ang))


func brace_turn(boss, delta: float) -> void:
	var h = charge["hazard"]
	var heading: Vector3 = charge["heading"]
	var owed := absf(Vector2(boss.ship.heading.x, boss.ship.heading.z).angle_to(Vector2(heading.x, heading.z)))
	if owed <= 0.0:
		return
	var time_left := maxf(delta, h.warn_seconds - h.age - Rules.CHARGE_TURN_SETTLE)
	turn_ship(boss, heading, maxf(Rules.CHARGE_TURN_RATE, owed / time_left), delta)


func commit_charge(boss, cued := false) -> void:
	if not cued:
		boss.step_combo()
	var from: Vector3 = boss.ship.global_position
	var half: float = boss.Requisition.HULL.z * 0.5
	var warn := FightPhases.CUED_WARN if cued else ChallengeDials.tell("brindle", Rules.CHARGE_WARN, boss.Hazard.MIN_WARN)
	var ball: Vector3 = boss.ctx.player.ball_position()
	var to_ball := Vector3(ball.x - from.x, 0.0, ball.z - from.z)
	var ball_heading := aim_at(boss, ball)
	var into_wall := to_ball.length() + Rules.CHARGE_OVERSHOOT >= travel_to_rim(boss, from, ball_heading)
	var aim := ball
	if not into_wall:
		aim = PackPressure.lead_aim(boss.ctx.player, from, warn, Rules.CHARGE_SPEED, half + CHARGE_REACH, half + Tuning.RADIUS)
	var to_aim := Vector3(aim.x - from.x, 0.0, aim.z - from.z)
	var heading := ball_heading if into_wall else aim_at(boss, aim)
	var to_wall := travel_to_rim(boss, from, heading)
	var wanted := to_aim.length() + Rules.CHARGE_OVERSHOOT
	var length := to_wall if into_wall else maxf(0.0, minf(wanted, to_wall - CHARGE_RIM_CLEAR))
	if not into_wall and length < CHARGE_MIN_LANE:
		heading = ball_heading
		length = to_ball.length() + Rules.CHARGE_OVERSHOOT
	var h = boss.new_hazard()
	if cued:
		h.warn_floor = FightPhases.CUED_WARN
		h.cued = true
	h.commit_lane("charge", boss.Hazard.Threat.Type.LANE, from, heading, half, length + half, boss.Requisition.HULL.x * 0.5 + 1.0,
		boss.Requisition.HULL.y + 0.5, warn, length / Rules.CHARGE_SPEED + 0.2)
	h.lane_front = half + CHARGE_REACH
	boss.add_hazard(h)
	boss.note_commit()
	boss.ship.set_hook_brace(false)
	boss.ship.cue("charge_warn", h.get_instance_id())
	charge = {"state": CHARGE_BRACE, "hazard": h, "from": from, "heading": heading, "length": length,
		"into_wall": into_wall, "travelled": 0.0, "cued": cued}
	boss.publish_event("boss_attack_telegraphed", ["charge_wall" if into_wall else "charge", h.warn_seconds])


func travel_to_rim(boss, from: Vector3, heading: Vector3) -> float:
	var p := Vector2(from.x - boss.arena.global_position.x, from.z - boss.arena.global_position.z)
	var d := Vector2(heading.x, heading.z)
	var b := p.dot(d)
	var c := p.length_squared() - Rules.CHARGE_STOP_R * Rules.CHARGE_STOP_R
	return maxf(0.0, -b + sqrt(maxf(0.0, b * b - c)))


func run_charge(boss, delta: float, ball: Vector3) -> void:
	var h = charge["hazard"]
	var half: float = boss.Requisition.HULL.z * 0.5
	var front_before: float = charge["travelled"] + half
	charge["travelled"] = minf(charge["length"], charge["travelled"] + Rules.CHARGE_SPEED * delta)
	var at: Vector3 = charge["from"] + charge["heading"] * charge["travelled"]
	boss.ship.move_to(Vector3(at.x, boss.arena.ground(at), at.z), charge["heading"])
	var front: float = charge["travelled"] + half
	h.lane_front = front + CHARGE_REACH
	if h.contains(ball) and boss.clock >= boss.hazard_grace(h.get_instance_id()) \
			and (not h.cued or h.age >= h.warn_seconds + 0.025):
		var along: float = h.lane_along(ball)
		if along >= front_before - 1.0 and along <= front + CHARGE_REACH:
			charge_hit(boss, h, ball, boss.ball_cruising())
			if not boss.ctx.flow.in_play():
				return
	var will_hook: bool = not charge["into_wall"] and not charge.get("cued", false) \
		and boss.follow_ups() > 0 and not (boss.reeling() and boss.reel_plant_mode() == "stop")
	var rem_s: float = maxf(0.0, (float(charge["length"]) - float(charge["travelled"])) / Rules.CHARGE_SPEED)
	if will_hook and rem_s <= Rules.HOOK_BRACE_LEAD and boss.reel_plant_mode() != "no_brace":
		boss.ship.set_hook_brace(true, h.get_instance_id())
	if charge["travelled"] >= charge["length"]:
		h.finish()
		if charge["into_wall"]:
			stun(boss, ChallengeDials.punish("brindle", Rules.WALL_STUN))
			boss.discover_entry(CodexEntries.WALL_BAIT, boss.ship.global_position)
		elif will_hook:
			note_missed_charge()
			boss.cue_phase_name("charge")
			if boss.reel_plant_mode() != "no_brace":
				boss.ship.set_hook_brace(true, h.get_instance_id())
			hook_token = h.get_instance_id()
			charge = {"state": CHARGE_HOOK, "timer": FightPhases.CUE_LEAD}
		else:
			boss.ship.set_hook_brace(false)
			note_missed_charge()
			charge = {"state": CHARGE_RECOVER, "timer": Rules.CHARGE_RECOVER}


func charge_hit(boss, h, ball: Vector3, skim := false) -> void:
	if not skim:
		boss.reel_sear(ball, "brindle_charge")
	var dmg := Rules.CHARGE_DAMAGE if skim else ChallengeDials.damage("brindle", Rules.CHARGE_DAMAGE, boss.phase)
	boss.ctx.run.damage(dmg, "brindle_charge")
	if not boss.ctx.flow.in_play():
		return
	boss.set_hazard_grace(h.get_instance_id(), boss.clock + Rules.CHARGE_GRACE)
	if boss.ctx.calm:
		return
	var lateral: float = h.lane_lateral(ball)
	var away: Vector3 = h.side() * (1.0 if lateral >= 0.0 else -1.0)
	var v: Vector3 = boss.ctx.player.state.velocity
	var along: float = v.dot(h.heading)
	var up := maxf(0.0, Rules.CHARGE_SHOVE_UP - v.y)
	boss.shove_ball("brindle_charge", away * Rules.CHARGE_SHOVE_SIDE + Vector3.UP * up - h.heading * minf(0.0, along))
	boss.ship.hull.add_collision_exception_with(boss.ctx.player.body())
	boss.ship.follow_shoved_rider(boss.ctx.player.body())
	ghost_until = boss.clock + Rules.CHARGE_GRACE


func step_ghost(boss) -> void:
	if ghost_until < 0.0 or boss.clock < ghost_until:
		return
	var local: Vector3 = boss.ship.hull.to_local(boss.ctx.player.ball_position())
	var half: Vector3 = boss.Requisition.HULL * 0.5 + Vector3.ONE * (Tuning.RADIUS + 0.3)
	if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
		return
	boss.ship.hull.remove_collision_exception_with(boss.ctx.player.body())
	boss.ship.follow_shoved_rider(null)
	ghost_until = -1.0


func stun(boss, seconds: float) -> void:
	boss.clear_combo()
	if is_instance_valid(boss.ship):
		boss.ship.set_hook_brace(false)
	if charge.has("hazard") and is_instance_valid(charge["hazard"]):
		charge["hazard"].finish()
	charge = {"state": CHARGE_STUN, "timer": seconds}
	boss.note_commit()
	boss.stuns += 1
	boss.ship.cue("wall_stun", boss.stuns)


func stunned(boss) -> bool:
	return boss.state == boss.FIGHT and boss.phase == 3 and charge.get("state", "") == CHARGE_STUN


func charging(boss) -> bool:
	return boss.state == boss.FIGHT and boss.phase == 3 and charge.get("state", "") == CHARGE_RUN


func charge_coming(boss) -> bool:
	return boss.state == boss.FIGHT and boss.phase == 3 and charge.get("state", "") in [CHARGE_BRACE, CHARGE_RUN]


func note_missed_charge() -> void:
	if scuttle_punch < Rules.HULL_PLATING:
		short_tries += 1


func note_glance(boss, target, part: String, result: Dictionary) -> void:
	if boss.state != boss.FIGHT or boss.phase != 3 or target.role != "hull" or part.begins_with("cap_") or stunned(boss) or boss.posture_staggered():
		return
	var punch := float(result.get("punch", 0.0))
	scuttle_punch = maxf(scuttle_punch, punch)
	if punch < float(result.get("plating", Rules.HULL_PLATING)) and scuttle_punch < Rules.HULL_PLATING:
		short_tries += 1


func take_hint(boss) -> String:
	if boss.state != boss.FIGHT or boss.phase != 3 or boss.stuns > 0 or short_tries <= 0 or boss.clock < hint_next:
		return ""
	if scuttle_punch >= Rules.HULL_PLATING:
		return ""
	if boss.in_transition() or boss.is_held() or boss.posture_staggered():
		return ""
	hint_next = boss.clock + Rules.SCUTTLE_HINT_GAP
	return Rules.SCUTTLE_HINT
