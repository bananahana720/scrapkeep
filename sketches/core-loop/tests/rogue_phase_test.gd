extends SceneTree

const Game := preload("res://src/game.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")

# Phase two of the rogue fleet machines (Andrew 19:02Z and 19:11Z 23 Oct): the hit that takes
# one under half health turns it to phase 2 through its enter_phase hook. The turn lasts
# TURN_SECONDS, takes no damage and drops any committed attack; then it stalks. Its wind-ups
# shorten by PHASE_TWO_WIND, and the wind-up rows read the shorter leads; its first attack
# chains into its second with no vented window, through a CUE_LEAD sound-cue beat that commits
# nothing, and the second still vents; its anthem moves to the heavier variant id.

var failures := 0
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	game.ctx.calm = true
	for kind in Rogue.ROWS:
		var rogue = game.ctx.spawner.spawn_enemy(kind, Vector3(0, 40, 0))
		rogue.set_physics_process(false)
		var row: Dictionary = Rogue.ROWS[kind]
		var first := String(row.attacks[0])
		var second := String(row.attacks[1])
		var lane_before: float = rogue.wind_lane
		# A wind-up committed in phase 1 keeps its length when phase 2 starts mid-wind.
		rogue._begin_attack(Vector3(0, 0, -10))
		var committed: float = rogue._seconds("wind")
		rogue.enter_phase(2)
		_check(is_equal_approx(rogue._seconds("wind"), committed), kind + " a committed wind-up keeps its length into phase 2")
		rogue._clear_telegraph()
		rogue.phase = 1
		rogue._set_leads()
		rogue._next = 0
		_check(rogue.phase == 1 and rogue.anthem() == row.anthem, kind + " starts in phase 1 on its anthem")
		rogue._begin_attack(Vector3(0, 0, -10))
		rogue.take_damage(rogue.hp - rogue.max_hp * 0.4)
		_check(rogue.phase == 2 and rogue.anthem() == row.anthem_heavy, kind + " under half health enters phase 2, anthem " + rogue.anthem())
		_check(rogue.state == Rogue.State.TURN and rogue.telegraph() == null, kind + " turns, with its committed attack dropped")
		var hp_turning: float = rogue.hp
		_check(rogue.take_damage(50.0) == 0.0 and rogue.hp == hp_turning, kind + " takes no damage while it turns")
		rogue.live = func(): return true
		rogue._physics_process(Rogue.TURN_SECONDS * 0.5)
		_check(rogue.state == Rogue.State.TURN, kind + " still turning halfway through")
		rogue._physics_process(Rogue.TURN_SECONDS * 0.5 + 0.001)
		_check(rogue.state == Rogue.State.STALK, kind + " stalks after the turn")
		rogue._enter(Rogue.State.STALK)
		rogue._next = 0
		_check(is_equal_approx(rogue.wind_lane, lane_before * Rogue.PHASE_TWO_WIND), kind + " lane wind-up shortened")
		rogue._begin_attack(Vector3(0, 0, -10))
		_check(rogue.attack == first and is_equal_approx(rogue._seconds("wind"), float(Rogue.ATTACKS[first].wind) * rogue.beat() * Rogue.PHASE_TWO_WIND),
			kind + " %s winds up in %.2f s" % [first, rogue._seconds("wind")])
		var lane_row := ""
		for id in WindupRows.ROWS[kind].attacks:
			if WindupRows.ROWS[kind].attacks[id] == ["wind_lane"]:
				lane_row = id
		_check(is_equal_approx(WindupRows.row(kind, rogue, lane_row).get("lead_seconds", 0.0), rogue.wind_lane), kind + " wind-up row reads the phase 2 lead")
		rogue.state = Rogue.State.STRIKE
		rogue._finish_strike()
		_check(rogue.state == Rogue.State.CUE and rogue.telegraph() == null, kind + " %s is followed by a cue beat that commits nothing" % first)
		rogue._begin_attack(Vector3(0, 0, -10))
		_check(rogue.state == Rogue.State.WIND and rogue.attack == second and rogue.telegraph() != null,
			kind + " %s chains into %s with no vented window" % [first, second])
		_check(rogue._seconds("wind") >= ChallengeDials.TELL_FLOOR, kind + " phase 2 wind-up stays over the tell floor")
		rogue.state = Rogue.State.STRIKE
		rogue._finish_strike()
		_check(rogue.state == Rogue.State.WEAK, kind + " %s still vents" % second)
		rogue.enter_phase(1)
		_check(rogue.phase == 2, kind + " never drops back a phase")
		rogue._clear_telegraph()
		rogue.free()
	print("rogue_phase_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	game.free()
	quit(0 if failures == 0 else 1)
