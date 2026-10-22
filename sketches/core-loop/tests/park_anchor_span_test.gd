extends SceneTree
# Islands anchor posts (#241 ruling 6330671507 item 2): clear_zones skips a footprint that spans the park
# (park_recipes.gd spans_park: size[2] reaches the play rect's extent on its cross axis, the park_map.gd mesa_edge
# reach), and keeps every route lane.
# (a) islands places posts (it placed 0 of 1,730 before) and its full-width bands are no footprint zone;
# (b) the other five parks keep their post counts (pinned from base b12fd171);
# (c) a full-width row's route lanes still clear a post.
# Evidence limit: placement data only.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

# Posts per park at base b12fd171 (clear_zones without the span rule); islands was 0.
const PINNED := {"dam": 6059, "flume": 20, "pit": 85, "sinkhole": 1281, "crown": 5618}

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
	_t.check("(a) islands places posts (%d)" % _posts(islands), _posts(islands) > 0)
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
			{"id": "band", "element": "drop", "at": [0, 0], "size": [40, 10, 200], "yaw_deg": 0},
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
	quit(_t.verdict())
