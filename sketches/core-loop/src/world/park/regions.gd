extends RefCounted

# Park coordinates and the Slag Bowl's centre-relative coordinates are both (x, z).
const FILES := {
	"park_dam": "res://assets/park/park_dam/regions.json",
	"park_flume": "res://assets/park/park_flume/regions.json",
	"slag_bowl": "res://src/boss/arena_regions.json",
}

static var _maps := {}


static func at(map_id: String, point: Vector2) -> Dictionary:
	if not FILES.has(map_id):
		return {}
	if not _maps.has(map_id):
		var prepared := []
		if not FileAccess.file_exists(FILES[map_id]):
			return {}
		var rows = JSON.parse_string(FileAccess.get_file_as_string(FILES[map_id]))
		if not rows is Array:
			push_error("Cannot read regions for %s" % map_id)
			return {}
		for row: Dictionary in rows:
			var polygon := PackedVector2Array()
			for vertex: Array in row["polygon"]:
				polygon.append(Vector2(vertex[0], vertex[1]))
			prepared.append({"polygon": polygon, "row": row})
		_maps[map_id] = prepared
	for region: Dictionary in _maps[map_id]:
		if Geometry2D.is_point_in_polygon(point, region.polygon):
			return region.row.duplicate(true)
	return {}
