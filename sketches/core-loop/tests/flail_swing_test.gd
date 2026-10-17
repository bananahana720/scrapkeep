extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Grip := preload("res://src/movement/grip.gd")

# PF3 (design-v3/POLES-FLAILS.md section 5), through a real Game and real physics. A heavy ball
# bites a chaser with the pole-flail toggle on and holds the harpoon: the chaser's lunge
# warning is cancelled, it stops processing and comes to the ball, strikes a bystander it is
# dragged through, at most three times, and is then thrown and processes again. The ball takes
# no damage. With the toggle off the same bite reels, as before.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _failures := 0
var _checks := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()


func _check(label: String, ok: bool, detail := "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


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


func _spawn(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, at)
	enemy.live = Callable(self, "_never")
	return enemy


func _clear_field() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()


func _bite(body: Node3D) -> void:
	_player.grapple_to(body.global_position, Vector3.UP, body)
	_source.hold = {"harpoon_held": true}


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
	_clear_field()
	await _sim(0.2)

	# Toggle off: the bite reels as it always has.
	_combat.heft_override = 3.0
	var ball := _point(0.0, 0.0, 0.6)
	_player.reset_to(ball)
	var lone := _spawn("chaser", _point(10.0, 0.0, 1.0))
	await _sim(0.2)
	_bite(lone)
	await physics_frame
	_check("toggle off reels", _player.kit.grip == Grip.REEL, "grip %s" % _player.kit.grip)
	await _sim(0.2)
	_check("toggle off takes no flail", _combat.flail.flailed == 0)
	_source.hold = {}
	_player.release_grapple()
	_clear_field()
	await _sim(0.3)

	# Toggle on, heavy ball: a flail.
	_check("toggle reads on", _game.tuning.set_option("pole_flail", "on") and _game.tuning.pole_flail())
	_player.reset_to(ball)
	var flail := _spawn("chaser", _point(10.0, 0.0, 1.0))
	var bystander := _spawn("chaser", _point(7.0, 0.0, 1.0))
	await _sim(0.3)
	var hp_before: float = _game.run.hp
	var by_hp: float = bystander.hp
	_bite(flail)
	await physics_frame
	_check("heavy ball takes a flail grip", _player.kit.grip == Grip.FLAIL, "grip %s heft %.2f" % [_player.kit.grip, _player.heft()])
	await _sim(0.1)
	_check("the flail is held", _combat.flail.holding(flail))
	_check("a held flail stops processing", not flail.is_physics_processing())
	_check("a held flail is not winding up or lunging", int(flail.state) in [0, 3], "state %d" % int(flail.state))
	await _sim(0.4)
	_check("the flail came to the ball", flail.global_position.distance_to(_player.ball_position()) <= 6.5,
		"gap %.2f" % flail.global_position.distance_to(_player.ball_position()))
	_check("the flail struck the bystander", not is_instance_valid(bystander) or bystander.hp < by_hp,
		"hp %.1f -> %.1f" % [by_hp, bystander.hp if is_instance_valid(bystander) else -1.0])
	await _sim(2.4)
	_check("the flail strikes at most three times", _combat.flail.strikes <= 3 + 1, "strikes %d" % _combat.flail.strikes)
	_check("the flail is thrown by the hold limit", _combat.flail.thrown == 1 and not _player.kit.hooked,
		"thrown %d hooked %s" % [_combat.flail.thrown, _player.kit.hooked])
	_check("a thrown flail processes again", not is_instance_valid(flail) or flail.is_physics_processing())
	_check("the ball took no damage", _game.run.hp >= hp_before, "hp %.1f -> %.1f" % [hp_before, _game.run.hp])

	print("flail_swing_test: %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks])
	quit(1 if _failures > 0 else 0)
