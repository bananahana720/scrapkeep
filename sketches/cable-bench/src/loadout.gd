extends RefCounted

const Tuning := preload("res://src/tuning.gd")
const Rules := preload("res://src/rules.gd")

# Buffs are stack counts in one table, and every effect is recomputed from the
# accepted ball-lab defaults each time a stack lands. Nothing accumulates by
# repeated mutation, so a buff can never drift the tuned feel somewhere odd.
const BUFFS := [
	{"key": "cruise", "label": "Overdrive coil", "effect": "+10% cruise"},
	{"key": "jump", "label": "Spring shank", "effect": "+1 m/s jump"},
	{"key": "boost", "label": "Charge cell", "effect": "-15% boost cooldown"},
	{"key": "impact", "label": "Hardened shell", "effect": "+25% impact damage"},
	{"key": "hp", "label": "Plate stack", "effect": "+20 max HP"},
]

const HP_PER_STACK := 20.0

var damage_multiplier := 1.0

var _tuning
var _state
var _run
var _stacks := {}
var _base := {}


func bind(tuning, state, run) -> void:
	_tuning = tuning
	_state = state
	_run = run
	for spec in Tuning.SPECS:
		_base[spec["key"]] = spec["value"]
	for buff in BUFFS:
		_stacks[buff["key"]] = 0
	_recompute()


func grant(key: String) -> Dictionary:
	_stacks[key] = int(_stacks[key]) + 1
	if key == "hp":
		_run.hp = minf(_run.hp_max + HP_PER_STACK, _run.hp + HP_PER_STACK)
	_recompute()
	return spec_of(key)


func grant_random(rng: RandomNumberGenerator) -> Dictionary:
	return grant(BUFFS[rng.randi_range(0, BUFFS.size() - 1)]["key"])


func stacks(key: String) -> int:
	return int(_stacks.get(key, 0))


func total_stacks() -> int:
	var total := 0
	for key in _stacks:
		total += int(_stacks[key])
	return total


func spec_of(key: String) -> Dictionary:
	for buff in BUFFS:
		if buff["key"] == key:
			return buff
	return {}


func held_lines() -> Array:
	var lines := []
	for buff in BUFFS:
		var n: int = int(_stacks[buff["key"]])
		if n > 0:
			lines.append("%s x%d  (%s)" % [buff["label"], n, buff["effect"]])
	return lines


func summary() -> String:
	var lines := held_lines()
	return "none" if lines.is_empty() else ", ".join(lines)


func _recompute() -> void:
	_tuning.set_value("cruise", float(_base["cruise"]) * pow(1.10, stacks("cruise")))
	_tuning.set_value("jump_speed", float(_base["jump_speed"]) + stacks("jump"))
	_state.boost_cooldown_scale = pow(0.85, stacks("boost"))
	damage_multiplier = 1.0 + 0.25 * stacks("impact")
	_run.hp_max = Rules.PLAYER_HP + HP_PER_STACK * stacks("hp")
	_run.hp = minf(_run.hp, _run.hp_max)
