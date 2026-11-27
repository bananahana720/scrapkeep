extends SceneTree
# Islands anchor posts (#241 ruling 6330671507 item 2): clear_zones skips a footprint that spans the park
# (park_recipes.gd spans_park: park_map.gd mesa_edge's rule, a stamped greybox row with no y whose size[2] reaches the
# play rect's extent on its cross axis), and keeps every route lane.
# (a) islands places 1,229 posts (it placed 0 of 1,730 before) and its full-width bands are no footprint zone;
# (b) the other five parks keep their post counts (pinned at b12fd171, unchanged at 74682daf);
# (c) a full-width row's route lanes still clear a post;
# (d) the cross axis on a non-square rect at yaw 0 and 90, and a full-width built solid (no stamp, or a y) keeps out.
# Evidence limit: placement data only.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

# Posts per park at b12fd171 (clear_zones without the span rule; islands was 0), unchanged at 74682daf.
# Re-pinned 2026-10-30 (clip audit): islands 1229 -> 1172, as anchor_posts drops a lane-edge post within ANCHOR_POST_M
# of a post already kept (two lanes' edge posts at a joint, or an edge post on a lattice post, drew one post through another).
const ISLANDS_POSTS := 1172
# Re-pinned 2026-10-23 (#241 gate, comment 6357833993): sinkhole 1281 -> 1282 at B12 #350 (main_tube_upper_post_11i moved
# to (-27.3, -120.2) and now keeps a post); crown 5618 -> 5620 at B11 #321 (sentinel_36 and sentinel_50 moved and each now keeps a post).
# Re-pinned 2026-10-26 (unit 10, the dam's canyon walls): dam 6059 -> 5184, because eighteen outskirts fields now stop
# 12 m short of the walls' feet (park_dam.json hoodoo_1 to saguaro_26), so no post stands on a face.
# Re-pinned 2026-10-30 for the same edge-post rule: dam 5184 -> 5177, flume 20 -> 16, pit 85 -> 79, sinkhole 1282 -> 1260,
# crown 5620 -> 5436.
const PINNED := {"dam": 5168, "flume": 16, "pit": 79, "sinkhole": 1260, "crown": 5436}

var _t := T.new("park_anchor_span_test")


func _initialize() -> void:
	call_deferred("_run")


func _park(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_%s.json" % name))


func _posts(park: Dictionary) -> int:
	var zones := ParkRecipes.clear_zones(park)
	var n := 0
	for row: Dictionary in ParkRecipes.placed_rows(park):
		if ParkRecipes.is_anchor_field(row):
			n += ParkRecipes.anchor_posts(row, zones).size()
	return n


func _run() -> void:
	var islands := _park("islands")
	_t.eq("(a) islands places its posts", _posts(islands), ISLANDS_POSTS)
	var mesa := {}
	for row: Dictionary in islands["park_rows"]:
		if row["id"] == "lookout_mesa":
			mesa = row
	_t.check("(a) lookout_mesa spans the park", ParkRecipes.spans_park(mesa, islands))
	var footprints := ParkRecipes.clear_zones(islands).filter(func(z: Dictionary) -> bool: return not z.has("a"))
	_t.check("(a) no footprint zone is 1,600 m across", footprints.all(func(z: Dictionary) -> bool: return (z["size"] as Vector2).y < 1600.0))
	for name: String in PINNED:
		_t.eq("(b) %s post count" % name, _posts(_park(name)), PINNED[name])
	var lanes := ParkRecipes.clear_zones(islands).filter(func(z: Dictionary) -> bool: return z.has("a"))
	_t.check("(c) islands keeps route lanes (%d)" % lanes.size(), lanes.size() > 0)
	var park := {
		"play_rect": [-100, -100, 200, 200], "waymarks": [], "spawn": {"at": [0, -80]},
		"park_rows": [
			{"id": "band", "element": "drop", "at": [0, 0], "size": [40, 10, 200], "yaw_deg": 0, "recipe": "greybox:drop", "stamp": "plateau", "y": null},
			{"id": "far", "element": "drop", "at": [0, 60], "size": [10, 10, 10], "yaw_deg": 0},
		],
		"routes": [{"id": "r", "from": "drop_in", "via": ["band"], "to": "far"}],
	}
	var zones := ParkRecipes.clear_zones(park)
	var foot := zones.filter(func(z: Dictionary) -> bool: return not z.has("a"))
	var lane := zones.filter(func(z: Dictionary) -> bool: return z.has("a"))
	_t.eq("(c) the full-width band is no footprint, the small row is", foot.size(), 1)
	_t.check("(c) the band's route lanes remain (%d)" % lane.size(), lane.size() == 2)
	_t.check("(c) a point on the lane is cleared", ParkRecipes.in_clear(zones, Vector2(0, -40), 1.0))
	# A 200 m wide (x) by 400 m deep (z) rect. At yaw 0 the across axis is x, at yaw 90 it is z; 300 m spans x only, so
	# a swapped rect read fails both.
	var tall := {"play_rect": [-100, -200, 200, 400]}
	var stamped := {"element": "drop", "recipe": "greybox:drop", "stamp": "plateau", "y": null}
	var across_x := stamped.merged({"size": [40, 10, 300], "yaw_deg": 0})
	var across_z := stamped.merged({"size": [40, 10, 300], "yaw_deg": 90})
	_t.check("(d) 300 m across at yaw 0 spans a 200 m wide rect", ParkRecipes.spans_park(across_x, tall))
	_t.check("(d) 300 m across at yaw 90 does not span a 400 m deep rect", not ParkRecipes.spans_park(across_z, tall))
	_t.check("(d) a full-width row with no stamp is a built solid, not a band", not ParkRecipes.spans_park(across_x.merged({"stamp": ""}, true), tall))
	_t.check("(d) a full-width row with an absolute y is a built solid", not ParkRecipes.spans_park(across_x.merged({"y": 4.0}, true), tall))
	_t.check("(d) a full-width row on a built recipe keeps out", not ParkRecipes.spans_park(across_x.merged({"recipe": "mesa_lip_kicker"}, true), tall))
	quit(_t.verdict())
