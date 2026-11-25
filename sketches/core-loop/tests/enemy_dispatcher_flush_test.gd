extends SceneTree

# W47-E3 dispatcher secondary: Express Cargo Flush (0.95 s pressure siren when perch ignored > 14 s)
# -> ramming falling cargo pod fires it back up the chute, one-shotting the perch.
# Verifies tell floor >= 0.60 s, Palette.HAZARD, AttackBudget + 0.2 s gap, 14 s ignore threshold,
# hitting perch resets ignore clock, unrammed cargo flush impact, and ram-return one-shot payoff.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Palette := preload("res://src/core/palette.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Dispatcher := preload("res://src/combat/dispatcher.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("enemy_dispatcher_flush_test")
var ball := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
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
	await _frames(4)
	_clear()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	if root.has_meta(AttackBudget.LAST_META):
		root.remove_meta(AttackBudget.LAST_META)


func _spawn_rig(rest := 0.0) -> Node3D:
	game.player.reset_to(ball)
	var at := Vector3(ball.x + 14.0, 0.0, ball.z + 4.0)
	at.y = game.ctx.terrain.height(at.x, at.z)
	var rig: Node3D = game.combat.spawn_enemy("dispatcher", at)
	rig._rest = rest
	return rig


func _run() -> void:
	await _boot()
	var player = game.player

	# 1. Tell floor invariant >= 0.60 s.
	t.check("Express Cargo Flush siren >= 0.60 s", Dispatcher.FLUSH_SIREN >= 0.60, str(Dispatcher.FLUSH_SIREN))
	t.near("Express Cargo Flush siren is 0.95 s", Dispatcher.FLUSH_SIREN, 0.95, 0.001)
	t.near("Express Cargo Flush ignore threshold is 14 s", Dispatcher.FLUSH_IGNORE_S, 14.0, 0.001)

	# 2. Hitting the perch resets ignored_seconds so active engagement prevents Express Cargo Flush.
	_clear()
	var rig := _spawn_rig(100.0)
	rig.ignored_seconds = 13.5
	rig.take_damage(1.0)
	t.near("damaging perch resets ignored_seconds", rig.ignored_seconds, 0.0, 0.001)
	rig.free()

	# 3. Ignored > 14 s triggers Express Cargo Flush with 0.95 s siren + Palette.HAZARD ring + AttackBudget.
	_clear()
	rig = _spawn_rig(0.0)
	rig.ignored_seconds = Dispatcher.FLUSH_IGNORE_S + 0.5
	var flushed_pods := []
	rig.cargo_flushed.connect(func(pod: Node3D): flushed_pods.append(pod))
	# Inside 0.2 s gap: AttackBudget blocks start.
	root.set_meta(AttackBudget.LAST_META, Engine.get_physics_frames())
	root.set_meta(AttackBudget.VOLLEY_META, [-1, -999])
	await _frames(2)
	t.eq("flush obeys 0.2 s AttackBudget gap", rig.phase, rig.Phase.ROAM)
	root.remove_meta(AttackBudget.LAST_META)
	await _frames(4)
	var ring: Node3D = rig.telegraph()
	t.eq("ignored > 14 s commits Express Cargo Flush", [rig.phase, rig._flush_active], [rig.Phase.WARN, true])
	t.check("flush holds AttackBudget slot", rig.is_in_group(AttackBudget.ATTACKING))
	t.check("flush ring is Palette.HAZARD with 5.0 m radius and 1.85 s total warn",
		ring != null and ring.color.is_equal_approx(Palette.HAZARD)
		and is_equal_approx(ring.radius, Dispatcher.FLUSH_RADIUS)
		and is_equal_approx(ring.warn_seconds, Dispatcher.FLUSH_WARN))

	# Advance past the 0.95 s siren so the heavy cargo pod launches out of the chute.
	await _frames(int(ceil((Dispatcher.FLUSH_SIREN + 0.25) * Engine.physics_ticks_per_second)))
	t.eq("cargo pod launched after 0.95 s siren", flushed_pods.size(), 1)
	t.check("cargo pod is live in flight", is_instance_valid(rig._pod))

	# 4. Practiced payoff: ramming falling cargo pod fires it back up the chute, one-shotting the perch!
	var returned := []
	rig.cargo_returned.connect(func(d: Node3D): returned.append(d))
	rig.hp = rig.max_hp
	var pod_pos: Vector3 = rig._pod.global_position
	var ram_vel := Vector3(16.0, 0.0, 0.0)
	player.reset_to(pod_pos, ram_vel)
	player.state.velocity = ram_vel
	player.state.tier = SpeedTier.CRUISE
	await _frames(3)
	t.check("ramming falling cargo pod fires it back up the chute", rig.cargo_returns == 1 and returned == [rig],
		"returns=%d signals=%d" % [rig.cargo_returns, returned.size()])
	t.check("hostile telegraph cancelled on return", rig.telegraph() == null)
	# Wait for the 0.35 s return flight up the chute to one-shot the perch.
	await _frames(int(ceil((Dispatcher.CARGO_RETURN_FLIGHT + 0.15) * Engine.physics_ticks_per_second)))
	t.check("returning cargo pod one-shots the Dispatcher perch", not is_instance_valid(rig) or rig.is_dead())
	t.check("stream_cut discovered on cargo-return kill", game.combat.discovered.has("stream_cut"))

	# 5. Unrammed Express Cargo Flush lands heavy cargo pod + chaser and resets ignored_seconds.
	_clear()
	rig = _spawn_rig(0.0)
	rig.ignored_seconds = Dispatcher.FLUSH_IGNORE_S + 0.5
	var hits := []
	var adds := []
	rig.hit_player.connect(func(amount: float, _shove: Vector3): hits.append(amount))
	rig.dispatched.connect(func(add: Node3D): adds.append(add))
	# Keep player parked (WALK tier, 0 speed) inside landing ring so it does not ram the pod.
	for _tick in int(ceil((Dispatcher.FLUSH_WARN + 0.2) * Engine.physics_ticks_per_second)):
		player.reset_to(ball, Vector3.ZERO)
		player.state.velocity = Vector3.ZERO
		player.state.tier = SpeedTier.WALK
		await physics_frame
		if rig.cargo_flushes > 0:
			break
	t.eq("unrammed flush lands heavy cargo pod and chaser", [rig.cargo_flushes, hits, adds.size()], [1, [Dispatcher.FLUSH_DAMAGE], 1])
	t.near("ignored_seconds resets after flush lands", rig.ignored_seconds, 0.0, 0.05)

	_clear()
	game.free()
	quit(t.verdict())
