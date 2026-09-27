extends SceneTree

const Game := preload("res://src/game.gd")
const Lobber := preload("res://src/combat/lobber.gd")

# In the arena, combat's telegraphs and the lobber's aim stand on the boss module's
# floor, not on the parked stage terrain under it. The double is a boss whose
# ground_height_at(point) answers a flat floor 30 m above the terrain, with a collider
# there so the ball and a drone lobber rest on it. A shell's ring centres on that floor,
# the shell hits the ball resting there, and the lobber aims its landing at that floor.

const LIFT := 30.0
const TIMEOUT := 4.0


class BossDouble extends Node3D:
	var floor_y := 0.0

	func ground_height_at(_point: Vector3) -> float:
		return floor_y

	func build(at: Vector3) -> void:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(120.0, 1.0, 120.0)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		body.global_position = Vector3(at.x, floor_y - 0.5, at.z)


var _game
var _combat
var _failures := 0
var _step := 0
var _clock := 0.0
var _boss: Node3D
var _centre := Vector3.ZERO
var _terrain_y := 0.0
var _lobber: Node3D
var _shell_hit := false
var _shell_done := false
var _aim_y := INF


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
	match _step:
		0:
			_setup()
			_step = 1
		1:
			_clock += delta
			if _clock > 0.5:
				_fire_shell()
				_clock = 0.0
				_step = 2
		2:
			_clock += delta
			if _shell_done or _clock > TIMEOUT:
				_report("shell_hit", _shell_done and _shell_hit,
					"the shell landed on the arena floor ball: exploded %s, hit %s" % [_shell_done, _shell_hit])
				_lobber._clock = Lobber.CYCLE - 0.05
				_clock = 0.0
				_step = 3
		3:
			_clock += delta
			if _aim_y != INF or _clock > TIMEOUT:
				_report("lobber_aim", absf(_aim_y - _boss.floor_y) < 0.01,
					"the drone lobber aimed its landing at y %.2f (floor %.2f, terrain %.2f)" % [_aim_y, _boss.floor_y, _terrain_y])
				return _finish()
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_centre = ctx.terrain.spawn_point(1)
	_terrain_y = ctx.terrain.height(_centre.x, _centre.z)
	_boss = BossDouble.new()
	_boss.floor_y = _terrain_y + LIFT
	ctx.root.add_child(_boss)
	_boss.build(_centre)
	ctx.boss = _boss
	ctx.flow.in_arena = true
	var at := Vector3(_centre.x, _boss.floor_y + 1.05, _centre.z)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	_lobber = ctx.spawner.spawn_enemy("lobber", Vector3(_centre.x + 15.0, _boss.floor_y + 2.2, _centre.z))
	_lobber.fired.connect(func(_origin: Vector3, landing: Vector3, _flight: float):
		if _aim_y == INF:
			_aim_y = landing.y)


func _fire_shell() -> void:
	var landing := Vector3(_centre.x, _terrain_y, _centre.z)
	var before: Array = _game.get_tree().get_nodes_in_group("enemy_shot")
	_combat._on_lobber_fired(_lobber.muzzle_point(), landing, 1.9, _lobber)
	var shell: Node3D = null
	for node in _game.get_tree().get_nodes_in_group("enemy_shot"):
		if not node in before:
			shell = node
	var ring: Node3D = shell.ring
	var ball: Vector3 = _game.player.ball_position()
	_report("ring_centre", absf(ring.center.y - _boss.floor_y) < 0.01,
		"the shell's ring centres at y %.2f (floor %.2f, terrain %.2f)" % [ring.center.y, _boss.floor_y, _terrain_y])
	_report("contains", ring.contains(ball),
		"the ring contains the ball resting on the floor at y %.2f" % ball.y)
	shell.exploded.connect(func(_at: Vector3, _blast: float, hit: bool):
		_shell_done = true
		_shell_hit = hit)


func _finish() -> bool:
	var ok := _failures == 0
	print("combat_arena_ground_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
