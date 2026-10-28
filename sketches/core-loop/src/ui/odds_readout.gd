extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")

# The odds readout (SG13): what an offer can contain, as words and as rows a plate can draw.
# It formats ItemGen.odds() and nothing else, so the number on screen is the number the roll
# reads. A rarity with no weight is not listed. Colour and label come from the one RARITY table,
# so a tier reads the same here as on the shelf frame and the reveal stamp.

const SEPARATOR := " / "


# The odds of a table as Parts.roll delivers them for this class: ItemGen.odds() over the
# table's rarities that hold at least one part in the pool. A rarity with no part cannot be
# paid (roll() hands its slot to the rest of the pool), so showing it would promise what never
# comes; a table with no part at all shows [] and pays nothing. Weights stay the weight row's.
static func odds_for(rarities: Array, class_id: String) -> Array:
	var live: Array = []
	for r in ItemGen.resolve_rarities(rarities):
		if not Parts.offer_pool(class_id, [r]).is_empty():
			live.append(r)
	return ItemGen.odds(live)


# One row per rarity that can come up: its id, stamp label, whole percent and colour.
static func rows(odds: Array) -> Array:
	var out: Array = []
	for row in odds:
		if float(row["share"]) <= 0.0:
			continue
		var rarity: String = row["rarity"]
		out.append({"rarity": rarity, "label": ItemGen.RARITY[rarity]["stamp"], "percent": roundi(float(row["share"]) * 100.0),
			"color": ItemGen.RARITY[rarity]["color"]})
	return out


# "FIELD KIT 90% / FLEET GRADE 10%"; "" when nothing can come up.
static func text(odds: Array) -> String:
	var bits: Array = []
	for row in rows(odds):
		bits.append("%s %d%%" % [row["label"], row["percent"]])
	return SEPARATOR.join(bits)
