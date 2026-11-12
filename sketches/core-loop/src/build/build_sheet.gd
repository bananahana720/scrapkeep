extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const HullMark := preload("res://src/world/hull_mark.gd")

# The derived build: every held part and awake maker trick folded into one sheet. It is a
# pure function of the part list, so a retry that restores the list restores the build
# exactly, and applying it twice changes nothing (CONTRACTS: idempotent recompute).
# Movement and weapon multipliers go out through tuning mods; pattern levels,
# transformers and element triggers are read from this sheet through the build API.

# 2026-10-14 SG14-CONTRACT C1: power is rapid-laser DPS / bare rapid-laser DPS.
# Stationary unplated enemy at 5 m; three neighbours, each 3 m right of the last.
# tools/pattern_dps.gd measures actual HP removal at 90 Hz under this contract.
const POWER_CONTRACT := {
	"weapon": Weapons.RAPID_LASER, "distance_m": 5.0, "neighbours": 3,
	"neighbour_spacing_m": 3.0, "ticks_per_second": 90,
}

var parts: Array = []
var mods := {}
var cooldown_scale := 1.0
var patterns := {}
var transformers: Array = []
# Action to the ordered element list it applies: dash, slam, roll_on_water.
var triggers := {}
var magnet := 1.0
var kill_scrap := 1.0
var max_hp_bonus := 0.0
var dials := {}
# The maker tricks awake right now (Synergies.ROWS), in row order.
var synergies: Array = []
# Flat per-hit weapon damage from parts, before the weapon multipliers.
var punch := 0.0
# Flat per-hit damage from Punch Rivet panels (panels.gd fold), which a weapon hit and a ball
# contact add to their punch (combat.gd panel_punch). Also counted in punch above.
var panel_punch := 0.0
# Flat amounts in their own unit, by tuning key (grey panels: area_radius in metres). They
# reach the readers through tuning.add(key).
var adds := {}


static func from_parts(held: Array) -> RefCounted:
	var sheet: RefCounted = load("res://src/build/build_sheet.gd").new()
	sheet.parts = held.duplicate()
	var counted := {}
	for part_id in held:
		var d: Resource = Parts.def(part_id)
		if d == null:
			continue
		# An Evolved part gives nothing while an ingredient is missing.
		if not Synergies.evolution_live(part_id, held):
			continue
		# A linear or capped row stops adding at stack_cap copies (v2 W4 loot); the
		# catalogue's first rows carry no cap, so their copies all count as before. A
		# levelled row (SG15) folds once, at its first copy, with the held level's numbers.
		counted[part_id] = counted.get(part_id, 0) + 1
		if not d.levels.is_empty():
			if counted[part_id] > 1:
				continue
			d = Parts.def_at(part_id, Parts.level_of(part_id, held))
		elif d.stack_rule != "hyperbolic" and d.stack_cap >= 1.0 and counted[part_id] > int(d.stack_cap):
			continue
		sheet._fold(d.mods, d.patterns, d.elements)
		sheet.cooldown_scale *= d.cooldown_scale
		sheet.magnet *= d.magnet
		sheet.kill_scrap *= d.kill_scrap
		sheet.max_hp_bonus += d.max_hp_bonus
		sheet.punch += d.punch
	sheet.synergies = Synergies.active(Parts.maker_counts(held))
	for key in sheet.synergies:
		sheet.fold_row(Synergies.ROWS[key])
	return sheet


# A maker trick's row: its pattern levels, element triggers, transformers and dials.
func fold_row(row: Dictionary) -> void:
	_fold(row.get("mods", {}), row.get("patterns", {}), row.get("elements", {}))
	for t in row.get("transformers", []):
		if not t in transformers:
			transformers.append(t)
	var row_dials: Dictionary = row.get("dials", {})
	for dial in row_dials:
		dials[dial] = dials.get(dial, 1.0) * row_dials[dial]


func _fold(part_mods: Dictionary, part_patterns: Dictionary, part_elements: Dictionary) -> void:
	for knob in part_mods:
		mods[knob] = mods.get(knob, 1.0) * part_mods[knob]
	for pattern in part_patterns:
		patterns[pattern] = patterns.get(pattern, 0) + part_patterns[pattern]
	for action in part_elements:
		var list: Array = triggers.get(action, [])
		var given = part_elements[action]
		for element in (given if given is Array else [given]):
			if not element in list:
				list.append(element)
		triggers[action] = list


# Tuning mods and the health ceiling, from nothing: clear, then set every knob.
func apply(tuning, run) -> void:
	tuning.clear_mods()
	for knob in mods:
		tuning.set_mod(knob, mods[knob])
	for key in adds:
		tuning.set_add(key, adds[key])
	tuning.boost_cooldown_scale = cooldown_scale
	if run != null:
		var ceiling: float = HullMark.ceiling(run, run.base_max_hp() + max_hp_bonus)
		if not is_equal_approx(run.max_hp, ceiling):
			run.set_max_hp(ceiling)


func mod(knob: String) -> float:
	return mods.get(knob, 1.0)


func pattern_level(pattern_id: String) -> int:
	return patterns.get(pattern_id, 0)


func elements_for(action: String) -> Array:
	return triggers.get(action, [])


func dial(key: String) -> float:
	return dials.get(key, 1.0)


func lattice_chain_jumps() -> int:
	if not "storm_lattice" in transformers or pattern_level("cross_split") == 0:
		return 0
	return Synergies.ROWS["storm_lattice"]["patterns"]["chain_arc"]


# All emitted bolts land in POWER_CONTRACT. Each visits at most three neighbours.
# Rapid-laser bolts do not read punch, so it contributes no weapon output here.
func power() -> float:
	var ids: Array = parts.duplicate()
	for _jump in lattice_chain_jumps():
		ids.append("chain_arc")
	var base: Resource = Weapons.base(POWER_CONTRACT["weapon"])
	var pattern: Resource = base.transformed(ids)
	var chain := 1.0
	for jump in mini(pattern.chain_jumps, POWER_CONTRACT["neighbours"]):
		chain += pow(pattern.chain_falloff, jump + 1)
	var rate: float = clampf(pattern.rate * mod("weapon_rate"), Pattern.MIN_RATE, Pattern.MAX_RATE) / base.rate
	return pattern.damage / base.damage * mod("weapon_damage") * rate * pattern.volley_size() * chain
