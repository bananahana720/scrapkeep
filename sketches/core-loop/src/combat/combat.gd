extends Node

const Chaser := preload("res://src/combat/chaser.gd")
const EnemyBase := preload("res://src/combat/enemy.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Warden := preload("res://src/combat/warden.gd")
const Vault := preload("res://src/combat/vault.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Effects := preload("res://src/combat/effects.gd")
const Palette := preload("res://src/core/palette.gd")
const Groups := preload("res://src/core/groups.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Ground := preload("res://src/combat/ground.gd")
const WearTrail := preload("res://src/combat/wear_trail.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Sticky := preload("res://src/combat/sticky.gd")
const Devices := preload("res://src/core/devices.gd")
const NearMiss := preload("res://src/combat/near_miss.gd")
const WayOutPaint := preload("res://src/presentation/way_out_paint.gd")
const Redline := preload("res://src/combat/redline.gd")
const Flail := preload("res://src/combat/flail.gd")
const Augments := preload("res://src/movement/augments.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const KestKit := preload("res://src/combat/kest_kit.gd")
const Sight := preload("res://src/combat/sight.gd")
const Fleet := preload("res://src/combat/fleet.gd")
const Dunk := preload("res://src/combat/dunk.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Roster := preload("res://src/combat/roster.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")
const Companion := preload("res://src/core/companion.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const ChurnGround := preload("res://src/combat/churn_ground.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const BallTuning := preload("res://src/movement/tuning.gd")
const OrbitalSatellites := preload("res://src/combat/orbital_satellites.gd")
const BallRules := preload("res://src/movement/ball_rules.gd")
const AllyHusk := preload("res://src/combat/ally_husk.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const HeroFx := preload("res://src/presentation/hero_fx.gd")
const ActiveBase := preload("res://src/combat/actives/active_base.gd")

const MUZZLE := 1.25
const AIM_SLACK := 14.0
const KINDS := ["chaser", "lobber", "miniboss", "warden", "vault"]
const CONTACT_KINDS := ["stomp", "ram", "slam"]
const ARC_MARK_FRACTION := 0.10
const ARC_MARK_SECONDS := 5.0
const ARC_MARK_KIND := "arc"
const MASS_K_RADIUS := 0.25
const MASS_K_SATURATION := 990.0
const SYNERGY := "synergy"
const DEBRIS := "debris"
const FIGHT_GROUPS := [Groups.ENEMY, Groups.ENEMY_SHOT, "telegraph", "ally_husk", "ally_zone"]
const CHIP := 0.2
const WARDEN_FALLBACK := [
	{"warden_plating": 30.0, "warden_hp": 400.0},
	{"warden_plating": 60.0, "warden_hp": 700.0},
	{"warden_plating": 95.0, "warden_hp": 1000.0},
]
const VAULT_TOP_SCALE := 1.2
const MINIBOSS_PLATING_SCALE := 1.25
const SHELL_RETURN_DAMAGE := 40.0
const BAT_REACH := 2.4
const PARTING_WINDOW := 1.0
const CRUSH_WINDOW := 1.0
const CRUSH_CHAIN := 3
const SHRED_PER_PUNCH := 0.017
const SHRED_HOLD_DECAY := 0.05
const SHRED_REST_DECAY := 1.0
const SHRED_GRACE := 1.5
const SHRED_FLOOR := 0.5
const PROW_SHOVE := 12.0
const PROW_STAGGER := 0.8
const SPRING_WINDOW := 3.0
const SPRING_MULT := 1.5
const RAKE_DELAY := 0.25
const RAKE_DAMAGE := 0.6
const WALK_WINDOW := 2.0
const WALK_REACH := 6.0
const WAKE_DAMAGE := 0.5
const WAKE_MIN_TRAVEL := 1.0
const WAKE_GRACE := 0.5
const PIKE_RADIUS_MULT := 2.0
const PIKE_RING_RADIUS := 1.5
const GRAPESHOT_ANGLE_DEG := 8.0
const GRAPESHOT_KNOCK_SHARE := 0.5
const HOAR_FROST_RADIUS := 2.0
const FAULT_DELAY := 0.45
const FAULT_DAMAGE := 0.5
const FAULT_LAYER := "fault_hammer"

const STRIKE_DAMAGE := {
	"stomp": [30.0, 1.1],
	"ram": [14.0, 1.3],
	"slam": [0.0, 1.2],
}

const RANGE_NEAR_M := 6.0
const RANGE_MID_M := 16.0

var ctx
var fleet
var bolts
var effects
var ground
var volleys := 0
var _pike_count := 0
var _pike_last := -INF
var _strips: Array = []
var _bells: Array = []
var _verb_serial := 0
var _reel_hits := {}
var _reel_frame := -1
var _wake_frame := -1
var last_strip := {}
var last_reel_arc := {}
var last_bell := {}
var last_shot := {}
var last_burst := {}
var heft_override := -1.0
var deflections := 0
var discovered := {}
var discovery_log: Array = []
var _ledger := {}
var _warden_slam_hits := 0
var _boss_add_ids := {}
var _forced_source := ""
var _warden_warned := {}
var stage_defs = null

var _patterns := {}
var _part_map := {}
var weapon_driver := WeaponDriver.new()
var _cooldown: float:
	get:
		return weapon_driver.cooldown_s()
	set(value):
		weapon_driver.set_cooldown_s(value)
var _overdrive := 0.0
var _mounted_boost_left := 0.0
var _last_flight_breaks_props := false
var _last_flight_break_radius := 2.2
var _last_flight_weapon := ""
var _since_slingshot := INF
var _crushes: Array = []
var _clock := 0.0
const REEL_MARK := "panel_reel_at"
const REEL_KILL_WINDOW := 0.25
var _pending := {}
var _shred := {}
var _guards := {}

var _specials := {}
var _special_buffer := 0.0
var _line_buffer := 0.0
var _active_buffer := 0.0
var relic_swaps
var _line_skills := {}
var _line_load := {}
var last_line := {}
var sticky
var devices
var wear_trail
var last_committed := {}
var cloak_left := 0.0
var cloak_at := Vector3.ZERO
var _rocket_left := 0.0
var rocket_cooldown_scale := 1.0
var _pinned := {}
var _hulks: Array = []
var pins := 0
var _proc_ready := {}
var _echo := {}
var _echoing := false
var _marks := {}
var _primed := {}
var _prow_until := {}
var _spring_until := -1.0
signal escape_acted(piece: String, style: String)
var drivers: Dictionary = Companion.DRIVERS
signal companion_assisted(assist: Dictionary)
signal companion_assist_full
signal flung(enemy: Node3D)
var assist_charge := 0.0
var assists := 0
var last_assist := {}
var escape_acts := 0
var escape_lane := {}
var _escape := {}
var _clamped := {}
var _rakes: Array = []
var _aftershocks: Array = []
var _fault_layer_count := 0
var _has_grapeshot := false
var _has_hoar := false
var _has_fault := false
var orbitals
var hero_hooks
var consumables
var _air_steer_surge_left := 0.0
var _air_dash_bat_left := 0.0
var _boost_active_left := 0.0
var _cadence_window_extended := false
var _cadence_extended_weapon := ""
var _prev_window_state := WeaponDriver.WINDOW_IDLE
var _pendulum_zapped := {}
var _pendulum_swing_charged := false
var _pendulum_swing_origin := Vector3.INF
var _thermobaric_pins := {}
var _pulled_recent := {}
var _gravity_ledger_ready_at := -INF
var last_micro_mutation := {}
var last_cross_synergy := {}
var _micro_counts := {}
var _cross_counts := {}
var _hot_wire_cd := {}
var _det_cord_queue: Array = []
var _tether_live := {}
var _live_bus_charged_until := -1.0
var _live_bus_charges := 0
var _tether_slam_armed := {}
var _grapple_mut_counts := {}
var last_grapple_mut := {}
var _active_grapple_slots := {}
const HEAT_GLOW := 2.0
const HEAT_BONUS := 1.15
var _heated := {}
const PULL_KNOCK := 7.0
const PULL_RATIO_CAP := 1.5
const PULL_FALLOFF := 0.6
var _cannon := []
var _cannon_count := 0
var _walk := {}
var _wake := {}
var _exposed := {}
var last_cannon_paint := {}
var bay := 0
var plate := {}
var link_group := {}
var last_card := {}
var _cards := {}
var _arcing := false
var _gather_tick := 0.0
var _roll_clock := 0.0
var _restored_frame := {}
const TALLY_PIECES := ["plate_return", "plate_audit", "plate_flywheel"]
const PUNCH_TAPE_CASTS := 10
const BOOKS_SETTLES := 6
const EYESHADE_SETTLES := 20
var clip_post := {}
var tally_piece := ""
var ride_clips := {}
var tally_last_settle := {}
var _fly_plates: Array = []
var _fly_pulled := false
var _run_settles := 0
var _stage_clip_casts := 0
var _tally_cards := {}
var _tally_card_frame := -1
const CLIP_IDS := ["link_clips", "link_double"]
const INK_SECONDS := 3.0
const INK_HEIGHT := 2.2
var _ink := {}
static var _ink_mesh: ArrayMesh
var near_miss
var flail
var ultimate
var actives
var ally_husks
var last_player_hit := {}
var _hit_attack := ""
var last_impact := {}
var _cloud := {}
var _sentry := {}
var _pulse_left := 0.0
var _cloak_held := 0.0
var _actions := {}
var door := DamageDoor.new()
var _deferred_procs: Array = []
var _draining_procs := false
var _pressure_chasers := 0
var churn
var boils
var _strike_stages := {}


func _init() -> void:
	_strike_stages = {"armour": _door_armour, "caps": _door_caps, "crit": _door_crit,
		"announce": _door_announce, "plates": _door_plates, "health": _door_health,
		"execute": _door_execute, "events": _door_events}
	door.hook("hit", "primer_mesh", _hook_primer_mesh)
	door.hook("hit", "companion_ram", _hook_companion_ram)
	door.hook("hit", "companion_assist", _hook_companion_assist)


func _stage_table():
	return stage_defs if stage_defs != null else ctx.stages


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Combat"
	ctx.spawner = self
	ground = Ground.new(ctx)
	fleet = Fleet.new()
	add_child(fleet)
	fleet.setup(ctx, self)
	effects = Effects.new()
	ctx.root.add_child(effects)
	effects.setup()
	bolts = Bolts.new()
	ctx.root.add_child(bolts)
	bolts.setup()
	bolts.on_hit = _on_bolt_hit
	bolts.on_shell = func(_bolt: Dictionary, shell: Node3D) -> bool: return _bat(shell)
	bolts.on_stop = func(at: Vector3, color: Color):
		effects.spark(at, color)
		if _last_flight_breaks_props:
			_last_flight_breaks_props = false
			ctx.break_props(at, _last_flight_break_radius, _last_flight_weapon)
	bolts.on_bounce = _on_bolt_bounce
	bolts.on_flight = _on_bolt_flight
	sticky = Sticky.new()
	sticky.name = "StickyCharges"
	ctx.root.add_child(sticky)
	devices = Devices.new()
	sticky.ledger = devices
	wear_trail = WearTrail.new()
	wear_trail.setup(ctx, effects, floor_at)
	wear_trail.deal = trail_deal
	churn = ChurnGround.new()
	churn.setup(ctx)
	boils = SiltBoil.new()
	boils.setup(ctx, ground)
	boils.deal = func(amount: float, shove: Vector3): _on_player_hit(amount, shove, "silt_boil")
	near_miss = NearMiss.new()
	add_child(near_miss)
	flail = Flail.new()
	flail.name = "Flail"
	add_child(flail)
	flail.setup(ctx, self)
	near_miss.setup(ctx.events, Callable(ctx.player, "ball_position"))
	var way_out := WayOutPaint.new()
	near_miss.add_child(way_out)
	way_out.setup(near_miss, Callable(ctx.player, "ball_position"), Callable(ground, "height"))
	_wire_redline()
	_specials = {
		"detonation_gauge": {"geometry": discharge_geometry, "fire": fire_discharge},
		"overdrive_blast": {"geometry": _overdrive_geometry, "fire": _fire_overdrive},
		"detonation_line": {"geometry": line_geometry, "fire": fire_line},
		"point_blank": {"geometry": _point_blank_geometry, "fire": _fire_point_blank},
		"clamp": {"geometry": _clamp_geometry, "fire": _fire_clamp},
		"cannon_plate": {"geometry": _plate_geometry, "fire": _fire_plate},
		"gather_plate": {"tap": _tap_gather, "commit": card_aim},
	}
	_line_skills = {
		"line_reel": {"on_body": _line_reel_body, "on_world": reel_burst, "geometry": line_reel_geometry},
		"bank_shot": {"on_body": bank_body, "on_world": bank_world, "geometry": bank_geometry},
		"line_drive": preload("res://src/combat/rivet_kit.gd").line_row(self),
		"cable_charge": KestKit.line_row(self),
		"claw_drag": preload("res://src/combat/tarn_claw.gd").line_row(self),
		"link_clips": {"on_body": _link_clips_body, "on_world": _link_clips_world, "geometry": _clip_geometry},
		"link_double": {"on_body": _link_clips_body, "on_world": _link_clips_world, "geometry": _clip_geometry},
		"cannon_lane_charge": {"on_body": _cannon_line_body, "on_world": _cannon_line_world, "geometry": _cannon_line_geometry},
	}
	ctx.player.line_load_of = line_load
	ultimate = KestKit.new()
	add_child(ultimate)
	ultimate.setup(ctx, self)
	ultimate.register("ult_default", {"tech": _ult_volley, "peak": _ult_peak, "landing": _ult_landing})
	actives = preload("res://src/combat/actives/active_rack.gd").new()
	add_child(actives)
	actives.setup(ctx, self)
	ally_husks = AllyHusk.new()
	add_child(ally_husks)
	ally_husks.setup(ctx, self)
	orbitals = OrbitalSatellites.new()
	add_child(orbitals)
	orbitals.setup(ctx, self)
	hero_hooks = preload("res://src/combat/hero_hooks.gd").new()
	add_child(hero_hooks)
	hero_hooks.setup(ctx, self)
	consumables = preload("res://src/combat/consumable_runtime.gd").new()
	add_child(consumables)
	consumables.setup(ctx, self)
	relic_swaps = preload("res://src/combat/relic_swaps.gd").new()
	add_child(relic_swaps)
	relic_swaps.setup(ctx, self)
	ctx.events.grapple_fired.connect(func(anchor: Vector3):
		_bite_load()
		_on_grapple_fired_muts(anchor)
		_on_cannon_grapple_fired(anchor))
	ctx.events.player_died.connect(_on_player_died)
	_cards = {"balance_due": _run_balance}
	ctx.events.enemy_struck.connect(_on_card_struck)
	ctx.events.harpoon_smashed.connect(func(_enemy: Node3D, _at: Vector3, _speed: float): _grant_pressure(1))
	ctx.events.slammed.connect(func(at: Vector3, _strength: float, _flatness: float):
		var smash = ctx.player.abilities
		if smash.cap(AbilityState.SMASH, "flavour", "") != "stamp":
			_grant_pressure(1)
		else:
			if smash.cap(AbilityState.SMASH, "mutation", "") == "stamp_ink":
				_book_ink(at)
			if ally_husks != null and ghost_shift_unlocked():
				ally_husks.refresh_all_shifts())
	_wire_tally()
	_actions = _proc_actions()
	var facts := {}
	for class_id in UpgradeTree.TREES:
		for n in UpgradeTree.TREES[class_id]:
			for proc in n.get("proc", []):
				facts[proc["on"]] = true
	for kind in facts:
		if not ctx.events.has_signal(kind):
			continue
		var argc: int = _signal_argc(ctx.events, kind)
		ctx.events.connect(kind, _on_proc_fact.bind(kind).unbind(argc))
	ctx.events.slammed.connect(_on_slammed_upgrade)
	ctx.events.slammed.connect(_on_cannon_slammed)
	ctx.events.slammed.connect(_on_fault_slammed)
	ctx.events.slammed.connect(_on_thermobaric_slammed)
	ctx.events.dashed.connect(_on_cannon_dashed)
	ctx.events.dashed.connect(_on_wake_dash)
	ctx.events.dashed.connect(_on_dashed_micro)
	ctx.events.boosted.connect(_on_wake_dash)
	ctx.events.boosted.connect(_on_boosted_micro)
	ctx.events.vault_kicked.connect(hero_hooks.on_vault_kicked)
	ctx.events.grapple_released.connect(_on_grapple_released_w47)
	ctx.events.world_fact.connect(_on_world_fact_w47)
	if ctx.events.has_signal("consumable_used"):
		var c_argc: int = _signal_argc(ctx.events, "consumable_used")
		if c_argc >= 2:
			ctx.events.connect("consumable_used", func(cid: String, at: Vector3): on_consumable_used(cid, at))
		elif c_argc == 1:
			ctx.events.connect("consumable_used", func(cid: String): on_consumable_used(cid))
		else:
			ctx.events.connect("consumable_used", func(): on_consumable_used("consumable"))
	ctx.events.harpoon_smashed.connect(_on_reel_chain)
	ctx.events.slammed.connect(_on_slam_crack)
	ctx.events.dismounted.connect(_on_dismounted_sentry)
	ctx.events.tree_picked.connect(func(_c: String, _n: String, _d: int): rebuild_patterns())
	ctx.player.heft_of = heft
	ctx.player.enemy_heft_of = Roster.heft_of
	ctx.player.strike_damage = STRIKE_DAMAGE
	ctx.player.pressure_grant = _grant_pressure
	ctx.player.hulk_launch = bowl_hulk
	ctx.player.mass_of = func() -> float: return ctx.run.mass
	reset_ledger()
	ctx.events.demo_slammed.connect(_on_demo_slammed)
	ctx.events.arc_slammed.connect(func(at: Vector3, _faces: int): effects.ring(at, 12.0, ClassDef.SABLE_COLOR))
	ctx.events.skid_smashed.connect(func(at: Vector3, _hits: int):
		effects.ring(at, 4.0, ClassDef.RIVET_COLOR)
		weapon_driver.top_up_cylinder())
	ctx.events.blink_used.connect(_on_blink)
	ctx.events.line_state_changed.connect(_on_chain_state)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.escape_window.connect(func(_seconds: float): _escape_act())
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.run_ended.connect(func(_won: bool):
		_clear_devices()
		_clear_cannon_paint()
		_clear_input_buffers()
		hero_hooks.reset()
		_reset_w47_h2_state()
		weapon_driver.reset())
	ctx.events.flow_changed.connect(func(state_name: String):
		if state_name in ["summary", "title"]:
			_clear_cannon_paint()
			_clear_input_buffers()
			hero_hooks.reset()
			_reset_w47_h2_state()
			weapon_driver.reset())
	ctx.events.run_started.connect(func(_class_id: String):
		churn.reset(true)
		boils.reset(true)
		_armour_known = {}
		discovered = {}
		discovery_log = []
		_proc_ready = {}
		_echo = {}
		_marks = {}
		_primed = {}
		assist_charge = 0.0
		assists = 0
		last_assist = {}
		_prow_until = {}
		_guards.clear()
		_clamped = {}
		_rakes = []
		_deferred_procs.clear()
		_clear_aftershocks()
		_heated = {}
		_escape = {}
		escape_lane = {}
		escape_acts = 0
		_free_cannon()
		_cannon_count = 0
		_reset_cards()
		_line_load = {}
		_cast_pending = {}
		_clear_input_buffers()
		_bite_pending = false
		_pike_count = 0
		_pike_last = -INF
		_clear_verb_items()
		_reset_w47_c2_state(true)
		_reset_grapple_muts_state(true)
		hero_hooks.reset()
		_reset_w47_h2_state()
		_cloud = {}
		_sentry = {}
		_pulse_left = 0.0
		_boss_add_ids = {}
		_mounted_boost_left = 0.0
		_overdrive = 0.0
		_spring_until = -1.0
		cloak_left = 0.0
		_clear_combat_buffs()
		weapon_driver.reset()
		reset_ledger()
		rebuild_patterns())
	ctx.events.beacon_unsealed.connect(func(stage: int):
		_ledger["warden_slam_hits"][str(stage)] = _warden_slam_hits
		_warden_slam_hits = 0)
	ctx.events.boss_defeated.connect(func(): _record_retirement("boss"))
	ctx.events.dismounted.connect(func(v: Vector3):
		_mounted_boost_left = 0.0
		weapon_driver.interrupt(WeaponDriver.INTERRUPT_MOUNT)
		if v.length() > 0.1:
			_since_slingshot = 0.0
		hero_hooks.on_dismounted_kinetic_pylon(v))
	ctx.events.part_gained.connect(func(_part: String, _source: String): rebuild_patterns())
	ctx.events.mounted.connect(func(_at: Vector3, _banked_speed: float):
		_mounted_boost_left = Weapons.CHARGE_MOUNT_BOOST_S
		weapon_driver.interrupt(WeaponDriver.INTERRUPT_MOUNT))
	ctx.events.mounted.connect(_on_mounted)
	ctx.events.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		weapon_driver.interrupt(WeaponDriver.INTERRUPT_ULTIMATE)
		_clear_input_buffers()
		_clear_cannon_paint()
		var wg = ctx.player.abilities.gauge(AbilityState.WEAPON)
		if wg != null and wg.cancel():
			ctx.player.indicator.clear("weapon")
			ctx.player.indicator.clear("landing"))
	rebuild_patterns()
	_declare_codex()


func spawn_enemy(kind: String, at: Vector3, affix_id := "", perch := Vector3.INF, health_scale: float = 1.0) -> Node3D:
	var enemy: Node3D
	match kind:
		"lobber":
			enemy = Lobber.new()
		"miniboss":
			enemy = Miniboss.new()
		"warden":
			enemy = Warden.new()
		"vault":
			enemy = Vault.new()
		"chaser":
			enemy = Chaser.new()
		_ when Rogue.ROWS.has(kind):
			enemy = Rogue.new()
		_ when fleet.makes(kind):
			enemy = fleet.make(kind)
		_:
			push_warning("spawn_enemy: unknown kind '%s', spawning a chaser" % kind)
			kind = "chaser"
			enemy = Chaser.new()
	enemy.position = ctx.root.global_transform.affine_inverse() * at
	ctx.root.add_child(enemy)
	if ctx.flow != null and ctx.flow.in_arena:
		_boss_add_ids[enemy.get_instance_id()] = true
	var target = Sight.new(ctx.player, self, enemy, kind) if Sight.REACH.has(kind) or fleet.makes(kind) else ctx.player
	var health := _threat()
	var enemy_spec: Dictionary = fleet.dress(kind, _spec_for(kind))
	if kind == "lobber" and ctx.flow.in_stage():
		enemy_spec["lead"] = ChallengeDials.by_stage_or("mobs.lobber_lead_by_stage", ctx.flow.stage(), Lobber.LEAD)
	if affix_id == EliteAffixes.PLATED:
		enemy_spec["armour"] = EliteAffixes.PLATED
	if kind == "dispatcher" and perch.is_finite():
		enemy_spec["perch"] = perch
	if kind not in ["warden", "vault"]:
		var director = _director()
		if director != null:
			health = director.hp_scale()
			enemy_spec["rest_scale"] = director.rest_scale()
		if director != null and director.run_tier() >= 1:
			enemy_spec["stage_threat"] = _threat()
			if kind == "plated_brute" and director.run_tier() >= RunTier.HARD and not EliteAffixes.row(affix_id).is_empty():
				enemy_spec.merge(RunTier.row(director.run_tier()).elite_stats, true)
				enemy_spec["affix"] = affix_id
				enemy_spec["affix_world"] = director.world
		var pressure := PackPressure.crew_row(int(ctx.run.stage))
		if ctx.flow.in_stage() and (pressure.lead > 0.0 or pressure.rest != 1.0 or pressure.flank > 0.0):
			if kind == "chaser" and pressure.flank > 0.0:
				_pressure_chasers += 1
				pressure["flanker"] = _pressure_chasers % 2 == 0
			enemy_spec["pressure"] = pressure
		if kind == "chaser" and ctx.flow.in_stage():
			enemy_spec["run_speed"] = Chaser.stage_speed(int(ctx.run.stage))
	enemy.setup(target, ground, ctx.root, Callable(ctx.flow, "in_play"), health * health_scale, enemy_spec)
	if enemy is CollisionObject3D and not enemy.global_position.is_equal_approx(at):
		_reenter_space(enemy)
	if "threat_level" in enemy:
		enemy.threat_level = _threat()
	if "landed_attack" in enemy:
		enemy.hit_player.connect(func(_amount: float, _shove: Vector3): _hit_attack = String(enemy.landed_attack))
	enemy.hit_player.connect(_on_player_hit.bind(kind))
	if enemy.has_signal("counter_hit"):
		enemy.counter_hit.connect(_on_player_hit.bind("warden_counter"))
	enemy.died.connect(func(where: Vector3, scrap: int):
		var source: String = enemy.last_damage_source if "last_damage_source" in enemy else ""
		if enemy.has_meta(HazardHits.STRUCK):
			source = "hazard"
		if source != "fuse":
			ctx.run.kill_tags = _kill_tags(enemy, affix_id)
			ctx.run.record_kill(kind, where, scrap, source)
		var id := enemy.get_instance_id()
		consumables.on_enemy_died(id, kind, where, source)
		_primed.erase(id)
		_prow_until.erase(id)
		_record_retirement(_class_for_id(id, kind))
		_clamped.erase(id)
		_heated.erase(id)
		_drop_exposed(id)
		_drop_exposed(_arc_key(id))
		_boss_add_ids.erase(id)
		_pendulum_zapped.erase(id)
		_pulled_recent.erase(id)
		_hot_wire_cd.erase(id)
		if ally_husks != null and ghost_shift_unlocked():
			ally_husks.record_wreck(enemy))
	if enemy.has_signal("fired"):
		enemy.fired.connect(_on_lobber_fired.bind(enemy))
	SpecialCues.attach(enemy)
	ctx.events.enemy_spawned.emit(enemy, kind)
	fleet.on_spawned(enemy, kind)
	return enemy


static func _reenter_space(body: CollisionObject3D) -> void:
	var rid := body.get_rid()
	var space := PhysicsServer3D.body_get_space(rid)
	PhysicsServer3D.body_set_space(rid, RID())
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
	PhysicsServer3D.body_set_space(rid, space)


func _kill_tags(enemy: Node3D, affix_id: String) -> Dictionary:
	var reel_at = enemy.get_meta(REEL_MARK) if enemy.has_meta(REEL_MARK) else null
	return {"elite": bool(enemy.get_meta("elite_pack", false)) or affix_id != "",
		"jackpot": reel_at != null and _clock - float(reel_at) <= REEL_KILL_WINDOW,
		"yard": bool(enemy.get_meta("yard_crew", false))}


func build_read() -> Dictionary:
	return fleet.build_read()


func strike(enemy: Node3D, kind: String, force: float, part := "", source := "", impact := "", chip := CHIP) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	if ultimate != null and ultimate.active() and kind in CONTACT_KINDS and enemy.has_method("_apply_posture") \
			and enemy.has_method("staggered") and not enemy.staggered():
		ultimate.warden_posture(enemy, resolve(enemy, kind, force, part, 0.0,
			panel_punch(kind, _classify_source(kind, source if source != "" else _forced_source)), chip))
		return
	var dunk := _dunk_bonus(enemy, kind)
	var reel: bool = ctx != null and ctx.player != null and ctx.player.get("kit") != null \
		and is_reel_impact(kind, ctx.player.smash_landing == enemy)
	if ctx != null and ctx.player != null and ctx.player.get("kit") != null and (dunk > 0.0 or reel):
		enemy.set_meta(REEL_MARK, _clock)
	var hit := door.pass_hit({"enemy": enemy, "kind": kind, "force": force, "part": part, "source": source,
		"impact": impact, "dunk": dunk, "chip": chip}, _strike_stages)
	if reel:
		_note_reel(enemy, float(hit.get("result", {}).get("dealt", 0.0)))


func _door_armour(hit: Dictionary) -> void:
	hit["cls"] = _classify_source(hit["kind"], hit["source"] if hit["source"] != "" else _forced_source)
	hit["bonus"] = panel_punch(hit["kind"], hit["cls"])
	var chip: float = float(hit.get("chip", CHIP))
	hit["result"] = resolve(hit["enemy"], hit["kind"], hit["force"], hit["part"], hit["dunk"], hit["bonus"], chip)
	if hit["dunk"] > 0.0 and bool(hit["result"].get("guarded", false)):
		hit["dunk"] = 0.0
		hit["result"] = resolve(hit["enemy"], hit["kind"], hit["force"], hit["part"], 0.0, hit["bonus"], chip)


func _door_caps(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var result: Dictionary = hit["result"]
	result["base_dealt"] = float(result["dealt"])
	result["dealt"] = float(result["dealt"]) * _strike_mult(enemy, hit["kind"], hit["cls"])
	if ctx != null and ctx.run != null and ctx.run.has_method("override_on") and ctx.run.override_on("impact_force_2x"):
		result["dealt"] = float(result["dealt"]) * 2.0
	_read_armour(enemy, hit, result)
	if enemy.has_method("absorbs_hit") and enemy.absorbs_hit(result):
		result["absorbed"] = true
	if hit["dunk"] > 0.0:
		if bool(result.get("absorbed", false)) and enemy.absorbs_hit(
				resolve(enemy, hit["kind"], hit["force"], hit["part"], 0.0, hit["bonus"])):
			hit["dunk"] = 0.0
		else:
			ctx.player.dunk.spend(enemy)
			result["dunk"] = hit["dunk"]
	if hit["kind"] in CONTACT_KINDS and _exposed.has(enemy.get_instance_id()) \
			and float(_exposed[enemy.get_instance_id()]["until"]) <= _clock:
		_drop_exposed(enemy.get_instance_id())
	if hit["kind"] == ARC_MARK_KIND:
		_arc_mark(enemy)


func _dunk_bonus(enemy: Node3D, kind: String) -> float:
	if ctx == null or ctx.player == null or not ctx.player.get("dunk"):
		return 0.0
	var smash: bool = ctx.player.smash_landing == enemy
	var kit = ctx.player.kit
	var reeled: bool = kind in ["stomp", "ram", "slam"] and kit.reel_body == enemy and kit.reel_left > 0.0
	if not reeled and (not is_reel_impact(kind, smash) or not (smash or kit.anchor_body == enemy)):
		return 0.0
	return ctx.player.dunk.peek()


func is_reel_impact(kind: String, smash: bool) -> bool:
	var kit = ctx.player.kit
	return Dunk.is_reel_impact(kind, smash, kit.hooked, kit.winching)


func _read_armour(enemy: Node3D, hit: Dictionary, result: Dictionary) -> void:
	var armour := DamageFamilies.armour_of(enemy)
	var read := DamageFamilies.verdict(armour, hit["kind"], hit["cls"]) if bool(result.get("full", false)) else ""
	enemy.set_meta("armour_read", read)
	if read == "":
		return
	result["dealt"] = float(result["dealt"]) * DamageFamilies.mult(armour, hit["kind"], hit["cls"])
	result["read"] = read
	if _armour_known.has(armour):
		return
	_armour_known[armour] = true
	match armour:
		"plated":
			discover("armour_plated", enemy.global_position)
		"wet":
			discover("armour_wet", enemy.global_position)


func _door_crit(hit: Dictionary) -> void:
	hit["spent"] = _primer_hit(hit["enemy"], hit["kind"], hit["cls"])


func _door_announce(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var kind: String = hit["kind"]
	var force: float = hit["force"]
	var result: Dictionary = hit["result"]
	hit["at"] = enemy.global_position
	hit["id"] = enemy.get_instance_id()
	_detect_before(enemy, kind, result)
	var outer := _pending
	_pending = {"id": enemy.get_instance_id(), "kind": kind, "force": force, "part": result["part"], "dunk": hit["dunk"],
		"bonus": hit["bonus"], "result": result}
	hit["hp_before"] = _hp_of(enemy)
	var outer_impact := last_impact
	last_impact = {"key": hit["impact"], "enemy": enemy.get_instance_id()} if hit["impact"] != "" else {}
	ctx.events.enemy_struck.emit(enemy, kind, force)
	last_impact = outer_impact
	if not result["full"]:
		deflections += 1
		ctx.events.strike_deflected.emit(enemy, kind, result["punch"], result["plating"])
	_pending = outer


func _door_plates(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var result: Dictionary = hit["result"]
	if enemy.has_method("on_struck"):
		enemy.on_struck(hit["kind"], result["part"], result)
	if hit["kind"] in ["stomp", "slam"] and float(result["dealt"]) > 0.0 and target_class_of(enemy) == "Warden":
		_warden_slam_hits += 1


func _door_health(hit: Dictionary) -> void:
	hit["removed"] = DamageDoor.health(hit["enemy"], hit["result"]["dealt"], hit["hp_before"])


func _door_execute(hit: Dictionary) -> void:
	hit["killed"] = DamageDoor.dead(hit["enemy"])


func _door_events(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var result: Dictionary = hit["result"]
	if result.get("shred", true):
		add_shred(enemy, result["punch"])
	_detect_after(enemy, hit["kind"], result)
	_record_delivered(enemy, hit["kind"], hit["removed"], result["dealt"],
		hit["source"] if hit["source"] != "" else _forced_source)
	_consume_grapple_mut_strike(hit)


func _hook_primer_mesh(hit: Dictionary) -> void:
	if hit["spent"] == "primer_mesh":
		_primer_mesh(hit["at"], hit["id"], float(hit["result"]["dealt"]))


func _hook_companion_ram(hit: Dictionary) -> void:
	_companion_ram(hit["enemy"], hit["kind"], hit["result"])


func _hook_companion_assist(hit: Dictionary) -> void:
	if ctx.run.companion.is_empty() or float(hit["result"].get("dealt", 0.0)) <= 0.0:
		return
	if is_instance_valid(hit["enemy"]) and _fights_posture(hit["enemy"]):
		return
	var kind: String = hit["kind"]
	if kind == Companion.ASSIST_TRIGGER and assist_ready():
		_call_assist(hit["at"], float(hit["result"]["dealt"]))
		return
	_charge_assist(kind)


func _charge_assist(kind: String) -> void:
	if ctx.run.companion.is_empty():
		return
	var was := assist_ready()
	assist_charge = Companion.assist_charge(assist_charge, kind)
	if assist_ready() and not was:
		companion_assist_full.emit()


func assist_ready() -> bool:
	return assist_charge >= Companion.ASSIST_FULL


func assist_fill() -> float:
	return clampf(assist_charge / Companion.ASSIST_FULL, 0.0, 1.0)


func _call_assist(at: Vector3, dealt: float) -> void:
	var sockets: Array = ctx.run.companion.get("sockets", [])
	var row := Companion.assist_of(sockets)
	var heft: int = ctx.run.heft_class() if ctx.run.has_method("heft_class") else 1
	var power := Companion.assist_power(heft)
	var radius: float = power["radius"]
	var ball: Vector3 = ctx.player.ball_position()
	var travel: Vector3 = ctx.player.planar_velocity()
	travel.y = 0.0
	var dir := travel.normalized() if travel.length_squared() > 0.01 else (at - ball).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var damage := maxf(dealt, Companion.ASSIST_DAMAGE_FLOOR)
	assist_charge = 0.0
	assists += 1
	var struck := _assist_targets(row["shape"], at, ball, dir, radius)
	for enemy in struck:
		trail_deal(enemy, damage, "companion_assist", "item_proc")
		if DamageDoor.dead(enemy):
			continue
		if row["prime"]:
			_primed[enemy.get_instance_id()] = _clock + Companion.PRIMER_SECONDS
		if row["shove"] and enemy.has_method("knock"):
			var flat: Vector3 = enemy.global_position - (ball if row["shape"] == "lane" else at)
			flat.y = 0.0
			var away := flat.normalized() if flat.length_squared() > 0.0001 else dir
			var weight = enemy.get("weight")
			enemy.knock(away + Vector3.UP * 0.35, Companion.ASSIST_KNOCK * float(power["knock"]) * (float(weight) if weight != null else 1.0))
	if row["slick"] and (escape_lane.is_empty() or _clock >= float(escape_lane["until"])):
		escape_lane = {"from": ball, "dir": dir, "length": radius * 2.0, "half_width": Companion.ESCAPE_LANE_HALF_WIDTH,
			"friction": Companion.ESCAPE_LANE_FRICTION, "hold": maxf(travel.dot(dir), Companion.ESCAPE_LANE_FLOOR),
			"until": _clock + Companion.ASSIST_SLICK_SECONDS}
	if row["shape"] == "lane":
		effects.arc(ball, ball + dir * radius * 2.0, Palette.VERDIGRIS)
	else:
		effects.ring(at, radius, Palette.VERDIGRIS)
	last_assist = {"id": row["id"], "name": row["name"], "word": row["word"], "cue": row["cue"], "at": at,
		"radius": radius, "knock": power["knock"], "area": power["area"], "layers": power["layers"],
		"hits": struck.size(), "mark": int(Companion.mark_of(heft)["mark"])}
	companion_assisted.emit(last_assist)


func _assist_targets(shape: String, at: Vector3, ball: Vector3, dir: Vector3, radius: float) -> Array:
	var found := []
	var nearest: Node3D = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if DamageDoor.dead(enemy) or _fights_posture(enemy):
			continue
		var flat: Vector3 = enemy.global_position - at
		flat.y = 0.0
		match shape:
			"single":
				if flat.length() <= radius and flat.length() < best:
					best = flat.length()
					nearest = enemy
			"ring":
				if flat.length() <= radius:
					found.append(enemy)
			"lane":
				var rel: Vector3 = enemy.global_position - ball
				rel.y = 0.0
				var along := rel.dot(dir)
				if along >= 0.0 and along <= radius * 2.0 and (rel - dir * along).length() <= radius * Companion.ASSIST_LANE_HALF_WIDTH:
					found.append(enemy)
	if nearest != null:
		found.append(nearest)
	return found


func _primer_hit(enemy: Node3D, kind: String, cls: String, _result := {}) -> String:
	var row := _primer_driver(enemy, kind, cls)
	var id := enemy.get_instance_id()
	match String(row.get("act", "")):
		"prime":
			var live: bool = float(_primed.get(id, -1.0)) > _clock
			_primed[id] = _clock + Companion.PRIMER_SECONDS
			if not live:
				effects.spark(enemy.global_position + Vector3.UP * 0.5, Palette.VERDIGRIS)
		"consume":
			_primed.erase(id)
			effects.arc(ctx.player.ball_position() + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, Palette.VERDIGRIS)
			return Companion.seated(ctx.run.companion, Companion.CONDUCTIVE_PRIMER)
	return ""


func _primer_driver(enemy: Node3D, kind: String, cls: String) -> Dictionary:
	var piece := Companion.seated(ctx.run.companion, Companion.CONDUCTIVE_PRIMER)
	if piece == "" or _fights_posture(enemy):
		return {}
	var on := "weapon" if cls == "weapon" else ("contact" if kind in CONTACT_KINDS else ("special" if cls == "special" else "other"))
	return Companion.pick({"piece": piece, "on": on,
		"primed": float(_primed.get(enemy.get_instance_id(), -1.0)) > _clock}, drivers)


func _primer_consumes(enemy: Node3D, kind: String, cls: String) -> String:
	if _primer_driver(enemy, kind, cls).get("act", "") != "consume":
		return ""
	return Companion.seated(ctx.run.companion, Companion.CONDUCTIVE_PRIMER)


func _strike_mult(enemy: Node3D, kind: String, cls: String) -> float:
	var mult := 1.0
	if kind in CONTACT_KINDS and float(_exposed.get(enemy.get_instance_id(), {}).get("until", -INF)) > _clock:
		mult *= MindAttacks.BRACE_MULT
	if consumables.memo_exposed(enemy):
		mult *= float(Consumables.row_of(Consumables.FOREMAN_MEMO).get("weak_mult", 1.5))
	if _primer_consumes(enemy, kind, cls) == "primer_coil":
		mult *= Companion.PRIMER_COIL_MULT
	if _arc_marked(enemy):
		mult *= 1.0 + ARC_MARK_FRACTION
	if live_bus_charged() and cls != "debris" and kind != "live_bus":
		mult *= float(Parts.GRAPPLE_MUTATIONS["live_bus"]["bonus_mult"])
	if _tether_slam_matches(enemy, kind):
		mult *= float(Parts.GRAPPLE_MUTATIONS["tether_slam"]["crush_mult"])
	if orbitals != null:
		mult *= orbitals.strike_mult(enemy, kind, cls)
	return mult


func _primer_mesh(at: Vector3, struck_id: int, dealt: float) -> void:
	var found := []
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.get_instance_id() == struck_id or enemy.is_dead() or _fights_posture(enemy):
			continue
		var distance: float = enemy.global_position.distance_to(at)
		if distance <= Companion.PRIMER_MESH_RANGE:
			found.append([distance, enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(Companion.PRIMER_MESH_TARGETS, found.size()):
		var n: Node3D = found[i][1]
		effects.arc(at + Vector3.UP * 0.5, n.global_position + Vector3.UP * 0.5, Palette.VERDIGRIS)
		if n.has_method("flash"):
			n.flash()
		trail_deal(n, dealt * Companion.PRIMER_MESH_SHARE, "primer_mesh", "item_proc")


func _fights_posture(enemy: Node3D) -> bool:
	return enemy.has_method("fight") and enemy.call("fight") == "posture"


func primed(enemy: Node3D) -> bool:
	return is_instance_valid(enemy) and float(_primed.get(enemy.get_instance_id(), -1.0)) > _clock


func primer_expired(enemy_id: int) -> bool:
	return _primed.has(enemy_id) and float(_primed[enemy_id]) <= _clock


func _companion_ram(enemy: Node3D, kind: String, result: Dictionary) -> void:
	var piece := Companion.seated(ctx.run.companion, Companion.RAM_BRACE)
	if piece == "":
		return
	var valid := is_instance_valid(enemy)
	var free: bool = valid and not enemy.has_method("staggered") and not (enemy.has_method("is_dead") and enemy.is_dead())
	var row := Companion.pick({"piece": piece, "on": kind, "foe_free": free,
		"prow_ready": valid and _clock >= float(_prow_until.get(enemy.get_instance_id(), -1.0)),
		"dealt": float(result.get("dealt", 0.0)) > 0.0}, drivers)
	match String(row.get("act", "")):
		"shove":
			if not valid:
				return
			_prow_until[enemy.get_instance_id()] = _clock + PROW_STAGGER
			var flat: Vector3 = enemy.global_position - ctx.player.ball_position()
			flat.y = 0.0
			var flat_dir: Vector3 = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
			var weight = enemy.get("weight")
			if enemy.has_method("knock"):
				enemy.knock(flat_dir + Vector3.UP * 0.35, PROW_SHOVE * (float(weight) if weight != null else 1.0))
			effects.ring(enemy.global_position, 2.5, Palette.VERDIGRIS)
		"arm":
			_spring_until = _clock + SPRING_WINDOW
			_post_buff("spring", {"icon": "spring", "tone": Palette.AMBER, "kind": BuffLedger.KIND_TIMER,
				"duration_s": SPRING_WINDOW, "left_s": SPRING_WINDOW})
			effects.spark(ctx.player.ball_position(), Palette.VERDIGRIS)


func _escape_act() -> void:
	var piece := Companion.seated(ctx.run.companion, Companion.ESCAPE_CORRIDOR)
	var esc := Companion.escape_of(piece)
	var row := Companion.pick({"piece": piece, "on": "escape_window", "alive": ctx.run.alive()}, drivers)
	if esc.is_empty() or row.is_empty():
		return
	var style := String(row["act"])
	_escape = {"piece": piece, "style": style, "until": _clock + float(esc["seconds"])}
	var ball: Vector3 = ctx.player.ball_position()
	var v: Vector3 = ctx.player.planar_velocity()
	var speed := v.length()
	var away := Vector3.ZERO
	if not last_player_hit.is_empty() and int(last_player_hit.get("frame", -1)) == Engine.get_physics_frames():
		away = ball - Vector3(last_player_hit["from"])
		away.y = 0.0
	if away.length_squared() < 0.0001:
		away = v
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	if style == "shove":
		var after := v + away * maxf(Companion.ESCAPE_SHOVE_FLOOR, speed * Companion.ESCAPE_SHOVE_SHARE)
		var cap := maxf(speed * Companion.ESCAPE_SHOVE_CAP, Companion.ESCAPE_SHOVE_FLOOR)
		if after.length() > cap:
			after = after.normalized() * cap
		if after.length() < speed:
			after = after.normalized() * speed
		ctx.player.add_external_accel((after - v) / get_physics_process_delta_time())
		effects.ring(ball, 2.0, Palette.VERDIGRIS)
	else:
		var dir := v.normalized() if speed > 1.0 else away
		escape_lane = {"from": ball, "dir": dir, "length": Companion.ESCAPE_LANE_LENGTH,
			"half_width": Companion.ESCAPE_LANE_HALF_WIDTH, "friction": Companion.ESCAPE_LANE_FRICTION,
			"hold": maxf(v.dot(dir), Companion.ESCAPE_LANE_FLOOR), "until": _escape["until"]}
		effects.arc(ball, ball + dir * Companion.ESCAPE_LANE_LENGTH, Palette.VERDIGRIS)
	escape_acts += 1
	escape_acted.emit(piece, style)


func _step_escape_lane() -> void:
	if escape_lane.is_empty():
		return
	if _clock >= float(escape_lane["until"]):
		escape_lane = {}
		return
	var dir: Vector3 = escape_lane["dir"]
	var rel: Vector3 = ctx.player.ball_position() - Vector3(escape_lane["from"])
	rel.y = 0.0
	var along := rel.dot(dir)
	if along < -0.5 or along > float(escape_lane["length"]) or (rel - dir * along).length() > float(escape_lane["half_width"]):
		return
	var short: float = float(escape_lane["hold"]) - ctx.player.planar_velocity().dot(dir)
	if short > 0.0:
		ctx.player.add_external_accel(dir * short * (1.0 - float(escape_lane["friction"])) / get_physics_process_delta_time())


func escape_phase() -> String:
	if Companion.seated(ctx.run.companion, Companion.ESCAPE_CORRIDOR) == "":
		return "none"
	if not _escape.is_empty() and _clock < float(_escape["until"]):
		return "acting"
	return "spent" if ctx.run.companion.get("escape_spent", false) == true else "ready"


func escape_style() -> String:
	return String(_escape.get("style", ""))


func prow_staggered(enemy: Node3D) -> bool:
	return is_instance_valid(enemy) and _clock < float(_prow_until.get(enemy.get_instance_id(), -1.0))


func spring_armed() -> bool:
	return _clock < _spring_until


func _hp_of(enemy: Node3D) -> float:
	return DamageDoor.hp_of(enemy)


func _record_delivered(enemy: Node3D, kind: String, removed: float, dealt: float, raw_source: String, known_class := "") -> void:
	if _ledger.is_empty():
		reset_ledger()
	var source := _classify_source(kind, raw_source)
	var target_class := known_class if known_class != "" else target_class_of(enemy)
	_ledger["hits"] = int(_ledger["hits"]) + 1
	if removed <= 0.0:
		_ledger["zero_damage_hits"] = int(_ledger["zero_damage_hits"]) + 1
	_ledger["total"] = float(_ledger["total"]) + removed
	_ledger["overkill"] = float(_ledger["overkill"]) + maxf(0.0, dealt - removed)
	_bump(_ledger["by_source"], source, removed)
	_bump(_ledger["by_action"], kind, removed)
	_bump(_ledger["by_target_class"], target_class, removed)
	_bump(_ledger["by_range"], _range_bucket(enemy), removed)


func trail_deal(enemy: Node3D, amount: float, action := "spark", source := "persistent_actor") -> float:
	var target_class := target_class_of(enemy)
	var removed := DamageDoor.health(enemy, amount, _hp_of(enemy))
	_record_delivered(enemy, action, removed, amount, source, target_class)
	return removed


func _record_retirement(target_class: String) -> void:
	if _ledger.is_empty():
		reset_ledger()
	_ledger["retirements"][target_class] = int(_ledger["retirements"].get(target_class, 0)) + 1


static func _bump(map: Dictionary, key: String, amount: float) -> void:
	map[key] = float(map.get(key, 0.0)) + amount


func _classify_source(kind: String, explicit: String) -> String:
	if kind == DEBRIS:
		return DEBRIS
	if explicit != "":
		return explicit
	if kind == SYNERGY:
		return "item_proc"
	if kind in CONTACT_KINDS:
		return "drop_or_slam" if kind == "slam" else "ram_or_contact"
	if kind == "pin" or kind == "shell":
		return "ram_or_contact"
	return "item_proc"


func target_class_of(enemy: Node3D) -> String:
	return _class_for_id(enemy.get_instance_id(), _spawn_kind_of(enemy))


func _class_for_id(id: int, kind: String) -> String:
	if _boss_add_ids.has(id):
		return "boss_adds"
	return _target_class_of_kind(kind)


func _spawn_kind_of(enemy: Node3D) -> String:
	var spec_val = enemy.get("spec")
	if spec_val is Dictionary and (spec_val as Dictionary).has("kind"):
		return String((spec_val as Dictionary)["kind"])
	var k = enemy.get("kind")
	return String(k) if k != null else ""


func _target_class_of_kind(kind: String) -> String:
	if kind == "warden":
		return "Warden"
	if Roster.is_boss_piece(kind):
		return "boss"
	if kind == "vault":
		return "cache"
	if kind in KINDS or Rogue.ROWS.has(kind):
		return "enemy"
	if not Roster.is_reinforcement(kind) and not Roster.row(kind).has("priority") and not Roster.is_world_kind(kind):
		push_warning("_target_class_of_kind: '%s' is neither a v1 kind nor a Fleet reinforcement; counting it under 'adds'" % kind)
	return "adds"


func _range_bucket(enemy: Node3D) -> String:
	if ctx == null or ctx.player == null:
		return "far"
	var d := enemy.global_position.distance_to(ctx.player.ball_position())
	if d <= RANGE_NEAR_M:
		return "near"
	if d <= RANGE_MID_M:
		return "mid"
	return "far"


func reset_ledger() -> void:
	_ledger = {
		"total": 0.0, "overkill": 0.0, "hits": 0, "zero_damage_hits": 0,
		"by_source": {}, "by_action": {}, "by_target_class": {}, "by_range": {"near": 0.0, "mid": 0.0, "far": 0.0},
		"retirements": {}, "warden_slam_hits": {},
	}
	_warden_slam_hits = 0
	if ctx != null and ctx.run != null:
		ctx.run.set_meta("delivered_damage", _ledger)


func delivered_damage() -> Dictionary:
	return _ledger


func resolve(enemy: Node3D, kind: String, force: float, part := "", dunk := 0.0, bonus := 0.0, chip := CHIP) -> Dictionary:
	if not _pending.is_empty() and _pending["id"] == enemy.get_instance_id() \
			and _pending["kind"] == kind and _pending["force"] == force:
		if _pending.has("result") and (part == "" or part == _pending["part"]):
			return (_pending["result"] as Dictionary).duplicate()
		if part == "":
			part = _pending["part"]
		if dunk == 0.0:
			dunk = _pending["dunk"]
		bonus = maxf(bonus, float(_pending.get("bonus", 0.0)))
	if part == "" and kind in CONTACT_KINDS and enemy.has_method("contact_part"):
		part = enemy.contact_part(ctx.player.ball_position(), kind)
	if kind == SYNERGY:
		part = ""
	var punch := punch_of(kind, force) + dunk + bonus
	if enemy.has_method("fight") and enemy.fight() == "posture":
		var tier: int = SpeedTier.of(force, ctx.player.tuning.tier_cruise()) if kind == "ram" else 0
		var smash: bool = ctx.player.smash_landing == enemy
		var judged: Dictionary = enemy.judge_hit(kind, punch, smash, tier, part) \
				if enemy.get_method_argument_count("judge_hit") >= 5 else enemy.judge_hit(kind, punch, smash, tier)
		if not judged.is_empty():
			judged["reel"] = is_reel_impact(kind, smash)
			return judged
	var guard := guard_of(enemy)
	if guard != null and guard.blocks(kind):
		return {"punch": punch, "plating": guard.DISH_PLATING, "full": false, "dealt": 0.0, "part": part, "shred": false,
			"guarded": true}
	var reported: float = enemy.plating_for(kind, part) if enemy.has_method("plating_for") else 0.0
	var plating := maxf(0.0, reported - shred_of(enemy))
	var full := punch >= plating
	var mult: float = enemy.hit_mult(kind, part) if full and enemy.has_method("hit_mult") else 1.0
	var dealt := punch * mult if full else punch * chip
	return {"punch": punch, "plating": plating, "full": full, "dealt": dealt, "part": part}


func guard_of(enemy: Node3D) -> Node3D:
	if enemy == null or not is_instance_valid(enemy):
		return null
	var linker = _guards.get(enemy.get_instance_id())
	if linker == null or not is_instance_valid(linker) or not linker.guarding(enemy):
		return null
	return linker


func guard(partner: Node3D, linker: Node3D) -> bool:
	var held = _guards.get(partner.get_instance_id())
	if held != null and held != linker and is_instance_valid(held) and held.holds_partner(partner):
		return false
	_guards[partner.get_instance_id()] = linker
	return true


func guard_holder(enemy: Node3D) -> Node3D:
	var held = _guards.get(enemy.get_instance_id())
	return held if held != null and is_instance_valid(held) and held.holds_partner(enemy) else null


func unguard(partner: Node3D, linker: Node3D) -> void:
	if partner == null or not is_instance_valid(partner):
		for id in _guards.keys():
			if _guards[id] == linker:
				_guards.erase(id)
		return
	if _guards.get(partner.get_instance_id()) == linker:
		_guards.erase(partner.get_instance_id())


func punch_of(kind: String, force: float) -> float:
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		var scale := 1.0
		if ctx != null and ctx.player.kit.sprinting:
			scale = _knob("sprint_punch")
		elif ctx != null and ctx.player.kit.hooked and ctx.player.kit.winching:
			scale = _knob("winch_punch")
		if kind == "ram" and ctx != null and ctx.tuning != null:
			scale *= ctx.tuning.mod("ram_force")
		return (row[0] + force * row[1]) * heft() * scale
	return force


func panel_punch(kind: String, cls: String) -> float:
	if not (cls == "weapon" or (kind in CONTACT_KINDS and cls in ["ram_or_contact", "drop_or_slam"])):
		return 0.0
	var build = ctx.build if ctx != null else null
	if build == null or not build.has_method("panel_punch"):
		return 0.0
	return float(build.panel_punch())


func heft() -> float:
	if heft_override >= 0.0:
		return heft_override
	if ctx != null and ctx.run != null and ctx.run.has_method("heft"):
		return ctx.run.heft()
	return 1.0


func punch_now() -> float:
	var weapon := active_weapon()
	var shot: float = _patterns[weapon].damage * damage_mod(weapon) + panel_punch("", "weapon") if _patterns.has(weapon) else 0.0
	return maxf(ram_punch_now(), shot)


func ram_punch_now() -> float:
	var planar: float = ctx.player.planar_velocity().length()
	if SpeedTier.of(planar, ctx.player.tuning.tier_cruise()) < SpeedTier.CRUISE:
		return 0.0
	return punch_of("ram", planar) + panel_punch("ram", "ram_or_contact")


func damage_mod(weapon: String) -> float:
	var scale: float = ctx.tuning.mod("weapon_damage")
	if weapon == Weapons.PYLON_TURRET:
		scale *= ctx.tuning.mod("turret_damage")
	return scale


func plating_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy) or not enemy.has_method("plating_now"):
		return 0.0
	return maxf(0.0, enemy.plating_now() - shred_of(enemy))


func shred_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	return float(_shred.get(enemy.get_instance_id(), {}).get("amount", 0.0))


func wipe_shred(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	_shred.erase(enemy.get_instance_id())
	_show_shred(enemy, 0.0)


func integrity_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 1.0
	if (enemy.has_method("is_dead") and enemy.is_dead()) or float(enemy.get("max_hp")) <= 0.0:
		return 0.0
	return clampf(float(enemy.get("hp")) / float(enemy.get("max_hp")), 0.0, 1.0)


func would_crush(enemy: Node3D, kind: String, force: float) -> bool:
	if not is_instance_valid(enemy) or enemy.is_dead():
		return false
	if enemy.has_method("crushable") and not enemy.crushable():
		return false
	var cls := _classify_source(kind, _forced_source)
	var result := resolve(enemy, kind, force, "", 0.0, panel_punch(kind, cls))
	var dealt: float = float(result["dealt"]) * _strike_mult(enemy, kind, cls)
	if bool(result.get("full", false)):
		dealt *= DamageFamilies.mult(DamageFamilies.armour_of(enemy), kind, cls)
	return result["plating"] <= 0.0 and dealt >= enemy.hp


func register_part(part_id: String, transformer_ids: Array) -> void:
	_part_map[part_id] = transformer_ids.duplicate()
	rebuild_patterns()


func transformer_ids() -> PackedStringArray:
	return PackedStringArray(Pattern.TRANSFORMERS.keys())


func active_transformers() -> Array:
	var ids := []
	if ctx == null or ctx.run == null:
		return ids
	for part in ctx.run.parts:
		if _part_map.has(part):
			ids.append_array(_part_map[part])
		elif Pattern.has_transformer(part):
			ids.append(part)
	return ids


func pattern(weapon_id: String) -> Resource:
	return (_patterns[weapon_id] as Resource).copy()


func clock_now() -> float:
	return _clock


func rocket_left() -> float:
	return _rocket_left


func clamp_for(enemy: Node3D, seconds: float) -> void:
	_clamped[enemy.get_instance_id()] = _clock + seconds


func live_pattern(weapon_id: String) -> Resource:
	return _patterns.get(weapon_id)


func set_pattern(weapon_id: String, p: Resource) -> void:
	_patterns[weapon_id] = p


func line_skill(id: String) -> Dictionary:
	return _line_skills.get(id, {})


func register_line_skill(id: String, row: Dictionary) -> void:
	_line_skills[id] = row


func register_special(id: String, row: Dictionary) -> void:
	_specials[id] = row


func live_projectiles() -> int:
	return bolts.live()


func active_weapon() -> String:
	var def = ctx.run.class_def
	if def == null:
		return ""
	var abilities = ctx.player.abilities
	var weapon: String = abilities.id_of(AbilityState.WEAPON)
	var mounted_as = abilities.cap(AbilityState.WEAPON, "mounted", null)
	if mounted_as != null and (ctx.player.kit.mounted or (_knob("air_turret") and not ctx.player.state.on_floor())):
		return mounted_as
	return String(abilities.cap(AbilityState.WEAPON, "pattern", weapon))


func discharge_preview(speed: float) -> Dictionary:
	var p: Resource = _patterns[Weapons.PYLON_TURRET]
	var scale: float = p.damage * damage_mod(Weapons.PYLON_TURRET) / Weapons.base_damage(Weapons.PYLON_TURRET)
	var burst := Weapons.burst(speed, p.burst_scale, scale)
	burst["radius"] = float(burst["radius"]) + ctx.tuning.add("area_radius")
	return burst


func _physics_process(delta: float) -> void:
	if ctx == null:
		return
	var playing: bool = ctx.flow.in_play()
	ctx.camera.shoulder_target = 1.0 if playing and ctx.player.kit.mounted else 0.0
	if not playing or ctx.run.class_def == null:
		return
	_clock += delta
	_since_slingshot += delta
	var had_overdrive := _overdrive > 0.0
	_overdrive = maxf(0.0, _overdrive - delta)
	if had_overdrive and _overdrive <= 0.0:
		clear_buff("overdrive")
	if _mounted_boost_left > 0.0:
		_mounted_boost_left = maxf(0.0, _mounted_boost_left - delta)
	if _spring_until >= 0.0 and _clock >= _spring_until:
		_spring_until = -1.0
		clear_buff("spring")
	if _pike_count > 0:
		var pike_row := _pike_row()
		if pike_row.is_empty() or _clock - _pike_last >= float(pike_row.get("idle_s", 3.0)):
			_pike_count = 0
			clear_buff("pike")
	_rocket_left = maxf(0.0, _rocket_left - delta)
	_tick_cloak(delta)
	_tick_upgrades(delta)
	_step_micro_mutations(delta)
	_step_escape_lane()
	var enemies_pre := get_tree().get_nodes_in_group(Groups.ENEMY)
	consumables.step(delta, enemies_pre)
	var intent = ctx.player.intent
	var weapon := active_weapon()
	var is_cards: bool = ctx.player.abilities.cap(AbilityState.WEAPON, "cards", null) != null
	var is_lane: bool = not is_cards and ctx.player.abilities.cap(AbilityState.WEAPON, "family", "") == "lane"
	var is_lob: bool = not is_cards and not is_lane and ctx.player.abilities.cap(AbilityState.WEAPON, "lob", 0) > 0
	var p: Resource = _patterns.get(weapon)
	var cadence_rate: float = _rate(weapon) if not is_cards and not is_lob and p != null else 0.0
	var shots: Array = weapon_driver.step(delta, intent, weapon, p, cadence_rate,
		_weapon_step_context(weapon, p, cadence_rate))
	if consumables.overclock_card_left() > 0.0 and not shots.is_empty():
		shots = consumables.apply_overclock_shots(shots, p)
	if is_cards:
		_step_cards(delta, shots)
	elif is_lane:
		for shot in shots:
			_fire_cannon_lane(weapon, shot)
	elif is_lob:
		_step_sticky_weapon(intent, delta, shots)
	else:
		for shot in shots:
			_fire(weapon, "weapon", shot)
	if is_lob:
		var wsnap: Dictionary = weapon_driver.state_snapshot()
		var snap_tok: int = int(wsnap.get("snap_token", 0))
		if snap_tok > 0:
			sticky.sync_snap_state(snap_tok, String(wsnap.get("window", "")))
	_step_cadence_micro(weapon, p, shots)
	_step_cast()
	_step_special(intent, delta)
	_step_line(intent, delta)
	_step_active_buffer(intent, delta)
	step_cannon(delta)
	var enemies := get_tree().get_nodes_in_group(Groups.ENEMY)
	_step_verb_items(enemies)
	_step_cross_synergies(delta, enemies)
	_step_grapple_mutations(delta, enemies)
	hero_hooks.step(delta, enemies)
	if relic_swaps != null: relic_swaps.step(delta, enemies)
	var shells := get_tree().get_nodes_in_group(Groups.ENEMY_SHOT)
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	bolts.step(delta, space, enemies, shells)
	for charge in sticky.step(delta, space, enemies):
		detonate(charge)
	_step_devices(delta)
	if ally_husks != null:
		ally_husks.step(delta, enemies)
	if orbitals != null:
		orbitals.step(delta, enemies)
	_step_deferred_procs()
	wear_trail.step(delta, enemies)
	PackPressure.observe(ctx.player.planar_velocity(), ctx.player.tuning.f("cruise"))
	churn.step(delta)
	boils.step(delta, enemies)
	_pin_step(enemies)
	_hulk_step(enemies, delta)
	_bat_by_ball(shells)
	_decay_shred(delta)
	_tint(enemies)


func _tint(enemies = null) -> void:
	var punch := punch_now()
	var ram := ram_punch_now()
	var pool: Array = enemies if enemies is Array else get_tree().get_nodes_in_group(Groups.ENEMY)
	for enemy in pool:
		if not is_instance_valid(enemy) or not enemy.has_method("set_tint") or enemy.is_dead() or enemy.plating <= 0.0:
			continue
		var against: float = ram if enemy.has_method("tint_verb") and enemy.tint_verb() == "ram" else punch
		enemy.set_tint("amber" if against >= plating_of(enemy) else "slate")


func add_shred(enemy: Node3D, punch: float) -> void:
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	if enemy.get("kind") == "warden":
		return
	var id := enemy.get_instance_id()
	var entry: Dictionary = _shred.get(id, {"amount": 0.0, "cap": 0.0, "idle": 0.0})
	if enemy.has_method("plating_now"):
		entry["cap"] = maxf(entry["cap"], enemy.plating_now())
	entry["amount"] = minf(entry["amount"] + punch * SHRED_PER_PUNCH, entry["cap"])
	entry["idle"] = 0.0
	_shred[id] = entry
	_show_shred(enemy, entry["amount"])


func _decay_shred(delta: float) -> void:
	if _shred.is_empty():
		return
	for id in _shred.keys():
		var enemy := instance_from_id(id) as Node3D
		if DamageDoor.dead(enemy):
			_shred.erase(id)
			continue
		var entry: Dictionary = _shred[id]
		entry["idle"] += delta
		var resting: bool = entry["idle"] > SHRED_GRACE
		entry["amount"] *= exp(-(SHRED_REST_DECAY if resting else SHRED_HOLD_DECAY) * delta)
		if resting and entry["amount"] < SHRED_FLOOR:
			_shred.erase(id)
			_show_shred(enemy, 0.0)
		else:
			_show_shred(enemy, entry["amount"])


func _show_shred(enemy: Node3D, amount: float) -> void:
	if enemy.has_method("set_shred"):
		enemy.set_shred(amount)


func _bat_by_ball(shells: Array) -> void:
	var dash_bat: bool = _air_dash_bat_left > 0.0 and _has_micro_mutation("dash_vane")
	if ctx.player.speed_tier() < SpeedTier.CRUISE and not dash_bat:
		return
	var reach := BAT_REACH + (float(_micro_row("dash_vane").get("reach_bonus", 0.6)) if dash_bat else 0.0)
	var ball: Vector3 = ctx.player.ball_position()
	for shell in shells:
		if is_instance_valid(shell) and not shell.returned and shell.global_position.distance_to(ball) <= reach:
			if _bat(shell) and dash_bat:
				_note_micro("dash_vane", {"at": shell.global_position})


func _bat(shell: Node3D) -> bool:
	if not is_instance_valid(shell) or not shell.bat():
		return false
	effects.spark(shell.global_position, Palette.AMBER)
	return true


func _rate(weapon: String) -> float:
	var rate: float = clampf(_patterns[weapon].rate * ctx.tuning.mod("weapon_rate"), Pattern.MIN_RATE, Pattern.MAX_RATE)
	if _overdrive > 0.0:
		rate *= Weapons.OVERDRIVE_RATE
	return rate


func _weapon_step_context(weapon: String, p: Resource, cadence_rate: float) -> Dictionary:
	var rate_mult := 1.0
	if p != null and cadence_rate > 0.0 and Weapons.BASE.has(weapon):
		var base_rate := float(Weapons.BASE[weapon].get("rate", 1.0))
		if base_rate > 0.0:
			rate_mult = cadence_rate / base_rate
	var reload_rate_mult := (rate_mult / Weapons.OVERDRIVE_RATE) if _overdrive > 0.0 else rate_mult
	var charge_rate := 1.0
	if weapon == Weapons.PYLON_TURRET:
		if _mounted_boost_left > 0.0:
			var banked: float = float(ctx.player.kit.mount_banked)
			charge_rate = WeaponDriver.charge_rate_for_tier(SpeedTier.of(banked, ctx.player.tuning.tier_cruise()))
	else:
		charge_rate = WeaponDriver.charge_rate_for_tier(ctx.player.speed_tier())
	var wg = ctx.player.abilities.gauge(AbilityState.WEAPON)
	var is_cards: bool = ctx.player.abilities.cap(AbilityState.WEAPON, "cards", null) != null
	var is_lob: bool = not is_cards and ctx.player.abilities.cap(AbilityState.WEAPON, "lob", 0) > 0
	var cast_cost: float = float(p.cast_cost) if is_cards and p != null else 1.0
	return {
		"rate_mult": rate_mult,
		"reload_rate_mult": reload_rate_mult,
		"charge_rate": charge_rate,
		"sprinting": bool(ctx.player.kit.sprinting),
		"planar_speed": ctx.player.planar_velocity().length(),
		"managed_gauge": is_lob,
		"managed_commit": is_cards,
		"slot_ready": ctx.player.abilities.ready(AbilityState.WEAPON, cast_cost),
		"lob_charging": wg != null and wg.charging,
		"recoil_airborne": cannon_recoil_airborne(),
	}


func _fire(weapon: String, source := "weapon", shot_desc := {}) -> void:
	var p: Resource = _patterns[weapon]
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var reach: float = p.range_m * ctx.tuning.mod("weapon_range")
	var damage: float = p.damage * damage_mod(weapon)
	var pierce_chip := false
	var extra_pierce := 0
	var no_chain := false
	var breaks_props := false
	var spark_count := 1
	var extra_spread := 0.0
	var knock_mult := 1.0
	var range_mult := 1.0
	if source == "weapon" and not shot_desc.is_empty():
		damage *= float(shot_desc.get("damage_mult", 1.0))
		extra_pierce = int(shot_desc.get("pierce_pass", 0))
		pierce_chip = bool(shot_desc.get("pierce", false)) or extra_pierce > 0 or int(p.pierce) > 0
		no_chain = bool(shot_desc.get("no_chain", false))
		breaks_props = bool(shot_desc.get("breaks_props", false)) or bool(p.breaks_props)
		spark_count = maxi(1, int(shot_desc.get("spark_count", 1)))
		extra_spread = float(shot_desc.get("spread_deg", 0.0))
		knock_mult = float(shot_desc.get("knock_mult", 1.0))
		range_mult = float(shot_desc.get("range_mult", 1.0))
	elif source == "weapon":
		pierce_chip = int(p.pierce) > 0
		breaks_props = bool(p.breaks_props)
	reach *= range_mult
	var sprung := source == "weapon" and spring_armed()
	if sprung:
		damage *= SPRING_MULT
		_spring_until = -1.0
		clear_buff("spring")
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, reach + AIM_SLACK)
	var point: Vector3 = aim["point"]
	var forward := point - ball
	if forward.length() < MUZZLE * 1.5:
		forward = ctx.aim_forward()
	forward = forward.normalized()
	if extra_spread > 0.0:
		var up_hint := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		var right := forward.cross(up_hint).normalized()
		var up := right.cross(forward).normalized()
		var phase := float(volleys) * 2.3999632
		var half_rad := deg_to_rad(extra_spread * 0.5)
		forward = (forward + (right * cos(phase) + up * sin(phase)) * tan(half_rad)).normalized()
	var muzzle := ball + forward * MUZZLE
	if sprung:
		effects.ring(muzzle, 1.5, Palette.VERDIGRIS)
	var layout_pat: Resource = p
	if source == "weapon" and spark_count > 1:
		layout_pat = p.copy()
		layout_pat.count = clampi(int(layout_pat.count) + spark_count - 1, 1, Pattern.MAX_VOLLEY)
		layout_pat.spread_deg = maxf(float(layout_pat.spread_deg), 6.0)
	var layout: Array = layout_pat.layout(forward, volleys)
	var shot: int = shot_bits() if source == "weapon" else 0
	var ricochet_carve: bool = source == "weapon" and ctx.player.state.carving and _has_cross_synergy("ricochet_canyon")
	var rc_row: Dictionary = Synergies.cross_system_row("ricochet_canyon") if ricochet_carve else {}
	var sixth_hot: bool = source == "weapon" and weapon == Weapons.RAPID_LASER and bool(shot_desc.get("sixth_hot", false))
	var pike := _pike_press(source)
	var fired := layout.size()
	if pike.get("ring", false):
		effects.ring(muzzle, PIKE_RING_RADIUS, Palette.COPPER)
	if pike.get("fuse", false):
		var centre: Dictionary = layout[0]
		for entry in layout:
			if entry["centre"]:
				centre = entry
				break
		var fused := pike_bolt(bolt_record(weapon, p, {"dir": forward, "centre": true, "phase": centre["phase"]}, muzzle, reach, damage, source, shot),
			layout.size(), _pike_row())
		fused["knock"] = float(fused["knock"]) * knock_mult
		if extra_pierce > 0:
			fused["pierce"] = int(fused["pierce"]) + extra_pierce
		if no_chain:
			fused["chain_jumps"] = 0
		if pierce_chip:
			fused["pierce_chip"] = true
		if breaks_props:
			fused["breaks_props"] = true
			fused["prop_break_radius"] = 2.2
		if ricochet_carve:
			_stamp_ricochet_canyon(fused, rc_row)
		if sixth_hot:
			hero_hooks.stamp_rivet_sixth_hot(fused)
		_evolve_record(fused, p)
		bolts.fire(fused)
		fired = 1
		_pike_cue()
	else:
		for entry in layout:
			var rec := bolt_record(weapon, p, entry, muzzle, reach, damage, source, shot)
			rec["knock"] = float(rec["knock"]) * knock_mult
			if extra_pierce > 0:
				rec["pierce"] = int(rec["pierce"]) + extra_pierce
			if no_chain:
				rec["chain_jumps"] = 0
			if pierce_chip:
				rec["pierce_chip"] = true
			if breaks_props:
				rec["breaks_props"] = true
				rec["prop_break_radius"] = 2.2
			if ricochet_carve:
				_stamp_ricochet_canyon(rec, rc_row)
			if sixth_hot:
				hero_hooks.stamp_rivet_sixth_hot(rec)
			bolts.fire(rec)
	if sixth_hot:
		var hfx = hero_hooks.hero_fx()
		if hfx != null:
			hfx.add_rivet_hot_tracer(muzzle, aim["to"])
		effects.beam(muzzle, aim["to"], Palette.COPPER, 0.16)
	if ricochet_carve:
		_note_cross("ricochet_canyon", {"extra_bounces": int(rc_row.get("extra_bounces", 2)), "bolts": fired})
	if source == "weapon" and breaks_props and weapon == Weapons.CLAW_SWEEP:
		ctx.break_props(muzzle + forward * (reach * 0.5), reach * 0.5, weapon)
	var beat3_lunge := false
	if source == "weapon" and weapon == Weapons.CLAW_SWEEP and String(shot_desc.get("kind", "")) == WeaponDriver.SHOT_BEAT_3:
		var tarn_claw = get_node_or_null("TarnClaw")
		if tarn_claw != null and tarn_claw.has_method("trigger_beat3_lunge"):
			tarn_claw.trigger_beat3_lunge(forward)
			beat3_lunge = true
	if rake_follows(source, ctx.player.abilities.cap(AbilityState.WEAPON, "mutation", "")):
		_rakes.append({"at": _clock + RAKE_DELAY, "weapon": weapon, "forward": forward,
			"damage": p.damage * damage_mod(weapon), "volley": volleys})
	if relic_swaps != null: relic_swaps.on_weapon_fire(weapon, source, shot_desc, muzzle, forward, reach, damage)
	volleys += 1
	last_shot = {"weapon_id": weapon, "from": muzzle, "to": aim["to"], "point": point,
		"blocked": aim["blocked"], "bolts": fired, "volley": volleys, "sprung": sprung, "fused": pike.get("fuse", false),
		"kind": String(shot_desc.get("kind", "plain")), "pierce_chip": pierce_chip,
		"beat": int(shot_desc.get("beat", 0)), "knock_mult": knock_mult, "breaks_props": breaks_props,
		"sixth_hot": sixth_hot, "instant_charge": bool(shot_desc.get("instant_charge", false)),
		"beat3_lunge": beat3_lunge}
	ctx.events.shot_fired.emit(weapon, muzzle, aim["to"])


func _pike_row() -> Dictionary:
	var build = ctx.build if ctx != null else null
	var held = build.get("effects") if build != null else null
	return held.pike_fuse() if held != null and held.has_method("pike_fuse") else {}


func _pike_press(source: String) -> Dictionary:
	if source != "weapon":
		return {}
	var row := _pike_row()
	if row.is_empty():
		_pike_count = 0
		clear_buff("pike")
		return {}
	var step := pike_advance(_pike_count, _pike_last, _clock, row)
	_pike_count = int(step["count"])
	_pike_last = _clock
	if _pike_count > 0:
		_post_buff("pike", {"icon": "pike", "tone": Palette.AMBER, "kind": BuffLedger.KIND_COUNT,
			"stacks": _pike_count, "max_stacks": maxi(1, int(row.get("every", 6)) - 1)})
	else:
		clear_buff("pike")
	return step


static func pike_advance(count: int, last: float, now: float, row: Dictionary) -> Dictionary:
	var every := int(row.get("every", 6))
	var n := 0 if now - last >= float(row.get("idle_s", 3.0)) else count
	n += 1
	var fuse := n >= every
	return {"count": 0 if fuse else n, "ring": n == every - 1, "fuse": fuse}


static func pike_bolt(record: Dictionary, volley_size: int, row: Dictionary) -> Dictionary:
	var out := record.duplicate()
	var one: float = float(record["damage"])
	out["damage"] = minf(one * volley_size, one * float(row.get("cap_mult", 6.0)))
	out["max_dist"] = float(record["max_dist"]) * float(row.get("range_mult", 1.25))
	out["radius"] = float(record["radius"]) * PIKE_RADIUS_MULT
	out["width_scale"] = PIKE_RADIUS_MULT
	out["color"] = ShotBits.TABLE["pierce"]["color"]
	out["bits"] = fused_bits(int(record.get("bits", 0)))
	return out


static func fused_bits(bits: int) -> int:
	var pierce := ShotBits.bit("pierce")
	if ShotBits.has(bits, pierce):
		return bits
	if ShotBits.count(bits) >= ShotBits.MAX_SHOT_BITS:
		for i in range(ShotBits.NAMES.size() - 1, -1, -1):
			var b := ShotBits.bit(ShotBits.NAMES[i])
			if ShotBits.has(bits, b):
				bits = ShotBits.without(bits, b)
				break
	return ShotBits.union(bits, pierce)


func _pike_cue() -> void:
	var presentation = ctx.root.get("presentation") if ctx != null and ctx.root != null else null
	var audio = presentation.get("audio") if presentation != null else null
	if audio != null:
		audio.play("shot_pierce", 0.0, 1.0, "SFX", String(ShotBits.TABLE["pierce"]["sound"]))


func _verb(effect_id: String) -> Dictionary:
	var build = ctx.build if ctx != null else null
	var held = build.get("effects") if build != null else null
	return held.verb_row(effect_id) if held != null and held.has_method("verb_row") else {}


func leash_scale() -> float:
	var row := _verb("line_leash")
	return maxf(1.0, float(row.get("load_mult", 1.0))) if not row.is_empty() else 1.0


func _weapon_hit() -> float:
	var weapon := active_weapon()
	var p: Resource = _patterns.get(weapon)
	return p.damage * damage_mod(weapon) if p != null else 0.0


func _lay_strip(item: String, from: Vector3, to: Vector3, width: float, damage: float, life: float, knock: float) -> Dictionary:
	_verb_serial += 1
	var strip := {"item": item, "layer": "verb_strip_%d" % _verb_serial, "damage": damage, "knock": knock,
		"until": _clock + life, "struck": {}, "hits": 0, "source": "item_proc", "bits": 0,
		"shape": ctx.player.yours({"kind": "line", "from": from, "to": to, "width": width})}
	ctx.player.indicator.set_shape(strip["layer"], strip["shape"])
	_strips.append(strip)
	_strike_strip(strip)
	last_strip = strip
	return strip


func _strike_strip(strip: Dictionary, enemies = null) -> void:
	var shape: Dictionary = strip["shape"]
	var pool: Array = enemies if enemies is Array else get_tree().get_nodes_in_group(Groups.ENEMY)
	for enemy in pool:
		if not is_instance_valid(enemy):
			continue
		var id: int = enemy.get_instance_id()
		if strip["struck"].has(id) or enemy.is_dead() \
				or not in_line(shape["from"], shape["to"], shape["width"], enemy.global_position, hull_radius(enemy)):
			continue
		strip["struck"][id] = true
		strip["hits"] = int(strip["hits"]) + 1
		deal_hit(enemy, SYNERGY, float(strip["damage"]), enemy.global_position - Vector3(shape["from"]), float(strip["knock"]),
			"", "item_proc", "proc")


func _step_verb_items(enemies = null) -> void:
	if not _strips.is_empty():
		for strip in _strips.duplicate():
			if _clock >= float(strip["until"]):
				ctx.player.indicator.clear(String(strip["layer"]))
				_strips.erase(strip)
			else:
				_strike_strip(strip, enemies)
	if not _bells.is_empty():
		for bell in _bells.duplicate():
			if _clock >= float(bell["at"]):
				_bells.erase(bell)
				_toll(bell, enemies)


func _clear_verb_items() -> void:
	if ctx != null and ctx.player != null and ctx.player.indicator != null:
		for record in _strips + _bells:
			ctx.player.indicator.clear(String(record["layer"]))
	_strips.clear()
	_bells.clear()
	_reel_hits = {}
	_reel_frame = -1
	_wake_frame = -1


func _on_wake_dash(dir: Vector3) -> void:
	var row := _verb("dash_wake")
	var frame := Engine.get_physics_frames()
	if row.is_empty() or ctx.run.class_def == null or _wake_frame == frame:
		return
	_wake_frame = frame
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length() > 0.01 else aim_heading()
	var from := _ground_under(ctx.player.ball_position())
	_lay_strip("dash_wake", from, from - flat * float(row.get("length", 4.0)), float(row.get("width", 2.0)),
		float(row.get("mult", 0.4)) * _weapon_hit(), float(row.get("life", 1.5)), float(row.get("knock", 4.0)))


func _note_reel(enemy: Node3D, dealt: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame != _reel_frame:
		_reel_frame = frame
		_reel_hits = {}
	var id := enemy.get_instance_id()
	_reel_hits[id] = float(_reel_hits.get(id, 0.0)) + dealt


func _on_reel_chain(enemy: Node3D, at: Vector3, _speed: float) -> void:
	var row := _verb("reel_chain")
	if row.is_empty() or _reel_frame != Engine.get_physics_frames() or _reel_hits.is_empty():
		return
	var first: Node3D = enemy if enemy != null and is_instance_valid(enemy) else null
	var damage := float(_reel_hits.get(first.get_instance_id(), 0.0)) if first != null else float(_reel_hits.values().max())
	_reel_hits = {}
	if damage <= 0.0:
		return
	var from: Vector3 = first.global_position if first != null else at
	var mult := float(row.get("mult", 0.7))
	var next := chain_hit(first, from, {"damage": damage, "chain_jumps": 1, "chain_falloff": mult,
		"chain_range": float(row.get("reach", 6.0)), "color": ctx.player.class_color(), "kind": SYNERGY,
		"knock": float(row.get("knock", 6.0)), "source": "item_proc", "bits": 0}, 1.0)
	last_reel_arc = {"from": from, "damage": damage * mult, "source": "item_proc", "bits": 0, "target": next}


func _on_slam_crack(at: Vector3, strength: float, _flatness: float) -> void:
	var row := _verb("slam_crack")
	if row.is_empty() or strength < 0.05 or ctx.run.class_def == null:
		return
	var heading: Vector3 = ctx.player.planar_velocity()
	heading.y = 0.0
	heading = heading.normalized() if heading.length() > 1.0 else aim_heading()
	var from := _ground_under(at)
	var length := float(row.get("length", 8.0))
	_lay_strip("slam_crack", from, from + heading * length, float(row.get("width", 2.5)),
		float(row.get("mult", 0.5)) * punch_of("slam", Augments.SLAM_KNOCK * strength), float(row.get("life", 0.5)),
		float(row.get("knock", 8.0)))
	for along in row.get("props", [2.0, 4.5, 7.0]):
		ctx.break_props(from + heading * minf(float(along), length), float(row.get("prop_radius", 2.5)), "faultline_cap")


func _bell_mark() -> Dictionary:
	return {"burst": last_burst}


func _ring_bell(id: String, shape: Dictionary, mark: Dictionary) -> void:
	var row := _verb("second_bell")
	if row.is_empty():
		return
	var bell := {"id": id, "at": _clock + float(row.get("delay", 1.0)), "source": "item_proc", "bits": 0,
		"knock": float(row.get("knock", 6.0)), "breaks": false}
	if shape.is_empty():
		if plate.is_empty() or String(last_card.get("card", "")) != id:
			return
		bell["mode"] = "gather"
		bell["shape"] = ctx.player.yours({"kind": "ring", "centre": plate["at"],
			"radius": Weapons.GATHER_RADIUS * float(row.get("gather_scale", 0.5))})
	else:
		if is_same(last_burst, mark["burst"]) or float(last_burst.get("damage", 0.0)) <= 0.0:
			return
		bell["mode"] = "pulse"
		bell["damage"] = float(last_burst["damage"]) * float(row.get("mult", 0.5))
		bell["limit"] = int(last_burst.get("targets", -1))
		bell["breaks"] = bool(last_burst.get("breaks_props", false))
		var drawn := {}
		for key in ["kind", "centre", "radius", "from", "to", "width", "apex", "dir", "length", "half_angle"]:
			if shape.has(key):
				drawn[key] = shape[key]
		bell["shape"] = ctx.player.yours(drawn)
	_verb_serial += 1
	bell["layer"] = "second_bell_%d" % _verb_serial
	ctx.player.indicator.set_shape(bell["layer"], bell["shape"])
	_bells.append(bell)


func _toll(bell: Dictionary, enemies = null) -> void:
	ctx.player.indicator.clear(String(bell["layer"]))
	var shape: Dictionary = bell["shape"]
	var color: Color = shape["color"]
	var hits := 0
	var pool: Array = enemies if enemies is Array else get_tree().get_nodes_in_group(Groups.ENEMY)
	if bell["mode"] == "gather":
		_gather_pull(shape["centre"], float(shape["radius"]), pool)
		effects.ring(shape["centre"], float(shape["radius"]), color)
	else:
		var origin := _shape_origin(shape)
		var found: Array = []
		for enemy in pool:
			if is_instance_valid(enemy) and not enemy.is_dead() and in_shape(shape, enemy):
				found.append([enemy.global_position.distance_to(origin), enemy])
		found.sort_custom(func(a, b): return a[0] < b[0])
		var limit: int = int(bell["limit"]) if int(bell["limit"]) >= 0 else found.size()
		for pair in found.slice(0, limit):
			var enemy: Node3D = pair[1]
			if not is_instance_valid(enemy) or enemy.is_dead():
				continue
			deal_hit(enemy, SYNERGY, float(bell["damage"]), enemy.global_position - origin, float(bell["knock"]), "", "item_proc", "proc")
			hits += 1
		_draw_shape(shape, color)
		if bell["breaks"]:
			for blast in _shape_blasts(shape):
				ctx.break_props(blast[0], blast[1], "second_bell")
	last_bell = bell.duplicate()
	last_bell["hits"] = hits
	last_bell["rung_at"] = _clock


static func in_shape(shape: Dictionary, enemy: Node3D) -> bool:
	match String(shape.get("kind", "")):
		"ring":
			return in_ring(shape["centre"], float(shape["radius"]), enemy)
		"line":
			return in_line(shape["from"], shape["to"], float(shape["width"]), enemy.global_position, hull_radius(enemy))
		"cone":
			var flat: Vector3 = enemy.global_position - Vector3(shape["apex"])
			flat.y = 0.0
			var hull := hull_radius(enemy)
			var reach := flat.length()
			if reach - hull > float(shape["length"]) * (1.0 + AbilityState.FORGIVENESS):
				return false
			if reach <= hull:
				return true
			var dir: Vector3 = shape["dir"]
			var off := acos(clampf((flat / reach).dot(Vector3(dir.x, 0.0, dir.z).normalized()), -1.0, 1.0))
			return off <= float(shape["half_angle"]) * (1.0 + AbilityState.FORGIVENESS) + atan2(hull, reach)
	return false


static func _shape_origin(shape: Dictionary) -> Vector3:
	match String(shape.get("kind", "")):
		"line":
			return shape["from"]
		"cone":
			return shape["apex"]
	return shape.get("centre", Vector3.ZERO)


static func _shape_blasts(shape: Dictionary) -> Array:
	match String(shape.get("kind", "")):
		"line":
			var from: Vector3 = shape["from"]
			var to: Vector3 = shape["to"]
			var r := maxf(float(shape["width"]) * 0.5, from.distance_to(to) / 6.0)
			return [[from.lerp(to, 1.0 / 6.0), r], [from.lerp(to, 0.5), r], [from.lerp(to, 5.0 / 6.0), r]]
		"cone":
			var half := float(shape["length"]) * 0.5
			return [[Vector3(shape["apex"]) + Vector3(shape["dir"]) * half, half]]
	return [[shape["centre"], float(shape["radius"])]]


func _draw_shape(shape: Dictionary, color: Color) -> void:
	match String(shape.get("kind", "")):
		"ring":
			effects.ring(shape["centre"], float(shape["radius"]), color)
		"line":
			effects.beam(shape["from"], shape["to"], color, Effects.RING_LIFE)
		"cone":
			var apex: Vector3 = shape["apex"]
			var dir: Vector3 = shape["dir"]
			for side in [-1.0, 0.0, 1.0]:
				var edge := dir.rotated(Vector3.UP, float(shape["half_angle"]) * side)
				effects.beam(apex, apex + edge * float(shape["length"]), color, Effects.RING_LIFE)


func bolt_record(weapon: String, p: Resource, entry: Dictionary, muzzle: Vector3, reach: float, damage: float, source: String, bits := 0) -> Dictionary:
	var record := {
		"origin": muzzle, "fired_from": muzzle, "dir": entry["dir"], "speed": p.speed, "max_dist": reach,
		"damage": damage, "kind": Weapons.strike_kind(weapon), "weapon_id": weapon, "radius": p.bolt_radius,
		"knock": p.knock, "chain_jumps": p.chain_jumps, "chain_range": p.chain_range,
		"chain_falloff": p.chain_falloff, "lattice_chain_falloff": p.lattice_chain_falloff, "color": Weapons.color(weapon),
		"wave_amp": 0.0 if entry["centre"] else p.wave_amp, "wave_hz": p.wave_hz, "phase": entry["phase"],
		"pierce": p.pierce,
		"source": source,
		"bits": bits,
	}
	_evolve_record(record, p)
	if orbitals != null:
		orbitals.stamp_bolt(record, p)
	return record


func _evolve_record(record: Dictionary, p: Resource) -> void:
	if String(record.get("source", "")) != "weapon":
		return
	if _has_grapeshot:
		record["split_angle_deg"] = GRAPESHOT_ANGLE_DEG
		record["split_knock"] = maxf(float(p.knock), Augments.SLAM_KNOCK * GRAPESHOT_KNOCK_SHARE)
	if _has_hoar and (int(p.pierce) > 0 or ShotBits.has(int(record.get("bits", 0)), ShotBits.bit("pierce"))):
		record["hoar"] = true
		record["hoar_spared"] = []


func _evolution_live(part_id: String) -> bool:
	return ctx != null and ctx.run != null and Synergies.evolved_live(part_id, ctx.run.parts)


func _field():
	var build = ctx.build if ctx != null else null
	return build.get("field") if build != null else null


func _on_bolt_flight(bolt: Dictionary, from: Vector3, to: Vector3) -> bool:
	_last_flight_breaks_props = bool(bolt.get("breaks_props", false)) and String(bolt.get("source", "")) == "weapon"
	_last_flight_break_radius = float(bolt.get("prop_break_radius", 2.2))
	_last_flight_weapon = String(bolt.get("weapon_id", "weapon"))
	if not bool(bolt.get("hoar", false)) or String(bolt.get("source", "")) != "weapon":
		return false
	var field = _field()
	if field == null or field.slab_count() < 1:
		return false
	var burst: Dictionary = field.detonate_crossed_slabs(from, to, bolt["dir"], ctx.player.ball_position(), BallTuning.RADIUS,
		"item_proc", bolt.get("hoar_spared", []))
	return int(burst["detonated"]) > 0


func _hoar_patch(bolt: Dictionary, at: Vector3, point: Vector3) -> void:
	var field = _field()
	if field == null:
		return
	var slab: Dictionary = field.frost_patch(at, HOAR_FROST_RADIUS, "item_proc")
	effects.frost_flash(point)
	if not slab.is_empty() and bolt.get("hoar_spared") is Array:
		(bolt["hoar_spared"] as Array).append(int(slab["id"]))


func _on_fault_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05 or not ctx.flow.in_play() or not _has_fault:
		return
	_aftershocks.append({"at": at, "radius": float(ctx.player.slam_radius()), "damage": fault_damage(strength, heft()),
		"born": _clock, "due": _clock + FAULT_DELAY})
	_draw_aftershock()


static func fault_damage(strength: float, pilot_heft: float) -> float:
	return Dunk.slam_damage(Augments.SLAM_KNOCK * strength, STRIKE_DAMAGE["slam"], pilot_heft) * FAULT_DAMAGE


func _tick_aftershocks() -> void:
	if _aftershocks.is_empty():
		return
	var due: Array = []
	var waiting: Array = []
	for shock in _aftershocks:
		if float(shock["due"]) <= _clock:
			due.append(shock)
		else:
			waiting.append(shock)
	_aftershocks = waiting
	for shock in due:
		_aftershock(shock)
	_draw_aftershock()


func _aftershock(shock: Dictionary) -> void:
	var at: Vector3 = shock["at"]
	var radius: float = shock["radius"]
	effects.shockwave(at, radius, ctx.player.class_color())
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var reach: float = enemy.global_position.distance_to(at)
		if reach > radius:
			continue
		if enemy.has_method("flash"):
			enemy.flash()
		strike(enemy, SYNERGY, float(shock["damage"]) * (1.0 - reach / radius), "", "item_proc")
	var field = _field()
	if field != null:
		field.shatter_slabs_in_ring(at, radius, "item_proc")
	ctx.break_props(at, radius, "fault_hammer")


static func _fault_layer(index: int) -> String:
	return FAULT_LAYER if index == 0 else "%s_%d" % [FAULT_LAYER, index]


func _draw_aftershock() -> void:
	var indicator = ctx.player.indicator
	for i in _aftershocks.size():
		var shock: Dictionary = _aftershocks[i]
		indicator.set_shape(_fault_layer(i), ctx.player.yours({"kind": "ring", "centre": shock["at"], "radius": shock["radius"],
			"fill": clampf((_clock - float(shock["born"])) / FAULT_DELAY, 0.0, 1.0)}))
	for i in range(_aftershocks.size(), _fault_layer_count):
		indicator.clear(_fault_layer(i))
	_fault_layer_count = _aftershocks.size()


func _clear_aftershocks() -> void:
	_aftershocks.clear()
	if ctx != null and ctx.player != null and ctx.player.indicator != null:
		for i in _fault_layer_count:
			ctx.player.indicator.clear(_fault_layer(i))
	_fault_layer_count = 0


static func rake_follows(source: String, mutation: String) -> bool:
	return source == "weapon" and mutation == "claw_rake"


func _tick_rakes() -> void:
	var waiting: Array = []
	for rake in _rakes:
		if float(rake["at"]) > _clock:
			waiting.append(rake)
		else:
			_rake_return(rake)
	_rakes = waiting


func _rake_return(rake: Dictionary) -> void:
	var weapon: String = rake["weapon"]
	if not _patterns.has(weapon):
		return
	var p: Resource = _patterns[weapon]
	var forward: Vector3 = rake["forward"]
	var muzzle: Vector3 = ctx.player.ball_position() + forward * MUZZLE
	var reach: float = p.range_m * ctx.tuning.mod("weapon_range")
	var damage: float = float(rake["damage"]) * RAKE_DAMAGE
	var up_hint := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var right := forward.cross(up_hint).normalized()
	var up := right.cross(forward).normalized()
	for entry in p.layout(forward, int(rake.get("volley", volleys))):
		var dir: Vector3 = entry["dir"]
		var mirrored := (forward * dir.dot(forward) - right * dir.dot(right) + up * dir.dot(up)).normalized()
		var bolt := bolt_record(weapon, p, {"dir": mirrored, "centre": entry["centre"], "phase": PI - float(entry["phase"])},
			muzzle, reach, damage, "item_proc")
		bolt["wave_hz"] = -float(p.wave_hz)
		bolt["bits"] = 0
		bolts.fire(bolt)


func _on_bolt_hit(bolt: Dictionary, enemy: Node3D, point: Vector3, part := "") -> void:
	effects.spark(point, bolt["color"])
	var from: Vector3 = enemy.global_position
	var damage: float = bolt["damage"]
	if bolt["kind"] == "claw":
		var id := enemy.get_instance_id()
		if float(_clamped.get(id, -INF)) > _clock:
			damage *= Weapons.CLAMP_BONUS
		else:
			_clamped.erase(id)
	var acts := int(bolt.get("acts", 0))
	if ShotBits.has(int(bolt.get("bits", 0)), ShotBits.bit("heat")):
		var heat := apply_heat(enemy, point)
		damage *= float(heat["mult"])
		if heat["lit"] or heat["bonus"]:
			acts = ShotBits.union(acts, ShotBits.bit("heat"))
	var pull_plan := _pull_plan(enemy, bolt) if Bolts.bit_ready(bolt, "pull") else {}
	var hit_knock := 0.0 if not pull_plan.is_empty() else float(bolt["knock"])
	var long_barrel_stagger := false
	if String(bolt.get("source", "")) == "weapon" and _has_micro_mutation("long_barrel"):
		var lb_row := _micro_row("long_barrel")
		var origin_pt: Vector3 = Vector3(bolt.get("fired_from", bolt["origin"]))
		var hit_dist := maxf(point.distance_to(origin_pt), float(bolt.get("travelled", 0.0)))
		if hit_dist > float(lb_row.get("min_range_m", 20.0)):
			hit_knock *= 1.0 + float(lb_row.get("knock_bonus", 0.15))
			long_barrel_stagger = true
			_note_micro("long_barrel", {"dist": hit_dist, "knock": hit_knock})
	var chip := Weapons.PIERCE_CHIP if bool(bolt.get("pierce_chip", false)) else CHIP
	deal_hit(enemy, bolt["kind"], damage, bolt["dir"], hit_knock, part, bolt.get("source", "weapon"), "", chip)
	if long_barrel_stagger and is_instance_valid(enemy) and not enemy.is_dead() and enemy.has_method("react"):
		enemy.react("stagger", bolt["dir"], true)
	if bool(bolt.get("breaks_props", false)) and String(bolt.get("source", "")) == "weapon":
		ctx.break_props(point, float(bolt.get("prop_break_radius", 2.2)), String(bolt.get("weapon_id", "weapon")))
	if bool(bolt.get("hoar", false)) and String(bolt.get("source", "")) == "weapon":
		_hoar_patch(bolt, from, point)
	if not pull_plan.is_empty() and is_instance_valid(enemy) and not enemy.is_dead():
		enemy.knock(pull_plan["dir"], float(pull_plan["force"]))
		acts = ShotBits.union(acts, ShotBits.bit("pull"))
		_check_gravity_ledger(enemy.global_position, [enemy])
	_bit_tell(acts, bolt, point)
	if bool(bolt.get("sixth_hot", false)) and not bool(bolt.get("sixth_hot_ricocheted", false)):
		hero_hooks.resolve_rivet_armor_ricochet(bolt, enemy, point, part)
	if bolt["chain_jumps"] > 0:
		chain_hit(enemy, from, bolt)
	if orbitals != null:
		orbitals.on_bolt_hit(bolt, enemy, point, part)


func _on_bolt_bounce(bolt: Dictionary, at: Vector3) -> void:
	if bool(bolt.get("sixth_hot", false)) and not bool(bolt.get("sixth_hot_ricocheted", false)):
		hero_hooks.resolve_rivet_wall_ricochet(bolt, at)
		return
	_bit_tell(ShotBits.bit("bounce"), bolt, at)
	if orbitals != null:
		orbitals.on_bolt_bounce(bolt, at)


static func hit_tell(acts: int) -> String:
	var tells := ShotBits.tells(acts)
	return String(tells[0]["sound"]) if not tells.is_empty() else ""


func _bit_tell(acts: int, bolt: Dictionary, point: Vector3) -> void:
	var sound := hit_tell(acts)
	if sound == "":
		return
	var bit_name := String(ShotBits.names(acts)[0])
	effects.bit_hit(bit_name, point, bolt["dir"], _bit_aim(bit_name, bolt, point),
		float(bolt.get("split_angle_deg", Bolts.SPLIT_ANGLE_DEG)))
	var presentation = ctx.root.get("presentation") if ctx != null and ctx.root != null else null
	var audio = presentation.get("audio") if presentation != null else null
	if audio != null:
		audio.play("shot_" + String(ShotBits.names(acts)[0]), 0.0, 1.0, "SFX", sound)


func _bit_aim(bit_name: String, bolt: Dictionary, point: Vector3) -> Vector3:
	if bit_name == "pull" and ctx != null and ctx.player != null:
		return ctx.player.ball_position() - point
	if bit_name == "bounce":
		var normal: Vector3 = bolt.get("origin", point) - point
		if normal.length_squared() > 0.000001:
			return -(bolt["dir"] as Vector3).bounce(normal.normalized())
	return Vector3.ZERO


func _pull_plan(enemy: Node3D, bolt: Dictionary) -> Dictionary:
	var nth := int(bolt.get("pulled", 0))
	bolt["pulled"] = nth + 1
	if not is_instance_valid(enemy) or enemy.is_dead():
		return {}
	var force := pull_force(heft(), Roster.heft_of(enemy), nth)
	var toward: Vector3 = ctx.player.ball_position() - enemy.global_position
	toward.y = 0.0
	if force <= 0.0 or toward.length() < 0.01:
		return {}
	return {"dir": toward.normalized(), "force": force}


static func pull_force(pilot_heft: float, body_heft: float, nth: int) -> float:
	if body_heft == INF or body_heft > pilot_heft:
		return 0.0
	return PULL_KNOCK * minf(pilot_heft / maxf(body_heft, 0.01), PULL_RATIO_CAP) * pow(PULL_FALLOFF, nth)


func shot_bits() -> int:
	var build = ctx.build if ctx != null else null
	return int(build.shot_bits()) if build != null and build.has_method("shot_bits") else 0


func apply_heat(enemy: Node3D, point: Vector3) -> Dictionary:
	var hit := heat_hit(_heated, enemy.get_instance_id(), _clock)
	if hit["lit"] or hit["bonus"]:
		effects.ring(point, hull_radius(enemy) + (0.6 if hit["bonus"] else 0.3), ShotBits.TABLE["heat"]["color"])
	return hit


func heated(enemy: Node3D) -> bool:
	return float(_heated.get(enemy.get_instance_id(), {}).get("glow", -INF)) > _clock


static func heat_hit(state: Dictionary, id: int, now: float) -> Dictionary:
	var entry: Dictionary = state.get(id, {"glow": -INF, "ready": -INF})
	var glowing := float(entry["glow"]) > now
	var bonus := glowing and now >= float(entry["ready"])
	if bonus:
		entry["ready"] = now + HEAT_GLOW
	entry["glow"] = now + HEAT_GLOW
	state[id] = entry
	return {"mult": HEAT_BONUS if bonus else 1.0, "lit": not glowing, "bonus": bonus}


func deal_proc_hit(enemy: Node3D, kind: String, damage: float, direction: Vector3, knock: float, part := "", source := "item_proc", impact := "", chip := CHIP) -> void:
	if door.in_pass():
		if _draining_procs:
			return
		_deferred_procs.append({"enemy": enemy, "kind": kind, "damage": damage, "direction": direction,
			"knock": knock, "part": part, "source": source, "impact": impact, "chip": chip})
		return
	deal_hit(enemy, kind, damage, direction, knock, part, source, impact, chip)


func _step_deferred_procs() -> void:
	if _deferred_procs.is_empty():
		return
	if ctx != null and ctx.run != null and not ctx.run.alive():
		_deferred_procs.clear()
		return
	var batch := _deferred_procs
	_deferred_procs = []
	_draining_procs = true
	for entry in batch:
		var enemy = entry["enemy"]
		if DamageDoor.dead(enemy):
			continue
		deal_hit(enemy, entry["kind"], float(entry["damage"]), entry["direction"], float(entry["knock"]),
			entry["part"], entry["source"], entry["impact"], float(entry["chip"]))
	_draining_procs = false



func deal_hit(enemy: Node3D, kind: String, damage: float, direction: Vector3, knock: float, part := "", source := "", impact := "", chip := CHIP) -> void:
	var push := Vector3(direction.x, 0.0, direction.z)
	push = push.normalized() if push.length() > 0.01 else Vector3.FORWARD
	enemy.knock(push + Vector3.UP * float(EventKinds.impact(impact if impact != "" else kind)["lift"]), knock)
	if enemy.has_method("react"):
		enemy.react(String(EventKinds.impact(impact if impact != "" else kind)["react"]), push, true)
	enemy.flash()
	strike(enemy, kind, damage, part, source, impact, chip)
	var id := enemy.get_instance_id()
	if _marks.has(id) and enemy.is_dead():
		var live: bool = _marks[id] > _clock
		_marks.erase(id)
		if live and _knob("mark_burst"):
			detonate({"pos": enemy.global_position, "radius": Weapons.BASE[Weapons.STICKY_CHARGE]["bolt_radius"],
				"damage": _patterns[Weapons.STICKY_CHARGE].damage * damage_mod(Weapons.STICKY_CHARGE), "crit": false, "born": _clock,
				"_source": "item_proc"})


func chain_hit(first: Node3D, from: Vector3, bolt: Dictionary, knock_scale := 0.5) -> Node3D:
	var visited := [first]
	var damage: float = bolt["damage"]
	var at := from
	var first_jump: Node3D = null
	for jump in int(bolt["chain_jumps"]):
		var falloff: float = bolt["chain_falloff"]
		if jump == int(bolt["chain_jumps"]) - 1 and float(bolt.get("lattice_chain_falloff", 0.0)) > 0.0:
			falloff = bolt["lattice_chain_falloff"]
		damage *= falloff
		var next := nearest_enemy(at, bolt["chain_range"], visited)
		if next == null:
			return first_jump
		if first_jump == null:
			first_jump = next
		visited.append(next)
		var to: Vector3 = next.global_position
		effects.arc(at, to, bolt["color"])
		deal_hit(next, bolt["kind"], damage, to - at, bolt["knock"] * knock_scale, "", bolt.get("source", "weapon"))
		at = to
	return first_jump


func nearest_enemy(at: Vector3, reach: float, exclude: Array) -> Node3D:
	var best: Node3D = null
	var best_distance := reach
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy in exclude or enemy.is_dead():
			continue
		var distance: float = enemy.global_position.distance_to(at)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best


func nearest_enemies(at: Vector3, reach: float, limit: int) -> Array:
	var found := []
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead():
			continue
		var distance: float = enemy.global_position.distance_to(at)
		if distance <= reach:
			found.append([distance, enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(limit, found.size()):
		out.append(found[i][1])
	return out


func _knob(name: String):
	return ctx.player.tree.knob(name)


func _clear_input_buffers() -> void:
	_special_buffer = 0.0
	_line_buffer = 0.0
	_active_buffer = 0.0


func _slot_ready_wait(abilities, slot_name: String) -> float:
	var s = abilities.slot(slot_name)
	if not s.available:
		return INF
	var wait := 0.0
	if abilities.silenced(slot_name):
		wait = maxf(wait, float(abilities.jam_left))
	if abilities.casting != AbilityState.UNSTARTED and abilities.casting != slot_name:
		wait = maxf(wait, float(abilities.cast_left))
	var payer_name: String = abilities.pool_of(slot_name)
	var payer = abilities.slot(payer_name)
	if payer.is_pressure:
		if payer.pressure_val + AbilityState.PRESSURE_EPS < 1.0:
			return INF
	elif payer.charges <= 0:
		var cd: float = abilities.cooldown_of(payer_name)
		if cd <= 0.0:
			return INF
		wait = maxf(wait, maxf(0.0, cd - payer.recharge))
	return wait


func _step_active_buffer(intent, delta: float) -> void:
	if actives == null or not actives.enabled() or actives.active_id == "":
		_active_buffer = 0.0
		return
	var had_buffer := _active_buffer > 0.0
	if had_buffer:
		_active_buffer = maxf(0.0, _active_buffer - delta)
	if intent.cancel_pressed:
		_active_buffer = 0.0
		had_buffer = false
	var row: Dictionary = actives.row_of(actives.active_id)
	var rate: float = ctx.tuning.mod("active_recharge") if ctx.tuning != null else 1.0
	var recharge_s: float = float(row.get("recharge", 0.0))
	var lock_wait: float = maxf(0.0, actives.lock_remaining() - delta)
	var charge_wait := 0.0
	if actives.charges < 1:
		if recharge_s > 0.0 and rate > 0.0:
			var prog_after: float = float(actives.progress) + delta * rate / recharge_s
			charge_wait = 0.0 if prog_after >= 1.0 else (1.0 - prog_after) * recharge_s / rate
		else:
			charge_wait = INF
	var ready_this_tick: bool = actives.winding <= 0.0 and lock_wait <= 0.0 and charge_wait <= 0.0
	var wait_s: float = maxf(maxf(lock_wait, charge_wait), float(actives.winding) if actives.winding > 0.0 else 0.0)
	if intent.active_pressed:
		if ready_this_tick:
			_active_buffer = 0.0
			return
		if wait_s <= BallTuning.ACTION_BUFFER_S + 0.0001:
			_active_buffer = BallTuning.ACTION_BUFFER_S
			intent.active_pressed = false
		return
	if had_buffer and ready_this_tick:
		_active_buffer = 0.0
		intent.active_pressed = true


func _step_special(intent, delta: float) -> void:
	var had_buffer := _special_buffer > 0.0
	if had_buffer:
		_special_buffer = maxf(0.0, _special_buffer - delta)
	if intent.cancel_pressed:
		_special_buffer = 0.0
		had_buffer = false
	var abilities = ctx.player.abilities
	var kit = ctx.player.kit
	var id: String = abilities.id_of(AbilityState.SPECIAL)
	var gauge = abilities.gauge(AbilityState.SPECIAL)
	if not _specials.has(id):
		return
	var row: Dictionary = _specials[id]
	if gauge == null:
		if abilities.casting == AbilityState.SPECIAL:
			if intent.special_pressed or intent.cancel_pressed:
				_special_buffer = 0.0
				var dropped: String = abilities.cancel_cast()
				if dropped != "":
					ctx.events.gauge_cancelled.emit(dropped, "cancel")
			return
		if row.has("tap"):
			if intent.special_pressed:
				if abilities.ready(AbilityState.SPECIAL) and abilities.casting == AbilityState.UNSTARTED:
					_special_buffer = 0.0
					_tap(AbilityState.SPECIAL, id, row["tap"], row.get("commit", Callable()))
				else:
					var tap_wait := _slot_ready_wait(abilities, AbilityState.SPECIAL)
					if tap_wait > 0.0 and tap_wait <= BallTuning.ACTION_BUFFER_S + 0.0001:
						_special_buffer = BallTuning.ACTION_BUFFER_S
					else:
						_tap(AbilityState.SPECIAL, id, row["tap"], row.get("commit", Callable()))
			elif had_buffer and abilities.ready(AbilityState.SPECIAL) and abilities.casting == AbilityState.UNSTARTED:
				_special_buffer = 0.0
				_tap(AbilityState.SPECIAL, id, row["tap"], row.get("commit", Callable()))
		return
	var auto: bool = _knob("mounted_autogauge") and kit.mounted
	if gauge.charging and (intent.special_pressed or intent.cancel_pressed):
		_special_buffer = 0.0
		gauge.cancel()
		ctx.player.indicator.collapse("special")
		ctx.events.gauge_cancelled.emit(id, "cancel")
		return
	if not gauge.charging and intent.special_pressed and not abilities.ready(AbilityState.SPECIAL):
		var wait := _slot_ready_wait(abilities, AbilityState.SPECIAL)
		if wait > 0.0 and wait <= BallTuning.ACTION_BUFFER_S + 0.0001:
			_special_buffer = BallTuning.ACTION_BUFFER_S
		else:
			_refuse_cast(AbilityState.SPECIAL, "cooling")
	if not gauge.charging and (intent.special_pressed or had_buffer or auto) and abilities.ready(AbilityState.SPECIAL) \
			and (not row.has("can") or row["can"].call()):
		_special_buffer = 0.0
		gauge.begin()
		ctx.events.gauge_charging.emit(id)
		if _knob("sprint_full_blast") and kit.sprinting:
			gauge.held = gauge.charge_max
	if not gauge.charging:
		ctx.player.indicator.clear("special")
		return
	var held: bool = (intent.special_held or auto) and not (_knob("sprint_full_blast") and kit.sprinting)
	var step: float = delta * (_knob("air_charge") if not ctx.player.state.on_floor() else 1.0)
	if not gauge.step(step, held):
		ctx.player.indicator.set_shape("special", row["geometry"].call(gauge.fraction()))
		return
	var f: float = gauge.fired_fraction
	var shape: Dictionary = row["geometry"].call(f)
	ctx.player.indicator.set_shape("special", shape)
	ctx.player.indicator.clear("special")
	if row.has("can") and not row["can"].call():
		ctx.events.gauge_cancelled.emit(id, "blocked")
		return
	abilities.spend(AbilityState.SPECIAL)
	last_committed = {"id": id, "fraction": f, "geometry": shape}
	var mark := _bell_mark()
	row["fire"].call(f, shape)
	if _knob("special_echo") > 0.0:
		_echo = {"row": row, "fraction": f * 0.6, "left": _knob("special_echo")}
	_ring_bell(id, shape, mark)
	ctx.events.gauge_released.emit(id, f)
	ctx.events.special_used.emit(id, ctx.player.ball_position())
	ctx.events.slot_cast.emit(AbilityState.SPECIAL, id, ctx.player.ball_position())


func _tap(slot: String, id: String, cast: Callable, commit := Callable()) -> void:
	var abilities = ctx.player.abilities
	if abilities.casting == slot:
		return
	if not abilities.ready(slot):
		_refuse_cast(slot, "cooling")
		return
	if abilities.cast_of(slot) > 0.0:
		var fire := cast
		if commit.is_valid():
			var aim: Dictionary = commit.call()
			if not bool(aim.get("valid", true)):
				_refuse_cast(slot, "no_target")
				return
			fire = cast.bind(aim)
		if not abilities.begin_cast(slot):
			_refuse_cast(slot, "cooling")
			return
		_cast_pending = {"slot": slot, "id": id, "fire": fire}
		ctx.events.gauge_charging.emit(id)
		return
	_land_tap(slot, id, cast)


func _step_cast() -> void:
	var done: String = ctx.player.abilities.take_cast_done()
	var swapped: String = ctx.player.abilities.take_swap_dropped()
	if _cast_pending.is_empty():
		return
	if swapped != "":
		ctx.player.indicator.collapse(String(_cast_pending["slot"]))
		ctx.events.gauge_cancelled.emit(swapped, "swap")
		_cast_pending = {}
		return
	if done == "":
		if ctx.player.abilities.casting == "":
			_cast_pending = {}
		return
	var pending := _cast_pending
	_cast_pending = {}
	if done == String(pending["slot"]):
		ctx.events.gauge_released.emit(String(pending["id"]), 1.0)
		_land_tap(done, String(pending["id"]), pending["fire"])


func _land_tap(slot: String, id: String, cast: Callable) -> void:
	var abilities = ctx.player.abilities
	if not abilities.ready(slot):
		_refuse_cast(slot, "cooling")
		return
	var mark := _bell_mark()
	if not bool(cast.call()):
		_refuse_cast(slot, "no_target")
		return
	abilities.spend(slot)
	var at: Vector3 = ctx.player.ball_position()
	if slot == AbilityState.SPECIAL:
		_ring_bell(id, {}, mark)
		ctx.events.special_used.emit(id, at)
	ctx.events.slot_cast.emit(slot, id, at)


func _refuse_cast(slot: String, reason: String) -> void:
	if reason == "cooling" and ctx.player.abilities.silenced(slot):
		reason = "jammed"
	if ctx.player.abilities.selected == slot:
		ctx.events.verb_failed.emit("fire", reason, ctx.player.ball_position())


func _tick_echo(delta: float) -> void:
	if _echo.is_empty():
		return
	_echo["left"] -= delta
	if _echo["left"] > 0.0:
		return
	var row: Dictionary = _echo["row"]
	var f: float = _echo["fraction"]
	_echo = {}
	if row.has("can") and not row["can"].call():
		return
	_echoing = true
	row["fire"].call(f, row["geometry"].call(f))
	_echoing = false


static func in_ring(centre: Vector3, radius: float, enemy: Node3D) -> bool:
	var flat := enemy.global_position - centre
	flat.y = 0.0
	return flat.length() - hull_radius(enemy) <= radius * (1.0 + AbilityState.FORGIVENESS)


static func in_line(from: Vector3, to: Vector3, width: float, point: Vector3, hull := 0.0) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var p := Vector2(point.x, point.z)
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return false
	var t := (p - a).dot(along / length)
	var slack := AbilityState.FORGIVENESS
	if t < -hull or t > length * (1.0 + slack) + hull:
		return false
	var side := absf((p - a).cross(along / length))
	return side - hull <= width * 0.5 * (1.0 + slack)


static func hull_radius(enemy: Node3D) -> float:
	return ActiveBase.enemy_girth(enemy, 1.0)


func _ground_under(at: Vector3) -> Vector3:
	return at + Vector3.DOWN * 0.9


func floor_at(at: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 80.0, PhysicsLayers.WORLD_MASK))
	return hit["position"] if not hit.is_empty() else _ground_under(at)


func aim_heading() -> Vector3:
	var dir: Vector3 = ctx.aim_forward()
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD


func _discharge_speed(f: float) -> float:
	var speed := maxf(f * Weapons.DISCHARGE_FULL_SPEED, 0.75 * ctx.player.state.velocity.length())
	if ctx.player.kit.mounted:
		speed = maxf(speed, ctx.player.kit.mount_banked)
	return speed


func discharge_geometry(f: float) -> Dictionary:
	var burst := discharge_preview(_discharge_speed(f))
	return ctx.player.yours({"kind": "ring", "centre": _ground_under(ctx.player.ball_position()), "radius": burst["radius"],
		"full_radius": discharge_preview(_discharge_speed(1.0))["radius"], "fill": f})


func fire_discharge(f: float, shape: Dictionary) -> void:
	var kit = ctx.player.kit
	var prev_source := _forced_source
	_forced_source = "special"
	_discharge(ctx.player.ball_position(), _discharge_speed(f), "turret" if kit.mounted else "arc", shape["centre"])
	_forced_source = prev_source


func _overdrive_geometry(f: float) -> Dictionary:
	return ctx.player.yours({"kind": "ring", "centre": _ground_under(ctx.player.ball_position()),
		"radius": Weapons.OVERDRIVE_RADIUS * AbilityState.Gauge.scaled(f, 1.0, Weapons.OVERDRIVE_FULL),
		"full_radius": Weapons.OVERDRIVE_RADIUS * Weapons.OVERDRIVE_FULL, "fill": f})


func _fire_overdrive(f: float, shape: Dictionary) -> void:
	var prev_source := _forced_source
	_forced_source = "special"
	_overdrive_blast(ctx.player.ball_position(), AbilityState.Gauge.scaled(f, 1.0, Weapons.OVERDRIVE_FULL), shape)
	_forced_source = prev_source


func _point_blank_geometry(f: float) -> Dictionary:
	var shape := _overdrive_geometry(f)
	shape["radius"] = float(shape["radius"]) * Weapons.POINT_BLANK_RADIUS
	shape["full_radius"] = float(shape["full_radius"]) * Weapons.POINT_BLANK_RADIUS
	return shape


func _fire_point_blank(f: float, shape: Dictionary) -> void:
	var prev_source := _forced_source
	_forced_source = "special"
	_overdrive_blast(ctx.player.ball_position(), AbilityState.Gauge.scaled(f, 1.0, Weapons.OVERDRIVE_FULL), shape,
		Weapons.POINT_BLANK_RADIUS, Weapons.POINT_BLANK_DAMAGE)
	_forced_source = prev_source


func _clamp_geometry(f: float) -> Dictionary:
	return ctx.player.yours({"kind": "ring", "centre": _ground_under(ctx.player.ball_position()),
		"radius": AbilityState.Gauge.scaled(f, Weapons.CLAMP_RADIUS_MIN, Weapons.CLAMP_RADIUS_MAX),
		"full_radius": Weapons.CLAMP_RADIUS_MAX, "fill": f})


func _fire_clamp(f: float, shape: Dictionary) -> void:
	var prev_source := _forced_source
	_forced_source = "special"
	var ball: Vector3 = ctx.player.ball_position()
	var centre: Vector3 = shape["centre"]
	var radius: float = shape["radius"]
	var damage := AbilityState.Gauge.scaled(f, Weapons.CLAMP_DAMAGE_MIN, Weapons.CLAMP_DAMAGE_MAX) * damage_mod(Weapons.CLAW_SWEEP)
	var seconds := AbilityState.Gauge.scaled(f, Weapons.CLAMP_SECONDS_MIN, Weapons.CLAMP_SECONDS_MAX)
	var hit := 0
	var pulled: Array = []
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead() or not in_ring(centre, radius, enemy):
			continue
		clamp_for(enemy, seconds)
		deal_hit(enemy, "claw", damage, ball - enemy.global_position, Weapons.CLAMP_KNOCK, "", "special", "clamp")
		if is_instance_valid(enemy) and not enemy.is_dead():
			pulled.append(enemy)
		hit += 1
	if not pulled.is_empty():
		_check_gravity_ledger(centre, pulled)
	var seized_enemy: Node3D = null
	if not _echoing and not pulled.is_empty() and ctx.run != null and ctx.run.class_def != null and ctx.run.class_def.id == "tarn":
		var tarn_claw = get_node_or_null("TarnClaw")
		if tarn_claw != null and tarn_claw.has_method("try_seize"):
			seized_enemy = tarn_claw.try_seize(pulled)
	effects.ring(centre, radius, ClassDef.TARN_COLOR)
	last_burst = {"at": centre, "radius": radius, "damage": damage, "hit": hit, "kind": "clamp",
		"breaks_props": false, "seized": seized_enemy != null}
	_forced_source = prev_source


func _cannon_phase() -> int:
	return clampi(ctx.stages.world_of(ctx.run.stage), 1, 3) if ctx.stages != null else 1


func _cannon_ground(p: Vector3) -> float:
	return floor_at(p + Vector3.UP).y


func commit_cannon(family: String, target: Vector3, centre: Vector3, radius: float, damage: float, source: String,
		expose := false, overrides := {}) -> Dictionary:
	_cannon_count += 1
	var seed: int = _cannon_count * 7919 + ctx.run.stage
	var phase := _cannon_phase()
	var descriptors: Array = MindAttacks.commit(family, seed, target, centre, phase, radius)
	var entry := {"family": family, "hazards": [], "damage": damage, "source": source, "struck": {}, "expose": expose,
		"verb": "", "window": 0.0, "seed": seed, "target": target, "centre": centre, "radius": radius, "phase": phase, "options": overrides, "noted": false, "born": _clock}
	for d in descriptors:
		d["id"] = "cannon_%s_%d" % [String(d["id"]).trim_prefix("mind_"), _cannon_count]
		for key in ["warn", "live", "from", "dir", "ahead", "half", "band"]:
			if overrides.has(key):
				d[key] = overrides[key]
		var h = Hazard.from_def(d)
		if overrides.has("warn"):
			h.warn_seconds = maxf(0.0, float(overrides["warn"]))
		h.color = overrides["color"] if overrides.has("color") else ClassDef.CANNON_COLOR
		h.ground = _cannon_ground
		ctx.root.add_child(h)
		entry["hazards"].append(h)
		if d.has("verb"):
			entry["verb"] = String(d["verb"])
			entry["window"] = float(d["weak_window"])
	_cannon.append(entry)
	return entry


func step_cannon(delta: float) -> void:
	_step_cannon_exposure()
	_step_cannon_recoil_airborne(delta)
	_step_cannon_piton()
	_track_wake()
	_step_cannon_paint()
	if ctx.player.abilities.selected == AbilityState.LINE and ctx.player.abilities.id_of(AbilityState.LINE) == "cannon_lane_charge" and ctx.player.kit.hooked:
		ctx.player.indicator.set_shape(AbilityState.LINE, _cannon_line_geometry(1.0))
	elif ctx.player.abilities.id_of(AbilityState.LINE) == "cannon_lane_charge":
		ctx.player.indicator.clear(AbilityState.LINE)
	if _cannon.is_empty():
		return
	var enemies := get_tree().get_nodes_in_group(Groups.ENEMY)
	var kept := []
	for entry in _cannon:
		var done := true
		for h in entry["hazards"]:
			if not is_instance_valid(h):
				continue
			var options: Dictionary = entry["options"]
			if options.has("live_at"):
				h.age = maxf(0.0, h.warn_seconds + _clock - float(options["live_at"]))
				h.step(0.0)
			else:
				h.step(delta)
			if h.is_live() and not entry["noted"]:
				entry["noted"] = true
				entry["live_clock"] = _clock
				_cannon_note(entry)
			if not h.is_done():
				done = false
			if h.is_live():
				_cannon_strike(entry, h, enemies)
		if done:
			for h in entry["hazards"]:
				if is_instance_valid(h):
					h.queue_free()
		else:
			kept.append(entry)
	_cannon = kept


func _cannon_strike(entry: Dictionary, h: Node3D, enemies: Array) -> void:
	for enemy in enemies:
		if DamageDoor.dead(enemy):
			continue
		var id: int = enemy.get_instance_id()
		if entry["struck"].has(id) or (enemy != entry["options"].get("forced") and not h.contains(enemy.global_position)):
			continue
		entry["struck"][id] = true
		var push: Vector3 = h.heading if h.shape == Hazard.Shape.LANE else enemy.global_position - h.centre
		var options: Dictionary = entry["options"]
		if options.has("budget"):
			var dealt := cannon_set_piece_hit(enemy, float(entry["damage"]), h.centre, false, false, options["budget"])
			var record: Dictionary = options["record"]
			if entry["struck"].size() == 1:
				record["zone_hits"] = int(record.get("zone_hits", 0)) + 1
			record["volley_hits"] = int(record.get("volley_hits", 0)) + 1
			record["damage"] = float(record.get("damage", 0.0)) + dealt
		else:
			var chip := Weapons.CANNON_AIR_RAIL_CHIP if bool(options.get("overpenetrate", false)) \
				else (Weapons.PIERCE_CHIP if bool(options.get("pierce_chip", false)) else CHIP)
			deal_hit(enemy, "cannon", float(entry["damage"]) * damage_mod(Weapons.CANNON_LANE), push, Weapons.CANNON_KNOCK, "", entry["source"], "", chip)
		if not entry.get("recital_checked", false):
			entry["recital_checked"] = true
			if entry["source"] != "item_proc":
				_cannon_recital(entry["family"], enemy.global_position)
			if options.has("discovery"):
				discover("cannon_lane_charge", enemy.global_position)
		if entry["expose"] and is_instance_valid(enemy) and not enemy.is_dead():
			_cannon_expose(enemy, float(entry["window"]), entry["verb"])


func _free_cannon() -> void:
	_recital_index = 0
	_recital_at = -INF
	_clear_exposed()
	for entry in _cannon:
		for h in entry["hazards"]:
			if is_instance_valid(h):
				if h.get_parent() != null:
					h.get_parent().remove_child(h)
				h.queue_free()
	_cannon = []
	_walk = {}
	_wake = {}
	_cannon_recoil_airborne = false
	_cannon_recoil_air_grace = 0.0
	_cannon_piton = {}
	_clear_cannon_paint()


func _clear_cannon_paint() -> void:
	last_cannon_paint = {}
	if ctx != null and ctx.player != null and ctx.player.get("indicator") != null:
		ctx.player.indicator.clear("cannon_paint")
		ctx.player.indicator.clear("cannon_bracket_l")
		ctx.player.indicator.clear("cannon_bracket_r")


func _cannon_lane_plan(reach_base: float, width_mult: float, allow_walk := true) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var reach: float = reach_base * ctx.tuning.mod("weapon_range")
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, reach + AIM_SLACK)
	var point: Vector3 = aim["point"]
	var centre := _ground_under(ball)
	var target := point
	if Vector2(point.x - centre.x, point.z - centre.z).length() < 1.5:
		target = centre + aim_heading() * 10.0
	var mutation: String = ctx.player.abilities.cap(AbilityState.WEAPON, "mutation", "")
	var walked := allow_walk and walk_extends(mutation, _walk, _clock)
	var half: float = MindAttacks.LANE_HALF * maxf(width_mult, Pattern.MIN_LOCK_WIDTH_MULT)
	var radius := reach
	var ahead: float = maxf(1.0, reach - half)
	var walk_od := 1.0
	if walked:
		walk_od = relic_swaps.overdrive_for(AbilityState.WEAPON) if relic_swaps != null else 1.0
		var walk_reach := WALK_REACH * walk_od
		var flat := Vector3(target.x - centre.x, 0.0, target.z - centre.z)
		var dir_w := flat.normalized() if flat.length_squared() > 0.0001 else aim_heading()
		var end_at: Vector3 = _walk["end"]
		centre = floor_at(end_at + Vector3.UP)
		target = centre + dir_w * 10.0
		radius = walk_reach + half
		ahead = walk_reach
	var flat_dir := Vector3(target.x - centre.x, 0.0, target.z - centre.z)
	var heading := flat_dir.normalized() if flat_dir.length_squared() > 0.0001 else aim_heading()
	return {
		"aim": aim, "point": point, "centre": centre, "target": target, "heading": heading,
		"radius": radius, "ahead": ahead, "half": half, "to": centre + heading * ahead,
		"walked": walked, "overdrive": walk_od, "mutation": mutation, "ball": ball,
	}


func _step_cannon_paint() -> void:
	var is_lane: bool = ctx.player.abilities.cap(AbilityState.WEAPON, "family", "") == "lane"
	var snap: Dictionary = weapon_driver.state_snapshot()
	if not is_lane or not bool(snap.get("painted", false)):
		if not last_cannon_paint.is_empty():
			_clear_cannon_paint()
		return
	var weapon := active_weapon()
	var p: Resource = _patterns.get(weapon)
	if p == null:
		_clear_cannon_paint()
		return
	var stage: String = String(snap.get("lock_stage", WeaponDriver.SHOT_PULSE))
	var reach_base: float = float(p.lock_pulse_reach) if float(p.lock_pulse_reach) > 0.0 else float(p.range_m)
	var width_mult: float = float(p.lock_pulse_width_mult)
	var color: Color = ClassDef.CANNON_COLOR
	var air_overpen := false
	if stage == WeaponDriver.SHOT_RAIL:
		reach_base = float(p.lock_rail_reach) if float(p.lock_rail_reach) > 0.0 else float(p.range_m)
		width_mult = float(p.lock_rail_width_mult)
		if cannon_recoil_airborne():
			width_mult *= Weapons.CANNON_AIR_RAIL_WIDTH_MULT
			air_overpen = true
		color = Palette.ARC
	elif stage == WeaponDriver.SHOT_BARRAGE:
		reach_base = float(p.range_m)
		width_mult = float(p.lock_barrage_width_mult)
		color = Palette.SLATE
	var plan := _cannon_lane_plan(reach_base, width_mult, true)
	var from: Vector3 = plan["centre"]
	var to: Vector3 = plan["to"]
	var half: float = float(plan["half"])
	var heading: Vector3 = plan["heading"]
	var side := Vector3.UP.cross(heading).normalized()
	var bracket_norm: float = float(snap.get("lock_bracket", 0.0))
	var bracket_gap: float = bracket_norm * 1.6
	var lane_shape := {"kind": "line", "from": from, "to": to, "full_to": to, "width": half * 2.0,
		"color": color, "ticks": "lane", "fill": 1.0 if stage == WeaponDriver.SHOT_RAIL else 0.5}
	var offset := side * (half + bracket_gap)
	var left_bracket := {"kind": "line", "from": from + offset, "to": to + offset, "width": 0.24, "color": color, "fill": 1.0}
	var right_bracket := {"kind": "line", "from": from - offset, "to": to - offset, "width": 0.24, "color": color, "fill": 1.0}
	ctx.player.indicator.set_shape("cannon_paint", lane_shape)
	ctx.player.indicator.set_shape("cannon_bracket_l", left_bracket)
	ctx.player.indicator.set_shape("cannon_bracket_r", right_bracket)
	last_cannon_paint = {"stage": stage, "from": from, "to": to, "ahead": float(plan["ahead"]),
		"half": half, "width": half * 2.0, "color": color, "bracket_gap": bracket_gap,
		"air_lock_overpen": air_overpen}


func _fire_cannon_lane(weapon: String, shot_desc := {}, source := "weapon") -> void:
	var p: Resource = _patterns.get(weapon)
	var shot_kind := String(shot_desc.get("kind", "plain"))
	var has_lock_desc := shot_desc.has("damage")
	var damage: float = float(shot_desc["damage"]) if has_lock_desc else (float(p.damage) if (p != null and String(p.trigger) == Pattern.TRIGGER_HOLD_AUTO) else Weapons.LANE_DAMAGE)
	var reach_base: float = float(shot_desc.get("reach", Weapons.CANNON_LANE_REACH)) if has_lock_desc else Weapons.CANNON_LANE_REACH
	var width_mult: float = float(shot_desc.get("width_mult", 1.0)) if has_lock_desc else 1.0
	var pierce: bool = source == "weapon" and bool(shot_desc.get("pierce", false))
	var air_lock_overpen: bool = source == "weapon" and bool(shot_desc.get("air_lock_overpen", false))
	var overpenetrate: bool = source == "weapon" and (bool(shot_desc.get("overpenetrate", false)) or air_lock_overpen)
	var breaks_props: bool = source == "weapon" and (bool(shot_desc.get("breaks_props", false)) or air_lock_overpen)
	var plan := _cannon_lane_plan(reach_base, width_mult, source == "weapon")
	var walk_od: float = float(plan["overdrive"])
	if bool(plan["walked"]):
		damage *= walk_od
	var aim: Dictionary = plan["aim"]
	var point: Vector3 = plan["point"]
	var ball: Vector3 = plan["ball"]
	var overrides := {"ahead": plan["ahead"], "half": plan["half"], "pierce_chip": pierce, "overpenetrate": overpenetrate}
	if shot_kind == WeaponDriver.SHOT_RAIL:
		overrides["color"] = Palette.SAND
	var entry := commit_cannon("lane", plan["target"], plan["centre"], plan["radius"], damage, source, false, overrides)
	var h = entry["hazards"][0]
	var kit = ctx.player.kit
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		var held: Vector3 = kit.anchor_body.global_position
		if h.contains(Vector3(held.x, h.ground_at(held) + 1.0, held.z)) and not h.contains(held):
			(entry["options"] as Dictionary)["forced"] = kit.anchor_body
	var end: Vector3 = (h.centre as Vector3) + (h.heading as Vector3) * float(h.length)
	if shot_kind == WeaponDriver.SHOT_RAIL:
		var side: Vector3 = Vector3.UP.cross(h.heading as Vector3).normalized() * float(h.half_width)
		effects.beam((h.centre as Vector3) + side, end + side, ClassDef.CANNON_COLOR, Effects.RING_LIFE)
		effects.beam((h.centre as Vector3) - side, end - side, ClassDef.CANNON_COLOR, Effects.RING_LIFE)
		if air_lock_overpen:
			effects.beam(h.centre as Vector3, end, Palette.SAND, Effects.RING_LIFE)
	var breached_props: Array[String] = []
	if air_lock_overpen:
		if ctx.destructibles != null and is_instance_valid(ctx.destructibles) and ctx.destructibles.has_method("on_rail_breach"):
			breached_props = ctx.destructibles.on_rail_breach(
				h.centre as Vector3, end, float(h.half_width), Weapons.CANNON_AIR_RAIL_MAX_TIER, "cannon_air_rail")
	elif breaks_props:
		for blast in _shape_blasts({"kind": "line", "from": h.centre, "to": end, "width": h.half_width * 2.0}):
			ctx.break_props(blast[0], float(blast[1]), "cannon_rail")
	if source == "weapon" and String(plan["mutation"]) == "cannon_lane_walk":
		_walk = {} if bool(plan["walked"]) else {"end": end, "at": _clock}
	if source == "weapon":
		_clear_cannon_paint()
	var muzzle: Vector3 = ball + h.heading * MUZZLE
	volleys += 1
	last_shot = {"weapon_id": weapon, "from": muzzle, "to": end, "point": point, "blocked": aim["blocked"], "bolts": 0,
		"volley": volleys, "sprung": false, "kind": shot_kind, "pierce_chip": pierce,
		"damage": damage, "overdrive": walk_od, "width_mult": width_mult, "reach": reach_base, "breaks_props": breaks_props,
		"air_lock_overpen": air_lock_overpen, "overpenetrate": overpenetrate, "breached_props": breached_props}
	ctx.events.shot_fired.emit(weapon, muzzle, end)


static func walk_extends(mutation: String, walk: Dictionary, clock: float) -> bool:
	return mutation == "cannon_lane_walk" and not walk.is_empty() and clock - float(walk["at"]) <= WALK_WINDOW


func _on_cannon_dashed(dir: Vector3) -> void:
	if ctx.player.abilities.cap(AbilityState.MOVEMENT, "family", "") != "split_lane":
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length() > 0.01 else aim_heading()
	var centre := _ground_under(ctx.player.ball_position())
	commit_cannon("split_lane", centre - flat * 10.0, centre, Weapons.RECOIL_REACH, Weapons.RECOIL_DAMAGE, "special")
	if cannon_piton_staked():
		ctx.player.set_velocity_now(Vector3.ZERO, "piton_stake")
		_cannon_piton["recoil_cancelled"] = true
		_cannon_recoil_airborne = false
		_cannon_recoil_air_grace = 0.0
		last_cannon_piton = {
			"mode": "stake",
			"at": _cannon_piton["anchor"],
			"recoil_cancelled": true,
			"hits": 0,
			"walls_broken": [],
		}
	else:
		_cannon_recoil_airborne = true
		_cannon_recoil_air_grace = Weapons.CANNON_RECOIL_AIR_GRACE_S


func _plate_geometry(f: float) -> Dictionary:
	return ctx.player.yours({"kind": "cone", "apex": _ground_under(ctx.player.ball_position()), "dir": aim_heading(),
		"length": 2.0 * MindAttacks.PLATE_HALF_BAND, "half_angle": MindAttacks.PLATE_HALF_SPAN, "fill": f})


func _fire_plate(f: float, shape: Dictionary) -> void:
	var apex: Vector3 = shape["apex"]
	var dir: Vector3 = shape["dir"]
	var damage := AbilityState.Gauge.scaled(f, Weapons.PLATE_DAMAGE_MIN, Weapons.PLATE_DAMAGE_MAX)
	commit_cannon("plate", apex + dir * MindAttacks.PLATE_HALF_BAND, apex, shape["length"], damage, "special", true)
	last_burst = {"at": apex, "damage": damage * damage_mod(Weapons.CANNON_LANE), "kind": "cannon_plate", "breaks_props": false}


func _on_cannon_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05 or ctx.player.abilities.cap(AbilityState.SMASH, "family", "") != "rush":
		return
	var landing := floor_at(at + Vector3.UP)
	var target := landing + aim_heading() * 6.0
	var best := Weapons.RUSH_REACH
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var d := Vector2(enemy.global_position.x - landing.x, enemy.global_position.z - landing.z).length()
		if d <= best:
			best = d
			target = enemy.global_position
	commit_cannon("rush", target, landing, Weapons.RUSH_REACH, Weapons.RUSH_DAMAGE * clampf(strength, 0.5, 1.5),
		"drop_or_slam")
	var from_recoil_surf := _cannon_recoil_airborne or _cannon_recoil_air_grace > 0.0
	_cannon_recoil_airborne = false
	_cannon_recoil_air_grace = 0.0
	if from_recoil_surf and ctx.player.abilities.cap(AbilityState.MOVEMENT, "family", "") == "split_lane":
		ctx.player.abilities.grant(AbilityState.MOVEMENT)
		effects.ring(landing, 3.0, Palette.ANCIENT)
		last_cannon_recoil_reset = {"at": landing, "clock": _clock}
	if wake_follows("drop_or_slam", ctx.player.abilities.cap(AbilityState.SMASH, "mutation", "")):
		_lay_wake(landing)


static func wake_follows(source: String, mutation: String) -> bool:
	return source == "drop_or_slam" and mutation == "cannon_rush_wake"


func _track_wake() -> void:
	if ctx.player.abilities.cap(AbilityState.SMASH, "mutation", "") != "cannon_rush_wake":
		if not _wake.is_empty():
			_wake.clear()
		return
	if ctx.player.kit.slamming:
		if _wake.is_empty() or float(_wake["until"]) < INF:
			_wake = {"from": ctx.player.ball_position(), "until": INF}
	elif not _wake.is_empty() and float(_wake["until"]) == INF:
		_wake["until"] = _clock + WAKE_GRACE


func _lay_wake(landing: Vector3) -> void:
	var wake := _wake
	_wake = {}
	if wake.is_empty() or _clock > float(wake["until"]):
		return
	var from: Vector3 = wake["from"]
	var back := Vector3(from.x - landing.x, 0.0, from.z - landing.z)
	back = back.normalized() if back.length() >= WAKE_MIN_TRAVEL else -aim_heading()
	var reach: float = Weapons.CANNON_LANE_REACH * ctx.tuning.mod("weapon_range")
	commit_cannon("lane", landing + back * 10.0, landing, reach, Weapons.LANE_DAMAGE * WAKE_DAMAGE, "item_proc")


const CannonAugments := preload("res://src/movement/augments.gd")
var _recital_index := 0
var _recital_at := -INF
static var _exposure_mesh: ArrayMesh
static var _exposure_material: ShaderMaterial


func cannon_audio():
	var presentation = ctx.root.get("presentation")
	return presentation.audio if presentation != null else null


func _cannon_note(entry: Dictionary) -> void:
	var audio = cannon_audio()
	if audio != null:
		var kind: String = {"weapon": "cannon_weapon", "line": "cannon_line_live", "drop_or_slam": "cannon_smash"}.get(entry["source"], "cannon_live")
		if entry["family"] == "split_lane" and entry["source"] == "special" and not entry["options"].has("budget"):
			kind = "cannon_recoil"
		audio.cannon_family(entry["family"], false, kind)


func _cannon_line_geometry(fraction: float) -> Dictionary:
	var kit = ctx.player.kit
	var ball: Vector3 = ctx.player.ball_position()
	var from := _ground_under(ball)
	var dir := aim_heading()
	var ahead := Weapons.CANNON_LANE_REACH - MindAttacks.LANE_HALF
	if kit.hooked and kit.on_body:
		dir = Vector3(kit.anchor.x - ball.x, 0.0, kit.anchor.z - ball.z).normalized()
		if dir.length() < 0.01:
			dir = aim_heading()
		ahead = Vector2(kit.anchor.x - ball.x, kit.anchor.z - ball.z).length() + Weapons.LANE_CHARGE_PAST
	elif kit.hooked:
		var floor = cannon_floor(kit.anchor)
		if floor != null:
			from = floor
			var normal: Vector3 = kit.anchor_normal
			if absf(normal.y) < 0.7 and Vector2(normal.x, normal.z).length() > 0.01:
				dir = Vector3(normal.x, 0.0, normal.z).normalized()
		else:
			dir = Vector3(kit.anchor.x - ball.x, 0.0, kit.anchor.z - ball.z).normalized()
			if dir.length() < 0.01:
				dir = aim_heading()
	return ctx.player.yours({"kind": "line", "from": from, "to": from + dir * ahead,
		"full_to": from + dir * ahead, "width": MindAttacks.LANE_HALF * 2.0, "fill": fraction})


func _cannon_line_body(target: Node3D, fraction: float, mult: float) -> void:
	_cannon_line_fire(fraction, mult, target)


func _cannon_line_world(anchor: Vector3, fraction: float, mult: float) -> void:
	_cannon_line_fire(fraction, mult, null)
	_arm_cannon_piton(anchor, ctx.player.kit.anchor_normal, mult)


func _cannon_line_fire(fraction: float, mult: float, target: Node3D) -> void:
	var shape := _cannon_line_geometry(fraction)
	var from: Vector3 = shape["from"]
	var to: Vector3 = shape["to"]
	commit_cannon("lane", to, from, from.distance_to(to) + MindAttacks.LANE_HALF,
		Weapons.LANE_CHARGE_DAMAGE * mult, "line", false,
		{"warn": Weapons.LANE_CHARGE_WARN, "live": Weapons.LANE_CHARGE_LIVE,
		"from": from, "dir": (to - from).normalized(), "ahead": from.distance_to(to), "forced": target,
		"discovery": "cannon_lane_charge"})
	var audio = cannon_audio()
	if audio != null:
		audio.cannon_line(ctx.player.chain.combo)


func cannon_floor(at: Vector3):
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1,
		at - Vector3.UP * Weapons.VOID_DROP, CannonAugments.WORLD_MASK))
	return hit["position"] if not hit.is_empty() and (hit["normal"] as Vector3).y >= 0.7 else null


func _cannon_recital(family: String, at: Vector3) -> void:
	if _clock - _recital_at > Weapons.RECITAL_SECONDS:
		_recital_index = 0
	if family == MindAttacks.FAMILIES[_recital_index]:
		if _recital_index == 0:
			_recital_at = _clock
		_recital_index += 1
	elif family == "lane":
		_recital_at = _clock
		_recital_index = 1
	else:
		_recital_index = 0
	if _recital_index == MindAttacks.FAMILIES.size():
		_recital_index = 0
		discover("cannon_recital", at)
		var audio = cannon_audio()
		if audio != null:
			audio.cannon_motif("cannon_recital", true)


func cannon_set_piece_hit(enemy: Node3D, damage: float, at: Vector3, landing: bool, mortar: bool, budget: Dictionary) -> float:
	if enemy.has_method("_apply_posture") and enemy.has_method("staggered"):
		if landing and enemy.staggered():
			return ult_hit(enemy, "ultimate", damage, at, true)
		var judged: Dictionary = enemy.judge_hit("slam" if landing else "cannon",
			damage if landing else damage * Ultimate.WARDEN_VOLLEY, landing, 0)
		var id := enemy.get_instance_id()
		var spent := float(budget.get(id, 0.0))
		judged["gain"] = minf(float(judged.get("gain", 0.0)), maxf(0.0, Ultimate.cap_for_warden(enemy) - spent))
		judged["shatter"] = false
		judged["crack"] = false
		budget[id] = spent + float(judged["gain"])
		enemy._apply_posture(judged)
		effects.spark(enemy.global_position + Vector3.UP, Palette.SLATE)
		return 0.0
	return ult_hit(enemy, "slam" if mortar and landing else "ultimate", damage, at, landing)


func _cannon_expose(enemy: Node3D, window: float, verb: String) -> void:
	var id := enemy.get_instance_id()
	var mark: MeshInstance3D = enemy.get_node_or_null("CannonExposure")
	if mark == null:
		if _exposure_mesh == null:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 24:
				if i % 6 == 0:
					continue
				var a := TAU * i / 24.0
				var b := TAU * (i + 0.8) / 24.0
				for p in [Vector2(a, 1.1), Vector2(b, 1.1), Vector2(a, 1.25),
					Vector2(b, 1.1), Vector2(b, 1.25), Vector2(a, 1.25)]:
					surface.add_vertex(Vector3(cos(p.x) * p.y, 0.12, sin(p.x) * p.y))
			_exposure_mesh = surface.commit()
			_exposure_material = ShaderMaterial.new()
			var shader := Shader.new()
			shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform vec4 tint : source_color; instance uniform float left = 1.0; void fragment(){ ALBEDO = tint.rgb; ALPHA = left; }"
			_exposure_material.shader = shader
			_exposure_material.set_shader_parameter("tint", Palette.ANCIENT)
			_exposure_mesh.surface_set_material(0, _exposure_material)
		mark = MeshInstance3D.new()
		mark.name = "CannonExposure"
		mark.mesh = _exposure_mesh
		enemy.add_child(mark)
	mark.set_instance_shader_parameter("left", 1.0)
	_exposed[id] = {"until": _clock + window, "verb": verb, "window": window, "mark": mark}


static var _arc_mark_mesh: ArrayMesh


static func _arc_key(id: int) -> String:
	return "arc:%d" % id


func _arc_marked(enemy: Node3D) -> bool:
	return float(_exposed.get(_arc_key(enemy.get_instance_id()), {}).get("until", -INF)) > _clock


func _arc_mark(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	var radius := hull_radius(enemy)
	var mark: MeshInstance3D = enemy.get_node_or_null("ArcMark")
	if mark == null or mark.is_queued_for_deletion():
		mark = arc_mark_view()
		enemy.add_child(mark)
	var parent_scale: Vector3 = enemy.global_basis.get_scale()
	mark.scale = Vector3(radius / maxf(parent_scale.x, 0.0001), 1.0, radius / maxf(parent_scale.z, 0.0001))
	mark.set_instance_shader_parameter("left", 1.0)
	_exposed[_arc_key(id)] = {"kind": ARC_MARK_KIND, "id": id, "until": _clock + ARC_MARK_SECONDS,
		"window": ARC_MARK_SECONDS, "radius": radius, "mark": mark}


static func arc_mark_view() -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.name = "ArcMark"
	mark.mesh = _arc_ring()
	return mark


static func _arc_ring() -> ArrayMesh:
	if _arc_mark_mesh != null:
		return _arc_mark_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		if i % 4 == 3:
			continue
		var a := TAU * i / 16.0
		var b := TAU * (i + 0.7) / 16.0
		for p in [Vector2(a, 0.86), Vector2(b, 0.86), Vector2(a, 1.0),
			Vector2(b, 0.86), Vector2(b, 1.0), Vector2(a, 1.0)]:
			surface.add_vertex(Vector3(cos(p.x) * p.y, 0.14, sin(p.x) * p.y))
	_arc_mark_mesh = surface.commit()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform vec4 tint : source_color; instance uniform float left = 1.0; void fragment(){ ALBEDO = tint.rgb; ALPHA = left; }"
	material.shader = shader
	material.set_shader_parameter("tint", Palette.ARC)
	_arc_mark_mesh.surface_set_material(0, material)
	return _arc_mark_mesh


func _drop_exposed(key) -> void:
	var row = _exposed.get(key)
	if row is Dictionary:
		var mark = row.get("mark")
		if is_instance_valid(mark):
			if mark.get_parent() != null:
				mark.get_parent().remove_child(mark)
			mark.queue_free()
	_exposed.erase(key)


func _clear_exposed() -> void:
	for key in _exposed.keys():
		_drop_exposed(key)


func _step_cannon_exposure() -> void:
	for key in _exposed.keys():
		var row: Dictionary = _exposed[key]
		var left := float(row["until"]) - _clock
		var mark = row.get("mark")
		if left <= 0.0 or not is_instance_valid(instance_from_id(int(row.get("id", key)))):
			_drop_exposed(key)
		elif is_instance_valid(mark):
			mark.set_instance_shader_parameter("left", left / float(row["window"]))

const LINE_LOAD_SECONDS := 4.0
const LINE_REEL_DAMAGE := 10.0
const LINE_REEL_KNOCK := 12.0
const REEL_BURST := 8.0

var _cast_pending := {}
var _armour_known := {}
var _bite_pending := false


func line_load() -> Dictionary:
	return _line_load.duplicate()


func _bite_load() -> void:
	if not _line_load.is_empty():
		_bite_pending = true


func _step_line(intent, delta: float) -> void:
	var had_buffer := _line_buffer > 0.0
	if had_buffer:
		_line_buffer = maxf(0.0, _line_buffer - delta)
	if intent.cancel_pressed:
		_line_buffer = 0.0
		had_buffer = false
	var abilities = ctx.player.abilities
	var kit = ctx.player.kit
	if _bite_pending:
		_bite_pending = false
		if not _line_load.is_empty() and kit.hooked:
			var waiting := _line_load
			_line_load = {}
			_fire_line_skill(String(waiting["id"]), float(waiting["fraction"]))
			discover("loaded_line", kit.anchor)
	if not _line_load.is_empty():
		_line_load["left"] = float(_line_load["left"]) - delta
		if float(_line_load["left"]) <= 0.0:
			var gone := String(_line_load["id"])
			_line_load = {}
			ctx.events.line_skill_expired.emit(gone)
	var id: String = abilities.id_of(AbilityState.LINE)
	if not _line_skills.has(id):
		return
	var gauge = abilities.gauge(AbilityState.LINE)
	var fraction := 1.0
	if gauge != null:
		if gauge.charging and (intent.line_pressed or intent.cancel_pressed):
			_line_buffer = 0.0
			gauge.cancel()
			ctx.player.indicator.collapse(AbilityState.LINE)
			ctx.events.gauge_cancelled.emit(id, "cancel")
			return
		if not gauge.charging:
			if intent.line_pressed:
				if _line_load.is_empty() and abilities.ready(AbilityState.LINE):
					_line_buffer = 0.0
					gauge.begin()
					ctx.events.gauge_charging.emit(id)
				else:
					var load_wait := float(_line_load["left"]) if not _line_load.is_empty() else 0.0
					var wait := maxf(load_wait, _slot_ready_wait(abilities, AbilityState.LINE))
					if wait > 0.0 and wait <= BallTuning.ACTION_BUFFER_S + 0.0001:
						_line_buffer = BallTuning.ACTION_BUFFER_S
					else:
						_line_cast_ok()
			elif had_buffer and _line_load.is_empty() and abilities.ready(AbilityState.LINE):
				_line_buffer = 0.0
				gauge.begin()
				ctx.events.gauge_charging.emit(id)
		if not gauge.charging:
			ctx.player.indicator.clear(AbilityState.LINE)
			return
		if not gauge.step(delta, intent.line_held):
			ctx.player.indicator.set_shape(AbilityState.LINE, _line_skills[id]["geometry"].call(gauge.fraction()))
			return
		ctx.player.indicator.clear(AbilityState.LINE)
		fraction = gauge.fired_fraction
		if not abilities.ready(AbilityState.LINE) or not _line_load.is_empty():
			ctx.events.gauge_cancelled.emit(id, "blocked")
			return
		ctx.events.gauge_released.emit(id, fraction)
	elif intent.line_pressed:
		if _line_load.is_empty() and abilities.ready(AbilityState.LINE):
			_line_buffer = 0.0
		else:
			var load_wait := float(_line_load["left"]) if not _line_load.is_empty() else 0.0
			var wait := maxf(load_wait, _slot_ready_wait(abilities, AbilityState.LINE))
			if wait > 0.0 and wait <= BallTuning.ACTION_BUFFER_S + 0.0001:
				_line_buffer = BallTuning.ACTION_BUFFER_S
			else:
				_line_cast_ok()
			return
	elif had_buffer and _line_load.is_empty() and abilities.ready(AbilityState.LINE):
		_line_buffer = 0.0
	else:
		return
	_cast_line(id, fraction)


func _line_cast_ok() -> bool:
	if not _line_load.is_empty():
		ctx.events.verb_failed.emit("select", "loaded", ctx.player.ball_position())
		return false
	if not ctx.player.abilities.ready(AbilityState.LINE):
		_refuse_cast(AbilityState.LINE, "cooling")
		return false
	return true


func _cast_line(id: String, fraction: float) -> void:
	var abilities = ctx.player.abilities
	abilities.spend(AbilityState.LINE)
	ctx.events.slot_cast.emit(AbilityState.LINE, id, ctx.player.ball_position())
	if ctx.player.kit.hooked:
		_fire_line_skill(id, fraction)
		return
	var seconds := float(AbilityState.ABILITIES.get(id, {}).get("load_seconds", LINE_LOAD_SECONDS)) * leash_scale()
	_line_load = {"id": id, "fraction": fraction, "left": seconds}
	ctx.events.line_skill_loaded.emit(id, seconds)


func _fire_line_skill(id: String, fraction: float) -> void:
	var row: Dictionary = _line_skills.get(id, {})
	if row.is_empty():
		return
	var kit = ctx.player.kit
	var mult := float(ctx.player.chain.multiplier())
	var target: Node3D = kit.anchor_body if kit.on_body and is_instance_valid(kit.anchor_body) and not (id == "bank_shot" and Augments.anchor_line(kit.anchor_body)) else null
	var at: Vector3 = kit.anchor
	var on := "body" if target != null else "world"
	var prev_source := _forced_source
	_forced_source = "special"
	if target != null:
		row["on_body"].call(target, fraction, mult)
	else:
		row["on_world"].call(at, fraction, mult)
	_forced_source = prev_source
	last_line = {"id": id, "on": on, "target": target, "at": at, "fraction": fraction, "mult": mult}
	ctx.events.line_skill_fired.emit(id, target, at, on)


func _line_reel_body(target: Node3D, _fraction: float, mult: float) -> void:
	if target.has_method("is_dead") and target.is_dead():
		return
	deal_hit(target, "line", LINE_REEL_DAMAGE * mult, ctx.player.ball_position() - target.global_position, LINE_REEL_KNOCK, "", "special")


func _ult_volley(_beat: int, ball: Vector3, aim: Vector3, _heft_mult: float) -> int:
	var picks: Array = []
	var bias := deg_to_rad(Ultimate.VOLLEY_BIAS_DEG)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if DamageDoor.dead(enemy):
			continue
		var gap: float = enemy.global_position.distance_to(ball)
		if gap > Ultimate.VOLLEY_RADIUS:
			continue
		var to: Vector3 = enemy.global_position - ball
		var biased: bool = aim.length() > 0.01 and to.length() > 0.01 and aim.angle_to(to) <= bias
		picks.append([(0.0 if biased else 100.0) + gap, enemy])
	picks.sort_custom(func(a, b): return a[0] < b[0])
	var weapon := active_weapon()
	var kind := weapon if weapon != "" else "ultimate"
	var hits := 0
	for entry in picks.slice(0, ultimate.volley_targets()):
		var enemy: Node3D = entry[1]
		effects.arc(ball + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, ctx.player.class_color())
		ult_hit(enemy, kind, Ultimate.VOLLEY_DAMAGE * _heft_mult, ball, false)
		hits += 1
	return hits


func _ult_peak(at: Vector3) -> void:
	effects.ring(at, Ultimate.VOLLEY_RADIUS, ctx.player.class_color())


func _ult_landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	var radius: float = ultimate.landing_radius()
	effects.ring(at, radius, ctx.player.class_color())
	ctx.break_props(at, radius, "ultimate")
	var hits := 0
	var dealt := 0.0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if DamageDoor.dead(enemy):
			continue
		if enemy.global_position.distance_to(at) > radius:
			continue
		dealt += ult_hit(enemy, "ultimate", Ultimate.LANDING_DAMAGE * heft_mult * chain_mult, at, true)
		hits += 1
	return [hits, dealt]


func ult_hit(enemy: Node3D, kind: String, damage: float, from: Vector3, landing: bool) -> float:
	if enemy.has_method("_apply_posture") and enemy.has_method("staggered"):
		if landing and enemy.staggered():
			discover("set_piece_core", enemy.global_position)
			var held: Node3D = ctx.player.smash_landing
			ctx.player.smash_landing = enemy
			deal_hit(enemy, "slam", damage, enemy.global_position - from, 0.0, "", "special", "slam")
			ctx.player.smash_landing = held
			return damage
		var punch := damage if landing else damage * Ultimate.WARDEN_VOLLEY
		ultimate.warden_posture(enemy, enemy.judge_hit("slam" if landing else kind, punch, landing, 0))
		effects.spark(enemy.global_position + Vector3.UP, Palette.SLATE)
		return 0.0
	if target_class_of(enemy) == "boss":
		damage *= Ultimate.BOSS_MULT
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, kind, damage, "", "special")
		return damage
	deal_hit(enemy, kind, damage, enemy.global_position - from, Ultimate.LANDING_KNOCK if landing else 3.0, "", "special",
		"slam" if landing else "")
	return damage


func reel_burst(anchor: Vector3, _fraction: float, _mult: float) -> void:
	var body: RigidBody3D = ctx.player.body()
	var toward: Vector3 = anchor - body.global_position
	if toward.length() > 0.01:
		body.linear_velocity += toward.normalized() * REEL_BURST


func line_reel_geometry(f: float) -> Dictionary:
	var ball: Vector3 = ctx.player.ball_position()
	var kit = ctx.player.kit
	var to: Vector3 = kit.anchor if kit.hooked else ball + aim_heading() * ctx.player.grapple_range()
	return ctx.player.yours({"kind": "line", "from": ball, "to": to, "width": 1.0, "full_to": to, "fill": f})


func _reset_cards() -> void:
	bay = 0
	plate = {}
	link_group = {}
	last_card = {}
	_arcing = false
	_gather_tick = 0.0
	_roll_clock = 0.0
	_restored_frame = {}
	_clear_clip_post()
	_clear_tally_piece()
	_clear_ink()
	tally_last_settle = {}
	_tally_cards = {}
	if ally_husks != null:
		ally_husks.reset()


func _wire_tally() -> void:
	var ev = ctx.events
	ev.dashed.connect(func(_dir: Vector3):
		if ctx.player.abilities.id_of(AbilityState.MOVEMENT) == "flywheel_surge":
			_grant_pressure(Weapons.SURGE_PRESSURE)
			if ally_husks != null and ghost_shift_unlocked():
				ally_husks.start_surge_overclock())
	ev.line_skill_fired.connect(func(id: String, _target: Node3D, at: Vector3, _on: String):
		if not id in CLIP_IDS:
			return
		_stage_clip_casts += 1
		if _stage_clip_casts >= PUNCH_TAPE_CASTS:
			_tally_discover("tally_punch_tape", "loaded_line", at))
	ev.stage_entered.connect(func(_stage: int, _retry: bool):
		_stage_clip_casts = 0
		_clear_clip_post())
	ev.stage_content_cleared.connect(func(_reason: String): _clear_ink())
	ev.player_died.connect(_clear_ink)
	ev.run_started.connect(func(_class_id: String):
		_run_settles = 0
		_stage_clip_casts = 0)
	ev.ultimate_started.connect(func(id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		_clear_tally_piece()
		if id in TALLY_PIECES:
			tally_piece = id)
	ev.ultimate_cancelled.connect(func(_id: String, _reason: String, _refunded: bool): _clear_tally_piece())
	ev.synergy_discovered.connect(func(_id: String, _category: String, _first: bool):
		_tally_card_frame = Engine.get_physics_frames())


func _step_cards(delta: float, shots: Array) -> void:
	var abilities = ctx.player.abilities
	var cards: Array = abilities.cap(AbilityState.WEAPON, "cards", [])
	bay = clampi(bay, 0, cards.size() - 1)
	abilities.slot(AbilityState.WEAPON).icon = String(Weapons.CARDS.get(cards[bay], {}).get("icon", ""))
	_step_plate(delta)
	if not link_group.is_empty() and float(link_group["until"]) <= _clock:
		link_group = {}
	_step_roll_restore(delta)
	_step_clip_post()
	_step_clip_preview()
	_step_tally_piece(delta)
	_step_tally_cards()
	_step_ink()
	if shots.is_empty():
		return
	var card: String = cards[bay]
	if not _cards.has(card):
		return
	var aim := card_aim()
	var shot: Dictionary = shots[0]
	var ok: bool = _run_balance(aim["point"], aim["valid"], shot, "weapon") if card == "balance_due" \
		else bool(_cards[card].call(aim["point"], aim["valid"]))
	if not ok:
		return
	var p: Resource = _patterns.get(Weapons.LEDGER_READER)
	if p != null and String(p.trigger) == Pattern.TRIGGER_STAMP:
		var paid: bool = bool(shot.get("paid", false))
		weapon_driver.commit_stamp(paid, 1.0)
		if paid:
			var safe_cost: float = maxf(float(shot.get("cast_cost", p.cast_cost)), Pattern.MIN_CAST_COST)
			var safe_refund: float = clampf(float(shot.get("refund", 0.0)), 0.0, safe_cost)
			if safe_refund > 0.0:
				_grant_pressure_amount(safe_refund)
				last_card["refund"] = safe_refund
	else:
		weapon_driver.commit_recovery(Weapons.CARD_RECOVERY)
	ctx.events.shot_fired.emit(card, ctx.player.ball_position(), aim["point"])


func card_aim() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, Weapons.CARD_REACH + AIM_SLACK)
	var point: Vector3 = aim["point"]
	return {"point": point, "valid": not aim["blocked"] and ball.distance_to(point) <= Weapons.CARD_REACH}


func _tap_gather(aim := {}) -> bool:
	if aim.is_empty():
		aim = card_aim()
	if not _run_gather(aim["point"], aim["valid"]):
		return false
	ctx.events.shot_fired.emit("gather_plate", ctx.player.ball_position(), aim["point"])
	return true


func is_ordinary(enemy: Node3D) -> bool:
	var kind := _spawn_kind_of(enemy)
	if kind in ["chaser", "lobber"]:
		return target_class_of(enemy) == "enemy"
	return Roster.has(kind) and Roster.faction_of(kind) == Roster.SWARM and target_class_of(enemy) == "adds"


func _step_plate(delta: float) -> void:
	if plate.is_empty():
		return
	if float(plate["until"]) <= _clock:
		plate = {}
		return
	_gather_tick += delta
	while _gather_tick >= Weapons.GATHER_TICK:
		_gather_tick -= Weapons.GATHER_TICK
		_gather_pull(plate["at"], float(plate.get("radius", Weapons.GATHER_RADIUS)))


func _gather_pull(at: Vector3, radius: float, enemies = null) -> void:
	var pool: Array = enemies if enemies is Array else get_tree().get_nodes_in_group(Groups.ENEMY)
	var pulled: Array = []
	for enemy in pool:
		if not is_instance_valid(enemy) or enemy.is_dead() or not is_ordinary(enemy):
			continue
		var inward: Vector3 = at - enemy.global_position
		inward.y = 0.0
		var distance := inward.length()
		if distance > radius or distance < 0.01:
			continue
		enemy.knock(inward / distance, Weapons.GATHER_KNOCK * clampf(distance / radius, 0.25, 1.0))
		pulled.append(enemy)
	if not pulled.is_empty():
		_check_gravity_ledger(at, pulled)


func _step_roll_restore(delta: float) -> void:
	var abilities = ctx.player.abilities
	var s = abilities.slot(AbilityState.WEAPON)
	var p: Resource = _patterns.get(Weapons.LEDGER_READER)
	var fractional: bool = p != null and String(p.trigger) == Pattern.TRIGGER_STAMP
	if fractional:
		if abilities.pressure_of(AbilityState.WEAPON) + AbilityState.PRESSURE_EPS >= float(s.max_charges):
			_roll_clock = 0.0
			return
		var planar: float = ctx.player.planar_velocity().length()
		if not ctx.player.state.on_floor() or SpeedTier.of(planar, ctx.player.tuning.f("cruise")) < SpeedTier.CRUISE:
			return
		_grant_pressure_amount(delta / Weapons.PRESSURE_ROLL_S)
		return
	if s.charges >= s.max_charges:
		_roll_clock = 0.0
		return
	var planar: float = ctx.player.planar_velocity().length()
	if not ctx.player.state.on_floor() or SpeedTier.of(planar, ctx.player.tuning.f("cruise")) < SpeedTier.CRUISE:
		return
	_roll_clock += delta
	while _roll_clock >= Weapons.PRESSURE_ROLL_S:
		_roll_clock -= Weapons.PRESSURE_ROLL_S
		_grant_pressure(1)


func _grant_pressure(count: int) -> void:
	var abilities = ctx.player.abilities
	if count > 0 and abilities.cap(AbilityState.WEAPON, "pressure", null) != null:
		abilities.grant(AbilityState.WEAPON, count)


func _grant_pressure_amount(amount: float) -> void:
	var abilities = ctx.player.abilities
	if amount > 0.0 and abilities.cap(AbilityState.WEAPON, "pressure", null) != null:
		abilities.grant_amount(AbilityState.WEAPON, amount)


func _spend_card(card: String, at: Vector3, cost := 1.0) -> bool:
	if not ctx.player.abilities.spend(AbilityState.WEAPON, cost):
		return false
	last_card = {"card": card, "at": at, "hits": 0, "spent": true, "cost": cost, "paid": false, "refund": 0.0}
	return true


func _run_gather(point: Vector3, valid: bool) -> bool:
	if not valid:
		return false
	last_card = {"card": "gather_plate", "at": point, "hits": 0, "spent": false}
	var at := floor_at(point + Vector3.UP)
	plate = {"at": at, "until": _clock + Weapons.GATHER_SECONDS}
	_gather_tick = 0.0
	effects.ring(at, Weapons.GATHER_RADIUS, Palette.COPPER)
	if ally_husks != null and ghost_shift_unlocked():
		ally_husks.raise_in_radius(at, Weapons.GATHER_RADIUS)
	return true


func _run_balance(point: Vector3, valid: bool, shot_desc := {}, source := "weapon") -> bool:
	if not valid:
		return false
	var p: Resource = _patterns.get(Weapons.LEDGER_READER)
	var is_stamp_mode: bool = p != null and String(p.trigger) == Pattern.TRIGGER_STAMP
	var is_proc: bool = source != "weapon"
	var cost: float = maxf(float(shot_desc.get("cast_cost", p.cast_cost if p != null else 1.0)), Pattern.MIN_CAST_COST)
	if not is_proc:
		if not _spend_card("balance_due", point, cost):
			_refuse_cast(AbilityState.WEAPON, "cooling")
			return false
	var speed: float = ctx.player.planar_velocity().length()
	var paid: bool = is_stamp_mode and not is_proc and bool(shot_desc.get("paid", false))
	var damage: float
	if is_stamp_mode:
		var weight := clampf((Weapons.STAMP_BASE + Weapons.STAMP_PER_SPEED * speed) / Weapons.STAMP_MAX, 0.0, 1.0)
		var raw: float = float(p.damage) * weight
		if paid:
			raw *= float(shot_desc.get("damage_mult", 1.0))
			var bonus: float = float(shot_desc.get("streak_bonus", 0.0))
			if bonus > 0.0:
				raw += bonus * weight
				var cap: float = float(shot_desc.get("streak_cap", 0.0))
				if cap > 0.0:
					raw = minf(raw, cap * weight)
		damage = raw * damage_mod(Weapons.LEDGER_READER)
	else:
		damage = minf(Weapons.BALANCE_MAX, Weapons.BALANCE_BASE + Weapons.BALANCE_PER_SPEED * speed) * damage_mod(Weapons.LEDGER_READER)
	var hits := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead() or not in_ring(point, Weapons.BALANCE_RADIUS, enemy):
			continue
		ledger_hit(enemy, damage, point, Weapons.LEDGER_KNOCK, source)
		hits += 1
		if paid:
			effects.ring(enemy.global_position, 1.35, Palette.AMBER)
			effects.spark(enemy.global_position + Vector3.UP * 1.1, Palette.AMBER)
		if not is_proc:
			_settle_ink(enemy)
	var cue_color: Color = Palette.LEDGER_CREAM if paid else Palette.COPPER
	effects.ring(point, Weapons.BALANCE_RADIUS, cue_color)
	if paid:
		effects.ring(point, Weapons.BALANCE_RADIUS * 0.72, Palette.AMBER)
		effects.shockwave(point, Weapons.BALANCE_RADIUS, Palette.LEDGER_CREAM)
	if not is_proc:
		last_card["hits"] = hits
		last_card["damage"] = damage
		last_card["paid"] = paid
		last_card["stamp_color"] = cue_color
		if relic_swaps != null: relic_swaps.on_ledger_cast(point, damage, shot_desc)
	return true


func _clip_geometry(_f: float) -> Dictionary:
	var kit = ctx.player.kit
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		return _clip_ring(kit.anchor_body.global_position, Weapons.LINK_NEIGHBOUR_REACH)
	var at: Vector3 = kit.anchor if kit.hooked else ctx.player.ball_position() + aim_heading() * ctx.player.grapple_range()
	return _clip_ring(at, Weapons.CLIP_POST_RADIUS)


func _clip_ring(centre: Vector3, radius: float) -> Dictionary:
	return ctx.player.yours({"kind": "ring", "centre": centre, "radius": radius, "full_radius": radius, "fill": 1.0, "ticks": "square"})


func _step_clip_preview() -> void:
	var abilities = ctx.player.abilities
	if abilities.selected == AbilityState.LINE and abilities.id_of(AbilityState.LINE) in CLIP_IDS and ctx.player.kit.hooked:
		ctx.player.indicator.set_shape("tally_clip", _clip_geometry(1.0))
	else:
		ctx.player.indicator.clear("tally_clip")


func _link_clips_body(target: Node3D, _fraction: float, mult: float) -> void:
	_clear_clip_post()
	_link_from(target, mult, _clip_ring(target.global_position, Weapons.LINK_NEIGHBOUR_REACH))
	if ally_husks != null and ghost_shift_unlocked() and is_instance_valid(target):
		ally_husks.raise_drive_by(target.global_position)


func _link_clips_world(anchor: Vector3, fraction: float, mult: float) -> void:
	reel_burst(anchor, fraction, mult)
	link_group = _new_link_group(Weapons.CLIP_POST_SECONDS, mult)
	clip_post = {"at": anchor, "until": _clock + Weapons.CLIP_POST_SECONDS, "shape": _clip_ring(anchor, Weapons.CLIP_POST_RADIUS)}
	ctx.player.indicator.set_shape("tally_post", clip_post["shape"])
	effects.ring(anchor, Weapons.CLIP_POST_RADIUS, Palette.COPPER)
	last_card = {"card": "link_clips", "at": anchor, "hits": 0, "spent": false}
	if ally_husks != null and ghost_shift_unlocked():
		ally_husks.raise_drive_by(anchor)


func _link_from(first: Node3D, mult := 1.0, shape := {}) -> int:
	var centre: Vector3 = shape.get("centre", first.global_position)
	var radius: float = shape.get("radius", Weapons.LINK_NEIGHBOUR_REACH)
	var clips := [first]
	for enemy in nearest_enemies(centre, radius * 2.0, 16):
		if clips.size() > Weapons.LINK_NEIGHBOURS:
			break
		if enemy != first and in_ring(centre, radius, enemy):
			clips.append(enemy)
	link_group = _new_link_group(Weapons.LINK_SECONDS, mult)
	for clip in clips:
		_add_clip(clip)
	last_card = {"card": "link_clips", "at": first.global_position, "hits": clips.size(), "spent": false}
	if clips.size() > Weapons.LINK_NEIGHBOURS:
		_tally_discover("tally_skim", "loaded_line", first.global_position)
	return clips.size()


func _new_link_group(seconds: float, mult: float) -> Dictionary:
	return {"ids": [], "until": _clock + seconds, "spent": false, "mult": mult, "jumped": false,
		"double": ctx.player.abilities.cap(AbilityState.LINE, "mutation", "") == "link_double"}


func _add_clip(enemy: Node3D) -> void:
	(link_group["ids"] as Array).append(enemy.get_instance_id())
	link_group["until"] = maxf(float(link_group["until"]), _clock + Weapons.LINK_SECONDS)
	effects.arc(ctx.player.ball_position(), enemy.global_position, Palette.AMBER)
	_grant_pressure(Weapons.CLIP_PRESSURE)


func _step_clip_post() -> void:
	if clip_post.is_empty():
		return
	if float(clip_post["until"]) <= _clock or link_group.is_empty():
		_clear_clip_post()
		return
	var ids: Array = link_group["ids"]
	var at: Vector3 = clip_post["at"]
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if ids.size() >= Weapons.CLIP_POST_MAX:
			break
		if not is_instance_valid(enemy) or enemy.is_dead() or ids.has(enemy.get_instance_id()):
			continue
		if in_ring(at, Weapons.CLIP_POST_RADIUS, enemy):
			_add_clip(enemy)
			last_card["hits"] = ids.size()
	if ids.size() >= Weapons.CLIP_POST_MAX:
		_tally_discover("tally_skim", "loaded_line", at)
		_clear_clip_post()


func _clear_clip_post() -> void:
	clip_post = {}
	if ctx != null and ctx.player != null:
		ctx.player.indicator.clear("tally_post")


func _on_card_struck(enemy: Node3D, kind: String, force: float) -> void:
	if kind == "ram" or kind == "stomp":
		var frame := Engine.get_physics_frames()
		if int(_restored_frame.get(kind, -1)) != frame:
			_restored_frame[kind] = frame
			_grant_pressure(1)
	if _arcing or link_group.is_empty() or link_group["spent"] or float(link_group["until"]) <= _clock:
		return
	var ids: Array = link_group["ids"]
	if not is_instance_valid(enemy) or not ids.has(enemy.get_instance_id()):
		return
	link_group["spent"] = true
	var from: Vector3 = enemy.global_position
	var damage := maxf(Weapons.LINK_ARC_MIN, force * Weapons.LINK_ARC_SHARE) * float(link_group.get("mult", 1.0))
	_arcing = true
	for id in ids:
		if id == enemy.get_instance_id():
			continue
		var other = instance_from_id(id)
		if other == null or not is_instance_valid(other) or other.is_dead():
			continue
		var to: Vector3 = other.global_position
		effects.arc(from, to, Palette.AMBER)
		ledger_hit(other, damage, from, Weapons.LEDGER_KNOCK, "weapon")
	if bool(link_group.get("double", false)) and not bool(link_group.get("jumped", false)):
		link_group["jumped"] = true
		_clip_jump(from, damage)
	_arcing = false


func _clip_jump(from: Vector3, damage: float) -> void:
	var ids: Array = link_group["ids"]
	var best: Node3D = null
	var best_gap := INF
	for other in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(other) or DamageDoor.dead(other) or ids.has(other.get_instance_id()):
			continue
		var gap: float = other.global_position.distance_to(from)
		if gap <= Weapons.LINK_NEIGHBOUR_REACH and gap < best_gap:
			best = other
			best_gap = gap
	if best == null:
		return
	link_group["jump_to"] = best.get_instance_id()
	effects.arc(from, best.global_position, Palette.AMBER)
	ledger_hit(best, damage, from, Weapons.LEDGER_KNOCK, "item_proc")


func _book_ink(at: Vector3) -> void:
	var reach: float = ctx.player.slam_radius()
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or DamageDoor.dead(enemy) or (enemy.global_position - at).length() > reach:
			continue
		var id: int = enemy.get_instance_id()
		var row: Dictionary = _ink.get(id, {})
		if row.is_empty() or not is_instance_valid(row["mark"]):
			row = {"mark": _ink_mark(enemy)}
		row["until"] = _clock + INK_SECONDS
		_ink[id] = row


func _settle_ink(enemy: Node3D) -> void:
	var id := enemy.get_instance_id()
	if not _ink.has(id):
		return
	var live: bool = float(_ink[id]["until"]) > _clock
	_drop_ink(id)
	if live:
		_grant_pressure(1)
		last_card["ink"] = int(last_card.get("ink", 0)) + 1


func _step_ink() -> void:
	for id in _ink.keys():
		var row: Dictionary = _ink[id]
		var enemy = instance_from_id(id)
		var left := float(row["until"]) - _clock
		if enemy == null or not is_instance_valid(enemy) or DamageDoor.dead(enemy) or left <= 0.0:
			_drop_ink(id)
		elif is_instance_valid(row["mark"]):
			row["mark"].visible = left > 0.75 or int(left * 8.0) % 2 == 0


func _drop_ink(id: int) -> void:
	var mark = _ink.get(id, {}).get("mark")
	if is_instance_valid(mark):
		if mark.get_parent() != null:
			mark.get_parent().remove_child(mark)
		mark.queue_free()
	_ink.erase(id)


func _clear_ink() -> void:
	for id in _ink.keys():
		_drop_ink(id)


func _ink_mark(enemy: Node3D) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.name = "InkTick"
	mark.mesh = _ink_tick()
	enemy.add_child(mark)
	var parent_scale: Vector3 = enemy.global_basis.get_scale()
	mark.scale = Vector3(1.0 / maxf(parent_scale.x, 0.0001), 1.0 / maxf(parent_scale.y, 0.0001), 1.0 / maxf(parent_scale.z, 0.0001))
	mark.position = Vector3(0.0, INK_HEIGHT / maxf(parent_scale.y, 0.0001), 0.0)
	return mark


static func _ink_tick() -> ArrayMesh:
	if _ink_mesh != null:
		return _ink_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bar in [[Vector2(-0.30, 0.02), Vector2(-0.10, -0.24)], [Vector2(-0.10, -0.24), Vector2(0.34, 0.34)]]:
		var a: Vector2 = bar[0]
		var b: Vector2 = bar[1]
		var side := (b - a).orthogonal().normalized() * 0.06
		for p in [a - side, a + side, b - side, a + side, b + side, b - side]:
			surface.add_vertex(Vector3(p.x, p.y, 0.0))
	_ink_mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_color = Palette.AMBER
	_ink_mesh.surface_set_material(0, material)
	return _ink_mesh


func ledger_hit(enemy: Node3D, damage: float, from: Vector3, knock: float, source: String) -> float:
	if target_class_of(enemy) == "boss":
		damage *= Ultimate.BOSS_MULT
		knock = 0.0
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, "ledger", damage, "", source)
		return damage
	deal_hit(enemy, "ledger", damage, enemy.global_position - from, knock, "", source)
	return damage


func _clear_tally_piece() -> void:
	tally_piece = ""
	ride_clips = {}
	_fly_plates = []
	_fly_pulled = false


func _tally_enemies() -> Array:
	return get_tree().get_nodes_in_group(Groups.ENEMY).filter(func(e): return not DamageDoor.dead(e))


static func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func tally_target(id: String, ball: Vector3, aim: Dictionary) -> Dictionary:
	if plate.is_empty():
		return {}
	var at: Vector3 = plate["at"]
	var reach: float = Ultimate.ARC_REACH[ultimate.heft_index()] if id == "plate_flywheel" else ctx.player.grapple_range()
	var forward: Vector3 = aim.get("forward", Vector3.ZERO)
	var flat_aim := Vector3(forward.x, 0.0, forward.z)
	var to := Vector3(at.x - ball.x, 0.0, at.z - ball.z)
	if ball.distance_to(at) > reach or flat_aim.length() < 0.01 or to.length() < 0.01:
		return {}
	if rad_to_deg(flat_aim.angle_to(to)) > Weapons.ULT_PLATE_AIM_DEG:
		return {}
	return {"path": "arc" if id == "plate_flywheel" else "line", "to": at, "target": null}


func tally_tech(id: String, _beat: int, ball: Vector3, aim: Vector3, heft: float) -> int:
	var cap: int = Weapons.CLIP_CAP[ultimate.heft_index()]
	var made := 0
	if id == "plate_audit":
		var ground = _audit_ground(ball)
		if ground == null:
			return 0
		var radius: float = Weapons.AUDIT_STAMP_RADIUS + float(ultimate.knob("ult_volley", 0))
		effects.ring(ground, radius, Palette.COPPER)
		for enemy in _tally_enemies():
			if in_ring(ground, radius, enemy):
				_piece_hit(enemy, Ultimate.VOLLEY_DAMAGE * heft, ground, Weapons.AUDIT_STAMP_KNOCK)
				made += _ride_clip(enemy, cap)
	elif id == "plate_flywheel":
		var knot = _densest_knot(ball)
		if knot == null:
			return 0
		_fly_plates.append({"at": knot, "until": _clock + Weapons.FLY_PLATE_SECONDS, "tick": 0.0})
		effects.ring(knot, Weapons.GATHER_RADIUS, Palette.COPPER)
		var near: Array = []
		for enemy in _tally_enemies():
			var gap := _flat_gap(enemy.global_position, knot)
			if gap <= Weapons.GATHER_RADIUS:
				near.append([gap, enemy])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for entry in near.slice(0, Weapons.FLY_KNOT_CLIPS + int(ultimate.knob("ult_volley", 0))):
			made += _ride_clip(entry[1], cap)
	else:
		for enemy in _volley_picks(ball, aim, ultimate.volley_targets()):
			effects.arc(ball + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, Palette.AMBER)
			_piece_hit(enemy, Ultimate.VOLLEY_DAMAGE * heft, ball, Weapons.LEDGER_KNOCK)
			made += _ride_clip(enemy, cap)
	if ally_husks != null and ghost_shift_unlocked():
		ally_husks.raise_in_radius(ball, Ultimate.VOLLEY_RADIUS)
	return made


func _volley_picks(ball: Vector3, aim: Vector3, count: int) -> Array:
	var picks: Array = []
	var bias := deg_to_rad(Ultimate.VOLLEY_BIAS_DEG)
	for enemy in _tally_enemies():
		var to: Vector3 = enemy.global_position - ball
		if to.length() > Ultimate.VOLLEY_RADIUS:
			continue
		var biased: bool = aim.length() > 0.01 and to.length() > 0.01 and aim.angle_to(to) <= bias
		var owed: bool = ride_clips.has(enemy.get_instance_id())
		picks.append([(1000.0 if owed else 0.0) + (0.0 if biased else 100.0) + to.length(), enemy])
	picks.sort_custom(func(a, b): return a[0] < b[0])
	return picks.slice(0, count).map(func(entry): return entry[1])


func _ride_clip(enemy: Node3D, cap: int) -> int:
	var id := enemy.get_instance_id()
	if ride_clips.has(id) or ride_clips.size() >= cap:
		return 0
	ride_clips[id] = true
	return 1


func _piece_hit(enemy: Node3D, damage: float, from: Vector3, knock: float) -> float:
	if (enemy.has_method("_apply_posture") and enemy.has_method("staggered")) or target_class_of(enemy) == "boss":
		return ult_hit(enemy, "ledger", damage, from, false)
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, "ledger", damage, "", "special")
		return damage
	deal_hit(enemy, "ledger", damage, enemy.global_position - from, knock, "", "special")
	return damage


func flail_hit(enemy: Node3D, damage: float, from: Vector3, knock: float) -> void:
	flung.emit(enemy)
	if (enemy.has_method("_apply_posture") and enemy.has_method("staggered")) or target_class_of(enemy) == "boss":
		ult_hit(enemy, "flail", damage, from, false)
		return
	if not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, "flail", damage, "", "flail")
		return
	deal_hit(enemy, "flail", damage, enemy.global_position - from, knock, "", "flail")


func _audit_ground(ball: Vector3):
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ball, ball + Vector3.DOWN * Weapons.AUDIT_GROUND_REACH, PhysicsLayers.WORLD_MASK))
	return hit["position"] if not hit.is_empty() else null


func _densest_knot(ball: Vector3):
	var enemies := _tally_enemies()
	var best = null
	var best_score := -1.0
	for enemy in enemies:
		var gap := _flat_gap(enemy.global_position, ball)
		if gap > Weapons.FLY_KNOT_SEARCH:
			continue
		var count := 0
		for other in enemies:
			if _flat_gap(other.global_position, enemy.global_position) <= Weapons.GATHER_RADIUS:
				count += 1
		var score := count * 100.0 - gap
		if score > best_score:
			best_score = score
			best = enemy.global_position
	return floor_at(best + Vector3.UP) if best != null else null


func tally_peak(id: String, at: Vector3) -> void:
	var state: Dictionary = ultimate.leg_state()
	var b: Vector3 = state["final_to"] if state["final_to"] != null else at
	var left := float(state["total_remaining"])
	if plate.is_empty() or _flat_gap(plate["at"], b) > 1.0:
		plate = {"at": floor_at(b + Vector3.UP), "until": 0.0}
		_gather_tick = 0.0
	plate["radius"] = ultimate.landing_radius() + (Weapons.FLY_LANDING_BONUS if id == "plate_flywheel" else 0.0)
	plate["until"] = _clock + maxf(left, 0.0) + Weapons.GATHER_TICK
	effects.ring(plate["at"], float(plate["radius"]), Palette.COPPER)


func tally_landing(id: String, at: Vector3, heft: float, chain: float) -> Array:
	var radius: float = ultimate.landing_radius() + (Weapons.FLY_LANDING_BONUS if id == "plate_flywheel" else 0.0)
	var amount: float = Ultimate.LANDING_DAMAGE * heft * chain
	effects.ring(at, radius, Palette.COPPER)
	ctx.break_props(at, radius, "ultimate")
	if not link_group.is_empty():
		link_group["spent"] = true
	var struck := {}
	var hits := 0
	var dealt := 0.0
	for enemy in _tally_enemies():
		if enemy.global_position.distance_to(at) > radius:
			continue
		struck[enemy.get_instance_id()] = true
		dealt += ult_hit(enemy, "ultimate", amount, at, true)
		hits += 1
	var share: float = float(ultimate.knob("ult_settle", Weapons.SETTLE_SHARE))
	var debts: Array = ride_clips.keys()
	if not link_group.is_empty() and float(link_group["until"]) > _clock:
		for cid in link_group["ids"]:
			if not debts.has(cid):
				debts.append(cid)
	var settled: Array = []
	for cid in debts:
		if struck.has(cid):
			continue
		var enemy = instance_from_id(cid)
		if DamageDoor.dead(enemy):
			continue
		effects.arc(at + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5, Palette.AMBER)
		dealt += _piece_hit(enemy, amount * share, at, Weapons.LEDGER_KNOCK)
		settled.append(cid)
	_grant_pressure(ctx.player.abilities.slot(AbilityState.WEAPON).max_charges)
	if ally_husks != null and ghost_shift_unlocked():
		ally_husks.command_charge(at)
	_fly_plates = []
	_fly_pulled = false
	tally_last_settle = {"at": at, "hits": hits, "settles": settled.size(), "ids": settled}
	_run_settles += settled.size()
	if settled.size() >= BOOKS_SETTLES:
		_tally_discover("tally_books_balanced", "set_piece", at)
	if _run_settles >= EYESHADE_SETTLES:
		_tally_discover("tally_eyeshade", "set_piece", at)
	return [hits + settled.size(), dealt]


func _step_tally_piece(delta: float) -> void:
	for p in _fly_plates.duplicate():
		if float(p["until"]) <= _clock:
			_fly_plates.erase(p)
			continue
		p["tick"] = float(p["tick"]) + delta
		while float(p["tick"]) >= Weapons.GATHER_TICK:
			p["tick"] = float(p["tick"]) - Weapons.GATHER_TICK
			_gather_pull(p["at"], Weapons.GATHER_RADIUS)
	if tally_piece != "plate_flywheel" or _fly_pulled or ultimate == null or ultimate.phase() != Ultimate.FLIGHT:
		return
	var state: Dictionary = ultimate.leg_state()
	if not bool(state["is_last"]):
		return
	if float(state["remaining"]) > Weapons.FLY_PULL_LEAD:
		return
	_fly_pulled = true
	var b: Vector3 = state["to"]
	var reach: float = ultimate.landing_radius() + Weapons.FLY_LANDING_BONUS + Weapons.FLY_PULL
	for enemy in _tally_enemies():
		if not is_ordinary(enemy):
			continue
		var inward: Vector3 = b - enemy.global_position
		inward.y = 0.0
		if inward.length() > reach or inward.length() < 0.01:
			continue
		var weight = enemy.get("weight")
		enemy.knock(inward, Weapons.FLY_PULL / Weapons.FLY_PULL_LEAD * (float(weight) if weight != null else 1.0))


func _tally_discover(id: String, after: String, at: Vector3) -> void:
	if discovered.has(id):
		return
	_tally_cards[id] = {"after": after, "at": at, "queued": Engine.get_physics_frames()}


func _step_tally_cards() -> void:
	var codex = run_codex()
	var frame := Engine.get_physics_frames()
	if codex == null or frame <= _tally_card_frame:
		return
	for id in _tally_cards.keys():
		var entry: Dictionary = _tally_cards[id]
		if frame > int(entry["queued"]) and codex.known(entry["after"]):
			_tally_cards.erase(id)
			_tally_card_frame = frame
			discover(id, entry["at"])
			return


func line_geometry(f: float) -> Dictionary:
	var from := _ground_under(ctx.player.ball_position())
	var length := AbilityState.Gauge.scaled(f, Weapons.LINE_MIN, Weapons.LINE_MAX)
	var shape: Dictionary = ctx.player.yours({"kind": "line", "from": from, "to": from + aim_heading() * length, "width": Weapons.LINE_WIDTH,
		"full_to": from + aim_heading() * Weapons.LINE_MAX, "fill": f})
	var points: Array = []
	for charge in _caught_line(shape):
		points.append(charge["pos"])
	shape["caught"] = points
	shape["bonus"] = 1.0 + Weapons.LINE_PER_CHARGE * mini(points.size(), Weapons.LINE_MAX_CAUGHT)
	ctx.player.indicator.set_shape("kest_caught", ctx.player.yours({"kind": "marks", "points": points}))
	return shape


func _caught_line(shape: Dictionary) -> Array:
	var live: Array = sticky.charges.duplicate()
	if ultimate != null:
		live.append_array(ultimate.caught_charges())
	return live.filter(func(c): return not c.get("_inert", false) and in_line(shape["from"], shape["to"], shape["width"], c["pos"]))


func fire_line(f: float, shape: Dictionary) -> void:
	var caught := []
	for charge in _caught_line(shape):
		caught.append(sticky.take(charge) if sticky.charges.has(charge) else ultimate.take_charge(charge))
	var bonus := 1.0 + Weapons.LINE_PER_CHARGE * mini(caught.size(), Weapons.LINE_MAX_CAUGHT)
	var damage := AbilityState.Gauge.scaled(f, Weapons.LINE_DAMAGE_MIN, Weapons.LINE_DAMAGE_MAX) * bonus \
		* damage_mod(Weapons.STICKY_CHARGE) * _cloak_shot()
	var snapped_tokens := {}
	for charge in caught:
		var tok: int = int(charge.get("snap_token", 0))
		if tok > 0 and not snapped_tokens.has(tok) and weapon_driver.consume_snap_window(tok):
			snapped_tokens[tok] = true
	for charge in caught:
		var tok: int = int(charge.get("snap_token", 0))
		detonate(charge, snapped_tokens.has(tok))
	var hit := 0
	var from: Vector3 = shape["from"]
	var to: Vector3 = shape["to"]
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead() or not in_line(from, to, shape["width"], enemy.global_position, hull_radius(enemy)):
			continue
		if _knob("line_marks") > 0.0:
			_marks[enemy.get_instance_id()] = _clock + _knob("line_marks")
		deal_hit(enemy, "line", damage, to - from, Weapons.LINE_KNOCK, "", "special")
		hit += 1
	var along: int = _knob("line_charges")
	for i in along:
		var spot: Vector3 = from.lerp(to, (float(i) + 0.5) / float(along))
		var fuse_charge: Dictionary = sticky.drop(spot, Weapons.MINI_DAMAGE * damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS,
			Weapons.MINI_FUSE, Weapons.MINI_ARM, _knob("sticky_reach"), _clock)
		fuse_charge["_source"] = "item_proc"
	effects.arc(from + Vector3.UP * 0.5, to + Vector3.UP * 0.5, ClassDef.KEST_COLOR)
	start_cloak()
	last_burst = {"at": from, "to": to, "damage": damage, "hit": hit, "kind": "line", "caught": caught.size(),
		"breaks_props": not caught.is_empty()}


func _on_mounted(at: Vector3, banked_speed: float) -> void:
	if ultimate != null and ultimate.active() and ultimate.active_id() == "outpost":
		return
	if ctx.run.class_def == null or not ctx.flow.in_play():
		return
	if ctx.run.class_def.id == "pylon_engineer":
		hero_hooks.plant_beachhead_pylon(at)
	var abilities = ctx.player.abilities
	if not abilities.cap(AbilityState.SPECIAL, "plant_discharge", false):
		return
	var prev_source := _forced_source
	_forced_source = "special"
	_discharge(at, banked_speed, "turret", null, 64 if _knob("plant_all") else -1)
	_forced_source = prev_source
	ctx.events.special_used.emit(abilities.id_of(AbilityState.SPECIAL), at)


func _discharge(at: Vector3, speed: float, kind: String, drawn_centre = null, limit := -1) -> void:
	var burst := discharge_preview(speed)
	var count: int = burst["targets"] if limit < 0 else limit
	var targets: Array
	if drawn_centre == null:
		targets = nearest_enemies(at, burst["radius"], count)
	else:
		targets = _nearest_in_ring(drawn_centre, burst["radius"], count)
	var color := Weapons.color(Weapons.PYLON_TURRET)
	for enemy in targets:
		var to: Vector3 = enemy.global_position
		effects.arc(at, to, color)
		deal_hit(enemy, kind, burst["damage"], to - at, Weapons.BURST_KNOCK, "", "", "burst")
	if _knob("discharge_chain"):
		for enemy in targets:
			if not is_instance_valid(enemy):
				continue
			var next := nearest_enemy(enemy.global_position, Weapons.BASE[Weapons.ARC_CASTER]["chain_range"], targets)
			if next != null:
				effects.arc(enemy.global_position, next.global_position, color)
				deal_hit(next, kind, burst["damage"] * 0.5, next.global_position - enemy.global_position, Weapons.BURST_KNOCK * 0.5, "", "", "spill")
	effects.ring(at, burst["radius"], color)
	last_burst = burst.duplicate()
	last_burst["at"] = at
	last_burst["hit"] = targets.size()
	last_burst["kind"] = kind
	last_burst["breaks_props"] = false


func _nearest_in_ring(centre: Vector3, radius: float, limit: int) -> Array:
	var found := []
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not enemy.is_dead() and in_ring(centre, radius, enemy):
			found.append([enemy.global_position.distance_to(centre), enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	return found.slice(0, limit).map(func(pair): return pair[1])


func _overdrive_blast(at: Vector3, scale := 1.0, shape := {}, radius_scale := 1.0, damage_scale := 1.0, boost := true) -> void:
	var p: Resource = _patterns[Weapons.RAPID_LASER]
	var damage: float = Weapons.OVERDRIVE_DAMAGE * scale * damage_scale * p.damage * damage_mod(Weapons.RAPID_LASER) \
		/ Weapons.base_damage(Weapons.RAPID_LASER)
	var radius := Weapons.OVERDRIVE_RADIUS * scale * radius_scale
	var centre: Vector3 = shape.get("centre", at)
	var pull: bool = _knob("blast_pull") and not _echoing
	var hit := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead() or not in_ring(centre, radius, enemy):
			continue
		var away: Vector3 = enemy.global_position - at
		deal_hit(enemy, "runner", damage, -away if pull else away, Weapons.OVERDRIVE_KNOCK * scale, "", "", "overdrive")
		hit += 1
	if boost:
		add_overdrive(Weapons.OVERDRIVE_SECONDS * p.special_scale)
	effects.ring(at, radius, ClassDef.RIVET_COLOR)
	last_burst = {"at": at, "radius": radius, "damage": damage, "hit": hit, "kind": "runner",
		"overdrive": _overdrive, "breaks_props": false}


func add_overdrive(seconds: float) -> void:
	_overdrive = minf(Weapons.OVERDRIVE_MAX, _overdrive + seconds) if _overdrive > 0.0 else seconds
	_post_buff("overdrive", {"icon": "overdrive", "tone": Palette.COPPER, "kind": BuffLedger.KIND_TIMER,
		"duration_s": maxf(Weapons.OVERDRIVE_SECONDS, _overdrive), "left_s": _overdrive})
	if _knob("overdrive_immune"):
		ctx.player.grant_immunity(_overdrive)


func _step_sticky_weapon(intent, delta: float, shots: Array = []) -> void:
	var abilities = ctx.player.abilities
	var gauge = abilities.gauge(AbilityState.WEAPON)
	if gauge == null:
		return
	var p: Resource = _lob_pattern()
	if p != null and p.trigger == Pattern.TRIGGER_LOB_SNAP:
		for shot in shots:
			if String(shot.get("kind", "")) == WeaponDriver.SHOT_SNAP:
				if gauge.charging:
					gauge.cancel()
				ctx.player.indicator.clear("weapon")
				ctx.player.indicator.clear("landing")
				var tok: int = int(shot.get("token", 0))
				var targets: Array = []
				for c in sticky.live():
					if tok <= 0 or int(c.get("snap_token", 0)) == tok:
						targets.append(c)
				for c in targets:
					detonate(sticky.take(c), true)
				return
		var snap: Dictionary = weapon_driver.state_snapshot()
		var snap_locked: bool = bool(snap.get("snap_locked", false))
		var can_open: bool = abilities.ready(AbilityState.WEAPON) and not snap_locked \
			and (float(p.floor_s) <= 0.601 or float(snap.get("cooldown", 0.0)) <= 0.0)
		var want_open: bool = intent.fire_pressed or (intent.fire_held and not snap_locked) or bool(snap.get("buffered", false))
		if not gauge.charging and want_open and can_open:
			weapon_driver.consume_buffer()
			gauge.begin()
		weapon_driver.set_lob_charging(gauge.charging)
		if not gauge.charging:
			ctx.player.indicator.clear("weapon")
			ctx.player.indicator.clear("landing")
			return
		var held_before: float = gauge.held
		if not gauge.step(delta, intent.fire_held):
			weapon_driver.set_lob_charging(gauge.charging)
			_draw_throw(_throw_landing(gauge.fraction(), gauge.held))
			return
		weapon_driver.set_lob_charging(false)
		var landing := _throw_landing(gauge.fired_fraction, held_before)
		_draw_throw(landing)
		if landing["blocked"]:
			ctx.player.indicator.collapse("weapon")
			ctx.player.indicator.collapse("landing")
			ctx.events.gauge_cancelled.emit(abilities.id_of(AbilityState.WEAPON), "blocked")
			return
		ctx.player.indicator.clear("weapon")
		ctx.player.indicator.clear("landing")
		abilities.spend(AbilityState.WEAPON)
		var tok: int = weapon_driver.commit_lob_throw(1.0)
		_throw_sticky(landing["point"], tok, bool(landing.get("tail_drop", false)))
		return
	if not gauge.charging and (intent.fire_pressed or intent.fire_held) and abilities.ready(AbilityState.WEAPON):
		gauge.begin()
	if not gauge.charging:
		ctx.player.indicator.clear("weapon")
		ctx.player.indicator.clear("landing")
		return
	if not gauge.step(delta, intent.fire_held):
		_draw_throw(_throw_landing(gauge.fraction()))
		return
	var landing := _throw_landing(gauge.fired_fraction)
	_draw_throw(landing)
	if landing["blocked"]:
		ctx.player.indicator.collapse("weapon")
		ctx.player.indicator.collapse("landing")
		ctx.events.gauge_cancelled.emit(abilities.id_of(AbilityState.WEAPON), "blocked")
		return
	ctx.player.indicator.clear("weapon")
	ctx.player.indicator.clear("landing")
	abilities.spend(AbilityState.WEAPON)
	_throw_sticky(landing["point"])


func _throw_origin() -> Vector3:
	return ctx.player.ball_position() + aim_heading() * MUZZLE + Vector3.UP * 0.6


func _lob_pattern() -> Resource:
	var abilities = ctx.player.abilities
	return _patterns[abilities.cap(AbilityState.WEAPON, "pattern", abilities.id_of(AbilityState.WEAPON))]


func _throw_landing(f: float, held_s := -1.0) -> Dictionary:
	var p: Resource = _lob_pattern()
	var tail_drop := false
	var flat: Vector3
	if p != null and p.trigger == Pattern.TRIGGER_LOB_SNAP:
		var hold_time := held_s if held_s >= 0.0 else f * Weapons.STICKY_CHARGE_MAX
		if hold_time < Weapons.STICKY_TAIL_HOLD_S:
			tail_drop = true
			var pv: Vector3 = ctx.player.planar_velocity()
			var tail_dir: Vector3 = -pv.normalized() if pv.length() > 0.5 else -aim_heading()
			flat = ctx.player.ball_position() + tail_dir * Weapons.STICKY_TAIL_OFFSET
		else:
			var reach := AbilityState.Gauge.scaled(f, 0.0, p.range_m * ctx.tuning.mod("weapon_range"))
			flat = ctx.player.ball_position() + aim_heading() * reach
	else:
		var reach := AbilityState.Gauge.scaled(f, Weapons.STICKY_THROW_MIN, p.range_m * ctx.tuning.mod("weapon_range"))
		flat = ctx.player.ball_position() + aim_heading() * reach
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(flat + Vector3.UP * 30.0, flat + Vector3.DOWN * 60.0, PhysicsLayers.WORLD_MASK))
	if hit.is_empty():
		return {"point": flat + Vector3.DOWN * 0.9, "blocked": true, "tail_drop": tail_drop}
	return {"point": hit["position"], "blocked": false, "tail_drop": tail_drop}


func _draw_throw(landing: Dictionary) -> void:
	var at: Vector3 = landing["point"]
	var blocked: bool = landing["blocked"]
	ctx.player.indicator.set_shape("weapon", ctx.player.yours({"kind": "arc",
		"points": Sticky.arc_points(_throw_origin(), at), "blocked": blocked}))
	ctx.player.indicator.set_shape("landing", ctx.player.yours({"kind": "ring", "centre": at,
		"radius": _lob_pattern().bolt_radius * mass_radius_scale(), "blocked": blocked}))


func mass_radius_scale() -> float:
	if not ctx.tuning.world_one():
		return 1.0
	return 1.0 + MASS_K_RADIUS * clampf(ctx.run.mass / MASS_K_SATURATION, 0.0, 1.0)


func _throw_sticky(landing: Vector3, snap_token := 0, tail_drop := false) -> void:
	var p: Resource = _lob_pattern()
	var ability_lob: int = ctx.player.abilities.cap(AbilityState.WEAPON, "lob", 1)
	var pattern_lob: int = int(p.count) if p != null else 1
	var count: int = maxi(ability_lob, pattern_lob)
	var origin := _throw_origin()
	var crit := cloak_left > 0.0
	var damage: float = p.damage * damage_mod(Weapons.STICKY_CHARGE) * _cloak_shot()
	var ring: float = p.bolt_radius * mass_radius_scale()
	var radius: float = ring
	if ability_lob > 1:
		damage *= Weapons.RAIN_DAMAGE / float(ability_lob)
		radius *= Weapons.RAIN_RADIUS
	var live_cap: int = int(p.max_live) if (p != null and int(p.max_live) > 0) else int(_knob("sticky_max_live"))
	devices.set_cap(Devices.STICKY, live_cap * count)
	var scatter_r: float = ring if ability_lob > 1 else minf(ring * 0.55, 1.4)
	for i in count:
		var live: Array = sticky.live()
		if live.size() >= devices.cap(Devices.STICKY):
			detonate(sticky.take(live[0]))
		var spot := landing
		if count > 1:
			var angle := TAU * float(i) / float(count)
			spot = landing + Vector3(cos(angle), 0.0, sin(angle)) * scatter_r
		var thrown: Dictionary = sticky.throw(origin, spot, damage, radius, _knob("sticky_fuse"), crit,
			_knob("sticky_reach"), _clock, _knob("sticky_ride"), tail_drop)
		thrown["_source"] = "weapon"
		if snap_token > 0 and p != null and p.trigger == Pattern.TRIGGER_LOB_SNAP:
			thrown["snap_mult"] = float(p.window_mult)
			sticky.set_snap_cue(thrown, p.window_s, snap_token)
	volleys += 1
	last_shot = {"weapon_id": Weapons.STICKY_CHARGE, "from": origin, "to": landing, "point": landing,
		"blocked": false, "bolts": count, "volley": volleys, "radius": radius, "tail_drop": tail_drop}
	hero_hooks.refresh_kest_fuse_trace()
	ctx.events.shot_fired.emit(Weapons.STICKY_CHARGE, origin, landing)


func detonate(charge: Dictionary, snapped := false) -> void:
	var at: Vector3 = charge["pos"]
	var radius: float = charge["radius"]
	var damage: float = charge["damage"]
	var knock: float = Weapons.BASE[Weapons.STICKY_CHARGE]["knock"]
	if snapped:
		damage *= float(charge.get("snap_mult", Weapons.STICKY_SNAP_MULT))
		radius *= Weapons.STICKY_SNAP_RADIUS_MULT
		knock *= Weapons.STICKY_SNAP_KNOCK_MULT
	if _knob("sticky_grow"):
		damage *= 1.0 + Weapons.GROW_PER_SECOND * minf(Weapons.GROW_MAX_SECONDS, _clock - float(charge.get("born", _clock)))
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead():
			continue
		if (enemy.global_position - at).length() - hull_radius(enemy) > radius * (1.0 + AbilityState.FORGIVENESS):
			continue
		var dealt := damage
		if float(enemy.get("plating") if enemy.get("plating") != null else 0.0) > 0.0:
			dealt *= _knob("sticky_breach")
		if _marks.get(enemy.get_instance_id(), -1.0) > _clock:
			dealt *= Weapons.MARK_BONUS
		if charge.has("_kest_cast"):
			ultimate.blast_hit(charge, enemy, dealt, at)
		else:
			deal_hit(enemy, "sticky", dealt, enemy.global_position - at, knock, "", charge.get("_source", "weapon"))
	if snapped:
		effects.ring(at, radius * 0.88, Palette.SAND)
		effects.ring(at, radius, Palette.AMBER)
	else:
		effects.ring(at, radius, ClassDef.KEST_COLOR)
	ctx.break_props(at, radius, "sticky")
	ctx.events.sticky_detonated.emit(at, charge["crit"])
	_rocket_jump(at)
	start_cloak()
	var tok: int = int(charge.get("snap_token", 0))
	if tok > 0 and not snapped:
		var still_live := false
		for other in sticky.charges:
			if int(other.get("snap_token", 0)) == tok:
				still_live = true
				break
		if not still_live:
			weapon_driver.notify_lob_charge_gone(tok)
	if _knob("sticky_chain") > 0.0:
		var live: Array = sticky.charges.duplicate()
		live.append_array(ultimate.caught_charges())
		for other in live:
			if other.get("_inert", false) or (not sticky.charges.has(other) and not ultimate.caught_charges().has(other)):
				continue
			if (other["pos"] as Vector3).distance_to(at) <= _knob("sticky_chain"):
				detonate(sticky.take(other) if sticky.charges.has(other) else ultimate.take_charge(other))


func _rocket_jump(at: Vector3) -> void:
	var player = ctx.player
	if not player.abilities.cap(AbilityState.MOVEMENT, "rocket", false) or _rocket_left > 0.0:
		return
	if not player.intent.jump_held and not _knob("rocket_auto"):
		return
	var away: Vector3 = player.ball_position() - at
	var reach := away.length()
	if reach > Weapons.ROCKET_REACH:
		return
	var dir := (away.normalized() if reach > 0.01 else Vector3.ZERO) + Vector3.UP
	dir = dir.normalized()
	var speed := AbilityState.Gauge.scaled(1.0 - reach / Weapons.ROCKET_REACH, Weapons.ROCKET_MIN, Weapons.ROCKET_MAX)
	var v: Vector3 = player.state.velocity
	var gain := maxf(0.0, speed - v.dot(dir))
	player.add_external_accel(dir * gain / get_physics_process_delta_time())
	_rocket_left = AbilityState.floored(Weapons.ROCKET_COOLDOWN, rocket_cooldown_scale)
	ctx.events.rocket_jumped.emit(at, speed)


func _on_demo_slammed(at: Vector3) -> void:
	if not ctx.flow.in_play():
		return
	var heading: Vector3 = ctx.player.planar_velocity()
	var turn := atan2(heading.z, heading.x) if heading.length() > 0.5 else 0.0
	var count: int = _knob("mini_count")
	var scale := 1.0
	if _knob("slam_fall_scale"):
		scale = clampf(ctx.player.kit.slam_landed / Weapons.DIVE_FALL, 1.0, Weapons.DIVE_MAX)
	var linger: float = _knob("mini_linger")
	var mass_scale := mass_radius_scale()
	for i in count:
		var angle := turn + TAU * float(i) / float(count)
		var spot := at + Vector3(cos(angle), 0.0, sin(angle)) * Weapons.MINI_SPREAD * sqrt(scale)
		var slam_charge: Dictionary = sticky.drop(spot, Weapons.MINI_DAMAGE * scale * damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS * sqrt(scale) * mass_scale,
			linger if linger > 0.0 else Weapons.MINI_FUSE, 0.0 if linger > 0.0 else Weapons.MINI_ARM, _knob("sticky_reach"), _clock)
		slam_charge["_source"] = "drop_or_slam"


func _on_blink(from: Vector3, to: Vector3) -> void:
	effects.ring(from, 2.5, ClassDef.KEST_COLOR)
	start_cloak()
	if _knob("blink_cut"):
		for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not enemy.is_dead() and in_line(from, to, Weapons.BLINK_CUT_WIDTH, enemy.global_position, hull_radius(enemy)):
				deal_hit(enemy, "sticky", _patterns[Weapons.STICKY_CHARGE].damage * damage_mod(Weapons.STICKY_CHARGE), to - from, EventKinds.IMPACT["proc"]["knock"], "", "item_proc", "proc")
	if _knob("smoke_cloud") > 0.0:
		_cloud = {"at": from, "left": _knob("smoke_cloud")}


func start_cloak() -> void:
	if not ctx.player.abilities.cap(AbilityState.MOVEMENT, "cloak", false):
		return
	var fresh := cloak_left <= 0.0
	cloak_left = maxf(cloak_left, Weapons.CLOAK_SECONDS)
	_post_buff("cloak", {"icon": "cloak", "tone": Palette.STEEL, "kind": BuffLedger.KIND_TIMER,
		"duration_s": cloak_left, "left_s": cloak_left})
	if fresh:
		cloak_at = ctx.player.ball_position()
		_cloak_held = 0.0
		ctx.events.cloak_started.emit(cloak_left)


func _tick_cloak(delta: float) -> void:
	var kit = ctx.player.kit
	if not _cloud.is_empty():
		_cloud["left"] -= delta
		if _cloud["left"] <= 0.0:
			_cloud = {}
		elif ctx.player.ball_position().distance_to(_cloud["at"]) <= Weapons.SMOKE_CLOUD_RADIUS:
			start_cloak()
	if _knob("glide_cloak") and kit.gliding:
		start_cloak()
	kit.cloaked = cloak_left > 0.0
	if cloak_left <= 0.0:
		return
	_cloak_held += delta
	var holding: bool = _knob("cloak_hold_fast") and ctx.player.speed_tier() >= SpeedTier.FAST \
		and _cloak_held < Weapons.CLOAK_HOLD_MAX
	if not holding:
		cloak_left -= delta
	if cloak_left <= 0.0:
		cloak_left = 0.0
		kit.cloaked = false
		clear_buff("cloak")
		ctx.events.cloak_broken.emit("faded")


func _cloak_shot() -> float:
	if cloak_left <= 0.0:
		return 1.0
	if not _knob("cloak_keep"):
		cloak_left = 0.0
		ctx.player.kit.cloaked = false
		clear_buff("cloak")
		ctx.events.cloak_broken.emit("shot")
	return Weapons.CLOAK_CRIT


func cloak_sight() -> float:
	return _knob("cloak_sight")


func _on_proc_fact(kind: String) -> void:
	if ctx == null or not ctx.flow.in_play() or ctx.run.class_def == null:
		return
	if kind == "enemy_killed" and ctx.run.last_kill_triggerless:
		return
	for proc in ctx.player.tree.procs():
		if proc["on"] != kind:
			continue
		var key: String = "%s:%s" % [proc["node"], kind]
		if _clock < float(_proc_ready.get(key, -INF)):
			continue
		_proc_ready[key] = _clock + float(proc["gap"])
		(_actions[proc["do"]] as Callable).call(float(proc.get("scale", 1.0)))


func _proc_actions() -> Dictionary:
	var abilities = func(): return ctx.player.abilities
	return {
		"discharge": _proc_discharge,
		"blast": _proc_blast,
		"volley": _proc_volley,
		"charge": _proc_charges,
		"detonate": _proc_detonate,
		"grant_special": func(_scale: float): _grant_special(abilities.call()),
		"grant_move": func(_scale: float): abilities.call().grant(AbilityState.MOVEMENT),
		"refund_special": func(scale: float): _refund_special(abilities.call(), scale),
		"refund_move": func(scale: float): abilities.call().refund(AbilityState.MOVEMENT, scale),
		"overdrive": func(scale: float): add_overdrive(scale),
		"air": func(_scale: float): ctx.player.state.air_actions = 1,
	}


func _grant_special(abilities) -> void:
	abilities.grant(abilities.pool_of(AbilityState.SPECIAL))


func _refund_special(abilities, scale: float) -> void:
	if scale <= 0.0:
		return
	var pool: String = abilities.pool_of(AbilityState.SPECIAL)
	if pool == AbilityState.SPECIAL:
		abilities.refund(AbilityState.SPECIAL, scale)
	else:
		abilities.grant(pool)


func _proc_volley(scale: float) -> void:
	var weapon := active_weapon()
	if not _patterns.has(weapon) or ctx.player.abilities.cap(AbilityState.WEAPON, "lob", 0) > 0:
		return
	var is_cards: bool = ctx.player.abilities.cap(AbilityState.WEAPON, "cards", null) != null
	var is_lane: bool = not is_cards and ctx.player.abilities.cap(AbilityState.WEAPON, "family", "") == "lane"
	var p: Resource = _patterns[weapon]
	for i in int(scale):
		if is_cards:
			var aim := card_aim()
			_run_balance(aim["point"], aim["valid"], {}, "item_proc")
		elif is_lane:
			var pulse_reach: float = float(p.lock_pulse_reach) if float(p.lock_pulse_reach) > 0.0 else float(p.range_m)
			_fire_cannon_lane(weapon, {
				"kind": WeaponDriver.SHOT_PULSE, "damage": float(p.damage), "reach": pulse_reach,
				"width_mult": float(p.lock_pulse_width_mult), "pierce": false, "breaks_props": false,
			}, "item_proc")
		else:
			_fire(weapon, "item_proc")


func _proc_discharge(scale: float) -> void:
	var prev_source := _forced_source
	_forced_source = "item_proc"
	_discharge(ctx.player.ball_position(), scale * Weapons.DISCHARGE_FULL_SPEED, "arc")
	_forced_source = prev_source


func _proc_blast(scale: float) -> void:
	var prev_source := _forced_source
	_forced_source = "item_proc"
	_overdrive_blast(ctx.player.ball_position(), scale, {}, 1.0, 1.0, false)
	_forced_source = prev_source


func _proc_detonate(scale: float) -> void:
	detonate({"pos": floor_at(ctx.player.ball_position()),
		"radius": Weapons.BASE[Weapons.STICKY_CHARGE]["bolt_radius"] * scale,
		"damage": _patterns[Weapons.STICKY_CHARGE].damage * damage_mod(Weapons.STICKY_CHARGE) * scale,
		"crit": false, "born": _clock, "_source": "item_proc"})


func _proc_charges(scale: float) -> void:
	var ground := floor_at(ctx.player.ball_position())
	var count := int(scale)
	for i in count:
		var angle := TAU * float(i) / float(count)
		var spot := ground + (Vector3(cos(angle), 0.0, sin(angle)) * Weapons.MINI_SPREAD if count > 1 else Vector3.ZERO)
		var proc_charge: Dictionary = sticky.drop(spot, Weapons.MINI_DAMAGE * damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS,
			Weapons.MINI_FUSE, Weapons.MINI_ARM, _knob("sticky_reach"), _clock)
		proc_charge["_source"] = "item_proc"


func _tick_upgrades(delta: float) -> void:
	var kit = ctx.player.kit
	_tick_echo(delta)
	_tick_rakes()
	_tick_aftershocks()
	_pulse_left = maxf(0.0, _pulse_left - delta)
	if _pulse_left <= 0.0:
		if kit.hooked and _knob("anchor_pulse") > 0.0:
			var prev_source := _forced_source
			_forced_source = "item_proc"
			_discharge(kit.anchor, Weapons.DISCHARGE_FULL_SPEED * 0.2, "arc")
			_forced_source = prev_source
			_pulse_left = _knob("anchor_pulse")
		elif kit.mounted and _knob("mount_pulse") > 0.0:
			var prev_source := _forced_source
			_forced_source = "item_proc"
			_discharge(ctx.player.ball_position(), kit.mount_banked * 0.5, "turret")
			_forced_source = prev_source
			_pulse_left = _knob("mount_pulse")
		elif kit.gliding and _knob("glide_bombs") > 0.0:
			var ground := floor_at(ctx.player.ball_position())
			var glide_charge: Dictionary = sticky.drop(ground, Weapons.MINI_DAMAGE * damage_mod(Weapons.STICKY_CHARGE), Weapons.MINI_RADIUS,
				Weapons.MINI_FUSE, Weapons.MINI_ARM, _knob("sticky_reach"), _clock)
			glide_charge["_source"] = "item_proc"
			_pulse_left = _knob("glide_bombs")
	_tick_sentry(delta)


func _on_dismounted_sentry(_velocity: Vector3) -> void:
	if _knob("sentry") > 0.0 and ctx.flow.in_play():
		var at: Vector3 = ctx.player.kit.mount_face + ctx.player.kit.mount_normal * 1.2
		var placed: Dictionary = devices.deploy(Devices.SENTRY, at)
		if int(placed["id"]) <= 0:
			return
		_sentry = {"at": at, "left": _knob("sentry"), "next": 0.0, "id": int(placed["id"])}


func _tick_sentry(delta: float) -> void:
	if _sentry.is_empty():
		return
	_sentry["left"] -= delta
	_sentry["next"] -= delta
	if _sentry["left"] <= 0.0:
		devices.remove(int(_sentry.get("id", 0)), "expired")
		_sentry = {}
		return
	if _sentry["next"] > 0.0:
		return
	var from: Vector3 = _sentry["at"]
	var target := nearest_enemy(from, Weapons.SENTRY_REACH, [])
	if target == null:
		return
	var p: Resource = _patterns[Weapons.PYLON_TURRET]
	_sentry["next"] = 1.0 / maxf(0.5, p.rate * Weapons.SENTRY_RATE)
	var dir: Vector3 = (target.global_position + Vector3.UP * 0.8 - from).normalized()
	bolts.fire({
		"origin": from, "dir": dir, "speed": p.speed, "max_dist": Weapons.SENTRY_REACH,
		"damage": p.damage * damage_mod(Weapons.PYLON_TURRET), "kind": Weapons.strike_kind(Weapons.PYLON_TURRET),
		"weapon_id": Weapons.PYLON_TURRET, "radius": p.bolt_radius, "knock": p.knock, "chain_jumps": p.chain_jumps,
		"chain_range": p.chain_range, "chain_falloff": p.chain_falloff,
		"lattice_chain_falloff": p.lattice_chain_falloff, "color": Weapons.color(Weapons.PYLON_TURRET),
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
		"source": "persistent_actor",
	})


func _step_devices(delta: float) -> void:
	if not _sentry.is_empty():
		devices.move(int(_sentry.get("id", 0)), _sentry["at"])
	for charge in ultimate.caught_charges():
		devices.move(int(charge.get("device_id", 0)), charge["pos"])
	for stake in ultimate.stakes.nodes:
		devices.move(stake.device_id, stake.global_position)
	for gone in devices.step(delta, ctx.player.ball_position()):
		if gone["kind"] == Devices.SENTRY:
			if int(_sentry.get("id", 0)) == int(gone["id"]):
				_sentry = {}
		elif gone["kind"] == Devices.SABLE_STAKE:
			ultimate.stakes.recall(int(gone["id"]))
		elif gone["kind"] in [Devices.KEST_MINE, Devices.KEST_RAID]:
			ultimate.payloads.recall(int(gone["id"]))
		else:
			sticky.recall(int(gone["id"]))


func _on_slammed_upgrade(at: Vector3, _strength: float, _flatness: float) -> void:
	var abilities = ctx.player.abilities
	if not ctx.flow.in_play() or not abilities.cap(AbilityState.SMASH, "spends_special", false):
		return
	if abilities.spend(AbilityState.SPECIAL):
		_discharge(at, Weapons.DISCHARGE_FULL_SPEED, "arc")
		ctx.events.special_used.emit(abilities.id_of(AbilityState.SPECIAL), at)


func _pin_step(enemies: Array) -> void:
	if not _pinned.is_empty():
		for key in _pinned.keys():
			if _clock - float(_pinned[key]) > 3.0:
				_pinned.erase(key)
	for carrier in enemies:
		if not _pinnable(carrier) or not (carrier is EnemyBase or carrier.has_method("_knocked_speed")):
			continue
		var speed: float = carrier._knocked_speed()
		if speed <= Weapons.PIN_MIN_SPEED:
			continue
		var heading := Vector3(carrier.velocity.x, 0.0, carrier.velocity.z)
		heading = heading.normalized() if heading.length_squared() > 0.01 else Vector3.ZERO
		if heading == Vector3.ZERO:
			continue
		for victim in enemies:
			if victim == carrier or not _pinnable(victim) or victim.get("weight") == null:
				continue
			var to: Vector3 = victim.global_position - carrier.global_position
			to.y = 0.0
			var reach := hull_radius(carrier) + hull_radius(victim) + Weapons.PIN_RADIUS
			if to.length_squared() > reach * reach:
				continue
			if to.normalized().dot(heading) < 0.5:
				continue
			var key := "%d:%d:%d" % [carrier.get_instance_id(), carrier.knocks, victim.get_instance_id()]
			if _pinned.has(key):
				continue
			_pinned[key] = _clock
			_pin(victim, to, speed)


func _pin(victim: Node3D, to: Vector3, speed: float, mult := 1.0) -> void:
	var damage := minf(Weapons.PIN_CAP, Weapons.PIN_BASE + Weapons.PIN_PER_SPEED * speed) * mult
	pins += 1
	ctx.events.enemy_pinned.emit(victim, damage)
	victim.knock(to + Vector3.UP * 0.2, speed * Weapons.PIN_CARRY * float(victim.weight))
	victim.flash()
	strike(victim, "pin", damage)
	if is_instance_valid(victim) and victim.is_dead():
		bowl_hulk(victim, to, speed * Weapons.PIN_CARRY)


func bowl_hulk(enemy: Node3D, direction: Vector3, speed: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if speed <= Weapons.PIN_MIN_SPEED or flat.length_squared() < 0.0001 or not is_instance_valid(enemy) or enemy.get("swarm") != null:
		return
	_hulks.append({"at": enemy.global_position, "vel": flat.normalized() * speed, "radius": hull_radius(enemy),
		"left": Weapons.HULK_SECONDS, "hit": {enemy.get_instance_id(): true}, "mult": heft()})


func _hulk_step(enemies: Array, delta: float) -> void:
	if _hulks.is_empty():
		return
	var stepping := _hulks
	_hulks = []
	var live: Array = []
	for hulk in stepping:
		var vel: Vector3 = hulk["vel"]
		var speed := vel.length()
		hulk["left"] = float(hulk["left"]) - delta
		if speed <= Weapons.PIN_MIN_SPEED or float(hulk["left"]) <= 0.0:
			continue
		var heading := vel / speed
		var at: Vector3 = hulk["at"]
		for victim in enemies:
			if not _pinnable(victim) or victim.get("weight") == null or (hulk["hit"] as Dictionary).has(victim.get_instance_id()):
				continue
			if victim.has_method("fight") and victim.fight() == "posture":
				continue
			if victim.get("swarm") != null:
				continue
			var to: Vector3 = victim.global_position - at
			to.y = 0.0
			if to.length() - float(hulk["radius"]) - hull_radius(victim) > Weapons.PIN_RADIUS or to.normalized().dot(heading) < 0.5:
				continue
			hulk["hit"][victim.get_instance_id()] = true
			_pin(victim, to, speed, float(hulk["mult"]))
		hulk["at"] = at + vel * delta
		hulk["vel"] = vel.move_toward(Vector3.ZERO, EnemyBase.KNOCK_DECAY * delta)
		live.append(hulk)
	_hulks = live + _hulks


static func _pinnable(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy is EnemyBase:
		return not enemy.is_dead()
	return enemy.has_method("knock") and enemy.has_method("is_dead") and not enemy.is_dead()


func _director():
	var world = ctx.root.get_node_or_null("World") if ctx.root != null else null
	var director = world.get("director") if world != null else null
	if director == null:
		_warn_no_director()
	return director


var _director_warned := false


func _warn_no_director() -> void:
	if not _director_warned:
		_director_warned = true
		push_warning("combat: no World director; enemy and hit scales read neutral")


func _on_player_hit(amount: float, shove: Vector3, source: String) -> void:
	var attack := _hit_attack
	_hit_attack = ""
	if not ctx.flow.in_play():
		return
	if ctx.run != null and ctx.run.consumable_grace_active():
		return
	if source not in ["warden", "warden_counter", "vault"]:
		var director = _director()
		if director != null:
			amount *= director.damage_scale()
		if source != "mind_hand":
			amount *= ChallengeDials.stage_mult("mobs.damage", ctx.run.stage)
	if ctx.run != null and ctx.run.class_def != null and ctx.run.class_def.id == "tarn":
		var tarn_claw = get_node_or_null("TarnClaw")
		if tarn_claw != null and tarn_claw.has_method("frontal_armor_scale"):
			var armor_mult: float = float(tarn_claw.frontal_armor_scale(shove))
			if armor_mult < 1.0:
				amount *= armor_mult
				shove *= 0.35
	last_player_hit = {"from": ctx.player.ball_position() - shove, "shove": shove, "source": source, "frame": Engine.get_physics_frames(), "attack": attack}
	var riding: bool = ultimate != null and ultimate.active()
	ctx.run.damage(amount, source)
	if not riding:
		_charge_assist("hull")
	if ctx.calm or riding:
		return
	ctx.player.crowd_control("knock", shove / get_physics_process_delta_time())


func _wire_redline() -> void:
	var redline = ctx.player.get("redline") if ctx.player != null else null
	if redline == null:
		return
	ctx.run.taken_hook = func(_source: String) -> float:
		redline.note_hit()
		return redline.taken_scale()
	redline.cooked_off.connect(func(_at: Vector3, _force: float):
		if ctx.flow.in_play():
			ctx.run.damage(ctx.run.max_hp * Redline.COOK_OFF_SELF_HULL, Redline.COOK_OFF_SOURCE))


func _on_lobber_fired(origin: Vector3, landing: Vector3, flight: float, lobber: Node3D) -> void:
	var shell := Projectile.new()
	ctx.root.add_child(shell)
	var cover: bool = ctx.flow.in_stage() and ChallengeDials.by_stage_or("hazard.shell_cover_by_stage", ctx.flow.stage(), 0.0) > 0.5
	shell.setup(ctx.player, ground, ctx.root, Callable(ctx.flow, "in_play"), origin, landing, flight, lobber, cover)
	shell.hit_player.connect(_on_player_hit.bind("lobber"))
	shell.returned_landed.connect(on_shell_returned)
	shell.exploded.connect(func(at: Vector3, blast: float, _hit: bool): effects.ring(at, blast, Palette.HAZARD))


func on_shell_returned(shell: Node3D) -> void:
	var ring: Node3D = shell.ring
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead() or not is_instance_valid(ring) or not ring.contains(enemy.global_position - Vector3.UP * enemy.half_height):
			continue
		var owned: bool = enemy == shell.lobber
		strike(enemy, "shell", SHELL_RETURN_DAMAGE)
		if owned and enemy.is_dead():
			discover("shell_return", enemy.global_position)


func _threat() -> float:
	return ctx.flow.stage_def()["threat"]


func _warn_warden_once(stage: int, text: String) -> void:
	if not _warden_warned.has(stage):
		_warden_warned[stage] = true
		push_warning("warden_spec: " + text)


func warden_spec(stage: int) -> Dictionary:
	var def: Dictionary = ctx.flow.stage_def() if stage == ctx.flow.stage() else _stage_table().of(stage)
	var fallback: Dictionary = WARDEN_FALLBACK[clampi(stage, 1, 3) - 1]
	var uses_fallback := false
	for key in fallback:
		uses_fallback = uses_fallback or not def.has(key)
	if stage > WARDEN_FALLBACK.size() and uses_fallback:
		_warn_warden_once(stage, "WARDEN_FALLBACK clamps stage %d to %d" % [stage, WARDEN_FALLBACK.size()])
	var family: String
	if def.has("warden_family"):
		family = String(def["warden_family"])
	else:
		family = Roster.warden_family(stage)
		if stage > Roster.WARDEN_FAMILIES.size():
			_warn_warden_once(stage, "stage %d row has no warden_family; Roster clamps it to %s" % [stage, family])
	return {
		"family": family,
		"plating": float(def.get("warden_plating", fallback["warden_plating"])),
		"hp": float(def.get("warden_hp", fallback["warden_hp"])),
		"posture": def.get("posture", {}),
	}


func _spec_for(kind: String) -> Dictionary:
	var stage: int = ctx.flow.stage()
	match kind:
		"warden":
			var w := warden_spec(stage)
			w["stage"] = stage
			w["reach"] = float(ctx.flow.stage_def().get("beacon_radius", 30.0))
			if ctx.stages == preload("res://src/core/park_defs.gd"):
				const ParkMap := preload("res://src/world/park/park_map.gd")
				var map = ctx.terrain.map()
				if map is ParkMap and map.ok:
					w.merge(map.warden_spec(), true)
					w["reach"] = map.reach_m
					w["park_landmark"] = true
					if ctx.flow.gate != null and ctx.flow.gate.has_gate():
						w["posture_gate"] = Callable(ctx.flow.gate, "locked")
			return w
		"miniboss":
			return {"plating": float(roundi(MINIBOSS_PLATING_SCALE * warden_spec(stage)["plating"]))}
		_ when Rogue.ROWS.has(kind):
			return {"kind": kind, "plating": float(roundi(MINIBOSS_PLATING_SCALE * warden_spec(stage)["plating"]))}
		"vault":
			var next_plating: float = roundf(VAULT_TOP_SCALE * warden_spec(stage)["plating"]) if ctx.stages.is_last(stage) \
					else warden_spec(stage + 1)["plating"]
			return {"stage": stage, "plating": next_plating, "hp": 400.0 * stage}
	return {}


func codex_entries() -> Array:
	return CodexEntries.all()


func run_codex():
	return ctx.get("codex") if ctx != null else null


func _declare_codex() -> void:
	var codex = run_codex()
	if codex == null or not codex.has_method("declare"):
		return
	for entry in CodexEntries.all():
		codex.declare(entry)


func discover(id: String, at: Vector3) -> void:
	if ctx.flow != null and not ctx.flow.in_play():
		return
	if not discovered.has(id):
		discovery_log.append(id)
	discovered[id] = at
	var codex = run_codex()
	if codex != null and codex.has_method("mark_discovered"):
		codex.mark_discovered(id, at, ["player"])


func _on_chain_state(state: String, _target: Node3D, at: Vector3, _cause: String) -> void:
	if state == "chain_link" and ctx.player.chain.combo >= 3:
		discover("chain", at)


func _detect_before(enemy: Node3D, kind: String, _result: Dictionary) -> void:
	var target_kind = enemy.get("kind")
	if kind == "ram" and target_kind == "chaser" and enemy.state_name() == "windup":
		discover("counter_ram", enemy.global_position)


func _detect_after(enemy: Node3D, kind: String, result: Dictionary) -> void:
	if not enemy.has_method("is_dead") or not enemy.is_dead():
		return
	var at: Vector3 = enemy.global_position
	if kind == "ram" and result["plating"] <= 0.0:
		_crushes.append(_clock)
		while not _crushes.is_empty() and _clock - _crushes[0] > CRUSH_WINDOW:
			_crushes.pop_front()
		if _crushes.size() >= CRUSH_CHAIN:
			discover("crush_chain", at)
	if kind in ["runner", "arc", "turret", "sticky", "line"] and _since_slingshot <= PARTING_WINDOW:
		discover("parting_shot", at)


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	_start_attempt()
	churn.reset()
	boils.reset()
	_pressure_chasers = 0
	_line_load = {}
	_escape = {}
	escape_lane = {}
	_reset_cards()
	ctx.camera.shoulder_target = 0.0
	volleys = 0
	last_shot = {}
	last_burst = {}
	_since_slingshot = INF
	rebuild_patterns()


func _on_player_died() -> void:
	_line_load = {}
	_cast_pending = {}
	_clear_input_buffers()
	_bite_pending = false
	_clear_verb_items()
	_reset_w47_c2_state()
	_reset_grapple_muts_state()
	hero_hooks.reset()
	_reset_w47_h2_state()
	consumables.reset()
	if ally_husks != null:
		ally_husks.reset()
	if orbitals != null:
		orbitals.reset_attempt()
	if relic_swaps != null: relic_swaps.reset()
	_clear_aftershocks()
	_rakes.clear()
	_deferred_procs.clear()
	_clear_cannon_paint()
	weapon_driver.reset()


func _on_stage_content_cleared(_reason: String) -> void:
	_start_attempt()
	_line_load = {}
	_escape = {}
	escape_lane = {}
	_reset_cards()


func _start_attempt() -> void:
	_clear_fight()
	_clear_input_buffers()
	_deferred_procs.clear()
	_crushes.clear()
	_shred.clear()
	_guards.clear()
	_pinned.clear()
	_hulks.clear()
	pins = 0
	_echo = {}
	_marks = {}
	_cloud = {}
	_sentry = {}
	_pulse_left = 0.0
	_prow_until.clear()
	_primed.clear()
	assist_charge = 0.0
	_clamped.clear()
	_rakes.clear()
	_clear_aftershocks()
	_heated.clear()
	_clear_exposed()
	_cast_pending = {}
	_bite_pending = false
	_pike_count = 0
	_pike_last = -INF
	_clear_verb_items()
	_reset_w47_c2_state(true)
	_reset_grapple_muts_state(true)
	hero_hooks.reset()
	_reset_w47_h2_state()
	consumables.reset()
	if ally_husks != null:
		ally_husks.reset()
	if orbitals != null:
		orbitals.reset_attempt()
	if relic_swaps != null: relic_swaps.reset()
	consumables.seed_attempt()
	_spring_until = -1.0
	_warden_slam_hits = 0
	_mounted_boost_left = 0.0
	weapon_driver.reset()
	_overdrive = 0.0
	_rocket_left = 0.0
	cloak_left = 0.0
	_clear_combat_buffs()
	last_committed = {}
	for id in ctx.player.abilities.cancel_gauges():
		ctx.events.gauge_cancelled.emit(id, "reset")
	ctx.player.indicator.clear_all()


func _clear_fight() -> void:
	for group in FIGHT_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			node.remove_from_group(group)
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.queue_free()
	bolts.clear()
	_clear_devices()
	effects.clear()
	_free_cannon()


func _clear_devices() -> void:
	sticky.clear()
	ultimate.clear_payloads()
	ultimate.stakes.fold()
	devices.remove(int(_sentry.get("id", 0)))
	_sentry = {}
	devices.clear()


func _refresh_evolutions() -> void:
	_has_grapeshot = _evolution_live("grapeshot_press")
	_has_hoar = _evolution_live("hoar_barrel")
	_has_fault = _evolution_live("fault_hammer")


func _on_build_recomputed(_categories: Array) -> void:
	_refresh_evolutions()
	_sync_grapple_mutations()


func rebuild_patterns() -> void:
	if ctx != null and ctx.build != null and ctx.build.get("stat_cache") != null \
			and not ctx.build.stat_cache.recomputed.is_connected(_on_build_recomputed):
		ctx.build.stat_cache.recomputed.connect(_on_build_recomputed)
	_refresh_evolutions()
	_sync_grapple_mutations()
	var ids := active_transformers()
	var lattice_falloff := 0.0
	if ctx != null and ctx.run != null:
		var sheet: RefCounted = preload("res://src/build/build_sheet.gd").from_parts(ctx.run.parts)
		for _jump in sheet.lattice_chain_jumps():
			ids.append("chain_arc")
			lattice_falloff = Pattern.new().chain_falloff
	for weapon in Weapons.ALL:
		var p: Resource = Weapons.base(weapon).transformed(ids)
		p.lattice_chain_falloff = lattice_falloff
		if ctx != null:
			for row in ctx.player.tree.pattern_ops(weapon):
				p._apply(row)
			p._clamp()
		_patterns[weapon] = p
	if ctx != null and ctx.run != null and ctx.run.class_def != null:
		var active := active_weapon()
		if _patterns.has(active):
			_cadence_window_extended = false
			_cadence_extended_weapon = ""
			weapon_driver.sync_pattern(active, _patterns[active])


func _post_buff(id: String, spec: Dictionary) -> void:
	if ctx != null and ctx.get("buffs") != null:
		ctx.buffs.post(id, spec)


func clear_buff(id: String) -> void:
	if ctx != null and ctx.get("buffs") != null:
		ctx.buffs.clear_id(id)


func _clear_combat_buffs() -> void:
	for id in ["overdrive", "cloak", "spring", "pike", "grapple_mut_live_bus",
			"consumable_nitro_siphon", "consumable_anchor_flare",
			"consumable_overclock_card", "consumable_foreman_memo"]:
		clear_buff(id)


static func _signal_argc(obj: Object, kind: String) -> int:
	for sig in obj.get_signal_list():
		if sig["name"] == kind:
			return sig["args"].size()
	return 0


func bank_body(target: Node3D, _fraction: float, mult: float) -> void:
	var launch: Dictionary = ctx.player.bank_geometry()
	var damage := 10.0 * mult * (0.5 if target_class_of(target) == "boss" else 1.0)
	if target_class_of(target) != "boss" and target.has_method("knock"):
		target.knock(-(launch["dir"] as Vector3), 12.0)
	if target.has_method("flash"):
		target.flash()
	strike(target, "arc", damage, "", "special")
	bank_world(ctx.player.kit.anchor, _fraction, mult)


func bank_world(_anchor: Vector3, _fraction: float, _mult: float) -> void:
	var kit = ctx.player.kit
	var stake = kit.anchor_body
	var switched: bool = is_instance_valid(stake) and stake.is_in_group(Augments.STAKE_GROUP)
	var learned: bool = ctx.codex != null and ctx.codex.known("loaded_line")
	ctx.player.bank_shot()
	if learned:
		discover("bank_shot", _anchor)
		if switched:
			discover("switchback", _anchor)


func bank_geometry(_fraction: float) -> Dictionary:
	return ctx.player.bank_geometry()


func _reset_w47_c2_state(clear_counts := false) -> void:
	_air_steer_surge_left = 0.0
	_air_dash_bat_left = 0.0
	_boost_active_left = 0.0
	_cadence_window_extended = false
	_cadence_extended_weapon = ""
	_prev_window_state = WeaponDriver.WINDOW_IDLE
	_pendulum_zapped.clear()
	_pendulum_swing_charged = false
	_pendulum_swing_origin = Vector3.INF
	_thermobaric_pins.clear()
	_pulled_recent.clear()
	_gravity_ledger_ready_at = -INF
	if clear_counts:
		last_micro_mutation = {}
		last_cross_synergy = {}
		_micro_counts.clear()
		_cross_counts.clear()
	assert(_pendulum_zapped.is_empty() and _thermobaric_pins.is_empty() and _pulled_recent.is_empty())


func _has_micro_mutation(part_id: String) -> bool:
	if ctx == null:
		return false
	var build = ctx.build
	var fx = build.get("effects") if build != null else null
	if fx != null and fx.has_method("has_micro_mutation") and fx.has_micro_mutation(part_id):
		return true
	return ctx.run != null and Parts.has_micro_mutation(ctx.run.parts, part_id)


func _micro_row(part_id: String) -> Dictionary:
	var build = ctx.build if ctx != null else null
	var fx = build.get("effects") if build != null else null
	if fx != null and fx.has_method("micro_mutation"):
		var row: Dictionary = fx.micro_mutation(part_id)
		if not row.is_empty():
			return row
	return Parts.micro_mutation(part_id)


func synergy_context(extra := {}) -> Dictionary:
	var c := extra.duplicate()
	if ctx != null and ctx.run != null:
		if not c.has("heft_class") and ctx.run.has_method("heft_class"):
			c["heft_class"] = ctx.run.heft_class()
		if not c.has("mass"):
			c["mass"] = float(ctx.run.mass)
	if not c.has("has_active"):
		c["has_active"] = actives != null and actives.active_id != ""
	if not c.has("has_consumable") and ctx != null and ctx.run != null:
		c["has_consumable"] = ctx.run.has_consumable()
	if not c.has("has_pull") and ctx != null and ctx.player != null and ctx.player.abilities != null:
		var sp_id: String = ctx.player.abilities.id_of(AbilityState.SPECIAL)
		c["has_pull"] = sp_id in ["gather_plate", "clamp"]
	return c


func _has_cross_synergy(id: String, extra := {}) -> bool:
	if ctx == null:
		return false
	var context := synergy_context(extra)
	var build = ctx.build
	var fx = build.get("effects") if build != null else null
	if fx != null and fx.has_method("has_cross_synergy") and fx.has_cross_synergy(id, context):
		return true
	if ctx.run == null:
		return false
	return Synergies.cross_system_awake(id, ctx.run.parts, OrbitalSatellites.part_synergy_info, context)


func micro_mutation_count(part_id: String) -> int:
	return int(_micro_counts.get(part_id, 0))


func cross_synergy_count(id: String) -> int:
	return int(_cross_counts.get(id, 0))


func air_steer_surge_left() -> float:
	return _air_steer_surge_left


func cadence_window_extended() -> bool:
	return _cadence_window_extended


func active_window_range() -> Vector2:
	return weapon_driver.state_snapshot().get("window_range", Vector2.ZERO)


static func extended_window(base: Vector2, extend_frac: float) -> Vector2:
	if base.y <= base.x or extend_frac <= 0.0:
		return base
	return Vector2(base.x, base.y + (base.y - base.x) * extend_frac)


func _note_micro(part_id: String, details := {}) -> void:
	_micro_counts[part_id] = int(_micro_counts.get(part_id, 0)) + 1
	var entry := details.duplicate()
	entry["part_id"] = part_id
	entry["at_clock"] = _clock
	last_micro_mutation = entry


func _note_cross(id: String, details := {}) -> void:
	_cross_counts[id] = int(_cross_counts.get(id, 0)) + 1
	var entry := details.duplicate()
	entry["id"] = id
	entry["at_clock"] = _clock
	last_cross_synergy = entry


func _stamp_ricochet_canyon(rec: Dictionary, rc_row: Dictionary) -> void:
	rec["extra_bounces"] = clampi(int(rc_row.get("extra_bounces", 2)), 0, Bolts.MAX_EXTRA_BOUNCES)
	rec["ricochet_home"] = true
	rec["ricochet_home_reach"] = float(rc_row.get("home_reach_m", Bolts.RICOCHET_HOME_REACH))
	rec["ricochet_home_turn"] = float(rc_row.get("home_turn", Bolts.RICOCHET_HOME_TURN))


func _step_micro_mutations(delta: float) -> void:
	if _has_micro_mutation("tread_plating") and ctx.player.state.carving:
		var bonus := float(_micro_row("tread_plating").get("rate_bonus", 0.25))
		var refund_s := delta * bonus
		if ctx.player.abilities != null:
			ctx.player.abilities.refund(AbilityState.MOVEMENT, refund_s)
		if ctx.player.state.boost_cooldown > 0.0:
			ctx.player.state.boost_cooldown = maxf(0.0, ctx.player.state.boost_cooldown - refund_s)
		_note_micro("tread_plating", {"refund_s": refund_s})
	if _air_steer_surge_left > 0.0:
		_air_steer_surge_left = maxf(0.0, _air_steer_surge_left - delta)
		if not ctx.player.state.grounded and _has_micro_mutation("long_spool"):
			var wish := _air_steer_wish()
			if wish.length_squared() > 0.0001:
				var mult := float(_micro_row("long_spool").get("steer_mult", 1.65))
				var extra_accel: float = ctx.player.tuning.f("drive_accel") * ctx.player.tuning.f("air_control") * maxf(0.0, mult - 1.0)
				ctx.player.add_external_accel(wish * extra_accel)
	if _air_dash_bat_left > 0.0:
		_air_dash_bat_left = maxf(0.0, _air_dash_bat_left - delta)
	if _boost_active_left > 0.0:
		_boost_active_left = maxf(0.0, _boost_active_left - delta)


func _air_steer_wish() -> Vector3:
	var intent = ctx.player.intent
	if intent == null or intent.move.length_squared() < 0.02:
		return Vector3.ZERO
	var drive_basis: Basis = ctx.camera.drive_basis() if ctx.camera != null and ctx.camera.has_method("drive_basis") else Basis.IDENTITY
	return BallRules.wish_direction(intent, drive_basis, ctx.player.state)


func _on_grapple_released_w47() -> void:
	_pendulum_zapped.clear()
	_pendulum_swing_charged = false
	_pendulum_swing_origin = Vector3.INF
	_on_grapple_released_muts()
	if not _cannon_piton.is_empty():
		_detonate_cannon_piton()
	if not ctx.flow.in_play() or not _has_micro_mutation("long_spool"):
		return
	var dur := float(_micro_row("long_spool").get("duration_s", 0.4))
	_air_steer_surge_left = maxf(_air_steer_surge_left, dur)
	_note_micro("long_spool", {"duration_s": dur})


func _on_dashed_micro(_dir: Vector3) -> void:
	if not ctx.flow.in_play():
		return
	if _has_micro_mutation("dash_vane") and not ctx.player.state.grounded:
		_air_dash_bat_left = maxf(_air_dash_bat_left, float(_micro_row("dash_vane").get("window_s", 0.28)))
	if _has_micro_mutation("boost_coil"):
		_boost_active_left = maxf(_boost_active_left, float(_micro_row("boost_coil").get("window_s", 0.5)))


func _on_boosted_micro(_dir: Vector3) -> void:
	if not ctx.flow.in_play():
		return
	if _has_micro_mutation("boost_coil"):
		_boost_active_left = maxf(_boost_active_left, float(_micro_row("boost_coil").get("window_s", 0.5)))


func _step_cadence_micro(weapon: String, p: Resource, shots: Array) -> void:
	var wsnap: Dictionary = weapon_driver.state_snapshot()
	var cur_state := String(wsnap.get("window", WeaponDriver.WINDOW_IDLE))
	var skilled_hit: bool = cur_state == WeaponDriver.WINDOW_HIT and _prev_window_state != WeaponDriver.WINDOW_HIT
	if not skilled_hit:
		for shot in shots:
			var kind := String(shot.get("kind", ""))
			if bool(shot.get("overclock_skilled", false)) or kind in [WeaponDriver.SHOT_SNAP, WeaponDriver.SHOT_BEAT_3, WeaponDriver.SHOT_STAMP, WeaponDriver.SHOT_RAIL]:
				skilled_hit = true
				break
	if skilled_hit and _has_micro_mutation("loose_trigger") and p != null and p.window_s.y > p.window_s.x:
		var extend_frac := float(_micro_row("loose_trigger").get("window_extend", 0.25))
		var widened: Resource = p.copy()
		widened.window_s = extended_window(p.window_s, extend_frac)
		weapon_driver.sync_pattern(weapon, widened)
		_cadence_window_extended = true
		_cadence_extended_weapon = weapon
		_note_micro("loose_trigger", {"weapon": weapon, "base": p.window_s, "extended": widened.window_s})
	elif _cadence_window_extended:
		var missed: bool = cur_state == WeaponDriver.WINDOW_SPENT and _prev_window_state != WeaponDriver.WINDOW_SPENT
		var swapped: bool = weapon != _cadence_extended_weapon
		if (missed or swapped or not _has_micro_mutation("loose_trigger")) and p != null:
			_cadence_window_extended = false
			_cadence_extended_weapon = ""
			weapon_driver.sync_pattern(weapon, p)
	_prev_window_state = cur_state


func _on_world_fact_w47(kind: String, at: Vector3) -> void:
	if kind != "piece_shattered" or not ctx.flow.in_play():
		return
	if _has_micro_mutation("boost_coil") and (_boost_active_left > 0.0 or ctx.player.kit.sprinting):
		var share := float(_micro_row("boost_coil").get("cd_refresh", 0.5))
		var full_boost: float = ctx.player.tuning.boost_cooldown()
		if ctx.player.state.boost_cooldown > 0.0:
			ctx.player.state.boost_cooldown = maxf(0.0, ctx.player.state.boost_cooldown - full_boost * share)
		if ctx.player.abilities != null:
			var mv_cd: float = ctx.player.abilities.cooldown_of(AbilityState.MOVEMENT)
			if mv_cd > 0.0:
				ctx.player.abilities.refund(AbilityState.MOVEMENT, mv_cd * share)
		_boost_active_left = 0.0
		_note_micro("boost_coil", {"at": at, "refresh_share": share})
	if _has_cross_synergy("demolition_derby"):
		var row := Synergies.cross_system_row("demolition_derby")
		var radius := float(row.get("radius_m", 12.0))
		var dmg := maxf(float(row.get("damage_base", 24.0)), _weapon_hit()) * heft()
		var knock := float(row.get("knock", 10.0))
		effects.shockwave(at, radius, row.get("color", Palette.AMBER))
		var hits := 0
		for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			var reach: float = enemy.global_position.distance_to(at)
			if reach > radius:
				continue
			var scale := clampf(1.0 - reach / (radius * 1.25), 0.35, 1.0)
			deal_hit(enemy, SYNERGY, dmg * scale, enemy.global_position - at, knock, "", "item_proc", "proc")
			hits += 1
		ctx.player.state.boost_cooldown = 0.0
		if ctx.player.abilities != null:
			ctx.player.abilities.grant(AbilityState.MOVEMENT)
		_note_cross("demolition_derby", {"at": at, "radius": radius, "hits": hits})


func _step_cross_synergies(_delta: float, enemies: Array) -> void:
	_step_pendulum_tesla(enemies)
	_step_thermobaric_pins(enemies)


func _step_pendulum_tesla(enemies: Array) -> void:
	var kit = ctx.player.kit
	if not kit.hooked:
		if not _pendulum_zapped.is_empty():
			_pendulum_zapped.clear()
		_pendulum_swing_charged = false
		_pendulum_swing_origin = Vector3.INF
		return
	if not _has_cross_synergy("pendulum_tesla"):
		return
	var row := Synergies.cross_system_row("pendulum_tesla")
	var a: Vector3 = ctx.player.ball_position()
	var b: Vector3 = kit.anchor
	if not _pendulum_swing_origin.is_finite():
		_pendulum_swing_origin = a
	if a.distance_squared_to(b) < 0.25:
		return
	var width := float(row.get("cable_width_m", 1.8))
	var dmg := maxf(float(row.get("damage_base", 18.0)), _weapon_hit() * 0.85)
	var color: Color = row.get("color", Palette.ARC)
	var zapped_now := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var id: int = enemy.get_instance_id()
		if _pendulum_zapped.has(id):
			continue
		var closest := Geometry3D.get_closest_point_to_segment(enemy.global_position, a, b)
		if closest.distance_to(enemy.global_position) > width + hull_radius(enemy):
			continue
		_pendulum_zapped[id] = true
		effects.arc(closest, enemy.global_position + Vector3.UP * 0.5, color)
		deal_hit(enemy, SYNERGY, dmg, enemy.global_position - closest, 3.0, "", "item_proc", "proc")
		zapped_now += 1
	var swept_far: bool = a.distance_to(_pendulum_swing_origin) >= 3.0
	if not _pendulum_swing_charged and (zapped_now > 0 or swept_far):
		_pendulum_swing_charged = true
		var share := float(row.get("special_charge_share", 0.15))
		var abilities = ctx.player.abilities
		if abilities != null:
			var sp_cd: float = abilities.cooldown_of(AbilityState.SPECIAL)
			if sp_cd > 0.0:
				_refund_special(abilities, sp_cd * share)
			else:
				_grant_special(abilities)
		_note_cross("pendulum_tesla", {"zapped": zapped_now, "special_share": share})
	elif zapped_now > 0:
		_note_cross("pendulum_tesla", {"zapped": zapped_now})


func _on_thermobaric_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05 or not ctx.flow.in_play() or not _has_cross_synergy("thermobaric_dunk"):
		return
	var row := Synergies.cross_system_row("thermobaric_dunk")
	var launch_r := float(row.get("launch_radius_m", 10.0))
	var nearby: Array = []
	var has_heated := false
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.global_position.distance_to(at) > launch_r:
			continue
		nearby.append(enemy)
		if heated(enemy):
			has_heated = true
	if not has_heated:
		return
	var launch_speed := float(row.get("launch_speed", 14.0))
	var det_r := float(row.get("detonate_radius_m", 6.5))
	var det_dmg := float(row.get("detonate_damage", 28.0)) * heft()
	var timeout_s := float(row.get("pin_timeout_s", 1.6))
	var color: Color = row.get("color", Palette.RUST)
	var launched := 0
	for enemy in nearby:
		if _fights_posture(enemy) or target_class_of(enemy) == "boss":
			continue
		var id: int = enemy.get_instance_id()
		if _thermobaric_pins.has(id):
			continue
		var away: Vector3 = enemy.global_position - at
		away.y = 0.0
		var dir := (away.normalized() * 0.55 + Vector3.UP * 1.4).normalized()
		if enemy.has_method("knock"):
			var weight = enemy.get("weight")
			enemy.knock(dir, launch_speed * (float(weight) if weight != null else 1.0))
		_thermobaric_pins[id] = {
			"enemy": enemy,
			"start_y": enemy.global_position.y,
			"peak_y": enemy.global_position.y,
			"airborne": false,
			"launched_at": _clock,
			"until": _clock + timeout_s,
			"radius": det_r,
			"damage": det_dmg,
			"color": color,
			"last_pos": enemy.global_position,
		}
		launched += 1
	if launched > 0:
		effects.ring(at, launch_r, color)
		_note_cross("thermobaric_dunk", {"stage": "launch", "launched": launched, "at": at})


func _step_thermobaric_pins(enemies: Array) -> void:
	if _thermobaric_pins.is_empty():
		return
	for id in _thermobaric_pins.keys():
		var pin: Dictionary = _thermobaric_pins[id]
		var enemy = pin["enemy"]
		var valid: bool = is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead())
		var pos: Vector3 = enemy.global_position if valid else Vector3(pin["last_pos"])
		pin["last_pos"] = pos
		var elapsed := _clock - float(pin["launched_at"])
		if valid:
			pin["peak_y"] = maxf(float(pin["peak_y"]), pos.y)
			if pos.y > float(pin["start_y"]) + 0.35 or elapsed >= 0.12:
				pin["airborne"] = true
		var impacted := not valid or _clock >= float(pin["until"])
		if not impacted and bool(pin["airborne"]) and elapsed >= 0.12:
			if enemy is CharacterBody3D and enemy.is_on_floor():
				impacted = true
			elif pos.y <= float(pin["start_y"]) + 0.15 and float(pin["peak_y"]) > float(pin["start_y"]) + 0.35:
				impacted = true
		if not impacted:
			continue
		_thermobaric_pins.erase(id)
		var det_r := float(pin["radius"])
		var det_dmg := float(pin["damage"])
		var color: Color = pin["color"]
		effects.shockwave(pos, det_r, color)
		var hits := 0
		for other in enemies:
			if not is_instance_valid(other) or (other.has_method("is_dead") and other.is_dead()):
				continue
			if other.global_position.distance_to(pos) > det_r:
				continue
			deal_hit(other, SYNERGY, det_dmg, other.global_position - pos, 8.0, "", "item_proc", "proc")
			hits += 1
		_note_cross("thermobaric_dunk", {"stage": "detonate", "at": pos, "hits": hits})


func _check_gravity_ledger(centre: Vector3, pulled_enemies: Array) -> void:
	if not ctx.flow.in_play() or not _has_cross_synergy("gravity_ledger"):
		return
	for e in pulled_enemies:
		if is_instance_valid(e) and not (e.has_method("is_dead") and e.is_dead()):
			_pulled_recent[e.get_instance_id()] = _clock
	for id in _pulled_recent.keys():
		if _clock - float(_pulled_recent[id]) > 0.6:
			_pulled_recent.erase(id)
	if _clock < _gravity_ledger_ready_at:
		return
	var row := Synergies.cross_system_row("gravity_ledger")
	var cluster_r := float(row.get("cluster_radius_m", 5.5))
	var cluster: Array = []
	for id in _pulled_recent.keys():
		var e = instance_from_id(int(id))
		if not is_instance_valid(e) or (e.has_method("is_dead") and e.is_dead()):
			_pulled_recent.erase(id)
			continue
		if e.global_position.distance_to(centre) <= cluster_r:
			cluster.append(e)
	if cluster.size() < 2:
		return
	_gravity_ledger_ready_at = _clock + float(row.get("cooldown_s", 0.35))
	var mid := Vector3.ZERO
	for e in cluster:
		mid += e.global_position
	mid /= float(cluster.size())
	var dmg := float(row.get("crush_damage", 22.0)) * heft()
	var color: Color = row.get("color", Palette.VERDIGRIS)
	effects.ring(mid, cluster_r * 0.6, color)
	for e in cluster:
		if is_instance_valid(e) and not e.is_dead():
			deal_hit(e, SYNERGY, dmg, mid - e.global_position, 6.0, "", "item_proc", "proc")
	var cogs := int(row.get("cog_count", 3))
	if ctx.build != null and ctx.build.get("scrap") != null and ctx.build.scrap.has_method("drop_cogs") \
			and (ctx.flow == null or ctx.flow.in_stage()):
		ctx.build.scrap.drop_cogs(mid, cogs)
	_note_cross("gravity_ledger", {"at": mid, "crushed": cluster.size(), "cogs": cogs})


func on_consumable_used(consumable_id: String, at := Vector3.INF) -> Dictionary:
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return {}
	if actives == null or actives.active_id == "":
		return {}
	if not _has_cross_synergy("catalyst_cartridge", {"has_consumable": true, "has_active": true}):
		return {}
	var row := Synergies.cross_system_row("catalyst_cartridge")
	var gain := float(row.get("active_charge_gain", 0.40))
	var radius := float(row.get("burst_radius_m", 8.0))
	var pos: Vector3 = at if at.is_finite() else ctx.player.ball_position()
	actives.recharge(gain)
	var active_row: Dictionary = actives.row_of(actives.active_id)
	var ring_color: Color = active_row.get("color", row.get("color", Palette.SAND))
	effects.ring(pos, radius, ring_color)
	var result := {
		"fired": true,
		"consumable_id": consumable_id,
		"active_id": actives.active_id,
		"charge_gain": gain,
		"radius": radius,
		"at": pos,
	}
	_note_cross("catalyst_cartridge", result)
	return result


func _reset_grapple_muts_state(clear_counts := false) -> void:
	_hot_wire_cd.clear()
	_det_cord_queue.clear()
	_tether_live.clear()
	_live_bus_charged_until = -1.0
	_live_bus_charges = 0
	_tether_slam_armed.clear()
	clear_buff("grapple_mut_live_bus")
	if ctx != null and ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
		ctx.destructibles.set_swing_heft_bonus(0)
	if clear_counts:
		_grapple_mut_counts.clear()
		last_grapple_mut = {}
	assert(_det_cord_queue.is_empty() and _tether_live.is_empty() and _tether_slam_armed.is_empty())


func _sync_grapple_mutations() -> void:
	if ctx == null:
		return
	var slots := {}
	var build_mod = ctx.build
	var fx = build_mod.get("effects") if build_mod != null else null
	if fx != null and fx.has_method("active_grapple_mutations") and ctx.run != null:
		if fx.get("_held_parts") != ctx.run.parts:
			fx.refresh(ctx.run.parts)
		slots = fx.active_grapple_mutations()
	elif ctx.run != null:
		slots = Parts.active_grapple_mutations(ctx.run.parts)
	_active_grapple_slots = slots
	if ctx.player != null and ctx.player.get("chain") != null and ctx.player.chain.has_method("set_mutations"):
		ctx.player.chain.set_mutations(slots)


func active_grapple_mutations() -> Dictionary:
	_sync_grapple_mutations()
	return _active_grapple_slots.duplicate(true)


func has_grapple_mutation(mut_id: String) -> bool:
	var mid := Parts.grapple_mutation_id_of(mut_id)
	if mid == "":
		return false
	for slot in _active_grapple_slots:
		var row: Variant = _active_grapple_slots[slot]
		if row is Dictionary and String((row as Dictionary).get("id", "")) == mid:
			return true
	return false


func _grapple_mut_row(mut_id: String) -> Dictionary:
	var mid := Parts.grapple_mutation_id_of(mut_id)
	for slot in _active_grapple_slots:
		var row: Variant = _active_grapple_slots[slot]
		if row is Dictionary and String((row as Dictionary).get("id", "")) == mid:
			return row as Dictionary
	return {}


func grapple_mut_count(mut_id: String) -> int:
	return int(_grapple_mut_counts.get(Parts.grapple_mutation_id_of(mut_id), 0))


func live_bus_charged() -> bool:
	return _live_bus_charges > 0 and _clock < _live_bus_charged_until


func det_cord_pending() -> int:
	return _det_cord_queue.size()


func wrecking_flail_taut_active() -> bool:
	if not has_grapple_mutation("wrecking_flail") or ctx == null or ctx.player == null:
		return false
	var kit = ctx.player.kit
	if kit == null or not kit.hooked:
		return false
	return _tether_is_taut(kit, ctx.player.ball_position(), kit.anchor)


func _note_grapple_mut(mut_id: String, details := {}) -> void:
	_grapple_mut_counts[mut_id] = int(_grapple_mut_counts.get(mut_id, 0)) + 1
	var entry := details.duplicate()
	entry["id"] = mut_id
	entry["at_clock"] = _clock
	last_grapple_mut = entry


func _tether_is_taut(kit, ball: Vector3, anchor: Vector3) -> bool:
	if kit == null or not kit.hooked:
		return false
	var dist := ball.distance_to(anchor)
	if dist < 1.0:
		return false
	return dist >= kit.rope * 0.80 or kit.winching or kit.line_state == Augments.LINE_SMASH \
		or ctx.player.state.velocity.length() >= 4.0


static func is_pendulum_apex(ball: Vector3, anchor: Vector3, vel: Vector3, min_y: float, hook_time: float, crossed_bottom: bool) -> bool:
	if hook_time < 0.05:
		return false
	if ball.y >= anchor.y - 0.5:
		return false
	var planar := Vector2(vel.x, vel.z).length()
	if planar < 4.0:
		return false
	return crossed_bottom or (absf(vel.y) <= 6.5 and ball.y <= min_y + 1.8)


func _on_grapple_fired_muts(anchor: Vector3) -> void:
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return
	_sync_grapple_mutations()
	_hot_wire_cd.clear()
	var ball: Vector3 = ctx.player.ball_position()
	var vel: Vector3 = ctx.player.state.velocity
	var kit = ctx.player.kit
	var body: Node3D = kit.anchor_body if kit != null and is_instance_valid(kit.anchor_body) else null
	_tether_live = {
		"from": ball,
		"to": anchor,
		"body": body,
		"hook_time": 0.0,
		"min_y": ball.y,
		"prev_vy": vel.y,
		"crossed_bottom": false,
		"prev_smash": kit != null and kit.line_state == Augments.LINE_SMASH,
		"prev_winch": kit != null and kit.winching,
		"live_bus_checked": false,
	}
	_try_charge_live_bus(body, anchor, ball)


func _try_charge_live_bus(body: Node3D, anchor: Vector3, ball: Vector3) -> void:
	if not has_grapple_mutation("live_bus"):
		return
	if bool(_tether_live.get("live_bus_checked", false)):
		return
	_tether_live["live_bus_checked"] = true
	if not _is_powered_world_prop(body, anchor):
		return
	var row := _grapple_mut_row("live_bus")
	var dur := float(row.get("charge_duration_s", 8.0))
	_live_bus_charges = 1
	_live_bus_charged_until = _clock + dur
	_post_buff("grapple_mut_live_bus", {
		"icon": "cat_damage",
		"tone": Palette.AMBER,
		"duration_s": dur,
		"left_s": dur,
		"kind": BuffLedger.KIND_TIMER,
		"stacks": 1,
		"max_stacks": 1,
	})
	effects.arc(anchor, ball, Palette.AMBER)
	effects.spark(ball, Palette.AMBER)
	_note_grapple_mut("live_bus", {"stage": "charge", "anchor": anchor, "color": Palette.AMBER})


func _is_powered_world_prop(body: Node3D, anchor: Vector3) -> bool:
	if is_instance_valid(body):
		if body.is_in_group("sluice_valve_bite") or body.has_meta("sluice_valve_id"):
			return true
		if body.is_in_group("powered_prop") or bool(body.get_meta("powered", false)):
			return true
		if body.is_in_group(Augments.ANCHOR_GROUP) or body.is_in_group(Augments.WORLD_ANCHOR_GROUP) \
				or body.is_in_group(Augments.STAKE_GROUP) or body.is_in_group(Consumables.BALLOON_GROUP):
			return true
		var bname := body.name.to_lower()
		for kw in ["sluice", "valve", "relay", "mast", "pylon", "conduit", "warden"]:
			if kw in bname:
				return true
	if ctx != null and ctx.root != null:
		for grp in ["sluice_valve_bite", "powered_prop", Augments.STAKE_GROUP, Augments.WORLD_ANCHOR_GROUP]:
			for node in get_tree().get_nodes_in_group(grp):
				if node is Node3D and is_instance_valid(node) and (node as Node3D).global_position.distance_to(anchor) <= 4.0:
					return true
	return false


func _on_grapple_released_muts() -> void:
	_hot_wire_cd.clear()
	if ctx != null and ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
		ctx.destructibles.set_swing_heft_bonus(0)
	if _tether_live.is_empty():
		return
	var snap := _tether_live
	_tether_live = {}
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return
	_sync_grapple_mutations()
	var from: Vector3 = snap.get("from", ctx.player.ball_position())
	var to: Vector3 = snap.get("to", from)
	if has_grapple_mutation("det_cord"):
		_enqueue_det_cord(from, to)
	if has_grapple_mutation("sonic_snap_sling"):
		var ball: Vector3 = ctx.player.ball_position()
		var vel: Vector3 = ctx.player.state.velocity
		if is_pendulum_apex(ball, to, vel, float(snap.get("min_y", ball.y)),
				float(snap.get("hook_time", 0.0)), bool(snap.get("crossed_bottom", false))):
			_fire_sonic_snap_sling(ball, vel)


func _enqueue_det_cord(from: Vector3, to: Vector3) -> void:
	var span := from.distance_to(to)
	if span < 1.5:
		return
	var row := _grapple_mut_row("det_cord")
	var spacing := maxf(1.0, float(row.get("spacing_m", 3.5)))
	var max_nodes := clampi(int(row.get("max_nodes", 6)), 2, 8)
	var count := clampi(int(ceil(span / spacing)), 2, max_nodes)
	var step_delay := float(row.get("step_delay_s", 0.06))
	var radius := float(row.get("blast_radius_m", 4.2))
	var dmg := maxf(float(row.get("damage_base", 22.0)), _weapon_hit() * 0.9) * heft()
	var knock := float(row.get("knock", 9.0))
	for i in count:
		var frac := float(i + 1) / float(count + 1)
		_det_cord_queue.append({
			"at": from.lerp(to, frac),
			"due": _clock + float(i) * step_delay,
			"radius": radius,
			"damage": dmg,
			"knock": knock,
			"index": i,
		})
	_note_grapple_mut("det_cord", {"stage": "queued", "nodes": count, "from": from, "to": to})


func _step_det_cord(enemies: Array) -> void:
	if _det_cord_queue.is_empty():
		return
	var i := 0
	while i < _det_cord_queue.size():
		var entry: Dictionary = _det_cord_queue[i]
		if _clock < float(entry["due"]):
			i += 1
			continue
		_det_cord_queue.remove_at(i)
		assert(not _det_cord_queue.has(entry))
		var at: Vector3 = entry["at"]
		var radius := float(entry["radius"])
		var dmg := float(entry["damage"])
		var knock := float(entry["knock"])
		effects.shockwave(at, radius, Palette.BRASS)
		effects.spark(at, Palette.AMBER)
		var hits := 0
		for enemy in enemies:
			if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			if enemy.global_position.distance_to(at) > radius + hull_radius(enemy):
				continue
			deal_hit(enemy, SYNERGY, dmg, enemy.global_position - at, knock, "", "item_proc", "proc")
			hits += 1
		if ctx.destructibles != null and ctx.destructibles.has_method("on_blast"):
			var hc: int = ctx.run.heft_class() if ctx.run != null and ctx.run.has_method("heft_class") else 1
			ctx.destructibles.on_blast(at, radius, "det_cord", 1, hc)
		_note_grapple_mut("det_cord", {"stage": "detonate", "at": at, "hits": hits, "index": int(entry["index"])})


func _fire_sonic_snap_sling(ball: Vector3, vel: Vector3) -> void:
	var row := _grapple_mut_row("sonic_snap_sling")
	var burst := float(row.get("burst_speed", 12.0))
	var flat := Vector3(vel.x, 0.0, vel.z)
	var cur_speed := flat.length()
	var dir := flat.normalized() if cur_speed > 0.1 else aim_heading()
	var cruise: float = ctx.player.tuning.f("cruise")
	var blazing_floor: float = cruise * float(SpeedTier.MULTIPLES[SpeedTier.BLAZING])
	var target_speed := minf(Augments.POLE_EXIT_CAP, maxf(cur_speed + burst, blazing_floor))
	target_speed = maxf(target_speed, cur_speed + burst)
	ctx.player.set_velocity_now(Vector3(dir.x * target_speed, maxf(vel.y, 2.0), dir.z * target_speed), "sonic_snap_sling")
	ctx.player.refresh_air()
	effects.ring(ball, 4.0, Palette.COPPER)
	effects.spark(ball, Palette.AMBER)
	_note_grapple_mut("sonic_snap_sling", {
		"before_speed": cur_speed,
		"after_speed": target_speed,
		"delta_speed": target_speed - cur_speed,
		"air_refreshed": true,
	})


func _step_grapple_mutations(delta: float, enemies: Array) -> void:
	_sync_grapple_mutations()
	_step_det_cord(enemies)
	if _live_bus_charges > 0 and _clock >= _live_bus_charged_until:
		_live_bus_charges = 0
		_live_bus_charged_until = -1.0
		clear_buff("grapple_mut_live_bus")
	if not _tether_slam_armed.is_empty() and _clock >= float(_tether_slam_armed.get("until", -1.0)):
		_tether_slam_armed.clear()
	var kit = ctx.player.kit
	if kit == null or not kit.hooked:
		if ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
			ctx.destructibles.set_swing_heft_bonus(0)
		if not _tether_live.is_empty():
			_on_grapple_released_muts()
		return
	var ball: Vector3 = ctx.player.ball_position()
	var anchor: Vector3 = kit.anchor
	var vel: Vector3 = ctx.player.state.velocity
	var body: Node3D = kit.anchor_body if is_instance_valid(kit.anchor_body) else null
	if _tether_live.is_empty():
		_tether_live = {
			"from": ball,
			"to": anchor,
			"body": body,
			"hook_time": 0.0,
			"min_y": ball.y,
			"prev_vy": vel.y,
			"crossed_bottom": false,
			"prev_smash": false,
			"prev_winch": false,
			"live_bus_checked": false,
		}
	var prev_vy := float(_tether_live.get("prev_vy", vel.y))
	_tether_live["from"] = ball
	_tether_live["to"] = anchor
	_tether_live["body"] = body
	_tether_live["hook_time"] = float(_tether_live.get("hook_time", 0.0)) + delta
	_tether_live["min_y"] = minf(float(_tether_live.get("min_y", ball.y)), ball.y)
	if prev_vy < -0.5 and vel.y >= -6.5:
		_tether_live["crossed_bottom"] = true
	_tether_live["prev_vy"] = vel.y
	_try_charge_live_bus(body, anchor, ball)

	var taut := _tether_is_taut(kit, ball, anchor)
	if has_grapple_mutation("hot_wire") and taut:
		_step_hot_wire(ball, anchor, enemies)
	if has_grapple_mutation("dragnet_siphon"):
		_step_dragnet_siphon(delta, ball, anchor)
	if has_grapple_mutation("tether_slam"):
		_step_tether_slam(ball, anchor, kit, enemies)
	if has_grapple_mutation("wrecking_flail"):
		_step_wrecking_flail(delta, ball, anchor, kit, taut, enemies)
	elif ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
		ctx.destructibles.set_swing_heft_bonus(0)


func _step_hot_wire(ball: Vector3, anchor: Vector3, enemies: Array) -> void:
	var row := _grapple_mut_row("hot_wire")
	var width := float(row.get("line_width_m", 1.6))
	var float_reach := float(row.get("float_reach_m", 2.2))
	var cd := float(row.get("hit_cooldown_s", 0.35))
	var dmg := maxf(float(row.get("damage_base", 24.0)), _weapon_hit() * 1.15) * heft()
	var sliced_enemies := 0
	var popped_floats := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var kind := _spawn_kind_of(enemy)
		if kind == "boom_tender":
			var popped_arr = enemy.get("popped")
			if popped_arr is Array and enemy.has_method("float_position") and enemy.has_method("pop_float_at"):
				for fi in popped_arr.size():
					if bool(popped_arr[fi]):
						continue
					var fpos: Vector3 = enemy.float_position(fi)
					var c_pt := Geometry3D.get_closest_point_to_segment(fpos, ball, anchor)
					if c_pt.distance_to(fpos) <= float_reach and enemy.pop_float_at(fi, true):
						effects.spark(fpos + Vector3.UP * 0.5, Palette.AMBER)
						popped_floats += 1
		if _fights_posture(enemy) or target_class_of(enemy) in ["Warden", "boss"]:
			continue
		var eid: int = enemy.get_instance_id()
		if _clock < float(_hot_wire_cd.get(eid, -INF)):
			continue
		var closest := Geometry3D.get_closest_point_to_segment(enemy.global_position, ball, anchor)
		if closest.distance_to(enemy.global_position) > width + hull_radius(enemy):
			continue
		_hot_wire_cd[eid] = _clock + cd
		effects.arc(closest, enemy.global_position + Vector3.UP * 0.5, Palette.AMBER)
		effects.spark(closest, Palette.AMBER)
		deal_hit(enemy, SYNERGY, dmg, enemy.global_position - closest, 6.0, "", "item_proc", "proc")
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			_heated[eid] = {"glow": _clock + HEAT_GLOW, "ready": float(_heated.get(eid, {}).get("ready", -INF))}
		sliced_enemies += 1
	var cut_props: Array[String] = []
	if ctx.destructibles != null and ctx.destructibles.has_method("on_segment_cut"):
		cut_props = ctx.destructibles.on_segment_cut(ball, anchor, int(row.get("max_destructible_tier", 2)), width, "hot_wire")
		for pid in cut_props:
			var b: AABB = ctx.destructibles.bounds_of(pid)
			effects.spark(b.get_center(), Palette.AMBER)
	if sliced_enemies > 0 or popped_floats > 0 or not cut_props.is_empty():
		_note_grapple_mut("hot_wire", {
			"enemies": sliced_enemies,
			"floats": popped_floats,
			"props": cut_props,
			"color": Palette.AMBER,
		})


func _step_dragnet_siphon(delta: float, ball: Vector3, anchor: Vector3) -> void:
	var row := _grapple_mut_row("dragnet_siphon")
	var radius := float(row.get("vacuum_radius_m", 5.0))
	var pull_speed := float(row.get("pull_speed", 26.0))
	var pulled_scrap := 0
	var pulled_consumables := 0
	var scrap = ctx.build.get("scrap") if ctx.build != null else null
	if scrap != null and scrap.has_method("pull_along_segment"):
		pulled_scrap = scrap.pull_along_segment(ball, anchor, radius, pull_speed * delta)
	if ctx.run != null and ctx.run.has_method("can_hold_consumable") and ctx.run.can_hold_consumable():
		for cradle in consumables.live_consumable_drops():
			if not is_instance_valid(cradle) or cradle.collected:
				continue
			var closest := Geometry3D.get_closest_point_to_segment(cradle.global_position, ball, anchor)
			if closest.distance_to(cradle.global_position) <= radius:
				cradle.global_position = cradle.global_position.move_toward(ball, pull_speed * delta)
				pulled_consumables += 1
	if pulled_scrap > 0 or pulled_consumables > 0:
		_note_grapple_mut("dragnet_siphon", {"scrap_pulled": pulled_scrap, "consumables_pulled": pulled_consumables})


func _step_tether_slam(ball: Vector3, anchor: Vector3, kit, enemies: Array) -> void:
	var is_smash: bool = kit.line_state == Augments.LINE_SMASH
	var is_winch: bool = bool(kit.winching)
	var prev_smash := bool(_tether_live.get("prev_smash", false))
	var prev_winch := bool(_tether_live.get("prev_winch", false))
	_tether_live["prev_smash"] = is_smash
	_tether_live["prev_winch"] = is_winch
	if (is_smash and not prev_smash) or (is_winch and not prev_winch):
		trigger_tether_slam()
	elif not _tether_slam_armed.is_empty():
		var mid: Vector3 = _tether_slam_armed.get("mid", anchor)
		var target = _tether_slam_armed.get("target")
		var meet_at: Vector3 = target.global_position if is_instance_valid(target) else mid
		if ball.distance_to(meet_at) <= 3.2:
			_detonate_tether_slam_midpoint(meet_at, enemies)


func trigger_tether_slam() -> Dictionary:
	if ctx == null or ctx.player == null or ctx.player.kit == null or not ctx.player.kit.hooked:
		return {}
	if not has_grapple_mutation("tether_slam"):
		return {}
	var kit = ctx.player.kit
	var row := _grapple_mut_row("tether_slam")
	var ball: Vector3 = ctx.player.ball_position()
	var target: Node3D = kit.anchor_body if is_instance_valid(kit.anchor_body) else null
	var target_pos: Vector3 = target.global_position if target != null else kit.anchor
	var mid := (ball + target_pos) * 0.5
	var yank_speed := float(row.get("yank_speed", 24.0))
	var to_mid := mid - ball
	if to_mid.length_squared() > 0.01:
		var spd := maxf(ctx.player.state.velocity.length(), yank_speed)
		var dv: Vector3 = to_mid.normalized() * spd - ctx.player.state.velocity
		ctx.player.add_external_accel(dv * 60.0)
	var yanked_target := false
	if target != null and target.is_in_group(Groups.ENEMY) and not _fights_posture(target) and target_class_of(target) != "boss":
		var pull_dir := mid - target.global_position
		if pull_dir.length_squared() > 0.01:
			var weight = target.get("weight")
			if target.has_method("knock"):
				target.knock(pull_dir.normalized() + Vector3.UP * 0.2, yank_speed * (float(weight) if weight != null else 1.0))
			target.global_position = target.global_position.lerp(mid, 0.5)
			yanked_target = true
			_check_gravity_ledger(mid, [target])
	var armed_window := float(row.get("armed_window_s", 1.2))
	_tether_slam_armed = {
		"target": target,
		"mid": mid,
		"until": _clock + armed_window,
		"mult": float(row.get("crush_mult", 2.0)),
	}
	effects.ring(mid, 3.0, Palette.COPPER)
	var result := {"mid": mid, "yanked_target": yanked_target, "mult": float(_tether_slam_armed["mult"])}
	_note_grapple_mut("tether_slam", {"stage": "yank", "mid": mid, "yanked_target": yanked_target})
	return result


func _detonate_tether_slam_midpoint(at: Vector3, enemies: Array) -> void:
	var row := _grapple_mut_row("tether_slam")
	var mult := float(_tether_slam_armed.get("mult", row.get("crush_mult", 2.0)))
	var radius := float(row.get("slam_radius_m", 8.0))
	var base_dmg := maxf(float(row.get("damage_base", 32.0)), punch_of("slam", Augments.SLAM_KNOCK))
	var dmg := base_dmg * mult
	var knock := float(row.get("knock", 16.0))
	_tether_slam_armed.clear()
	effects.shockwave(at, radius, Palette.COPPER)
	var hits := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.global_position.distance_to(at) > radius + hull_radius(enemy):
			continue
		deal_hit(enemy, SYNERGY, dmg, enemy.global_position - at, knock, "", "item_proc", "proc")
		hits += 1
	if ctx.destructibles != null and ctx.destructibles.has_method("on_blast"):
		var hc: int = ctx.run.heft_class() if ctx.run != null and ctx.run.has_method("heft_class") else 1
		ctx.destructibles.on_blast(at, radius, "tether_slam", 1, hc)
	_note_grapple_mut("tether_slam", {"stage": "crush", "at": at, "mult": mult, "hits": hits})


func _tether_slam_matches(enemy: Node3D, kind: String) -> bool:
	if _tether_slam_armed.is_empty() or _clock >= float(_tether_slam_armed.get("until", -1.0)):
		return false
	if not (kind in CONTACT_KINDS):
		return false
	var target = _tether_slam_armed.get("target")
	return target == null or target == enemy


func _step_wrecking_flail(delta: float, ball: Vector3, _anchor: Vector3, _kit, taut: bool, enemies: Array) -> void:
	var row := _grapple_mut_row("wrecking_flail")
	var bonus := clampi(int(row.get("heft_bonus", 1)), 0, 1) if taut else 0
	if ctx.destructibles != null and ctx.destructibles.has_method("set_swing_heft_bonus"):
		ctx.destructibles.set_swing_heft_bonus(bonus)
	if not taut:
		return
	var vel: Vector3 = ctx.player.state.velocity
	var reach := float(row.get("swing_reach_m", 3.2))
	var hc: int = ctx.run.heft_class() if ctx.run != null and ctx.run.has_method("heft_class") else 1
	var broken: Array[String] = []
	if ctx.destructibles != null and ctx.destructibles.has_method("on_taut_swing"):
		broken = ctx.destructibles.on_taut_swing(ball, vel, hc, bonus, reach, delta)
		for pid in broken:
			var b: AABB = ctx.destructibles.bounds_of(pid)
			effects.ring(b.get_center(), 3.2, Palette.STEEL)
			effects.spark(b.get_center(), Palette.AMBER)
	var shredded := 0
	var flat_speed := Vector2(vel.x, vel.z).length()
	if flat_speed >= float(row.get("min_speed", 8.0)):
		var shred_amt := float(row.get("armor_shred_bonus", 25.0))
		for enemy in enemies:
			if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			if enemy.global_position.distance_to(ball) > reach + hull_radius(enemy):
				continue
			var had_armor := false
			if "plates" in enemy and int(enemy.plates) > 0:
				enemy.plates = maxi(0, int(enemy.plates) - 1)
				had_armor = true
			if enemy.has_method("plating_for") and float(enemy.plating_for("ram", "")) > 0.0:
				add_shred(enemy, shred_amt)
				had_armor = true
			if had_armor:
				effects.spark(enemy.global_position + Vector3.UP * 0.5, Palette.AMBER)
				shredded += 1
	if not broken.is_empty() or shredded > 0:
		_note_grapple_mut("wrecking_flail", {"broken": broken, "shredded": shredded, "effective_heft": mini(Destructibles.TIER_MAX, hc + bonus)})


func _consume_grapple_mut_strike(hit: Dictionary) -> void:
	var enemy: Node3D = hit["enemy"]
	var kind: String = hit["kind"]
	var cls: String = hit["cls"]
	var dealt := float(hit["result"].get("dealt", 0.0))
	if live_bus_charged() and cls != "debris" and kind != "live_bus" and dealt > 0.0:
		var row := _grapple_mut_row("live_bus")
		var bonus_flat := float(row.get("bonus_flat", 24.0))
		var arc_r := float(row.get("arc_radius_m", 8.0))
		_live_bus_charges = 0
		_live_bus_charged_until = -1.0
		clear_buff("grapple_mut_live_bus")
		var at: Vector3 = hit["at"]
		effects.arc(ctx.player.ball_position() + Vector3.UP * 0.5, at + Vector3.UP * 0.5, Palette.AMBER)
		effects.ring(at, 4.5, Palette.AMBER)
		var arced_to: Node3D = null
		for other in get_tree().get_nodes_in_group(Groups.ENEMY):
			if other == enemy or not is_instance_valid(other) or (other.has_method("is_dead") and other.is_dead()):
				continue
			if _fights_posture(other):
				continue
			if other.global_position.distance_to(at) <= arc_r:
				arced_to = other
				break
		if arced_to != null:
			effects.arc(at + Vector3.UP * 0.5, arced_to.global_position + Vector3.UP * 0.5, Palette.AMBER)
			trail_deal(arced_to, bonus_flat, "live_bus", "item_proc")
		_note_grapple_mut("live_bus", {"stage": "discharge", "at": at, "dealt": dealt, "arced": arced_to != null, "color": Palette.AMBER})
	if _tether_slam_matches(enemy, kind) and dealt > 0.0:
		var mult := float(_tether_slam_armed.get("mult", 2.0))
		_tether_slam_armed.clear()
		effects.shockwave(hit["at"], 6.0, Palette.COPPER)
		_note_grapple_mut("tether_slam", {"stage": "contact_crush", "at": hit["at"], "mult": mult, "dealt": dealt})
	if wrecking_flail_taut_active() and kind in CONTACT_KINDS and is_instance_valid(enemy):
		add_shred(enemy, float(_grapple_mut_row("wrecking_flail").get("armor_shred_bonus", 25.0)))
		if "plates" in enemy and int(enemy.plates) > 0:
			enemy.plates = maxi(0, int(enemy.plates) - 1)

func _ghost_shift_ops() -> Array:
	var out: Array = []
	if ctx == null or ctx.player == null or ctx.player.tree == null:
		return out
	for p in ctx.player.tree.procs():
		var gs := String(p.get("ghost_shift", ""))
		if gs != "" and not out.has(gs):
			out.append(gs)
	return out


func ghost_shift_unlocked() -> bool:
	return not _ghost_shift_ops().is_empty()


func ghost_shift_extra_seats() -> int:
	return 1 if _ghost_shift_ops().has("seat_and_bits") else 0


func ghost_shift_has_severance() -> bool:
	return _ghost_shift_ops().has("severance_and_bits")


func ghost_shift_inherits_bits() -> bool:
	var ops := _ghost_shift_ops()
	return ops.has("seat_and_bits") or ops.has("severance_and_bits")


func ally_husk_hit(_husk: Node3D, enemy: Node3D, damage: float, origin: Vector3, shot_bits := 0) -> float:
	if enemy == null or not is_instance_valid(enemy) or DamageDoor.dead(enemy):
		return 0.0
	var final_damage := damage
	var chip := CHIP
	var knock := Weapons.LEDGER_KNOCK
	if ShotBits.has(shot_bits, ShotBits.bit("heat")):
		var heat := apply_heat(enemy, enemy.global_position)
		final_damage *= float(heat["mult"])
	if ShotBits.has(shot_bits, ShotBits.bit("pierce")):
		chip = Weapons.PIERCE_CHIP
	if ShotBits.has(shot_bits, ShotBits.bit("bounce")):
		knock *= 1.35
	var pull_dir := Vector3.ZERO
	var pull_mag := 0.0
	if ShotBits.has(shot_bits, ShotBits.bit("pull")):
		pull_mag = pull_force(heft(), Roster.heft_of(enemy), 0)
		var toward: Vector3 = origin - enemy.global_position
		toward.y = 0.0
		if pull_mag > 0.0 and toward.length() > 0.01:
			pull_dir = toward.normalized()
			knock = 0.0
	var dealt := 0.0
	if (enemy.has_method("_apply_posture") and enemy.has_method("staggered")) or target_class_of(enemy) == "boss":
		dealt = ult_hit(enemy, "ledger", final_damage, origin, false)
	elif not (enemy.has_method("knock") and enemy.has_method("flash")):
		strike(enemy, "ledger", final_damage, "", "persistent_actor", "", chip)
		dealt = final_damage
	else:
		deal_hit(enemy, "ledger", final_damage, enemy.global_position - origin, knock, "", "persistent_actor", "", chip)
		dealt = final_damage
	if pull_mag > 0.0 and pull_dir != Vector3.ZERO and is_instance_valid(enemy) and not enemy.is_dead():
		enemy.knock(pull_dir, pull_mag)
	if ShotBits.has(shot_bits, ShotBits.bit("split")):
		var best: Node3D = null
		var best_d := 6.0
		for other in get_tree().get_nodes_in_group(Groups.ENEMY):
			if other == enemy or not is_instance_valid(other) or DamageDoor.dead(other):
				continue
			var d: float = other.global_position.distance_to(enemy.global_position)
			if d <= best_d:
				best_d = d
				best = other
		if best != null:
			effects.arc(enemy.global_position + Vector3.UP * 0.8, best.global_position + Vector3.UP * 0.8, Palette.AMBER)
			ally_husk_hit(_husk, best, damage * 0.5, enemy.global_position, 0)
	return dealt


var _cannon_recoil_airborne := false
var _cannon_recoil_air_grace := 0.0
var _cannon_piton := {}
var last_cannon_piton := {}
var last_cannon_recoil_reset := {}


func _reset_w47_h2_state() -> void:
	_cannon_recoil_airborne = false
	_cannon_recoil_air_grace = 0.0
	_cannon_piton = {}
	last_cannon_piton = {}
	last_cannon_recoil_reset = {}
	var tarn_claw = get_node_or_null("TarnClaw")
	if tarn_claw != null and tarn_claw.has_method("_clear"):
		tarn_claw._clear()


func cannon_recoil_airborne() -> bool:
	if not _cannon_recoil_airborne or ctx == null or ctx.player == null:
		return false
	return not ctx.player.state.grounded or _cannon_recoil_air_grace > 0.0


func _step_cannon_recoil_airborne(delta: float) -> void:
	if _cannon_recoil_air_grace > 0.0:
		_cannon_recoil_air_grace = maxf(0.0, _cannon_recoil_air_grace - delta)
	if _cannon_recoil_airborne and _cannon_recoil_air_grace <= 0.0 and ctx != null and ctx.player != null and ctx.player.state.grounded and not ctx.player.kit.slamming:
		_cannon_recoil_airborne = false


func _on_cannon_grapple_fired(anchor: Vector3) -> void:
	if ctx == null or ctx.player == null or ctx.player.abilities == null:
		return
	if ctx.player.abilities.id_of(AbilityState.LINE) != "cannon_lane_charge":
		return
	var kit = ctx.player.kit
	if kit.hooked and not kit.on_body:
		_arm_cannon_piton(anchor, kit.anchor_normal, float(ctx.player.chain.multiplier()))


func _arm_cannon_piton(anchor: Vector3, normal: Vector3, mult := 1.0) -> void:
	_cannon_piton = {
		"anchor": anchor,
		"normal": normal,
		"staked": true,
		"mult": maxf(mult, 1.0),
		"recoil_cancelled": false,
		"armed_at": _clock,
	}
	last_cannon_piton = {
		"mode": "stake",
		"at": anchor,
		"recoil_cancelled": false,
		"hits": 0,
		"walls_broken": [],
	}


func cannon_piton_staked() -> bool:
	return not _cannon_piton.is_empty() and bool(_cannon_piton.get("staked", false)) \
		and ctx != null and ctx.player != null and ctx.player.kit.hooked and not ctx.player.kit.on_body


func cannon_piton_state() -> Dictionary:
	return _cannon_piton.duplicate()


func _step_cannon_piton() -> void:
	if _cannon_piton.is_empty():
		return
	var kit = ctx.player.kit
	if not kit.hooked or kit.on_body:
		if String(kit.line_end) == "reset":
			_cannon_piton = {}
		else:
			_detonate_cannon_piton()


func _detonate_cannon_piton() -> Dictionary:
	if _cannon_piton.is_empty():
		return {}
	var piton := _cannon_piton
	_cannon_piton = {}
	var anchor: Vector3 = piton["anchor"]
	var mult: float = float(piton.get("mult", 1.0))
	var radius := Weapons.CANNON_PITON_BREACH_RADIUS
	var broken: Array[String] = []
	if ctx.destructibles != null and is_instance_valid(ctx.destructibles) and ctx.destructibles.has_method("on_piton_breach"):
		broken = ctx.destructibles.on_piton_breach(anchor, radius, Weapons.CANNON_PITON_MAX_TIER, "cannon_piton_breach")
	var dmg: float = Weapons.CANNON_PITON_BREACH_DAMAGE * mult * damage_mod(Weapons.CANNON_LANE)
	var hits := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if DamageDoor.dead(enemy) or not in_ring(anchor, radius, enemy):
			continue
		var push: Vector3 = enemy.global_position - anchor
		deal_hit(enemy, "cannon", dmg, push, Weapons.CANNON_PITON_BREACH_KNOCK, "", "special")
		hits += 1
	effects.ring(anchor, radius, Palette.ANCIENT)
	effects.spark(anchor + Vector3.UP * 0.4, Palette.SAND)
	last_cannon_piton = {
		"mode": "breach",
		"at": anchor,
		"radius": radius,
		"hits": hits,
		"damage": dmg,
		"walls_broken": broken,
		"recoil_cancelled": bool(piton.get("recoil_cancelled", false)),
	}
	return last_cannon_piton


static func spawnable_kinds(world := 0) -> Array[String]:
	var found: Array[String] = []
	for kind in KINDS + Rogue.ROWS.keys() + Fleet.SCRIPTS.keys() + Roster.ROWS.keys():
		if kind in found:
			continue
		if Roster.has(kind) and not Fleet.SCRIPTS.has(kind) and not kind in KINDS and not Rogue.ROWS.has(kind):
			if not Roster.row(kind).has("script") or not Roster.built(kind):
				continue
		var w := int(Rogue.ROWS[kind].get("world", 0)) if Rogue.ROWS.has(kind) else int(Roster.row(kind).get("world", 0))
		if world == 0 or w in [0, world]:
			found.append(kind)
	return found


static func kind_label(kind: String) -> String:
	if Rogue.ROWS.has(kind):
		return String(Rogue.ROWS[kind].name)
	var named := Roster.name_of(kind) if Roster.has(kind) else ""
	return named if named != "" else kind.replace("_", " ")
