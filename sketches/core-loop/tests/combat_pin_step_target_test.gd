extends SceneTree

const Game := preload("res://src/game.gd")
const Target := preload("res://src/boss/boss_target.gd")

# A Brindle piece in combat's enemy array has no weight and is never pinnable: _pin_step
# skips it, leaves it where it is, and still pins a real enemy that lies behind it.


class FakeBoss:
	var hp := 100.0
	var max_hp := 100.0
	func target_live(_t) -> bool:
		return true
	func tint_for(_t, s):
		return s
	func plating_for(_t, _k, _p) -> float:
		return 0.0
	func hit_mult(_t, _k, _p) -> float:
		return 1.0
	func contact_part(_t, _b, _k) -> String:
		return ""
	func on_struck(_t, _k, _p, _r) -> void:
		pass
	func take_damage(_t, a, _f, _p) -> float:
		return a
	func charging() -> bool:
		return false
	func fight(_t) -> String:
		return ""


var _failures := 0
var _game


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "ok" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	var combat = _game.ctx.spawner
	var base: Vector3 = _game.ctx.terrain.spawn_point(1) + Vector3(20.0, 0.0, 40.0)
	var carrier: Node3D = combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(base.x, base.z, 1.6))
	var victim: Node3D = combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(base.x + 2.5, base.z, 1.6))
	var target := Target.new()
	target.setup(FakeBoss.new(), "hull", "hull", Vector3.ZERO, Vector2(1.0, 1.0))
	root.add_child(target)
	target.global_position = _game.ctx.terrain.drop_point(base.x + 2.0, base.z, 1.6)
	await physics_frame
	carrier._knock = Vector3(12.0, 0.0, 0.0)
	carrier.velocity = Vector3(12.0, 0.0, 0.0)
	var before: Vector3 = target.global_position
	var knocks_before: int = victim.knocks
	var pins_before: int = combat.pins

	combat._pin_step([target, carrier, victim])
	_check("target placed", before.distance_to(carrier.global_position) < 3.0, "target at %s, carrier at %s" % [before, carrier.global_position])
	_check("target untouched", target.global_position == before,
		"boss target moved %s" % [target.global_position - before])
	_check("real victim pinned", victim.knocks == knocks_before + 1 and combat.pins > pins_before,
		"victim knocks %d -> %d, pins %d -> %d" % [knocks_before, victim.knocks, pins_before, combat.pins])
	print("combat_pin_step_target_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(1 if _failures > 0 else 0)
