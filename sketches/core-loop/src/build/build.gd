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
# the beacon offer two parts you roll through; won events award milestone parts. Every
# held part folds into one derived sheet (build_sheet.gd) that sets the tuning mods,
# the pattern levels combat reads, and the element triggers that feed the element x
# material table (elements.gd, resolved by element_field.gd).
#
# Other modules reach this node through the context: ctx.get_meta("build") until the
# spine adds a ctx.build field (see SEAMS.md). Its public API is the block of methods
# under "Build API" below.

const GATE_CHOICES := 2
# The dash leaves frost this long, and drops a visible puff every few ticks of it.
const FROST_TRAIL := 0.7
const PUFF_EVERY := 3
# Arc Coil: the slam's arc reaches this far at full strength and hits this hard,
# before the weapon damage multiplier.
const ARC_RADIUS := 8.0
const ARC_DAMAGE := 18.0
# Thermal Shock refreezes a pad this wide around the slam.
const REFREEZE_RING := 4.0

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
	gates.chosen.connect(_on_gate_chosen)
	fabricators = Fabricators.new()
	fabricators.name = "Fabricators"
	ctx.root.add_child(fabricators)
	field = ElementField.new()
	field.name = "ElementField"
	ctx.root.add_child(field)
	field.setup(ctx)
	accretion = Accretion.new()
	ctx.player.roll_node().add_child(accretion)
	accretion.setup()
	ctx.set_meta("build", self)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.beacon_charge_changed.connect(_on_beacon_charge)
	ctx.events.part_gained.connect(func(_id: String, _source: String): recompute())
	ctx.events.scrap_collected.connect(func(_amount: int, _at: Vector3, _total: int): _redraw())
	ctx.events.milestone_won.connect(_on_milestone_won)
	ctx.events.dashed.connect(_on_dashed)
	ctx.events.slammed.connect(_on_slammed)
	ctx.events.run_started.connect(func(_class_id: String): recompute())


# ---- Build API (for combat, presentation and world; see SEAMS.md) ----

func pattern_level(pattern_id: String) -> int:
	return sheet.pattern_level(pattern_id)


func patterns() -> Dictionary:
	return sheet.patterns.duplicate()


func has_transformer(transformer_id: String) -> bool:
	return transformer_id in sheet.transformers


func weapon_mod(key: String) -> float:
	return sheet.mod(key)


func active_synergies() -> Array:
	return sheet.synergies.duplicate()


func power() -> float:
	return sheet.power()


func part_info(part_id: String) -> Dictionary:
	var d: Resource = Parts.def(part_id)
	if d == null:
		return {"id": part_id, "name": Parts.display_name(part_id)}
	return {"id": d.id, "name": d.display_name, "text": d.text, "rarity": d.rarity, "tier": d.tier, "family": d.family}


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


# ---- Derivation ----

# Folds run.parts into the sheet and pushes it out: tuning mods, health ceiling,
# magnet, shatter damage and the ball's hardware. Idempotent, so a retry, a new part
# and a stage entry all call the same thing.
func recompute() -> void:
	sheet = BuildSheet.from_parts(ctx.run.parts)
	sheet.apply(ctx.tuning, ctx.run)
	scrap.magnet_scale = sheet.magnet
	field.shatter_scale = sheet.dial("shatter_damage")
	_redraw()


func _redraw() -> void:
	accretion.show_build(ctx.run.scrap, ctx.run.parts, sheet.synergies)


func _class_id() -> String:
	return ctx.run.class_id()


func _on_stage_entered(stage: int, _retry: bool) -> void:
	gates.close()
	field.clear()
	_trail = 0.0
	_slams.clear()
	scrap.lay_out(ctx.terrain, ctx.terrain.scrap_lines(stage), ctx.flow.stage_def()["scrap_density"], ctx.rng)
	fabricators.lay_out(ctx.terrain, stage, _class_id(), ctx.rng, ctx.run.parts)
	recompute()


func _on_enemy_killed(_kind: String, at: Vector3, scrap_value: int) -> void:
	scrap.drop(at, int(round(scrap_value * sheet.kill_scrap)), ctx.rng)


func _on_beacon_charge(fraction: float) -> void:
	if fraction < 1.0 or gates.is_open():
		return
	var picks: Array = Parts.roll(ctx.rng, ctx.run.stage, _class_id(), ctx.run.parts, GATE_CHOICES)
	ctx.events.reward_offered.emit(gates.open(picks, ctx.player.ball_position(), _heading(), ctx.run.parts))


func _on_gate_chosen(part_id: String) -> void:
	ctx.run.add_part(part_id, "gate")
	ctx.events.reward_chosen.emit(part_id)


# A won event pays out at once, so the stinger and the new part land as one beat.
func _on_milestone_won(event_id: String) -> void:
	ctx.run.add_part(Parts.milestone_for(event_id, ctx.run.parts), "milestone")


# The bus reports the dash and the slam; the frost and arc they carry resolve in this
# module's own physics step, once each (TADR-008: a signal applies nothing).
func _on_dashed(_direction: Vector3) -> void:
	if not sheet.elements_for("dash").is_empty():
		_trail = FROST_TRAIL
		_trail_ticks = 0


func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if not sheet.elements_for("slam").is_empty():
		_slams.append({"at": at, "strength": clampf(strength, 0.3, 1.6)})


# The ball's own line when it is moving, else where the camera looks.
func _heading() -> Vector3:
	var flat: Vector3 = ctx.player.planar_velocity()
	if flat.length() > 3.0:
		return flat.normalized()
	return -ctx.camera.yaw_basis().z


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.flow.in_play():
		return
	var ball: Vector3 = ctx.player.ball_position()
	var speed: float = ctx.player.planar_velocity().length()
	for at in scrap.step(ball, speed, delta):
		ctx.run.add_scrap(1, at)
	_step_fabricators(ball, delta)
	if gates.step(ball, _heading()):
		ctx.events.reward_offered.emit(gates.offers)
	_step_elements(ball, delta)
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
	for slam in _slams:
		_resolve_slam(slam["at"], slam["strength"])
	_slams.clear()


func _resolve_slam(at: Vector3, strength: float) -> void:
	for element in sheet.elements_for("slam"):
		if element == "arc":
			var reach := ARC_RADIUS * (0.6 + 0.4 * strength)
			field.flash_ring(at + Vector3.DOWN * 0.8, reach, Palette.ARC)
			if ctx.spawner != null:
				var damage: float = ARC_DAMAGE * strength * sheet.mod("weapon_damage")
				for enemy in get_tree().get_nodes_in_group("enemy"):
					if (enemy as Node3D).global_position.distance_to(at) <= reach:
						ctx.spawner.strike(enemy, "arc", damage)
			field.apply("arc", at, "slam")
		elif element == "frost":
			field.apply("frost", at, "slam")
			for i in 6:
				var angle := TAU * float(i) / 6.0
				field.apply("frost", at + Vector3(cos(angle), 0.0, sin(angle)) * REFREEZE_RING, "slam")
		else:
			field.apply(element, at, "slam")
