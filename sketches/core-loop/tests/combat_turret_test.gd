extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# The pylon turret, through real plants on a wall built beside the stage 1 spawn.
# The engineer rolls along the wall and presses E twice: once slow, once fast. Each
# plant banks its arrival speed, and the opening burst it fires must grow with the
# bank: more enemies arced, more damage each, a wider reach. While planted after the
# fast run, the camera must be in the shoulder view, held fire must be the turret
# (faster than the caster), and the turret's shots must go where the shoulder
# reticle points and strike the chaser under it.

const SLOW := 5.0
const FAST := 26.0
const RUN_UP := 0.12
const PLANT_WAIT := 0.5
const SHOULDER_WAIT := 0.6
const FIRE_SECONDS := 1.0
const DROP_WAIT := 0.4
const RING := 8

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _steps := []
var _index := 0
var _entered := false
var _clock := 0.0

var _base := Vector3.ZERO
var _heading := Vector3.ZERO
var _right := Vector3.ZERO
var _mounts := []
var _bursts := {}
var _struck := {}
var _turret_shots := 0
var _aimed := 0
var _aim_gap := 0.0
var _target: Node3D


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
	if _steps.is_empty():
		_setup()
		return false
	if _index >= _steps.size():
		return _finish()
	var step: Dictionary = _steps[_index]
	if not _entered:
		_entered = true
		_clock = 0.0
		(step["enter"] as Callable).call()
		return false
	_clock += delta
	if step.has("tick"):
		(step["tick"] as Callable).call()
	if _clock < float(step["seconds"]):
		return false
	(step["exit"] as Callable).call()
	_index += 1
	_entered = false
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = _source
	_game.events.mounted.connect(func(_at: Vector3, banked: float): _mounts.append(banked))
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
		_struck[kind] = _struck.get(kind, 0) + 1
		if enemy == _target:
			_struck["target:" + kind] = _struck.get("target:" + kind, 0) + 1)
	_game.events.shot_fired.connect(_on_shot)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_heading = ctx.terrain.entry_heading(1)
	_right = _heading.cross(Vector3.UP).normalized()
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	_base = Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z), spawn.z)
	_build_wall()
	_steps = [
		{"enter": _run_up.bind(SLOW), "seconds": RUN_UP, "exit": _press.bind("mount_pressed")},
		{"enter": _noop, "seconds": PLANT_WAIT, "exit": _record.bind("slow")},
		{"enter": _press.bind("mount_pressed"), "seconds": DROP_WAIT, "exit": _noop},
		{"enter": _run_up.bind(FAST), "seconds": RUN_UP, "exit": _press.bind("mount_pressed")},
		{"enter": _noop, "seconds": SHOULDER_WAIT, "exit": _record_fast},
		{"enter": _start_turret, "seconds": FIRE_SECONDS, "tick": _aim_tick, "exit": _stop_turret},
	]


# A tall wall whose face runs along the entry heading, through the spawn point.
func _build_wall() -> void:
	var body := StaticBody3D.new()
	var basis := Basis(_right, Vector3.UP, -_heading)
	body.transform = Transform3D(basis, _base - _right * 1.0 + Vector3.UP * 6.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 40.0, 90.0)
	shape.shape = box
	body.add_child(shape)
	_game.add_child(body)


func _noop() -> void:
	pass


func _press(key: String) -> void:
	_source.press[key] = true


# Clears the field, sets a ring of chasers out from the face, and rolls the ball along
# the wall 1.8 m off it at the given speed.
func _run_up(speed: float) -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	var ctx = _game.ctx
	var start := _base + _right * 1.8 - _heading * 3.0
	start.y = ctx.terrain.height(start.x, start.z) + 1.05
	var plant := start + _heading * speed * RUN_UP
	for i in RING:
		var out := plant + _right * (5.0 + 1.2 * i) + _heading * (-6.0 + 1.7 * i)
		ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(out.x, out.z, 1.6))
	_struck = {}
	_game.player.reset_to(start, _heading * speed)
	_game.player.body().global_position = start
	_game.camera.snap(_right, -0.1)


func _record(label: String) -> void:
	_bursts[label] = _game.ctx.spawner.last_burst.duplicate()
	_bursts[label]["banked"] = _mounts.back() if not _mounts.is_empty() else -1.0
	_bursts[label]["mounted"] = _game.player.kit.mounted
	_bursts[label]["struck"] = _struck.get("turret", 0)


func _record_fast() -> void:
	_record("fast")
	var cam = _game.camera
	_bursts["fast"]["shoulder_target"] = cam.shoulder_target
	_bursts["fast"]["shoulder_blend"] = cam.shoulder_blend


# One fresh chaser out in front of the face; the reticle is put on it and fire held.
func _start_turret() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	var ctx = _game.ctx
	var out: Vector3 = _game.player.ball_position() + _right * 18.0 + _heading * 4.0
	_target = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(out.x, out.z, 1.6))
	_target.hp = 99999.0
	_struck = {}
	_turret_shots = 0
	_aimed = 0
	_aim_gap = 0.0
	_source.hold = {}
	_source.press = {"fire_pressed": true}


func _aim_tick() -> void:
	if not is_instance_valid(_target):
		return
	var cam = _game.camera
	var d: Vector3 = (_target.global_position + Vector3.UP * 0.4 - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)
	var snap: Dictionary = _game.ctx.spawner.weapon_driver.state_snapshot()
	if bool(snap.get("ready", false)):
		_source.press = {"fire_pressed": true}


# Each turret shot is compared with an independent read of the shoulder camera's centre
# ray: the committed point must sit on that ray.
func _on_shot(weapon: String, _from: Vector3, _to: Vector3) -> void:
	if weapon != Weapons.PYLON_TURRET:
		return
	_turret_shots += 1
	var cam = _game.camera
	var point: Vector3 = _game.ctx.spawner.last_shot["point"]
	var origin: Vector3 = cam.aim_origin()
	var forward: Vector3 = cam.aim_forward()
	var along: float = (point - origin).dot(forward)
	var gap: float = (origin + forward * along).distance_to(point)
	_aim_gap = maxf(_aim_gap, gap)
	if gap < 0.25:
		_aimed += 1


func _stop_turret() -> void:
	_source.hold = {}
	_bursts["turret"] = {"shots": _turret_shots, "aimed": _aimed, "gap": _aim_gap,
		"target_hits": _struck.get("target:turret", 0), "mounted": _game.player.kit.mounted}


func _finish() -> bool:
	var slow: Dictionary = _bursts.get("slow", {})
	var fast: Dictionary = _bursts.get("fast", {})
	var planted: bool = slow.get("mounted", false) and fast.get("mounted", false) and _mounts.size() >= 2
	_report("plants", planted, "two real plants on the wall, banked %s m/s" % [_fmt(_mounts)])
	var grew: bool = planted and fast.get("banked", 0.0) > slow.get("banked", 0.0) + 10.0 \
		and fast.get("hit", 0) > slow.get("hit", 0) and fast.get("damage", 0.0) > slow.get("damage", 0.0) \
		and fast.get("radius", 0.0) > slow.get("radius", 0.0)
	_report("burst", grew,
		"opening burst: banked %.1f -> %d arcs x %.1f dmg, %.1f m reach; banked %.1f -> %d arcs x %.1f dmg, %.1f m reach"
			% [slow.get("banked", -1.0), slow.get("hit", 0), slow.get("damage", 0.0), slow.get("radius", 0.0),
				fast.get("banked", -1.0), fast.get("hit", 0), fast.get("damage", 0.0), fast.get("radius", 0.0)])
	_report("burst_strikes", fast.get("struck", 0) == fast.get("hit", -1) and fast.get("struck", 0) > slow.get("struck", 0),
		"turret strikes on the bus: %d slow, %d fast" % [slow.get("struck", 0), fast.get("struck", 0)])
	_report("shoulder", fast.get("shoulder_target", 0.0) == 1.0 and fast.get("shoulder_blend", 0.0) > 0.9,
		"mounted: shoulder_target %.1f, shoulder_blend %.2f" % [fast.get("shoulder_target", 0.0), fast.get("shoulder_blend", 0.0)])
	var turret: Dictionary = _bursts.get("turret", {})
	var turret_floor: float = float(Weapons.BASE[Weapons.PYLON_TURRET]["floor_s"])
	var expected_sparks := int(FIRE_SECONDS / turret_floor)
	_report("turret_rate", turret.get("mounted", false) and turret.get("shots", 0) >= expected_sparks
		and float(Weapons.BASE[Weapons.PYLON_TURRET]["damage"]) > float(Weapons.BASE[Weapons.ARC_CASTER]["damage"]),
		"%d mounted turret volleys in %.0f s at %.2f s spark floor (expected >= %d)" % [turret.get("shots", 0), FIRE_SECONDS, turret_floor, expected_sparks])
	_report("shoulder_aim", turret.get("shots", 0) > 0 and turret.get("aimed", 0) == turret.get("shots", 0) and turret.get("target_hits", 0) >= 1,
		"%d of %d turret shots on the shoulder reticle's ray (worst %.3f m off), %d strikes on the chaser under it"
			% [turret.get("aimed", 0), turret.get("shots", 0), turret.get("gap", 0.0), turret.get("target_hits", 0)])
	var ok := _failures == 0
	print("combat_turret_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true


static func _fmt(values: Array) -> String:
	var parts := PackedStringArray()
	for v in values:
		parts.append("%.1f" % v)
	return "[" + ", ".join(parts) + "]"
