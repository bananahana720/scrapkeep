extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# A bolt hits and kills, for each class, through the live game. The camera is aimed at
# a chaser the way a player would aim, fire is held, and the test watches the bus:
# the shot is sent at the point under the reticle, the bolts strike with the class's
# kind, the chaser dies once, and the kill publishes its scrap. For the engineer a
# second chaser stands beside the first, and the arc caster's chain must reach it.

const AHEAD := 16.0
const BESIDE := 5.0
const TIMEOUT := 6.0

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _phase := ""
var _clock := 0.0
var _target: Node3D
var _buddy: Node3D
var _struck := {}
var _kills := []
var _on_target := 0
var _shots := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	if _phase == "":
		var events = _game.events
		events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
			var key := "%s:%s" % ["target" if enemy == _target else ("buddy" if enemy == _buddy else "other"), kind]
			_struck[key] = _struck.get(key, 0) + 1)
		events.enemy_killed.connect(func(kind: String, _at: Vector3, scrap: int): _kills.append([kind, scrap]))
		events.shot_fired.connect(_on_shot)
		_game.ctx.calm = true
		_game.player.source = _source
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_start("runner")
		return false
	_clock += delta
	if is_instance_valid(_target):
		_aim_at(_target.global_position + Vector3.UP * 0.4)
	_drive_fire()
	var done: bool = _kills.size() >= 1 and (_phase == "runner" or _struck.get("buddy:arc", 0) >= 1)
	if not done and _clock < TIMEOUT:
		return false
	_source.hold = {}
	_source.press = {}
	if _phase == "runner":
		_check("runner", "runner")
		# Die on purpose, then start a new run as the engineer.
		_game.run.damage(99999.0, "test")
		_game.flow.open_class_select()
		_game.flow.choose_class(0)
		_start("engineer")
		return false
	_check("engineer", "arc")
	_report("chain", _struck.get("buddy:arc", 0) >= 1,
		"the arc caster's chain reached the chaser beside the target %d times" % _struck.get("buddy:arc", 0))
	var ok := _failures == 0
	print("combat_bolt_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true


func _start(phase: String) -> void:
	_phase = phase
	_clock = 0.0
	_struck = {}
	_kills = []
	_on_target = 0
	_shots = 0
	_game.run.set_max_hp(99999.0)
	var ctx = _game.ctx
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	var at: Vector3 = ctx.terrain.spawn_point(1)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	_game.camera.snap(heading, -0.1)
	var ahead: Vector3 = at + heading * AHEAD
	_target = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(ahead.x, ahead.z, 1.6))
	_buddy = null
	if phase == "engineer":
		var side: Vector3 = heading.cross(Vector3.UP).normalized() * BESIDE
		_buddy = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(ahead.x + side.x, ahead.z + side.z, 1.6))
	_source.hold = {}
	_source.press = {"fire_pressed": true}


func _drive_fire() -> void:
	var snap: Dictionary = _game.ctx.spawner.weapon_driver.state_snapshot()
	if _phase == "runner":
		_source.hold = {}
		if bool(snap.get("reloading", false)):
			if bool(snap.get("window_open", false)):
				_source.press = {"fire_pressed": true}
		elif bool(snap.get("ready", false)):
			_source.press = {"fire_pressed": true}
	else:
		if bool(snap.get("charge_armed", false)):
			if float(snap.get("charge", 0.0)) >= 0.9999:
				_source.hold = {}
				_source.press = {"fire_released": true}
			else:
				_source.hold = {"fire_held": true}
		elif bool(snap.get("ready", false)):
			_source.press = {"fire_pressed": true}
			_source.hold = {"fire_held": true}
		else:
			_source.hold = {}


func _check(label: String, kind: String) -> void:
	var hits: int = _struck.get("target:%s" % kind, 0)
	var chaser_kills := 0
	for kill in _kills:
		if kill[0] == "chaser" and kill[1] == 3:
			chaser_kills += 1
	_report("%s_aim" % label, _on_target >= 1,
		"%d of %d shots were sent at a point on the chaser under the reticle" % [_on_target, _shots])
	_report("%s_hit" % label, hits >= 1, "%d bolt strikes of kind '%s' on the target" % [hits, kind])
	_report("%s_kill" % label, chaser_kills >= 1 and not is_instance_valid(_target) and _clock < TIMEOUT,
		"chaser killed %d time(s) with 3 scrap each, %.2f s after fire began (limit %.0f)" % [chaser_kills, _clock, TIMEOUT])


# The shot's committed point, compared with the target under the reticle.
func _on_shot(_weapon: String, _from: Vector3, _to: Vector3) -> void:
	_shots += 1
	if not is_instance_valid(_target):
		return
	var point: Vector3 = _game.ctx.spawner.last_shot["point"]
	var flat := Vector2(point.x - _target.global_position.x, point.z - _target.global_position.z)
	if flat.length() < _target.radius + 0.3 and absf(point.y - _target.global_position.y) < _target.half_height + 0.3:
		_on_target += 1


# Turns the camera so its centre ray passes through the point, as a player's mouse would.
func _aim_at(point: Vector3) -> void:
	var cam = _game.camera
	var d: Vector3 = (point - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)
