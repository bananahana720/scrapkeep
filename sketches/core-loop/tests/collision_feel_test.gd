extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Contact := preload("res://src/movement/contact.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# Collisions you can feel (thread "Make collisions feel physical", 13 Nov 2026). A real Game, a floor
# and a wall placed high above the map. Covers: a head-on roll into the wall publishes one bumped at
# its closing speed with the normal pointing back off the face, and juice answers it (camera kick,
# pad, sound); a glancing roll and a plain landing publish none; a chaser knocked into the wall stops
# into the wall lands one enemy_walled (no damage) and keeps its knock, so the run is unchanged, while a
# weak knock, a knock away from the wall and a knock up a ramp publish none. Evidence limit: rules in a headless run,
# not the feel, which needs Andrew's PC.

const BASE := Vector3(0, 400, 0)
const WALL_X := 12.0

var t := T.new("collision_feel_test")
var game
var bumps: Array = []
var walls: Array = []
var landings: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	return body


func _ticks(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.world.activities.set_physics_process(false)
	game.world.activities.clear()
	game.events.bumped.connect(func(at: Vector3, n: Vector3, s: float): bumps.append([at, n, s]))
	game.events.enemy_walled.connect(func(e: Node3D, at: Vector3, n: Vector3, s: float): walls.append([e, at, n, s]))
	game.events.landed.connect(func(i: float): landings.append(i))
	# A floor whose top is BASE.y and a wall whose -x face stands at WALL_X.
	_box(BASE - Vector3(0, 1, 0), Vector3(200, 2, 200))
	_box(BASE + Vector3(WALL_X + 2.0, 4.0, 0), Vector3(4, 8, 60))
	await physics_frame
	await _ball_cases()
	await _enemy_cases()
	game.free()
	quit(t.verdict())


func _roll(from: Vector3, velocity: Vector3, seconds: float) -> void:
	var ball = game.player.active_body()
	ball.set_active(true)
	ball.teleport(from, velocity)
	await _ticks(seconds)


func _ball_cases() -> void:
	var juice = game.presentation.juice if "presentation" in game and game.presentation != null and "juice" in game.presentation else null
	var start := BASE + Vector3(0, 1.0, 0)
	bumps.clear()
	var kicks_before: int = juice.hook_log.size() if juice != null else 0
	var rumbles_before: int = juice.rumble_log.size() if juice != null else 0
	await _roll(start, Vector3(20, 0, 0), 1.0)
	var head: Array = bumps[0] if not bumps.is_empty() else [Vector3.ZERO, Vector3.ZERO, 0.0]
	t.check("a head-on roll at 20 m/s bumps once", bumps.size() == 1, "%d bumps" % bumps.size())
	t.check("the bump is sized from the speed it hit at", float(head[2]) >= 16.0 and float(head[2]) <= 21.0, "%.1f m/s" % float(head[2]))
	t.check("the bump's normal points back off the face", (head[1] as Vector3).x < -0.9, str(head[1]))
	t.check("the bump is on the face", absf((head[0] as Vector3).x - WALL_X) < 0.3, str(head[0]))
	if juice != null:
		var kicked: bool = juice.hook_log.slice(kicks_before).any(func(h: Array): return h[1] == "bumped")
		var rumbled: bool = juice.rumble_log.slice(rumbles_before).any(func(r: Array): return r[0] == "bumped")
		t.check("juice kicks the camera into the wall and rumbles", kicked and rumbled, "kick %s, rumble %s" % [kicked, rumbled])
	else:
		t.check("juice is reachable", false, "no presentation.juice")
	t.check("bumped has an event row with a sound", EventKinds.has("bumped") and String(EventKinds.row("bumped")["sound"]) != "", "row")

	bumps.clear()
	var glance := Vector3(cos(deg_to_rad(75.0)), 0, sin(deg_to_rad(75.0))) * 14.0
	await _roll(start + Vector3(4, 0, -10), glance, 1.0)
	t.check("a glancing roll at cruise (75 degrees off the normal) does not bump", bumps.is_empty(), "%d bumps" % bumps.size())

	bumps.clear()
	landings.clear()
	await _roll(BASE + Vector3(-20, 14.0, 0), Vector3(0, -6, 0), 1.6)
	t.check("a hard landing is a landing, not a bump", bumps.is_empty() and not landings.is_empty(), "%d bumps, %d landings" % [bumps.size(), landings.size()])
	game.player.active_body().set_active(false)


func _never() -> bool:
	return false


func _chaser(at: Vector3) -> Node3D:
	var enemy: Node3D = game.combat.spawn_enemy("chaser", at)
	enemy.live = Callable(self, "_never")
	enemy.max_hp = 9999.0
	enemy.hp = 9999.0
	await _ticks(0.3)
	return enemy


func _enemy_cases() -> void:
	var enemy := await _chaser(BASE + Vector3(WALL_X - 4.0, 1.5, 0))
	walls.clear()
	var hp_before: float = enemy.hp
	enemy.knock(Vector3(1, 0, 0.6), 22.0 * float(enemy.weight))
	var along_before := 22.0 * 0.6 / Vector3(1, 0, 0.6).length()
	await _ticks(0.05)
	var through: bool = false
	for i in 40:
		await physics_frame
		if not walls.is_empty():
			break
	t.check("a chaser thrown into the wall slams it once", walls.size() == 1 and walls[0][0] == enemy, "%d slams" % walls.size())
	if not walls.is_empty():
		t.check("the slam faces back off the wall", (walls[0][2] as Vector3).x < -0.9, str(walls[0][2]))
		t.check("the slam is sized from the speed into the face", float(walls[0][3]) >= Contact.WALL_SLAM_SPEED, "%.1f m/s" % float(walls[0][3]))
	var knock: Vector3 = enemy._knock
	t.check("the slam leaves the knock as it was, so the run is unchanged", knock.x > 0.0 and absf(knock.z) > along_before * 0.5, "(%.1f, %.1f)" % [knock.x, knock.z])
	t.check("the slam deals no damage", is_equal_approx(float(enemy.hp), hp_before), "%.0f to %.0f" % [hp_before, float(enemy.hp)])
	await _ticks(0.8)
	t.check("one slam per knock", walls.size() == 1, "%d slams" % walls.size())

	walls.clear()
	enemy.global_position = BASE + Vector3(WALL_X - 3.0, 1.5, 0)
	await _ticks(0.2)
	enemy.knock(Vector3(1, 0, 0), 5.0 * float(enemy.weight))
	await _ticks(0.6)
	t.check("a weak knock into the wall is not a slam", walls.is_empty(), "%d slams" % walls.size())

	walls.clear()
	enemy.global_position = BASE + Vector3(WALL_X - 2.0, 1.5, 0)
	await _ticks(0.2)
	enemy.knock(Vector3(-1, 0, 0), 22.0 * float(enemy.weight))
	await _ticks(0.6)
	t.check("a knock away from the wall is not a slam", walls.is_empty(), "%d slams" % walls.size())
	# A hill is a floor, not a wall: a knock thrown up a 12 degree ramp carries on up it.
	walls.clear()
	var ramp := _box(BASE + Vector3(-30, 0, 40), Vector3(40, 2, 12))
	ramp.rotation.z = deg_to_rad(12.0)
	enemy.global_position = BASE + Vector3(-36, 2.5, 40)
	await _ticks(0.6)
	var before_x: float = enemy.global_position.x
	enemy.knock(Vector3(1, 0, 0), 22.0 * float(enemy.weight))
	await _ticks(0.8)
	t.check("a knock up a ramp is not a slam and carries up it", walls.is_empty() and enemy.global_position.x - before_x > 3.0,
		"%d slams, %.1f m up" % [walls.size(), enemy.global_position.x - before_x])
	t.check("enemy_walled has an event row with a sound", EventKinds.has("enemy_walled") and String(EventKinds.row("enemy_walled")["sound"]) != "", "row")
