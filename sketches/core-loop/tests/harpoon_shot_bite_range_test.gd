extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# A shot line and a lock line bitten into the same body at the same range must behave the same:
# the latched auto-release counts the body's radius once, whatever anchor_offset the bite stored.
#   bite    a chaser just outside the release range stays hooked after a bite, shot or lock
#   winch   a winched line lets go at the same centre-to-centre range under shot and lock
# Evidence limit: one chaser kind on the Spillway's flat shelf; the feel of the release is unjudged.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const MARGIN := 0.15
const WINCH_TOLERANCE := 0.8
const WINCH_LIMIT_SECONDS := 6.0

var _failures := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()


func _check(label: String, ok: bool, detail: String) -> void:
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


func _pilot(harpoon: String) -> void:
	var def: Resource = ClassDef.by_id("pylon_engineer")
	_game.tuning.set_option("harpoon", harpoon)
	_game.tuning.set_option("harpoon_pull", "self")
	_game.tuning.set_option("harpoon_keys", "shift")
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_source.hold = {}
	_source.press = {}


func _point(dx: float, dz: float, lift: float) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, lift)


func _cam(from: Vector3, to: Vector3) -> void:
	_game.camera.set_process(false)
	_game.camera.cam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


func _spawn_chaser(at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", at)
	enemy.live = Callable(self, "_never")
	return enemy


func _release_range(chaser: Node3D) -> float:
	return Augments.MIN_ROPE + Tuning.RADIUS + float(chaser.get("radius"))


# Bites the body the way a press does: the aim's surface point, or its centre under lock.
func _bite(mode: String, ball: Vector3, chaser: Node3D) -> Dictionary:
	_pilot(mode)
	_player.reset_to(ball, Vector3.ZERO)
	await physics_frame
	var eye := ball + Vector3(0, 0.8, 4.0)
	var aim: Dictionary = _game.aim_along(eye, (chaser.global_position - eye).normalized())
	if aim.get("body") == chaser:
		_player.grapple_to(aim["point"], aim["normal"], aim["body"])
	return aim


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
	_combat.heft_override = 1.0
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()
	await _sim(0.2)

	await _bite_range()
	await _winch_range()

	print("harpoon_shot_bite_range_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _bite_range() -> void:
	var ball := _point(0, 0, 1.6)
	var chaser := _spawn_chaser(_point(0, -10, 1.5))
	await _sim(0.3)
	var gap := _release_range(chaser) + MARGIN
	for mode in ["lock", "shot"]:
		chaser.global_position = ball + Vector3(0, chaser.global_position.y - ball.y, -gap)
		var aim: Dictionary = await _bite(mode, ball, chaser)
		var kit = _player.kit
		var bitten: bool = kit.hooked
		await _sim(0.05)
		var offset: float = kit.anchor_offset.length()
		_check("%s: bite at %.2f m holds" % [mode, gap], bitten and kit.hooked,
			"aimed body %s, release range %.2f m, stored anchor_offset %.2f m, bitten %s, hooked after 3 ticks %s" % [
				aim.get("body") == chaser, _release_range(chaser), offset, bitten, kit.hooked])
		_player.release_grapple()
	chaser.queue_free()
	await _sim(0.1)


# Winches from 12 m and reports the centre-to-centre range on the last tick the line was held.
func _drop_range(mode: String, ball: Vector3, chaser: Node3D) -> float:
	chaser.global_position = ball + Vector3(0, chaser.global_position.y - ball.y, -12.0)
	await _bite(mode, ball, chaser)
	_source.hold = {"harpoon_held": true}
	var last := -1.0
	var ticks := roundi(WINCH_LIMIT_SECONDS * Engine.physics_ticks_per_second)
	for i in ticks:
		if not _player.kit.hooked:
			break
		last = _player.body().global_position.distance_to(chaser.global_position)
		await physics_frame
	_source.hold = {}
	_player.release_grapple()
	return last if not _player.kit.hooked or last >= 0.0 else -1.0


func _winch_range() -> void:
	var ball := _point(0, 0, 1.6)
	var chaser := _spawn_chaser(_point(0, -12, 1.5))
	await _sim(0.3)
	var lock := await _drop_range("lock", ball, chaser)
	await _sim(0.2)
	var shot := await _drop_range("shot", ball, chaser)
	_check("winch: shot lets go where lock does", lock > 0.0 and shot > 0.0 and absf(shot - lock) <= WINCH_TOLERANCE,
		"last held range lock %.2f m, shot %.2f m, release range %.2f m, tolerance %.1f m" % [
			lock, shot, _release_range(chaser), WINCH_TOLERANCE])
	chaser.queue_free()
