extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const PlatedBrute := preload("res://src/combat/plated_brute.gd")
const Hooker := preload("res://src/combat/hooker.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const T := preload("res://tests/support/t.gd")

const TELL_FLOOR := 0.60

var _game
var _t := T.new("chaser_lobber_plated_brute_hooker_secondary_test")
var _ball_at := Vector3.ZERO
var _tick := 1.0 / 90.0


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 17
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	_clear_field()
	_tick = root.get_physics_process_delta_time()
	var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
	_ball_at = _game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)


func _clear_field() -> void:
	if _game != null and _game.combat != null and _game.combat.fleet != null:
		_game.combat.fleet.holds.clear()
	for group in ["enemy", "enemy_shot", "telegraph"]:
		for node in get_nodes_in_group(group):
			if is_instance_valid(node):
				node.free()
	root.remove_meta(AttackBudget.LAST_META)
	root.remove_meta(AttackBudget.VOLLEY_META)


func _settle(enemy: Node3D) -> void:
	for i in 90:
		if enemy.is_on_floor():
			break
		await physics_frame


func _check_tell_floor_and_budget() -> void:
	_t.check("01 all 4 secondary tells >= 0.60 s",
		is_equal_approx(Telegraph.SECONDARY_TELL_FLOOR, TELL_FLOOR)
		and Chaser.VAULT_WINDUP >= TELL_FLOOR and Lobber.CLUSTER_TELEGRAPH >= TELL_FLOOR
		and PlatedBrute.CHARGE_WARN >= TELL_FLOOR and Hooker.WHIP_WARN >= TELL_FLOOR,
		"floor %.2f; chaser %.2f, lobber %.2f, brute %.2f, hooker %.2f" % [
			Telegraph.SECONDARY_TELL_FLOOR, Chaser.VAULT_WINDUP, Lobber.CLUSTER_TELEGRAPH, PlatedBrute.CHARGE_WARN, Hooker.WHIP_WARN])
	var clamped := Telegraph.secondary_ring(_game.ctx.root, _game.ctx.terrain, Threat.Type.INSTANT, _ball_at, 3.0, 0.25)
	_t.check("01b Telegraph.secondary_* clamps tell floor to 0.60 s and locks Palette.HAZARD",
		is_equal_approx(clamped.warn_seconds, Telegraph.SECONDARY_TELL_FLOOR) and clamped.color == Palette.HAZARD,
		"warn %.2f, color %s" % [clamped.warn_seconds, clamped.color.to_html(false)])
	clamped.queue_free()
	await physics_frame
	# Verify AttackBudget.gap_open_for / mark_warn enforce the 0.2 s inter-warning floor.
	var a := Chaser.new()
	var b := Hooker.new()
	_game.ctx.root.add_child(a)
	_game.ctx.root.add_child(b)
	a.world_root = _game.ctx.root
	b.world_root = _game.ctx.root
	a.kind = "chaser"
	b.kind = "hooker"
	a.set_physics_process(false)
	b.set_physics_process(false)
	root.remove_meta(AttackBudget.LAST_META)
	AttackBudget.mark_warn(a)
	var blocked_immediately := not AttackBudget.gap_open_for(b)
	await _frames(AttackBudget.gap_frames() + 1)
	var open_after_gap := AttackBudget.gap_open_for(b)
	_t.check("02 AttackBudget mark_warn enforces 0.2 s inter-warning gap", blocked_immediately and open_after_gap,
		"blocked immediately %s, open after %d frames %s" % [blocked_immediately, AttackBudget.gap_frames() + 1, open_after_gap])
	a.free()
	b.free()
	_clear_field()


func _check_chaser_spring_vault() -> void:
	_clear_field()
	var at := _ball_at + Vector3(8.0, 0.0, 0.0)
	var chaser = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(at.x, at.z, 1.6))
	chaser.hp = 60.0
	await _settle(chaser)

	# Grounded ball: should NOT want vault.
	_game.player.reset_to(_ball_at)
	_game.player.body().freeze = true
	_t.check("03 chaser grounded ball uses primary lunge, not vault", not chaser._wants_vault(chaser._flat_to_ball()))

	# Bank trigger: ball > 10 m away and elevated up a bank -> wants vault.
	var bank_offset := Vector3(-13.0, 0.0, 0.0)
	_game.player.reset_to(chaser.global_position + bank_offset + Vector3(0.0, 5.0, 0.0))
	_t.check("04 chaser > 10 m up a bank triggers spring-vault", chaser._wants_vault(chaser._flat_to_ball()))

	# Airborne > 1.5 m trigger: commits 0.70 s HAZARD arcing ring and launches.
	_game.player.reset_to(_ball_at + Vector3(0.0, 4.0, 0.0))
	chaser._rest = 0.0
	var wound_at := -1
	var launched_at := -1
	var tele_ok := false
	for f in 180:
		await physics_frame
		if chaser.state == Chaser.State.WINDUP and chaser.is_vaulting() and wound_at < 0:
			wound_at = f
			var tele: Node3D = chaser.telegraph()
			tele_ok = tele != null and tele.color == Palette.HAZARD and tele.has_flight and tele.type == Threat.Type.PROJECTILE
		if chaser.state == Chaser.State.LUNGE and chaser.is_vaulting() and launched_at < 0:
			launched_at = f
			break
	var tell_s := float(launched_at - wound_at) * _tick if wound_at >= 0 and launched_at >= 0 else -1.0
	_t.check("05 chaser airborne > 1.5 m commits 0.70 s HAZARD arcing ring",
		wound_at >= 0 and launched_at >= 0 and tele_ok and tell_s >= Chaser.VAULT_WINDUP - _tick - 0.001,
		"tell %.3f s (min %.2f), tele_ok %s" % [tell_s, Chaser.VAULT_WINDUP, tele_ok])

	# Mid-arc Air-Parry Homing Bounce: unfreeze ball, clear air_actions, move into mid-arc chaser.
	var parried_count := [0]
	chaser.died.connect(func(_at: Vector3, _scrap: int): parried_count[0] = chaser.air_parries)
	_game.player.body().freeze = false
	_game.player.state.air_actions = 0
	var start_vel := Vector3(12.0, 2.0, 0.0)
	_game.player.reset_to(chaser.global_position + Vector3(-0.6, 0.3, 0.0), start_vel)
	await _frames(3)
	var chaser_dead: bool = (not is_instance_valid(chaser)) or chaser.is_dead()
	var after_speed := Vector2(_game.player.planar_velocity().x, _game.player.planar_velocity().z).length()
	_t.check("06 chaser mid-arc air-parry 1-hit shatters, kicks +8 m/s, refreshes air-jump",
		chaser_dead and parried_count[0] == 1 and _game.player.state.air_actions == 1 and after_speed >= 18.0,
		"dead %s, parries %d, air_actions %d, speed %.1f m/s (from 12.0)" % [
			chaser_dead, parried_count[0], _game.player.state.air_actions, after_speed])

	# F1 cloak guard: a vault aimed before cloak must NOT hit the real player once cloaked away.
	_clear_field()
	_game.player.reset_to(_ball_at + Vector3(0.0, 4.0, 0.0))
	_game.player.body().freeze = true
	var cloak_chaser = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(at.x, at.z, 1.6))
	await _settle(cloak_chaser)
	var phantom_hits := [0]
	cloak_chaser.hit_player.connect(func(_a: float, _s: Vector3): phantom_hits[0] += 1)
	cloak_chaser._knock = Vector3.ZERO
	cloak_chaser._rest = 0.0
	cloak_chaser._vault_cd = 0.0
	cloak_chaser._begin_vault()
	_game.combat.cloak_at = _ball_at
	_game.combat.cloak_left = 4.0
	_game.player.reset_to(_ball_at + Vector3(30.0, 0.0, 0.0))
	for f in 180:
		await physics_frame
		if cloak_chaser.vaults >= 1:
			break
	_game.combat.cloak_left = 0.0
	_t.check("06b chaser spring-vault does not hit cloaked player outside landing ring (F1)",
		cloak_chaser.vaults >= 1 and phantom_hits[0] == 0,
		"vaults %d, phantom_hits %d" % [cloak_chaser.vaults, phantom_hits[0]])
	_clear_field()


func _check_lobber_bung_cluster() -> void:
	_clear_field()
	var at := _ball_at + Vector3(15.0, 0.0, 0.0)
	var lobber = _game.combat.spawn_enemy("lobber", _game.ctx.terrain.drop_point(at.x, at.z, 2.1))
	lobber.hp = 26.0
	await _settle(lobber)

	# Open ground at 15 m: primary shot, not cluster.
	_game.player.reset_to(_ball_at)
	_game.player.body().freeze = true
	_t.check("07 lobber at 15 m open uses primary mortar", not lobber._wants_cluster(_ball_at - lobber.global_position))

	# Behind cover at 15 m while slow: triggers cluster.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 20.0, 20.0)
	shape.shape = box
	wall.add_child(shape)
	_game.ctx.root.add_child(wall)
	wall.global_position = _ball_at + Vector3(7.5, 6.0, 0.0)
	await _frames(3)
	_t.check("08 lobber stalling behind cover triggers bung-cluster", lobber._wants_cluster(_ball_at - lobber.global_position))
	wall.free()
	await _frames(2)

	# Close < 10 m: commits 0.85 s HAZARD fan and fires 3 bungs across 35 deg spread.
	_game.player.reset_to(lobber.global_position + Vector3(-7.0, 0.0, 0.0))
	lobber._clock = Lobber.CYCLE - Lobber.TELEGRAPH - _tick
	var started_at := -1
	var fired_at := -1
	var tele_hazard := false
	for f in 180:
		await physics_frame
		if lobber.is_clustering() and started_at < 0:
			started_at = f
			tele_hazard = is_instance_valid(lobber._cluster_tele) and lobber._cluster_tele.color == Palette.HAZARD
		if lobber.cluster_shots >= 1 and fired_at < 0:
			fired_at = f
			break
	var tell_s := float(fired_at - started_at) * _tick if started_at >= 0 and fired_at >= 0 else -1.0
	var bungs: Array = []
	for s in get_nodes_in_group("enemy_shot"):
		if s.get("lobber") == lobber:
			bungs.append(s)
	var spread_deg := 0.0
	if bungs.size() == 3:
		var dirs: Array = []
		for s in bungs:
			var d: Vector3 = s.landing - lobber.global_position
			dirs.append(Vector2(d.x, d.z).normalized())
		spread_deg = rad_to_deg(acos(clampf((dirs[0] as Vector2).dot(dirs[2] as Vector2), -1.0, 1.0)))
	_t.check("09 lobber < 10 m commits 0.85 s HAZARD fan and fires 3 bungs in 35 deg spread",
		started_at >= 0 and fired_at >= 0 and tele_hazard and tell_s >= Lobber.CLUSTER_TELEGRAPH - _tick - 0.001
		and bungs.size() == 3 and absf(spread_deg - Lobber.CLUSTER_SPREAD_DEG) <= 4.0,
		"tell %.3f s, bungs %d, spread %.1f deg, hazard %s" % [tell_s, bungs.size(), spread_deg, tele_hazard])

	# Chain-Bat Detonation: place chaff beside lobber, bat ONLY 1 bung FAST (>= 14 m/s) -> all 3 chain-bat and wipe chaff!
	var chaff_pos: Vector3 = lobber.global_position + Vector3(3.0, 0.0, 0.5)
	var chaff = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(chaff_pos.x, chaff_pos.z, 1.6))
	await _settle(chaff)
	_game.player.body().freeze = false
	_game.player.reset_to(_ball_at, Vector3(16.0, 0.0, 0.0))
	_t.check("10 batting 1 bung fast succeeds", bungs.size() == 3 and bungs[0].bat())
	await _frames(3)
	var all_returned: bool = bungs.size() == 3 and bool(bungs[0].returned) and bool(bungs[1].returned) and bool(bungs[2].returned)
	var all_amber: bool = bungs.size() == 3 and bungs[0].ring.color == Palette.AMBER and bungs[1].ring.color == Palette.AMBER and bungs[2].ring.color == Palette.AMBER
	var chains_recorded: int = lobber.chain_detonations if is_instance_valid(lobber) else 0
	# Wait for the 3 returned bungs (0.9 s flight) to land and chain-detonate.
	await _frames(95)
	var lobber_dead: bool = (not is_instance_valid(lobber)) or lobber.is_dead()
	var chaff_dead: bool = (not is_instance_valid(chaff)) or chaff.is_dead()
	_t.check("11 chain-bat flips all 3 bungs to AMBER and 3x blast wipes nearby chaff",
		all_returned and all_amber and chains_recorded == 1 and lobber_dead and chaff_dead,
		"all_returned %s, all_amber %s, chains %d, lobber_dead %s, chaff_dead %s" % [
			all_returned, all_amber, chains_recorded, lobber_dead, chaff_dead])

	# AttackBudget queue cleanliness: a lobber refused a cluster slot then leaving cluster range
	# must withdraw from WAITING so it never deadlocks other units' attacks.
	_clear_field()
	var l2 = _game.combat.spawn_enemy("lobber", _game.ctx.terrain.drop_point(at.x, at.z, 2.1))
	var other_u = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(at.x + 25.0, at.z, 1.6))
	await _settle(l2)
	_game.player.reset_to(l2.global_position + Vector3(-6.0, 0.0, 0.0))
	_game.player.body().freeze = true
	AttackBudget.mark_warn(other_u)
	l2._clock = Lobber.CYCLE - Lobber.TELEGRAPH
	await _frames(2)
	var queued_in_wait: bool = l2.is_in_group(AttackBudget.WAITING)
	_game.player.reset_to(l2.global_position + Vector3(-16.0, 0.0, 0.0))
	await _frames(2)
	var withdrew_cleanly: bool = not l2.is_in_group(AttackBudget.WAITING)
	l2._begin_cluster(l2._ball() - l2.global_position)
	await physics_frame
	l2._cancel_cluster()
	await physics_frame
	var released_on_cancel: bool = not l2.is_in_group(AttackBudget.ATTACKING) and not l2.is_in_group(AttackBudget.WAITING)
	_t.check("11b lobber withdraws from AttackBudget WAITING when leaving cluster range and releases on cancel",
		queued_in_wait and withdrew_cleanly and released_on_cancel,
		"queued %s, withdrew %s, released_cancel %s" % [queued_in_wait, withdrew_cleanly, released_on_cancel])
	_clear_field()


func _check_plated_brute_bulldoze() -> void:
	_clear_field()
	var at := _ball_at + Vector3(11.0, 0.0, 0.0)
	var brute = _game.combat.spawn_enemy("plated_brute", _game.ctx.terrain.drop_point(at.x, at.z, 1.8))
	brute.hp = 500.0
	await _settle(brute)
	_game.player.reset_to(_ball_at)
	_game.player.body().freeze = true

	# Before any slam, orbiting 11 m away must NOT trigger shield-charge.
	_t.check("12 brute before first slam does not charge", not brute._can_charge(brute._flat_to_ball()))

	# Trigger one primary slam first (ball inside SLAM_RANGE).
	_game.player.reset_to(brute.global_position + Vector3(-4.0, 0.0, 0.0))
	brute._rest = 0.0
	for f in 160:
		await physics_frame
		if brute.slams >= 1 and brute.phase == brute.Phase.ROAM:
			break
	_t.check("13 brute primary slam primes shield-charge", brute.slams == 1 and brute._charge_primed)

	# Now player orbits 11 m away with a Tier 5 Heft Destructible wall directly in the charge lane!
	var wall_pos: Vector3 = brute.global_position + Vector3(-5.0, 0.0, 0.0)
	var wall_y: float = _game.ctx.terrain.height(wall_pos.x, wall_pos.z) + 1.5
	var props := Destructibles.new()
	props.build([{"id": "tier5_shortcut", "tier": 5, "at": [wall_pos.x, wall_y, wall_pos.z], "size": [1.8, 3.0, 4.0]}],
		{"root": _game.ctx.root, "no_visuals": true})
	_game.ctx.destructibles = props
	_game.player.reset_to(brute.global_position + Vector3(-11.0, 0.0, 0.0))
	brute._rest = 0.0
	brute.recover_left = 0.0

	var warn_at := -1
	var live_at := -1
	var lane_ok := false
	for f in 240:
		await physics_frame
		if brute.is_charging() and brute.phase == brute.Phase.WARN and warn_at < 0:
			warn_at = f
			var tele: Node3D = brute.telegraph()
			lane_ok = tele != null and tele.color == Palette.HAZARD and tele.shape == Telegraph.Shape.LANE \
				and is_equal_approx(tele.length, PlatedBrute.CHARGE_LENGTH)
		if brute.is_charging() and brute.phase == brute.Phase.LIVE and live_at < 0:
			live_at = f
		if brute.charge_crashes >= 1:
			break
	var tell_s := float(live_at - warn_at) * _tick if warn_at >= 0 and live_at >= 0 else -1.0
	_t.check("14 brute after slam commits 0.85 s 16 m HAZARD shield-charge lane",
		warn_at >= 0 and live_at >= 0 and lane_ok and tell_s >= PlatedBrute.CHARGE_WARN - _tick - 0.001,
		"tell %.3f s (min %.2f), lane_ok %s" % [tell_s, PlatedBrute.CHARGE_WARN, lane_ok])
	_t.check("15 baiting charge into Tier 5 destructible breaks it at Heft 1 & strips outer plate",
		props.state_of("tier5_shortcut") == "shattered" and brute.plates == 0 and brute.plates_popped == 1
		and brute.last_crash_cause == "destructible" and brute.stunned(),
		"wall %s, plates %d, popped %d, cause %s, stunned %s" % [
			props.state_of("tier5_shortcut"), brute.plates, brute.plates_popped, brute.last_crash_cause, brute.stunned()])
	_game.ctx.destructibles = null
	props.free()

	# Also verify Brute-on-Brute crash strips BOTH Brutes' outer plates.
	_clear_field()
	var a = _game.combat.spawn_enemy("plated_brute", _game.ctx.terrain.drop_point(_ball_at.x + 12.0, _ball_at.z, 1.8))
	var b = _game.combat.spawn_enemy("plated_brute", _game.ctx.terrain.drop_point(_ball_at.x + 6.5, _ball_at.z, 1.8))
	a.hp = 500.0
	b.hp = 500.0
	await _settle(a)
	await _settle(b)
	_game.player.reset_to(_ball_at)
	a._charge_primed = true
	a._rest = 0.0
	b._rest = 999.0
	for f in 240:
		await physics_frame
		if a.charge_crashes >= 1:
			break
	_t.check("16 baiting charge into another Brute strips outer plates on BOTH Brutes",
		a.last_crash_cause == "brute" and a.plates == 0 and b.plates == 0,
		"cause %s, a.plates %d, b.plates %d" % [a.last_crash_cause, a.plates, b.plates])
	_clear_field()


func _check_hooker_pendulum_whip() -> void:
	_clear_field()
	var at := _ball_at + Vector3(9.0, 0.0, 0.0)
	var hooker = _game.combat.spawn_enemy("hooker", _game.ctx.terrain.drop_point(at.x, at.z, 1.8))
	hooker.hp = 500.0
	await _settle(hooker)
	_game.player.reset_to(_ball_at)
	_game.player.body().freeze = false
	_game.player.set_velocity_now(Vector3.ZERO)
	hooker._rest = 0.0

	# Path A: hold the ball on the hooker's lane so it tethers and stays tethered > 1.0 s -> Pendulum Reel-Whip arms!
	var held_at := -1
	var whip_armed_at := -1
	var crest_boosted := false
	var wedge_ok := false
	var speed_before := 0.0
	for f in 400:
		if not crest_boosted:
			_game.player.reset_to(_ball_at)
		await physics_frame
		if _game.combat.fleet.holds.held(hooker) and held_at < 0:
			held_at = f
		if hooker._whip_armed and whip_armed_at < 0:
			whip_armed_at = f
			var tele: Node3D = hooker.telegraph()
			wedge_ok = tele != null and tele.color == Palette.HAZARD and tele.shape == Telegraph.Shape.WEDGE \
				and is_equal_approx(rad_to_deg(tele.half_angle), Hooker.WHIP_HALF_DEG)
		if hooker._whip_armed and hooker.in_whip_crest() and not crest_boosted:
			crest_boosted = true
			_game.player.state.air_actions = 0
			_game.player.set_velocity_now(Vector3(-12.0, 0.0, 0.0))
			speed_before = 12.0
			_game.events.boosted.emit(Vector3(-1.0, 0.0, 0.0))
			await _frames(2)
			break
	var tether_s := float(whip_armed_at - held_at) * _tick if held_at >= 0 and whip_armed_at >= 0 else -1.0
	var vel_after: Vector3 = _game.player.body().linear_velocity
	var speed_after := Vector2(vel_after.x, vel_after.z).length()
	_t.check("17 hooker tethered > 1.0 s arms 150-deg HAZARD Pendulum Reel-Whip",
		held_at >= 0 and whip_armed_at >= 0 and wedge_ok and tether_s >= Hooker.WHIP_TETHER_S - _tick - 0.01,
		"tethered %.3f s, wedge_ok %s" % [tether_s, wedge_ok])
	_t.check("18 boosting at whip crest catapults ball >= 1.5x speed with upward lift & staggers hooker",
		crest_boosted and hooker.catapult_snaps == 1 and speed_after >= speed_before * Hooker.CATAPULT_MULT
		and vel_after.y >= 5.0 and _game.player.state.air_actions == 1 and hooker.stunned(),
		"snaps %d, speed %.1f -> %.1f m/s, vy %.1f, air %d, stunned %s" % [
			hooker.catapult_snaps, speed_before, speed_after, vel_after.y, _game.player.state.air_actions, hooker.stunned()])

	# Path B: circling behind the post after warned > 0 triggers Pendulum Reel-Whip (0.75 s shriek).
	hooker.stun_left = 0.0
	hooker.recover_left = 0.0
	hooker._rest = 0.0
	var behind: Vector3 = hooker.global_position - Vector3(hooker.global_basis.z.x, 0.0, hooker.global_basis.z.z).normalized() * 8.0
	_game.player.reset_to(_game.ctx.terrain.drop_point(behind.x, behind.z, 1.05))
	var b_warn := -1
	var b_live := -1
	var b_wedge := false
	for f in 180:
		await physics_frame
		if hooker._whipping and hooker.phase == hooker.Phase.WARN and b_warn < 0:
			b_warn = f
			var tele: Node3D = hooker.telegraph()
			b_wedge = tele != null and tele.color == Palette.HAZARD and tele.shape == Telegraph.Shape.WEDGE
		if hooker.whips >= 1 and b_live < 0:
			b_live = f
			break
	var b_tell := float(b_live - b_warn) * _tick if b_warn >= 0 and b_live >= 0 else -1.0
	_t.check("19 circling behind hooker post triggers 0.75 s 150-deg HAZARD Pendulum Reel-Whip",
		b_warn >= 0 and b_live >= 0 and b_wedge and b_tell >= Hooker.WHIP_WARN - _tick - 0.001,
		"tell %.3f s (min %.2f), wedge %s, whips %d" % [b_tell, Hooker.WHIP_WARN, b_wedge, hooker.whips])
	_clear_field()


func _run() -> void:
	await _boot()
	await _check_tell_floor_and_budget()
	await _check_chaser_spring_vault()
	await _check_lobber_bung_cluster()
	await _check_plated_brute_bulldoze()
	await _check_hooker_pendulum_whip()
	_game.free()
	quit(_t.verdict())
