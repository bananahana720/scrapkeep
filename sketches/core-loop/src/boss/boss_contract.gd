class_name BossContract
extends RefCounted

const TARGET := [
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
	["plating_for", 2, TYPE_FLOAT],
	["hit_mult", 2, TYPE_FLOAT],
	["contact_part", 2, TYPE_STRING],
	["on_struck", 3, TYPE_NIL],
	["knock", 2, TYPE_NIL],
	["flash", 0, TYPE_NIL],
	["set_tint", 1, TYPE_NIL],
	["plating_now", 0, TYPE_FLOAT],
]

const TARGET_PROPERTIES := [
	["plating", TYPE_FLOAT],
	["hp", TYPE_FLOAT],
	["max_hp", TYPE_FLOAT],
	["radius", TYPE_FLOAT],
	["half_height", TYPE_FLOAT],
	["kind", TYPE_STRING],
]

const MODULE := [
	["enter_arena", 1, TYPE_NIL],
	["exit_arena", 0, TYPE_NIL],
	["active", 0, TYPE_BOOL],
	["ground_height_at", 1, TYPE_FLOAT],
	["music_state", 0, TYPE_DICTIONARY],
	["objective_text", 0, TYPE_STRING],
]


static func conforms(obj: Object, surface: Array) -> Array:
	var missing: Array = []
	var props: Array = TARGET_PROPERTIES if surface == TARGET else []
	if obj == null:
		for row in surface + props:
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
		var most: int = info["args"].size()
		var fewest: int = most - info["default_args"].size()
		if int(row[1]) < fewest or int(row[1]) > most:
			missing.append("%s (takes %d to %d arguments, contract says %d)" % [method_name, fewest, most, int(row[1])])
			continue
		var ret_type: int = info["return"]["type"]
		if int(row[2]) != TYPE_NIL and ret_type != TYPE_NIL and ret_type != int(row[2]):
			missing.append("%s (returns type %d, contract says %d)" % [method_name, ret_type, int(row[2])])
	var have := {}
	for prop in obj.get_property_list():
		have[prop["name"]] = prop["type"]
	for row in props:
		if not have.has(row[0]):
			missing.append(row[0])
		elif int(have[row[0]]) != int(row[1]) and int(have[row[0]]) != TYPE_NIL:
			missing.append("%s (property type %d, contract says %d)" % [row[0], have[row[0]], int(row[1])])
	return missing


static func describe() -> String:
	var lines: PackedStringArray = []
	lines.append("TARGET")
	for row in TARGET:
		lines.append("  %s(%d) -> %s" % [row[0], row[1], type_string(row[2]) if row[2] != TYPE_NIL else "void"])
	for row in TARGET_PROPERTIES:
		lines.append("  property %s: %s" % [row[0], type_string(row[1])])
	lines.append("MODULE")
	for row in MODULE:
		lines.append("  %s(%d) -> %s" % [row[0], row[1], type_string(row[2]) if row[2] != TYPE_NIL else "void"])
	return "\n".join(lines)
