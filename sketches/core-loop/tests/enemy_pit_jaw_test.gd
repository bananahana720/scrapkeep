extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# The pit jaw (design-v3/WORLD-ROSTERS.md): it sets under a ball on the floor, bites and holds
# it there, passes under a ball that is off the floor, and dies to a slam on its open jaw.

var game
var t := T.new("enemy_pit_jaw_test")
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
	var unit = game.combat.spawn_enemy("pit_jaw", at)
	await _frames(2)
	return unit


func _bite() -> void:
	var unit = await _spawn(Vector3(10.0, 0.0, 3.0))
	t.check("spawns", unit != null and unit.kind == "pit_jaw", "")
	unit.attack_phase.connect(func(f: Dictionary): facts.append(f))
	unit.hit_player.connect(func(_amount: float, _shove: Vector3): hits += 1)
	unit.hp = 100000.0
	unit._rest = 0.05
	var frames := 0
	# The ball sits still on the flat: a reset every tick would leave it ungrounded when the
	# enemy reads it, and the floor rule wants a ball on the floor.
	while unit.phase != unit.Phase.WARN and frames < 300:
		await physics_frame
		frames += 1
	t.check("it sets under a ball on the floor", unit.phase == unit.Phase.WARN, "%d frames" % frames)
	var first: Dictionary = facts[0] if not facts.is_empty() else {}
	t.eq("first fact row", first.get("row"), "E30")
	t.eq("telegraph is a floor ring", first.get("geometry", {}).get("form"), "radial")
	frames = 0
	while unit.bitten == 0 and frames < 240:
		await physics_frame
		frames += 1
	t.eq("it bit the ball once", unit.bitten, 1)
	t.check("and holds it", unit._holding(), "")
	t.check("the bite stung", hits >= 1, "hits %d" % hits)
	unit.free()


func _off_floor() -> void:
	var unit = await _spawn(Vector3(8.0, 0.0, 2.0))
	unit.set_physics_process(false)
	var state = game.player.state
	var to: Vector3 = unit._flat_to_ball()
	state.grounded = true
	state.contact_normal = Vector3.UP
	t.check("wants a ball on the floor", unit._wants_attack(to), "")
	state.contact_normal = Vector3(0.6, 0.8, 0.0).normalized()
	t.check("leaves a ball on a bank alone", not unit._wants_attack(to), "")
	state.grounded = false
	state.contact_normal = Vector3.UP
	t.check("leaves an airborne ball alone", not unit._wants_attack(to), "")
	state.grounded = true
	unit._warn(to)
	unit.phase = unit.Phase.LIVE
	unit._go_live()
	state.grounded = false
	unit._live(1.0 / 60.0)
	t.eq("a ball over the jaw but off the floor passes", unit.bitten, 0)
	unit.free()


func _slam() -> void:
	var unit = await _spawn(Vector3(8.0, 0.0, -2.0))
	unit.set_physics_process(false)
	unit._warn(unit._flat_to_ball())
	var centre: Vector3 = unit.telegraph().center
	game.events.slammed.emit(centre + Vector3(8.0, 0.0, 0.0), 1.0, 1.0)
	t.check("a slam 8 m off the jaw leaves it", not unit.is_dead(), "")
	game.events.slammed.emit(centre, 1.0, 1.0)
	t.check("a slam on the open jaw shuts it", unit.is_dead() and unit.slam_kills == 1, "slam_kills %d" % unit.slam_kills)
	t.check("and the codex learns it", game.combat.discovered.has("jaw_slam"), "")
	var idle = await _spawn(Vector3(-8.0, 0.0, 2.0))
	idle.set_physics_process(false)
	game.events.slammed.emit(idle.global_position, 1.0, 1.0)
	t.check("a closed jaw at rest is not killed by a slam", not idle.is_dead(), "")
	idle.free()


func _run() -> void:
	await _boot()
	await _bite()
	await _off_floor()
	await _slam()
	game.free()
	quit(t.verdict())
