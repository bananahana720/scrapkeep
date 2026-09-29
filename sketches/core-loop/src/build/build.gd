extends Node

const ScrapField := preload("res://src/build/scrap_field.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const ElementField := preload("res://src/build/element_field.gd")
const Elements := preload("res://src/build/elements.gd")
const Accretion := preload("res://src/build/accretion.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const Palette := preload("res://src/core/palette.gd")
const Triggers := preload("res://src/build/triggers.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const RunClock := preload("res://src/build/run_clock.gd")
const Shop := preload("res://src/build/shop.gd")
const Lanes := preload("res://src/build/lanes.gd")
const RunState := preload("res://src/core/run_state.gd")

# Writer B's module: build and growth. Scrap magnetizes to the ball and sticks to it;
# drive-through fabricators turn scrap into parts on the roll; the reward gates after
# the beacon offer two parts you roll through; vaults and won events award parts. Every
# held part folds into one derived sheet (build_sheet.gd) that sets the tuning mods,
# the pattern levels combat reads, the element triggers that feed the element x
# material table (elements.gd, resolved by element_field.gd), and the live synergies.
#
# Synergies (synergies.gd) are tag pairs. This module runs the behaviour of each named
# one, tells the codex (ctx.codex) the first time each goes live in a run, and tells it
# the first time an unnamed interaction fires. The codex publishes synergy_discovered
# and interaction_found and grants the discovery burst; build never emits those two.
#
# Other modules reach this node as ctx.build (ctx.build_module() also finds it). Its
# public API is the "Build API" block; SEAMS.md lists the ids.

const GATE_CHOICES := 2
# Hot-wired H1, Riveted Shell (--hotwire-shell=on): the armour costs this much less scrap per
# absorbed HP, and airborne steering takes this factor. Read through shell_scrap_per_hp() and
# shell_air_factor() only, so an inversion (S4, K5, R6) changes one return value later.
const SHELL_SCRAP_PER_HP := 5.0
const SHELL_AIR_FACTOR := 0.75
const PARTICIPANTS := ["player"]
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
var sheet
# v2 W4 loot: the trigger bus, what held items do, and the loot's own seeded stream
# (reseeded each stage entry, so a retry replays the same procs and never draws from
# the run's shared ctx.rng).
var bus
var effects
# The run and difficulty clocks W1 draws, Moss's shop economy, and the bowling score.
var clock
var shop
var lanes
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
var _tesla_clock := 0.0
var _pinwheel_clock := 0.0
# Pinwheel cuts each enemy at most once per PINWHEEL_EVERY: instance id to time left.
var _pinwheel_cut := {}
# Named synergies live after the last recompute, to spot a new activation.
var _live: Array = []
# Discovered this run (id to true) and found this run (key to description). The codex
# registry, when present, is the lasting record; these keep the run's view.
var _discovered := {}
var _found := {}
var _declared := false


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Build"
	sheet = BuildSheet.from_parts([])
	scrap = ScrapField.new()
	scrap.name = "Scrap"
	ctx.root.add_child(scrap)
	scrap.setup()
	gates = RewardGates.new()
	gates.name = "RewardGates"
	ctx.root.add_child(gates)
	gates.setup(ctx.terrain)
	gates.mark_for = offer_mark
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
	accretion = Accretion.new()
	ctx.player.roll_node().add_child(accretion)
	accretion.setup()
	bus = Triggers.Bus.new()
	effects = ItemEffects.new(self)
	clock = RunClock.new()
	shop = Shop.new(ctx, self)
	lanes = Lanes.new()
	ctx.build = self
	ctx.set_meta("build", self)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.flow_changed.connect(_on_flow_changed)
	ctx.events.part_gained.connect(_on_part_gained)
	ctx.events.scrap_collected.connect(_on_scrap_collected)
	ctx.events.milestone_won.connect(_on_milestone_won)
	ctx.events.dashed.connect(_on_dashed)
	ctx.events.slammed.connect(_on_slammed)
	ctx.events.landed.connect(_on_landed)
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	ctx.events.shot_fired.connect(_on_shot_fired)
	ctx.events.run_started.connect(_on_run_started)
	ctx.events.scrap_lost.connect(_on_scrap_lost)
	ctx.run.armor_hit.connect(_on_armor_hit)
	_sync_scrap_flags()
	ctx.events.heft_class_changed.connect(func(_c: int, _h: float): _redraw())
	_connect_triggers()
	ctx.events.beacon_unsealed.connect(func(_stage: int): clock.warden_broken())
	ctx.events.player_died.connect(func(): shop.note_death(ctx.run.scrap))


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


# Codex hint cards for the build category: {id, category, name, hint, clue, text,
# shown, tags}. Declared to ctx.codex at setup when the registry exists.
func codex_declarations() -> Array:
	var cards: Array = Synergies.declarations(func(part_id: String) -> String: return Parts.display_name(part_id))
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
# taking it brings a named synergy live, "* ingredient: ??? *" when it is the shown
# ingredient of a synergy not yet live (named once discovered), else "".
func offer_mark(part_id: String) -> String:
	var held: Array = ctx.run.parts
	var completes := Parts.completed_by(part_id, held)
	if completes != "":
		return "* completes %s *" % Synergies.ROWS[completes]["name"]
	var ingredient := Parts.ingredient_of(part_id, held)
	if ingredient != "":
		var named: bool = is_known(ingredient) or has_perk("lens")
		return "* ingredient: %s *" % (Synergies.ROWS[ingredient]["name"] if named else "???")
	return ""


# ---- Loot API (v2 W4; CONTRACTS "Loot and shop") ----

# The nearest enemies within radius of at, nearest first, at most count.
func enemies_near(at: Vector3, radius: float, count: int) -> Array[Node3D]:
	return _enemies_near(at, radius, count)


# An item's own hit: damage after the weapon multiplier, as a synergy strike that never
# procs another item, with its element applied where it lands.
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
			_post(Triggers.Kind.ON_VAULT, "vault", Triggers.DISCRETE_PROC, at, null, speed))
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
# the first time this run is a discovery.
func recompute() -> void:
	_sync_scrap_flags()
	sheet = BuildSheet.from_parts(ctx.run.parts)
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
	for synergy_id in sheet.synergies:
		if not synergy_id in _live:
			_on_synergy_live(synergy_id)
	_live = sheet.synergies.duplicate()
	_redraw()


func shell_fitted() -> bool:
	return ctx != null and ctx.tuning != null and ctx.tuning.option("hotwire_shell") == "on"


# The resolved air-control factor Riveted Shell contributes; 1.0 when not fitted. The one place
# an inversion flips it.
func shell_air_factor() -> float:
	return SHELL_AIR_FACTOR if shell_fitted() else 1.0


func shell_scrap_per_hp() -> float:
	return SHELL_SCRAP_PER_HP if shell_fitted() else RunState.SCRAP_PER_HP


# After sheet.apply has cleared and refilled the mods, so the penalty survives every recompute.
func _apply_shell() -> void:
	ctx.run.scrap_per_hp = shell_scrap_per_hp()
	if shell_fitted():
		ctx.tuning.set_mod("air_control", ctx.tuning.mod("air_control") * shell_air_factor())


func _redraw() -> void:
	accretion.show_build(ctx.run.mass, ctx.run.parts, sheet.synergies, ctx.run.heft_class())


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
			"hint": card["hint"], "clue": card["clue"], "text": card["text"]})


# Every new activation goes to the codex, which owns the once-per-attempt rule: after
# a retry that took the synergy back, reactivating it discovers it again, pays again
# and keeps it in the run log (CONTRACTS, Codex; DESIGN-NOTES I3).
func _on_synergy_live(synergy_id: String) -> void:
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
	var row := Elements.ROWS.get(key, {}) as Dictionary
	if row.has("found"):
		_note_found("element:" + key, row["found"])


func _class_id() -> String:
	return ctx.run.class_id()




func _on_part_gained(part_id: String, _source: String) -> void:
	recompute()
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
		ctx.run.set_max_hp(BuildSheet.BASE_MAX_HP + sheet.max_hp_bonus)
	_redraw()


func _on_run_started(_class_id_value: String) -> void:
	_live = []
	_mass_hp = 0.0
	_discovered.clear()
	_found.clear()
	_refresh_seams()
	bus.clear()
	effects.reset_run()
	clock.begin_run(_next_modifiers)
	if ctx.codex != null:
		clock.load_best(ctx.codex.storage_dir.path_join("runs.ndjson"), Engine.physics_ticks_per_second)
	ctx.run.set_meta("run_tags", clock.tags())
	_sync_scrap_flags()
	_apply_route()
	shop.reset_run()
	lanes.reset()
	recompute()


func _on_stage_entered(stage: int, _retry: bool) -> void:
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
	loot_rng.seed = LOOT_SEED + stage * 7919 + ctx.run.retries
	_speed_tier = ctx.player.speed_tier()
	scrap.lay_out(ctx.terrain, ctx.terrain.scrap_lines(stage), ctx.flow.stage_def()["scrap_density"], ctx.rng)
	fabricators.lay_out(ctx.terrain, stage, _class_id(), ctx.rng, ctx.run.parts)
	recompute()


# The arena is not a stage (DESIGN-NOTES spine call 34): the scrap field, the
# fabricators, any open gates and every surface an element made on the stage go now.
# The build itself, its synergies and its elements keep working in the fight. An arena
# retry has just restored the run silently, so the build and the ball's shell are
# recomputed from the restored parts and mass.
func _on_stage_content_cleared(_reason: String) -> void:
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
	var amount := int(round(scrap_value * sheet.kill_scrap)) if not scrapless() else 0
	if kind == "warden":
		scrap.drop_line(at, _heading(), WARDEN_LINE, amount, ctx.rng)
	else:
		scrap.drop(at, amount, ctx.rng)
	# A vault pays out a rare part and a bonus core (DEMO-SPEC engagement tiers).
	if kind == "vault":
		var picks: Array = Parts.roll(ctx.rng, Parts.SOURCE_RARITIES["vault"], _class_id(), ctx.run.parts, 1)
		if not picks.is_empty() and not scrapless():
			ctx.run.add_part(picks[0], "vault")
		ctx.run.add_core("vault", at)


# The gates open when flow enters its gates state, never on the charge reading: a
# sealed beacon's shown charge can reach 1.0 a tick before the Warden's kill is
# recorded, and gates opened then would be ignored by flow and soft-lock the stage.
# Stage 2's pair carries the pattern guarantee (Parts.roll_gate).
func _on_flow_changed(state: String) -> void:
	if state != "gates" or gates.is_open():
		return
	var rarities := Parts.gate_rarities(ctx.run.gate_tier_bonus())
	var picks: Array = Parts.roll_gate(ctx.rng, rarities, _class_id(), ctx.run.parts, GATE_CHOICES, ctx.flow.stage(), _offered)
	for part_id in picks:
		_offered[part_id] = _offered.get(part_id, 0) + 1
	ctx.events.reward_offered.emit(gates.open(picks, ctx.player.ball_position(), _heading(), ctx.run.parts))


# Scrapless still rolls through a gate to launch (the handshake needs reward_chosen);
# it just takes nothing.
func _on_gate_chosen(part_id: String) -> void:
	if not scrapless():
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
	if not sheet.elements_for("shot").is_empty():
		_shots.append(to)
	for rule_id in sheet.rules:
		if Synergies.TAG_RULES[rule_id].get("fires_on", "") == "shot":
			_note_found("rule:" + rule_id, Synergies.TAG_RULES[rule_id]["found"])


# The ball's own line when it is moving, else where the camera looks.
func _heading() -> Vector3:
	var flat: Vector3 = ctx.player.planar_velocity()
	if flat.length() > 3.0:
		return flat.normalized()
	return -ctx.camera.yaw_basis().z


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
		seed(route_seed)
	var start := float(ctx.tuning.base("start_mass"))
	if start > 0.0:
		ctx.run.grant_start_mass(start)


# A hit removed scrap: SPILL_CLUSTERS at most, ahead of or beside the outgoing line.
# Recovery runs only where the scrap field does (stage play). The boss arena clears the
# field and never steps it, so a cluster dropped there could never be collected: the
# spill is destroyed instead and logged, so the hit reads as what it cost.
func _on_armor_hit(_removed: float, spill: int, _source: String) -> void:
	if not ctx.flow.in_stage():
		ctx.run.metrics["destroyed"] += spill
		ctx.run.metrics["arena_destroyed"] += spill
		_redraw()
		return
	scrap.drop_recovery(ctx.terrain, ctx.player.ball_position(), _heading(), spill, RunState.SPILL_CLUSTERS, ctx.rng)
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
	run.wear_step(delta, planar.length(), ctx.tuning.f("cruise"), grounded and not get_tree().paused and not shop.clock_paused())
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
	_rod_budget = minf(ROD_PER_SECOND, _rod_budget + ROD_PER_SECOND * delta)
	_shrapnel_budget = minf(SHRAPNEL_PER_SECOND, _shrapnel_budget + SHRAPNEL_PER_SECOND * delta)
	scrap.magnet_scale = sheet.magnet * effects.magnet_boost()
	clock.paused = shop.clock_paused()
	clock.advance(delta, ctx.run.run_time, ctx.flow.in_stage())
	_own_strikes += 1
	if ctx.flow.in_stage():
		if not scrapless():
			for at in scrap.step(ball, speed, delta):
				ctx.run.add_scrap(1, at)
				_post(Triggers.Kind.ON_PICKUP, "scrap", Triggers.DISCRETE_PROC, at)
				if has_transformer("lightning_rod"):
					_lightning_rod(ball)
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
	for fab in fabricators.step(ball, delta, ctx.run.scrap, ctx.run.parts):
		var part_id: String = fab["part_id"]
		if ctx.run.spend_scrap(Fabricators.price(part_id, ctx.run.parts.size())):
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


# ---- Named synergy behaviours ----

func _step_synergies(ball: Vector3, delta: float) -> void:
	for at in _rams:
		field.flash_ring(at, WRECK_RADIUS, Palette.AMBER)
		for enemy in _enemies_near(at, WRECK_RADIUS, 99):
			if enemy.global_position.distance_to(at) > 0.5:
				_synergy_hit(enemy, WRECK_FORCE)
	_rams.clear()
	for at in _kills:
		if _shrapnel_budget < 1.0:
			break
		_shrapnel_budget -= 1.0
		field.shard_burst(at)
		for enemy in _enemies_near(at, SHRAPNEL_RADIUS, SHRAPNEL_TARGETS):
			_synergy_hit(enemy, SHRAPNEL_FORCE)
	_kills.clear()
	for impact in _landings:
		field.flash_ring(ball + Vector3.DOWN * 0.8, GLACIER_RADIUS, ElementField.ICE)
		for enemy in _enemies_near(ball, GLACIER_RADIUS, 99):
			_synergy_hit(enemy, impact * 1.5)
		_frost_ring(ball)
	_landings.clear()
	if has_transformer("tesla_pylon") and (ctx.player.kit.mounted or ctx.player.kit.hooked):
		_tesla_clock -= delta
		if _tesla_clock <= 0.0:
			_tesla_clock = TESLA_EVERY
			for enemy in _enemies_near(ball, TESLA_REACH, TESLA_TARGETS):
				field.zap_line(ball, enemy.global_position)
				_strike(enemy, "arc", TESLA_DAMAGE * sheet.mod("weapon_damage"))
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
				_synergy_hit(enemy, PINWHEEL_FORCE)
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
func _synergy_hit(enemy: Node3D, force: float) -> void:
	_strike(enemy, SYNERGY_KIND, force * SYNERGY_PUNCH * ctx.run.heft())
