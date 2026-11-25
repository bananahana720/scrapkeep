extends SceneTree

# W47-H1 Hero Baselines Part 1 (Sable, Rivet, Kest):
# - Sable: Kinetic Orbit Pylon (mint Palette.ARC arcs only while moving at speed — zero camping!)
#   and Vault-Kick instant max-charge (0.0 s charge time on next arc_caster bolt).
# - Rivet (he/his): Active-reloaded 6th hot round ricochets once off canyon rock or armor toward
#   nearest enemy/weak point with metallic KLANG-PING + copper/amber tracer (never Palette.HAZARD),
#   and existing map rail/zip/pipe/canal-lip/trestle riding via line_drive Haul & overdrive_sprint
#   auto-lock at +20% top speed while firing twin revolvers (strictly G0 single ChainState).
# - Kest: Air-Draw Glide Hang (0.45x gravity for 1.2 s while holding sticky_charge airborne),
#   clean upward vault off cable_charge spire latches, visible amber (Palette.AMBER #E5A044)
#   direct-sightline fuse-spark trace revealing unobstructed weak points & cracked destructible
#   seams with ZERO through-rock wall-hack radar, and baseline high wall-kick boost.
# - Zero Overwatch hero names in player-facing strings.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Palette := preload("res://src/core/palette.gd")
const ChainState := preload("res://src/combat/chain.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const HeroFx := preload("res://src/presentation/hero_fx.gd")
const T := preload("res://tests/support/t.gd")

const DT := 1.0 / 60.0
const EXPECTED_CHECKS := 41

var _t := T.new("w47_h1_heroes_test")
var _game
var _player
var _combat
var _kit_rivet
var _source := Intent.Scripted.new()
var _temp_nodes: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _never() -> bool:
	return false


func _make_box_wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	wall.add_child(cs)
	_game.add_child(wall)
	wall.global_position = at
	_temp_nodes.append(wall)
	return wall


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


func _switch_pilot(class_id: String, at: Vector3) -> void:
	_clear_temp()
	_combat._reset_w47_h1_state()
	_combat.bolts.clear()
	_combat.sticky.clear()
	var def: Resource = ClassDef.by_id(class_id)
	_game.run.class_def = def
	_player.fit_class(def)
	_combat._rebuild_patterns()
	_combat.weapon_driver.reset(_combat.pattern(def.weapon_id))
	_player.body().freeze = true
	_player.reset_to(at, Vector3.ZERO)
	_player.drive_basis = Basis.looking_at(Vector3.FORWARD)
	_player.intent.clear()
	if _kit_rivet != null:
		_kit_rivet._clear()


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
	_kit_rivet = _combat.get_node("RivetKit")
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_kit_rivet.set_physics_process(false)
	_combat.ultimate.set_physics_process(false)

	await _test_sable()
	await _test_rivet()
	await _test_kest()
	_test_hygiene_and_resets()

	_clear_temp()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	quit(_t.verdict())


# --- 1. SABLE -------------------------------------------------------------------------

func _test_sable() -> void:
	var base_pt := Vector3(-120.0, 140.0, -120.0)
	_switch_pilot("pylon_engineer", base_pt)
	await physics_frame

	# 1a. Vault-Kick grants instant max-charge (0.0 s charge time) on next arc_caster bolt.
	var pat: Resource = _combat.pattern(Weapons.ARC_CASTER)
	_combat.weapon_driver.reset(pat)
	var before_snap: Dictionary = _combat.weapon_driver.state_snapshot()
	_t.eq("Sable starts without instant charge", bool(before_snap["instant_charge"]), false)
	_game.events.vault_kicked.emit(base_pt + Vector3.RIGHT * 2.0, 26.0)
	var armed_snap: Dictionary = _combat.weapon_driver.state_snapshot()
	_t.check("Vault-Kick arms instant max-charge on WeaponDriver", bool(armed_snap["instant_charge"]) and float(armed_snap["instant_charge_left"]) > 3.5)
	var intent := Intent.new()
	intent.fire_pressed = true
	var shots: Array = _combat.weapon_driver.step(DT, intent, Weapons.ARC_CASTER, pat, float(pat.rate), {"rate_mult": 1.0, "charge_rate": 1.0})
	_t.check("Next arc_caster press fires instant max-charge SHOT_CHARGED at 0.0 s hold",
		shots.size() == 1 and String(shots[0]["kind"]) == WeaponDriver.SHOT_CHARGED
		and is_equal_approx(float(shots[0]["charge"]), 1.0) and bool(shots[0]["instant_charge"]), str(shots))
	_t.eq("Instant charge consumes cleanly after one bolt", bool(_combat.weapon_driver.state_snapshot()["instant_charge"]), false)

	# 1b. Kinetic Orbit Pylon: zero camping (mounted or stationary fires ZERO kinetic arcs).
	var enemy := _spawn_dummy(base_pt + Vector3(8.0, 0.0, 0.0), "chaser", 1000.0)
	_combat._on_mounted(base_pt, 20.0)
	var pstate: Dictionary = _combat.kinetic_pylon_state()
	_t.check("Planting pylon registers beachhead pylon", not pstate.is_empty() and (pstate["at"] as Vector3).is_equal_approx(base_pt))
	_player.kit.mounted = true
	_player.state.velocity = Vector3.ZERO
	var hp_before: float = enemy.hp
	for i in 45:
		_combat._step_kinetic_pylon(DT, [enemy])
	_t.near("Zero camping: mounted stationary Sable fires zero kinetic-orbit arcs", hp_before - enemy.hp, 0.0, 0.001)

	# 1c. Dismount / vault-kick off pylon + orbiting at speed overcharges mint Palette.ARC arcs!
	_player.kit.mounted = false
	_player.state.velocity = Vector3(24.0, 0.0, 0.0)
	_player.state.refresh_tier(_player.tuning.f("cruise"))
	_game.events.vault_kicked.emit(base_pt + Vector3(2.0, 0.0, 0.0), 28.0)
	_t.check("Vault-kicking near beachhead pylon overcharges it", float(_combat.kinetic_pylon_state().get("overcharge_left", 0.0)) >= Weapons.KINETIC_PYLON_OVERCHARGE_S - 0.1)
	_combat._step_kinetic_pylon(DT, [enemy])
	_t.check("Overcharged pylon fires automatic mint Palette.ARC arcs while moving at speed",
		enemy.hp < hp_before and not _combat.last_kinetic_arc.is_empty() and _combat.last_kinetic_arc["color"] == Palette.ARC,
		str(_combat.last_kinetic_arc))

	# 1d. Orbiting around beachhead pylon at speed overcharges even without vault-kick.
	_combat._plant_beachhead_pylon(base_pt)
	_t.near("Fresh beachhead starts un-overcharged", float(_combat.kinetic_pylon_state().get("overcharge_left", -1.0)), 0.0, 0.001)
	for step_i in 12:
		var ang := float(step_i) * 0.14
		var pos := base_pt + Vector3(cos(ang) * 8.0, 0.0, sin(ang) * 8.0)
		_player.reset_to(pos, Vector3(-sin(ang), 0.0, cos(ang)) * 22.0)
		_player.state.refresh_tier(_player.tuning.f("cruise"))
		_combat._step_kinetic_pylon(DT, [enemy])
	_t.check("Orbiting beachhead pylon at speed triggers kinetic overcharge",
		float(_combat.kinetic_pylon_state().get("overcharge_left", 0.0)) > 0.0
		and String(_combat.kinetic_pylon_state().get("reason", "")) == "orbit",
		str(_combat.kinetic_pylon_state()))

	# 1e. Stopping mid-overcharge pauses automatic kinetic-orbit arcs (zero camping!).
	var arcs_before := int(_combat.kinetic_pylon_state().get("arcs_fired", 0))
	_player.state.velocity = Vector3.ZERO
	_player.state.refresh_tier(_player.tuning.f("cruise"))
	for i in 45:
		_combat._step_kinetic_pylon(DT, [enemy])
	_t.eq("Stopping mid-overcharge pauses kinetic-orbit arcs (zero camping)", int(_combat.kinetic_pylon_state().get("arcs_fired", 0)), arcs_before)


# --- 2. RIVET (he/his) ----------------------------------------------------------------

func _test_rivet() -> void:
	var base_pt := Vector3(-160.0, 140.0, -160.0)
	_switch_pilot("runner_gunner", base_pt)
	await physics_frame

	# 2a. WeaponDriver marks ONLY the 6th active-reloaded hot round as sixth_hot.
	var pat: Resource = _combat.pattern(Weapons.RAPID_LASER)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	# Empty 6 plain rounds -> enter reload.
	var plain_sixth := false
	for i in 6:
		var pi := Intent.new()
		pi.fire_pressed = true
		var s := drv.step(0.25, pi, Weapons.RAPID_LASER, pat, float(pat.rate), {"rate_mult": 1.0})
		if not s.is_empty() and bool(s[0].get("sixth_hot", false)):
			plain_sixth = true
	_t.eq("Plain 6th round never flags sixth_hot", plain_sixth, false)
	# Hit active reload window [0.38, 0.54] s -> fires hot round #1 of 6.
	drv.step(0.42, Intent.new(), Weapons.RAPID_LASER, pat, float(pat.rate), {"rate_mult": 1.0})
	var reload_press := Intent.new()
	reload_press.fire_pressed = true
	var hot1 := drv.step(DT, reload_press, Weapons.RAPID_LASER, pat, float(pat.rate), {"rate_mult": 1.0})
	_t.check("Active reload fires hot round 1 (not sixth_hot)", hot1.size() == 1 and bool(hot1[0]["hot"]) and not bool(hot1[0]["sixth_hot"]))
	var sixth_flags: Array = []
	for i in 5:
		var fi := Intent.new()
		fi.fire_pressed = true
		var s := drv.step(0.25, fi, Weapons.RAPID_LASER, pat, float(pat.rate), {"rate_mult": 1.0})
		sixth_flags.append(bool(s[0].get("sixth_hot", false)) if not s.is_empty() else false)
	_t.eq("Active-reloaded cylinder flags ONLY the 6th hot round", sixth_flags, [false, false, false, false, true])

	# 2b. Southwest Ricochet 6th hot round off canyon rock toward nearest enemy/weak point (strictly once + KLANG-PING + copper/amber tracer).
	var rock_wall := _make_box_wall(base_pt + Vector3(12.0, 0.0, 0.0), Vector3(1.0, 12.0, 14.0))
	var rock_target := _spawn_dummy(base_pt + Vector3(6.0, 0.0, 8.0), "chaser", 500.0)
	await physics_frame
	await physics_frame
	var audio = _game.presentation.audio
	audio.bake_now()
	var cue_start: int = audio.cue_log_total
	_combat.last_ricochet = {}
	var hp_rock_before: float = rock_target.hp
	var bolt_rock := {
		"origin": base_pt, "fired_from": base_pt, "dir": Vector3.RIGHT, "speed": 190.0, "max_dist": 60.0,
		"damage": 14.4, "kind": "runner", "weapon_id": Weapons.RAPID_LASER, "radius": 0.3,
		"knock": 4.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.7,
		"lattice_chain_falloff": 0.0, "color": Palette.COPPER, "wave_amp": 0.0, "wave_hz": 0.0,
		"phase": 0.0, "pierce": 0, "source": "weapon", "bits": 0,
	}
	_combat._stamp_rivet_sixth_hot(bolt_rock)
	_combat.bolts.fire(bolt_rock)
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	for step_i in 20:
		_combat.bolts.step(DT, space, [rock_target], [])
	var rock_cues: Array = audio.cues_since(cue_start)
	_t.check("6th hot round ricochets off canyon rock into target", rock_target.hp < hp_rock_before and String(_combat.last_ricochet.get("surface", "")) == "rock",
		"hp %.1f->%.1f ric=%s" % [hp_rock_before, rock_target.hp, str(_combat.last_ricochet)])
	_t.check("Rock ricochet uses copper/amber tracer (NEVER Palette.HAZARD)",
		_combat.last_ricochet.get("color") == Palette.COPPER and _combat.last_ricochet.get("accent") == Palette.AMBER
		and _combat.last_ricochet.get("color") != Palette.HAZARD and _combat.last_ricochet.get("accent") != Palette.HAZARD)
	_t.check("Rock ricochet plays metallic KLANG-PING cues",
		rock_cues.any(func(c): return c[1] == "clank") and rock_cues.any(func(c): return c[1] == "crit_ping"), str(rock_cues))
	rock_wall.free()

	# 2c. 6th hot round ricochets once off armor toward nearest other enemy (never loops).
	var armor_a := _spawn_dummy(base_pt + Vector3(0.0, 0.0, -10.0), "plated_brute", 1000.0)
	var armor_b := _spawn_dummy(base_pt + Vector3(8.0, 0.0, -12.0), "chaser", 500.0)
	await physics_frame
	_combat.last_ricochet = {}
	var hp_b_before: float = armor_b.hp
	var bolt_armor := {
		"origin": base_pt, "fired_from": base_pt, "dir": Vector3.FORWARD, "speed": 190.0, "max_dist": 50.0,
		"damage": 14.4, "kind": "runner", "weapon_id": Weapons.RAPID_LASER, "radius": 0.4,
		"knock": 4.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.7,
		"lattice_chain_falloff": 0.0, "color": Palette.COPPER, "wave_amp": 0.0, "wave_hz": 0.0,
		"phase": 0.0, "pierce": 0, "source": "weapon", "bits": 0,
	}
	_combat._stamp_rivet_sixth_hot(bolt_armor)
	_combat.bolts.fire(bolt_armor)
	for step_i in 25:
		_combat.bolts.step(DT, space, [armor_a, armor_b], [])
	_t.check("6th hot round ricochets once off armor into nearest other enemy",
		armor_b.hp < hp_b_before and String(_combat.last_ricochet.get("surface", "")) == "armor",
		"hp_b %.1f->%.1f ric=%s" % [hp_b_before, armor_b.hp, str(_combat.last_ricochet)])

	# 2d. Existing map rail/zip extraction from real park_dam & park_flume (pipes, canal lips, zip cables, trestle rails).
	var dam_map := ParkMap.new("res://src/world/park/park_dam.json")
	var dam_rails := RideRail.extract_map_rails(dam_map)
	var dam_kinds := dam_rails.map(func(r): return String(r["kind"]))
	_t.check("park_dam exposes existing zip cables, pipes, canal lips, and rails",
		dam_kinds.has("zip") and dam_kinds.has("pipe") and dam_kinds.has("canal_lip") and dam_kinds.has("rail"), str(dam_kinds))
	var flume_map := ParkMap.new("res://src/world/park/park_flume.json")
	var flume_rails := RideRail.extract_map_rails(flume_map)
	_t.check("park_flume exposes existing trestle/flume grind rails",
		flume_rails.any(func(r): return String(r["kind"]) == "trestle"), str(flume_rails.size()))

	# 2e. Rivet rides existing rail via line_drive Haul AND overdrive_sprint auto-lock at +20% top speed while firing twin revolvers (strictly G0).
	var rail_start := base_pt + Vector3(0.0, 0.0, 20.0)
	var rail_end := base_pt + Vector3(40.0, 0.0, 20.0)
	var test_rail := [{"id": "test_canal_lip", "kind": "canal_lip", "from": rail_start, "to": rail_end, "floor": 18.0, "width": 3.0}]
	_kit_rivet.set_extra_rails(test_rail)
	_player.reset_to(rail_start + Vector3(2.0, 0.5, 0.0), Vector3(17.5, 0.0, 0.0))
	_player.kit.sprinting = true
	_kit_rivet.step(DT)
	var sprint_top := float(_player.tuning.f("cruise")) * 1.25
	_t.check("overdrive_sprint auto-locks onto existing canal lip rail",
		not _kit_rivet.rail_ride.is_empty() and String(_kit_rivet.last_rail_ride.get("via", "")) == "sprint"
		and String(_kit_rivet.last_rail_ride.get("kind", "")) == "canal_lip", str(_kit_rivet.last_rail_ride))
	_t.check("Rail grind grants +20% top speed and keeps twin revolvers live",
		float(_kit_rivet.last_rail_ride.get("speed", 0.0)) >= maxf(sprint_top, 18.0) * 1.20 - 0.05
		and bool(_kit_rivet.last_rail_ride.get("allow_fire", false)), str(_kit_rivet.last_rail_ride))
	_t.eq("Strictly G0 single ChainState (zero two-anchor standing rail-line)",
		int(_kit_rivet.last_rail_ride.get("chain_cap", 0)), ChainState.MAX_CHAINS_PER_PILOT)
	# Twin revolvers fire cleanly while grinding!
	var volleys_before: int = _combat.volleys
	_combat._fire(Weapons.RAPID_LASER, "weapon", {"kind": WeaponDriver.SHOT_PLAIN, "damage_mult": 1.0})
	_t.eq("Rivet can fire his twin revolvers while rail-grinding", _combat.volleys, volleys_before + 1)

	# 2f. line_drive Haul onto existing zip cable rides it at +20% speed.
	_kit_rivet._end_rail_ride(false)
	_kit_rivet._rail_regrab_cd = 0.0
	_player.kit.sprinting = false
	var zip_a := base_pt + Vector3(0.0, 4.0, 35.0)
	var zip_b := base_pt + Vector3(45.0, 2.0, 35.0)
	_kit_rivet.set_extra_rails([{"id": "test_zip", "kind": "zip", "from": zip_a, "to": zip_b, "floor": 20.0, "width": 3.5}])
	_player.reset_to(zip_a + Vector3(-4.0, -2.0, 0.0), Vector3(14.0, 0.0, 0.0))
	_player.grapple_to(zip_a + Vector3(1.0, 0.0, 0.0), Vector3.LEFT, null)
	_kit_rivet.on_world(zip_a + Vector3(1.0, 0.0, 0.0), 1.0, 1.0)
	_t.check("line_drive Haul onto existing map zip cable locks into +20% zip grind",
		not _kit_rivet.rail_ride.is_empty() and String(_kit_rivet.last_rail_ride.get("via", "")) == "haul"
		and String(_kit_rivet.last_rail_ride.get("kind", "")) == "zip"
		and float(_kit_rivet.last_rail_ride.get("speed", 0.0)) >= Weapons.LINE_HAUL_SPEED * 1.20 - 0.05,
		str(_kit_rivet.last_rail_ride))
	_kit_rivet._clear()


# --- 3. KEST --------------------------------------------------------------------------

func _test_kest() -> void:
	var base_pt := Vector3(-200.0, 150.0, -200.0)
	_switch_pilot("demolitions_caster", base_pt)
	await physics_frame

	# 3a. Air-Draw Glide Hang: 0.45x gravity for 1.2 s while holding sticky_charge airborne.
	_player.state.grounded = false
	_player.abilities.selected = AbilityState.WEAPON
	_player.intent.fire_held = true
	_player._rigid.external_accel = Vector3.ZERO
	_player._step_kest_air_draw(DT)
	var want_accel := float(_player.tuning.f("gravity")) * (1.0 - Weapons.KEST_AIR_DRAW_GRAVITY)
	_t.check("Air-Draw Glide Hang activates while holding sticky_charge airborne", _player.air_draw_active)
	_t.near("Air-Draw applies 0.45x net gravity counter-accel (0.55g up)", _player._rigid.external_accel.y, want_accel, 0.02)
	# Exhaust 1.2 s budget -> ends cleanly!
	for i in 80:
		_player._rigid.external_accel = Vector3.ZERO
		_player._step_kest_air_draw(DT)
	_t.check("Air-Draw Glide Hang expires cleanly after 1.2 s", not _player.air_draw_active and _player.air_draw_left <= 0.0001)
	_player.intent.fire_held = false

	# 3b. Clean upward vault off cable_charge spire latch feeds Air-Draw Glide Hang.
	_player.state.grounded = false
	_player.state.velocity = Vector3(16.0, -4.0, 0.0)
	var spire_pt := base_pt + Vector3(10.0, 8.0, 0.0)
	_player.grapple_to(spire_pt, Vector3.LEFT, null)
	_combat.ultimate.cable_world(spire_pt, 1.0, 1.0)
	_t.check("cable_charge spire latch launches Kest cleanly upward and refreshes 1.2 s Air-Draw",
		_player.state.velocity.y >= Weapons.KEST_SPIRE_VAULT_UP - 0.01
		and is_equal_approx(_player.air_draw_left, Weapons.KEST_AIR_DRAW_MAX_S)
		and _player.state.velocity.x >= 15.9,
		"vel=%s draw=%.2f" % [str(_player.state.velocity), _player.air_draw_left])
	_combat.ultimate.clear_payloads()

	# 3c. Kest baseline high wall-kick boost off steep canyon wall (player_ball.gd).
	_player.kit.drop_line("reset")
	var canyon_wall := _make_box_wall(base_pt + Vector3(2.0, 0.0, 0.0), Vector3(1.0, 16.0, 16.0))
	await physics_frame
	await physics_frame
	_player.reset_to(base_pt, Vector3(0.0, -2.0, -10.0))
	_player.state.grounded = false
	_player.intent.jump_pressed = true
	_player.state.jump_buffer = 0.1
	_player._step_kest_wall_kick(DT)
	var jump_spd := float(_player.tuning.f("jump_speed"))
	_t.check("Kest baseline high wall-kick launches vertically off steep canyon wall",
		not _player.last_kest_wall_kick.is_empty()
		and _player.state.velocity.y >= jump_spd * Weapons.KEST_WALL_KICK_UP_MULT - 0.05
		and _player.state.velocity.x < -2.0,
		"vel=%s kick=%s" % [str(_player.state.velocity), str(_player.last_kest_wall_kick)])
	canyon_wall.free()

	# 3d. Visible Amber (#E5A044) Fuse-Spark Trace: STRICTLY direct line-of-sight ONLY (ZERO wall-hack!).
	var scan_origin := Vector3(-260.0, 160.0, -260.0)
	var visible_wall := _make_box_wall(scan_origin + Vector3(0.0, 0.0, -18.0), Vector3(16.0, 10.0, 1.0))
	# Occluder spans x in [+2, +14] at z=-6, squarely blocking rays to x=+12 at z=-12/-14 while leaving x<=0 unobstructed.
	var occluder := _make_box_wall(scan_origin + Vector3(8.0, 0.0, -6.0), Vector3(12.0, 12.0, 1.5))
	var visible_enemy := _spawn_dummy(scan_origin + Vector3(-4.0, 0.0, -10.0), "lobber", 500.0)
	var hidden_enemy := _spawn_dummy(scan_origin + Vector3(12.0, 0.0, -14.0), "lobber", 500.0)
	# Also build 2 Heft Destructibles: one directly in sight, one strictly occluded behind occluder!
	var dest := Destructibles.new()
	_game.add_child(dest)
	_temp_nodes.append(dest)
	dest.build([
		{"id": "seam_visible", "tier": 2, "at": [scan_origin.x - 1.0, scan_origin.y, scan_origin.z - 11.0], "size": [2.4, 3.0, 1.2], "yaw_deg": 0.0},
		{"id": "seam_hidden", "tier": 2, "at": [scan_origin.x + 12.0, scan_origin.y, scan_origin.z - 12.0], "size": [2.4, 3.0, 1.2], "yaw_deg": 0.0},
	], {"root": _game, "no_visuals": true})
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var scan := HeroFx.scan_kest_sightline(space, scan_origin, Vector3.FORWARD, [visible_enemy, hidden_enemy], dest, Weapons.KEST_FUSE_TRACE_RANGE)
	var vis_weaks: Array = (scan["weak_points"] as Array).map(func(w): return int(w["enemy_id"]))
	var vis_seams: Array = (scan["destructible_seams"] as Array).map(func(s): return String(s["id"]))
	_t.check("Amber fuse-spark trace runs along directly visible canyon wall surfaces",
		not (scan["wall_traces"] as Array).is_empty() and scan["color"] == Palette.AMBER and scan["color"] != Palette.HAZARD,
		"walls=%d color=%s" % [(scan["wall_traces"] as Array).size(), str(scan["color"])])
	_t.check("Reveals unobstructed enemy weak point AND skips occluded enemy behind rock (ZERO wall-hack)",
		vis_weaks.has(visible_enemy.get_instance_id()) and not vis_weaks.has(hidden_enemy.get_instance_id()),
		"weaks=%s occluded=%d" % [str(vis_weaks), int(scan["occluded_skipped"])])
	_t.check("Reveals unobstructed cracked destructible seam AND skips occluded seam behind rock (ZERO wall-hack)",
		vis_seams.has("seam_visible") and not vis_seams.has("seam_hidden"),
		"seams=%s occluded=%d" % [str(vis_seams), int(scan["occluded_skipped"])])
	_t.check("Occluded targets increment occluded_skipped counter", int(scan["occluded_skipped"]) >= 2, str(scan["occluded_skipped"]))
	# Confirm HeroFx stores amber trace cleanly and clears cleanly.
	var hfx = _game.presentation.vfx.hero_fx
	hfx.set_kest_fuse_trace(scan)
	_t.check("HeroFx draws sightline amber trace without HAZARD",
		int(hfx.snapshot()["kest_trace_walls"]) > 0 and int(hfx.snapshot()["kest_trace_seams"]) == 1)
	hfx.clear_kest_fuse_trace()
	_t.eq("HeroFx clears kest trace cleanly", int(hfx.snapshot()["kest_trace_walls"]), 0)
	visible_wall.free()
	occluder.free()


# --- 4. HYGIENE & RESETS --------------------------------------------------------------

func _test_hygiene_and_resets() -> void:
	# Zero Overwatch hero names across ClassDef player-facing strings.
	var banned := ["Cassidy", "Soldier:76", "Soldier 76", "Hanzo", "Pharah", "Tracer", "Wrecking Ball"]
	var found_ow: Array = []
	for def in ClassDef.all():
		var blob := "%s %s %s %s" % [def.display_name, def.role, def.pitch, String(def.unlock.get("label", ""))]
		for name in banned:
			if blob.findn(name) != -1:
				found_ow.append("%s:%s" % [def.id, name])
	_t.eq("Zero Overwatch hero names in ClassDef player-facing cards", found_ow, [])

	# Rivet pronoun hygiene (he/his, never she/her) in RivetKit & RideRail W47-H1 code.
	var rivet_src := FileAccess.get_file_as_string("res://src/combat/rivet_kit.gd")
	var bad_pronoun := false
	for line in rivet_src.split("\n"):
		if line.findn("rivet") != -1 and (line.findn(" she ") != -1 or line.findn(" her ") != -1):
			bad_pronoun = true
	_t.eq("RivetKit strictly uses he/his (never she/her for Rivet)", bad_pronoun, false)

	# HeroFx never references Palette.HAZARD.
	var hfx_src := FileAccess.get_file_as_string("res://src/presentation/hero_fx.gd")
	var hazard_code_hit := false
	for line in hfx_src.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		if trimmed.find("HAZARD") != -1:
			hazard_code_hit = true
	_t.eq("HeroFx never uses Palette.HAZARD in code", hazard_code_hit, false)

	# Clean reset clears all W47-H1 runtime state.
	_combat._reset_w47_h1_state()
	_t.check("Combat W47-H1 state resets cleanly",
		_combat.kinetic_pylon_state().is_empty() and _combat.last_ricochet.is_empty() and _combat.last_kest_trace.is_empty())
