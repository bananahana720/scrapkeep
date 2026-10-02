extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")

const PILOTS := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster"}
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const WALL_X := -52.0

var _failures := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _origin := FLAT_SHELF
var _wall_body: StaticBody3D


func _check(label: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [label, detail, "ok" if ok else "FAIL"])
	if not ok:
		_failures += 1


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

func _pilot(name: String) -> void:
	var def: Resource = ClassDef.by_id(PILOTS[name])
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_source.hold = {}
	_source.press = {}


func _spawn(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, at)
	enemy.live = Callable(self, "_never")
	return enemy


func _point(dx: float, dz: float, lift: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_origin.x + dx, _origin.z + dz, lift)


func _clear_field() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()


func _place(at: Vector3, velocity := Vector3.ZERO) -> void:
	_player.reset_to(at, velocity)
	_source.hold = {}


func _wall() -> void:
	_wall_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 30.0, 80.0)
	shape.shape = box
	_wall_body.add_child(shape)
	_game.add_child(_wall_body)
	_wall_body.global_position = Vector3(WALL_X - 1.0, 15.0, FLAT_SHELF.z)


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
	_wall()
	await _sim(0.3)
	await _mounted_body_line()
	_wall_body.free()
	print("harpoon_mounted_body_line_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(1 if _failures > 0 else 0)


# A body line held through a real mount (E at a steep face) follows its body and lets go
# of it when the body dies, as it does unmounted.
func _mounted_body_line() -> void:
	_pilot("sable")
	var chaser := _spawn("chaser", _point(WALL_X - _origin.x + 4.0, -16, 1.5))
	await _sim(0.4)
	_place(_game.ctx.terrain.drop_point(WALL_X + 1.8, FLAT_SHELF.z, 1.4))
	await _sim(0.1)
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	_source.hold = {"harpoon_held": true}
	await _sim(0.15)
	_source.press = {"mount_pressed": true}
	await _sim(0.1)
	_source.press = {}
	var mounted: bool = _player.kit.mounted and _player.kit.hooked and _player.kit.on_body
	_check("real mount on a body line", mounted,
		"mounted %s hooked %s on_body %s" % [_player.kit.mounted, _player.kit.hooked, _player.kit.on_body])
	await _sim(0.5)
	chaser.global_position += Vector3(8.0, 0.0, 0.0)
	await _sim(0.3)
	var gap: float = _player.kit.anchor.distance_to(chaser.global_position)
	_check("anchor follows the moved body while mounted", mounted and _player.kit.mounted and gap < 1.0,
		"anchor-to-body %.2f m, mounted %s" % [gap, _player.kit.mounted])
	chaser.take_damage(999999.0)
	await _sim(0.3)
	_check("killed body drops the line while mounted", mounted and _player.kit.mounted and not _player.kit.hooked and not _player.kit.on_body,
		"hooked %s on_body %s mounted %s" % [_player.kit.hooked, _player.kit.on_body, _player.kit.mounted])
	_source.hold = {}
	_source.press = {"mount_pressed": true}
	await _sim(0.2)
	_source.press = {}
	_player.release_grapple()
	if is_instance_valid(chaser):
		chaser.queue_free()
	await _sim(0.2)
