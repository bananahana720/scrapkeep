extends SceneTree

const Lab := preload("res://tools/matchup_lab.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Game := preload("res://src/game.gd")
const Augments := preload("res://src/movement/augments.gd")
const Director := preload("res://src/world/director.gd")
const T := preload("res://tests/support/t.gd")

# Regression guard for DuelDriver._roam() takeoff wedge in tools/matchup_lab.gd:
# 1. DuelDriver defaults chain_hand_enabled = false so pack duels stay on the one-bite
#    harpoon hand and never stall in _chain_phase = "takeoff" (which suppressed stick,
#    dodge, actives, and weapon cadence fire).
# 2. If a caller explicitly enables chain_hand_enabled = true, DuelDriver._roam() steps
#    _explorer_chain() instead of trapping _act() in _chain_drive() forever.
# 3. A live Tally vs park elite pack duel (seed 1, previously capped at 40s) clears the
#    pack with zero _chain_phase ticks and fires Tally PAID stamps throughout.

const DT := 1.0 / 90.0
const PACK_MEMBERS := ["hooker", "jolt_layer", "plated_brute"]

var _t := T.new("matchup_lab_driver_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.beacon_seconds_override = Lab.BEACON_PIN_S
	_game.run.run_seed_override = 1

	var driver := Lab.DuelDriver.new(_game, "brawler", 1)
	driver.class_index = BotDriver.class_index_for(0, "tally")
	driver.dodge = Lab.DODGE
	driver._dodge_rng.seed = hash(["dodge", 1])
	driver.stage_limit = INF
	_t.check("DuelDriver defaults chain_hand_enabled to false", not driver.chain_hand_enabled)
	driver.start()
	for _i in 6:
		await physics_frame

	_check_harpoon_and_roam(driver)
	await _check_live_tally_elite_duel(driver)

	_game.free()
	_game = null
	quit(_t.verdict())


func _check_harpoon_and_roam(driver) -> void:
	var player = _game.player
	var first := StaticBody3D.new()
	var second := StaticBody3D.new()
	for anchor in [first, second]:
		anchor.collision_layer = Augments.ENEMY_MASK
		anchor.add_to_group("enemy")
		root.add_child(anchor)
	first.global_position = player.ball_position() + Vector3(0.0, 0.0, -18.0)
	second.global_position = player.ball_position() + Vector3(8.0, 0.0, -18.0)
	var saved_grounded: bool = player.state.grounded
	var saved_aim: Dictionary = player.kit.aim.duplicate()
	var saved_vel: Vector3 = player.body().linear_velocity
	var saved_pos: Vector3 = player.body().global_position

	# Default DuelDriver: two hookable enemies in rope range keep the one-bite harpoon hand.
	player.state.grounded = true
	player.kit.aim = {"body": first, "point": first.global_position, "normal": Vector3.UP, "state": Augments.AIM_BODY}
	driver._off_line = 99.0
	driver.source.press.clear()
	driver.source.hold.clear()
	driver._harpoon_hand(first, DT)
	_t.check("default DuelDriver keeps _chain_phase empty with two enemies in range",
		driver._chain_phase == "" and driver.source.press.get("harpoon_pressed", false)
		and not driver.source.press.get("jump_pressed", false),
		"phase='%s' press=%s" % [driver._chain_phase, driver.source.press])

	# Planted fallback: if chain_hand_enabled is forced true, DuelDriver._roam() steps _explorer_chain()
	# and clears _chain_phase on apex fall instead of wedging forever in "takeoff".
	var saved_chain_hand: bool = driver.chain_hand_enabled
	driver.chain_hand_enabled = true
	driver.source.press.clear()
	driver.source.hold.clear()
	driver._harpoon_hand(first, DT)
	_t.eq("explicit chain_hand_enabled arms takeoff", driver._chain_phase, "takeoff")
	player.state.grounded = false
	player.body().linear_velocity = Vector3.UP * 8.0
	driver._roam(DT)
	_t.check("DuelDriver._roam() steps _explorer_chain() while rising", driver._chain_rose)
	player.body().linear_velocity = Vector3.ZERO
	driver._roam(DT)
	_t.eq("DuelDriver._roam() clears takeoff on apex fall (no wedge)", driver._chain_phase, "")

	# Restore clean state for the live duel.
	driver.chain_hand_enabled = saved_chain_hand
	driver._clear_chain_hand()
	driver._off_line = 0.0
	driver.source.press.clear()
	driver.source.hold.clear()
	player.state.grounded = saved_grounded
	player.kit.aim = saved_aim
	player.body().linear_velocity = saved_vel
	player.body().global_position = saved_pos
	first.free()
	second.free()


func _check_live_tally_elite_duel(driver) -> void:
	# Wait for Tally to rest on the ground, then spawn the park elite pack 12 m ahead.
	var settled := 0.0
	for _i in 900:
		await physics_frame
		if _game.flow.in_stage() and _game.player.state.grounded:
			_game.player.set_velocity_now(Vector3.ZERO, "matchup_lab_driver_test")
			settled += DT
			if settled >= 0.25:
				break
	_game.run.set_max_hp(Lab.HULL_POOL)
	var ball: Vector3 = _game.player.ball_position()
	var forward: Vector3 = _game.ctx.aim_forward()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	if forward.length() < 0.5:
		forward = Vector3.FORWARD
	var side := Vector3(-forward.z, 0.0, forward.x)
	var center: Vector3 = ball + forward * Lab.PACK_RANGE
	for i in PACK_MEMBERS.size():
		var spot: Vector3 = center + side * Director.PACK_SPREAD * (float(i) - float(PACK_MEMBERS.size() - 1) * 0.5)
		var foe: Node3D = _game.combat.spawn_enemy(PACK_MEMBERS[i], _game.ctx.terrain.drop_point(spot.x, spot.z, 1.8))
		if foe != null:
			driver.members.append(foe)
	_t.eq("all three elite pack members spawned", driver.members.size(), 3)

	var chain_ticks := 0
	var start_s: float = _game.run.stage_time
	var cleared := false
	for _tick in 2250: # 25 s cap at 90 Hz
		driver.tick(DT)
		if driver._chain_phase != "":
			chain_ticks += 1
		await physics_frame
		var any_alive := false
		for m in driver.members:
			if Lab.DuelDriver.alive(m):
				any_alive = true
				break
		if not any_alive:
			cleared = true
			break
	var duel_s: float = _game.run.stage_time - start_s
	var cadence_windows: int = int(driver._totals.get("cadence_windows", 0))
	var cadence_hits: int = int(driver._totals.get("cadence_hits", 0))
	var shots: int = int(driver._totals.get("shots", 0))
	_t.eq("live Tally vs elite duel never enters _chain_phase", chain_ticks, 0)
	_t.check("live Tally vs elite duel clears pack inside 25 s", cleared, "duel_s=%.2f" % duel_s)
	_t.check("live Tally casts PAID stamps throughout the duel",
		cadence_windows > 0 and cadence_hits > 0 and shots > 0,
		"shots=%d cadence_hits=%d/%d" % [shots, cadence_hits, cadence_windows])
