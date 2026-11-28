extends SceneTree

# W47-E3 ramp_flipper secondary: Catapult Double-Snap (0.65 s double-ratchet steeper kicker when
# approaching >= FAST) -> Jump on double-snap = +12 m/s forward boost + instant Blazing tier.
# Verifies tell floor >= 0.60 s, Palette.HAZARD, AttackBudget + 0.2 s gap, ruling cu (FAST ball
# never held/stopped), Sonic Turbo-Ramp payoff, and clean reset after attack end.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Palette := preload("res://src/core/palette.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const RampFlipper := preload("res://src/combat/ramp_flipper.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("enemy_ramp_flipper_double_snap_test")
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


func _spawn_flipper(offset: Vector3) -> Node3D:
	var at := ball + offset
	var unit: Node3D = game.combat.spawn_enemy("ramp_flipper", game.ctx.terrain.drop_point(at.x, at.z, 1.8))
	unit._rest = 0.0
	return unit


func _run() -> void:
	await _boot()
	var player = game.player
	var fleet = game.combat.fleet

	# 1. Tell floor invariant >= 0.60 s.
	t.check("Catapult Double-Snap warn >= 0.60 s", RampFlipper.DOUBLE_SNAP_WARN >= 0.60, str(RampFlipper.DOUBLE_SNAP_WARN))
	t.near("Catapult Double-Snap warn is 0.65 s", RampFlipper.DOUBLE_SNAP_WARN, 0.65, 0.001)

	# 2. Slow/parked ball triggers primary 1.0 s warn, not double-snap.
	_clear()
	player.reset_to(ball, Vector3.ZERO)
	var primary := _spawn_flipper(Vector3(12.0, 0.0, 0.0))
	primary.target = player
	primary._warn(player.ball_position() - primary.global_position)
	t.eq("parked ball stays on primary attack", [primary.double_snaps, primary._double_snap], [0, false])
	t.near("primary warn stays 1.0 s", primary.warn_seconds, 1.0, 0.001)
	primary.free()

	# 3. Approaching >= FAST ball triggers Catapult Double-Snap with 0.65 s HAZARD ring and obeys AttackBudget.
	_clear()
	var cruise: float = player.tuning.f("cruise")
	var fast_speed := cruise * SpeedTier.MULTIPLES[SpeedTier.FAST] + 1.5
	var fast_vel := Vector3(fast_speed, 0.0, 0.0)
	player.reset_to(ball, fast_vel)
	player.state.velocity = fast_vel
	player.state.tier = SpeedTier.FAST
	var unit := _spawn_flipper(Vector3(14.0, 0.0, 0.0))
	unit.target = player
	# 0.2 s inter-warning gap check: stamp LAST_META now -> AttackBudget refuses until gap opens.
	root.set_meta(AttackBudget.LAST_META, Engine.get_physics_frames())
	root.set_meta(AttackBudget.VOLLEY_META, [-1, -999])
	t.check("AttackBudget blocks double-snap inside 0.2 s gap", not AttackBudget.ask(unit))
	root.remove_meta(AttackBudget.LAST_META)
	t.check("AttackBudget grants double-snap when gap is open", AttackBudget.ask(unit))
	unit._warn(player.ball_position() - unit.global_position)
	var ring: Node3D = unit.telegraph()
	t.eq("approaching FAST ball triggers Catapult Double-Snap", [unit.double_snaps, unit._double_snap], [1, true])
	t.near("double-snap warn_seconds is 0.65 s", unit.warn_seconds, 0.65, 0.001)
	t.check("double-snap telegraph is Palette.HAZARD", ring != null and ring.color.is_equal_approx(Palette.HAZARD))

	# 4. Double-ratchet pose increases steeply in two steps during WARN and snaps on LIVE.
	unit.phase = unit.Phase.WARN
	unit._t = 0.0
	unit._pose()
	var y_start: float = unit._plate.basis.orthonormalized().y.y
	unit._t = RampFlipper.DOUBLE_SNAP_WARN * 0.50
	unit._pose()
	var y_mid: float = unit._plate.basis.orthonormalized().y.y
	unit._t = RampFlipper.DOUBLE_SNAP_WARN
	unit._pose()
	var y_end: float = unit._plate.basis.orthonormalized().y.y
	t.check("double-ratchet tilts steeper from notch 1 to notch 2", y_mid < y_start and y_end < y_mid,
		"y=%.3f -> %.3f -> %.3f" % [y_start, y_mid, y_end])

	# 5. Jump on double-snap = +12 m/s forward boost + instant Blazing tier.
	player.reset_to(ring.center + Vector3.UP * 1.05, fast_vel)
	player.state.velocity = fast_vel
	player.state.tier = SpeedTier.FAST
	var before_speed := Vector2(player.state.velocity.x, player.state.velocity.z).length()
	unit.phase = unit.Phase.LIVE
	unit._t = 0.05
	game.events.jumped.emit(false)
	var after_speed := Vector2(player.state.velocity.x, player.state.velocity.z).length()
	t.eq("Jump on double-snap fires Sonic Turbo-Ramp once", unit.turbo_launches, 1)
	t.check("Turbo-Ramp adds at least +12 m/s forward boost", after_speed >= before_speed + RampFlipper.TURBO_KICK - 0.1,
		"before=%.2f after=%.2f delta=%.2f" % [before_speed, after_speed, after_speed - before_speed])
	t.eq("Turbo-Ramp grants instant Blazing tier", player.speed_tier(), SpeedTier.BLAZING)
	t.check("Turbo-Ramp adds upward lift", player.state.velocity.y >= RampFlipper.TURBO_UP - 0.1, str(player.state.velocity.y))
	# Second jump in same attack does not double-fire.
	game.events.jumped.emit(true)
	t.eq("Turbo-Ramp fires at most once per double-snap", unit.turbo_launches, 1)
	unit._end()
	t.eq("end resets double-snap state and warn_seconds", [unit._double_snap, unit.warn_seconds], [false, 1.0])
	unit.free()

	# 6. Ruling cu: FAST ball rolling over double-snap without jumping is NEVER held/stopped.
	_clear()
	fleet.holds.clear()
	player.reset_to(ball, fast_vel)
	player.state.velocity = fast_vel
	player.state.tier = SpeedTier.FAST
	player.state.grounded = true
	player.state.contact_normal = Vector3.UP
	var flow_unit := _spawn_flipper(Vector3(12.0, 0.0, 0.0))
	flow_unit.target = player
	flow_unit._warn(player.ball_position() - flow_unit.global_position)
	var flow_ring: Node3D = flow_unit.telegraph()
	player.reset_to(flow_ring.center + Vector3.UP * 1.05, fast_vel)
	player.state.velocity = fast_vel
	player.state.tier = SpeedTier.FAST
	player.state.grounded = true
	player.state.contact_normal = Vector3.UP
	flow_unit.phase = flow_unit.Phase.LIVE
	flow_unit._t = 0.0
	flow_unit._go_live()
	t.eq("FAST unjumped ball rides double-snap without being held", [flow_unit.rides, flow_unit.flings, fleet.holds.held(flow_unit)], [1, 0, false])
	flow_unit._end()
	flow_unit.free()

	_clear()
	game.free()
	quit(t.verdict())
