extends RefCounted

const Palette := preload("res://src/core/palette.gd")


const NAMES := ["pierce", "bounce", "split", "pull", "heat"]
const BITS := {"pierce": 1, "bounce": 2, "split": 4, "pull": 8, "heat": 16}
const ALL := 31
const MAX_PART_BITS := 2
const MAX_SHOT_BITS := 3

const TABLE := {
	"pierce": {"color": Palette.LEDGER, "sound": "breach_crack",
		"rule": "Passes through the first body it hits and keeps flying"},
	"bounce": {"color": Palette.ARC, "sound": "shell_spring",
		"rule": "Glances off the first wall it meets instead of stopping"},
	"split": {"color": Palette.BRASS, "sound": "scrap_rip",
		"rule": "Breaks into two children on its first hit"},
	"pull": {"color": Palette.SLATE, "sound": "line_zip",
		"rule": "Drags what it hits a step toward the shooter"},
	"heat": {"color": Palette.COPPER, "sound": "wear_sputter",
		"rule": "Leaves what it hits glowing; a second heated hit adds a little damage"},
}

const TAG_BITS := {"kinetic": "pierce", "mass": "pierce", "chain": "bounce", "split": "split",
	"anchor": "pull", "arc": "heat"}

const PAIRS := {
	"pierce+bounce": "Pierces bodies, glances off walls; both apply",
	"pierce+split": "Splits on the first body, and the children keep piercing",
	"pierce+pull": "Pulls each body it passes through, the first hardest",
	"pierce+heat": "Heats each body it passes through",
	"bounce+split": "Splits on the first body; the children still glance off walls",
	"bounce+pull": "A glance off a wall pulls nothing; a body hit pulls toward the shooter",
	"bounce+heat": "Heats on body hits only; a glance off a wall heats nothing",
	"split+pull": "Only the first hit pulls; the children do not pull again",
	"split+heat": "The first hit and each child's hit heat",
	"pull+heat": "Pulls, then heats; the glow follows the body",
}


static func bit(name: String) -> int:
	return int(BITS.get(name, 0))


static func has(mask: int, b: int) -> bool:
	return (mask & b) > 0


static func union(a: int, b: int) -> int:
	return a | b


static func without(a: int, b: int) -> int:
	return a & ~b


static func count(mask: int) -> int:
	var n := 0
	for name in NAMES:
		if has(mask, BITS[name]):
			n += 1
	return n


static func names(mask: int) -> Array:
	return NAMES.filter(func(name): return has(mask, BITS[name]))


static func part_mask(tags: Array, explicit = null) -> int:
	var wanted := 0
	if explicit is Array:
		for name in explicit:
			wanted = union(wanted, bit(String(name)))
	else:
		for tag in tags:
			wanted = union(wanted, bit(String(TAG_BITS.get(tag, ""))))
	var out := 0
	for name in NAMES:
		if has(wanted, BITS[name]) and count(out) < MAX_PART_BITS:
			out = union(out, BITS[name])
	return out


static func shot(part_masks: Array) -> Dictionary:
	var bits := 0
	var dropped := 0
	for part in part_masks:
		for name in NAMES:
			var b: int = BITS[name]
			if not has(int(part), b) or has(bits, b):
				continue
			if count(bits) < MAX_SHOT_BITS:
				bits = union(bits, b)
			else:
				dropped = union(dropped, b)
	return {"bits": bits, "dropped": without(dropped, bits)}


static func live(mask: int, live_mask: int) -> int:
	return mask & live_mask


static func tells(mask: int) -> Array:
	var out: Array = []
	for name in names(mask):
		var row: Dictionary = TABLE[name]
		out.append({"bit": name, "color": row["color"], "sound": row["sound"], "rule": row["rule"]})
	return out


static func pair_key(a: String, b: String) -> String:
	return a + "+" + b if NAMES.find(a) < NAMES.find(b) else b + "+" + a


static func pair_outcome(a: String, b: String, pairs: Dictionary = PAIRS) -> String:
	return String(pairs.get(pair_key(a, b), ""))


static func unspecified_pairs(mask: int, pairs: Dictionary = PAIRS) -> int:
	var held := names(mask)
	var n := 0
	for i in held.size():
		for j in range(i + 1, held.size()):
			if pair_outcome(held[i], held[j], pairs).strip_edges().is_empty():
				n += 1
	return n


static func table_problems(table: Dictionary) -> Array:
	var out: Array = []
	for name in NAMES:
		var row: Dictionary = table.get(name, {})
		for key in ["color", "sound", "rule"]:
			if not row.has(key):
				out.append("%s has no %s" % [name, key])
	return out
