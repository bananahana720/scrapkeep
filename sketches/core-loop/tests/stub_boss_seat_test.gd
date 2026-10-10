extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Warden := preload("res://src/combat/warden.gd")
const T := preload("res://tests/support/t.gd")

# The stub family's Warden stands on its pad, not sunk into it (BUGFIX-BOSS F006, judged
# not a bug, 2026-10-09): stub_boss.gd places it at the pad top, and Warden.setup then seats
# it HALF_HEIGHT above the ground its terrain (the stub) reports, as waking.gd's re-seat does.
# Checked in the Mind fight (world three) on entry and a second later.

const SETTLE_FRAMES := 90
const TOLERANCE := 0.05

var _t := T.new("stub_boss_seat_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	Harness.enter_world(_game, 3)
	var mod = Harness.module(_game, 3)
	if _t.check("Mind module has a Warden", mod != null and is_instance_valid(mod.warden), "module %s" % mod):
		_seat("on entry", mod)
		for _i in SETTLE_FRAMES:
			await physics_frame
		_seat("after a second", mod)
	_game.free()
	quit(_t.verdict())


func _seat(when: String, mod) -> void:
	var at: Vector3 = mod.warden.global_position
	var top: float = mod.ground_height_at(at)
	_t.near("Warden stands HALF_HEIGHT above the pad top %s" % when, at.y - top, Warden.HALF_HEIGHT, TOLERANCE)
