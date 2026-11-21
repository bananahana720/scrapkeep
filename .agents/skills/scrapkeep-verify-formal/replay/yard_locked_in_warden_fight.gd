extends SceneTree

# Replays the counterexamples of models/YardLock.tla on the real park_dam, one model step per call:
#   ring  (yardlock-today, NoLockInWardenFight, finding YL-1): Start; one frame in which flow's tick sees the ball
#         just outside the beacon ring and the ball's own tick carries it, grounded, inside it, so StageLocks shuts the
#         yard first; the next frame, flow engages the Warden and the yard stays shut.
#   near  (the same rule by the second path): the ball first touches ground near the beacon, outside its ring; the
#         yard shuts; the ball rolls inside the yard into the ring; flow engages; the yard stays shut.
#   strike (the same rule by StrikeWarden): the yard shuts 75 m from the beacon, the ball stays outside the ring inside
#         the yard, 40 m from the Warden, and a hit lands on the Warden (the enemy_struck that combat.gd emits for every
#         hit, as a scrap_rockets lock at 42 m would); flow engages; the yard stays shut.
#   dead  (yardlock-today-nostore, WallOnlyWhileLocked, finding YL-2): a storeless flow; the yard shuts; the ball dies;
#         the dead screen comes up with the lock still "locked" and its wall standing.
#   control (dead with a store, as a played game): the death goes to the summary and the wall goes.
# Each prints its steps and REPRODUCED or NOT REPRODUCED. The ball is placed with player.reset_to, which stands in
# for the flight that brings it there, and in near and strike for the roll inside the yard (the wall's hold is not
# exercised); every tick after it is the game's own.
# Copy it into sketches/core-loop/tests/ to run it (SKILL.md, "Read a result"); it is not a suite test. Run it with
# HOME (and XDG_DATA_HOME on the PC) set to a scratch folder so no real save is touched.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RADIUS := 1.0
const STORE := "user://replay_yardlock/run.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ring := await _ring()
	print("ring: %s" % ("REPRODUCED" if ring else "NOT REPRODUCED"))
	var near := await _near()
	print("near: %s" % ("REPRODUCED" if near else "NOT REPRODUCED"))
	var strike := await _strike()
	print("strike: %s" % ("REPRODUCED" if strike else "NOT REPRODUCED"))
	var dead := await _dead(false)
	print("dead: %s" % ("REPRODUCED" if dead else "NOT REPRODUCED"))
	var control := await _dead(true)
	print("control (store): %s" % ("REPRODUCED" if control else "NOT REPRODUCED"))
	quit(0)


func _game(store: bool):
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	if store:
		DirAccess.make_dir_recursive_absolute("user://replay_yardlock")
		game.run_store_path = STORE
	root.add_child(game)
	await process_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 8:
		await physics_frame
	return game


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# A point `d` metres from the beacon on the side the ball came from, and the flat unit vector toward the beacon.
func _toward(game, d: float) -> Array:
	var beacon: Vector3 = game.flow.beacon.global_position
	var ball: Vector3 = game.player.ball_position()
	var dir := Vector3(beacon.x - ball.x, 0.0, beacon.z - ball.z).normalized()
	var spot := beacon - dir * d
	return [game.ctx.terrain.drop_point(spot.x, spot.z, RADIUS), dir]


func _say(game, step: String) -> void:
	var locks = game.flow.gate
	print("  %s: flow %s, ball %.1f m from the beacon (ring %.0f m), grounded %s, lock %s, wall %s, Warden engaged %s" % [
		step, game.flow.state_name(), _flat(game.player.ball_position(), game.flow.beacon.global_position),
		game.flow.beacon.radius, game.player.state.grounded, locks.lock_state, locks.get_node_or_null("ArenaLockWall") != null,
		game.flow.engaged()])


func _ring() -> bool:
	print("ring:")
	var game = await _game(true)
	var locks = game.flow.gate
	_say(game, "Start")
	# Between frames: the ball 0.25 m outside the ring on the ground, rolling in at 30 m/s (0.5 m a tick).
	var at: Array = _toward(game, game.flow.beacon.radius + 0.25)
	game.player.reset_to(at[0], at[1] * 30.0)
	_say(game, "placed")
	# The ball's first tick after the placement grounds it where it was put; it rolls in on the next.
	var frames := 0
	while locks.lock_state == "armed" and frames < 5:
		await physics_frame
		frames += 1
		_say(game, "frame %d (FlowTick, BallTick, LocksTick)" % frames)
	var inside: bool = game.flow.beacon.in_ring(game.player.ball_position())
	var shut_first: bool = locks.lock_state == "locked" and inside and not game.flow.engaged()
	await physics_frame
	_say(game, "frame %d (FlowTick engages)" % (frames + 1))
	var both: bool = locks.lock_state == "locked" and game.flow.engaged()
	for i in 30:
		await physics_frame
	_say(game, "half a second later")
	print("  objective: %s" % game.flow.objective_text())
	var held: bool = locks.lock_state == "locked" and game.flow.engaged()
	game.free()
	await process_frame
	return shut_first and both and held


func _near() -> bool:
	print("near:")
	var game = await _game(true)
	var locks = game.flow.gate
	_say(game, "Start")
	var at: Array = _toward(game, game.flow.beacon.radius + 15.0)
	game.player.reset_to(at[0], Vector3.ZERO)
	_say(game, "placed 15 m outside the ring")
	var waited := 0
	while locks.lock_state == "armed" and waited < 60:
		await physics_frame
		waited += 1
	_say(game, "Lock (after %d frames)" % waited)
	var shut: bool = locks.lock_state == "locked" and not game.flow.engaged()
	var centre: Vector3 = locks.lock_centre
	print("  yard centre %.1f m from the beacon, radius %.0f m" % [_flat(centre, game.flow.beacon.global_position), float(locks.lock_row().get("radius_m", 0.0))])
	# The ball rolls on inside the yard, into the ring (5 m inside it, inside the wall).
	var inner: Array = _toward(game, game.flow.beacon.radius - 5.0)
	print("  that point is %.1f m from the yard centre" % _flat(inner[0], centre))
	game.player.reset_to(inner[0], Vector3.ZERO)
	await physics_frame
	await physics_frame
	_say(game, "rolled into the ring")
	var both: bool = locks.lock_state == "locked" and game.flow.engaged()
	for i in 30:
		await physics_frame
	_say(game, "half a second later")
	var held: bool = locks.lock_state == "locked" and game.flow.engaged()
	game.free()
	await process_frame
	return shut and both and held


func _strike() -> bool:
	print("strike:")
	var game = await _game(true)
	var locks = game.flow.gate
	var at: Array = _toward(game, 75.0)
	game.player.reset_to(at[0], Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 60:
		await physics_frame
		waited += 1
	_say(game, "Lock (after %d frames)" % waited)
	var shut: bool = locks.lock_state == "locked" and not game.flow.engaged()
	var centre: Vector3 = locks.lock_centre
	var inner: Array = _toward(game, 40.0)
	print("  yard centre %.1f m from the beacon; the ball goes to a point %.1f m from the yard centre" % [
		_flat(centre, game.flow.beacon.global_position), _flat(inner[0], centre)])
	game.player.reset_to(inner[0], Vector3.ZERO)
	await physics_frame
	await physics_frame
	_say(game, "rolled to 40 m, outside the ring")
	var before: bool = not game.flow.engaged()
	game.events.enemy_struck.emit(game.flow.warden, "rockets", 10.0)
	_say(game, "StrikeWarden")
	for i in 30:
		await physics_frame
	_say(game, "half a second later")
	var held: bool = locks.lock_state == "locked" and game.flow.engaged() \
			and not game.flow.beacon.in_ring(game.player.ball_position())
	game.free()
	await process_frame
	return shut and before and held


func _dead(store: bool) -> bool:
	print("%s:" % ("control" if store else "dead"))
	var game = await _game(store)
	var locks = game.flow.gate
	var at: Array = _toward(game, 140.0)
	game.player.reset_to(at[0], Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 120:
		await physics_frame
		waited += 1
	_say(game, "Lock")
	game.run.damage(99999.0, "replay")
	_say(game, "Death")
	for i in 30:
		await physics_frame
	_say(game, "half a second later")
	var stands: bool = game.flow.state_name() in ["dead", "summary"] and locks.lock_state == "locked" \
			and locks.get_node_or_null("ArenaLockWall") != null
	if not store:
		game.flow.retry_stage()
		await physics_frame
		await process_frame
		_say(game, "Retry")
	game.free()
	await process_frame
	return stands
