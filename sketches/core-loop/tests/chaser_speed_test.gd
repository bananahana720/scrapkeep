# smoke: solo timeout=180s (wave 37 unit D2: chasers on world 1 run between walking pace and cruise)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# Ruling cu, call 4: chasers may run faster than walking pace and slower than cruise. World 1 ships
# mobs.chaser_speed_by_stage at 9 m/s on the dam and the flume (ChallengeDials.CHASER_SPEED_W1). On the real
# chaser, with a ball on rails rolling straight away from it:
#   - a ball that dawdles (DAWDLE, between the old 4.8 m/s and the new speed) is run down and lunged;
#   - the same dawdle with the dial off (the planted case, the game before this unit) is never caught;
#   - a ball at cruise is never caught and the gap only grows: running past a pack stays free;
#   - the wind-up is as long as it was, and no dial reaches the ball's cruise speed.

const DAWDLE := 6.0
const HEAD_START := 16.0
const SECONDS := 14.0
const SPEED_OFF := {"mobs.chaser_speed_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}


class Roller:
	var at := Vector3.ZERO
	var v := Vector3.ZERO

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return Vector3(v.x, 0.0, v.z)


var _game
var _t := T.new("chaser_speed_test")


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


func _cruise() -> float:
	for row in Tuning.SPECS:
		if row.key == "cruise":
			return float(row.value)
	return 0.0


# One chase: the roller starts HEAD_START metres off and rolls straight away at `speed` for SECONDS.
# {"hits", "speed" (the chaser's run speed), "gap_end", "tell" (shortest lane-to-lunge seconds, -1 with no lunge)}.
func _chase(speed: float, overrides: Dictionary) -> Dictionary:
	ChallengeDials.set_overrides(overrides)
	var enemy = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(-100.0, -90.0, 1.6))
	ChallengeDials.set_overrides({})
	enemy.hp = 100000.0
	var roller := Roller.new()
	enemy.target = roller
	enemy._rest = 999.0
	for i in 40:
		roller.at = enemy.global_position
		await physics_frame
	var hits := [0]
	enemy.hit_player.connect(func(_amount: float, _shove: Vector3): hits[0] += 1)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var away := Vector3(1.0, 0.0, 0.0)
	roller.at = enemy.global_position + away * HEAD_START
	roller.v = away * speed
	enemy._rest = 0.0
	var wound_at := -1
	var tell := INF
	var was := -1
	for i in int(SECONDS / dt):
		roller.at += roller.v * dt
		roller.at.y = _game.ctx.terrain.height(roller.at.x, roller.at.z) + 0.8
		await physics_frame
		if enemy.state != was:
			if enemy.state == enemy.State.WINDUP:
				wound_at = i
			elif enemy.state == enemy.State.LUNGE and wound_at >= 0:
				tell = minf(tell, float(i - wound_at) * dt)
			was = enemy.state
		if hits[0] > 0:
			break
	var gap := Vector2(roller.at.x - enemy.global_position.x, roller.at.z - enemy.global_position.z).length()
	var out := {"hits": hits[0], "speed": float(enemy.run_speed), "gap_end": gap, "tell": tell if tell < INF else -1.0}
	enemy.free()
	await _frames(2)
	return out


func _run() -> void:
	ChallengeDials.reset()
	var cruise := _cruise()
	_t.eq("01 chasers ship at 9 m/s on the dam and the flume, their own speed after them", ChallengeDials.value("mobs.chaser_speed_by_stage"), [9.0, 9.0, 0.0, 0.0, 0.0, 0.0])
	_t.near("02 a dam chaser runs at 9", Chaser.stage_speed(1), 9.0)
	_t.near("03 a Dig chaser runs at its own speed", Chaser.stage_speed(3), Chaser.SPEED)
	_t.check("04 the ceiling is under the ball's cruise", cruise > 0.0 and Chaser.SPEED_CEILING < cruise, "ceiling %.1f m/s, cruise %.1f m/s" % [Chaser.SPEED_CEILING, cruise])
	_t.check("05 the shipped speed is above the old walk and under cruise", Chaser.stage_speed(1) > Chaser.SPEED and Chaser.stage_speed(1) < cruise, "%.1f m/s between %.1f and %.1f" % [Chaser.stage_speed(1), Chaser.SPEED, cruise])
	ChallengeDials.set_overrides({"mobs.chaser_speed_by_stage": [99.0, 2.0, 0.0, 0.0, 0.0, 0.0]})
	_t.near("06 a dial past the ceiling is held at it", Chaser.stage_speed(1), Chaser.SPEED_CEILING)
	_t.near("07 a dial under the chaser's own speed never slows it", Chaser.stage_speed(2), Chaser.SPEED)
	ChallengeDials.set_overrides({})
	_t.check("08 the wind-up is at least the tell floor", Chaser.WINDUP >= ChallengeDials.TELL_FLOOR, "WINDUP %.2f s" % Chaser.WINDUP)
	await _boot()
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var slow: Dictionary = await _chase(DAWDLE, {})
	_t.near("09 a chaser spawned on the dam runs at the stage's speed", slow.speed, 9.0)
	_t.check("10 a ball dawdling away is run down and lunged", slow.hits > 0, "%.0f m/s with a %.0f m head start: hits %d, gap at the end %.1f m" % [DAWDLE, HEAD_START, slow.hits, slow.gap_end])
	_t.check("11 the lane stood the whole wind-up before every lunge", slow.tell >= Chaser.WINDUP - tick - 0.0001, "shortest lane to lunge %.3f s, WINDUP %.2f s" % [slow.tell, Chaser.WINDUP])
	# The planted case: the same dawdle with the dial off is the game before this unit, and the chaser must
	# never reach it, or check 10 says nothing about the speed.
	var planted: Dictionary = await _chase(DAWDLE, SPEED_OFF)
	_t.near("12 planted: with the dial off the chaser runs at its own speed", planted.speed, Chaser.SPEED)
	_t.check("13 planted: the same dawdle is never caught", planted.hits == 0 and planted.gap_end > HEAD_START, "hits %d, gap at the end %.1f m" % [planted.hits, planted.gap_end])
	var fast: Dictionary = await _chase(cruise, {})
	_t.check("14 a ball at cruise is never caught and the gap grows", fast.hits == 0 and fast.gap_end > HEAD_START + 0.3 * SECONDS * (cruise - Chaser.SPEED_CEILING),
		"%.0f m/s: hits %d, gap %.1f m from %.0f m" % [cruise, fast.hits, fast.gap_end, HEAD_START])
	ChallengeDials.reset()
	quit(_t.verdict())
