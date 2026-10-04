class_name BossContract
extends RefCounted

# The duck-typed surface a boss answers, written down once. Nothing here is enforced at
# runtime; tests/boss_contract_test.gd checks a candidate against it. Two surfaces:
#
# TARGET: what combat, the plate, the ring, audio and the run log call on the boss's
#   body (an enemy node). combat.resolve() sends any enemy whose fight() is "posture"
#   through judge_hit() before the plating rule.
# MODULE: what flow and others call on the boss module (ctx.boss).
#
# Each row is [name, argument count, declared return type]. TYPE_NIL means no return value.
# The type is checked from the method's declaration when it has one, and by the test
# against a live call.

const TARGET := [
	# The posture fight (warden.gd, "The posture fight").
	["fight", 0, TYPE_STRING],
	["posture", 0, TYPE_FLOAT],
	["staggered", 0, TYPE_BOOL],
	["stagger_left", 0, TYPE_FLOAT],
	["chunks_left", 0, TYPE_INT],
	["glances", 0, TYPE_INT],
	["chunk_cracked", 0, TYPE_BOOL],
	["judge_hit", 4, TYPE_DICTIONARY],
	["take_damage", 1, TYPE_FLOAT],
	["is_dead", 0, TYPE_BOOL],
	# The enemy protocol combat reads (combat.gd resolve and strike).
	["plating_for", 2, TYPE_FLOAT],
	["hit_mult", 2, TYPE_FLOAT],
	["contact_part", 2, TYPE_STRING],
	["on_struck", 3, TYPE_NIL],
]

const MODULE := [
	["enter_arena", 1, TYPE_NIL],
	["exit_arena", 0, TYPE_NIL],
	["active", 0, TYPE_BOOL],
	["ground_height_at", 1, TYPE_FLOAT],
	["music_state", 0, TYPE_DICTIONARY],
	["objective_text", 0, TYPE_STRING],
]


# The missing or mistyped names in obj against a surface (TARGET or MODULE). Empty means
# it conforms. A wrong argument count or a declared return type that differs reports the
# name with the reason.
static func conforms(obj, surface: Array) -> Array:
	var missing: Array = []
	if obj == null:
		for row in surface:
			missing.append(row[0])
		return missing
	var declared := {}
	for m in obj.get_method_list():
		declared[m["name"]] = m
	for row in surface:
		var method_name: String = row[0]
		if not obj.has_method(method_name) or not declared.has(method_name):
			missing.append(method_name)
			continue
		var info: Dictionary = declared[method_name]
		if info["args"].size() != int(row[1]):
			missing.append("%s (takes %d arguments, contract says %d)" % [method_name, info["args"].size(), int(row[1])])
			continue
		var ret_type: int = info["return"]["type"]
		if int(row[2]) != TYPE_NIL and ret_type != TYPE_NIL and ret_type != int(row[2]):
			missing.append("%s (returns type %d, contract says %d)" % [method_name, ret_type, int(row[2])])
	return missing


static func describe() -> String:
	var lines: PackedStringArray = []
	lines.append("TARGET")
	for row in TARGET:
		lines.append("  %s(%d) -> %s" % [row[0], row[1], type_string(row[2]) if row[2] != TYPE_NIL else "void"])
	lines.append("MODULE")
	for row in MODULE:
		lines.append("  %s(%d) -> %s" % [row[0], row[1], type_string(row[2]) if row[2] != TYPE_NIL else "void"])
	return "\n".join(lines)
