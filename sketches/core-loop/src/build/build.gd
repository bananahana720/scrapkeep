extends Node

const Companion := preload("res://src/core/companion.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const CalledShot := preload("res://src/build/called_shot.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const HullMark := preload("res://src/world/hull_mark.gd")
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

# Writer B's module: build and growth. Scrap magnetizes to the ball and sticks to it;
# drive-through fabricators turn scrap into parts on the roll; the reward gates after
# the beacon offer two parts you roll through; vaults and won events award parts. Every
# held part folds into one derived sheet (build_sheet.gd) that sets the tuning mods,
# the pattern levels combat reads, the element triggers that feed the element x
# material table (elements.gd, resolved by element_field.gd), and the awake maker tricks.
#
# Maker tricks (synergies.gd) wake on two parts of one maker. This module runs the behaviour
# of each, tells the codex (ctx.codex) the first time each fires in a run, and tells it the
# first time an unnamed interaction fires. The codex publishes synergy_discovered
# and interaction_found and grants the discovery burst; build never emits those two.
#
# Other modules reach this node as ctx.build (ctx.build_module() also finds it). Its
# public API is the "Build API" block; SEAMS.md lists the ids.

const GATE_CHOICES := 2
# The stock plating (--hotwire-shell=on, the default): the armour costs this much scrap per absorbed
# HP (RunState.SCRAP_PER_HP with the flag off) and airborne steering takes this factor. The flag
# shipped on, so every played build, band and pin since was fit on these two numbers; they are the
# game's baseline, whatever the run holds. Read through shell_scrap_per_hp() and
# shell_air_factor() only, so an inversion (S4, K5, R6) changes one return value later.
const SHELL_SCRAP_PER_HP := 5.0
const SHELL_AIR_FACTOR := 0.75
# Hot-wired H1, Riveted Shell, a rare part a Warden's gate puts up (Parts.HOTWIRED). Until 9 Nov
# the baseline above was all "the shell" did, so holding it changed nothing. Held, it now pays what its card says, measured from the baseline the player has been rolling
# on: the armour goes RIVETED_ARMOUR times as far per scrap again, and airborne steering takes
# RIVETED_AIR_FACTOR again. An inversion still lifts the factor to its own value, so the tree's
# three shell nodes are worth more to a pilot who fits it.
const RIVETED_SHELL := "riveted_shell"
const RIVETED_ARMOUR := HotwireRules.RIVETED_ARMOUR
const RIVETED_AIR_FACTOR := HotwireRules.RIVETED_AIR_FACTOR
# S4, Face Runner (--world-one-builds=on, node taken, shell fitted): for this many sim seconds
# after a valid vault the shell's air factor is SHELL_AIR_FACTOR_VAULT instead.
const SHELL_VAULT_WINDOW := 2.0
const SHELL_AIR_FACTOR_VAULT := 1.25
# R6 Second Wind (world-one): while sprinting the shell's penalty cancels (factor 1.0).
const SHELL_AIR_FACTOR_SPRINT := 1.0
# K5 Smoke Trail (world-one): while gliding the shell's air factor is SHELL_AIR_FACTOR_VAULT.
# The resolved shell factor moved between two fitted values: `rose` is true above the resting
# factor (an inversion is live), false on the return to it. Presentation reads only this.
signal shell_air_changed(factor: float, rose: bool)
# A gained part woke a maker trick that is told on waking (Synergies.told_on_wake: one that only
# adds an element) for the first time this run. Build-local: presentation raises the banner from
# it, with the trick's name, its one line and its colour. A resume or a retry that restores a held
# trick recomputes without a gain, so it never announces the trick again.
signal set_completed(set_id: String, title: String, text: String, color: Color)
const PARTICIPANTS := ["player"]
# SG15: an offer of a part already held shows the level it would reach, by its current level.
# A part at its top level is never offered, so it has no entry.
const LEVEL_NAMES := ["", "II", "III"]
# The dash leaves frost this long, and drops a visible puff every few ticks of it.
const FROST_TRAIL := 0.7
const PUFF_EVERY := 3
# Arc Coil: the slam's arc reaches this far at full strength and hits this hard,
# before the weapon damage multiplier.
const ARC_RADIUS := 8.0
const ARC_DAMAGE := 18.0
# Thermal Shock and Glacier Hull refreeze a pad this wide.
const REFREEZE_RING := 4.0
# A Warden's scrap is thrown in a line this long along the ball's heading, toward the
# gates that just opened.
const WARDEN_LINE := 20.0
# Named synergy behaviours. Every one is capped per second so a big build stays
# readable (principle 4).
const ROD_REACH := 12.0
const ROD_DAMAGE := 10.0
const ROD_PER_SECOND := 6.0
const TESLA_REACH := 12.0
const TESLA_DAMAGE := 12.0
const TESLA_EVERY := 0.5
const TESLA_TARGETS := 2
const WRECK_RADIUS := 6.0
const SYNERGY_KIND := "synergy"
# Punch per unit of synergy force, the slam row's 1.2 the synergies used to borrow.
const SYNERGY_PUNCH := 1.2
const WRECK_FORCE := 18.0
const SHRAPNEL_RADIUS := 6.0
const SHRAPNEL_FORCE := 14.0
const SHRAPNEL_TARGETS := 3
const SHRAPNEL_PER_SECOND := 6.0
const GLACIER_IMPACT := 9.0
const GLACIER_RADIUS := 5.0
const PINWHEEL_RADIUS := 4.5
const PINWHEEL_FORCE := 10.0
const PINWHEEL_EVERY := 0.3
const PINWHEEL_TIER := 2
const PINWHEEL_TARGETS := 4

var ctx
var scrap
var gates
var fabricators
var field
var accretion
# Grey panels (IL-01): the plates on the ball, the kill-drop roller with its pity, and the
# drop stream, seeded per stage from the run seed so a replay drops the same panels.
var panel_shell
var dropper = Panels.Dropper.new()
var panel_rng := RandomNumberGenerator.new()
# Scrap drops roll on their own stream, so how a fight spills scrap does not move the stage plan.
var scrap_rng := RandomNumberGenerator.new()
# A paid chain's burst rolls on its own stream, so a chain never moves where a kill's scrap lands.
var chain_rng := RandomNumberGenerator.new()
# Vaults paid this stage: each names its own offer stream.
var _vaults_paid := 0
var _overtimes_paid := 0
# Called Shot (called_shot.gd, behind --called-shot): the gate asks it for the pair's rarities.
var called_shot: Node3D
# Louvres the last recompute converted into the pilot's signature stat (Panels.OVERFLOW), and
# the counts it folded after that conversion (what the build read's stat lines say).
var panel_overflow := 0
var panel_effective := {}
# The pity count at this stage's entry: a retry puts it back, so dying never carries a dry
# streak into the retry.
var _stage_dry := 0
# Stages whose missing cell data the rib read has logged.
var _no_cells_logged := {}
# True from stage entry until the stage's rib caches are placed (the director's graph is read
# by the first in-stage tick).
var _caches_pending := false
# Ticks the placement has waited for the stage's colliders (_cache_ground).
var _caches_wait := 0
# The stage's rib cache spots, read from the director's graph on the first try and kept while the
# placement waits for colliders: the read was 15 ms of the flume's entry tick and 5 ms of each wait
# tick on the cloud (scrapkeep#494).
var _cache_spots: Array = []
# Every in-stage kill this run as the drop saw it, [stage, kind, elite, rib, jackpot, dropped],
# for the drop simulation's recorded streams (tools/bot_run.gd --panel-log=1).
var kill_log: Array = []
const KILL_LOG_CAP := 4000
# The told-on-wake tricks this run has woken (a respec that sends one back to sleep keeps it
# here and in the codex's Found list), and the ones the last recompute woke for the first time.
var _woken := {}
var _sets_fresh: Array = []
var sheet
# SI5: the derived sheet between part-list changes; recompute() reads it, so pickup,
# respec, run start and stage entry refold only the categories the changed parts touch.
var stat_cache = StatCache.new()
# v2 W4 loot: the trigger bus, what held items do, and the loot's own seeded stream
# (reseeded each stage entry, so a retry replays the same procs and never draws from
# the run's shared ctx.rng).
var bus
var effects
# The run and difficulty clocks W1 draws, Moss's shop economy, and the bowling score.
var clock
var shop
var lanes
# Maker sets (maker_sets.gd, maker_bonuses.gd): the completed sets' bonuses.
var makers
# The challenge modifiers the class screen chose for the next run (RunClock.MODIFIERS).
var _next_modifiers := {}
# Parts offered at this stage's gates, id to count, so a stage rarely repeats one.
var _offered := {}
var loot_rng := RandomNumberGenerator.new()
const LOOT_SEED := 20260927
# Build's own strikes (synergies, elements, items) never post on_hit: the first guard
# against build feeding itself. Triggers.STRIKE_PROC["synergy"] = 0 is the second.
var _own_strikes := 0
var _last_strike_kind := ""
var _last_smash_frame := -1
var _speed_tier := 0
var _mass_hp := 0.0

var _trail := 0.0
var _trail_ticks := 0
var _slams: Array[Dictionary] = []
var _rams: Array[Vector3] = []
var _kills: Array[Vector3] = []
var _landings: Array[float] = []
var _shots: Array[Vector3] = []
# Token buckets for the capped behaviours; they start full so the first burst of a
# stage is never swallowed.
var _rod_budget := ROD_PER_SECOND
var _shrapnel_budget := SHRAPNEL_PER_SECOND
# Sim seconds left in S4's inverted-shell window; counted down in _physics_process, so a
# paused tree or the bay does not spend it.
var _shell_window := 0.0
# The last resolved factor seen while the shell was fitted; 0.0 while it is not (or before the
# first read of a fit), so fitting, unfitting and the first recompute stay silent.
var _air_seen := 0.0
var _air_rest := 0.0
# The last kit.sprinting Build saw, so a sprint start or end (any path) refreshes the air mod once.
var _sprint_seen := false
# Likewise for kit.gliding (K5).
var _glide_seen := false
# The hot-wired offer and the world whose first Warden spent it.
var _hotwire_id := ""
var _hotwire_state := ""
var _hotwire_spent := false
var _hotwire_world := 1
# Spark Tread: sim seconds left in the recovery, the frame and kind of the last activation
# (one activation per attack), bonus strikes waiting for the physics step, and a count of
# activations this run.
var _tread_recovery := 0.0
var _tread_frame := -1
var _tread_kind := ""
var _tread_hits: Array[Dictionary] = []
var tread_fires := 0
var _tesla_clock := 0.0
var _pinwheel_clock := 0.0
# Pinwheel cuts each enemy at most once per PINWHEEL_EVERY: instance id to time left.
var _pinwheel_cut := {}
# Named synergies live after the last recompute, to spot a new activation.
var _live: Array = []
# Discovered this run (id to true) and found this run (key to description). The codex
# registry, when present, is the lasting record; these keep the run's view.
var _discovered := {}
# Armed once per run; fired once per activation. A retry clears the fired record, so a
# discovery the codex rewound is found again at the next firing.
var _armed := {}
var _fired := {}
var _found := {}
var _declared := false


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Build"
	Synergies.table = ctx.stages
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
	ctx.events.beacon_unsealed.connect(_on_warden_broken_hotwire)
	# Marked hull: the Warden break lifts the mark a keeper's gamble put on max hull.
	ctx.events.beacon_unsealed.connect(func(_stage: int): HullMark.lift(ctx.run))
	ctx.events.enemy_struck.connect(_on_tread_struck)
	ctx.events.player_died.connect(func(): shop.note_death(ctx.run.cogs))
	makers.setup()


# ---- Build API (for combat, presentation and world; see SEAMS.md) ----

func pattern_level(pattern_id: String) -> int:
	return sheet.pattern_level(pattern_id)


func patterns() -> Dictionary:
	return sheet.patterns.duplicate()


func has_transformer(transformer_id: String) -> bool:
	return transformer_id in sheet.transformers


func weapon_mod(key: String) -> float:
	return sheet.mod(key)


# Flat per-hit weapon damage from parts, added before the weapon multipliers.
func punch_bonus() -> float:
	return sheet.punch


# Flat damage Punch Rivet panels add to every weapon hit and ball contact (combat.gd).
func panel_punch() -> float:
	return sheet.panel_punch


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


# Codex cards for the build category: {id, category, name, hint, text, maker, tags}. Declared
# to ctx.codex at setup when the registry exists.
func codex_declarations() -> Array:
	var cards: Array = Synergies.declarations(func(maker: String) -> String: return String(MakerSets.SETS.get(maker, {}).get("name", maker)))
	for entry in Lanes.ENTRIES:
		cards.append(entry.duplicate())
	return cards


func discovered() -> Array:
	return _discovered.keys()


func found() -> Array:
	return _found.values()


# Known means discovered in this run or in any saved run (the codex's record).
func is_known(synergy_id: String) -> bool:
	var codex = _codex()
	if codex != null and codex.known(synergy_id):
		return true
	return _discovered.has(synergy_id)


# The element x material table, for any source: returns the resolved result, or {}
# when the pair does nothing. source is free text for logs ("dash", "event", ...).
func apply_element(element_id: String, at: Vector3, source := "") -> Dictionary:
	return field.apply(element_id, at, source)


func material_at(point: Vector3) -> Dictionary:
	return field.material_at(point)


func register_material(material_id: String, provider: Callable) -> void:
	field.register_material(material_id, provider)


static func resolve(element_id: String, material_id: String) -> Dictionary:
	return Elements.resolve(element_id, material_id)


# The line an offer (gate or fabricator) adds under its name: "* completes X *" when
# taking it wakes a maker trick, "* level N *" for a part already held, "* starts X *" for a
# maker's first piece while the lens perk is held, else "".
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


# ---- Loot API (v2 W4; CONTRACTS "Loot and shop") ----

# The nearest enemies within radius of at, nearest first, at most count.
func enemies_near(at: Vector3, radius: float, count: int) -> Array[Node3D]:
	return _enemies_near(at, radius, count)


# An item's own hit: callers pass damage before the weapon multiplier and this applies
# it once, as a synergy strike that never procs another item, with its element applied
# where it lands.
func item_hit(enemy: Node3D, damage: float, element := "") -> void:
	if not is_instance_valid(enemy) or damage <= 0.0:
		return
	_own_strikes += 1
	var at := enemy.global_position
	_strike(enemy, SYNERGY_KIND, damage * sheet.mod("weapon_damage"))
	if element != "":
		field.apply(element, at, "item")
	_own_strikes -= 1


# A part's live effect numbers for a card or the fuzzer: {id, trigger, procs}.
func item_procs() -> Dictionary:
	return effects.procs.duplicate()


# Maker sets: maker id to distinct pieces held (parts, relics and the racked active), the live
# bonus ids, and the active rack's open-frame question (fired in the air, fire twice).
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


# The class screen's opt-in challenge modifiers for the next run: {"scrapless": bool,
# "par": bool}. They take effect at run_started and are tagged in the run record.
func set_modifiers(chosen: Dictionary) -> void:
	_next_modifiers = chosen.duplicate()


func run_tags() -> Array:
	return clock.tags()


func scrapless() -> bool:
	return clock.on(RunClock.SCRAPLESS)


# W1's run clock and difficulty bar record (CONTRACTS "Loot and shop").
func clock_record() -> Dictionary:
	return clock.record(has_perk("par"))


# True while the ball is in Moss's bay: the director's difficulty clock should hold.
func clock_paused() -> bool:
	return shop.clock_paused()


# Which other modules' seams are live now; a part that needs a missing one is never
# offered (Parts.seams).
func _refresh_seams() -> void:
	var spawner = ctx.spawner
	var patterns: PackedStringArray = spawner.transformer_ids() if spawner != null and spawner.has_method("transformer_ids") else PackedStringArray()
	Parts.seams = {
		"spawner.extend_cloak": spawner != null and spawner.has_method("extend_cloak"),
		"spawner.fan_spread": "fan_spread" in patterns,
		"spawner.helix_drill": "helix_drill" in patterns,
		"player.set_vault_cooldown_scale": ctx.player.has_method("set_vault_cooldown_scale"),
		"player.set_vault_charges": ctx.player.has_method("set_vault_charges"),
	}


func _post(kind: int, source: String, proc: float, at: Vector3, enemy: Node3D = null, amount := 0.0) -> void:
	if proc <= 0.0 or not ctx.flow.in_play():
		return
	bus.post(Triggers.Commitment.new(kind, source, proc, at, enemy, amount))


# Every trigger source is a fact already on the bus (or build's own pickup and speed
# tier), so no other module's code changes to feed the vocabulary. The handlers only
# queue; the passes resolve in _step_loot.
func _connect_triggers() -> void:
	var events = ctx.events
	events.enemy_struck.connect(_on_struck_trigger)
	events.enemy_killed.connect(func(_kind: String, at: Vector3, _scrap: int):
		if ctx.run.last_kill_from_spark:
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


# One smash per physics frame, whichever flavour reported it.
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


# The speed tier rising is build's own commitment point, read once per step.
func _step_loot(delta: float) -> void:
	var tier: int = ctx.player.speed_tier()
	if tier > _speed_tier:
		_post(Triggers.Kind.ON_SPEED_TIER_UP, "speed", Triggers.DISCRETE_PROC, ctx.player.ball_position(), null, tier)
	_speed_tier = tier
	effects.tick(delta, bus)
	bus.run(effects.resolve, loot_rng)


# ---- Derivation ----

# Folds run.parts into the sheet and pushes it out: tuning mods, health ceiling,
# magnet, shatter damage and the ball's hardware. Idempotent, so a retry, a new part
# and a stage entry all call the same thing. A named synergy that comes live here for
# the first time this run is announced as armed.
func recompute() -> void:
	_sync_scrap_flags()
	sheet = stat_cache.sync(ctx.run.parts)
	_fold_panels()
	effects.refresh(ctx.run.parts)
	var mass_hp: float = effects.mass_health(ctx.run.mass)
	# Armour mode: mass lost to hits or wear never lowers the hull ceiling, so the
	# Scrap Armor bonus only ratchets up (same rule as _on_scrap_collected).
	if ctx.run.armor_mode:
		mass_hp = maxf(mass_hp, _mass_hp)
	_mass_hp = mass_hp
	sheet.max_hp_bonus += _mass_hp
	sheet.apply(ctx.tuning, ctx.run)
	_apply_shell()
	effects.apply_abilities(ctx.player)
	scrap.magnet_scale = sheet.magnet
	field.shatter_scale = sheet.dial("shatter_damage")
	for synergy_id in _live:
		if not synergy_id in sheet.synergies:
			_fired.erase(synergy_id)
	for synergy_id in sheet.synergies:
		if not synergy_id in _live:
			_on_synergy_live(synergy_id)
	_live = sheet.synergies.duplicate()
	_sets_fresh = []
	for trick_id in sheet.synergies:
		if Synergies.told_on_wake(trick_id) and not _woken.has(trick_id):
			_woken[trick_id] = true
			_sets_fresh.append(trick_id)
			_discovered[trick_id] = true
			var codex = _codex()
			if codex != null:
				if not _declared:
					_declare()
				codex.mark_known(trick_id, PARTICIPANTS)
	_redraw()


# Panels fold after the parts, so the louvre cap reads the parts' fire rate (IL-01 overflow).
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
	return ctx != null and ctx.tuning != null and ctx.tuning.option("hotwire_shell") == "on"


# The run holds the hot-wired Riveted Shell (Fit, then rolled through its gate). Like the tread
# (HotwireRules.fitted) it reads the held part; the flag off switches it off with the plating.
func shell_held() -> bool:
	return shell_fitted() and ctx.run != null and RIVETED_SHELL in ctx.run.parts


# The air factor with no inversion live: the stock plating's, and the held shell's on top.
func shell_rest_factor() -> float:
	if not shell_fitted():
		return 1.0
	return SHELL_AIR_FACTOR * (RIVETED_AIR_FACTOR if shell_held() else 1.0)


# The resolved air-control factor the shell contributes; 1.0 with the flag off. The one place
# an inversion flips it.
func shell_air_factor() -> float:
	if not shell_fitted():
		return 1.0
	# Active inversions do not stack: the highest factor wins (an implementation choice, not a
	# design ruling; BUILD-SYSTEMS.md lists S4, K5 and R6 without ranking them).
	var factor := shell_rest_factor()
	if _shell_window > 0.0 and _face_runner_s4():
		factor = maxf(factor, SHELL_AIR_FACTOR_VAULT)
	if _sprinting() and _second_wind_r6():
		factor = maxf(factor, SHELL_AIR_FACTOR_SPRINT)
	if _gliding() and _smoke_trail_k5():
		factor = maxf(factor, SHELL_AIR_FACTOR_VAULT)
	return factor


# R6 is taken: Rivet's Second Wind with the world-one profile on (parity with S4's gate).
func _second_wind_r6() -> bool:
	var tree = ctx.player.tree if ctx != null and ctx.player != null else null
	return tree != null and tree.world_one and "r_second_wind" in tree.picks


# K5 is taken: Kest's world-one Smoke Trail (same id at every flag state, so world_one gates it).
func _smoke_trail_k5() -> bool:
	var tree = ctx.player.tree if ctx != null and ctx.player != null else null
	return tree != null and tree.world_one and "k_smoke_trail" in tree.picks


# The live glide state: augments.gd owns kit.gliding and posts no end signal.
func _gliding() -> bool:
	return ctx != null and ctx.player != null and ctx.player.kit != null and ctx.player.kit.gliding


# The live sprint state: augments.gd owns kit.sprinting and posts no end signal.
func _sprinting() -> bool:
	return ctx != null and ctx.player != null and ctx.player.kit != null and ctx.player.kit.sprinting


# S4 is taken: the world-one Face Runner (same id as the base node at index 9, which the
# world-one depth cap keeps out of reach), so tree.world_one tells them apart.
func _face_runner_s4() -> bool:
	var tree = ctx.player.tree if ctx != null and ctx.player != null else null
	return tree != null and tree.world_one and "s_face_runner" in tree.picks


# A valid vault opens (or restarts) the window. build recomputes only on part changes, so the
# air-control mod is refreshed here and when the window closes; recompute() reads the same
# live factor, so a recompute inside the window keeps the flip.
func _open_shell_window() -> void:
	if not shell_fitted() or not _face_runner_s4():
		return
	_shell_window = SHELL_VAULT_WINDOW
	_refresh_air_mod()


# The part-derived air_control mod times the shell's current factor; nothing else touched.
func _refresh_air_mod() -> void:
	ctx.tuning.set_mod("air_control", sheet.mod("air_control") * shell_air_factor())
	_note_air_factor()


# One emit point for every inversion: a change of the resolved factor between two fitted
# reads. An unfitted shell resets the memory, so a toggle or a first read never cues.
func _note_air_factor() -> void:
	if not shell_fitted():
		_air_seen = 0.0
		_air_rest = 0.0
		return
	var factor := shell_air_factor()
	var rest := shell_rest_factor()
	var before := _air_seen
	var rest_before := _air_rest
	_air_seen = factor
	_air_rest = rest
	# Fitting the held shell moves the resting factor itself: a new baseline, not an inversion.
	if before > 0.0 and not is_equal_approx(before, factor) and is_equal_approx(rest_before, rest):
		shell_air_changed.emit(factor, factor > rest)


func shell_scrap_per_hp() -> float:
	if not shell_fitted():
		return RunState.SCRAP_PER_HP
	return SHELL_SCRAP_PER_HP / (RIVETED_ARMOUR if shell_held() else 1.0)


# ---- Hot-wired parts at the gates, and Spark Tread (H2) ----

# The first Warden broken in each world puts up the first part Parts.hotwire_offer allows as a
# striped rare gate beside the pair ("fit": it waits at the gates until taken). Later Wardens in
# that world add nothing new (the stage-2 discovery offer is authored elsewhere).
func _on_warden_broken_hotwire(_stage: int) -> void:
	var world := maxi(ctx.run.world, 1)
	if world != _hotwire_world:
		_hotwire_world = world
		_hotwire_spent = false
		_hotwire_id = ""
		_hotwire_state = ""
	if _hotwire_spent:
		return
	_hotwire_spent = true
	_hotwire_save()
	var ids := Parts.hotwire_offer(ctx.run.armor_mode, ctx.run.parts, ctx.run.world)
	if ids.is_empty():
		return
	_hotwire_id = ids[0]
	_hotwire_state = "fit"
	_hotwire_save()
	_hotwire_to_open_gates()


# Gates already standing are put up again with the hot-wired part beside them.
func _hotwire_to_open_gates() -> void:
	if gates.is_open() and not _hotwire_id in gates.offers.map(func(offer): return offer["part_id"]):
		var ids: Array = gates.offers.map(func(offer): return offer["part_id"])
		ids.append(_hotwire_id)
		ctx.events.reward_offered.emit(gates.open(ids, ctx.player.ball_position(), _heading(), ctx.run.parts))


# The offer's fields ride the run's extra so the entrance doc carries them: resume_run
# emits run_started (which clears them) before it applies the doc, so _hotwire_restore puts
# them back on the first stage_entered.
func _hotwire_save() -> void:
	if ctx != null and ctx.run != null:
		ctx.run.extra["hotwire"] = {"id": _hotwire_id, "state": _hotwire_state, "spent": _hotwire_spent, "world": _hotwire_world}


func _hotwire_restore(retry := false) -> void:
	if ctx == null or ctx.run == null:
		return
	# A retry rewinds the offer with the snapshot (run.restore put its saved fields back, or
	# erased them): a Recycle taken after the checkpoint is undone with its cogs.
	if retry and not ctx.run.extra.has("hotwire"):
		_hotwire_id = ""
		_hotwire_state = ""
		_hotwire_spent = false
		_hotwire_world = 1
		return
	if (_hotwire_spent and not retry) or not ctx.run.extra.has("hotwire"):
		return
	var saved: Dictionary = ctx.run.extra["hotwire"]
	_hotwire_id = String(saved.get("id", ""))
	_hotwire_state = String(saved.get("state", ""))
	_hotwire_spent = bool(saved.get("spent", false))
	_hotwire_world = int(saved.get("world", 1))
	# A save from before the fold can hold an offer still waiting on the Fit / Recycle screen
	# ("open"). There is no screen now, so it goes to the gates like a fresh one.
	if _hotwire_state == "open":
		_hotwire_state = "fit"
		_hotwire_save()


# {part_id, state}: state "fit" while the Warden break's hot-wired part waits at the gates (an old
# save may say "recycle", a choice the retired screen made); part_id "" when none was put up.
func hotwire_pending() -> Dictionary:
	return {"part_id": _hotwire_id, "state": _hotwire_state}


# The held hot-wired offer a gate opening adds after its rolled picks, until it is taken.
func _hotwire_gate_ids() -> Array:
	if _hotwire_state == "fit" and not _hotwire_id in ctx.run.parts:
		return [_hotwire_id]
	return []


func tread_fitted() -> bool:
	return ctx != null and ctx.run != null and ctx.tuning != null \
		and HotwireRules.fitted(ctx.run.parts, ctx.tuning.option("hotwire_tread"))


# A struck enemy: the first eligible attack after the recovery queues the bonus, and so does
# every strike of that attack (same kind, same frame). Resolved in the physics step, never
# inside combat's own strike.
func _on_tread_struck(enemy: Node3D, kind: String, force: float) -> void:
	if _own_strikes > 0 or not tread_fitted() or not is_instance_valid(enemy):
		return
	var frame := Engine.get_physics_frames()
	if frame != _tread_frame or kind != _tread_kind:
		var speed: float = ctx.player.planar_velocity().length()
		if not HotwireRules.eligible(kind, _tread_recovery, speed, ctx.tuning.f("cruise"), ctx.run.mass):
			return
		_tread_frame = frame
		_tread_kind = kind
		_tread_recovery = HotwireRules.RECOVERY
		tread_fires += 1
	var punch: float = ctx.spawner.punch_of(kind, force) if ctx.spawner != null and ctx.spawner.has_method("punch_of") else force
	_tread_hits.append({"enemy": enemy, "damage": HotwireRules.bonus_damage(punch)})


func _step_tread(delta: float) -> void:
	_tread_recovery = maxf(0.0, _tread_recovery - delta)
	var hits := _tread_hits
	_tread_hits = []
	_own_strikes += 1
	for hit in hits:
		_strike(hit["enemy"], SYNERGY_KIND, hit["damage"])
	_own_strikes -= 1


# After sheet.apply has cleared and refilled the mods, so the penalty survives every recompute.
func _apply_shell() -> void:
	ctx.run.scrap_per_hp = shell_scrap_per_hp()
	if shell_fitted():
		ctx.tuning.set_mod("air_control", ctx.tuning.mod("air_control") * shell_air_factor())
	_note_air_factor()


func _redraw() -> void:
	accretion.show_build(ctx.run.mass, ctx.run.parts, sheet.synergies, ctx.run.heft_class())
	panel_shell.show_panels(ctx.run.panels, ctx.run.run_seed)


func _codex():
	return ctx.codex


# The hint cards go to the codex on the first tick of play rather than in setup. The
# codex exists at setup, but spine_codex_test counts exact entries right after class
# select and fails if a module's cards are there (SPINE REQUEST in the handoff). A
# repeat declare is harmless, and the Tab codex only matters in play.
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
		Synergies.table = null


# A synergy coming live is announced once per run; discovery waits for its first firing
# (_fire), because the owner learns a synergy by seeing what it does.
func _on_synergy_live(synergy_id: String) -> void:
	if _armed.has(synergy_id):
		return
	_armed[synergy_id] = true
	ctx.events.cause_armed.emit(synergy_id)


# A named synergy's effect really happened: publish where and on what (body is null when
# no single body was struck), and the first firing of an activation is its discovery.
func _fire(synergy_id: String, body: Node3D, at: Vector3) -> void:
	ctx.events.cause_fired.emit(synergy_id, body, at)
	if _fired.has(synergy_id):
		return
	_fired[synergy_id] = true
	_discovered[synergy_id] = true
	var codex = _codex()
	if codex != null:
		if not _declared:
			_declare()
		codex.mark_discovered(synergy_id, ctx.player.ball_position(), PARTICIPANTS)


# An unnamed interaction, reported every time it fires; the codex logs it once per
# attempt and lets a retried attempt find it again (CONTRACTS, Codex).
func _note_found(key: String, text: String) -> void:
	_found[key] = text
	var codex = _codex()
	if codex != null:
		codex.mark_found(text, Synergies.CATEGORY, PARTICIPANTS)


# The field resolved an element against a material: publish it once for presentation
# (element_resolved, B's signal), then log a first find.
func _on_element_resolved(result: Dictionary) -> void:
	ctx.events.element_resolved.emit(result["element"], result["material"], result["behaviour"], result["at"])
	var key: String = result.get("key", "")
	if key == "arc:ice" and result.get("source", "") == "slam" and has_transformer("thermal_shock") and result.get("shattered", 0) > 0:
		_fire("thermal_shock", null, ctx.player.ball_position())
	var row := Elements.ROWS.get(key, {}) as Dictionary
	if row.has("found"):
		_note_found("element:" + key, row["found"])


# SG2: a fusion's first fire logs its codex card, which carries the row's elite rule.
func _on_fused(result: Dictionary) -> void:
	_note_found("fusion:" + String(result["key"]), Elements.card_text(Elements.FUSIONS[result["key"]]))


func _class_id() -> String:
	return ctx.run.class_id()




# The element a told-on-wake trick adds, "frost" or "arc": what its chime rings in.
func set_element(trick_id: String) -> String:
	return Synergies.element(trick_id)


func _on_part_gained(part_id: String, _source: String) -> void:
	recompute()
	# A copy: a listener's own part gain recomputes and replaces the list.
	for trick_id in _sets_fresh.duplicate():
		var row: Dictionary = Synergies.ROWS[trick_id]
		set_completed.emit(trick_id, row["name"], row["text"], row["color"])
	_grant_evolutions()
	var d: Resource = Parts.def(part_id)
	if d != null and d.effect.get("do", "") == "ballast":
		ctx.run.add_scrap(int(d.effect.get("mass", 0)), ctx.player.ball_position())


# Scrap Armor reads mass, so a pickup can raise the health ceiling; nothing else in the
# build changes with mass.
func _on_scrap_collected(_amount: int, _at: Vector3, _total: int) -> void:
	var mass_hp: float = effects.mass_health(ctx.run.mass)
	# Armour mode lets the mass layer wear and spill without ever touching the hull, so
	# the ceiling Scrap Armor grants only ratchets up.
	if ctx.run.armor_mode:
		mass_hp = maxf(mass_hp, _mass_hp)
	if mass_hp != _mass_hp:
		sheet.max_hp_bonus += mass_hp - _mass_hp
		_mass_hp = mass_hp
		ctx.run.set_max_hp(HullMark.ceiling(ctx.run, ctx.run.base_max_hp() + sheet.max_hp_bonus))
	_redraw()


func _on_run_started(_class_id_value: String) -> void:
	_relic_fx.clear()
	_live = []
	_armed.clear()
	_fired.clear()
	_mass_hp = 0.0
	_shell_window = 0.0
	_air_seen = 0.0
	_air_rest = 0.0
	_hotwire_id = ""
	_hotwire_state = ""
	_hotwire_spent = false
	_hotwire_world = 1
	_tread_recovery = 0.0
	_tread_frame = -1
	_tread_hits = []
	tread_fires = 0
	_discovered.clear()
	_found.clear()
	_woken.clear()
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
		_fired.clear()
		# A retry undocks the bay without a bay_left, so the shop visit ends here; left set,
		# the run clock and wear would stay paused through the whole retried stage.
		shop.inside = false
		shop.rewind_stage()
	gates.close()
	field.clear()
	_trail = 0.0
	_slams.clear()
	_rams.clear()
	_kills.clear()
	_landings.clear()
	_shots.clear()
	_pinwheel_cut.clear()
	_rod_budget = ROD_PER_SECOND
	_shrapnel_budget = SHRAPNEL_PER_SECOND
	bus.clear()
	effects.reset_stage()
	clock.enter_stage(stage)
	lanes.reset()
	_offered = {}
	_vaults_paid = 0
	_overtimes_paid = 0
	# A retry replays the same procs and panel drops: the seeds name the run and stage only.
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


# The arena is not a stage (DESIGN-NOTES spine call 34): the scrap field, the
# fabricators, any open gates and every surface an element made on the stage go now.
# The build itself, its synergies and its elements keep working in the fight. An arena
# retry has just restored the run silently, so the build and the ball's shell are
# recomputed from the restored parts and mass.
func _on_stage_content_cleared(reason: String) -> void:
	if reason == "arena_retry":
		_fired.clear()
	# A Continue into the arena (SA-F1) reaches it with no stage_entered, so the relics are put on the kit here.
	sync_relics()
	scrap.clear()
	fabricators.clear()
	gates.close()
	field.clear()
	_trail = 0.0
	recompute()


func _on_enemy_killed(kind: String, at: Vector3, scrap_value: int) -> void:
	if has_transformer("shrapnel_bloom") and not ctx.run.last_kill_from_spark:
		_kills.append(at)
	if not ctx.flow.in_stage():
		return
	# The stage row's kill_scrap (the slice's 4.0; a row without one pays 1.0) scales a kill on top of the sheet's.
	var stage_pay := float(ctx.flow.stage_def().get("kill_scrap", 1.0))
	var amount := int(round(scrap_value * sheet.kill_scrap * stage_pay)) if not scrapless() else 0
	# A kill pays mass as scrap and the wallet as an equal count of 1-cog gears (CG1).
	if kind == "warden":
		scrap.drop_line(at, _heading(), WARDEN_LINE, amount, scrap_rng)
		scrap.drop_cogs_line(at, _heading(), WARDEN_LINE, amount)
	else:
		scrap.drop(at, amount, scrap_rng)
		scrap.drop_cogs(at, amount)
	_drop_panel(kind, at)
	# A vault pays out a rare part and a bonus core (DEMO-SPEC engagement tiers).
	if kind == "vault":
		# Each vault in a stage rolls its own stream, so two vaults never pay the same part.
		_vaults_paid += 1
		var vault_rng := _offer_rng("vault_%d" % _vaults_paid)
		var picks: Array = Parts.roll(vault_rng, Parts.SOURCE_RARITIES["vault"], _class_id(), ctx.run.parts, 1)
		if not picks.is_empty() and not scrapless():
			ctx.run.add_part(picks[0], "vault")
		ctx.run.add_core("vault", at)
		var active := active_offer("vault", Parts.SOURCE_RARITIES["vault"], vault_rng)
		if active != "" and not scrapless():
			active_rack().take(active, ctx.player.ball_position())


# A kill may drop a grey panel (IL-01 card section 3): elite kills always, an ordinary kill
# at the drop row's chance plus pity, raised in off-spine ribs and on reel or dunk kills. The
# stat leans toward the pilot's nemesis answers. Draws only from panel_rng, so no other
# stream moves. A yard lock's crew (stage_locks.gd) does not roll: the cleared yard pays one
# panel (yard_cleared), so the lock's waves add fights, not a pile of panels, and pity waits.
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


# A yard lock broken to its last wave (stage_locks.gd): one panel at the yard's centre, Isaac's
# room-clear reward. It draws from panel_rng like a kill and leaves the pity count alone.
func yard_cleared(at: Vector3) -> void:
	if scrapless():
		return
	if kill_log.size() < KILL_LOG_CAP:
		kill_log.append([ctx.flow.stage(), "yard_clear", false, 1.0, false, true, false])
	scrap.drop_panel(at, Panels.draw(panel_rng, _class_id()))


# The overtime pot (overtime.gd, loops.md Spec 2), on top of the yard's own panel (ruling af
# stays): one ring adds a panel, two add a rare (cobalt) part, three add a core and another rare.
# Each payout rolls its own stream, like a vault's, so no other stream moves.
func overtime_paid(at: Vector3, rings: int) -> void:
	if scrapless() or rings <= 0:
		return
	_overtimes_paid += 1
	var rng := _offer_rng("overtime_%d" % _overtimes_paid)
	scrap.drop_panel(at, Panels.draw(rng, _class_id()))
	var rares := (1 if rings >= 2 else 0) + (1 if rings >= 3 else 0)
	for i in rares:
		var picks: Array = Parts.roll(rng, Parts.SOURCE_RARITIES["vault"], _class_id(), ctx.run.parts, 1)
		if not picks.is_empty():
			ctx.run.add_part(picks[0], "overtime")
	if rings >= 3:
		ctx.run.add_core("overtime", at)


# The rib multiplier at a kill: DROP.rib in an off-spine dead end, else 1.0. A stage with no
# cell data pays 1.0 and says so once.
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


# The stage's rib caches: Panels.RIB_CACHES panels, each at the end of a seeded off-route dead
# end. Their own stream (run seed and stage, not retries) puts a retry's caches back where
# they were, with the same panels.
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


# A graph node's y can sit under a deck laid over it (the flume's crew_ledges node is at 76.5
# under a deck at 77.5), so a cache stands on the surface a ray finds from CACHE_RAY_UP over
# its node to CACHE_RAY_DOWN under it. A stage entered from another stage can tick before its
# colliders reach the physics space, so a miss waits a tick, up to CACHE_WAIT_TICKS, and then
# falls back to the node.
const CACHE_RAY_UP := 2.0
const CACHE_RAY_DOWN := 1.0
const CACHE_WAIT_TICKS := 30
# A node can sit on a wall, a face steeper than 60 degrees: the dam's (64, -232) is on a dome's
# flank 6 m over the floor, where a ball rolled in from 25 m on 0 of 8 headings and only the
# magnet took the panel from below. Such a cache moves to the flattest surface on the nearest
# ring that has one, rings CACHE_SLIDE_STEP apart out to CACHE_SLIDE_M, each ray reaching
# CACHE_SLIDE_DOWN under the node.
const CACHE_STAND_NORMAL := 0.5
const CACHE_SLIDE_STEP := 3.0
const CACHE_SLIDE_M := 12.0
const CACHE_SLIDE_DOWN := 10.0
const CACHE_SLIDE_BEARINGS := 8


# The surface a cache spot stands on (under it, or the nearest non-wall beside it), or null when
# the ray under it finds none.
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


# Debug drawer (dev only): grant a panel at the ball.
func grant_panel(panel_id: String) -> void:
	ctx.run.add_panel(panel_id, ctx.player.ball_position())


# The active rack (src/combat/actives) while --actives is on, else null.
func active_rack():
	var rack = ctx.spawner.get("actives") if ctx.spawner != null else null
	return rack if rack != null and rack.enabled() else null


# An active offer id for a draw from `source` at these rarities (ActiveOffers), or "" with
# --actives off, when none fits, or when the draw's share misses.
func active_offer(source: String, rarities: Array, rng: RandomNumberGenerator) -> String:
	var rack = active_rack()
	if rack == null:
		return ""
	return ActiveOffers.roll(rng, source, rack.rows(), rarities, rack.held())


func _active_row(id: String) -> Dictionary:
	var rack = active_rack()
	return rack.row_of(id) if rack != null else {}


# The gates open when flow enters its gates state, never on the charge reading: a
# sealed beacon's shown charge can reach 1.0 a tick before the Warden's kill is
# recorded, and gates opened then would be ignored by flow and soft-lock the stage.
# Stage 2's pair carries the pattern guarantee (Parts.roll_gate).
func _on_flow_changed(state: String) -> void:
	if state != "gates" or gates.is_open():
		return
	# The called shot settles here (called_shot.gd): a met call lifts the pair, a missed one costs a core.
	var rarities: Array = called_shot.gate_rarities()
	var gate_rng := _offer_rng("gates")
	var picks: Array = Parts.roll_gate(gate_rng, rarities, _class_id(), ctx.run.parts, GATE_CHOICES, ctx.flow.stage(), _offered)
	picks = Parts.floor_gate(gate_rng, picks, _class_id(), ctx.run.parts, _offered, GATE_CHOICES)
	for part_id in picks:
		_offered[part_id] = _offered.get(part_id, 0) + 1
	picks += _hotwire_gate_ids()
	var active := active_offer("gate", rarities, gate_rng)
	if active != "":
		picks.append(active)
	ctx.events.reward_offered.emit(gates.open(picks, ctx.player.ball_position(), _heading(), ctx.run.parts))


# A reward's own stream, named by the run, the stage and the source: the gate pair and a vault's
# roll do not move with how many kills or hits came before them in the stage.
func _offer_rng(source: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.rng.seed, ctx.flow.run_key(), ctx.flow.stage(), source])
	return rng


# Scrapless still rolls through a gate to launch (the handshake needs reward_chosen);
# it just takes nothing.
func _on_gate_chosen(part_id: String) -> void:
	if ActiveOffers.is_offer(part_id):
		var rack = active_rack()
		if rack != null and not scrapless():
			rack.take(part_id, ctx.player.ball_position())
	elif not scrapless():
		ctx.run.add_part(part_id, "gate")
	ctx.events.reward_chosen.emit(part_id)


# A won event pays out its milestone part at once, so the stinger and the new part land
# as one beat. The event's bonus core is world's to grant (DESIGN-NOTES I1 call 5).
func _on_milestone_won(event_id: String) -> void:
	if not scrapless():
		ctx.run.add_part(Parts.milestone_for(event_id, ctx.run.parts), "milestone")


# A theft: the chunks the lost mass carried fly off toward where it went.
func _on_scrap_lost(_amount: int, at: Vector3, _total: int, _cause: String) -> void:
	var want := Accretion.chunks_for(ctx.run.mass)
	if accretion.chunk_count() > want:
		accretion.fling(accretion.chunk_count() - want, at, ctx.root)
	_redraw()


# The bus reports what happened; the elements and synergy effects it triggers resolve
# in this module's own physics step, once each (TADR-008: a signal applies nothing).
func _on_dashed(_direction: Vector3) -> void:
	if not sheet.elements_for("dash").is_empty():
		_trail = FROST_TRAIL
		_trail_ticks = 0


# A paid chain of 3 or more bursts scrap at its landing (W1-74), scaled as a kill's scrap is.
# Scrap only: the wallet already outruns the shop by Brindle (gameplay critique finding 11).
func _on_line_state(id: String, _target: Node3D, at: Vector3, cause: String) -> void:
	if id != "chain_end" or cause != "paid" or scrapless() or not ctx.flow.in_stage():
		return
	var stage_pay := float(ctx.flow.stage_def().get("kill_scrap", 1.0))
	var amount := int(round(ctx.player.chain.last_burst() * sheet.kill_scrap * stage_pay))
	if amount > 0:
		scrap.drop(at, amount, chain_rng)


# Every slam carries kinetic, so a slam on ice shatters it whatever you hold.
func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	_slams.append({"at": at, "strength": clampf(strength, 0.3, 1.6)})


func _on_landed(impact: float) -> void:
	if has_transformer("glacier_hull") and impact >= GLACIER_IMPACT:
		_landings.append(impact)


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if kind == "ram" and has_transformer("wrecking_ball") and is_instance_valid(enemy):
		_rams.append(enemy.global_position)


func _on_shot_fired(_weapon_id: String, _from: Vector3, to: Vector3) -> void:
	if has_transformer("storm_lattice"):
		_fire("storm_lattice", null, ctx.player.ball_position())
	if not sheet.elements_for("shot").is_empty():
		_shots.append(to)
	if has_transformer("linked_spiral"):
		_note_found("trick:linked_spiral", Synergies.ROWS["linked_spiral"]["found"])


# The ball's own line when it is moving, else where the player faces.
func _heading() -> Vector3:
	var flat: Vector3 = ctx.player.planar_velocity()
	if flat.length() > 3.0:
		return flat.normalized()
	return ctx.heading()


# ---- Scrap as armour (the durability prototype; every branch is behind tuning flags) ----

func _sync_scrap_flags() -> void:
	if ctx == null or ctx.tuning == null or ctx.run == null:
		return
	ctx.run.armor_mode = ctx.tuning.armor()
	ctx.run.wear_on = ctx.tuning.wear_on()


# The fixed route: --route-seed reseeds the run's streams, --start-mass opens with that mass.
# Flow takes the stage checkpoint after run_started, so a retry restores it.
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


# --companion-stub=on: one piece per family owned at run start, none assembled. Activities pay
# pieces in play now; the stub stays as a test aid.
func _grant_companion_stub() -> void:
	if ctx.tuning == null or ctx.tuning.option("companion_stub") != "on" or not ctx.run.companion.is_empty():
		return
	var model := Companion.new()
	for id in ["primer_coil", "ram_prow", "escape_vent"]:
		model.acquire(id)
	ctx.run.companion = model.to_dict()


# A hit removed scrap: SPILL_CLUSTERS at most, ahead of or beside the outgoing line.
# Recovery runs only where the scrap field does (stage play). The boss arena clears the
# field and never steps it, so a cluster dropped there could never be collected: the
# spill is destroyed instead and logged, so the hit reads as what it cost. A scrapless run
# never steps the field either, so its spill is destroyed the same way.
func _on_armor_hit(_removed: float, spill: int, _source: String) -> void:
	if scrapless():
		ctx.run.metrics["destroyed"] += spill
		_redraw()
		return
	if not ctx.flow.in_stage():
		# A boss that takes the spill puts it back on its floor (ruling aw); anywhere else
		# it has nowhere to land and is destroyed.
		var boss = ctx.boss if "boss" in ctx else null
		if boss == null or not boss.has_method("take_spill") or not boss.take_spill(ctx.player.ball_position(), _heading(), spill):
			ctx.run.metrics["destroyed"] += spill
			ctx.run.metrics["arena_destroyed"] += spill
		_redraw()
		return
	scrap.drop_recovery(ctx.terrain, ctx.player.ball_position(), _heading(), spill, RunState.SPILL_CLUSTERS, scrap_rng)
	_redraw()


# Runs in stage play only: wear, recovered scrap and the reversing metric. Wear is
# grounded play in a stage: not paused (the tree does not tick), not in the bay, and not
# in the launch flight or an authored transfer.
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
	# Spark Tread doubles ordinary wear by doubling the accrual, through the one wear path.
	var wear_delta := delta * HotwireRules.wear_scale(tread_fitted())
	run.wear_step(wear_delta, planar.length(), ctx.tuning.f("cruise"), grounded and not get_tree().paused and not shop.clock_paused())
	# Seconds reversing toward a spill (an approximation): a spill is live and the ball
	# is moving against the stage's entry heading, the route's forward direction.
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
	if _shell_window > 0.0:
		_shell_window -= delta
		if _shell_window <= 0.0:
			_shell_window = 0.0
			_refresh_air_mod()
	# Sprint edge: polled from kit.sprinting on the sim clock, so a release, a drain and a
	# cleared SPRINT flag all refresh. Reads at most one physics tick behind the player, and
	# not at all while not in play (the guard above), so an end during a pause lands late.
	var sprinting_now := _sprinting()
	if sprinting_now != _sprint_seen:
		_sprint_seen = sprinting_now
		if shell_fitted():
			_refresh_air_mod()
	# Glide edge (K5): same polling as the sprint edge above.
	var gliding_now := _gliding()
	if gliding_now != _glide_seen:
		_glide_seen = gliding_now
		if shell_fitted():
			_refresh_air_mod()
	_step_tread(delta)
	makers.step(delta)
	_rod_budget = minf(ROD_PER_SECOND, _rod_budget + ROD_PER_SECOND * delta)
	_shrapnel_budget = minf(SHRAPNEL_PER_SECOND, _shrapnel_budget + SHRAPNEL_PER_SECOND * delta)
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
			# Gears fill the wallet only: no mass, no scrap_collected and no pickup procs.
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
		# The ball rolled through a stocked hoop, bought or not: the fabricator tune's cue
		# (tunes.json "fabricator"). No WORLD_ROWS row, so it plays no sound of its own.
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


# Slam order: the parts' own elements first (Arc Coil's arc shatters ice at the
# Thermal Shock bonus), then the slam's kinetic, then frost last so it lays fresh ice.
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


# ---- Evolutions ----

# Both ingredients of an evolution held: the run gains its Evolved part once, announced as
# part_gained with source "evolution". Nested gains recompute and find nothing more ready.
func _grant_evolutions() -> void:
	for part_id in Synergies.evolutions_ready(ctx.run.parts):
		ctx.events.evolution_fired.emit(part_id)
		ctx.run.add_part(part_id, "evolution")


# The awake maker tricks by name, with the maker that woke each.
func synergy_read() -> Array:
	return sheet.synergies.map(func(key): return {"id": key, "name": Synergies.ROWS[key]["name"], "maker": Synergies.ROWS[key]["maker"]})


# ---- Named synergy behaviours ----

func _step_synergies(ball: Vector3, delta: float) -> void:
	for at in _rams:
		field.flash_ring(at, WRECK_RADIUS, Palette.AMBER)
		var wrecked := false
		for enemy in _enemies_near(at, WRECK_RADIUS, 99):
			if enemy.global_position.distance_to(at) > 0.5:
				wrecked = true
				_synergy_hit(enemy, WRECK_FORCE, "wrecking_ball")
		if not wrecked:
			_fire("wrecking_ball", null, at)
	_rams.clear()
	for at in _kills:
		if _shrapnel_budget < 1.0:
			break
		_shrapnel_budget -= 1.0
		field.shard_burst(at)
		var burst_targets := _enemies_near(at, SHRAPNEL_RADIUS, SHRAPNEL_TARGETS)
		for enemy in burst_targets:
			_synergy_hit(enemy, SHRAPNEL_FORCE, "shrapnel_bloom")
		if burst_targets.is_empty():
			_fire("shrapnel_bloom", null, at)
	_kills.clear()
	for impact in _landings:
		field.flash_ring(ball + Vector3.DOWN * 0.8, GLACIER_RADIUS, ElementField.ICE)
		var ring_targets := _enemies_near(ball, GLACIER_RADIUS, 99)
		for enemy in ring_targets:
			_synergy_hit(enemy, impact * 1.5, "glacier_hull")
		if ring_targets.is_empty():
			_fire("glacier_hull", null, ball)
		_frost_ring(ball)
	_landings.clear()
	if has_transformer("tesla_pylon") and (ctx.player.kit.mounted or ctx.player.kit.hooked):
		_tesla_clock -= delta
		if _tesla_clock <= 0.0:
			_tesla_clock = TESLA_EVERY
			for enemy in _enemies_near(ball, TESLA_REACH, TESLA_TARGETS):
				field.zap_line(ball, enemy.global_position)
				_strike(enemy, "arc", TESLA_DAMAGE * sheet.mod("weapon_damage"))
				_fire("tesla_pylon", enemy, enemy.global_position)
	else:
		_tesla_clock = 0.0
	for id in _pinwheel_cut.keys():
		_pinwheel_cut[id] -= delta
		if _pinwheel_cut[id] <= 0.0:
			_pinwheel_cut.erase(id)
	if has_transformer("pinwheel") and ctx.player.speed_tier() >= PINWHEEL_TIER:
		_pinwheel_clock -= delta
		if _pinwheel_clock <= 0.0:
			_pinwheel_clock = PINWHEEL_EVERY
			field.flash_ring(ball, PINWHEEL_RADIUS, Palette.AMBER)
		for enemy in _enemies_near(ball, PINWHEEL_RADIUS, PINWHEEL_TARGETS):
			if not _pinwheel_cut.has(enemy.get_instance_id()):
				_pinwheel_cut[enemy.get_instance_id()] = PINWHEEL_EVERY
				_synergy_hit(enemy, PINWHEEL_FORCE, "pinwheel")
	else:
		_pinwheel_clock = 0.0


func _lightning_rod(ball: Vector3) -> void:
	if _rod_budget < 1.0:
		return
	var targets := _enemies_near(ball, ROD_REACH, 1)
	if targets.is_empty():
		return
	_rod_budget -= 1.0
	field.zap_line(ball, targets[0].global_position)
	_strike(targets[0], "arc", ROD_DAMAGE * sheet.mod("weapon_damage"))
	_fire("lightning_rod", targets[0], targets[0].global_position)


# The nearest enemies within radius of at, nearest first, at most count.
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


# A synergy's shockwave, shrapnel, frost ring or blade is its own strike kind, never a
# landing: a weak point that takes a slam (a vent cap, the scooter) must not take one
# the ball never landed. The spawner resolves a kind outside its contact table as the
# damage given, so build scales it the way the slam row it replaced did.
func _synergy_hit(enemy: Node3D, force: float, synergy_id: String) -> void:
	_strike(enemy, SYNERGY_KIND, force * SYNERGY_PUNCH * ctx.run.heft())
	_fire(synergy_id, enemy, enemy.global_position)


# ---- RL2: relics on the kit. -------------------------------------------------------------
# What each slot's held relic did to the kit: slot to {relic, prev (the ability id the
# swap replaced), swapped, cooldown, charges}. sync_relics() makes the kit match the relics
# in the part list (Relics.held) from this record, so a gain, a stage entry, a retry and a
# loaded entrance all land on the same kit and none applies a row twice.
var _relic_fx := {}


func _on_relic_gained(_part_id: String, _source: String) -> void:
	sync_relics()


func sync_relics() -> void:
	var abilities = ctx.player.get("abilities") if ctx.player != null else null
	if abilities == null:
		return
	_adopt_saved_relics()
	var held := Relics.held(ctx.run.parts)
	var touched := false
	for slot in AbilityState.SLOTS:
		var want: String = held.get(slot, "")
		if not Relics.has(want):
			want = ""
		var fx: Dictionary = _relic_fx.get(slot, {})
		if String(fx.get("relic", "")) == want:
			continue
		if not fx.is_empty():
			_relic_undo(abilities, slot, fx)
			_relic_fx.erase(slot)
		if want != "":
			_relic_fx[slot] = _relic_apply(abilities, slot, want)
		touched = true
	if touched and ctx.player.has_method("_refit"):
		ctx.player._refit()


# A save from before relics joined the part list holds them in RunState.relics, slot to relic
# id. They move into the part list once, silently (no part_gained, so no second reveal), and
# the old map is emptied so a later save writes them in one place only.
func _adopt_saved_relics() -> void:
	if ctx.run.relics.is_empty():
		return
	for slot in ctx.run.relics:
		var part_id := Relics.part_of(String(ctx.run.relics[slot]))
		if part_id != "" and not part_id in ctx.run.parts:
			ctx.run.parts.append(part_id)
	ctx.run.relics.clear()
	recompute()


func _relic_apply(abilities, slot: String, relic_id: String) -> Dictionary:
	var row := Relics.row(relic_id)
	var fx := {"relic": relic_id, "prev": abilities.id_of(slot), "swapped": false,
		"cooldown": float(row.get("cooldown", 1.0)), "charges": int(row.get("charges", 0))}
	if Relics.swap_of(relic_id) != "":
		abilities.swap(slot, Relics.swap_of(relic_id))
		fx["swapped"] = true
	var s = abilities.slot(slot)
	abilities.set_cooldown_scale(slot, s.cooldown_scale * fx["cooldown"])
	if fx["charges"] > 0:
		abilities.set_max_charges(slot, s.max_charges + fx["charges"])
		abilities.grant(slot, fx["charges"])
	return fx


func _relic_undo(abilities, slot: String, fx: Dictionary) -> void:
	var s = abilities.slot(slot)
	if fx["charges"] > 0:
		abilities.set_max_charges(slot, s.max_charges - fx["charges"])
	abilities.set_cooldown_scale(slot, s.cooldown_scale / fx["cooldown"])
	# A tree pick that swaps the slot to the same row keeps it: undoing the relic must not
	# strip a pick the player made (the swap relics duplicate a tree node on purpose).
	var tree = ctx.player.tree if ctx.player != null else null
	var tree_owns: bool = tree != null and tree.gives_swap(slot, Relics.swap_of(fx["relic"]))
	if fx["swapped"] and abilities.id_of(slot) == Relics.swap_of(fx["relic"]) and not tree_owns:
		abilities.swap(slot, fx["prev"])
