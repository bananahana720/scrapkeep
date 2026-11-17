extends RefCounted

# The Spillway's breathers as data (map audit unit 7, map points 2, 3 and 9), keyed by park map id; a map with no row
# has none. A breather is a circle on the riding lines, clear of every fight site, where the director places no pack of
# its own (director.gd). It belongs where those packs come from: line nodes with no crew home in the window ahead (a
# home in the window spawns its own crew instead), which on world 1 are about half of each map's lines. Kept beside lock_rows.gd rather than in the park JSON, whose hash the bakes carry: a breather
# changes no ground. ParkMap.breathers() reads them; director_breather_test checks each one stands on the lines, keeps
# clear of the fights, and has a radius inside RADIUS.
const RADIUS := Vector2(20.0, 120.0)
# The flume has none (W1-31, gameplay critique section 6): its landing was a breath after the dam launch, and the curve
# after the dam must not rest on its opening.
const ROWS := {
	"park_dam": [
		# Below the shelf, where no crew home is in the window ahead (so the director's own packs land here) and the
		# riding lines run 92 m clear of every fight site. 23 of the 29 such line nodes on the dam are inside it.
		{"id": "shelf_foot_breather", "at": Vector2(8.0, -104.0), "radius_m": 60.0},
	],
}


static func rows(map_id: String) -> Array:
	return ROWS.get(map_id, [])
