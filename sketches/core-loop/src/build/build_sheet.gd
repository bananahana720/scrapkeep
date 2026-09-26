extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")

# The derived build: every held part and live synergy folded into one sheet. It is a
# pure function of the part list, so a retry that restores the list restores the build
# exactly, and applying it twice changes nothing (CONTRACTS: idempotent recompute).
# Movement and weapon multipliers go out through tuning mods; pattern levels,
# transformers and element triggers are read from this sheet through the build API.

const BASE_MAX_HP := 100.0
# The class weapon's base per-hit damage before parts, for the output estimate only;
# combat owns the real number.
const BASE_HIT := 14.0

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
var synergies: Array = []
# Unnamed tag rules live right now (Synergies.TAG_RULES).
var rules: Array = []
# Flat per-hit weapon damage from parts, before the weapon multipliers.
var punch := 0.0


static func from_parts(held: Array) -> RefCounted:
	var sheet: RefCounted = load("res://src/build/build_sheet.gd").new()
	sheet.parts = held.duplicate()
	for part_id in held:
		var d: Resource = Parts.def(part_id)
		if d == null:
			continue
		sheet._fold(d.mods, d.patterns, d.elements)
		sheet.cooldown_scale *= d.cooldown_scale
		sheet.magnet *= d.magnet
		sheet.kill_scrap *= d.kill_scrap
		sheet.max_hp_bonus += d.max_hp_bonus
		sheet.punch += d.punch
	var sets := Parts.tag_sets(held)
	sheet.synergies = Synergies.active(sets)
	sheet.rules = Synergies.active_rules(sets)
	var rows: Array = []
	for key in sheet.synergies:
		rows.append(Synergies.ROWS[key])
	for key in sheet.rules:
		rows.append(Synergies.TAG_RULES[key])
	for row in rows:
		sheet._fold(row.get("mods", {}), row.get("patterns", {}), row.get("elements", {}))
		for t in row.get("transformers", []):
			if not t in sheet.transformers:
				sheet.transformers.append(t)
		var dials: Dictionary = row.get("dials", {})
		for dial in dials:
			sheet.dials[dial] = sheet.dials.get(dial, 1.0) * dials[dial]
	return sheet


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
	tuning.boost_cooldown_scale = cooldown_scale
	if run != null and not is_equal_approx(run.max_hp, BASE_MAX_HP + max_hp_bonus):
		run.set_max_hp(BASE_MAX_HP + max_hp_bonus)


func mod(knob: String) -> float:
	return mods.get(knob, 1.0)


func pattern_level(pattern_id: String) -> int:
	return patterns.get(pattern_id, 0)


func elements_for(action: String) -> Array:
	return triggers.get(action, [])


func dial(key: String) -> float:
	return dials.get(key, 1.0)


# An estimate of weapon output against a bare weapon, for the growth curve: damage
# times rate times a shot multiplier per pattern level. It is a model for tuning the
# trajectory, not combat's truth; combat caps what it actually draws.
func power() -> float:
	var shots := (1.0 + 1.0 * pattern_level("cross_split")) \
		* (1.0 + 0.6 * pattern_level("spiral_wave")) \
		* (1.0 + 0.5 * pattern_level("chain_arc"))
	if "storm_lattice" in transformers:
		shots *= 1.5
	var hit := (BASE_HIT + punch) / BASE_HIT
	return hit * mod("weapon_damage") * mod("weapon_rate") * shots
