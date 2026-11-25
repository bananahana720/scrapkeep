extends RefCounted

const RADIUS := Vector2(20.0, 120.0)
const ROWS := {
	"park_dam": [
		{"id": "shelf_foot_breather", "at": Vector2(8.0, -104.0), "radius_m": 60.0},
	],
	"park_pit": [
		{"id": "upper_haul_breather", "at": Vector2(-184.0, -432.0), "radius_m": 60.0},
	],
	"park_sinkhole": [
		{"id": "cenote_rim_breather", "at": Vector2(-8.0, -184.0), "radius_m": 60.0},
	],
	"park_islands": [
		{"id": "lee_span_breather", "at": Vector2(-16.0, 208.0), "radius_m": 60.0},
	],
}


static func rows(map_id: String) -> Array:
	return ROWS.get(map_id, [])
