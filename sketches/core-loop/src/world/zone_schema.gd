extends RefCounted

const Spillway := preload("res://src/world/map_spillway.gd")

const REQUIRED := ["spawn", "beacon", "vault", "bay"]
const OPTIONAL := ["activity_sites", "hard_points", "relic_spot"]
const SPILLWAY_BENCHES := [
	{"at": Vector2(24.0, 22.0)},
	{"at": Vector2(66.0, 2.0)},
]


static func slots(map) -> Dictionary:
	var result := {}
	for id in REQUIRED + OPTIONAL:
		if has_field(map, id):
			result[id] = field(map, id)
	if not result.has("bay"):
		if map is Spillway:
			result["bay"] = SPILLWAY_BENCHES
		elif has_field(map, "gate_slots"):
			var gates = field(map, "gate_slots")
			if not gates is Array or not gates.is_empty():
				result["bay"] = gates
	return result.duplicate(true)


static func validate(map) -> Array:
	var issues := []
	var data := slots(map)
	for id in REQUIRED:
		if not data.has(id):
			issues.append(id)
		elif id == "bay":
			if not _positions(data[id], false):
				issues.append("bay: expected nonempty Array of {at: Vector2}")
		elif not data[id] is Vector2:
			issues.append("%s: expected Vector2" % id)
	for id in OPTIONAL:
		if not data.has(id):
			continue
		var value = data[id]
		match id:
			"activity_sites":
				if not _positions(value, true, true):
					issues.append("activity_sites: expected Array of {id: String, at: Vector2}")
			"hard_points":
				if not _positions(value, false, true):
					issues.append("hard_points: expected Array of {at: Vector2}")
			"relic_spot":
				if not value is Vector2:
					issues.append("relic_spot: expected Vector2")
	return issues


static func _positions(value, needs_id: bool, allow_empty := false) -> bool:
	if not value is Array:
		return false
	if value.is_empty():
		return allow_empty
	for row in value:
		if not row is Dictionary or not row.get("at") is Vector2:
			return false
		if needs_id:
			if not row.get("id") is String or row["id"].is_empty():
				return false
	return true


static func has_field(map, id: String) -> bool:
	if map is Dictionary:
		return map.has(id)
	return map is Object and id in map


static func field(map, id: String):
	return map.get(id)
