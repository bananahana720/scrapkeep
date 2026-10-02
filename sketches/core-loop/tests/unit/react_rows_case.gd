extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const FIELDS := ["angle", "rise", "hold", "recover", "overshoot", "tumble", "limit"]


func run(t) -> void:
	for hit in EventKinds.IMPACT:
		t.check("ER-1 " + hit, EventKinds.REACTIONS.has(EventKinds.IMPACT[hit]["react"]), "reaction row exists")
	for id in EventKinds.REACTIONS:
		var row: Dictionary = EventKinds.REACTIONS[id]
		t.eq("ER-1 field count " + id, row.size(), FIELDS.size())
		for field in FIELDS:
			t.check("ER-1 numeric " + id + "/" + field, row.has(field) and (row[field] is float or row[field] is int), "numeric field")
		var duration := float(row["rise"]) + float(row["hold"]) + float(row["recover"])
		t.check("ER-1 valid timing " + id, row["rise"] > 0.0 and row["hold"] >= 0.0 and row["recover"] > 0.0 and duration <= row["limit"], str(duration))
		t.check("ER-1 valid angles " + id, row["angle"] > 0.0 and row["overshoot"] >= 0.0 and row["tumble"] >= 0.0, str(row))
	t.check("flinch duration", EventKinds.REACTIONS["flinch"]["limit"] <= 0.15)
	t.check("stagger duration", EventKinds.REACTIONS["stagger"]["rise"] + EventKinds.REACTIONS["stagger"]["hold"] + EventKinds.REACTIONS["stagger"]["recover"] >= 0.3 and EventKinds.REACTIONS["stagger"]["limit"] <= 0.45)
	t.check("launch duration", EventKinds.REACTIONS["launch"]["limit"] <= 0.9)
