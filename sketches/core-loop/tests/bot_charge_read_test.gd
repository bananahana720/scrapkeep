extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")
const T := preload("res://tests/support/t.gd")

# Brindle's phase 3 charge, read by band (bot_driver.gd _charge_plan). A committed charge lane is
# staged on a fake boss with a real Hazard, and the driver's phase 3 plan is stepped against it with
# a point ball that rolls at the steer and takes the boss's own contact rule (boss.gd _run_charge).
# An Expert steps out of the lane before the front arrives and takes no hit; an unread lane leaves
# the old plan (roll at the hull) and is hit; a Novice never clashes; an Expert clashes only head-on
# with time to spare.
#
# Evidence limit: kinematic ball (14 m/s, no mass), the fake boss's charge dict mirrors boss.gd, and
# the bot's perception runs on its own tick count. It does not show a full fight or the real ball.

const DT := 1.0 / 90.0
const ROLL := 14.0
const SPEED := BossRules.CHARGE_SPEED


class FakeState:
	var grounded := true
	var air_actions := 1
	var velocity := Vector3.ZERO


class FakePlayer:
	var at := Vector3.ZERO
	var vel := Vector3.ZERO
	var state := FakeState.new()

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return vel


class FakeFlow:
	func state_name() -> String:
		return "boss"


class FakeGame:
	var bot_driven := false
	var player := FakePlayer.new()
	var flow := FakeFlow.new()


class FakeBoss:
	var _charge := {}
	var clash_punch := 150.0


class Probe extends BotDriver:
	var steered := Vector3.INF
	var evaded := true
	var counts := {}

	func _init(game_ref) -> void:
		super(game_ref, "skipper", 1)
		boot_note()

	func boot_note() -> void:
		boss_note = {"hits": 0}

	func _act(steer: Vector3, _aim, _delta: float, _fight: Node3D = null, evade := true) -> void:
		steered = steer
		evaded = evade

	func _count(key: String, by: float = 1.0) -> void:
		counts[key] = counts.get(key, 0) + by


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t := T.new("bot_charge_read_test")
	var hull := Node3D.new()
	root.add_child(hull)

	# Expert, no clash punch, ball off to one side: reads the lane and steps out before the front.
	var side := _fight(hull, "expert", 1.0, Vector3(3.0, 0.0, 40.0), Vector3.ZERO, 100.0)
	t.eq("expert sidestep: no charge hit", side["hits"], 0)
	t.eq("expert sidestep: lane read once", side["counts"].get("charge_reads", 0), 1)
	t.eq("expert sidestep: sidestep counted once", side["counts"].get("charge_sidesteps", 0), 1)
	t.eq("expert sidestep: no clash tried", side["counts"].get("clash_tries", 0), 0)
	t.check("expert sidestep: clear of half width plus margin", absf(side["lateral_at_front"]) >= 5.5 + 1.9, str(side["lateral_at_front"]))
	t.check("expert sidestep: took the nearer side", side["lateral_at_front"] > 0.0, str(side["lateral_at_front"]))
	t.check("expert sidestep: out before the front reached the ball", side["clear_s"] < side["front_s"], "%s vs %s" % [side["clear_s"], side["front_s"]])

	# Same ball in the middle of the lane at rest: still gets out, and takes the side it is nearer to.
	var mid := _fight(hull, "expert", 1.0, Vector3(-1.0, 0.0, 40.0), Vector3.ZERO, 200.0)
	t.eq("expert at rest in the lane: no hit", mid["hits"], 0)
	t.eq("expert at rest in the lane: no clash (not closing)", mid["counts"].get("clash_tries", 0), 0)
	t.check("expert at rest in the lane: left side", mid["lateral_at_front"] < 0.0, str(mid["lateral_at_front"]))

	# Learner a1 with the lane unread: the old plan (roll at the hull) runs and the front hits it.
	var unread := _fight(hull, "learner", 0.0, Vector3(0.0, 0.0, 40.0), Vector3.ZERO, 100.0, true)
	t.eq("unread learner: no read counted", unread["counts"].get("charge_reads", 0), 0)
	t.eq("unread learner: no sidestep counted", unread["counts"].get("charge_sidesteps", 0), 0)
	t.eq("unread learner: plan returned to the old routine", unread["plan_used"], false)
	t.check("unread learner: the front hits it", unread["hits"] >= 1, str(unread["hits"]))

	# Learner a1 that reads the lane steps out like the Expert, after its slower reaction.
	var read := _fight(hull, "learner", 1.0, Vector3(0.0, 0.0, 40.0), Vector3.ZERO, 100.0)
	t.eq("read learner: sidestep counted", read["counts"].get("charge_sidesteps", 0), 1)
	t.eq("read learner: no hit", read["hits"], 0)

	# Novice: never clashes, even with the punch and a head-on run, and steps out when it reads.
	var novice := _fight(hull, "novice", 1.0, Vector3(0.0, 0.0, 45.0), Vector3(0.0, 0.0, -12.0), 400.0, true)
	t.eq("novice: no clash tried", novice["counts"].get("clash_tries", 0), 0)
	t.eq("novice: never a clash goal", novice["clash_steps"], 0)
	t.eq("novice: no hit after reading", novice["hits"], 0)

	# Expert head-on with the punch and time to spare: the clash is tried, once, and kept.
	var head := _fight(hull, "expert", 1.0, Vector3(0.0, 0.0, 45.0), Vector3(0.0, 0.0, -12.0), 200.0, true)
	t.eq("expert head-on: clash tried once", head["counts"].get("clash_tries", 0), 1)
	t.check("expert head-on: clashes while the front closes", head["clash_steps"] > 10, str(head["clash_steps"]))
	t.eq("expert head-on: the clash lands", head["clashed"], true)
	t.eq("expert head-on: no hit", head["hits"], 0)
	t.eq("expert head-on: no sidestep", head["counts"].get("charge_sidesteps", 0), 0)
	t.eq("expert head-on: clash evasion off", head["clash_evaded"], false)

	# Expert head-on but short of punch: sidestep.
	var weak := _fight(hull, "expert", 1.0, Vector3(0.0, 0.0, 45.0), Vector3(0.0, 0.0, -12.0), 120.0, true)
	t.eq("expert head-on short of punch: no clash", weak["counts"].get("clash_tries", 0), 0)
	t.eq("expert head-on short of punch: no hit", weak["hits"], 0)

	# Expert with the punch but no time: ball close to the bow, off the axis.
	var late := _fight(hull, "expert", 1.0, Vector3(4.0, 0.0, 14.0), Vector3(0.0, 0.0, -12.0), 200.0, true)
	t.eq("expert without time: no clash", late["counts"].get("clash_tries", 0), 0)
	t.eq("expert without time: sidestep", late["counts"].get("charge_sidesteps", 0), 1)

	# Expert with the punch, offset sideways and standing: not head-on, so sidestep.
	var off := _fight(hull, "expert", 1.0, Vector3(12.0, 0.0, 40.0), Vector3.ZERO, 200.0)
	t.eq("expert off the axis: no clash", off["counts"].get("clash_tries", 0), 0)
	t.eq("expert off the axis: no hit", off["hits"], 0)

	hull.free()
	quit(t.verdict())
	return false


# Steps one charge against a bot of `band_name`. read_chance 0 forces the lane unread, 1 read.
func _fight(hull: Node3D, band_name: String, read_chance: float, start: Vector3, vel: Vector3, punch: float, roll_at_hull := false) -> Dictionary:
	var game := FakeGame.new()
	game.player.at = start
	game.player.vel = vel
	var bot := Probe.new(game)
	bot.band = SkillBand.make(band_name, 1, 1)
	bot.band.read_chance = read_chance
	var boss := FakeBoss.new()
	var half := Requisition.HULL.z * 0.5
	var from := Vector3.ZERO
	var length := 70.0
	var h := Hazard.new()
	h.commit_lane("charge", Hazard.Threat.Type.LANE, from, Vector3.BACK, half, length + half, Requisition.HULL.x * 0.5 + 1.0,
		Requisition.HULL.y + 0.5, 1.4, length / SPEED + 0.2)
	boss._charge = {"state": "brace", "hazard": h, "from": from, "heading": Vector3.BACK, "length": length, "travelled": 0.0}
	var out := {"hits": 0, "clash_steps": 0, "clash_evaded": true, "plan_used": false, "clashed": false, "lateral_at_front": 0.0, "clear_s": INF, "front_s": INF}
	var clock := 0.0
	var grace := -1.0
	while clock < 1.4 + length / SPEED + 0.5:
		hull.global_position = from + Vector3.BACK * boss._charge["travelled"]
		bot.ticks += 1
		bot.steered = Vector3.INF
		var used := false
		if boss._charge["state"] != "done":
			used = bot._charge_plan(boss, hull, game.player.at, punch, DT)
		out["plan_used"] = out["plan_used"] or used
		if used and bot._goal == "boss clash":
			out["clash_steps"] += 1
			out["clash_evaded"] = bot.evaded
		# Unplanned (unread): the old routine rolls at the hull.
		var steer: Vector3 = bot.steered if used else (hull.global_position if roll_at_hull else game.player.at)
		var want := Vector3(steer.x - game.player.at.x, 0.0, steer.z - game.player.at.z)
		want = want.normalized() * ROLL if want.length() > 0.5 else Vector3.ZERO
		game.player.vel = game.player.vel.move_toward(want, 60.0 * DT)
		game.player.at += game.player.vel * DT
		clock += DT
		h.age = clock
		if used and bot._goal == "boss clash" and boss._charge["state"] == "run" \
				and h.lane_along(game.player.at) - (boss._charge["travelled"] + half) <= 2.5:
			out["clashed"] = true
			boss._charge["state"] = "done"
			h.state = Hazard.DONE
		if boss._charge["state"] == "brace" and clock >= 1.4:
			h.state = Hazard.LIVE
			boss._charge["state"] = "run"
		elif boss._charge["state"] == "run":
			var front_before: float = boss._charge["travelled"] + half
			boss._charge["travelled"] = minf(length, boss._charge["travelled"] + SPEED * DT)
			var front: float = boss._charge["travelled"] + half
			var ball: Vector3 = game.player.at
			if h.contains(ball) and clock >= grace:
				var along := h.lane_along(ball)
				if along >= front_before - 1.0 and along <= front + 1.5:
					out["hits"] += 1
					grace = clock + BossRules.CHARGE_GRACE
					bot.counts["charge_hits"] = bot.counts.get("charge_hits", 0) + 1
			if out["front_s"] == INF and along_ahead(h, ball, front):
				out["lateral_at_front"] = h.lane_lateral(ball)
			if absf(h.lane_lateral(ball)) >= h.half_width and out["clear_s"] == INF:
				out["clear_s"] = clock
			if along_ahead(h, ball, front) and out["front_s"] == INF:
				out["front_s"] = clock
			if boss._charge["travelled"] >= length:
				boss._charge["state"] = "done"
				h.state = Hazard.DONE
	out["lateral"] = h.lane_lateral(game.player.at)
	if out["clear_s"] == INF:
		out["clear_s"] = 999.0
	out["counts"] = bot.counts
	h.free()
	return out


# The first time the front is within a ball radius of the ball's station: the moment it would hit.
static func along_ahead(h, ball: Vector3, front: float) -> bool:
	return h.lane_along(ball) - front <= 1.0
