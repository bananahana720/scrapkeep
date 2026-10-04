extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("enemy_burrower_test")
var ball := Vector3.ZERO
var facts := []
var hits := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 11
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)
	await _frames(30)
	ball = game.player.ball_position()


func _spawn(offset: Vector3):
	var at := Vector3(ball.x + offset.x, 0.0, ball.z + offset.z)
	at.y = game.ctx.terrain.height(at.x, at.z) + 0.5
	var unit = game.combat.spawn_enemy("burrower", at)
	await _frames(2)
	return unit


func _attack() -> void:
	var unit = await _spawn(Vector3(10.0, 0.0, 3.0))
	t.check("spawns hidden", unit.hidden and unit.collision_layer == 0, "layer %d" % unit.collision_layer)
	unit.attack_phase.connect(func(f: Dictionary): facts.append(f))
	unit.hit_player.connect(func(_amount: float, _shove: Vector3): hits += 1)
	unit.hp = 100000.0
	unit._rest = 0.05
	var frames := 0
	while unit.phase != unit.Phase.WARN and frames < 300:
		game.player.reset_to(ball)
		await physics_frame
		frames += 1
	t.check("it commits a wind-up", unit.phase == unit.Phase.WARN, "%d frames" % frames)
	var first: Dictionary = facts[0] if not facts.is_empty() else {}
	t.eq("first fact row", first.get("row"), "E19")
	t.eq("first fact phase", first.get("phase"), "windup")
	t.eq("telegraph is a lane", first.get("geometry", {}).get("form"), "lane")
	t.check("still hidden in the wind-up", unit.hidden and unit.collision_layer == 0, "layer %d" % unit.collision_layer)
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var waited := 0.0
	while unit.phase == unit.Phase.WARN and waited < unit.warn_seconds + 1.0:
		game.player.reset_to(ball)
		await physics_frame
		waited += tick
	t.check("surfaces within one tick of warn_seconds", unit.phase == unit.Phase.LIVE and waited <= unit.warn_seconds + 2.0 * tick,
		"waited %.3f of %.2f" % [waited, unit.warn_seconds])
	t.check("surfaced and solid", not unit.hidden and unit.get_collision_layer_value(3), "layer %d" % unit.collision_layer)
	var strike := false
	for f in facts:
		strike = strike or f.get("phase") == "strike"
	t.check("a strike fact", strike, "%d facts" % facts.size())
	t.eq("one burst", unit.bursts, 1)
	t.eq("one hit on the ball in the lane", hits, 1)
	t.eq("hit source", game.combat.last_player_hit.get("source"), "burrower")
	frames = 0
	while unit.phase != unit.Phase.ROAM and frames < 120:
		await physics_frame
		frames += 1
	t.check("hides again after the lunge", unit.hidden and unit.collision_layer == 0, "layer %d" % unit.collision_layer)
	unit.free()


func _slam() -> void:
	var near = await _spawn(Vector3(10.0, 0.0, 3.0))
	var far = await _spawn(Vector3(-10.0, 0.0, -3.0))
	near.set_physics_process(false)
	far.set_physics_process(false)
	game.events.slammed.emit(far.global_position + Vector3(10.0, 0.0, 0.0), 1.0, 1.0)
	t.check("a slam 10 m away leaves it alive", not near.is_dead() and not far.is_dead(), "slam_kills %d" % (near.slam_kills + far.slam_kills))
	game.events.slammed.emit(near.global_position, 1.0, 1.0)
	t.check("a slam on the marker kills it", near.is_dead() and near.slam_kills == 1, "slam_kills %d" % near.slam_kills)
	t.check("the other stays alive", not far.is_dead(), "")
	far.hidden = false
	game.events.slammed.emit(far.global_position, 1.0, 1.0)
	t.check("a surfaced one is not killed by a slam", not far.is_dead(), "")
	far.free()


func _run() -> void:
	await _boot()
	await _attack()
	await _slam()
	game.free()
	quit(t.verdict())
