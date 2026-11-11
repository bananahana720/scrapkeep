# smoke: solo timeout=120s (wave 37 unit D1: crews on world 1 lead the ball's roll by half)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const T := preload("res://tests/support/t.gd")

# Ruling cu, call 4: chasers lead your line. World 1 ships pack.lead_by_stage at 0.5 on the dam and the
# flume (ChallengeDials.LEAD_W1). What that means on the ground, on the real chaser:
#   - a ball that crawls across a chaser's front (SLOW, a quarter of walking a chaser down) is lunged: the lane
#     is laid halfway to where the roll will be, and that is close enough to a slow ball;
#   - the same crawl with the lead off (the planted case, the game before this unit) is missed;
#   - a ball crossing at cruise is missed with the lead on: rolling past a pack stays free;
#   - the wind-up is as long as it was: the lane stands WINDUP seconds before the lunge, never under 0.6 s;
#   - the lead fades out as the ball reaches cruise (pack.lead_cruise_by_stage, 0 on world 1): a ball rolling
#     straight at a chaser at FAST is past it before the lunge, as before wave 37, and with the fade off (the
#     planted case) the chaser winds up early and meets it. The stop-tax line F2 is what this holds.
# The ball is a roller on rails, so each pass is the same geometry: the chaser stands, the roller crosses GAP
# metres off its nose. One lunge is read per pass; a chaser running a slow ball down from behind is not the lead.

const GAP := 7.0
const SLOW := 2.6
const CRUISE := 14.0
const LEAD_OFF := {"pack.lead_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}
const FAST := 20.0
const HEAD_ON_FROM := 34.0
const HEAD_ON_SIDE := 0.6
const FADE_OFF := {"pack.lead_cruise_by_stage": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]}


class Roller:
	var at := Vector3.ZERO
	var v := Vector3.ZERO

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return Vector3(v.x, 0.0, v.z)


var _game
var _t := T.new("chaser_lead_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


# One pass: {"hit", "tell" (seconds the lane stood before the lunge, -1 with no lunge), "lead" (the row the
# chaser was spawned with)}.
# head_on: the roller starts HEAD_ON_FROM metres off and rolls straight at the chaser, HEAD_ON_SIDE off its centre.
func _pass(speed: float, overrides: Dictionary, head_on := false) -> Dictionary:
	ChallengeDials.set_overrides(overrides)
	var enemy = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(-100.0, -90.0, 1.6))
	ChallengeDials.set_overrides({})
	enemy.hp = 100000.0
	var roller := Roller.new()
	enemy.target = roller
	# Settle on the floor first: the roller sits on the chaser and the lunge is held.
	enemy._rest = 999.0
	for i in 40:
		roller.at = enemy.global_position
		await physics_frame
	var hits := [0]
	enemy.hit_player.connect(func(_amount: float, _shove: Vector3): hits[0] += 1)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	roller.at = enemy.global_position + Vector3(GAP, 0.0, 0.0)
	roller.v = Vector3(0.0, 0.0, speed)
	if head_on:
		roller.at = enemy.global_position + Vector3(HEAD_ON_FROM, 0.0, HEAD_ON_SIDE)
		roller.v = Vector3(-speed, 0.0, 0.0)
		# The head-on roll is read on a chaser at its own SPEED, whatever the stage's chaser speed is (unit D2
		# raises it), so the pass is the same geometry on every head of the stack. The fade is what differs.
		if "run_speed" in enemy:
			enemy.run_speed = Chaser.SPEED
	enemy._rest = 0.0
	var wound_at := -1
	var wound_m := -1.0
	var lunged_at := -1
	for i in 360:
		roller.at += roller.v * dt
		roller.at.y = _game.ctx.terrain.height(roller.at.x, roller.at.z) + 0.8
		await physics_frame
		if enemy.state == enemy.State.WINDUP and wound_at < 0:
			wound_at = i
			wound_m = Vector2(roller.at.x - enemy.global_position.x, roller.at.z - enemy.global_position.z).length()
		if enemy.state == enemy.State.LUNGE and lunged_at < 0:
			lunged_at = i
		if enemy.lunges >= 1 or (lunged_at >= 0 and enemy.state == enemy.State.RECOVER):
			break
	var out := {"hit": hits[0] > 0, "tell": float(lunged_at - wound_at) * dt if lunged_at >= 0 and wound_at >= 0 else -1.0,
		"lead": float(enemy.pressure.get("lead", 0.0)), "wound_m": wound_m}
	enemy.free()
	await _frames(2)
	return out


func _run() -> void:
	ChallengeDials.reset()
	_t.eq("01 the lead ships at half on the dam and the flume, off after them", ChallengeDials.value("pack.lead_by_stage"), [0.5, 0.5, 0.0, 0.0, 0.0, 0.0])
	_t.near("02 a dam crew reads half", PackPressure.crew_row(1).lead, 0.5)
	_t.near("03 a flume crew reads half", PackPressure.crew_row(2).lead, 0.5)
	_t.near("04 a Dig crew reads none", PackPressure.crew_row(3).lead, 0.0)
	_t.check("05 the wind-up is at least the tell floor", Chaser.WINDUP >= ChallengeDials.TELL_FLOOR, "WINDUP %.2f s, floor %.2f s" % [Chaser.WINDUP, ChallengeDials.TELL_FLOOR])
	await _boot()
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var slow: Dictionary = await _pass(SLOW, {})
	_t.near("06 a chaser spawned on the dam carries the half lead", slow.lead, 0.5)
	_t.check("07 a ball crawling across its front is lunged", slow.hit, "%.1f m/s at %.0f m: hit %s" % [SLOW, GAP, slow.hit])
	_t.check("08 the lane stood the whole wind-up first", slow.tell >= Chaser.WINDUP - tick - 0.0001, "lane to lunge %.3f s, WINDUP %.2f s" % [slow.tell, Chaser.WINDUP])
	# The planted case: the same pass with the lead off is the game before this unit, and it must miss, or
	# check 07 says nothing about the lead.
	var planted: Dictionary = await _pass(SLOW, LEAD_OFF)
	_t.near("09 planted: with the dial off the chaser carries no lead", planted.lead, 0.0)
	_t.check("10 planted: the same crawl is missed without the lead", planted.tell > 0.0 and not planted.hit, "lunged after %.3f s, hit %s" % [planted.tell, planted.hit])
	var fast: Dictionary = await _pass(CRUISE, {})
	# At cruise the led aim is out of lunge range before the chaser can wind up, so no lane is laid at all.
	_t.check("11 a ball crossing at cruise is not hit with the lead on", not fast.hit, "%.0f m/s at %.0f m: hit %s, lane to lunge %.3f s (-1 is no lunge)" % [CRUISE, GAP, fast.hit, fast.tell])
	_t.check("12 a lane laid for it, if any, stood the whole wind-up too", fast.tell < 0.0 or fast.tell >= Chaser.WINDUP - tick - 0.0001, "lane to lunge %.3f s" % fast.tell)
	# The fade. The game's own cruise speed is what combat hands PackPressure each tick.
	var cruise: float = _game.player.tuning.f("cruise")
	_t.eq("13 the lead keeps none of itself at cruise on world 1, all of it after", ChallengeDials.value("pack.lead_cruise_by_stage"), [0.0, 0.0, 1.0, 1.0, 1.0, 1.0])
	var row: Dictionary = PackPressure.crew_row(1)
	var roller := Roller.new()
	var read := []
	for share in [0.0, 0.5, PackPressure.LEAD_FADE_FROM, 0.5 + PackPressure.LEAD_FADE_FROM * 0.5, 1.0, 1.5]:
		roller.v = Vector3(cruise * share, 0.0, 0.0)
		read.append(snappedf(PackPressure.lead_now(row, roller), 0.001))
	_t.eq("14 a dam crew's lead is whole to %.2f of cruise, half way down at the midpoint and gone at cruise" % PackPressure.LEAD_FADE_FROM, read, [0.5, 0.5, 0.5, 0.25, 0.0, 0.0])
	roller.v = Vector3(cruise * 1.5, 0.0, 0.0)
	_t.near("15 a row that keeps its lead at cruise reads it whole at any speed", PackPressure.lead_now({"lead": 0.5, "lead_cruise": 1.0}, roller), 0.5)
	var met: Dictionary = await _pass(FAST, {}, true)
	_t.check("16 a ball rolling straight at a chaser at %.0f m/s is not hit" % FAST, not met.hit, "hit %s, lane laid with the ball %.1f m off (-1 is no lane)" % [met.hit, met.wound_m])
	_t.check("17 and the chaser waits for its own lunge range before it winds up", met.wound_m < 0.0 or met.wound_m <= Chaser.LUNGE_RANGE + 0.5, "lane laid with the ball %.1f m off, range %.1f m" % [met.wound_m, Chaser.LUNGE_RANGE])
	# The planted case: the same roll with the fade off is the lead as unit D1 first shipped it, and the chaser
	# must wind up early and meet the ball, or checks 16 and 17 say nothing about the fade.
	var early: Dictionary = await _pass(FAST, FADE_OFF, true)
	_t.check("18 planted: with the fade off the chaser winds up beyond its lunge range", early.wound_m > Chaser.LUNGE_RANGE + 2.0, "lane laid with the ball %.1f m off, range %.1f m" % [early.wound_m, Chaser.LUNGE_RANGE])
	_t.check("19 planted: and the same roll is hit", early.hit, "hit %s" % early.hit)
	_t.check("20 planted: its lane still stood the whole wind-up", early.tell >= Chaser.WINDUP - tick - 0.0001, "lane to lunge %.3f s" % early.tell)
	ChallengeDials.reset()
	quit(_t.verdict())
