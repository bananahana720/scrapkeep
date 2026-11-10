extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Indicator := preload("res://src/movement/indicator.gd")

# The wall kick's aim mark shows only while a kick is on offer. In the air beside a steep face the
# ball wears it; on a mount Space is the slingshot, so the kick's mark goes and the slingshot's shows
# once it charges. The kick's record used to keep its last value through a mount (the kick rule never
# ran while mounted), so the PC filmed two stacked fans on a mount. Each mark the ball draws is an aim
# mark that starts clear of the ball.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const WALL_X := -52.0

var _failures := 0
var _game
var _player
var _source := Intent.Scripted.new()
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
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_game.run.set_max_hp(99999.0)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	var def: Resource = ClassDef.by_id("pylon_engineer")
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_wall()
	await _sim(0.3)
	await _marks()
	_wall_body.free()
	print("aim_mark_mount_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(1 if _failures > 0 else 0)


func _marks() -> void:
	var kit = _player.kit
	var shapes: Dictionary = _player.indicator.shapes
	# Dropped from well above the shelf, 1.8 m off the face: in the air for the next half second.
	_player.reset_to(_game.ctx.terrain.drop_point(WALL_X + 1.8, FLAT_SHELF.z, 8.0))
	await _sim(0.2)
	var kick: Dictionary = shapes.get("vault", {})
	_check("in the air beside a face the kick's mark shows", not kit.vault_aim.is_empty() and not kick.is_empty() and not kit.mounted,
		"aim %s, drawn %s, mounted %s" % [not kit.vault_aim.is_empty(), not kick.is_empty(), kit.mounted])
	_check("it is an aim mark that starts clear of the ball", Indicator.is_aim(kick) and float(kick.get("clear", 0.0)) > 1.0,
		"aim %s, clear %.2f m" % [Indicator.is_aim(kick), float(kick.get("clear", 0.0))])
	_source.press = {"mount_pressed": true}
	await _sim(0.1)
	_source.press = {}
	await _sim(0.3)
	_check("on a mount the kick is not on offer, so its mark is gone", kit.mounted and kit.vault_aim.is_empty() and not shapes.has("vault"),
		"mounted %s, aim %s, drawn %s" % [kit.mounted, not kit.vault_aim.is_empty(), shapes.has("vault")])
	_source.press = {"jump_pressed": true}
	_source.hold = {"jump_held": true}
	await _sim(0.3)
	_source.press = {}
	var sling: Dictionary = shapes.get("slingshot", {})
	_check("the slingshot's mark is the one aim mark while it charges", kit.mounted and Indicator.is_aim(sling) and float(sling.get("clear", 0.0)) > 1.0 and not shapes.has("vault"),
		"mounted %s, slingshot %s, clear %.2f m, kick drawn %s" % [kit.mounted, not sling.is_empty(), float(sling.get("clear", 0.0)), shapes.has("vault")])
	_source.hold = {}
	await _sim(1.0)
