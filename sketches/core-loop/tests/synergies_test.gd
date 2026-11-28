extends SceneTree

# W47-C2: six cross-system build-blossoming synergies (NORTHSTAR §4.4, REBASELINE §7).
# Checks table admission, activation matrix (incl. single-part negative control), live combat &
# bolt behaviour with planted controls, proc depth 1 (zero recursive loops), and attempt-boundary
# & death cleanup:
# 1. Demolition Derby   (Mass/Heft + Speed)
# 2. Pendulum Tesla     (Anchor/Grapple + Arc/Chain)
# 3. Ricochet Canyon    (Bounce + Split)
# 4. Thermobaric Dunk   (Heat + Smash/Kinetic)
# 5. Gravity Ledger     (Pull + Mass)
# 6. Catalyst Cartridge (Consumable + Active)

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Parts := preload("res://src/build/parts.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const T := preload("res://tests/support/t.gd")

const SIX := [
	"demolition_derby",
	"pendulum_tesla",
	"ricochet_canyon",
	"thermobaric_dunk",
	"gravity_ledger",
	"catalyst_cartridge",
]

var _t := T.new("synergies_test")
var _game
var _combat
var _player
var _build
var _source := Intent.Scripted.new()
var _slams_seen := 0
var _shatters_seen := 0
var _active_fires_seen := 0


func _initialize() -> void:
	_check_table_and_activation()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _sim(ticks: int) -> void:
	for _i in ticks:
		await physics_frame


func _set_parts(list: Array) -> void:
	_game.ctx.run.parts.assign(list)
	_build.effects.refresh(_game.ctx.run.parts)
	_combat._rebuild_patterns()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1) # Rivet
	await _sim(6)
	_combat = _game.ctx.spawner
	_build = _game.ctx.build
	_game.ctx.events.slammed.connect(func(_at: Vector3, _s: float, _f: float): _slams_seen += 1)
	_game.ctx.events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "piece_shattered":
			_shatters_seen += 1)
	_game.ctx.events.active_fired.connect(func(_id: String, _at: Vector3, _c: int): _active_fires_seen += 1)

	await _check_demolition_derby()
	await _check_pendulum_tesla()
	await _check_ricochet_canyon()
	await _check_thermobaric_dunk()
	await _check_gravity_ledger()
	await _check_catalyst_cartridge()
	await _check_attempt_and_death_cleanup()

	_game.free()
	quit(_t.verdict())


func _part_info(part_id: String) -> Dictionary:
	var d: Resource = Parts.def(part_id)
	return {} if d == null else {"tags": d.tags, "bits": d.bits}


func _check_table_and_activation() -> void:
	var problems := Synergies.cross_system_problems()
	_t.check("cross_system_problems", problems.is_empty(), "problems=%s" % [problems])
	_t.check("cross_system_count", Synergies.CROSS_SYSTEM.size() == 6, "size=%d" % Synergies.CROSS_SYSTEM.size())
	_t.check("maker_rows_untouched", Synergies.ROWS.size() == 14, "maker_rows=%d" % Synergies.ROWS.size())
	for id in SIX:
		_t.check("has_row_%s" % id, not Synergies.cross_system_row(id).is_empty(), id)
	var info := Callable(self, "_part_info")
	# Single multi-tag part alone must NOT wake a cross-system synergy.
	_t.check("single_part_cannot_solo",
		not Synergies.cross_system_awake("pendulum_tesla", ["pylon_capacitor"], info, {}),
		"pylon_capacitor alone")
	# Distinct part pairs wake their matching cross-system synergies.
	_t.check("wake_demolition_derby",
		Synergies.cross_system_awake("demolition_derby", ["rivet_plating", "tread_plating"], info, {}),
		"mass+speed")
	_t.check("wake_pendulum_tesla",
		Synergies.cross_system_awake("pendulum_tesla", ["long_spool", "arc_coil"], info, {}),
		"anchor+arc")
	_t.check("wake_ricochet_canyon",
		Synergies.cross_system_awake("ricochet_canyon", ["chain_arc", "cross_split"], info, {}),
		"bounce+split")
	_t.check("wake_thermobaric_dunk",
		Synergies.cross_system_awake("thermobaric_dunk", ["arc_coil", "hot_rivets"], info, {}),
		"heat+kinetic")
	_t.check("wake_gravity_ledger",
		Synergies.cross_system_awake("gravity_ledger", ["long_spool", "rivet_plating"], info, {}),
		"pull+mass")
	_t.check("wake_catalyst_cartridge",
		Synergies.cross_system_awake("catalyst_cartridge", [], info, {"has_consumable": true, "has_active": true}),
		"consumable+active")
	_t.check("catalyst_needs_both",
		not Synergies.cross_system_awake("catalyst_cartridge", [], info, {"has_consumable": true, "has_active": false}),
		"missing active")


func _check_demolition_derby() -> void:
	_combat._start_attempt()
	var origin: Vector3 = _player.ball_position()
	var near_e: Node3D = _combat.spawn_enemy("chaser", origin + Vector3(8.0, 0.0, 0.0))
	var far_e: Node3D = _combat.spawn_enemy("chaser", origin + Vector3(16.0, 0.0, 0.0))
	var near_hp0: float = near_e.hp
	var far_hp0: float = far_e.hp

	# Control without synergy: piece_shattered deals no shockwave and does not refill boost.
	_set_parts(["rivet_plating"])
	_player.state.boost_cooldown = 2.0
	_shatters_seen = 0
	_game.ctx.events.world_fact.emit("piece_shattered", origin)
	_t.check("derby_control_no_shockwave",
		is_equal_approx(near_e.hp, near_hp0) and is_equal_approx(_player.state.boost_cooldown, 2.0),
		"near_hp=%.1f cd=%.2f" % [near_e.hp, _player.state.boost_cooldown])

	# With Demolition Derby (Mass + Speed): 12 m shockwave hits near, misses far, refills boost, depth 1.
	_set_parts(["rivet_plating", "tread_plating"])
	_player.state.boost_cooldown = 2.5
	_player.abilities.spend(AbilityState.MOVEMENT)
	_shatters_seen = 0
	_game.ctx.events.world_fact.emit("piece_shattered", origin)
	_t.check("derby_hits_within_12m", near_e.hp < near_hp0, "hp %.1f -> %.1f" % [near_hp0, near_e.hp])
	_t.check("derby_misses_past_12m", is_equal_approx(far_e.hp, far_hp0), "far_hp %.1f -> %.1f" % [far_hp0, far_e.hp])
	_t.check("derby_refills_boost", is_equal_approx(_player.state.boost_cooldown, 0.0),
		"boost_cd=%.2f" % _player.state.boost_cooldown)
	_t.check("derby_no_recursive_shatter", _shatters_seen == 1, "shatters=%d" % _shatters_seen)


func _check_pendulum_tesla() -> void:
	_combat._start_attempt()
	var origin: Vector3 = _player.ball_position()
	var mid_e: Node3D = _combat.spawn_enemy("chaser", origin + Vector3(5.0, 0.0, 0.0))
	var hp0: float = mid_e.hp

	# Control without synergy: hooked cable does not zap enemy.
	_set_parts(["long_spool"])
	_player.kit.hooked = true
	_player.kit.anchor = origin + Vector3(10.0, 0.0, 0.0)
	_combat._step_pendulum_tesla([mid_e])
	_t.check("tesla_control_no_zap", is_equal_approx(mid_e.hp, hp0), "hp=%.1f" % mid_e.hp)

	# With Pendulum Tesla (Anchor + Arc): cable zaps swept enemy once & charges Special +15%.
	_set_parts(["long_spool", "arc_coil"])
	_player.abilities.spend(AbilityState.SPECIAL)
	var sp_before: float = _player.abilities.slot(AbilityState.SPECIAL).recharge
	var sp_full: float = _player.abilities.cooldown_of(AbilityState.SPECIAL)
	_combat._step_pendulum_tesla([mid_e])
	var hp1: float = mid_e.hp
	var sp_after: float = _player.abilities.slot(AbilityState.SPECIAL).recharge
	_t.check("tesla_zaps_swept_enemy", hp1 < hp0, "hp %.1f -> %.1f" % [hp0, hp1])
	_t.check("tesla_charges_special_15pct", is_equal_approx(sp_after - sp_before, sp_full * 0.15),
		"sp_before=%.3f sp_after=%.3f full=%.3f" % [sp_before, sp_after, sp_full])
	# Second tick on same swing does NOT zap same enemy again or double-charge Special.
	_combat._step_pendulum_tesla([mid_e])
	_t.check("tesla_once_per_swing", is_equal_approx(mid_e.hp, hp1) and is_equal_approx(_player.abilities.slot(AbilityState.SPECIAL).recharge, sp_after),
		"hp=%.1f sp=%.3f" % [mid_e.hp, _player.abilities.slot(AbilityState.SPECIAL).recharge])
	_player.kit.hooked = false
	_game.ctx.events.grapple_released.emit()


func _check_ricochet_canyon() -> void:
	_combat._start_attempt()
	_set_parts(["chain_arc", "cross_split"])

	# Firing while NOT wall-carving: zero extra_bounces.
	_player.state.carving = false
	_combat.bolts.clear()
	_combat._fire(_combat.active_weapon(), "weapon")
	var plain_bolt: Dictionary = _combat.bolts._bolts[0] if not _combat.bolts._bolts.is_empty() else {}
	_t.check("ricochet_requires_carving", int(plain_bolt.get("extra_bounces", 0)) == 0,
		"extra=%d" % int(plain_bolt.get("extra_bounces", 0)))

	# Firing an item_proc volley while carving: NEVER gains extra_bounces (proc depth 1).
	_player.state.carving = true
	_combat.bolts.clear()
	_combat._fire(_combat.active_weapon(), "item_proc")
	var proc_bolt: Dictionary = _combat.bolts._bolts[0] if not _combat.bolts._bolts.is_empty() else {}
	_t.check("ricochet_proc_carries_none", int(proc_bolt.get("extra_bounces", 0)) == 0 and not bool(proc_bolt.get("ricochet_home", false)),
		"proc_extra=%d" % int(proc_bolt.get("extra_bounces", 0)))

	# Firing weapon while wall-carving: stamps +2 canyon-wall bounces & homing curve.
	_combat.bolts.clear()
	_combat._fire(_combat.active_weapon(), "weapon")
	var rc_bolt: Dictionary = _combat.bolts._bolts[0] if not _combat.bolts._bolts.is_empty() else {}
	_t.check("ricochet_carve_stamps_2_bounces",
		int(rc_bolt.get("extra_bounces", 0)) == 2 and bool(rc_bolt.get("ricochet_home", false)),
		"extra=%d home=%s" % [int(rc_bolt.get("extra_bounces", 0)), rc_bolt.get("ricochet_home", false)])
	_player.state.carving = false

	# Verify Bolts._glance: 1 base bounce + 2 canyon-wall bounces = 3 glances, 4th wall stops (bounded!).
	# Also verify bounced shard curves toward nearest live enemy.
	var target: Node3D = _combat.spawn_enemy("chaser", Vector3(6.0, 0.0, 6.0))
	var snap := [{"enemy": target, "id": target.get_instance_id(), "centre": target.global_position, "dead": false}]
	var test_bolt := {
		"origin": Vector3.ZERO, "dir": Vector3(0.0, 0.0, 1.0), "speed": 50.0, "max_dist": 100.0,
		"damage": 10.0, "color": Color.WHITE, "bits": ShotBits.bit("bounce") | ShotBits.bit("split"), "spent": 0,
		"extra_bounces": 2, "ricochet_home": true, "ricochet_home_reach": 26.0, "ricochet_home_turn": 0.75,
		"exclude": [],
	}
	var b1: bool = _combat.bolts._glance(test_bolt, Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -1.0), 10.0, snap)
	var curved_after_b1: bool = bool(test_bolt.get("ricochet_curved", false))
	var dir_to_target := (target.global_position - Vector3(0.0, 0.0, 9.95)).normalized()
	var aligned: float = (test_bolt["dir"] as Vector3).dot(dir_to_target)
	var b2: bool = _combat.bolts._glance(test_bolt, Vector3(5.0, 0.0, 5.0), Vector3(-1.0, 0.0, 0.0), 10.0, [])
	var b3: bool = _combat.bolts._glance(test_bolt, Vector3(0.0, 0.0, 2.0), Vector3(1.0, 0.0, 0.0), 10.0, [])
	var b4: bool = _combat.bolts._glance(test_bolt, Vector3(5.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), 10.0, [])
	_t.check("ricochet_3_bounces_then_stops", b1 and b2 and b3 and not b4,
		"b1=%s b2=%s b3=%s b4=%s" % [b1, b2, b3, b4])
	_t.check("ricochet_curves_toward_enemy", curved_after_b1 and aligned > 0.85,
		"curved=%s dot=%.3f" % [curved_after_b1, aligned])
	# Split children stay bounded and keep split+pull spent.
	var kids := Bolts.split_children(rc_bolt, Vector3.ZERO, 999, 2.0)
	_t.check("ricochet_split_children_bounded",
		kids.is_empty() or (int(kids[0].get("extra_bounces", 0)) <= Bolts.MAX_EXTRA_BOUNCES and not Bolts.bit_ready(kids[0], "split")),
		"kids=%d" % kids.size())


func _check_thermobaric_dunk() -> void:
	_combat._start_attempt()
	var origin: Vector3 = _player.ball_position()
	var e1: Node3D = _combat.spawn_enemy("chaser", origin + Vector3(3.0, 0.0, 0.0))
	var e2: Node3D = _combat.spawn_enemy("chaser", origin + Vector3(5.0, 0.0, 0.0))

	# Control: slamming UNHEATED enemy with synergy active launches zero pins.
	_set_parts(["arc_coil", "hot_rivets"])
	_slams_seen = 0
	_game.ctx.events.slammed.emit(origin + Vector3(3.0, 0.0, 0.0), 1.0, 1.0)
	_t.check("thermobaric_control_unheated", _combat._thermobaric_pins.is_empty(),
		"pins=%d" % _combat._thermobaric_pins.size())

	# Heat e1, then slam: launches nearby enemies skyward as flaming pins.
	_combat.apply_heat(e1, e1.global_position)
	_t.check("thermobaric_enemy_heated", _combat.heated(e1), "heated=%s" % _combat.heated(e1))
	_slams_seen = 0
	_game.ctx.events.slammed.emit(origin + Vector3(3.0, 0.0, 0.0), 1.0, 1.0)
	_t.check("thermobaric_launches_pins", _combat._thermobaric_pins.size() >= 2,
		"pins=%d" % _combat._thermobaric_pins.size())

	# Advance past pin impact timeout so pins detonate once without emitting recursive slams.
	var hp2_before: float = e2.hp
	_combat._clock += 2.0
	_combat._step_thermobaric_pins([e1, e2])
	_t.check("thermobaric_detonates_once",
		_combat._thermobaric_pins.is_empty() and e2.hp < hp2_before and _slams_seen == 1,
		"pins_left=%d hp2 %.1f->%.1f slams=%d" % [_combat._thermobaric_pins.size(), hp2_before, e2.hp, _slams_seen])


func _check_gravity_ledger() -> void:
	_combat._start_attempt()
	var origin: Vector3 = _player.ball_position()
	var e1: Node3D = _combat.spawn_enemy("chaser", origin + Vector3(4.0, 0.0, 0.0))
	var e2: Node3D = _combat.spawn_enemy("chaser", origin + Vector3(5.5, 0.0, 0.0))

	# Control: pulling only 1 enemy does not trigger Gravity Ledger crush or cog shower.
	_set_parts(["long_spool", "rivet_plating"])
	var cogs0: int = _build.scrap.cog_count()
	var hp1_0: float = e1.hp
	_combat._check_gravity_ledger(origin + Vector3(4.0, 0.0, 0.0), [e1])
	_t.check("gravity_control_single_enemy",
		is_equal_approx(e1.hp, hp1_0) and _build.scrap.cog_count() == cogs0,
		"hp=%.1f cogs=%d" % [e1.hp, _build.scrap.cog_count()])

	# Pulling 2+ enemies together crushes them for bonus damage and drops a guaranteed cog shower.
	var hp2_0: float = e2.hp
	_combat._check_gravity_ledger(origin + Vector3(4.5, 0.0, 0.0), [e1, e2])
	var cogs1: int = _build.scrap.cog_count()
	_t.check("gravity_crushes_pair", e1.hp < hp1_0 and e2.hp < hp2_0,
		"e1 %.1f->%.1f e2 %.1f->%.1f" % [hp1_0, e1.hp, hp2_0, e2.hp])
	_t.check("gravity_drops_cog_shower", cogs1 >= cogs0 + 3, "cogs %d -> %d" % [cogs0, cogs1])


func _check_catalyst_cartridge() -> void:
	_combat._start_attempt()
	# Control: no active racked returns {}.
	_combat.actives.reset()
	var ctrl_res: Dictionary = _combat.on_consumable_used("oil_can")
	_t.check("catalyst_control_no_active", ctrl_res.is_empty(), "res=%s" % [ctrl_res])

	# With an active racked at 0 charges, 0.0 progress: popping consumable grants +40% charge & free visual ring.
	var first_active: String = String(_combat.actives.rows().keys()[0])
	_combat.actives.rack(first_active, false)
	_combat.actives.charges = 0
	_combat.actives.progress = 0.0
	_active_fires_seen = 0
	var res: Dictionary = _combat.on_consumable_used("oil_can", _player.ball_position())
	_t.check("catalyst_grants_40pct_charge",
		bool(res.get("fired", false)) and is_equal_approx(_combat.actives.progress, 0.40),
		"res=%s progress=%.3f" % [res, _combat.actives.progress])
	_t.check("catalyst_free_ring_no_recursive_active",
		_combat.actives.fires == 0 and _active_fires_seen == 0,
		"fires=%d active_fired_events=%d" % [_combat.actives.fires, _active_fires_seen])
	# Popping again at 0.70 wraps cleanly into +1 charge + 0.10 progress.
	_combat.actives.progress = 0.70
	_combat.on_consumable_used("oil_can", _player.ball_position())
	_t.check("catalyst_wraps_into_charge",
		_combat.actives.charges == 1 and is_equal_approx(_combat.actives.progress, 0.10),
		"charges=%d progress=%.3f" % [_combat.actives.charges, _combat.actives.progress])


func _check_attempt_and_death_cleanup() -> void:
	_combat._start_attempt()
	var origin: Vector3 = _player.ball_position()
	var e: Node3D = _combat.spawn_enemy("chaser", origin + Vector3(3.0, 0.0, 0.0))
	_set_parts(["arc_coil", "hot_rivets", "long_spool", "rivet_plating"])
	_combat.apply_heat(e, e.global_position)
	_game.ctx.events.slammed.emit(origin + Vector3(3.0, 0.0, 0.0), 1.0, 1.0)
	_t.check("cleanup_had_pin", not _combat._thermobaric_pins.is_empty(), "pins=%d" % _combat._thermobaric_pins.size())
	_combat._on_player_died()
	_t.check("death_clears_pins", _combat._thermobaric_pins.is_empty(), "pins=%d" % _combat._thermobaric_pins.size())
	_combat._pendulum_zapped[123] = true
	_combat._pulled_recent[123] = _combat._clock
	_combat._start_attempt()
	_t.check("attempt_clears_cross_state",
		_combat._pendulum_zapped.is_empty() and _combat._pulled_recent.is_empty(),
		"zapped=%d pulled=%d" % [_combat._pendulum_zapped.size(), _combat._pulled_recent.size()])
