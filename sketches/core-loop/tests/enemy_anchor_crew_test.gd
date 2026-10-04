extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const MAX_FRAMES := 600
const HELD_TICKS := 20

var game
var t := T.new("enemy_anchor_crew_test")
var ball := Vector3.ZERO
var facts: Array = []
var started := 0
var broken_facts: Array = []


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
	game.events.hold_started.connect(func(_kind: String, _at: Vector3): started += 1)
	game.events.hold_broken.connect(func(kind: String, method: String): broken_facts.append([kind, method]))


func _spawn():
	var at := Vector3(ball.x + 9.0, 0.0, ball.z + 3.0)
	at.y = game.ctx.terrain.height(at.x, at.z) + 0.1
	var unit = game.combat.spawn_enemy("anchor_crew", at)
	unit._rest = 0.1
	unit.hp = 100000.0
	unit.attack_phase.connect(func(fact: Dictionary): facts.append(fact))
	return unit


func _flat(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


func _run() -> void:
	await _boot()
	var unit = _spawn()
	t.check("ANCHOR-0 spawns by script", unit != null and unit.kind == "anchor_crew" and unit.row["mechanic"] == "deck_winch",
		"kind %s, mechanic %s" % [unit.kind, unit.row.get("mechanic")])

	# Warning: a lane toward the ball, no hold until it has run.
	var held_in_warn := false
	var warn_frames := 0
	for frame in MAX_FRAMES:
		game.player.reset_to(ball)
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
		if unit.phase == unit.Phase.WARN:
			warn_frames += 1
			held_in_warn = held_in_warn or unit.holds.held(unit)
		if unit.phase == unit.Phase.LIVE:
			break
	var first: Dictionary = facts[0] if not facts.is_empty() else {}
	var tele = unit.telegraph()
	t.check("ANCHOR-1 E23 windup lane", first.get("row") == "E23" and first.get("phase") == "windup" and first.get("committed") == true
		and tele != null and tele.shape == tele.Shape.LANE, "first fact %s/%s, lane %s" % [first.get("row"), first.get("phase"), tele != null])
	t.check("ANCHOR-2 no hold during warning", warn_frames > 0 and not held_in_warn, "%d warn frames, held in warn %s" % [warn_frames, held_in_warn])

	var holds = unit.holds
	var strike := false
	for fact in facts:
		strike = strike or fact["phase"] == "strike"
	t.check("ANCHOR-3 strike hooks the ball", strike and holds.held(unit) and started == 1 and unit.winched == 1,
		"strike fact %s, held %s, hold_started %d, winched %d" % [strike, holds.held(unit), started, unit.winched])

	# Pull: the ball (free to move now) comes toward the anchor.
	var steps := []
	await physics_frame
	var last := _flat(game.player.ball_position(), unit.anchor())
	var closer := true
	var speed_start: float = game.player.planar_velocity().length()
	for tick in HELD_TICKS:
		await physics_frame
		var now := _flat(game.player.ball_position(), unit.anchor())
		closer = closer and now < last
		last = now
		steps.append(now)
	t.check("ANCHOR-4 pulled toward the anchor", closer and holds.held(unit), "planar distance %.3f -> %.3f over %d ticks (every tick closer: %s), speed %.3f -> %.3f m/s"
		% [steps[0], steps[-1], HELD_TICKS, closer, speed_start, game.player.planar_velocity().length()])

	# Airborne: the pulled accel has a downward part. Drive _live directly against a lifted ball.
	unit.set_physics_process(false)
	game.player.reset_to(ball + Vector3.UP * 3.0)
	await _frames(2)
	var rigid = game.player._rigid
	var airborne: bool = not game.player.state.grounded
	rigid.external_accel = Vector3.ZERO
	unit._live(0.0)
	var accel: Vector3 = rigid.external_accel
	t.check("ANCHOR-5 airborne pull is downward", airborne and accel.y < 0.0 and holds.held(unit), "grounded %s, accel %s" % [not airborne, accel])
	var to: Vector3 = unit.anchor() - game.player.ball_position()
	to.y = 0.0
	t.check("ANCHOR-6 pull is planar toward the anchor", accel.x * to.x + accel.z * to.z > 0.0 and absf(Vector2(accel.x, accel.z).length() - unit.PULL) < 0.001,
		"planar pull %.3f m/s2 (PULL %.1f)" % [Vector2(accel.x, accel.z).length(), unit.PULL])
	unit.set_physics_process(true)

	# A jump slips the hook for good.
	var caught_before: int = unit.caught
	var breaks_before: int = holds.breaks_by_player
	game.events.jumped.emit(true)
	await physics_frame
	var reason: String = holds.last_release.get("reason", "")
	t.check("ANCHOR-7 jump breaks the tether", not holds.held(unit) and reason == "jump" and unit.broken_by == "jump"
		and broken_facts.has(["deck_winch", "jump"]) and holds.breaks_by_player == breaks_before + 1,
		"held %s, release %s, broken_by %s, hold_broken %s" % [holds.held(unit), holds.last_release, unit.broken_by, broken_facts])
	var again := false
	for frame in int(unit.live_seconds * float(Engine.physics_ticks_per_second)):
		await physics_frame
		again = again or holds.held(unit)
	t.check("ANCHOR-8 no re-catch", not again and unit.caught == caught_before, "re-held %s, caught %d -> %d" % [again, caught_before, unit.caught])
	game.free()
	quit(t.verdict())
