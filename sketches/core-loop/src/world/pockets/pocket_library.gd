extends RefCounted

const ROOT := "res://src/world/pockets/w1/"
const FOOTPRINTS := {"small": 24.0, "medium": 32.0, "large": 44.0}
const DIFFICULTIES := {1: 1.0, 5: 2.0, 10: 3.0}
static var _rows: Array = []


static func rows() -> Array:
	if _rows.is_empty():
		var files := DirAccess.get_files_at(ROOT)
		files.sort()
		for file in files:
			if file.ends_with(".json"):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROOT + file))
				assert(parsed is Dictionary, "invalid pocket: " + file)
				_rows.append(parsed)
	return _rows.duplicate(true)


static func for_site(map_id: String, row_id: String) -> Dictionary:
	for entry in rows():
		var assigned: Dictionary = entry.get("assigned", {})
		if assigned.get("map", "") == map_id and assigned.get("row", "") == row_id and entry.kind != "trade":
			return entry
	return {}


static func site_spec(entry: Dictionary) -> Dictionary:
	var side: float = FOOTPRINTS[entry.footprint]
	return {"interior": entry.duplicate(true), "ring": float(entry.ring),
		"difficulty": DIFFICULTIES[int(entry.difficulty)], "pack": entry.pack.duplicate(),
		"tell": entry.tell.duplicate(true), "footprint": Vector3(side, 8.0, side)}
