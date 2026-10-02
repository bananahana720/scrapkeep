extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenDrop := preload("res://src/combat/warden_drop.gd")

# A harpoon smash that lands a real drop on the Warden must not be followed by its own landing
# shockwave striking the same body again: that second strike scores `floor` inside the drop's
# rearm and plays the clank, the sound of a failure, over the best moment of the fight.
#   landed drop      one drop, no strike_deflected, and exactly one contact on the Warden
#   bystander        a second enemy inside the shockwave radius still takes the SLAM strike
#   plain chaser     a landed body with no drop rule still takes the shockwave's SLAM strike
# Evidence limit: contacts are real physics from placed starts, not a player's run.

const OUT := 58.0

var _game
var _player
var _warden
var _drop
var _source := Intent.Scripted.new()
var _failures := 0
var _deflected := 0
var _drops := 0
var _smashed := 0
var _warden_strikes: Array = []
var _bystander_slams := 0
var _bystander: Node3D
var _chaser: Node3D
var _chaser_slams := 0


func _report(label: String, ok: bool, detail: String) -> void:
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
		if is_instance_valid(_warden):
			_warden._pulse_clock = 0.0
			_warden._charging = false
		await physics_frame


func _mast() -> Vector3:
	return _warden.global_position


func _top() -> Vector3:
	return _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_mast().x + out, _mast().z, 1.5)


func _on_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if enemy == _warden:
		_warden_strikes.append(kind)
	elif enemy == _bystander and kind == "slam":
		_bystander_slams += 1
	elif enemy == _chaser and kind == "slam":
		_chaser_slams += 1


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_game.tuning.set_option("loop_mode", "drop")
	_game.tuning.set_option("gun_role", "hold")
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	_game.events.strike_deflected.connect(func(_e: Node3D, _kind: String, _punch: float, _plating: float): _deflected += 1)
	_game.events.warden_drop_landed.connect(func(_at: Vector3, _speed: float, _left: int, _n: int): _drops += 1)
	_player.struck.connect(_on_struck)
	await _sim(0.4)
	_game.run.set_max_hp(99999.0)
	_game.ctx.spawner.heft_override = 1.0
	_warden = _game.flow.warden
	_drop = _warden.get("drop") if is_instance_valid(_warden) else null
	if _drop == null:
		print("harpoon_smash_landing_test: FAIL (no drop rules)")
		quit(1)
		return
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()

	await _landed_drop()
	await _landed_chaser()

	print("harpoon_smash_landing_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _landed_drop() -> void:
	_player.reset_to(_ground(OUT))
	await _sim(0.3)
	_warden._open_left = 0.0
	if _warden._open_left <= 0.0:
		_warden._open(_warden.CORE_WINDOW)
	_drop._rearm = 0.0
	_drop._dropped = false
	_bystander = _game.ctx.spawner.spawn_enemy("chaser", _top() + Vector3(4.0, 0.5, 0.0))
	_bystander.live = func(): return false
	var hp: float = _warden.hp
	_player.reset_to(_top() + Vector3(-6.0, 6.0, 0.0))
	_player.grapple_to(_top(), Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	await _sim(0.02)
	_warden_strikes.clear()
	_deflected = 0
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}
	await _sim(0.3)
	_report("drop landed", _smashed == 1 and _drops == 1 and _warden.hp < hp,
		"smashes %d, drops %d, Warden %.0f -> %.0f HP" % [_smashed, _drops, hp, _warden.hp])
	_report("no clank after the drop", _deflected == 0,
		"%d strike_deflected after the landed drop; Warden strikes %s" % [_deflected, _warden_strikes])
	_report("bystander still shocked", _bystander_slams >= 1,
		"the enemy beside the Warden took %d slam strikes" % _bystander_slams)
	if is_instance_valid(_bystander):
		_bystander.queue_free()



func _landed_chaser() -> void:
	_smashed = 0
	_chaser_slams = 0
	_player.reset_to(_ground(OUT))
	await _sim(0.3)
	_chaser = _game.ctx.spawner.spawn_enemy("chaser", _top() + Vector3(0.0, 0.5, 8.0))
	_chaser.live = func(): return false
	_chaser.hp = 99999.0
	_player.reset_to(_chaser.global_position + Vector3(-6.0, 6.0, 0.0))
	_player.grapple_to(_chaser.global_position, Vector3.UP, _chaser)
	_source.hold = {"harpoon_held": true}
	await _sim(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}
	await _sim(0.3)
	_report("chaser smash landed", _smashed == 1, "%d smashes on the plain chaser" % _smashed)
	_report("plain chaser still shocked", _chaser_slams >= 1,
		"the landed chaser took %d shockwave slam strikes" % _chaser_slams)
	if is_instance_valid(_chaser):
		_chaser.queue_free()
