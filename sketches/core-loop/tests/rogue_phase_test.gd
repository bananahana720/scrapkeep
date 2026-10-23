extends SceneTree

const Game := preload("res://src/game.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")

# Phase two of the rogue fleet machines (Andrew 19:02Z 23 Oct): below half health each one
# enters phase 2 through its enter_phase hook. Its wind-ups shorten by PHASE_TWO_WIND, and the
# wind-up rows read the shorter leads; its first attack chains straight into its second with
# no vented window, and the second still vents; its anthem moves to the heavier variant id.

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
		_check(rogue.phase == 1 and rogue.anthem() == row.anthem, kind + " starts in phase 1 on its anthem")
		rogue.hp = rogue.max_hp * 0.4
		rogue._clock = 0.0
		rogue._physics_process(0.0)
		_check(rogue.phase == 2 and rogue.anthem() == row.anthem_heavy, kind + " under half health enters phase 2, anthem " + rogue.anthem())
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
		_check(rogue.state == Rogue.State.WIND and rogue.attack == second and rogue.telegraph() != null,
			kind + " %s chains into %s with no vented window" % [first, second])
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
