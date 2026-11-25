extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const Fabricators := preload("res://src/build/fabricators.gd")

const PREFIX := "active:"
const SHARE := {"gate": 0.3, "vault": 0.25, "shop": 0.35}
const ICON := "cat_damage"


static func is_offer(id: String) -> bool:
	return id.begins_with(PREFIX)


static func active_of(id: String) -> String:
	return id.substr(PREFIX.length()) if is_offer(id) else ""


static func offer_id(active_id: String) -> String:
	return PREFIX + active_id


static func pool(rows: Dictionary, rarities: Array, held: Array) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var out: Array = []
	for id in rows:
		if not id in held and ItemGen.resolve_rarity(String(rows[id]["rarity"])) in rarities:
			out.append(id)
	return out


static func roll(rng: RandomNumberGenerator, source: String, rows: Dictionary, rarities: Array, held: Array) -> String:
	var ids := pool(rows, rarities, held)
	if ids.is_empty() or rng.randf() >= float(SHARE.get(source, 0.0)):
		return ""
	return offer_id(ids[rng.randi_range(0, ids.size() - 1)])


static func rarity_of(row: Dictionary) -> String:
	var id := ItemGen.resolve_rarity(String(row.get("rarity", "rare")))
	return id if id != "" else "rare"


static func maker_name(row: Dictionary) -> String:
	return String(row.get("maker", "")).capitalize()


static func mark(row: Dictionary) -> String:
	return "* active, %s *" % maker_name(row)


static func gate_record(id: String, row: Dictionary) -> Dictionary:
	return {
		"part_id": id, "active": active_of(id), "maker": String(row.get("maker", "")),
		"name": row.get("name", ""), "headline": "%s: %s" % [row.get("name", ""), row.get("verb", "")],
		"verb": row.get("verb", ""), "punch": 0.0, "text": row.get("text", ""),
		"rarity": rarity_of(row), "hotwired": false, "tier": int(ItemGen.RARITY[rarity_of(row)]["tier"]),
		"synergy": "", "mark": mark(row), "family": "active", "icon": ICON, "trigger_icon": "", "element_icon": "",
	}


static func price(row: Dictionary, parts_held: int) -> int:
	return Fabricators.off_shelf_price(int(ItemGen.RARITY[rarity_of(row)]["tier"]), parts_held)
