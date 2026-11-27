extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const HullMark := preload("res://src/world/hull_mark.gd")


const POWER_CONTRACT := {
	"weapon": Weapons.RAPID_LASER, "distance_m": 5.0, "neighbours": 3,
	"neighbour_spacing_m": 3.0, "ticks_per_second": 90,
}

var parts: Array = []
var mods := {}
var cooldown_scale := 1.0
var patterns := {}
var transformers: Array = []
var triggers := {}
var magnet := 1.0
var kill_scrap := 1.0
var max_hp_bonus := 0.0
var dials := {}
var synergies: Array = []
var punch := 0.0
var panel_punch := 0.0
var adds := {}


static func from_parts(held: Array) -> RefCounted:
	var sheet: RefCounted = load("res://src/build/build_sheet.gd").new()
	sheet.parts = held.duplicate()
	var counted := {}
	for part_id in held:
		var d: Resource = Parts.def(part_id)
		if d == null:
			continue
		if not Synergies.evolution_live(part_id, held):
			continue
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
	var bolt_power: float = pattern.damage / base.damage * mod("weapon_damage") * rate * pattern.volley_size() * chain
	var vent_power := 0.0
	if "gatling_heart" in ids:
		var grow: Dictionary = Parts.micro_mutation("gatling_heart")
		if float(POWER_CONTRACT["distance_m"]) <= float(grow.get("radius_m", 5.5)):
			var every := float(maxi(1, int(grow.get("every_shots", 12))))
			vent_power = (rate / every) * (float(grow.get("damage_base", 18.0)) * mod("weapon_damage") / base.damage)
	return bolt_power + vent_power
