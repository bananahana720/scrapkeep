extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")

# FX-04: Brindle's fall plays where the scooter was caught, not at the empty ship. boss.gd
# _defeat keeps the scooter in sight through boss_defeated, so machine_fx's fall (its
# _brindle_at reads a visible scooter before the ship) is placed at the catch; the scooter
# is hidden once the event is out.
#
# Evidence limit: machine_fx's own moment log is read, not the drawn blasts.

var _game
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


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	var boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	boss.jump_to_phase(4)
	for _i in 400:
		boss.advance(1.0 / 90.0)
		if boss.scooter_landed():
			break
	var caught_at: Vector3 = boss.scooter.global_position
	var ship_at: Vector3 = boss.ship.global_position
	var seen := {"visible": false}
	_game.events.boss_defeated.connect(func(): seen["visible"] = boss.scooter.visible)
	Harness.defeat(_game)
	await physics_frame
	var fx = _game.presentation.machine_fx
	var falls: Array = fx.moments.filter(func(m): return m[1] == "boss_fall")
	var fall_at: Vector3 = falls[-1][3] if not falls.is_empty() else Vector3.INF
	_report("the scooter is in sight when the fall is announced", seen["visible"] and not boss.scooter.visible,
		"visible at boss_defeated %s; hidden after %s" % [seen["visible"], not boss.scooter.visible])
	_report("the fall plays at the catch, not the ship", fall_at.distance_to(caught_at) < 0.01 and caught_at.distance_to(ship_at) > 5.0,
		"fall at %s; scooter caught at %s; ship at %s" % [fall_at, caught_at, ship_at])
	print("brindle_fall_place_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
