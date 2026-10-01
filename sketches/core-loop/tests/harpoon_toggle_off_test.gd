extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")

const PILOTS := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster"}
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _failures := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _origin := FLAT_SHELF


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

func _pilot(name: String, harpoon := "shot", pull := "self", keys := "shift") -> void:
	var def: Resource = ClassDef.by_id(PILOTS[name])
	_game.tuning.set_option("harpoon", harpoon)
	_game.tuning.set_option("harpoon_pull", pull)
	_game.tuning.set_option("harpoon_keys", keys)
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
	await _toggle_off()
	print("harpoon_toggle_off_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(1 if _failures > 0 else 0)


# Turning the harpoon off lets go of a body line, so the line cannot outlive its setting.
func _toggle_off() -> void:
	_pilot("sable", "shot")
	var chaser := _spawn("chaser", _point(0, -20, 1.5))
	await _sim(0.4)
	_place(_point(0, 0, 1.4))
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	var held: bool = _player.kit.hooked and _player.kit.on_body
	_game.tuning.set_option("harpoon", "off")
	await _sim(0.05)
	var kept: bool = _player.kit.hooked or _player.kit.on_body
	_player.set_velocity_now(Vector3(0, 0, -12))
	await _sim(0.03)
	var after_ride: bool = _player.kit.hooked or _player.kit.on_body
	_check("toggle off drops the body line", held and not kept and not after_ride,
		"line held before %s; harpoon_on %s; line after toggle %s; after set_velocity_now %s" % [held, _player.kit.harpoon_on, kept, after_ride])
	_player.release_grapple()
	_game.tuning.set_option("harpoon", "shot")
	chaser.queue_free()
	await _sim(0.2)
