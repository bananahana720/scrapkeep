extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("enemy_lamp_swarm_test")
var ball := Vector3.ZERO


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


func _spawn():
	var at := Vector3(ball.x + 8.0, 0.0, ball.z)
	at.y = game.ctx.terrain.height(at.x, at.z) + 1.5
	var unit = game.combat.spawn_enemy("lamp_swarm", at)
	unit._strafe = 1.0
	unit._rest = 0.1
	unit.hp = 100000.0
	return unit


func _park() -> void:
	game.player.reset_to(ball)
	game.player.set_velocity_now(Vector3.ZERO)


func _to_live(unit) -> void:
	var guard := 0
	while unit.phase != unit.Phase.LIVE and guard < 360:
		_park()
		await physics_frame
		guard += 1


func _ram(unit) -> void:
	game.combat.deal_hit(unit, "ram", 1.0, Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"], "", "", "ram")


func _run() -> void:
	await _boot()
	var unit = _spawn()
	var rows := []
	unit.attack_phase.connect(func(fact: Dictionary): rows.append([fact["row"], fact["phase"]]))
	var guard := 0
	while unit.phase != unit.Phase.WARN and guard < 360:
		_park()
		await physics_frame
		guard += 1
	t.check("LS-1 windup row", rows.size() > 0 and rows[0][0] == "E21" and rows[0][1] == "windup" and unit.telegraph() != null,
		"first fact %s" % [rows[0] if rows.size() > 0 else "none"])
	await _to_live(unit)
	t.check("LS-2 bloom live", unit.phase == unit.Phase.LIVE and unit.blooms == 1, "phase %s blooms %d" % [unit.state_name(), unit.blooms])
	var hp_before: float = game.run.hp
	var before: int = unit.lured_ticks
	# 2026-10-04 (wave 10): the lure now gates on the committed wave's contains(), so the front
	# reaches the parked ball later than the old 20-frame radius check; wait up to 120 frames.
	for frame in 120:
		_park()
		await physics_frame
		if unit.lured_ticks > before:
			break
	var hit: Dictionary = game.combat.last_player_hit
	t.check("LS-3 slow ball lured", unit.lured_ticks > before, "lured_ticks %d -> %d" % [before, unit.lured_ticks])
	var toward := false
	if not hit.is_empty():
		toward = (hit["shove"] as Vector3).dot(unit.global_position - ball) > 0.0
	t.check("LS-4 lure steers toward the lamps without damage", toward and hit.get("source", "") == "lamp_swarm" and game.run.hp == hp_before,
		"source %s toward %s hp %s -> %s" % [hit.get("source", ""), toward, hp_before, game.run.hp])
	var cruise: float = game.ctx.tuning.f("cruise")
	var settled: int = unit.lured_ticks
	for frame in 10:
		game.player.reset_to(ball)
		game.player.set_velocity_now(Vector3.RIGHT * 1.2 * cruise)
		await physics_frame
	t.check("LS-5 cruise ball not lured", unit.lured_ticks == settled and unit.phase == unit.Phase.LIVE,
		"lured_ticks %d -> %d" % [settled, unit.lured_ticks])
	game.player.set_velocity_now(Vector3.RIGHT * 1.2 * cruise)
	await _ram(unit)
	await physics_frame
	await physics_frame
	t.check("LS-6 cruise ram scatters", unit.scatters == 1 and unit.phase == unit.Phase.ROAM,
		"scatters %d phase %s" % [unit.scatters, unit.state_name()])
	unit.free()
	var slow = _spawn()
	await _to_live(slow)
	game.player.set_velocity_now(Vector3.RIGHT * 0.5 * cruise)
	var phase_before: int = slow.phase
	_ram(slow)
	await physics_frame
	t.check("LS-7 slow ram does not scatter", slow.scatters == 0 and slow.phase == phase_before,
		"scatters %d phase %s" % [slow.scatters, slow.state_name()])
	slow.free()
	var front = _spawn()
	# Each shove is judged against the wave's own contains() on the tick it lands.
	var outside_hits := [0]
	var inside_hits := [0]
	front.hit_player.connect(func(_amount: float, _shove: Vector3):
		if front.telegraph().contains(game.player.ball_position()):
			inside_hits[0] += 1
		else:
			outside_hits[0] += 1)
	await _to_live(front)
	var flat_to: float = 0.0
	for frame in 240:
		_park()
		var tele = front.telegraph()
		if tele == null or inside_hits[0] > 0:
			break
		flat_to = Vector3(ball.x - tele.center.x, 0.0, ball.z - tele.center.z).length()
		await physics_frame
	t.check("LS-8 the lure follows the wave front", flat_to < front.BLOOM_RADIUS and outside_hits[0] == 0 and inside_hits[0] > 0,
		"ball %.1f m from the bloom, hits outside the front %d, on the front %d" % [flat_to, outside_hits[0], inside_hits[0]])
	game.free()
	game = null
	quit(t.verdict())
