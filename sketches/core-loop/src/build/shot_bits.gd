extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# Shot bits (SI4, W13-INTEGRATION-3.md; comps/isaac/items-and-synergies.md:89). A closed
# set of five behaviour bits. Each part adds zero to two of them (MAX_PART_BITS), a shot
# carries the OR of its held parts' bits, at most MAX_SHOT_BITS of them, and a child
# bolt copies its parent's set (bolts.gd child()). TADR-008 line 24 declines a general
# framework, so this is one closed table: a new bit is a row here and a code change in
# combat, never a script.
#
# A set is an int mask. Read it with set operations only (has, union, without, count);
# never compare two sets with == or !=, so a wider set can never break a comparison.
#
# TABLE is the one record per bit: the colour the bolt's tell draws, the sound its hit
# plays and the rule it adds. Sight and sound read the same row (tells()), so they
# cannot drift apart. Colours are palette constants and never HAZARD, which only
# telegraphs own (bolts.gd). Sounds are sfx_bank.gd recipe ids.

const NAMES := ["pierce", "bounce", "split", "pull", "heat"]
const BITS := {"pierce": 1, "bounce": 2, "split": 4, "pull": 8, "heat": 16}
const ALL := 31
const MAX_PART_BITS := 2
# Bits past the third are dropped in held order (the earliest held part wins) and
# reported, so the shot stays readable (BIBLE.md:552; the comps note's unbounded stack
# is what this refuses).
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

# Which bit a part's tag gives (a part carries one or two tags, so at most two bits).
# Tags not listed (frost, spiral, speed) give none.
const TAG_BITS := {"kinetic": "pierce", "mass": "pierce", "chain": "bounce", "split": "split",
	"anchor": "pull", "arc": "heat"}

# Every pair of distinct bits, by pair_key(), and what the two do together.
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


# The bits of a that are not in b.
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


# A part's bits: the explicit list a row names (null when it names none), else its
# tags through TAG_BITS; at most MAX_PART_BITS, in table order.
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


# A shot from its held parts' masks, in held order: the OR, capped at MAX_SHOT_BITS.
# Returns {"bits": the shot's set, "dropped": bits held but past the cap}.
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


# The bits of a set the live game honours: the tuning knob shot_bits_live is that mask
# (ABILITY-MUTATIONS.md B4, rolled out a pair at a time).
static func live(mask: int, live_mask: int) -> int:
	return mask & live_mask


# One tell per set bit, read off its single TABLE row: colour, sound and rule together.
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


# Pairs of distinct bits in the set with no declared outcome.
static func unspecified_pairs(mask: int, pairs: Dictionary = PAIRS) -> int:
	var held := names(mask)
	var n := 0
	for i in held.size():
		for j in range(i + 1, held.size()):
			if pair_outcome(held[i], held[j], pairs).strip_edges().is_empty():
				n += 1
	return n


# Rows missing a colour, a sound or a rule, one line each; [] is clean.
static func table_problems(table: Dictionary) -> Array:
	var out: Array = []
	for name in NAMES:
		var row: Dictionary = table.get(name, {})
		for key in ["color", "sound", "rule"]:
			if not row.has(key):
				out.append("%s has no %s" % [name, key])
	return out
