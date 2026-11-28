extends SceneTree

# W47-H2 Hero Baselines Part 2 (Tarn, The Cannon & Tally Canon Verification):
# - Tarn: Clamp-and-Hurl (0.6 s seize on light/medium -> 30 m/s aim-vector hurl bowling packs
#   and smashing Heft Destructibles +1 tier above Tarn's heft, Destructibles.tla once-per-piece
#   safe), Unstoppable 3rd-Beat Lunge (+6 m lunge with CC immunity & brief frontal armor),
#   and Inward-Facing Pendulum Guard/Strafe on claw_drag around heavy anchors/enemies with
#   his worn-steel articulated mechanical front claw shielding his face (Call #4, no banned terms).
# - The Cannon (its — never feminine pronouns): Air-Lock Overpenetration (releasing locked
#   cannon_lane rail while airborne from cannon_recoil widens beam 1.8x, pierces every enemy
#   in corridor, and blasts Tier 1-3 Heft Destructibles), Recoil-Surf Slam Reset (cannon_rush
#   landing resets cannon_recoil), Explosive Piton Stake (recoil cancel) / Breach (shaped-charge
#   detonation breaking Tier 1-3 Heft Destructibles on release, Destructibles.tla safe), and
#   strictly artillery cannon_fire_mission.
# - Tally: confirms live canon one-shot circuit arc rule preserved per negative paired band
#   experiment receipt.
# - Hygiene: zero Overwatch hero names, zero forbidden wording, clean runtime resets.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Palette := preload("res://src/core/palette.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")

const DT := 1.0 / 60.0
const EXPECTED_CHECKS := 45

var _t := T.new("w47_h2_heroes_test")
var _game
var _player
var _combat
var _claw
var _source := Intent.Scripted.new()
var _temp_nodes: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _never() -> bool:
	return false


func _clear_temp() -> void:
	for n in _temp_nodes:
		if is_instance_valid(n):
			n.free()
	_temp_nodes.clear()
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.free()


func _spawn_dummy(at: Vector3, kind := "chaser", hp := 1000.0) -> Node3D:
	var e: Node3D = _combat.spawn_enemy(kind, at)
	e.global_position = at
	if e.get("live") != null:
		e.live = _never
	e.set_physics_process(false)
	if e.get("hp") != null:
		e.hp = hp
		e.max_hp = hp
	return e


func _make_destructibles(rows: Array) -> Node3D:
	var dest := Destructibles.new()
	_game.add_child(dest)
	_temp_nodes.append(dest)
	dest.build(rows, {"root": _game, "no_visuals": true})
	_game.ctx.destructibles = dest
	return dest


func _switch_pilot(class_id: String, at: Vector3) -> void:
	_clear_temp()
	_game.ctx.destructibles = null
	_combat._reset_w47_h2_state()
	_combat.cannon.free_cannon()
	_combat.bolts.clear()
	_combat.sticky.clear()
	_combat._clamped.clear()
	var def: Resource = ClassDef.by_id(class_id)
	_game.run.class_def = def
	_game.run.mass = 0.0
	_game.run._heft_class = 1
	_player.fit_class(def)
	_combat.rebuild_patterns()
	_combat.weapon_driver.reset(_combat.pattern(def.weapon_id))
	_player.kit.drop_line("reset")
	_player.abilities.refill()
	_player.immune_left = 0.0
	_player.body().freeze = true
	_player.reset_to(at, Vector3.ZERO)
	_player.drive_basis = Basis.looking_at(Vector3.FORWARD)
	_game.camera.snap(Vector3.FORWARD, 0.0)
	_game.camera._process(0.0)
	_player.intent.clear()
	if _claw != null:
		_claw._clear()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for i in 24:
		await physics_frame
	_combat = _game.combat
	_claw = _combat.get_node("TarnClaw")
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_claw.set_physics_process(false)
	_combat.ultimate.set_physics_process(false)

	await _test_tarn()
	await _test_cannon()
	await _test_tally_canon_preserved()
	_test_hygiene_and_resets()

	_clear_temp()
	_game.ctx.destructibles = null
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	quit(_t.verdict())


# --- 1. TARN --------------------------------------------------------------------------

func _test_tarn() -> void:
	var base_pt := Vector3(-140.0, 140.0, -140.0)
	_switch_pilot("tarn", base_pt)
	await physics_frame

	# 1a. Clamp-and-Hurl: seizes light/medium enemy for 0.6 s, hurls at 30 m/s, bowls pack,
	# and smashes Heft Destructible +1 tier above Tarn's heft (Heft I breaks Tier 2, never Tier 3).
	var seized_foe := _spawn_dummy(base_pt + Vector3(0.0, 0.0, -2.5), "chaser", 800.0)
	var pack_a := _spawn_dummy(base_pt + Vector3(0.5, 0.0, -9.0), "chaser", 800.0)
	var pack_b := _spawn_dummy(base_pt + Vector3(-0.6, 0.0, -13.0), "chaser", 800.0)
	var dest := _make_destructibles([
		{"id": "hurl_t2", "tier": 2, "at": [base_pt.x, base_pt.y, base_pt.z - 10.0], "size": [3.0, 3.0, 1.4], "yaw_deg": 0.0},
		{"id": "hurl_t3", "tier": 3, "at": [base_pt.x, base_pt.y, base_pt.z - 14.0], "size": [3.0, 3.0, 1.4], "yaw_deg": 0.0},
	])
	await physics_frame

	var hp_a_before: float = pack_a.hp
	var hp_b_before: float = pack_b.hp
	_combat._fire_clamp(1.0, _combat._clamp_geometry(1.0))
	_t.check("Clamp seizes light/medium enemy for 0.6 s with worn-steel claw",
		not _claw.seized.is_empty() and _claw.seized.get("enemy") == seized_foe
		and is_equal_approx(float(_claw.seized.get("left", 0.0)), Weapons.CLAMP_SEIZE_SECONDS)
		and String(_claw.seized.get("claw_material", "")) == "worn_steel",
		str(_claw.seized))
	_t.eq("Clamp last_burst records seized=true", bool(_combat.last_burst.get("seized", false)), true)

	# Step 0.35 s: still seized, not yet hurled.
	for i in 21:
		_claw.step(DT)
	_t.check("Enemy stays seized during 0.6 s hold window", not _claw.seized.is_empty() and _claw.clamp_hurls.is_empty())

	# Step past 0.6 s -> launches down aim vector at 30 m/s!
	for i in 20:
		_claw.step(DT)
	_t.check("After 0.6 s Tarn hurls enemy down aim vector at 30 m/s",
		_claw.seized.is_empty() and not _claw.last_clamp_hurl.is_empty()
		and is_equal_approx(float(_claw.last_clamp_hurl.get("speed", 0.0)), Weapons.CLAMP_HURL_SPEED)
		and (_claw.last_clamp_hurl.get("dir", Vector3.ZERO) as Vector3).dot(Vector3.FORWARD) > 0.95,
		str(_claw.last_clamp_hurl))

	# Step flight through pack and walls.
	for i in 45:
		_claw.step(DT)
	_t.check("Hurled enemy bowls through pack targets along flight path",
		pack_a.hp < hp_a_before and pack_b.hp < hp_b_before and int(_claw.last_clamp_hurl.get("bowled", 0)) >= 2,
		"a %.1f->%.1f b %.1f->%.1f hurl=%s" % [hp_a_before, pack_a.hp, hp_b_before, pack_b.hp, str(_claw.last_clamp_hurl)])
	_t.eq("Heft I hurled enemy smashes Tier 2 (+1 tier) Heft Destructible", dest.state_of("hurl_t2"), "shattered")
	_t.eq("Heft I hurled enemy NEVER breaks Tier 3 (+2 tiers) Heft Destructible", dest.state_of("hurl_t3"), "intact")
	var loot_once: Dictionary = dest.loot()
	var second_sweep: Array[String] = dest.on_hurled_enemy(base_pt, base_pt + Vector3(0.0, 0.0, -20.0), 1, 2.0, "tarn_hurl")
	_t.check("Destructibles.tla safe: already-shattered piece never re-breaks or repays",
		second_sweep.is_empty() and dest.loot() == loot_once and dest.break_order().count("hurl_t2") == 1,
		"second=%s loot=%s order=%s" % [str(second_sweep), str(dest.loot()), str(dest.break_order())])

	# Protected/heavy enemy (Lobber weight 3.0 at Heft I) is NOT seized.
	var heavy_lobber := _spawn_dummy(base_pt + Vector3(0.0, 0.0, -2.5), "lobber", 1000.0)
	_t.eq("Clamp-and-Hurl never seizes heavy enemy above weight limit at Heft I", _claw.try_seize([heavy_lobber]), null)

	# 1b. Unstoppable 3rd-Beat Lunge: +6 m lunge with CC immunity & brief frontal armor.
	_switch_pilot("tarn", base_pt)
	await physics_frame
	_player.body().freeze = false
	_player.state.velocity = Vector3.ZERO
	_combat._fire(Weapons.CLAW_SWEEP, "weapon", {"kind": WeaponDriver.SHOT_BEAT_3, "beat": 3, "damage_mult": 43.0 / 18.0})
	_t.check("3rd-Beat Lunge activates with +6 m target and CC immunity",
		bool(_combat.last_shot.get("beat3_lunge", false))
		and not _claw.beat3_lunge.is_empty()
		and is_equal_approx(float(_claw.last_beat3_lunge.get("target_m", 0.0)), Weapons.TARN_BEAT3_LUNGE_M)
		and _player.immune_left >= Weapons.TARN_BEAT3_ARMOR_S - 0.02,
		"lunge=%s immune=%.2f" % [str(_claw.last_beat3_lunge), _player.immune_left])
	_t.eq("3rd-Beat Lunge is Unstoppable (crowd_control rejected)", _player.crowd_control("knock", Vector3.BACK * 40.0), false)
	var lunge_vel_z: float = _player.state.velocity.z
	_t.check("3rd-Beat Lunge drives forward at >= 24 m/s (6 m / 0.25 s)", lunge_vel_z <= -23.5, "vel=%s" % str(_player.state.velocity))
	# Frontal armor mitigates hits from the front (shove = Vector3.BACK means hit came from FORWARD),
	# while rear hits (shove = Vector3.FORWARD) take full damage.
	_game.run.hp = 135.0
	_game.run.max_hp = 135.0
	var hp_front_before: float = _game.run.hp
	_combat._on_player_hit(20.0, Vector3.BACK * 10.0, "chaser")
	var front_lost: float = hp_front_before - float(_game.run.hp)
	var hp_rear_before: float = _game.run.hp
	_combat._on_player_hit(20.0, Vector3.FORWARD * 10.0, "chaser")
	var rear_lost: float = hp_rear_before - float(_game.run.hp)
	_t.check("3rd-Beat Lunge frontal armor halves frontal hit while rear hit takes full damage",
		front_lost > 0.0 and rear_lost > front_lost and absf(front_lost / rear_lost - Weapons.TARN_FRONTAL_ARMOR_MULT) < 0.05
		and String(_claw.last_armor_block.get("source", "")) == "beat3_lunge",
		"front=%.2f rear=%.2f block=%s" % [front_lost, rear_lost, str(_claw.last_armor_block)])
	_player.body().freeze = true

	# 1c. Inward-Facing Pendulum Guard/Strafe on claw_drag around heavy anchor/enemy.
	_switch_pilot("tarn", base_pt)
	await physics_frame
	var heavy_anchor := _spawn_dummy(base_pt + Vector3(0.0, 0.0, -14.0), "lobber", 2000.0)
	_player.grapple_to(heavy_anchor.global_position, Vector3.BACK, heavy_anchor)
	_claw.on_body(heavy_anchor, 1.0, 1.0)
	_t.check("claw_drag on heavy enemy arms inward-facing pendulum guard with worn-steel claw",
		not _claw.pendulum_guard.is_empty() and bool(_claw.pendulum_guard.get("active", false))
		and (_claw.pendulum_guard.get("facing", Vector3.ZERO) as Vector3).dot(Vector3.FORWARD) > 0.95
		and String(_claw.pendulum_guard.get("claw_material", "")) == "worn_steel",
		str(_claw.pendulum_guard))
	# Lateral strafe input applies tangential pendulum acceleration perpendicular to facing.
	_player._rigid.external_accel = Vector3.ZERO
	_player.intent.move = Vector2(1.0, 0.0)
	_claw.step(DT)
	var tangent_accel: Vector3 = _player._rigid.external_accel
	_t.check("Inward pendulum strafe drives tangentially perpendicular to anchor facing",
		absf(tangent_accel.x) > 50.0 and absf(tangent_accel.z) < 1.0,
		"accel=%s" % str(tangent_accel))
	_player.intent.move = Vector2.ZERO
	# Front claw shields Tarn's face toward the heavy anchor.
	_game.run.hp = 135.0
	var pg_hp_before: float = _game.run.hp
	_combat._on_player_hit(20.0, Vector3.BACK * 10.0, "lobber")
	var pg_front_lost: float = pg_hp_before - float(_game.run.hp)
	var pg_rear_before: float = _game.run.hp
	_combat._on_player_hit(20.0, Vector3.FORWARD * 10.0, "lobber")
	var pg_rear_lost: float = pg_rear_before - float(_game.run.hp)
	_t.check("Pendulum guard shields face from inward frontal hits (0.50x) but not rear hits",
		pg_front_lost > 0.0 and absf(pg_front_lost / pg_rear_lost - Weapons.TARN_FRONTAL_ARMOR_MULT) < 0.05
		and String(_claw.last_armor_block.get("source", "")) == "pendulum_guard",
		"front=%.2f rear=%.2f" % [pg_front_lost, pg_rear_lost])
	# Releasing line drops pendulum guard cleanly.
	_player.kit.drop_line("let_go")
	_claw.step(DT)
	_t.eq("Releasing grapple line clears pendulum guard", _claw.pendulum_guard.is_empty(), true)


# --- 2. THE CANNON (its) --------------------------------------------------------------

func _test_cannon() -> void:
	var spawn_pt: Vector3 = _game.ctx.terrain.spawn_point(1)
	var base_pt := Vector3(spawn_pt.x, _game.ctx.terrain.height(spawn_pt.x, spawn_pt.z) + 4.0, spawn_pt.z)
	_switch_pilot("remembered_cannon", base_pt)
	await physics_frame

	# 2a. Grounded Rail keeps 1.0x width (air_lock_overpen=false).
	var pat: Resource = _combat.pattern(Weapons.CANNON_LANE)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	var p_in := Intent.new()
	p_in.fire_pressed = true
	p_in.fire_held = true
	drv.step(DT, p_in, Weapons.CANNON_LANE, pat, 1.0, {"rate_mult": 1.0, "recoil_airborne": false})
	var h_in := Intent.new()
	h_in.fire_held = true
	drv.step(0.36, h_in, Weapons.CANNON_LANE, pat, 1.0, {"rate_mult": 1.0, "recoil_airborne": false})
	var r_in := Intent.new()
	r_in.fire_released = true
	var grounded_shots := drv.step(DT, r_in, Weapons.CANNON_LANE, pat, 1.0, {"rate_mult": 1.0, "recoil_airborne": false})
	_t.check("Grounded locked cannon_lane rail keeps 1.0x width without Air-Lock Overpenetration",
		grounded_shots.size() == 1 and String(grounded_shots[0]["kind"]) == WeaponDriver.SHOT_RAIL
		and is_equal_approx(float(grounded_shots[0]["width_mult"]), 1.0)
		and not bool(grounded_shots[0]["air_lock_overpen"]),
		str(grounded_shots))

	# 2b. Air-Lock Overpenetration: airborne from cannon_recoil widens rail 1.8x, pierces every
	# enemy in widened corridor, and blasts Tier 1-3 Heft Destructibles (leaves Tier 4 intact).
	_player.state.grounded = false
	_combat.cannon.on_cannon_dashed(Vector3.FORWARD)
	_t.eq("cannon_recoil arms recoil_airborne while airborne", _combat.cannon.cannon_recoil_airborne(), true)

	# Paint preview while airborne & locked reflects 1.8x widened beam (TADR-008).
	_combat.weapon_driver.reset(pat)
	_combat.weapon_driver.step(DT, p_in, Weapons.CANNON_LANE, pat, 1.0, {"rate_mult": 1.0, "recoil_airborne": true})
	_combat.weapon_driver.step(0.36, h_in, Weapons.CANNON_LANE, pat, 1.0, {"rate_mult": 1.0, "recoil_airborne": true})
	_combat.cannon._step_cannon_paint()
	_t.check("Air-Lock paint preview widens rail 1.8x before release",
		bool(_combat.cannon.last_cannon_paint.get("air_lock_overpen", false))
		and is_equal_approx(float(_combat.cannon.last_cannon_paint.get("half", 0.0)), MindAttacks.LANE_HALF * Weapons.CANNON_AIR_RAIL_WIDTH_MULT),
		str(_combat.cannon.last_cannon_paint))

	# Place 3 enemies on the canyon floor along the widened corridor (including off-center inside
	# 1.8x width and a plated brute) plus Tier 1, 2, 3, and 4 Heft Destructibles.
	var p1 := Vector3(base_pt.x, _game.ctx.terrain.height(base_pt.x, base_pt.z - 7.0) + 1.0, base_pt.z - 7.0)
	var p2 := Vector3(base_pt.x + MindAttacks.LANE_HALF * 1.35, _game.ctx.terrain.height(base_pt.x + MindAttacks.LANE_HALF * 1.35, base_pt.z - 12.0) + 1.0, base_pt.z - 12.0)
	var p3 := Vector3(base_pt.x - 0.3, _game.ctx.terrain.height(base_pt.x - 0.3, base_pt.z - 17.0) + 1.0, base_pt.z - 17.0)
	var e1 := _spawn_dummy(p1, "chaser", 800.0)
	var e2 := _spawn_dummy(p2, "chaser", 800.0)
	var e3 := _spawn_dummy(p3, "plated_brute", 1000.0)
	var dest := _make_destructibles([
		{"id": "rail_t1", "tier": 1, "at": [base_pt.x, base_pt.y - 0.9, base_pt.z - 6.0], "size": [2.0, 4.0, 1.2], "yaw_deg": 0.0},
		{"id": "rail_t2", "tier": 2, "at": [base_pt.x, base_pt.y - 0.9, base_pt.z - 10.0], "size": [2.0, 4.0, 1.2], "yaw_deg": 0.0},
		{"id": "rail_t3", "tier": 3, "at": [base_pt.x, base_pt.y - 0.9, base_pt.z - 15.0], "size": [2.0, 4.0, 1.2], "yaw_deg": 0.0},
		{"id": "rail_t4", "tier": 4, "at": [base_pt.x, base_pt.y - 0.9, base_pt.z - 20.0], "size": [2.0, 4.0, 1.2], "yaw_deg": 0.0},
	])
	await physics_frame

	var air_shots: Array = _combat.weapon_driver.step(DT, r_in, Weapons.CANNON_LANE, pat, 1.0, {"rate_mult": 1.0, "recoil_airborne": true})
	_t.check("Air-Lock release emits widened 1.8x overpenetrating SHOT_RAIL",
		air_shots.size() == 1 and String(air_shots[0]["kind"]) == WeaponDriver.SHOT_RAIL
		and is_equal_approx(float(air_shots[0]["width_mult"]), Weapons.CANNON_AIR_RAIL_WIDTH_MULT)
		and bool(air_shots[0]["air_lock_overpen"]) and bool(air_shots[0]["overpenetrate"]),
		str(air_shots))

	var hp1 := float(e1.hp)
	var hp2 := float(e2.hp)
	var hp3 := float(e3.hp)
	_combat.cannon.fire_cannon_lane(Weapons.CANNON_LANE, air_shots[0], "weapon")
	var rail_entry: Dictionary = _combat.cannon._cannon.back()
	var rail_h = rail_entry["hazards"][0]
	_t.near("Committed Air-Lock rail hazard half_width is 1.8x MindAttacks.LANE_HALF",
		float(rail_h.half_width), MindAttacks.LANE_HALF * Weapons.CANNON_AIR_RAIL_WIDTH_MULT, 0.01)
	_t.eq("Air-Lock rail blasts Tier 1 Heft Destructible", dest.state_of("rail_t1"), "shattered")
	_t.eq("Air-Lock rail blasts Tier 2 Heft Destructible", dest.state_of("rail_t2"), "shattered")
	_t.eq("Air-Lock rail blasts Tier 3 Heft Destructible", dest.state_of("rail_t3"), "shattered")
	_t.eq("Air-Lock rail leaves Tier 4 Heft Destructible intact", dest.state_of("rail_t4"), "intact")
	var rail_loot: Dictionary = dest.loot()
	var rail_repeat: Array[String] = dest.on_rail_breach(base_pt, base_pt + Vector3(0.0, 0.0, -24.0), MindAttacks.LANE_HALF * 1.8, 3, "cannon_air_rail")
	_t.check("Destructibles.tla safe: repeated Air-Lock rail breach never re-shatters or repays",
		rail_repeat.is_empty() and dest.loot() == rail_loot, str(rail_repeat))

	# Step hazard to live so every enemy in the 1.8x corridor is pierced.
	for i in 120:
		_combat._clock += DT
		_combat.cannon.step_cannon(DT)
	_t.check("Air-Lock rail pierces every enemy across its 1.8x widened corridor",
		e1.hp < hp1 and e2.hp < hp2 and e3.hp < hp3,
		"e1 %.1f->%.1f e2 %.1f->%.1f e3 %.1f->%.1f" % [hp1, e1.hp, hp2, e2.hp, hp3, e3.hp])

	# 2c. Recoil-Surf Slam Reset: cannon_rush landing immediately resets cannon_recoil.
	_player.abilities.spend(AbilityState.MOVEMENT)
	_t.eq("cannon_recoil cooling after spend", _player.abilities.ready(AbilityState.MOVEMENT), false)
	_combat.cannon.on_cannon_slammed(base_pt, 1.0, 1.0)
	_t.check("cannon_rush slam landing immediately resets cannon_recoil",
		_player.abilities.ready(AbilityState.MOVEMENT) and not _combat.cannon.last_cannon_recoil_reset.is_empty(),
		str(_combat.cannon.last_cannon_recoil_reset))
	_t.eq("cannon_rush slam landing clears recoil_airborne flag", _combat.cannon.cannon_recoil_airborne(), false)

	# 2d. Explosive Piton Stake (recoil cancel) / Breach (shaped-charge detonation on release).
	_switch_pilot("remembered_cannon", base_pt)
	await physics_frame
	var piton_pt := base_pt + Vector3(0.0, 0.0, -8.0)
	var piton_foe := _spawn_dummy(piton_pt + Vector3(1.5, 0.0, 0.0), "chaser", 800.0)
	var piton_dest := _make_destructibles([
		{"id": "piton_t1", "tier": 1, "at": [piton_pt.x - 1.5, piton_pt.y, piton_pt.z], "size": [1.8, 2.2, 1.2], "yaw_deg": 0.0},
		{"id": "piton_t3", "tier": 3, "at": [piton_pt.x, piton_pt.y, piton_pt.z - 2.0], "size": [2.0, 2.4, 1.2], "yaw_deg": 0.0},
		{"id": "piton_t4", "tier": 4, "at": [piton_pt.x + 2.0, piton_pt.y, piton_pt.z - 1.0], "size": [2.0, 2.4, 1.2], "yaw_deg": 0.0},
	])
	await physics_frame

	# Latch piton to world anchor -> Stake mode.
	_player.grapple_to(piton_pt, Vector3.BACK, null)
	_t.eq("World grapple arms Cannon Explosive Piton Stake", _combat.cannon.cannon_piton_staked(), true)
	# Firing cannon_recoil while staked cancels recoil velocity kick!
	_player.state.velocity = Vector3(0.0, 4.0, -25.0)
	_combat.cannon.on_cannon_dashed(Vector3.FORWARD)
	_t.check("Explosive Piton Stake cancels recoil velocity kick while holding position",
		_player.state.velocity.is_equal_approx(Vector3.ZERO)
		and bool(_combat.cannon.last_cannon_piton.get("recoil_cancelled", false))
		and not _combat.cannon.cannon_recoil_airborne(),
		"vel=%s piton=%s" % [str(_player.state.velocity), str(_combat.cannon.last_cannon_piton)])

	# Release piton -> Breach shaped-charge detonation breaks Tier 1-3, leaves Tier 4, damages enemy!
	var foe_hp_before: float = piton_foe.hp
	_player.release_grapple()
	_combat._on_grapple_released_w47()
	_t.check("Explosive Piton Breach detonates on release and strikes nearby enemy",
		String(_combat.cannon.last_cannon_piton.get("mode", "")) == "breach"
		and int(_combat.cannon.last_cannon_piton.get("hits", 0)) >= 1
		and piton_foe.hp < foe_hp_before,
		"hp %.1f->%.1f piton=%s" % [foe_hp_before, piton_foe.hp, str(_combat.cannon.last_cannon_piton)])
	_t.eq("Explosive Piton Breach shatters Tier 1 Heft Destructible", piton_dest.state_of("piton_t1"), "shattered")
	_t.eq("Explosive Piton Breach shatters Tier 3 Heft Destructible", piton_dest.state_of("piton_t3"), "shattered")
	_t.eq("Explosive Piton Breach leaves Tier 4 Heft Destructible intact", piton_dest.state_of("piton_t4"), "intact")
	var piton_loot_once: Dictionary = piton_dest.loot()
	var second_det: Dictionary = _combat.cannon.detonate_cannon_piton()
	_t.check("Destructibles.tla safe: piton detonates strictly once and never repays",
		second_det.is_empty() and piton_dest.loot() == piton_loot_once,
		"second=%s loot=%s" % [str(second_det), str(piton_dest.loot())])


# --- 3. TALLY CANON PRESERVED ---------------------------------------------------------

func _test_tally_canon_preserved() -> void:
	var base_pt := Vector3(-230.0, 140.0, -230.0)
	_switch_pilot("tally", base_pt)
	await physics_frame
	var a := _spawn_dummy(base_pt + Vector3(0.0, 0.0, -8.0), "chaser", 800.0)
	var b := _spawn_dummy(base_pt + Vector3(3.0, 0.0, -8.0), "chaser", 800.0)
	_combat.tally_kit._link_from(a, 1.0)
	var hp_b_before: float = b.hp
	_combat.strike(a, "ram", 30.0)
	var hp_b_after_first: float = b.hp
	_combat.strike(a, "ram", 30.0)
	var hp_b_after_second: float = b.hp
	_t.check("Tally keeps live canon one-shot circuit arc (max(8, 0.6*force)*chain, spent after first hit)",
		hp_b_after_first < hp_b_before and is_equal_approx(hp_b_after_second, hp_b_after_first)
		and bool(_combat.tally_kit.link_group.get("spent", false)),
		"b %.1f -> %.1f -> %.1f spent=%s" % [hp_b_before, hp_b_after_first, hp_b_after_second, str(_combat.tally_kit.link_group.get("spent"))])


# --- 4. HYGIENE, TERMINOLOGY & CLEAN RESETS -------------------------------------------

func _test_hygiene_and_resets() -> void:
	# Zero external hero names across ClassDef player-facing strings.
	var ow_banned := ["Rein" + "hardt", "Doom" + "fist", "Bast" + "ion", "Rama" + "ttra", "Zen" + "yatta", "Som" + "bra",
		"Han" + "zo", "Pha" + "rah", "Tra" + "cer", "Cass" + "idy", "Sold" + "ier:76", "Sold" + "ier 76", "Wreck" + "ing Ball"]
	var ow_hits: Array = []
	for def in ClassDef.all():
		var blob := "%s %s %s %s" % [def.display_name, def.role, def.pitch, String(def.unlock.get("label", ""))]
		for name in ow_banned:
			if blob.findn(name) != -1:
				ow_hits.append("%s:%s" % [def.id, name])
	_t.eq("Zero external hero names in ClassDef player-facing cards", ow_hits, [])

	# Zero disallowed space-strike term across Tarn, Cannon, Ultimate, Weapons, WeaponDriver, Combat, Destructibles.
	# W50-ISAAC-PARTS added scrap-flywheel OrbitalSatellites (`orbitals`) to combat.gd, so combat.gd checks
	# space-strike phrases specifically while Cannon/Tarn/Weapons/Ultimate/Destructibles stay strictly clean.
	var orb_word := "orb" + "ital"
	var orb_files := [
		"res://src/combat/tarn_claw.gd",
		"res://src/combat/weapons.gd",
		"res://src/combat/weapon_driver.gd",
		"res://src/combat/ultimate.gd",
		"res://src/world/destructibles.gd",
		"res://src/combat/hero_hooks.gd",
		"res://src/combat/consumable_runtime.gd",
		"res://src/combat/tally_kit.gd",
		"res://src/combat/cannon_kit.gd",
		"res://src/combat/grapple_mutations.gd",
	]
	var orb_hits: Array = []
	for path in orb_files:
		var src := SourceScan.text(_t, path)
		if src == "" or src.findn(orb_word) != -1:
			orb_hits.append(path)
	for path in ["res://src/combat/combat.gd", "res://src/combat/micro_mutations.gd"]:
		var phrase_src := SourceScan.text(_t, path)
		for phrase in [orb_word + " strike", orb_word + " laser", orb_word + " beam", orb_word + " cannon"]:
			if phrase_src == "" or phrase_src.findn(phrase) != -1:
				orb_hits.append(path + ":" + phrase)
	_t.eq("Zero disallowed space-strike terminology in Tarn/Cannon/Combat/Destructibles source", orb_hits, [])

	# Purely mechanical worn-steel articulated claw in Tarn's claw module (Call #4).
	var tarn_src := SourceScan.text(_t, "res://src/combat/tarn_claw.gd")
	var em_word := "electro" + "magnet"
	var has_em := tarn_src.findn(em_word) != -1
	_t.eq("TarnClaw stays purely mechanical worn-steel articulated claw (Call #4)", has_em, false)

	# Cannon uses "its" (never she/her) in new W47-H2 Cannon code/comments.
	var cannon_bad_pronoun := false
	for path in ["res://src/combat/weapons.gd", "res://src/combat/ultimate.gd", "res://src/world/destructibles.gd"]:
		for line in SourceScan.text(_t, path).split("\n"):
			if line.findn("cannon") != -1 and (line.findn(" she ") != -1 or line.findn(" her ") != -1):
				cannon_bad_pronoun = true
	_t.eq("Cannon strictly uses its (never she/her)", cannon_bad_pronoun, false)

	# Clean reset clears all W47-H2 runtime state (TarnClaw + Combat).
	_combat._reset_w47_h2_state()
	_t.check("W47-H2 state resets cleanly with zero residue",
		not _combat.cannon.cannon_recoil_airborne()
		and _combat.cannon.cannon_piton_state().is_empty()
		and _combat.cannon.last_cannon_piton.is_empty()
		and _combat.cannon.last_cannon_recoil_reset.is_empty()
		and _claw.seized.is_empty()
		and _claw.clamp_hurls.is_empty()
		and _claw.beat3_lunge.is_empty()
		and _claw.pendulum_guard.is_empty())
