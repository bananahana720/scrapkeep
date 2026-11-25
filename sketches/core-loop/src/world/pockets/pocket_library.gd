extends RefCounted

const ParkDefs := preload("res://src/core/park_defs.gd")

const ROOT := "res://src/world/pockets/w1/"
const WORLD_ROOTS := {
	1: ROOT,
	2: "res://src/world/pockets/w2/",
	3: "res://src/world/pockets/w3/",
}
const FOOTPRINTS := {"small": 24.0, "medium": 32.0, "large": 44.0}
const DIFFICULTIES := {1: 1.0, 5: 2.0, 10: 3.0}
static var _rows: Array = []
static var _world_rows: Dictionary = {}


static func reset_for_tests() -> void:
	_rows.clear()
	_world_rows.clear()


static func rows() -> Array:
	return _loaded().duplicate(true)


static func rows_for_world(world: int) -> Array:
	return _loaded_world(world).duplicate(true)


static func all_rows() -> Array:
	var out: Array = []
	for world in [1, 2, 3]:
		for entry in _loaded_world(world):
			out.append(entry.duplicate(true))
	return out


static func world_for_map(map_id: String) -> int:
	for row in ParkDefs.DEFS:
		if String(row.get("map", "")) == map_id:
			return int(row.get("world", 0))
	return 0


static func _loaded() -> Array:
	if _rows.is_empty():
		_rows = _loaded_world(1)
	return _rows


static func _loaded_world(world: int) -> Array:
	if not WORLD_ROOTS.has(world):
		return []
	if not _world_rows.has(world):
		var root_dir: String = String(WORLD_ROOTS[world])
		var list: Array = []
		var files := DirAccess.get_files_at(root_dir)
		files.sort()
		for file in files:
			if file.ends_with(".json"):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(root_dir + file))
				assert(parsed is Dictionary, "invalid pocket: " + file)
				list.append(parsed)
		_world_rows[world] = list
	return _world_rows[world]


static func _loaded_all() -> Array:
	var out: Array = []
	for world in [1, 2, 3]:
		out.append_array(_loaded_world(world))
	return out


static func for_site(map_id: String, row_id: String) -> Dictionary:
	for entry in _loaded_all():
		var assigned: Dictionary = entry.get("assigned", {})
		if assigned.get("map", "") == map_id and assigned.get("row", "") == row_id and entry.kind != "trade":
			return entry.duplicate(true)
	return {}


static func site_spec(entry: Dictionary) -> Dictionary:
	var side: float = FOOTPRINTS[entry.footprint]
	return {"interior": entry.duplicate(true), "ring": float(entry.ring),
		"difficulty": DIFFICULTIES[int(entry.difficulty)], "pack": entry.pack.duplicate(),
		"tell": entry.tell.duplicate(true), "footprint": Vector3(side, 8.0, side)}


static func trade(id: String) -> Dictionary:
	for entry in _loaded_all():
		if entry.kind == "trade" and entry.id == id:
			return entry.duplicate(true)
	return {}
