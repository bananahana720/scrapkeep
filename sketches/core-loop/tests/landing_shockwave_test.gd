extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# A landing's shockwave strikes every body in reach, the one the ball landed on included.
#   harpoon smash    the landed chaser and a chaser beside it each take the SLAM strike
#   Warden           a smash landed on the Warden gives it the contact and then the SLAM
#   held-brake slam  Rivet's skid landing on a chaser gives it and a bystander the SLAM
# Evidence limit: contacts are real physics from placed starts, not a player's run.

const OUT := 58.0
const BESIDE := Vector3(4.0, 0.0, 0.0)

var _game
var _player
var _warden
var _source := Intent.Scripted.new()
var _failures := 0
var _smashed := 0
var _strikes := {}


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


func _top() -> Vector3:
	return _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_warden.global_position.x + out, _warden.global_position.z, 1.5)


func _on_struck(enemy: Node3D, kind: String, _force: float) -> void:
	var id := enemy.get_instance_id()
	if not _strikes.has(id):
		_strikes[id] = []
	_strikes[id].append(kind)


func _kinds(enemy: Node3D) -> Array:
	return _strikes.get(enemy.get_instance_id(), [])


func _still(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = _game.ctx.spawner.spawn_enemy(kind, at)
	enemy.live = func(): return false
	enemy.hp = 99999.0
	return enemy


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	_game.events.enemy_struck.connect(_on_struck)
	await _sim(0.4)
	_game.run.set_max_hp(99999.0)
	_game.ctx.spawner.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden) or _player.kit.smash_flavour != "skid":
		print("landing_shockwave_test: FAIL (no Warden, or the class's smash is not the skid)")
		quit(1)
		return
	_warden.hp = 99999.0
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()

	await _smash_on_chaser()
	await _smash_on_warden()
	await _slam_on_chaser()

	print("landing_shockwave_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _smash(body: Node3D, at: Vector3) -> void:
	_smashed = 0
	_strikes.clear()
	_player.reset_to(at + Vector3(-6.0, 6.0, 0.0))
	_player.grapple_to(at, Vector3.UP, body)
	_source.hold = {"harpoon_held": true}
	await _sim(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}
	await _sim(0.3)


func _smash_on_chaser() -> void:
	_player.reset_to(_ground(OUT))
	await _sim(0.3)
	var at := _ground(30.0)
	var chaser := _still("chaser", at)
	var beside := _still("chaser", at + BESIDE)
	await _smash(chaser, chaser.global_position)
	_report("chaser smash landed", _smashed == 1, "%d smashes on the chaser" % _smashed)
	_report("landed chaser shocked", "slam" in _kinds(chaser),
		"the landed chaser took %s" % [_kinds(chaser)])
	_report("bystander shocked", "slam" in _kinds(beside),
		"the chaser beside it took %s" % [_kinds(beside)])
	chaser.queue_free()
	beside.queue_free()


func _smash_on_warden() -> void:
	_player.reset_to(_ground(OUT))
	await _sim(0.3)
	await _smash(_warden, _top())
	var kinds := _kinds(_warden)
	var contact := kinds.filter(func(kind): return kind in ["stomp", "ram"])
	_report("Warden smash landed", _smashed == 1, "%d smashes on the Warden" % _smashed)
	_report("Warden takes the contact, then the shockwave", not contact.is_empty() and "slam" in kinds,
		"the Warden took %s" % [kinds])


func _slam_on_chaser() -> void:
	_player.reset_to(_ground(OUT))
	await _sim(0.3)
	var at := _ground(30.0)
	var chaser := _still("chaser", at)
	var beside := _still("chaser", at + BESIDE)
	_strikes.clear()
	_source.hold = {}
	_player.reset_to(at + Vector3(0.0, 6.0, 0.0), Vector3(0.0, -8.0, 0.0))
	await _sim(0.05)
	_source.hold = {"brake_held": true}
	await _sim(1.2)
	_source.hold = {}
	_report("landed chaser takes the slam", "slam" in _kinds(chaser),
		"a chaser the held-brake slam landed on took %s" % [_kinds(chaser)])
	_report("bystander takes the slam", "slam" in _kinds(beside),
		"the chaser beside it took %s" % [_kinds(beside)])
	chaser.queue_free()
	beside.queue_free()
