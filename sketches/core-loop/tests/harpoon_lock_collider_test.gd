extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const Target := preload("res://src/boss/boss_target.gd")

# Under --harpoon=lock the soft-lock only bites a body the ball can touch: a Brindle crane magnet
# has no collider, so the line refuses it, while a normal enemy in the same cone still locks.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)


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


var _failures := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()


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


func _never() -> bool:
	return false


func _point(dx: float, dz: float, lift: float) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, lift)


func _aim_at(target: Node3D) -> Dictionary:
	var ball: Vector3 = _player.ball_position()
	var eye := ball + Vector3(0, 0.8, 4.0)
	return _game.aim_along(eye, (target.global_position - eye).normalized())


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_game.run.set_max_hp(99999.0)
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()
	await _sim(0.2)
	var def: Resource = ClassDef.by_id("pylon_engineer")
	_game.tuning.set_option("harpoon", "lock")
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()

	var magnet := Target.new()
	magnet.setup(FakeBoss.new(), "magnet", "magnet_port", Vector3.ZERO, Vector2(1.5, 1.5))
	root.add_child(magnet)
	magnet.global_position = _point(0, -18, 5.0)
	var chaser: Node3D = _combat.spawn_enemy("chaser", _point(0, -18, 1.5))
	chaser.live = Callable(self, "_never")
	await _sim(0.1)
	_player.reset_to(_point(0, 0, 1.4), Vector3.ZERO)
	await _sim(0.05)

	var on_magnet := _aim_at(magnet)
	_check("magnet refused", on_magnet.get("body") != magnet,
		"lock aim on a collider-less magnet: state %s, body %s" % [on_magnet.get("state"), on_magnet.get("body")])
	magnet.free()
	await _sim(0.05)
	var on_chaser := _aim_at(chaser)
	_check("enemy still locks", on_chaser.get("state") == Augments.AIM_BODY and on_chaser.get("body") == chaser,
		"lock aim on a chaser: state %s, body %s" % [on_chaser.get("state"), on_chaser.get("body")])

	print("harpoon_lock_collider_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(1 if _failures > 0 else 0)
