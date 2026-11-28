extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")


static func odds_for(rarities: Array, class_id: String) -> Array:
	return Parts.odds_for(rarities, class_id)


static func text(odds: Array) -> String:
	return ItemGen.odds_text(odds)


static func results_text(seen: Array) -> String:
	var lines := PackedStringArray()
	for row in seen:
		var flags := []
		if row.curse:
			flags.append("curse, pool floor %.1f" % row.pool_floor)
		if row.sacrifice:
			flags.append("sacrifice %.3f%s" % [row.sacrifice_chance, ", full-health +0.25" if row.full_health_bump else ""])
		if flags.is_empty():
			flags.append("no curse or sacrifice")
		lines.append("Stage %d %s | %s | recency x%.2f | safe %.0f%% | refusal x%.2f | %s" % [row.stage, String(row.interior_id).replace("_", " "), row.family, row.recency, row.safe_share * 100.0, row.refusal_weight, "; ".join(flags)])
	return "\n".join(lines)
