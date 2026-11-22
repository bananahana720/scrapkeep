extends SceneTree

# Replays the counterexamples of models/YardLock.tla on the real park_dam, one model step per call:
#   near  (yardlock-today and yardlock-today-flight, NoLockInWardenFight, finding YL-1): the ball first touches ground
#         near the beacon, outside its ring; the yard shuts; the ball rolls inside the yard into the ring; flow
#         engages; the yard stays shut.
#   strike (yardlock-today-ranged, the same rule by StrikeWarden): a ball that rolled in shuts the yard 145 m from the
#         beacon, at the share's edge; it rolls to the yard's beacon side, 110 m from the beacon, and a hit lands on
#         the Warden (the enemy_struck that combat.gd emits for every hit, as a pylon turret's shot with a horizon
#         optic, read from the game's own tables, would); flow engages; the yard stays shut.
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
const Weapons := preload("res://src/combat/weapons.gd")
const Parts := preload("res://src/build/parts.gd")
const RADIUS := 1.0
const STORE := "user://replay_yardlock/run.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	var at: Array = _toward(game, 145.0)
	game.player.reset_to(at[0], Vector3.ZERO)
	var waited := 0
	while locks.lock_state == "armed" and waited < 60:
		await physics_frame
		waited += 1
	_say(game, "Lock (after %d frames)" % waited)
	var shut: bool = locks.lock_state == "locked" and not game.flow.engaged()
	var centre: Vector3 = locks.lock_centre
	var inner: Array = _toward(game, 110.0)
	print("  yard centre %.1f m from the beacon; the ball goes to a point %.1f m from the yard centre" % [
		_flat(centre, game.flow.beacon.global_position), _flat(inner[0], centre)])
	game.player.reset_to(inner[0], Vector3.ZERO)
	await physics_frame
	await physics_frame
	_say(game, "rolled to the yard's beacon side")
	var turret: float = float(Weapons.BASE[Weapons.PYLON_TURRET]["range_m"])
	var optic: float = float(Parts.CATALOGUE["horizon_optic"]["mods"]["weapon_range"])
	var to_warden: float = game.player.ball_position().distance_to(game.flow.warden.global_position)
	print("  the Warden is %.1f m away; a pylon turret reaches %.0f m, %.1f m with a horizon optic" % [
		to_warden, turret, turret * optic])
	var before: bool = not game.flow.engaged()
	game.events.enemy_struck.emit(game.flow.warden, "pylon_turret", 10.0)
	_say(game, "StrikeWarden")
	for i in 30:
		await physics_frame
	_say(game, "half a second later")
	var held: bool = locks.lock_state == "locked" and game.flow.engaged() \
			and not game.flow.beacon.in_ring(game.player.ball_position())
	game.free()
	await process_frame
	return shut and before and held and to_warden < turret * optic


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
