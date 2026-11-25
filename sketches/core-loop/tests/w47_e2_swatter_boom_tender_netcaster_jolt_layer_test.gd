extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Swatter := preload("res://src/combat/swatter.gd")
const BoomTender := preload("res://src/combat/boom_tender.gd")
const Netcaster := preload("res://src/combat/netcaster.gd")
const JoltLayer := preload("res://src/combat/jolt_layer.gd")
const T := preload("res://tests/support/t.gd")

# W47-E2 verification: conditional 2-attack kits for swatter, boom_tender, netcaster, jolt_layer.
# Covers:
# 1. Hard tell floor >= 0.60 s and Palette.HAZARD (#FF5A3C) telegraphs for every secondary attack.
# 2. AttackBudget + 0.2 s inter-warning gap compliance (all secondaries go through counter.gd).
# 3. swatter Overhead Sky-Spank (0.75 s tell when jumping Primary / hovering < 7 m) -> air-slam
#    springboard (+16 m/s launch) + gear stun; grounded fast ball is never hit.
# 4. boom_tender Buoy Flail Throw (0.75 s tell when >= 2 floats burst) -> cruise-ram return
#    knocks out Tender for double scrap (10 vs 5).
# 5. netcaster Snap-Trap Ceiling Drop (0.80 s tell when camping grounded > 1.5 s under active net)
#    -> smash/boost Conductive Tear triggers 10 m EMP arc stripping nearby Linker/Brute/Jolt/jam.
# 6. jolt_layer Cable Whip Overload (0.70 s tell when skirting mat rim) -> boost across glowing
#    wave reverses surge to 1-pop Jolt Layer + 30% Special cooldown refund.

var _t := T.new("w47_e2_swatter_boom_tender_netcaster_jolt_layer_test")
var _game
var _ball_at := Vector3.ZERO
var _source


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 47
	_source = Intent.Scripted.new()
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	_clear_field()
	_ball_at = _game.ctx.terrain.drop_point(_game.ctx.terrain.spawn_point(1).x, _game.ctx.terrain.spawn_point(1).z, 1.05)


func _clear_field() -> void:
	for group in ["enemy", "enemy_shot", "telegraph"]:
		for node in get_nodes_in_group(group):
			if is_instance_valid(node):
				node.free()
	if _game.combat != null and _game.combat.fleet != null and _game.combat.fleet.holds != null:
		_game.combat.fleet.holds.clear()


func _step_until(pred: Callable, max_frames := 360) -> bool:
	for i in max_frames:
		await physics_frame
		if pred.call():
			return true
	return false


func _test_tell_floors() -> void:
	_t.check("swatter SKY_WARN >= 0.60 s (0.75 s)", Swatter.SKY_WARN >= 0.60 and is_equal_approx(Swatter.SKY_WARN, 0.75),
		"SKY_WARN=%.2f" % Swatter.SKY_WARN)
	_t.check("boom_tender BUOY_WARN >= 0.60 s (0.75 s)", BoomTender.BUOY_WARN >= 0.60 and is_equal_approx(BoomTender.BUOY_WARN, 0.75),
		"BUOY_WARN=%.2f" % BoomTender.BUOY_WARN)
	_t.check("netcaster DROP_WARN >= 0.60 s (0.80 s)", Netcaster.DROP_WARN >= 0.60 and is_equal_approx(Netcaster.DROP_WARN, 0.80),
		"DROP_WARN=%.2f" % Netcaster.DROP_WARN)
	_t.check("jolt_layer WHIP_WARN >= 0.60 s (0.70 s)", JoltLayer.WHIP_WARN >= 0.60 and is_equal_approx(JoltLayer.WHIP_WARN, 0.70),
		"WHIP_WARN=%.2f" % JoltLayer.WHIP_WARN)


func _test_swatter_sky_spank() -> void:
	_clear_field()
	await _frames(2)
	var player = _game.player
	var at := _ball_at + Vector3(4.0, 0.0, 0.0)
	player.reset_to(_ball_at)
	var unit = _game.combat.spawn_enemy("swatter", _game.ctx.terrain.drop_point(at.x, at.z, 1.4))
	unit.hp = 500.0
	unit._rest = 0.05
	# Hover airborne < 7 m above ground inside sweep reach.
	var hover_pos := _ball_at + Vector3(0.0, 3.0, 0.0)
	var entered_warn := false
	for i in 120:
		player.reset_to(hover_pos)
		await physics_frame
		if unit.phase == unit.Phase.WARN:
			entered_warn = true
			break
	var tele = unit.telegraph()
	_t.check("swatter enters Overhead Sky-Spank WARN for hovering player",
		entered_warn and unit._sky_spank and is_equal_approx(unit.warn_seconds, Swatter.SKY_WARN),
		"warn=%s sky=%s warn_s=%.2f" % [entered_warn, unit._sky_spank, unit.warn_seconds])
	_t.check("swatter Sky-Spank telegraph is aerial Palette.HAZARD",
		tele != null and tele.aerial and tele.color.is_equal_approx(Palette.HAZARD),
		"tele=%s" % [tele])
	_t.check("swatter Sky-Spank takes AttackBudget slot", unit.is_in_group(AttackBudget.ATTACKING), "in attack_budget")
	# Wait for LIVE while hovering, then air-slam onto rising paddle.
	var entered_live := false
	for i in 120:
		player.reset_to(hover_pos)
		await physics_frame
		if unit.phase == unit.Phase.LIVE:
			entered_live = true
			break
	_t.check("swatter Sky-Spank reaches LIVE after >= 0.75 s",
		entered_live and unit.sky_spanks >= 1 and unit.last_warn >= Swatter.SKY_WARN - 0.03,
		"live=%s spanks=%d last_warn=%.3f" % [entered_live, unit.sky_spanks, unit.last_warn])
	# Air-slam onto rising paddle -> +16 m/s springboard launch + gear stun!
	player.reset_to(_ball_at + Vector3(2.0, 2.5, 0.0), Vector3(6.0, -8.0, 0.0))
	player.kit.slamming = true
	await _frames(3)
	var speed_after: float = player.state.velocity.length()
	var vy_after: float = player.state.velocity.y
	_t.check("air-slamming rising paddle triggers +16 m/s springboard + gear stun",
		unit.sky_vaults == 1 and speed_after >= 16.0 and vy_after > 8.0 and unit.stunned() and unit.staggers >= 1,
		"vaults=%d speed=%.1f vy=%.1f stun=%.2f staggers=%d" % [unit.sky_vaults, speed_after, vy_after, unit.stun_left, unit.staggers])
	_t.check("swatter restores primary warn_seconds after Sky-Spank ends",
		is_equal_approx(unit.warn_seconds, Swatter.PRIMARY_WARN),
		"warn_seconds=%.2f" % unit.warn_seconds)
	_clear_field()


func _test_boom_tender_buoy_throw() -> void:
	_clear_field()
	await _frames(2)
	var player = _game.player
	var at := _ball_at + Vector3(8.0, 0.0, 0.0)
	player.reset_to(_ball_at)
	var unit = _game.combat.spawn_enemy("boom_tender", _game.ctx.terrain.drop_point(at.x, at.z, 1.5))
	var died_scrap := [-1]
	unit.died.connect(func(_where: Vector3, scrap: int): died_scrap[0] = scrap)
	# Mark 2 floats burst to arm Buoy Flail Throw.
	unit.popped[0] = true
	unit.popped[1] = true
	unit.pops = 2
	unit._rest = 0.05
	var warned := await _step_until(func(): return unit.phase == unit.Phase.WARN, 120)
	var tele = unit.telegraph()
	_t.check("boom_tender triggers Buoy Flail Throw WARN when >= 2 floats burst",
		warned and unit._buoy_throw and is_equal_approx(unit.warn_seconds, BoomTender.BUOY_WARN),
		"warned=%s buoy=%s warn_s=%.2f" % [warned, unit._buoy_throw, unit.warn_seconds])
	_t.check("boom_tender Buoy Flail Throw uses Palette.HAZARD lane + AttackBudget",
		tele != null and tele.color.is_equal_approx(Palette.HAZARD) and unit.is_in_group(AttackBudget.ATTACKING),
		"tele=%s" % [tele])
	var lived := await _step_until(func(): return unit.phase == unit.Phase.LIVE, 140)
	_t.check("boom_tender Buoy Flail Throw enters LIVE after >= 0.75 s",
		lived and unit.buoy_throws >= 1 and unit.last_warn >= BoomTender.BUOY_WARN - 0.03,
		"lived=%s throws=%d last_warn=%.3f" % [lived, unit.buoy_throws, unit.last_warn])
	# Advance a few frames so buoy leaves hull, then cruise-ram into the thrown buoy!
	await _frames(10)
	var bpos: Vector3 = unit.buoy_position()
	var cruise_speed: float = player.tuning.f("cruise")
	player.reset_to(bpos, Vector3(cruise_speed, 0.0, 0.0))
	player.state.refresh_tier(cruise_speed)
	var returned := await _step_until(func(): return not is_instance_valid(unit) or unit.buoy_returns >= 1, 30)
	_t.check("cruise-ramming thrown buoy bats it back toward Tender", returned and is_instance_valid(unit) and unit.buoy_returns == 1,
		"returned=%s" % [returned])
	var ko := await _step_until(func(): return died_scrap[0] >= 0, 90)
	_t.check("returned buoy knocks out Tender for double scrap (10)",
		ko and died_scrap[0] == BoomTender.BASE_SCRAP * 2,
		"ko=%s scrap=%d" % [ko, died_scrap[0]])
	_clear_field()


func _test_netcaster_ceiling_drop() -> void:
	_clear_field()
	await _frames(2)
	var player = _game.player
	var at := _ball_at + Vector3(8.0, 0.0, 0.0)
	player.reset_to(_ball_at)
	var unit = _game.combat.spawn_enemy("netcaster", _game.ctx.terrain.drop_point(at.x, at.z, 1.4))
	unit.hp = 500.0
	unit._rest = 0.05
	# Spawn nearby shield & jam targets within 10 m of ball_at to test Conductive Tear EMP!
	var brute = _game.combat.spawn_enemy("plated_brute", _game.ctx.terrain.drop_point(_ball_at.x - 5.0, _ball_at.z, 1.5))
	brute.hp = 500.0
	brute.walk_speed = 0.0
	brute._rest = 99.0
	var linker = _game.combat.spawn_enemy("linker", _game.ctx.terrain.drop_point(_ball_at.x + 4.0, _ball_at.z + 3.0, 1.5))
	linker.hp = 500.0
	# Camp grounded beneath active primary net for > 1.5 s (brake on floor so Dam slope does not roll ball out).
	player.reset_to(_ball_at)
	var primed := false
	for i in 360:
		player.body().linear_velocity = Vector3.ZERO
		await physics_frame
		if unit._drop_primed:
			primed = true
			break
	_t.check("netcaster primes Snap-Trap Ceiling Drop after camping grounded > 1.5 s", primed,
		"camp=%.2f primed=%s" % [unit._camp_time, primed])
	# Wait through normal recovery into Snap-Trap Ceiling Drop WARN.
	var drop_warn := false
	for i in 240:
		player.body().linear_velocity = Vector3.ZERO
		await physics_frame
		if unit.phase == unit.Phase.WARN and unit._dropping:
			drop_warn = true
			break
	var tele = unit.telegraph()
	_t.check("netcaster enters Snap-Trap Ceiling Drop WARN (0.80 s HAZARD grounded ring + AttackBudget)",
		drop_warn and is_equal_approx(unit.warn_seconds, Netcaster.DROP_WARN)
		and tele != null and not tele.air_only and tele.color.is_equal_approx(Palette.HAZARD)
		and unit.is_in_group(AttackBudget.ATTACKING),
		"drop_warn=%s warn_s=%.2f" % [drop_warn, unit.warn_seconds])
	var drop_live := false
	for i in 140:
		player.body().linear_velocity = Vector3.ZERO
		await physics_frame
		if unit.phase == unit.Phase.LIVE and unit._dropping:
			drop_live = true
			break
	_t.check("netcaster Snap-Trap Ceiling Drop enters LIVE after >= 0.80 s",
		drop_live and unit.ceiling_drops >= 1 and unit.last_warn >= Netcaster.DROP_WARN - 0.03,
		"live=%s drops=%d last_warn=%.3f" % [drop_live, unit.ceiling_drops, unit.last_warn])
	# Apply a jam on player, then smash/boost through dropping net to trigger 10 m EMP arc!
	player.abilities.jam(2.0)
	_game.events.slammed.emit(tele.center if tele != null else _ball_at, 1.0, 1.0)
	await _frames(3)
	_t.check("smash through dropping net triggers 10 m EMP stripping Linker, Brute plate & player jam",
		unit.emp_arcs == 1 and linker.cut and brute.plates == 0 and not player.abilities.jammed() and unit.emp_stripped >= 3,
		"arcs=%d linker_cut=%s brute_plates=%d jammed=%s stripped=%d" % [unit.emp_arcs, linker.cut, brute.plates, player.abilities.jammed(), unit.emp_stripped])
	_t.check("netcaster restores primary warn_seconds after drop ends",
		is_equal_approx(unit.warn_seconds, Netcaster.PRIMARY_WARN),
		"warn_seconds=%.2f" % unit.warn_seconds)
	_clear_field()


func _test_jolt_layer_cable_whip() -> void:
	_clear_field()
	await _frames(2)
	var player = _game.player
	var at := _ball_at + Vector3(8.0, 0.0, 0.0)
	player.reset_to(_ball_at)
	var unit = _game.combat.spawn_enemy("jolt_layer", _game.ctx.terrain.drop_point(at.x, at.z, 1.5))
	unit._rest = 0.05
	var mat_live := await _step_until(func(): return unit.phase == unit.Phase.LIVE and unit.field != null, 180)
	_t.check("jolt_layer lays primary mat first", mat_live, "phase=%s" % unit.state_name())
	# Skirt the mat rim (radius 6.0 -> stand at 5.2 m from mat centre) without hurting spool.
	var rim_pos: Vector3 = unit.field.centre + Vector3(0.0, 0.0, 5.2)
	rim_pos.y = _game.ctx.terrain.height(rim_pos.x, rim_pos.z) + 1.05
	var primed := false
	for i in 200:
		player.reset_to(rim_pos)
		await physics_frame
		if unit._whip_primed:
			primed = true
			break
	_t.check("jolt_layer primes Cable Whip Overload when skirting mat rim", primed,
		"rim_time=%.2f primed=%s" % [unit._rim_time, primed])
	# Let current mat finish, wait through recovery into Cable Whip WARN.
	unit._t = unit.live_seconds
	var whip_warn := false
	for i in 320:
		player.reset_to(rim_pos)
		await physics_frame
		if unit.phase == unit.Phase.WARN and unit._whipping:
			whip_warn = true
			break
	var tele = unit.telegraph()
	_t.check("jolt_layer enters Cable Whip Overload WARN (0.70 s HAZARD lane + AttackBudget)",
		whip_warn and is_equal_approx(unit.warn_seconds, JoltLayer.WHIP_WARN)
		and tele != null and tele.color.is_equal_approx(Palette.HAZARD)
		and unit.is_in_group(AttackBudget.ATTACKING),
		"whip_warn=%s warn_s=%.2f" % [whip_warn, unit.warn_seconds])
	var whip_live := false
	for i in 140:
		player.reset_to(rim_pos)
		await physics_frame
		if unit.phase == unit.Phase.LIVE and unit._whipping:
			whip_live = true
			break
	_t.check("jolt_layer Cable Whip enters LIVE after >= 0.70 s",
		whip_live and unit.cable_whips >= 1 and unit.last_warn >= JoltLayer.WHIP_WARN - 0.03,
		"live=%s whips=%d last_warn=%.3f" % [whip_live, unit.cable_whips, unit.last_warn])
	# Spend Special so we can verify +30% Special cooldown refund!
	player.abilities.spend(AbilityState.SPECIAL)
	var s_slot = player.abilities.slot(AbilityState.SPECIAL)
	s_slot.recharge = 0.0
	var cd: float = player.abilities.cooldown_of(AbilityState.SPECIAL)
	var before_recharge: float = s_slot.recharge
	await _frames(4)
	# Boost across the glowing cable wave front!
	var wpos: Vector3 = unit.whip_wave_position()
	player.reset_to(wpos)
	_game.events.boosted.emit(Vector3.FORWARD)
	await _frames(3)
	var popped_dead: bool = not is_instance_valid(unit) or unit.is_dead()
	var gained: float = s_slot.recharge - before_recharge
	_t.check("boosting across glowing wave 1-pops Jolt Layer + refunds 30% Special cooldown",
		popped_dead and gained >= cd * JoltLayer.SPECIAL_REFUND_SHARE - 0.15,
		"dead=%s gained=%.2f want>=%.2f" % [popped_dead, gained, cd * JoltLayer.SPECIAL_REFUND_SHARE])
	_clear_field()


func _run() -> void:
	await _boot()
	_test_tell_floors()
	await _test_swatter_sky_spank()
	await _test_boom_tender_buoy_throw()
	await _test_netcaster_ceiling_drop()
	await _test_jolt_layer_cable_whip()
	_game.free()
	quit(_t.verdict())
