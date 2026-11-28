extends Node

const Companion := preload("res://src/core/companion.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const CalledShot := preload("res://src/build/called_shot.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const HullMark := preload("res://src/world/hull_mark.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const ElementField := preload("res://src/build/element_field.gd")
const Elements := preload("res://src/build/elements.gd")
const Accretion := preload("res://src/build/accretion.gd")
const Parts := preload("res://src/build/parts.gd")
const HotwireRules := preload("res://src/build/hotwire_rules.gd")
const Synergies := preload("res://src/build/synergies.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const StatCache := preload("res://src/build/stat_cache.gd")
const Palette := preload("res://src/core/palette.gd")
const Triggers := preload("res://src/build/triggers.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const RunClock := preload("res://src/build/run_clock.gd")
const Shop := preload("res://src/build/shop.gd")
const Lanes := preload("res://src/build/lanes.gd")
const RunState := preload("res://src/core/run_state.gd")
const Relics := preload("res://src/build/relics.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")
const MakerBonuses := preload("res://src/build/maker_bonuses.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const Panels := preload("res://src/build/panels.gd")
const PanelShell := preload("res://src/build/panel_shell.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Consumables := preload("res://src/build/consumables.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const HotwireShell := preload("res://src/build/hotwire_shell.gd")
const RelicSync := preload("res://src/build/relic_sync.gd")
const SynergyRuntime := preload("res://src/build/synergy_runtime.gd")


const GATE_CHOICES := 2
const SHELL_SCRAP_PER_HP := HotwireShell.SHELL_SCRAP_PER_HP
const SHELL_AIR_FACTOR := HotwireShell.SHELL_AIR_FACTOR
const RIVETED_SHELL := HotwireShell.RIVETED_SHELL
const RIVETED_ARMOUR := HotwireShell.RIVETED_ARMOUR
const RIVETED_AIR_FACTOR := HotwireShell.RIVETED_AIR_FACTOR
const SHELL_VAULT_WINDOW := HotwireShell.SHELL_VAULT_WINDOW
const SHELL_AIR_FACTOR_VAULT := HotwireShell.SHELL_AIR_FACTOR_VAULT
const SHELL_AIR_FACTOR_SPRINT := HotwireShell.SHELL_AIR_FACTOR_SPRINT
signal shell_air_changed(factor: float, rose: bool)
signal set_completed(set_id: String, title: String, text: String, color: Color)
const PARTICIPANTS := ["player"]
const LEVEL_NAMES := ["", "II", "III"]
const FROST_TRAIL := 0.7
const PUFF_EVERY := 3
const ARC_RADIUS := 8.0
const ARC_DAMAGE := 18.0
const REFREEZE_RING := 4.0
const WARDEN_LINE := 20.0
const ROD_REACH := SynergyRuntime.ROD_REACH
const ROD_DAMAGE := SynergyRuntime.ROD_DAMAGE
const ROD_PER_SECOND := SynergyRuntime.ROD_PER_SECOND
const TESLA_REACH := SynergyRuntime.TESLA_REACH
const TESLA_DAMAGE := SynergyRuntime.TESLA_DAMAGE
const TESLA_EVERY := SynergyRuntime.TESLA_EVERY
const TESLA_TARGETS := SynergyRuntime.TESLA_TARGETS
const WRECK_RADIUS := SynergyRuntime.WRECK_RADIUS
const SYNERGY_KIND := SynergyRuntime.SYNERGY_KIND
const SYNERGY_PUNCH := SynergyRuntime.SYNERGY_PUNCH
const WRECK_FORCE := SynergyRuntime.WRECK_FORCE
const SHRAPNEL_RADIUS := SynergyRuntime.SHRAPNEL_RADIUS
const SHRAPNEL_FORCE := SynergyRuntime.SHRAPNEL_FORCE
const SHRAPNEL_TARGETS := SynergyRuntime.SHRAPNEL_TARGETS
const SHRAPNEL_PER_SECOND := SynergyRuntime.SHRAPNEL_PER_SECOND
const GLACIER_IMPACT := SynergyRuntime.GLACIER_IMPACT
const GLACIER_RADIUS := SynergyRuntime.GLACIER_RADIUS
const PINWHEEL_RADIUS := SynergyRuntime.PINWHEEL_RADIUS
const PINWHEEL_FORCE := SynergyRuntime.PINWHEEL_FORCE
const PINWHEEL_EVERY := SynergyRuntime.PINWHEEL_EVERY
const PINWHEEL_TIER := SynergyRuntime.PINWHEEL_TIER
const PINWHEEL_TARGETS := SynergyRuntime.PINWHEEL_TARGETS

var ctx
var scrap
var gates
var fabricators
var field
var accretion
var panel_shell
var dropper = Panels.Dropper.new()
var panel_rng := RandomNumberGenerator.new()
var scrap_rng := RandomNumberGenerator.new()
var chain_rng := RandomNumberGenerator.new()
var _vaults_paid := 0
var _overtimes_paid := 0
var called_shot: Node3D
var panel_overflow := 0
var panel_effective := {}
var _stage_dry := 0
var _no_cells_logged := {}
var _caches_pending := false
var _caches_wait := 0
var _cache_spots: Array = []
var kill_log: Array = []
const KILL_LOG_CAP := 4000
var _hotwire := HotwireShell.new()
var _relic_sync := RelicSync.new()
var _synergies := SynergyRuntime.new()
var _woken: Dictionary:
	get:
		return _synergies.woken
	set(v):
		_synergies.woken = v
var _found: Dictionary:
	get:
		return _synergies.found_map
	set(v):
		_synergies.found_map = v
var _kills: Array[Vector3]:
	get:
		return _synergies.kills
	set(v):
		_synergies.kills = v
var _rams: Array[Vector3]:
	get:
		return _synergies.rams
	set(v):
		_synergies.rams = v
var _relic_fx: Dictionary:
	get:
		return _relic_sync.fx
	set(v):
		_relic_sync.fx = v
var _shell_window: float:
	get:
		return _hotwire.shell_window
	set(v):
		_hotwire.shell_window = v
var _hotwire_state: String:
	get:
		return _hotwire.state
	set(v):
		_hotwire.state = v
var _hotwire_spent: bool:
	get:
		return _hotwire.spent
	set(v):
		_hotwire.spent = v
var tread_fires: int:
	get:
		return _hotwire.tread_fires
	set(v):
		_hotwire.tread_fires = v
var sheet
var stat_cache = StatCache.new()
var _shot_masks: Array = []
var _shot_by_live := {}
var bus
var effects
var clock
var shop
var lanes
var makers
var _next_modifiers := {}
var _offered := {}
var loot_rng := RandomNumberGenerator.new()
const LOOT_SEED := 20260927
var _own_strikes := 0
var _last_strike_kind := ""
var _last_smash_frame := -1
var _speed_tier := 0
var _mass_hp := 0.0

var _trail := 0.0
var _trail_ticks := 0
var _slams: Array[Dictionary] = []
var _shots: Array[Vector3] = []
var _declared := false


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Build"
	Synergies.set_table(ctx.stages)
	sheet = stat_cache.sync([])
	scrap = ScrapField.new()
	scrap.name = "Scrap"
	ctx.root.add_child(scrap)
	scrap.setup()
	gates = RewardGates.new()
	gates.name = "RewardGates"
	ctx.root.add_child(gates)
	gates.setup(ctx.terrain)
	called_shot = CalledShot.new()
	ctx.root.add_child(called_shot)
	called_shot.setup(ctx)
	gates.mark_for = offer_mark
	gates.active_row = _active_row
	gates.playing = func() -> bool: return ctx.flow == null or ctx.flow.in_play()
	gates.chosen.connect(_on_gate_chosen)
	fabricators = Fabricators.new()
	fabricators.name = "Fabricators"
	ctx.root.add_child(fabricators)
	fabricators.mark_for = offer_mark
	field = ElementField.new()
	field.name = "ElementField"
	ctx.root.add_child(field)
	field.setup(ctx)
	field.resolved.connect(_on_element_resolved)
	field.fused.connect(_on_fused)
	field.extended_fused.connect(_on_fused)
	accretion = Accretion.new()
	ctx.player.roll_node().add_child(accretion)
	accretion.setup()
	panel_shell = PanelShell.new()
	ctx.player.roll_node().add_child(panel_shell)
	bus = Triggers.Bus.new()
	effects = ItemEffects.new(self)
	clock = RunClock.new()
	shop = Shop.new(ctx, self)
	lanes = Lanes.new()
	makers = MakerBonuses.new(self)
	ctx.build = self
	ctx.set_meta("build", self)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.flow_changed.connect(_on_flow_changed)
	ctx.events.part_gained.connect(_on_part_gained)
	ctx.events.part_gained.connect(_on_relic_gained)
	ctx.events.panel_gained.connect(func(_id: String, _count: int, _at: Vector3, _jackpot: bool): recompute())
	ctx.events.scrap_collected.connect(_on_scrap_collected)
	ctx.events.milestone_won.connect(_on_milestone_won)
	ctx.events.dashed.connect(_on_dashed)
	ctx.events.slammed.connect(_on_slammed)
	ctx.events.landed.connect(_on_landed)
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	ctx.events.shot_fired.connect(_on_shot_fired)
	ctx.events.run_started.connect(_on_run_started)
	ctx.events.scrap_lost.connect(_on_scrap_lost)
	ctx.events.line_state_changed.connect(_on_line_state)
	ctx.run.armor_hit.connect(_on_armor_hit)
	ctx.run.death_save_hook = effects.death_save_hull
	_sync_scrap_flags()
	ctx.events.heft_class_changed.connect(func(_c: int, _h: float): _redraw())
	_connect_triggers()
	ctx.events.beacon_unsealed.connect(func(_stage: int): clock.warden_broken())
	ctx.events.warden_engaged.connect(func(_stage: int): clock.warden_engaged())
	ctx.events.beacon_unsealed.connect(_on_warden_broken_hotwire)
	ctx.events.beacon_unsealed.connect(func(_stage: int): HullMark.lift(ctx.run))
	ctx.events.enemy_struck.connect(_on_tread_struck)
	ctx.events.player_died.connect(func(): shop.note_death(ctx.run.cogs))
	ctx.events.core_gained.connect(_on_core_gained)
	ctx.events.activity_done.connect(func(_id: String, at: Vector3): Companion.on_yard_cleared(ctx.run, ctx.spawner, at))
	ctx.events.stage_cleared.connect(_on_stage_cleared_contracts)
	ctx.events.world_fact.connect(_on_world_fact_overrides)
	makers.setup()


func pattern_level(pattern_id: String) -> int:
	return sheet.pattern_level(pattern_id)


func patterns() -> Dictionary:
	return sheet.patterns.duplicate()


func has_transformer(transformer_id: String) -> bool:
	return transformer_id in sheet.transformers


func weapon_mod(key: String) -> float:
	return sheet.mod(key)


func punch_bonus() -> float:
	return sheet.punch


func panel_punch() -> float:
	return sheet.panel_punch


func shot_bits() -> int:
	return int(_shot_fold()["bits"]) if _weapon_fires_bolts() else 0


func dropped_shot_bits() -> Array:
	return ShotBits.names(int(_shot_fold()["dropped"])) if _weapon_fires_bolts() else []


func _shot_fold() -> Dictionary:
	var live_mask := int(ctx.tuning.f("shot_bits_live"))
	if not _shot_by_live.has(live_mask):
		_shot_by_live[live_mask] = ShotBits.shot(_shot_masks.map(func(mask: int) -> int: return ShotBits.live(mask, live_mask)))
	return _shot_by_live[live_mask]


func _weapon_fires_bolts() -> bool:
	var abilities = ctx.player.get("abilities") if ctx.player != null else null
	return abilities == null or bool(abilities.cap(AbilityState.WEAPON, "bolts", true))


func _fold_shot_masks() -> void:
	_shot_masks = []
	for part_id in ctx.run.parts:
		var d: Resource = Parts.def(part_id)
		if d != null:
			_shot_masks.append(int(d.bits))
	_shot_by_live = {}


func active_synergies() -> Array:
	return sheet.synergies.duplicate()


func power() -> float:
	return sheet.power()


func part_info(part_id: String) -> Dictionary:
	var d: Resource = Parts.def(part_id)
	if d == null:
		return {"id": part_id, "name": Parts.display_name(part_id)}
	return {"id": d.id, "name": d.display_name, "verb": d.verb, "text": d.text, "punch": d.punch,
		"tags": d.tags, "rarity": d.rarity, "tier": d.tier, "family": d.family}


func codex_declarations() -> Array:
	var cards: Array = Synergies.declarations(func(maker: String) -> String: return String(MakerSets.SETS.get(maker, {}).get("name", maker)))
	for entry in Lanes.ENTRIES:
		cards.append(entry.duplicate())
	return cards


func discovered() -> Array:
	return _synergies.discovered()


func found() -> Array:
	return _synergies.found()


func is_known(synergy_id: String) -> bool:
	return _synergies.is_known(self, synergy_id)


func apply_element(element_id: String, at: Vector3, source := "") -> Dictionary:
	return field.apply(element_id, at, source)


func material_at(point: Vector3) -> Dictionary:
	return field.material_at(point)


func register_material(material_id: String, provider: Callable) -> void:
	field.register_material(material_id, provider)


static func resolve(element_id: String, material_id: String) -> Dictionary:
	return Elements.resolve(element_id, material_id)


func offer_mark(part_id: String) -> String:
	var held: Array = ctx.run.parts
	var completes := Parts.completed_by(part_id, held)
	if completes != "":
		return "* completes %s *" % Synergies.ROWS[completes]["name"]
	var level := Parts.level_of(part_id, held)
	if level > 0 and level < LEVEL_NAMES.size():
		return "* level %s *" % LEVEL_NAMES[level]
	var starts := Parts.started_by(part_id, held) if has_perk("lens") else ""
	if starts != "":
		return "* starts %s *" % Synergies.ROWS[starts]["name"]
	return ""


func enemies_near(at: Vector3, radius: float, count: int) -> Array[Node3D]:
	return _enemies_near(at, radius, count)


func item_hit(enemy: Node3D, damage: float, element := "") -> void:
	if not is_instance_valid(enemy) or damage <= 0.0:
		return
	_own_strikes += 1
	var at := enemy.global_position
	_strike(enemy, SYNERGY_KIND, damage * sheet.mod("weapon_damage"))
	if element != "":
		field.apply(element, at, "item")
	_own_strikes -= 1


func item_procs() -> Dictionary:
	return effects.procs.duplicate()


func maker_counts() -> Dictionary:
	makers.refresh()
	return makers.counted.duplicate()


func maker_bonuses() -> Array:
	makers.refresh()
	return makers.live.duplicate()


func maker_fires_twice() -> bool:
	return makers.fires_twice()


func trigger_stats() -> Dictionary:
	return {"passes": bus.passes, "fired": bus.fired.duplicate(), "refused": bus.refused,
		"max_same_kind": bus.max_same_kind, "leaked": bus.leaked()}


func has_perk(perk: String) -> bool:
	return effects.perks.has(perk)


func set_modifiers(chosen: Dictionary) -> void:
	_next_modifiers = chosen.duplicate()


func run_tags() -> Array:
	return clock.tags()


func scrapless() -> bool:
	return clock.on(RunClock.SCRAPLESS)


func clock_record() -> Dictionary:
	return clock.record(has_perk("par"))


func clock_paused() -> bool:
	return shop.clock_paused()


func _refresh_seams() -> void:
	var spawner = ctx.spawner
	var patterns: PackedStringArray = spawner.transformer_ids() if spawner != null and spawner.has_method("transformer_ids") else PackedStringArray()
	Parts.set_seams({
		"spawner.extend_cloak": spawner != null and spawner.has_method("extend_cloak"),
		"spawner.fan_spread": "fan_spread" in patterns,
		"spawner.helix_drill": "helix_drill" in patterns,
		"player.set_vault_cooldown_scale": ctx.player.has_method("set_vault_cooldown_scale"),
		"player.set_vault_charges": ctx.player.has_method("set_vault_charges"),
	})


func _post(kind: int, source: String, proc: float, at: Vector3, enemy: Node3D = null, amount := 0.0) -> void:
	if proc <= 0.0 or not ctx.flow.in_play():
		return
	bus.post(Triggers.Commitment.new(kind, source, proc, at, enemy, amount))


func _connect_triggers() -> void:
	var events = ctx.events
	events.enemy_struck.connect(_on_struck_trigger)
	events.enemy_killed.connect(func(_kind: String, at: Vector3, _scrap: int):
		if ctx.run.last_kill_triggerless:
			return
		_post(Triggers.Kind.ON_KILL, _last_strike_kind, Triggers.strike_proc(_last_strike_kind), at))
	for smash in ["slammed", "arc_slammed", "skid_smashed", "demo_slammed"]:
		if events.has_signal(smash):
			events.connect(smash, _on_smash_trigger.unbind(_argc(events, smash)))
	if events.has_signal("enemy_rebounded"):
		events.enemy_rebounded.connect(func(enemy: Node3D, speed: float):
			_post(Triggers.Kind.ON_REBOUND, "rebound", Triggers.DISCRETE_PROC, ctx.player.ball_position(), enemy, speed))
	if events.has_signal("vault_kicked"):
		events.vault_kicked.connect(func(at: Vector3, speed: float):
			_post(Triggers.Kind.ON_VAULT, "vault", Triggers.DISCRETE_PROC, at, null, speed)
			_open_shell_window())
	if events.has_signal("gauge_released"):
		events.gauge_released.connect(func(ability_id: String, fraction: float):
			_post(Triggers.Kind.ON_CHARGE_RELEASE, ability_id, Triggers.DISCRETE_PROC, ctx.player.ball_position(), null, fraction))
	if events.has_signal("cloak_broken"):
		events.cloak_broken.connect(func(reason: String):
			_post(Triggers.Kind.ON_CLOAK_BREAK, reason, Triggers.DISCRETE_PROC, ctx.player.ball_position()))
	events.landed.connect(func(impact: float):
		_post(Triggers.Kind.ON_LAND, "land", Triggers.DISCRETE_PROC, ctx.player.ball_position(), null, impact))
	events.player_hit.connect(func(amount: float, source: String):
		_post(Triggers.Kind.ON_DAMAGE_TAKEN, source, Triggers.DISCRETE_PROC, ctx.player.ball_position(), null, amount))
	if events.has_signal("enemy_pinned"):
		events.enemy_pinned.connect(func(victim: Node3D, damage: float):
			effects.note_pin(victim, damage)
			lanes.note_pin(victim))
	if events.has_signal("enemy_rebounded"):
		events.enemy_rebounded.connect(func(enemy: Node3D, _speed: float): lanes.note_rebound(enemy))


func _on_struck_trigger(enemy: Node3D, kind: String, force: float) -> void:
	if _own_strikes > 0:
		return
	_last_strike_kind = kind
	var at: Vector3 = enemy.global_position if is_instance_valid(enemy) else ctx.player.ball_position()
	_post(Triggers.Kind.ON_HIT, kind, Triggers.strike_proc(kind), at, enemy, force)


func _on_smash_trigger() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _last_smash_frame:
		return
	_last_smash_frame = frame
	_post(Triggers.Kind.ON_SMASH, "smash", Triggers.DISCRETE_PROC, ctx.player.ball_position(), null, 1.0)


static func _argc(events: Object, signal_name: String) -> int:
	for info in events.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


func _step_loot(delta: float) -> void:
	var tier: int = ctx.player.speed_tier()
	if tier > _speed_tier:
		_post(Triggers.Kind.ON_SPEED_TIER_UP, "speed", Triggers.DISCRETE_PROC, ctx.player.ball_position(), null, tier)
	_speed_tier = tier
	effects.tick(delta, bus)
	bus.run(effects.resolve, loot_rng)


func recompute() -> void:
	_sync_scrap_flags()
	sheet = stat_cache.sync(ctx.run.parts)
	_fold_shot_masks()
	_fold_panels()
	effects.refresh(ctx.run.parts)
	var mass_hp: float = effects.mass_health(ctx.run.mass)
	if ctx.run.armor_mode:
		mass_hp = maxf(mass_hp, _mass_hp)
	_mass_hp = mass_hp
	sheet.max_hp_bonus += _mass_hp
	sheet.apply(ctx.tuning, ctx.run)
	_apply_shell()
	effects.apply_abilities(ctx.player)
	scrap.magnet_scale = sheet.magnet * Companion.vacuum_scale(ctx.run.companion)
	field.shatter_scale = sheet.dial("shatter_damage")
	_synergies.sync_live(self)
	_redraw()


func _fold_panels() -> void:
	panel_overflow = 0
	panel_effective = {}
	if ctx.run.panels.is_empty():
		return
	var weapon_id: String = ctx.run.class_def.weapon_id if ctx.run.class_def != null else ""
	var rate := Panels.weapon_rate(weapon_id, ctx.run.parts)
	var room := Panels.louvre_room(rate, sheet.mod("weapon_rate")) if rate > 0.0 else -1
	var eff: Dictionary = Panels.effective(ctx.run.panel_counts(), _class_id(), room)
	panel_overflow = int(eff["converted"])
	panel_effective = eff["counts"]
	Panels.fold(sheet, eff["counts"])


func shell_fitted() -> bool:
	return _hotwire.shell_fitted(self)


func shell_held() -> bool:
	return _hotwire.shell_held(self)


func shell_rest_factor() -> float:
	return _hotwire.shell_rest_factor(self)


func shell_air_factor() -> float:
	return _hotwire.shell_air_factor(self)


func _second_wind_r6() -> bool:
	return _hotwire.second_wind_r6(self)


func _smoke_trail_k5() -> bool:
	return _hotwire.smoke_trail_k5(self)


func _face_runner_s4() -> bool:
	return _hotwire.face_runner_s4(self)


func _open_shell_window() -> void:
	_hotwire.open_shell_window(self)


func emit_shell_air_changed(factor: float, rose: bool) -> void:
	shell_air_changed.emit(factor, rose)


func shell_scrap_per_hp() -> float:
	return _hotwire.shell_scrap_per_hp(self)


func _on_warden_broken_hotwire(stage: int) -> void:
	_hotwire.on_warden_broken(self, stage)


func _hotwire_save() -> void:
	_hotwire.save(self)


func _hotwire_restore(retry := false) -> void:
	_hotwire.restore(self, retry)


func hotwire_pending() -> Dictionary:
	return _hotwire.pending()


func _hotwire_gate_ids() -> Array:
	return _hotwire.gate_ids(self)


func tread_fitted() -> bool:
	return _hotwire.tread_fitted(self)


func _on_tread_struck(enemy: Node3D, kind: String, force: float) -> void:
	_hotwire.on_tread_struck(self, enemy, kind, force)


func _apply_shell() -> void:
	_hotwire.apply_shell(self)


func in_own_strikes() -> bool:
	return _own_strikes > 0


func begin_own_strikes() -> void:
	_own_strikes += 1


func end_own_strikes() -> void:
	_own_strikes -= 1


func heading_dir() -> Vector3:
	return _heading()


func strike_enemy(enemy: Node3D, kind: String, force: float) -> void:
	_strike(enemy, kind, force)


func frost_ring(at: Vector3) -> void:
	_frost_ring(at)


func codex_ref():
	return _codex()


func ensure_declared() -> void:
	if not _declared:
		_declare()


func roll_cobalt_boss_picks(rng: RandomNumberGenerator, class_id: String, held: Array, count := 2) -> Array:
	return RewardGates.roll_cobalt_boss_picks(rng, class_id, held, count)


func open_cobalt_boss_gates(parent: Node, ground_query, picks: Array, at: Vector3, heading: Vector3, held: Array, on_chosen: Callable) -> Node3D:
	var cobalt_gates := RewardGates.new()
	cobalt_gates.name = "BrindleCobaltGates"
	parent.add_child(cobalt_gates)
	cobalt_gates.setup(ground_query)
	cobalt_gates.chosen.connect(on_chosen)
	cobalt_gates.open(picks, at, heading, held)
	return cobalt_gates


func _redraw() -> void:
	accretion.show_build(ctx.run.mass, ctx.run.parts, sheet.synergies, ctx.run.heft_class())
	panel_shell.show_panels(ctx.run.panels, ctx.run.run_seed)


func _codex():
	return ctx.codex


func _declare() -> void:
	_declared = true
	var codex = _codex()
	if codex == null:
		return
	for card in codex_declarations():
		codex.declare({"id": card["id"], "category": card["category"], "name": card["name"],
			"hint": card["hint"], "clue": String(card.get("clue", "")), "text": card["text"]})


func _exit_tree() -> void:
	if Synergies.table == ctx.stages:
		Synergies.set_table(null)


func _fire(synergy_id: String, body: Node3D, at: Vector3) -> void:
	_synergies.fire(self, synergy_id, body, at)


func _note_found(key: String, text: String) -> void:
	_synergies.note_found(self, key, text)


func _on_element_resolved(result: Dictionary) -> void:
	ctx.events.element_resolved.emit(result["element"], result["material"], result["behaviour"], result["at"])
	var key: String = result.get("key", "")
	if key == "arc:ice" and result.get("source", "") == "slam" and has_transformer("thermal_shock") and result.get("shattered", 0) > 0:
		_fire("thermal_shock", null, ctx.player.ball_position())
	var row := Elements.ROWS.get(key, {}) as Dictionary
	if row.has("found"):
		_note_found("element:" + key, row["found"])


func _on_fused(result: Dictionary) -> void:
	var row: Dictionary = Elements.all_fusions().get(String(result["key"]), {})
	if not row.is_empty():
		_note_found("fusion:" + String(result["key"]), Elements.card_text(row))


func _class_id() -> String:
	return ctx.run.class_id()


func set_element(trick_id: String) -> String:
	return Synergies.element(trick_id)


func _on_part_gained(part_id: String, source: String) -> void:
	recompute()
	for trick_id in _synergies.sets_fresh.duplicate():
		var row: Dictionary = Synergies.ROWS[trick_id]
		set_completed.emit(trick_id, row["name"], row["text"], row["color"])
	_grant_evolutions()
	var d: Resource = Parts.def(part_id)
	if d != null and d.effect.get("do", "") == "ballast":
		ctx.run.add_scrap(int(d.effect.get("mass", 0)), ctx.player.ball_position())
	if source not in ["duplicator_spool", "alt_loadout", "evolution"] and not Relics.is_relic(part_id) \
			and not Parts.maxed(part_id, ctx.run.parts):
		Consumables.try_clone_pickup(ctx, ctx.spawner, "part", part_id, ctx.player.ball_position())


func _on_core_gained(source: String, at: Vector3, _total: int) -> void:
	if source != "duplicator_spool":
		Consumables.try_clone_pickup(ctx, ctx.spawner, "core", 1, at)


func _on_stage_cleared_contracts(_stage: int) -> void:
	if ctx == null or ctx.run == null or clock == null:
		return
	var at: Vector3 = ctx.player.ball_position() if ctx.player != null else Vector3.ZERO
	TradePockets.settle_overtime_contract(ctx.run, float(clock.stage_seconds), at)


func note_offered(part_id: String) -> void:
	if part_id != "":
		_offered[part_id] = int(_offered.get(part_id, 0)) + 1


func _on_world_fact_overrides(kind: String, _at: Vector3) -> void:
	if kind != "wall_crumbled" or scrapless() or ctx == null or ctx.run == null:
		return
	if not ctx.run.override_on("drops_from_wrecks") or loot_rng.randf() >= 0.20:
		return
	var picks: Array = Parts.roll(loot_rng, ["common", "rare"], _class_id(), ctx.run.parts, 1)
	if not picks.is_empty():
		ctx.run.add_part(picks[0], "wreck_drop")


func _on_scrap_collected(_amount: int, _at: Vector3, _total: int) -> void:
	var mass_hp: float = effects.mass_health(ctx.run.mass)
	if ctx.run.armor_mode:
		mass_hp = maxf(mass_hp, _mass_hp)
	if mass_hp != _mass_hp:
		sheet.max_hp_bonus += mass_hp - _mass_hp
		_mass_hp = mass_hp
		ctx.run.set_max_hp(HullMark.ceiling(ctx.run, ctx.run.base_max_hp() + sheet.max_hp_bonus))
	_redraw()


func _on_run_started(_class_id_value: String) -> void:
	_relic_sync.reset()
	_synergies.reset_run()
	_mass_hp = 0.0
	_hotwire.reset_run()
	_refresh_seams()
	bus.clear()
	effects.reset_run()
	clock.begin_run(_next_modifiers)
	if ctx.codex != null:
		clock.load_best(ctx.codex.storage_dir.path_join("runs.ndjson"), Engine.physics_ticks_per_second)
	ctx.run.set_meta("run_tags", clock.tags())
	_sync_scrap_flags()
	_apply_route()
	_grant_companion_stub()
	shop.reset_run()
	lanes.reset()
	dropper.reset()
	kill_log.clear()
	_no_cells_logged.clear()
	recompute()


func _on_stage_entered(stage: int, retry: bool) -> void:
	sync_relics()
	_hotwire_restore(retry)
	if retry:
		_synergies.clear_fired()
		shop.inside = false
		shop.rewind_stage()
	gates.close()
	field.clear()
	_trail = 0.0
	_slams.clear()
	_shots.clear()
	_synergies.reset_stage()
	bus.clear()
	effects.reset_stage()
	clock.enter_stage(stage)
	lanes.reset()
	_offered = {}
	_vaults_paid = 0
	_overtimes_paid = 0
	loot_rng.seed = hash([LOOT_SEED, ctx.flow.run_key(), stage, "loot"])
	panel_rng.seed = hash([ctx.run.run_seed, stage, "panels"])
	scrap_rng.seed = hash([ctx.flow.run_key(), stage, "scrap"])
	chain_rng.seed = hash([ctx.flow.run_key(), stage, "chain"])
	scrap.clear_caches()
	_caches_pending = true
	_caches_wait = 0
	_cache_spots = []
	if retry:
		dropper.dry = _stage_dry
	else:
		_stage_dry = dropper.dry
	_speed_tier = ctx.player.speed_tier()
	scrap.lay_out(ctx.terrain, ctx.terrain.scrap_lines(stage), ctx.flow.stage_def()["scrap_density"], ctx.rng)
	scrap.lay_trail(ctx.terrain, ctx.terrain.scrap_trail(stage))
	fabricators.lay_out(ctx.terrain, stage, _class_id(), ctx.rng, ctx.run.parts)
	recompute()


func _on_stage_content_cleared(reason: String) -> void:
	if reason == "arena_retry":
		_synergies.clear_fired()
	sync_relics()
	scrap.clear()
	fabricators.clear()
	gates.close()
	field.clear()
	_trail = 0.0
	recompute()


func _on_enemy_killed(kind: String, at: Vector3, scrap_value: int) -> void:
	_synergies.on_enemy_killed(self, at)
	if not ctx.flow.in_stage():
		return
	var stage_pay := float(ctx.flow.stage_def().get("kill_scrap", 1.0))
	var amount := int(round(scrap_value * sheet.kill_scrap * stage_pay)) if not scrapless() else 0
	if kind == "warden":
		scrap.drop_line(at, _heading(), WARDEN_LINE, amount, scrap_rng)
		scrap.drop_cogs_line(at, _heading(), WARDEN_LINE, amount)
	else:
		scrap.drop(at, amount, scrap_rng)
		scrap.drop_cogs(at, amount)
	_drop_panel(kind, at)
	if kind not in ["warden", "vault"] and not scrapless() and ctx.run.override_on("drops_from_wrecks"):
		if loot_rng.randf() < 0.15:
			var wreck_picks: Array = Parts.roll(loot_rng, ["common", "rare"], _class_id(), ctx.run.parts, 1)
			if not wreck_picks.is_empty():
				ctx.run.add_part(wreck_picks[0], "wreck_drop")
	Companion.on_salvage_kill(ctx.run)
	if kind == "vault":
		_vaults_paid += 1
		var stage: int = ctx.flow.stage()
		var vault_rarities := Parts.source_rarities("vault", stage)
		var vault_rng := _offer_rng("vault_%d" % _vaults_paid)
		var tree = ctx.player.tree if ctx.player != null else null
		var picks: Array = Parts.roll_high_impact(vault_rng, vault_rarities, _class_id(), ctx.run.parts, 1, [], _offered, stage, stage >= Parts.WORLD_ESCALATION_STAGE_W2, tree)
		if not picks.is_empty() and not scrapless():
			ctx.run.add_part(picks[0], "vault")
		ctx.run.add_core("vault", at)
		var active := active_offer_for_channel("vault", vault_rarities, vault_rng, stage >= Parts.WORLD_ESCALATION_STAGE_W2)
		if active != "" and not scrapless():
			active_rack().take(active, ctx.player.ball_position())


func _drop_panel(kind: String, at: Vector3) -> void:
	if kind in Panels.NO_DROP_KINDS or scrapless():
		return
	var tags: Dictionary = ctx.run.kill_tags
	if bool(tags.get("yard", false)):
		if kill_log.size() < KILL_LOG_CAP:
			kill_log.append([ctx.flow.stage(), kind, false, 1.0, false, false, true])
		return
	var jackpot := bool(tags.get("jackpot", false))
	var elite := bool(tags.get("elite", false))
	var rib := _rib_mult(at)
	dropper.world = ctx.stages.world_of(ctx.flow.stage()) if ctx.stages != null else 1
	var dropped: bool = dropper.roll(panel_rng, elite, rib, jackpot)
	if kill_log.size() < KILL_LOG_CAP:
		kill_log.append([ctx.flow.stage(), kind, elite, rib, jackpot, dropped])
	if dropped:
		scrap.drop_panel(at, Panels.draw(panel_rng, _class_id()), jackpot)


func yard_cleared(at: Vector3) -> void:
	if scrapless():
		return
	if kill_log.size() < KILL_LOG_CAP:
		kill_log.append([ctx.flow.stage(), "yard_clear", false, 1.0, false, true, false])
	scrap.drop_panel(at, Panels.draw(panel_rng, _class_id()))
	Companion.on_yard_cleared(ctx.run, ctx.spawner, at)


func overtime_paid(at: Vector3, rings: int) -> void:
	if scrapless() or rings <= 0:
		return
	_overtimes_paid += 1
	var stage: int = ctx.flow.stage()
	var rng := _offer_rng("overtime_%d" % _overtimes_paid)
	var tree = ctx.player.tree if ctx.player != null else null
	scrap.drop_panel(at, Panels.draw(rng, _class_id()))
	var rares := (1 if rings >= 2 else 0) + (1 if rings >= 3 else 0)
	for i in rares:
		var is_top := rings >= 3 and i == rares - 1
		var table: Array = ["rare", "relic"] if is_top else ["rare"]
		var picks: Array = Parts.roll_high_impact(rng, table, _class_id(), ctx.run.parts, 1, [], _offered, stage, is_top, tree)
		if not picks.is_empty():
			ctx.run.add_part(picks[0], "overtime")
	if rings >= 3:
		ctx.run.add_core("overtime", at)
		var active := active_offer_for_channel("vault", ["rare", "relic"], rng, true)
		if active != "":
			active_rack().take(active, ctx.player.ball_position())


func _rib_mult(at: Vector3) -> float:
	var world = ctx.root.get_node_or_null("World")
	var director = world.get("director") if world != null else null
	var cell: int = director.off_spine(at) if director != null and director.has_method("off_spine") else -1
	if cell < 0:
		var stage: int = ctx.flow.stage()
		if not _no_cells_logged.has(stage):
			_no_cells_logged[stage] = true
			print("panels: stage %d has no cell data, rib drops pay 1.0" % stage)
		return 1.0
	return float(Panels.DROP["rib"]) if cell == 1 else 1.0


func _place_rib_caches() -> void:
	if scrapless():
		_caches_pending = false
		return
	var world = ctx.root.get_node_or_null("World")
	var director = world.get("director") if world != null else null
	if director == null or not director.has_method("rib_cache_spots"):
		_caches_pending = false
		return
	var stage: int = ctx.flow.stage()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.run.run_seed, stage, "rib_caches"])
	var spot_seed := rng.randi()
	if _cache_spots.is_empty():
		_cache_spots = director.rib_cache_spots(Panels.RIB_CACHES, spot_seed)
	var spots: Array = []
	for at in _cache_spots:
		var ground = _cache_ground(at)
		if ground == null and _caches_wait < CACHE_WAIT_TICKS:
			_caches_wait += 1
			return
		spots.append(at if ground == null else ground)
	_caches_pending = false
	for at in spots:
		scrap.drop_panel(at, Panels.draw(rng, _class_id()), false, true)


const CACHE_RAY_UP := 2.0
const CACHE_RAY_DOWN := 1.0
const CACHE_WAIT_TICKS := 30
const CACHE_STAND_NORMAL := 0.5
const CACHE_SLIDE_STEP := 3.0
const CACHE_SLIDE_M := 12.0
const CACHE_SLIDE_DOWN := 10.0
const CACHE_SLIDE_BEARINGS := 8


func _cache_ground(at: Vector3):
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * CACHE_RAY_UP, at + Vector3.DOWN * CACHE_RAY_DOWN, 1))
	if hit.is_empty():
		return null
	if hit["normal"].y >= CACHE_STAND_NORMAL:
		return hit["position"]
	var r := CACHE_SLIDE_STEP
	while r <= CACHE_SLIDE_M:
		var best := {}
		for k in CACHE_SLIDE_BEARINGS:
			var a := TAU * k / CACHE_SLIDE_BEARINGS
			var side := at + Vector3(cos(a), 0.0, sin(a)) * r
			var query := PhysicsRayQueryParameters3D.create(side + Vector3.UP * CACHE_RAY_UP, side + Vector3.DOWN * CACHE_SLIDE_DOWN, 1)
			query.hit_back_faces = false
			var low := space.intersect_ray(query)
			if not low.is_empty() and low["normal"].y >= CACHE_STAND_NORMAL and (best.is_empty() or low["normal"].y > best["normal"].y):
				best = low
		if not best.is_empty():
			return best["position"]
		r += CACHE_SLIDE_STEP
	return hit["position"]


func grant_panel(panel_id: String) -> void:
	ctx.run.add_panel(panel_id, ctx.player.ball_position())


func active_rack():
	var rack = ctx.spawner.get("actives") if ctx.spawner != null else null
	return rack if rack != null and rack.enabled() else null


func active_offer(source: String, rarities: Array, rng: RandomNumberGenerator) -> String:
	var rack = active_rack()
	if rack == null:
		return ""
	return ActiveOffers.roll(rng, source, rack.rows(), rarities, rack.held())


func active_offer_for_channel(source: String, rarities: Array, rng: RandomNumberGenerator, boosted := false) -> String:
	var rack = active_rack()
	if rack == null:
		return ""
	var rows: Dictionary = rack.rows()
	var ids := ActiveOffers.pool(rows, rarities, rack.held())
	if ids.is_empty():
		return ""
	var base_share := float(ActiveOffers.SHARE.get(source, 0.0))
	var spell_lean := Parts.dominant_archetype(ctx.run.parts) == "spell_cast"
	var counted := maker_counts()
	var set_ids: Array = []
	for aid in ids:
		var m := String(rows[aid].get("maker", ""))
		if m != "" and MakerSets.SETS.has(m) and int(counted.get(m, 0)) == int(MakerSets.SETS[m]["pieces"]) - 1:
			set_ids.append(aid)
	var share := base_share
	if boosted:
		share = minf(0.85, share + 0.2)
	if spell_lean or not set_ids.is_empty():
		share = minf(0.85, share + 0.15)
	if rng.randf() >= share:
		return ""
	var pool := set_ids if not set_ids.is_empty() else ids
	return ActiveOffers.offer_id(String(pool[rng.randi_range(0, pool.size() - 1)]))


func _active_row(id: String) -> Dictionary:
	var rack = active_rack()
	return rack.row_of(id) if rack != null else {}


func _on_flow_changed(state: String) -> void:
	if state != "gates" or gates.is_open():
		return
	var stage: int = ctx.flow.stage()
	var rarities: Array = called_shot.gate_rarities()
	var call_met: bool = called_shot.high_impact_met()
	var gate_rng := _offer_rng("gates")
	var tree = ctx.player.tree if ctx.player != null else null
	var picks: Array
	if call_met:
		picks = Parts.roll_high_impact(gate_rng, rarities, _class_id(), ctx.run.parts, GATE_CHOICES, [], _offered, stage, "relic" in rarities, tree)
	elif stage >= Parts.WORLD_ESCALATION_STAGE_W2:
		picks = Parts.roll_for_stage(gate_rng, rarities, _class_id(), ctx.run.parts, GATE_CHOICES, stage, [], _offered, false)
	else:
		picks = Parts.roll_gate(gate_rng, rarities, _class_id(), ctx.run.parts, GATE_CHOICES, stage, _offered)
	picks = Parts.floor_gate(gate_rng, picks, _class_id(), ctx.run.parts, _offered, GATE_CHOICES)
	var quick: Array = []
	if clock.quick_break():
		quick = Parts.roll_for_stage(_offer_rng("quick_break"), rarities, _class_id(), ctx.run.parts, 1, stage, picks, _offered, stage >= Parts.WORLD_ESCALATION_STAGE_W2) \
			if stage >= Parts.WORLD_ESCALATION_STAGE_W2 \
			else Parts.roll(_offer_rng("quick_break"), rarities, _class_id(), ctx.run.parts, 1, picks, _offered)
		picks += quick
	var stake_rolls := StakeDevices.warden_gate_bonus_rolls(ctx.run)
	if stake_rolls > 0:
		var stake_rarities: Array = ["rare", "relic"] if stake_rolls >= 2 or stage >= Parts.WORLD_ESCALATION_STAGE_W2 else ["rare"]
		picks += Parts.roll_high_impact(_offer_rng("challenge_stake"), stake_rarities, _class_id(), ctx.run.parts, stake_rolls, picks, _offered, stage, stake_rolls >= 2, tree)
	if ctx.run.override_on("warden_extra_cobalt"):
		picks += Parts.roll_high_impact(_offer_rng("override_cobalt"), ["rare"], _class_id(), ctx.run.parts, 1, picks, _offered, stage, false, tree)
	for part_id in picks:
		_offered[part_id] = _offered.get(part_id, 0) + 1
	picks += _hotwire_gate_ids()
	var active := active_offer_for_channel("gate", rarities, gate_rng, call_met or stake_rolls > 0) \
		if (ctx.run.bonus_cores > 0 or call_met or stake_rolls > 0) else ""
	if active != "":
		picks.append(active)
	var offers: Array = gates.open(picks, ctx.player.ball_position(), _heading(), ctx.run.parts)
	ctx.events.reward_offered.emit(offers)
	for offer in offers:
		if offer["part_id"] in quick:
			ctx.events.quick_break.emit(stage, clock.fight_seconds(), offer["at"])


func _offer_rng(source: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.rng.seed, ctx.flow.run_key(), ctx.flow.stage(), source])
	return rng


func _on_gate_chosen(part_id: String) -> void:
	if ActiveOffers.is_offer(part_id):
		var rack = active_rack()
		if rack != null and not scrapless():
			rack.take(part_id, ctx.player.ball_position())
	elif Consumables.is_offer(part_id):
		if not scrapless():
			if part_id == Consumables.BELT_OFFER_ID:
				ctx.run.expand_consumable_belt()
			else:
				var cid := Consumables.offer_consumable_id(part_id)
				if cid != "" and not ctx.run.add_consumable(cid) and ctx.spawner != null and ctx.spawner.has_method("drop_consumable"):
					ctx.spawner.drop_consumable(cid, ctx.player.ball_position())
	elif not scrapless():
		ctx.run.add_part(part_id, "gate")
	ctx.events.reward_chosen.emit(part_id)


func _on_milestone_won(event_id: String) -> void:
	if not scrapless():
		ctx.run.add_part(Parts.milestone_for(event_id, ctx.run.parts), "milestone")


func _on_scrap_lost(_amount: int, at: Vector3, _total: int, _cause: String) -> void:
	var want := Accretion.chunks_for(ctx.run.mass)
	if accretion.chunk_count() > want:
		accretion.fling(accretion.chunk_count() - want, at, ctx.root)
	_redraw()


func _on_dashed(_direction: Vector3) -> void:
	if not sheet.elements_for("dash").is_empty():
		_trail = FROST_TRAIL
		_trail_ticks = 0


func _on_line_state(id: String, _target: Node3D, at: Vector3, cause: String) -> void:
	if id != "chain_end" or cause != "paid" or scrapless() or not ctx.flow.in_stage():
		return
	var stage_pay := float(ctx.flow.stage_def().get("kill_scrap", 1.0))
	var amount := int(round(ctx.player.chain.last_burst() * sheet.kill_scrap * stage_pay))
	if amount > 0:
		scrap.drop(at, amount, chain_rng)


func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	_slams.append({"at": at, "strength": clampf(strength, 0.3, 1.6)})


func _on_landed(impact: float) -> void:
	_synergies.on_landed(self, impact)


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	_synergies.on_enemy_struck(self, enemy, kind)


func _on_shot_fired(_weapon_id: String, _from: Vector3, to: Vector3) -> void:
	if not sheet.elements_for("shot").is_empty():
		_shots.append(to)
	_synergies.on_shot_fired(self)


func _heading() -> Vector3:
	var flat: Vector3 = ctx.player.planar_velocity()
	if flat.length() > 3.0:
		return flat.normalized()
	return ctx.heading()


func _sync_scrap_flags() -> void:
	if ctx == null or ctx.tuning == null or ctx.run == null:
		return
	ctx.run.armor_mode = ctx.tuning.armor()
	ctx.run.wear_on = ctx.tuning.wear_on()


func _apply_route() -> void:
	if ctx.tuning == null:
		return
	var route_seed := int(ctx.tuning.base("route_seed"))
	if route_seed > 0:
		ctx.rng.seed = route_seed
		seed(route_seed)  # lint: route seed
	var start := float(ctx.tuning.base("start_mass"))
	if start > 0.0:
		ctx.run.grant_start_mass(start)


func _grant_companion_stub() -> void:
	if ctx.tuning == null or ctx.tuning.option("companion_stub") != "on" or not ctx.run.companion.is_empty():
		return
	var model := Companion.new()
	for id in ["primer_coil", "ram_prow", "escape_vent"]:
		model.acquire(id)
	ctx.run.companion = model.to_dict()


func _on_armor_hit(_removed: float, spill: int, _source: String) -> void:
	if scrapless():
		ctx.run.metrics["destroyed"] += spill
		_redraw()
		return
	if not ctx.flow.in_stage():
		var boss = ctx.boss if "boss" in ctx else null
		if boss == null or not boss.has_method("take_spill") or not boss.take_spill(ctx.player.ball_position(), _heading(), spill):
			ctx.run.metrics["destroyed"] += spill
			ctx.run.metrics["arena_destroyed"] += spill
		_redraw()
		return
	scrap.drop_recovery(ctx.terrain, ctx.player.ball_position(), _heading(), spill, RunState.SPILL_CLUSTERS, scrap_rng)
	_redraw()


func _step_armor(ball: Vector3, delta: float) -> void:
	var run = ctx.run
	for value in scrap.recovered_values:
		run.recover_mass(value)
	for value in scrap.expired_values:
		run.note_spill_expired(value)
	run.mitigation = effects.damage_reduction
	run.brace_hook = effects.brace_share_for
	run.deflect_hook = effects.deflect_for
	run.ward_hook = effects.ward_floor_for
	var grounded: bool = ctx.player.state.grounded and ctx.flow.state in [ctx.flow.STAGE, ctx.flow.BEACON, ctx.flow.GATES]
	var planar: Vector3 = ctx.player.planar_velocity()
	var wear_delta := delta * HotwireRules.wear_scale(tread_fitted())
	run.wear_step(wear_delta, planar.length(), ctx.tuning.f("cruise"), grounded and not get_tree().paused and not shop.clock_paused())
	if scrap.recovery_count() > 0 and planar.length() > 1.0 and planar.dot(ctx.terrain.entry_heading(run.stage)) < 0.0:
		run.metrics["reverse_seconds"] += delta


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.flow.in_play():
		return
	if not _declared:
		_declare()
	var ball: Vector3 = ctx.player.ball_position()
	var speed: float = ctx.player.planar_velocity().length()
	scrap.heft = ctx.run.heft()
	_hotwire.step(self, delta)
	makers.step(delta)
	_synergies.refill_budgets(delta)
	scrap.magnet_scale = sheet.magnet * effects.magnet_boost()
	clock.paused = shop.clock_paused()
	clock.cursed = ctx.run.cursed()
	clock.advance(delta, ctx.run.run_time, ctx.flow.in_stage())
	_own_strikes += 1
	if ctx.flow.in_stage():
		if _caches_pending:
			_place_rib_caches()
		if not scrapless():
			for at in scrap.step(ball, speed, delta):
				ctx.run.add_scrap(1, at)
				_post(Triggers.Kind.ON_PICKUP, "scrap", Triggers.DISCRETE_PROC, at)
				if has_transformer("lightning_rod"):
					_lightning_rod(ball)
			for value in scrap.cog_values:
				ctx.run.add_cogs(value)
				ctx.events.cogs_collected.emit(value, ctx.run.cogs)
			for take in scrap.panel_takes:
				ctx.run.add_panel(String(take["id"]), take["at"], bool(take["jackpot"]))
			_step_fabricators(ball, delta)
		if ctx.run.armor_mode:
			_step_armor(ball, delta)
		if gates.step(ball, _heading()):
			ctx.events.reward_offered.emit(gates.offers)
	_step_elements(ball, delta)
	_step_synergies(ball, delta)
	field.step(delta)
	_step_loot(delta)
	_own_strikes -= 1
	for score in lanes.step(delta):
		if ctx.codex != null:
			ctx.codex.mark_discovered(score[0], score[1], PARTICIPANTS)


func _step_fabricators(ball: Vector3, delta: float) -> void:
	for fab in fabricators.step(ball, delta, ctx.run.cogs, ctx.run.parts):
		ctx.events.world_fact.emit("fabricator_used", fab["at"])
		var part_id: String = fab["part_id"]
		if ctx.run.spend_cogs(Fabricators.hoop_price(part_id, Parts.priced_count(ctx.run.parts))):
			fabricators.sold(fab)
			ctx.run.add_part(part_id, "fabricator")


func _step_elements(ball: Vector3, delta: float) -> void:
	if _trail > 0.0:
		_trail -= delta
		_trail_ticks += 1
		for element in sheet.elements_for("dash"):
			field.apply(element, ball, "dash")
		if _trail_ticks % PUFF_EVERY == 0:
			field.puff(ball)
	for element in sheet.elements_for("roll_on_water"):
		field.apply(element, ball, "roll")
	for at in _shots:
		for element in sheet.elements_for("shot"):
			field.apply(element, at, "shot")
	_shots.clear()
	for slam in _slams:
		_resolve_slam(slam["at"], slam["strength"])
	_slams.clear()


func _resolve_slam(at: Vector3, strength: float) -> void:
	var elements: Array = sheet.elements_for("slam")
	for element in elements:
		if element == "arc":
			_arc_burst(at, strength)
		elif element != "frost":
			field.apply(element, at, "slam")
	field.apply("kinetic", at, "slam")
	if "frost" in elements:
		_frost_ring(at)


func _arc_burst(at: Vector3, strength: float) -> void:
	var reach := ARC_RADIUS * (0.6 + 0.4 * strength)
	field.flash_ring(at + Vector3.DOWN * 0.8, reach, Palette.ARC)
	var damage: float = ARC_DAMAGE * strength * sheet.mod("weapon_damage")
	for enemy in _enemies_near(at, reach, 99):
		_strike(enemy, "arc", damage)
	field.apply("arc", at, "slam")


func _frost_ring(at: Vector3) -> void:
	field.apply("frost", at, "slam")
	for i in 6:
		var angle := TAU * float(i) / 6.0
		field.apply("frost", at + Vector3(cos(angle), 0.0, sin(angle)) * REFREEZE_RING, "slam")


func _grant_evolutions() -> void:
	for part_id in Synergies.evolutions_ready(ctx.run.parts):
		ctx.events.evolution_fired.emit(part_id)
		ctx.run.add_part(part_id, "evolution")


func synergy_read() -> Array:
	return sheet.synergies.map(func(key): return {"id": key, "name": Synergies.ROWS[key]["name"], "maker": Synergies.ROWS[key]["maker"]})


func _step_synergies(ball: Vector3, delta: float) -> void:
	_synergies.step(self, ball, delta)


func _lightning_rod(ball: Vector3) -> void:
	_synergies.lightning_rod(self, ball)


func _enemies_near(at: Vector3, radius: float, count: int) -> Array[Node3D]:
	var near: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node3D
		if enemy != null and is_instance_valid(enemy) and enemy.global_position.distance_to(at) <= radius:
			near.append(enemy)
	near.sort_custom(func(a: Node3D, b: Node3D): return a.global_position.distance_to(at) < b.global_position.distance_to(at))
	if near.size() > count:
		near.resize(count)
	return near


func _strike(enemy: Node3D, kind: String, force: float) -> void:
	if ctx.spawner != null and is_instance_valid(enemy):
		ctx.spawner.strike(enemy, kind, force)


func _on_relic_gained(_part_id: String, _source: String) -> void:
	sync_relics()


func sync_relics() -> void:
	_relic_sync.sync(self)
