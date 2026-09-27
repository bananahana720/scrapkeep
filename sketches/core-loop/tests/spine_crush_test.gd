extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# Crush pass-through: a heavy ball rolls straight through fodder it outweighs and
# keeps its speed; a light ball meeting the same chaser rams it and bounces as before.

const DRIVE_FROM := Vector2(-110.0, -120.0)
const AHEAD := 14.0
const SPEED := 20.0
# Heft 3.0 at 1 + mass/450 (300 was, at the old 1/150).
const HEAVY_MASS := 900
const KEEP := 0.95
const WINDOW := 150

var _game
var _double
var _source := Intent.Scripted.new()
var _failures := 0
var _started := false
var _runs: Array[Dictionary] = []
var _run := {}
var _ticks := 0
var _kills := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_double = SpawnerDouble.new()
		_game.add_child(_double)
		_double.setup(_game.ctx)
		_game.ctx.spawner = _double
		_game.ctx.calm = true
		_game.player.source = _source
		_game.events.enemy_killed.connect(func(_k, _a, _v): _kills += 1)
		_game.events.enemy_struck.connect(_on_struck)
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_game.run.add_scrap(HEAVY_MASS, Vector3.ZERO)
		_approach("heavy")
		return false
	_ticks += 1
	var speed: float = _game.player.planar_velocity().length()
	var ball: Vector3 = _game.player.ball_position()
	var enemy = _run["enemy"]
	if not _run.has("passed") and ball.x >= _run["enemy_x"]:
		_run["passed"] = _ticks
	elif _run.has("passed") and not _run.has("after"):
		_run["after"] = speed
	_run["last"] = speed
	if is_instance_valid(enemy):
		_run["knocks_seen"] = enemy.knocks
	if _ticks >= WINDOW:
		_run["alive"] = is_instance_valid(enemy) and not enemy.dead
		_run["knocks"] = _run.get("knocks_seen", -1)
		_run["kills"] = _kills
		_runs.append(_run)
		if _runs.size() == 1:
			_game.run.lose_scrap(HEAVY_MASS, Vector3.ZERO, "test")
			_approach("light")
		else:
			return _finish()
	return false


func _approach(label: String) -> void:
	_kills = 0
	_ticks = 0
	var at: Vector3 = _game.ctx.terrain.drop_point(DRIVE_FROM.x, DRIVE_FROM.y, 1.0)
	_game.player.reset_to(at, Vector3.RIGHT * SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(Vector3.RIGHT)
	_source.hold = {"move": Vector2(0.0, 1.0)}
	var spot := Vector2(DRIVE_FROM.x + AHEAD, DRIVE_FROM.y)
	var enemy: Node3D = _double.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.y, 0.0))
	_run = {"label": label, "heft": _game.run.heft(), "enemy": enemy, "enemy_x": spot.x}


func _on_struck(_enemy: Node3D, kind: String, force: float) -> void:
	if not _run.has("before"):
		_run["before"] = _game.player.planar_velocity().length()
		_run["struck_kind"] = kind
		_run["force"] = force


func _finish() -> bool:
	var heavy: Dictionary = _runs[0]
	var light: Dictionary = _runs[1]
	var before: float = heavy.get("before", -1.0)
	var after: float = heavy.get("after", -1.0)
	_report("crush keeps speed", before > 0.0 and after >= before * KEEP and heavy["kills"] == 1 and not heavy["alive"] and heavy["knocks"] == 0,
		"heft %.1f at %.1f m/s: struck (%s) at %.2f m/s, %.2f m/s on the tick after passing it (needs >= %.0f%%), %d kill(s), %d knock(s)"
			% [heavy["heft"], SPEED, heavy.get("struck_kind", "none"), before, after, KEEP * 100.0, heavy["kills"], heavy["knocks"]])
	_report("light ram bounces", light["alive"] and light["kills"] == 0 and light["knocks"] >= 1 and light.get("struck_kind", "") == "ram",
		"heft %.1f, same approach: rammed (%s), knocked %d time(s), chaser alive %s, %d kill(s)"
			% [light["heft"], light.get("struck_kind", "none"), light["knocks"], light["alive"], light["kills"]])
	print("spine_crush_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
