extends RefCounted

const ZoneSchema := preload("res://src/world/zone_schema.gd")


static func fill(map, seed: int) -> Dictionary:
	var result := ZoneSchema.slots(map)
	var candidates := _sites(map)
	if candidates.is_empty():
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for id in ZoneSchema.OPTIONAL:
		if result.has(id):
			var value = result[id]
			if not value is Array or not value.is_empty():
				continue
		var site: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		match id:
			"activity_sites":
				result[id] = [site.duplicate(true)]
			"hard_points":
				result[id] = [{"at": site["at"]}]
			"relic_spot":
				result[id] = site["at"]
	return result


static func _sites(map) -> Array:
	var candidates := []
	if ZoneSchema.has_field(map, "activity_sites"):
		var activities = ZoneSchema.field(map, "activity_sites")
		if activities is Array:
			for row in activities:
				if row is Dictionary and row.get("id") is String and not row["id"].is_empty() and row.get("at") is Vector2:
					candidates.append({"id": row["id"], "at": row["at"]})
	if ZoneSchema.has_field(map, "sites"):
		var events = ZoneSchema.field(map, "sites")
		if events is Dictionary:
			for id in events:
				var row = events[id]
				if id is String and not id.is_empty() and row is Dictionary and row.get("ring") is Vector2:
					candidates.append({"id": id, "at": row["ring"]})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["id"] != b["id"]:
			return a["id"] < b["id"]
		var p: Vector2 = a["at"]
		var q: Vector2 = b["at"]
		return p.x < q.x or (p.x == q.x and p.y < q.y))
	return candidates
