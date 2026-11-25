extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")


const SEPARATOR := " / "


static func odds_for(rarities: Array, class_id: String) -> Array:
	var live: Array = []
	for r in ItemGen.resolve_rarities(rarities):
		if not Parts.offer_pool(class_id, [r]).is_empty():
			live.append(r)
	return ItemGen.odds(live)


static func rows(odds: Array) -> Array:
	var out: Array = []
	for row in odds:
		if float(row["share"]) <= 0.0:
			continue
		var rarity: String = row["rarity"]
		out.append({"rarity": rarity, "label": ItemGen.RARITY[rarity]["stamp"], "percent": roundi(float(row["share"]) * 100.0),
			"color": ItemGen.RARITY[rarity]["color"]})
	return out


static func text(odds: Array) -> String:
	var bits: Array = []
	for row in rows(odds):
		bits.append("%s %d%%" % [row["label"], row["percent"]])
	return SEPARATOR.join(bits)
