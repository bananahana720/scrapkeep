extends RefCounted

# Damage families and armour (design-v3/FIELDS-AND-CASTS.md section 6). Every hit's `kind` is
# one of three families (the element table's kinetic, arc and frost), and its source class is
# the second axis: an "ability" is the special source (slots 2 and 3 and the set piece). An
# armour row says which it resists and which it is weak to. Andrew's "Lean, never a wall" (Q5,
# 2026-10-17 22:12:39Z; trimmed to 125% under ruling ek, 2026-11-22): resisted deals about 60%,
# weak about 125%, and nothing is immune, so a strong build always pays. Weak beats resisted on
# the same hit: a kinetic ability on plate is weak, because casts beat plates. Applied in
# combat's caps stage to a hit that beat the plating; the armour stage and its 20% chip are
# unchanged.
#
# Where armour lives is deliberate, not uniform. The Spillway's Flow conducts through water
# (elements.gd arc:water) and through its own wet crews (the "wet" row: weak to arc, resists
# nothing); the Dig's Plate is this table; the Highdraft's Wind is knock-offs, not armour. An
# enemy may name its own class with armour_class() (an elite affix).

const RESISTED := 0.6
const WEAK := 1.25
const KINETIC := "kinetic"
const ARC := "arc"
const FROST := "frost"
const ABILITY := "special"
const RESISTED_READ := "resisted"
const WEAK_READ := "weak"

# Kinds outside kinetic; every other kind (ram, stomp, slam, claw, ledger, shell, the weapons)
# is the concussive hit.
const FAMILY_OF := {"arc": ARC, "electrify": ARC, "frost": FROST}

# resist and weak list families; "ability" in weak means the special source.
const ARMOUR := {
	"plated": {"resist": [KINETIC], "weak": [ARC, "ability"], "word_resisted": "DENT", "word_weak": "ZZAP!"},
	"wet": {"resist": [], "weak": [ARC], "word_resisted": "DENT", "word_weak": "ZZAP!"},
}

# The first plated kinds: the Dig's drill crew breaches with a plated bit. The Spillway's own
# crews work in the spillway and come out soaked (design-v3/SPILLWAY-ROSTER.md); the jolt layer
# stands on rubber boots, so its own mat never jolts it. Elites and later kinds name theirs
# through armour_class().
const ARMOUR_OF := {"drill_crew": "plated", "chaser": "wet", "hooker": "wet", "ramp_flipper": "wet", "boom_tender": "wet"}


static func family(kind: String) -> String:
	return String(FAMILY_OF.get(kind, KINETIC))


static func armour_of(enemy: Object) -> String:
	if enemy == null:
		return ""
	if enemy.has_method("armour_class"):
		var own := String(enemy.armour_class())
		if own != "":
			return own
	var kind = enemy.get("kind")
	return String(ARMOUR_OF.get(String(kind), "")) if kind != null else ""


# "weak", "resisted" or "" for this armour against this hit.
static func verdict(armour: String, kind: String, source: String) -> String:
	if not ARMOUR.has(armour):
		return ""
	var row: Dictionary = ARMOUR[armour]
	var fam := family(kind)
	if fam in row["weak"] or (source == ABILITY and "ability" in row["weak"]):
		return WEAK_READ
	if fam in row["resist"]:
		return RESISTED_READ
	return ""


static func mult(armour: String, kind: String, source: String) -> float:
	match verdict(armour, kind, source):
		WEAK_READ:
			return WEAK
		RESISTED_READ:
			return RESISTED
	return 1.0


# The comic word a first read stamps: DENT when resisted, ZZAP! when weak.
static func word(armour: String, read: String) -> String:
	var row: Dictionary = ARMOUR.get(armour, {})
	return String(row.get("word_resisted" if read == RESISTED_READ else "word_weak", ""))
