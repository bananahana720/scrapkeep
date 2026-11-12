extends RefCounted

# The Spillway's breathers as data (map audit unit 7, map points 2, 3 and 9), keyed by park map id; a map with no row
# has none. A breather is a circle on the riding lines, clear of every fight site, where the director places no pack of
# its own (director.gd). Kept beside lock_rows.gd rather than in the park JSON, whose hash the bakes carry: a breather
# changes no ground. ParkMap.breathers() reads them; director_breather_test checks each one stands on the lines, keeps
# clear of the fights, and has a radius inside RADIUS.
const RADIUS := Vector2(20.0, 120.0)
const ROWS := {
	"park_dam": [
		# The wash between the drop-in fights and the shelf: the riding lines run 118 m clear of every fight site.
		{"id": "low_wash_breather", "at": Vector2(-16.0, -272.0), "radius_m": 60.0},
		# The apron below the dam face, the last quiet stretch before the Warden: 112 m clear of every fight site.
		{"id": "mid_apron_breather", "at": Vector2(-8.0, 240.0), "radius_m": 60.0},
	],
	"park_flume": [
		# Where the dam launch lands: a breath after the flight, before the flume reach. 90 m clear of every fight site.
		{"id": "landing_breather", "at": Vector2(-462.0, -499.0), "radius_m": 60.0},
	],
}


static func rows(map_id: String) -> Array:
	return ROWS.get(map_id, [])
