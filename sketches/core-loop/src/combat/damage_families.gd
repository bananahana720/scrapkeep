extends RefCounted

const RESISTED := 0.6
const WEAK := 1.25
const KINETIC := "kinetic"
const ARC := "arc"
const FROST := "frost"
const ABILITY := "special"
const RESISTED_READ := "resisted"
const WEAK_READ := "weak"

const FAMILY_OF := {"arc": ARC, "electrify": ARC, "frost": FROST}

const ARMOUR := {
	"plated": {"resist": [KINETIC], "weak": [ARC, "ability"], "word_resisted": "DENT", "word_weak": "ZZAP!"},
	"wet": {"resist": [], "weak": [ARC], "word_resisted": "DENT", "word_weak": "ZZAP!"},
}

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


static func word(armour: String, read: String) -> String:
	var row: Dictionary = ARMOUR.get(armour, {})
	return String(row.get("word_resisted" if read == RESISTED_READ else "word_weak", ""))
