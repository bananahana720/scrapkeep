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
# World (D) may also grant the event's core; build skips its own grant when an event
# core arrived within this many seconds of the milestone.
const EVENT_CORE_WINDOW := 0.1
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
# Milestone core grants waiting a moment for world's own grant, and when world's last
# event core arrived (in run seconds).
var _pending_event_cores: Array[Dictionary] = []
var _last_event_core := -99.0


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
	ctx.build = self
	ctx.set_meta("build", self)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.flow_changed.connect(_on_flow_changed)
	ctx.events.part_gained.connect(func(_id: String, _source: String): recompute())
	ctx.events.scrap_collected.connect(func(_amount: int, _at: Vector3, _total: int): _redraw())
	ctx.events.milestone_won.connect(_on_milestone_won)
	ctx.events.dashed.connect(_on_dashed)
	ctx.events.slammed.connect(_on_slammed)
	ctx.events.landed.connect(_on_landed)
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	ctx.events.shot_fired.connect(_on_shot_fired)
	ctx.events.run_started.connect(_on_run_started)
	ctx.events.scrap_lost.connect(_on_scrap_lost)
	ctx.events.core_gained.connect(_on_core_gained)
	ctx.events.heft_class_changed.connect(func(_c: int, _h: float): _redraw())


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
	return Synergies.declarations(func(part_id: String) -> String: return Parts.display_name(part_id))


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
		return "* ingredient: %s *" % (Synergies.ROWS[ingredient]["name"] if is_known(ingredient) else "???")
	return ""


# ---- Derivation ----

# Folds run.parts into the sheet and pushes it out: tuning mods, health ceiling,
# magnet, shatter damage and the ball's hardware. Idempotent, so a retry, a new part
# and a stage entry all call the same thing. A named synergy that comes live here for
# the first time this run is a discovery.
func recompute() -> void:
	sheet = BuildSheet.from_parts(ctx.run.parts)
	sheet.apply(ctx.tuning, ctx.run)
	scrap.magnet_scale = sheet.magnet
	field.shatter_scale = sheet.dial("shatter_damage")
	for synergy_id in sheet.synergies:
		if not synergy_id in _live:
			_on_synergy_live(synergy_id)
	_live = sheet.synergies.duplicate()
	_redraw()


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


func _on_synergy_live(synergy_id: String) -> void:
	if _discovered.has(synergy_id):
		return
	_discovered[synergy_id] = true
	var codex = _codex()
	if codex != null:
		if not _declared:
			_declare()
		codex.mark_discovered(synergy_id, ctx.player.ball_position(), PARTICIPANTS)


# An unnamed interaction, logged once per run under its key.
func _note_found(key: String, text: String) -> void:
	if _found.has(key):
		return
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




func _on_run_started(_class_id_value: String) -> void:
	_live = []
	_discovered.clear()
	_found.clear()
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
	_pending_event_cores.clear()
	_pinwheel_cut.clear()
	_rod_budget = ROD_PER_SECOND
	_shrapnel_budget = SHRAPNEL_PER_SECOND
	scrap.lay_out(ctx.terrain, ctx.terrain.scrap_lines(stage), ctx.flow.stage_def()["scrap_density"], ctx.rng)
	fabricators.lay_out(ctx.terrain, stage, _class_id(), ctx.rng, ctx.run.parts)
	recompute()


# The arena is not a stage (DESIGN-NOTES spine call 34): the scrap field, the
# fabricators, any open gates and every surface an element made on the stage go now,
# with the stage's waiting event cores. The build itself, its synergies and its
# elements keep working in the fight.
func _on_stage_content_cleared(_reason: String) -> void:
	scrap.clear()
	fabricators.clear()
	gates.close()
	field.clear()
	_trail = 0.0
	_pending_event_cores.clear()


func _on_enemy_killed(kind: String, at: Vector3, scrap_value: int) -> void:
	if has_transformer("shrapnel_bloom"):
		_kills.append(at)
	if not ctx.flow.in_stage():
		return
	var amount := int(round(scrap_value * sheet.kill_scrap))
	if kind == "warden":
		scrap.drop_line(at, _heading(), WARDEN_LINE, amount, ctx.rng)
	else:
		scrap.drop(at, amount, ctx.rng)
	# A vault pays out a rare part and a bonus core (DEMO-SPEC engagement tiers).
	if kind == "vault":
		var picks: Array = Parts.roll(ctx.rng, Parts.SOURCE_RARITIES["vault"], _class_id(), ctx.run.parts, 1)
		if not picks.is_empty():
			ctx.run.add_part(picks[0], "vault")
		ctx.run.add_core("vault", at)


# The gates open when flow enters its gates state, never on the charge reading: a
# sealed beacon's shown charge can reach 1.0 a tick before the Warden's kill is
# recorded, and gates opened then would be ignored by flow and soft-lock the stage.
func _on_flow_changed(state: String) -> void:
	if state != "gates" or gates.is_open():
		return
	var rarities := Parts.gate_rarities(ctx.run.gate_tier_bonus())
	var picks: Array = Parts.roll(ctx.rng, rarities, _class_id(), ctx.run.parts, GATE_CHOICES)
	ctx.events.reward_offered.emit(gates.open(picks, ctx.player.ball_position(), _heading(), ctx.run.parts))


func _on_gate_chosen(part_id: String) -> void:
	ctx.run.add_part(part_id, "gate")
	ctx.events.reward_chosen.emit(part_id)


# A won event pays out at once, so the stinger and the new part land as one beat. Its
# bonus core waits a moment: if world grants the event's core itself, build does not
# grant a second one.
func _on_milestone_won(event_id: String) -> void:
	ctx.run.add_part(Parts.milestone_for(event_id, ctx.run.parts), "milestone")
	_pending_event_cores.append({"at": ctx.player.ball_position(), "since": ctx.run.run_time})


func _on_core_gained(source: String, _at: Vector3, _count: int) -> void:
	if source == "event":
		_last_event_core = ctx.run.run_time


func _step_event_cores() -> void:
	var now: float = ctx.run.run_time
	var i := _pending_event_cores.size() - 1
	while i >= 0:
		var pending: Dictionary = _pending_event_cores[i]
		if absf(_last_event_core - pending["since"]) <= EVENT_CORE_WINDOW:
			_pending_event_cores.remove_at(i)
		elif now - pending["since"] > EVENT_CORE_WINDOW:
			_pending_event_cores.remove_at(i)
			ctx.run.add_core("event", pending["at"])
		i -= 1


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
	if ctx.flow.in_stage():
		_step_event_cores()
		for at in scrap.step(ball, speed, delta):
			ctx.run.add_scrap(1, at)
			if has_transformer("lightning_rod"):
				_lightning_rod(ball)
		_step_fabricators(ball, delta)
		if gates.step(ball, _heading()):
			ctx.events.reward_offered.emit(gates.offers)
	_step_elements(ball, delta)
	_step_synergies(ball, delta)
	field.step(delta)


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
				_strike(enemy, "slam", WRECK_FORCE)
	_rams.clear()
	for at in _kills:
		if _shrapnel_budget < 1.0:
			break
		_shrapnel_budget -= 1.0
		field.shard_burst(at)
		for enemy in _enemies_near(at, SHRAPNEL_RADIUS, SHRAPNEL_TARGETS):
			_strike(enemy, "slam", SHRAPNEL_FORCE)
	_kills.clear()
	for impact in _landings:
		field.flash_ring(ball + Vector3.DOWN * 0.8, GLACIER_RADIUS, ElementField.ICE)
		for enemy in _enemies_near(ball, GLACIER_RADIUS, 99):
			_strike(enemy, "slam", impact * 1.5)
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
				_strike(enemy, "slam", PINWHEEL_FORCE)
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
